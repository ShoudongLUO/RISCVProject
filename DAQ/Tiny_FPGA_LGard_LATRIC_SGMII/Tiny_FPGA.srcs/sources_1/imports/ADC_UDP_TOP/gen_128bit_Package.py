import sys
import os
import math

# ================= 配置区域 =================
# 必须使用 r"" 来防止路径转义错误
INPUT_CSV = r"C:\Users\ShoudongLUO\Desktop\RISCV\500kHz-100%-300V_002_ALL.csv"
OUT_FILE_CH1 = "ch1_vectors.txt"
OUT_FILE_CH2 = "ch2_vectors.txt"


# ================= 物理常数 =================
THRESHOLD = 0.13          
SAMDT = 0.16              
SERFEQ = 720.0            
DBIT = (1.0 / SERFEQ) * 1000.0 

# ================= 协议常数 =================
HEADER_PATTERN = 0b10101010101010101
HEADER_LEN = 17
HEADER_MASK = (1 << HEADER_LEN) - 1
WORD_CONFIG = [30, 30, 30, 7, 7, 7] 

class ChannelEvent:
    def __init__(self):
        self.headerbuf = 0
        self.header = 0
        self.data = [0] * 6
        self.id = [0, 0]

    def clear(self, level=0):
        if level >= 1: self.headerbuf = 0
        self.header = 0
        self.data = [0] * 6
        self.id = [0, 0]

    def translatecode(self, dt_ns):
        return int(dt_ns / DBIT + 0.5)

    def getfinecode(self, val):
        ic = 0
        found = False
        for i in range(30):
            ps = (val >> (29 - i)) & 1
            if i == 29: ns = (val >> 29) & 1
            else: ns = (val >> (29 - i - 1)) & 1
            if ps == 0 and ns == 1:
                ic = i
                found = True
                break
        if not found: return -2 
        
        onezero = [0, 0]
        for j in range(ic + 1, ic + 1 + 30):
            pb = 29 - j
            if pb < 0: pb += 30 
            ps = (val >> pb) & 1
            if ps == 1: onezero[0] += 1
            if j < ic + 1 + 15:
                if ps == 1: onezero[1] += 1
            else:
                if ps == 0: onezero[1] += 1
        
        if onezero[1] != 30:
            if onezero[0] == 15: pass 
            else: return -3 
        return ic 

    def push_bits_recursive(self, bit_val, count, writer_func):
        remaining = count
        while remaining > 0:
            if self.header == 0:
                self.headerbuf = ((self.headerbuf << 1) | bit_val) & HEADER_MASK
                remaining -= 1
                if self.headerbuf == HEADER_PATTERN:
                    self.header = self.headerbuf
                    self.headerbuf = 0
            else:
                idx = self.id[0]
                self.data[idx] = ((self.data[idx] << 1) | bit_val) 
                remaining -= 1
                self.id[1] += 1
                
                idflag = False
                if 0 <= self.id[0] < 3:
                    if self.id[1] >= 30: idflag = True
                else:
                    if self.id[1] >= 7: idflag = True
                
                if idflag:
                    self.id[0] += 1
                    self.id[1] = 0
                    check_idx = self.id[0] - 1
                    if 0 <= check_idx < 3:
                        check_res = self.getfinecode(self.data[check_idx])
                        if check_res < 0:
                            self.clear(level=0) 
                            self.header = 0 
                            self.data = [0]*6
                            self.id = [0,0]
                            continue 

                if self.id[0] >= 6:
                    writer_func(self.data) 
                    self.clear(level=0)

def write_packet_to_file(f, data):
    packet = 0
    packet |= (data[0] & 0x3FFFFFFF) << 98
    packet |= (data[1] & 0x3FFFFFFF) << 68
    packet |= (data[2] & 0x3FFFFFFF) << 38
    packet |= (data[3] & 0x7F) << 31
    packet |= (data[4] & 0x7F) << 24
    packet |= (data[5] & 0x7F) << 17
    f.write(f"{packet:032x}\n")

def process_file(filename):
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found.")
        return

    print(f"Processing {filename} ...")
    
    f_ch1 = open(OUT_FILE_CH1, 'w')
    f_ch2 = open(OUT_FILE_CH2, 'w')
    
    ev = [ChannelEvent(), ChannelEvent()]
    prev_stat = [-1, -1]
    tnt = [0, 0] 

    def write_ch1(data): write_packet_to_file(f_ch1, data)
    def write_ch2(data): write_packet_to_file(f_ch2, data)
    writers = [write_ch1, write_ch2]

    line_count = 0
    data_line_count = 0
    packet_counts = [0, 0]

    try:
        f = open(filename, 'r', encoding='utf-8-sig')
    except:
        f = open(filename, 'r')

    start_reading = False
    
    for line in f:
        line = line.strip()
        if not line: continue
        line_count += 1
        
        parts = line.split(',')
        
        # 头部跳过逻辑
        if not start_reading:
            try:
                float(parts[0])
                if len(parts) >= 2: # 只要有至少两列就可以开始尝试
                    start_reading = True
                    print(f"[DEBUG] Found data start at Line {line_count}")
                else: continue
            except ValueError:
                continue

        # === 核心修改：适配 5列 CSV 格式 ===
        # 格式预期: Time1(0), Volts1(1), Empty(2), Time2(3), Volts2(4)
        if len(parts) < 2: continue
        
        try:
            # 获取 Ch1 电压 (第 1 列)
            v1 = float(parts[1])
            
            # 获取 Ch2 电压 (根据格式自动判断)
            if len(parts) >= 5:
                # 泰克示波器 Side-by-Side 格式 (你的格式)
                # 跳过 parts[2] (空) 和 parts[3] (Time2)
                v2 = float(parts[4])
            elif len(parts) >= 3:
                # 标准格式: Time, Ch1, Ch2
                # 如果 parts[2] 是空的，说明是上面的格式但行没对齐，fallback
                if parts[2].strip() == "":
                     # 尝试找后面非空的
                     if len(parts) > 4: v2 = float(parts[4])
                     else: continue
                else:
                    v2 = float(parts[2])
            else:
                # 只有一列数据的情况
                v2 = 0.0
            
            volts = [v1, v2]
            
        except (ValueError, IndexError):
            # 如果某一行数据损坏，跳过
            continue
        # =================================

        data_line_count += 1
        
        # 处理逻辑不变
        for i in range(2):
            curr_stat = 1 if volts[i] >= THRESHOLD else 0
            if curr_stat != prev_stat[i]:
                if prev_stat[i] != -1:
                    dt_ns = tnt[i] * SAMDT
                    nb = ev[i].translatecode(dt_ns)
                    if nb > 0:
                        def wrapped_writer(d):
                            writers[i](d)
                            packet_counts[i] += 1
                        ev[i].push_bits_recursive(prev_stat[i], nb, wrapped_writer)
                tnt[i] = 0
                prev_stat[i] = curr_stat
            tnt[i] += 1

    f.close()
    f_ch1.close()
    f_ch2.close()
    
    print("-" * 30)
    print(f"Summary:")
    print(f"Total Lines Scanned: {line_count}")
    print(f"Data Lines Processed: {data_line_count}")
    print(f"Ch1 Packets: {packet_counts[0]}")
    print(f"Ch2 Packets: {packet_counts[1]}")
    
    if packet_counts[0] == 0:
        print("\n[HINT] Ch1 count is 0. Check THRESHOLD (Currently {:.2f}V).".format(THRESHOLD))
        print("Your data starts with: {:.3f} V".format(volts[0] if 'volts' in locals() else 0))

if __name__ == "__main__":
    target_file = sys.argv[1] if len(sys.argv) > 1 else INPUT_CSV
    process_file(target_file)