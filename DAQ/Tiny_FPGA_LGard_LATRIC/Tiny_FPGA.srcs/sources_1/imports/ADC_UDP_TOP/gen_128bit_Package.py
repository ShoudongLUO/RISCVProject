import sys
import os
import math

# ================= 配置区域 =================
# 输入文件路径 (请修改这里)
INPUT_CSV = "Tek000_010_ALL_laser10.csv"

# 输出文件名称
OUT_FILE_CH1 = "ch1_vectors.txt"
OUT_FILE_CH2 = "ch2_vectors.txt"

# 物理参数 (必须与 C 代码一致)
THRESHOLD = 0.13      # 阈值电压 (V)
SAMDT = 0.16          # 采样间隔 (ns)
SERFEQ = 720.0        # 通信频率 (MHz)
BIT_DURATION = (1.0 / SERFEQ) * 1000.0 # 单比特时长 (ns)

# 协议参数
HEADER_PATTERN = 0b10101010101010101
HEADER_LEN = 17
HEADER_MASK = (1 << HEADER_LEN) - 1

# 数据包结构: 30-30-30-7-7-7
WORD_LENGTHS = [30, 30, 30, 7, 7, 7]
TOTAL_WORDS = 6

class ChannelDecoder:
    def __init__(self, ch_id, outfile):
        self.ch_id = ch_id
        self.f_out = open(outfile, 'w')
        self.reset()
        
    def reset(self):
        self.header_buf = 0
        self.header_found = False
        self.data = [0] * TOTAL_WORDS
        self.current_word_idx = 0
        self.current_bit_count = 0
        
    def close(self):
        self.f_out.close()

    def translate_code(self, dt_ns):
        # 计算脉冲持续时间对应的比特数 (对应 C++ translatecode)
        nb = int((dt_ns / BIT_DURATION) + 0.5)
        return nb

    def push_bits(self, bit_val, count):
        # 模拟 C++ 的 loadbuf
        # bit_val: 0 或 1
        # count: 连续多少个这样的 bit
        
        for _ in range(count):
            # 1. 如果还没找到 Header，先找 Header
            if not self.header_found:
                self.header_buf = ((self.header_buf << 1) | bit_val) & HEADER_MASK
                if self.header_buf == HEADER_PATTERN:
                    self.header_found = True
                    self.header_buf = 0 # 重置 buffer
                    # print(f"Ch{self.ch_id} Header Found!")
            
            # 2. 如果 Header 找到了，开始填充数据
            else:
                # 将 bit 推入当前的数据字
                curr_idx = self.current_word_idx
                self.data[curr_idx] = (self.data[curr_idx] << 1) | bit_val
                self.current_bit_count += 1
                
                # 检查当前字是否填满
                target_len = WORD_LENGTHS[curr_idx]
                
                # 特殊逻辑：前3个字允许是30位，后3个是7位 (复刻 C++ idflag 逻辑)
                if self.current_bit_count >= target_len:
                    self.current_word_idx += 1
                    self.current_bit_count = 0
                    
                    # 检查是否所有字都填满了 (包完整了)
                    if self.current_word_idx >= TOTAL_WORDS:
                        self.write_packet()
                        self.reset_payload() # 准备下一个包 (注意：不重置 Header 查找状态? 
                                             # C代码中 ev[i]->clear() 会重置 header，这意味着
                                             # 每个包都需要重新找 header)
                        self.header_found = False 
                        self.header_buf = 0

    def reset_payload(self):
        self.data = [0] * TOTAL_WORDS
        self.current_word_idx = 0
        self.current_bit_count = 0

    def write_packet(self):
        # 将 data[0]..data[5] 拼成 128-bit 大整数
        # 映射关系参考 Verilog:
        # [127:98] = data[0] (30 bit)
        # [97:68]  = data[1] (30 bit)
        # [67:38]  = data[2] (30 bit)
        # [37:31]  = data[3] (7 bit)
        # [30:24]  = data[4] (7 bit)
        # [23:17]  = data[5] (7 bit)
        
        packet = 0
        packet |= (self.data[0] & 0x3FFFFFFF) << 98
        packet |= (self.data[1] & 0x3FFFFFFF) << 68
        packet |= (self.data[2] & 0x3FFFFFFF) << 38
        packet |= (self.data[3] & 0x7F) << 31
        packet |= (self.data[4] & 0x7F) << 24
        packet |= (self.data[5] & 0x7F) << 17
        
        # 格式化为 32位 16进制字符串 (128 bits / 4 = 32 chars)
        hex_str = f"{packet:032x}"
        self.f_out.write(hex_str + "\n")
        # print(f"Ch{self.ch_id} Packet: {hex_str}")

def process_csv(filename):
    if not os.path.exists(filename):
        print(f"Error: File {filename} not found.")
        return

    print(f"Processing {filename} ...")
    
    # 初始化两个通道的解码器
    decoders = [
        ChannelDecoder(1, OUT_FILE_CH1),
        ChannelDecoder(2, OUT_FILE_CH2)
    ]
    
    # 状态变量 [Ch1, Ch2]
    prev_stat = [-1, -1]
    ticks_cnt = [0, 0] # tnt
    
    with open(filename, 'r') as f:
        start_reading = False
        
        for line in f:
            line = line.strip()
            if not line: continue
            
            # 自动跳过头部，直到找到以数字或符号开头的行
            if not start_reading:
                if line[0].isdigit() or line[0] == '-' or line[0] == '+':
                    start_reading = True
                else:
                    continue
            
            # 解析 CSV (Time, Ch1, Ch2)
            parts = line.split(',')
            if len(parts) < 3: continue
            
            try:
                # time_val = float(parts[0]) # Python 不需要用到时间戳，只需要顺序
                volts = [float(parts[1]), float(parts[2])]
            except ValueError:
                continue
                
            # 处理两个通道
            for i in range(2):
                # 1. 数字化 (Digitize)
                curr_stat = 1 if volts[i] >= THRESHOLD else 0
                
                # 2. 边沿检测 (Edge Detection)
                if curr_stat != prev_stat[i]:
                    if prev_stat[i] != -1:
                        # 状态翻转了，结算上一个状态的长度
                        dt_ns = ticks_cnt[i] * SAMDT
                        nb = decoders[i].translate_code(dt_ns)
                        
                        # 将比特推入解码器
                        decoders[i].push_bits(prev_stat[i], nb)
                        
                    # 重置计数器，更新状态
                    ticks_cnt[i] = 0
                    prev_stat[i] = curr_stat
                
                # 3. 累加计数器
                ticks_cnt[i] += 1
                
    # 关闭文件
    decoders[0].close()
    decoders[1].close()
    print(f"Done! Outputs saved to {OUT_FILE_CH1} and {OUT_FILE_CH2}")

if __name__ == "__main__":
    # 如果命令行没有参数，使用默认 INPUT_CSV，否则使用参数
    input_file = sys.argv[1] if len(sys.argv) > 1 else INPUT_CSV
    process_csv(input_file)