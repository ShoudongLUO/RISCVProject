#include <stdint.h>
#include "../../bsp/include/uart.h"   // 假设 uart_init() 和 xprintf() 在这里
#include "../../bsp/include/xprintf.h" // 假设 xprintf() 在这里
#include <math.h> 
//---------------------------------------------
// 寄存器基地址定义
//---------------------------------------------
#define ADC_BASE_ADDR  0x70000000 // 改个更通用的名字

// 寄存器偏移（4字节对齐）
typedef enum {
    REG_DRP_ADDR_OFFSET   = 0x00,  // W: 设置 DRP 目标地址 (Verilog: drp_addr)
                                 // R: 读回 DRP 目标地址
    REG_DRP_DATA_OFFSET   = 0x04,  // W: 写入 DRP 数据并触发DRP写 (Verilog: drp_di, drp_we, drp_en)
                                 // R: 读回 DRP DO (Verilog: drp_do) - 注意Verilog中此地址用于读drp_do
    REG_DRP_STATUS_OFFSET     = 0x08,  // W: (可选，如果写此地址也触发DRP读)
                                 // R: 状态: drp_rdy(bit1), pll_locked(bit0) (Verilog: drp_rdy_latched, pll_locked)
                                 //    Verilog中写此地址会触发一次DRP读 (drp_en=1, drp_we=0)
    REG_PLL_RST_OFFSET    = 0x0C,  // W/R: 控制/读取 PLL 复位状态 (Verilog: pll_rst)

    // 新增/修改的寄存器定义
    REG_UDP_CONFIG_OFFSET = 0x10,  // W/R: [17]=fifo_wr_en, [16]=udp_tx_enable, [15:0]=tx_data_num
    REG_BOARD_IP_OFFSET   = 0x14,  // W/R: 本机IP地址
    REG_DES_IP_OFFSET     = 0x18,  // W/R: 目标IP地址
    REG_BOARD_PORT_OFFSET = 0x1C,  // W/R: 本机端口
    REG_DES_PORT_OFFSET   = 0x20,  //目标端口
    REG_ADC_CONFIG_OFFSET = 0x24,  //ADC configuration, bit [0-3]: ADC width; bit [4-6] :data width of each channel; bit[7-32] number of channels;
    REG_SYS_STATUS_OFFSET = 0x28,      //System status, 0:Wait 1:Initialization finished; 2: Start Measure Mode; 3:Finish Measure Mode;
                                       //               4:Start Cluster Finding  ; 5: Finish Cluster Finding ; 6:Data Acquirision
    REG_ADC_TEST_OFFSET   = 0x2C,   // W/R: 测试寄存器 (Verilog: adc_test)
    REG_SYS_MODE_OFFSET   = 0x30,   // System mode control
    REG_ADC_DATA_OFFSET   = 0x1000,    //W/R:ADC 数据
    REG_ADC_BASELINE_OFFSET=0x2000,     //W/R:计算得到的基准电压 
    REG_ADC_NOISE_OFFSET  = 0x3000     //Noise 值

} FpgaRegOffset;

// 寄存器访问宏
#define REG_WRITE(offset, value) \
    (*(volatile uint32_t *)(ADC_BASE_ADDR + (offset)) = (value))

#define REG_READ(offset) \
    (*(volatile uint32_t *)(ADC_BASE_ADDR + (offset)))

//基准电压参数
#define CLUSTER_THRESH  3      // 着火阈值倍数
#define SEED_THRESH     2      // 种子阈值倍数
#define MAX_CLUSTER     32     // 最大簇大小
#define A_NOISE        40000     
#define SIGNAL_THRESH  (3 * A_NOISE)//信号阈值，低于该阈值说明未着火
#define SAMPLE_COUNT   16       // 每次采样 16此
#define SAMPLE_COUNT_BITS 5      //  

#define DATAWIDTH 12
#define ADCWIDTH 16
#define NUM_CHANNELS 4

// REG_DRP_STATUS_OFFSET 状态位掩码
#define STATUS_DRP_RDY_MASK    (1 << 1)  // bit1: drp_rdy
#define STATUS_PLL_LOCKED_MASK (1 << 0)  // bit0: pll_locked

// REG_UDP_CONFIG_OFFSET 位掩码和移位
#define UDP_CONFIG_TX_DATA_NUM_MASK   (0x0000FFFF)
#define UDP_CONFIG_TX_DATA_NUM_SHIFT  (0)
#define UDP_CONFIG_UDP_TX_ENABLE_MASK (1 << 16)
#define UDP_CONFIG_UDP_TX_ENABLE_SHIFT (16)
#define UDP_CONFIG_FIFO_WR_EN_MASK    (1 << 17)
#define UDP_CONFIG_FIFO_WR_EN_SHIFT   (17)

    uint16_t baselines[NUM_CHANNELS];
    uint16_t noises[NUM_CHANNELS];
//---------------------------------------------
// 函数：配置UDP参数
//---------------------------------------------
void configure_udp_settings(uint16_t tx_data_num, int udp_tx_enable, int fifo_wr_enable) {
    uint32_t current_config = REG_READ(REG_UDP_CONFIG_OFFSET); // 先读回当前值，避免修改其他未指定的位
    // 清除旧的位
    current_config &= ~UDP_CONFIG_TX_DATA_NUM_MASK;
    current_config &= ~UDP_CONFIG_UDP_TX_ENABLE_MASK;
    current_config &= ~UDP_CONFIG_FIFO_WR_EN_MASK;

    // 设置新的位
    current_config |= (tx_data_num << UDP_CONFIG_TX_DATA_NUM_SHIFT) & UDP_CONFIG_TX_DATA_NUM_MASK;
    if (udp_tx_enable) {
        current_config |= UDP_CONFIG_UDP_TX_ENABLE_MASK;
    }
    if (fifo_wr_enable) {
        current_config |= UDP_CONFIG_FIFO_WR_EN_MASK;
    }

    REG_WRITE(REG_UDP_CONFIG_OFFSET, current_config);
    xprintf("UDP Config Reg (0x%02X) written with: 0x%08X\n", (unsigned int)REG_UDP_CONFIG_OFFSET, (unsigned int)current_config);
}
// ADC配置寄存器位定义
#define ADC_CONFIG_ADC_WIDTH_MASK    0x0000000F  // bit[0-3]: ADC位宽
#define ADC_CONFIG_ADC_WIDTH_SHIFT   0
#define ADC_CONFIG_DATA_WIDTH_MASK   0x000003F0  // bit[4-9]: 数据位宽 (6 bits)
#define ADC_CONFIG_DATA_WIDTH_SHIFT  4
#define ADC_CONFIG_CHANNELS_MASK     0xFFFFFC00  // bit[10-31]: 通道数量 (22 bits)
#define ADC_CONFIG_CHANNELS_SHIFT    10

//---------------------------------------------
// 函数：配置ADC参数
//---------------------------------------------
void configure_adc_settings(int adc_width, int data_width, int adc_channels) {
    // 参数校验
    if(adc_width > 0xF || data_width > 0x3F || adc_channels > 0x3FFFFF) {
        xprintf("Invalid ADC config params!\n");
        return;
    }

    // 读取-修改-写入模式
    uint32_t current_config = REG_READ(REG_ADC_CONFIG_OFFSET);
    
    // 清除旧配置位
    current_config &= ~(ADC_CONFIG_ADC_WIDTH_MASK | 
                       ADC_CONFIG_DATA_WIDTH_MASK | 
                       ADC_CONFIG_CHANNELS_MASK);

    // 设置新配置位
    current_config |= ((adc_width << ADC_CONFIG_ADC_WIDTH_SHIFT) & ADC_CONFIG_ADC_WIDTH_MASK);
    current_config |= ((data_width << ADC_CONFIG_DATA_WIDTH_SHIFT) & ADC_CONFIG_DATA_WIDTH_MASK);
    current_config |= ((adc_channels << ADC_CONFIG_CHANNELS_SHIFT) & ADC_CONFIG_CHANNELS_MASK);

    // 写入寄存器
    REG_WRITE(REG_ADC_CONFIG_OFFSET, current_config);
}

//---------------------------------------------
// 函数：设置本机IP地址及端口
//---------------------------------------------
void set_board_ip(uint32_t ip_addr) {
    REG_WRITE(REG_BOARD_IP_OFFSET, ip_addr);
//REG_WRITE(REG_ADC_TEST_OFFSET, ADC_BASE_ADDR +REG_BOARD_IP_OFFSET );

    xprintf("Board IP set to: %d.%d.%d.%d (0x%08X)\n",
           (ip_addr >> 24) & 0xFF, (ip_addr >> 16) & 0xFF,
           (ip_addr >> 8) & 0xFF, ip_addr & 0xFF, (unsigned int)ip_addr);
}
void set_board_port(uint32_t port) {
    REG_WRITE(REG_BOARD_PORT_OFFSET, port);
    xprintf("Board port set to: %d\n",port);
}
//---------------------------------------------
// 函数：设置目标IP地址及端口
//---------------------------------------------
void set_des_ip(uint32_t ip_addr) {
    REG_WRITE(REG_DES_IP_OFFSET, ip_addr);
     xprintf("Destination IP set to: %d.%d.%d.%d (0x%08X)\n",
           (ip_addr >> 24) & 0xFF, (ip_addr >> 16) & 0xFF,
           (ip_addr >> 8) & 0xFF, ip_addr & 0xFF, (unsigned int)ip_addr);
}

void set_des_port(uint32_t port) {
    REG_WRITE(REG_DES_PORT_OFFSET, port);
    xprintf("Board port set to: %d\n",port);
}
//---------------------------------------------
// 基准电压&&噪声 计算模块
//---------------------------------------------
// 从FPGA读取ADC通道数据（Verilog中需要写入ADC数据到该寄存器）
// 通用批量数据读写接口


// 通用批量数据读写（核心接口）

static void bulk_read(uint32_t base_addr, uint16_t* buffer, uint16_t count) {
    for (uint16_t i = 0; i < count; i++) {
	    if(DATAWIDTH<32)
        buffer[i] = (uint16_t)(REG_READ(base_addr + i*8) & (0xFFFFFFFF>>(32-ADCWIDTH)));
	    else{
		for(int j=0;j<ADCWIDTH>>5;j++){
		    buffer[i] += ((uint16_t)(REG_READ(base_addr + i*8)))<<(j*6);
				}
		}
    }
}

static void bulk_write(uint32_t base_addr, const uint16_t* buffer, uint16_t count) {

    for (uint16_t i = 0; i < count; i++) {
	     if(DATAWIDTH<32)
        REG_WRITE(base_addr + i*8, (buffer[i] & (0xFFFFFFFF>>(32-ADCWIDTH)) | ((i & 0xF) << ADCWIDTH)));
	else{
			for(int j=0;j<ADCWIDTH>>5;j++){
REG_WRITE(base_addr + i*8, (buffer[i]<<(j*6)));
			}
	}
    }
}

// 多通道基线电压和噪声计算
void calculate_baseline_voltage() {
    uint32_t sum[NUM_CHANNELS] = {0};
    uint32_t sum_sq[NUM_CHANNELS] = {0};
    uint16_t current_batch[NUM_CHANNELS];


    // 多轮采样
    for (int s = 0; s < SAMPLE_COUNT; ++s) {
        REG_WRITE(REG_SYS_STATUS_OFFSET, 6); // 触发采样
        REG_WRITE(REG_SYS_STATUS_OFFSET, 0);
       bulk_read(REG_ADC_DATA_OFFSET, current_batch, NUM_CHANNELS);
        bulk_write(REG_ADC_DATA_OFFSET,current_batch,NUM_CHANNELS);

        for (int ch = 0; ch < NUM_CHANNELS; ch++) {
            uint16_t val = current_batch[ch];
            xprintf("Signal@CH%d: %u\n", ch, val);
            if (val > SIGNAL_THRESH) {
             //   xprintf("Signal@CH%d: %u\n", ch, val);
                return ;
            }
            sum[ch] += val;
            sum_sq[ch] += (uint32_t)val * val;
        }
    }

    // 计算并存储各通道数据
    uint32_t global_sum = 0;
    for (int ch = 0; ch < NUM_CHANNELS; ch++) {
        baselines[ch] = sum[ch] / SAMPLE_COUNT;
        double variance = ((double)sum_sq[ch] - (double)sum[ch]*sum[ch]/SAMPLE_COUNT)/SAMPLE_COUNT;
        noises[ch] = (uint16_t)sqrt(variance);
      // noises[ch] =1234;
    }

    bulk_write(REG_ADC_BASELINE_OFFSET, baselines, NUM_CHANNELS);
    bulk_write(REG_ADC_NOISE_OFFSET, noises, NUM_CHANNELS);
    REG_WRITE(REG_SYS_STATUS_OFFSET, 3); 
   
}

// 簇处理
void process_clusters() {
    uint16_t raw_data[NUM_CHANNELS];
    uint16_t baselines[NUM_CHANNELS];
    uint16_t noises[NUM_CHANNELS];
    uint16_t processed_data[NUM_CHANNELS] = {0};

    // 批量读取原始数据
    REG_WRITE(REG_SYS_STATUS_OFFSET, 6); // 触发采样
    REG_WRITE(REG_SYS_STATUS_OFFSET, 0);
    bulk_read(REG_ADC_DATA_OFFSET, raw_data, NUM_CHANNELS);
   
    
    REG_WRITE(REG_SYS_STATUS_OFFSET, 4); // 开始处理

    // 簇检测与处理
    for (uint16_t ch = 0; ch < NUM_CHANNELS;) {
        uint16_t fire_th = baselines[ch] + CLUSTER_THRESH * noises[ch];
        uint16_t seed_th = baselines[ch] + SEED_THRESH * noises[ch];
        
        if (raw_data[ch] <= seed_th) { ch++; continue; }

        // 双向簇扩展
        uint16_t start = ch, end = ch;
        while (end+1 < NUM_CHANNELS && 
               raw_data[end+1] > baselines[end+1] + CLUSTER_THRESH * noises[end+1]) {
            end++;
        }
        while (start > 0 && 
               raw_data[start-1] > baselines[start-1] + CLUSTER_THRESH * noises[start-1]) {
            start--;
        }

        // 扣除对应基线
        for (int i = start; i <= end; i++) {
            processed_data[i] = raw_data[i] - baselines[i];
        }
        ch = end + 1;
    }

    // 批量写回处理结果
    bulk_write(REG_ADC_DATA_OFFSET, processed_data, NUM_CHANNELS);
    REG_WRITE(REG_SYS_STATUS_OFFSET, 5); // 处理完成
}

void ReadData() {
    uint32_t sum[NUM_CHANNELS] = {0};
    uint32_t sum_sq[NUM_CHANNELS] = {0};
    uint16_t current_batch[NUM_CHANNELS];

        REG_WRITE(REG_SYS_STATUS_OFFSET, 6); // 触发采样
        REG_WRITE(REG_SYS_STATUS_OFFSET, 0);
       bulk_read(REG_ADC_DATA_OFFSET, current_batch, NUM_CHANNELS);
        bulk_write(REG_ADC_DATA_OFFSET,current_batch,NUM_CHANNELS);
	bulk_write(REG_ADC_DATA_OFFSET,current_batch,NUM_CHANNELS);

        for (int ch = 0; ch < NUM_CHANNELS; ch++) {
            uint16_t val = current_batch[ch];
            xprintf("Signal@CH%d: %u\n", ch, val);}
}
//---------------------------------------------
// 主函数：PLL配置, IP修改, ADC采集
//---------------------------------------------
int main() {
   // uart_init(); // 初始化UART用于xprintf
    xprintf("\n--- System Initialization ---\n");
    //修改IP地址
   // xprintf("\n--- Configuring Network Settings ---\n");
    uint32_t new_board_ip = (192 << 24) | (168 << 16) | (185 << 8) | 111; // 192.168.185.111
    uint32_t new_des_ip   = (192 << 24) | (168 << 16) | (185<< 8) | 243;   // 192.168.185.243
    uint32_t new_board_port =1234;
    uint32_t new_des_port =1234;
    set_board_ip(new_board_ip);
    set_board_port(new_board_port);
    set_des_ip(new_des_ip);
    set_des_port(new_des_port);  

    // 3. 打开FIFO读取使能 (实际是FIFO写入使能)，并使能UDP发送
  //  xprintf("\n--- Enabling Data Acquisition and UDP Transmission ---\n");

    configure_udp_settings(1024, 1, 1); // 发送1024个数据点(32-bit words), 使能UDP发送, 使能FIFO写入
 //   configure_adc_settings(ADCWIDTH, DATAWIDTH, NUM_CHANNELS);
    REG_WRITE(REG_SYS_STATUS_OFFSET,1);
    // 读取UDP配置寄存器验证
   uint32_t udp_cfg_val = REG_READ(REG_UDP_CONFIG_OFFSET);
    xprintf("UDP Config Reg (0x%02X) read back: 0x%08X\n", (unsigned int)REG_UDP_CONFIG_OFFSET, (unsigned int)udp_cfg_val);
  //  xprintf("  TX Data Num: %u\n", (unsigned int)((udp_cfg_val & UDP_CONFIG_TX_DATA_NUM_MASK) >> UDP_CONFIG_TX_DATA_NUM_SHIFT));
        
    uint32_t loop_counter = 0;
  
  if(REG_READ(REG_SYS_STATUS_OFFSET)==2){
            REG_WRITE(REG_SYS_STATUS_OFFSET,2);//将状态输出到verilog
            xprintf("\n--- Measuring Baseline Voltage ---\n");
          calculate_baseline_voltage();
        }	  
       
    while (1) {
 
	REG_WRITE(REG_SYS_MODE_OFFSET,2);
        if(REG_READ(REG_SYS_STATUS_OFFSET) == 4) {
ReadData();
	//            process_clusters();
        }
        /*
        if ((loop_counter % 1000000) == 0) { // 每隔一段时间
            xprintf("Main loop heartbeat. Loop count: %u\n", (unsigned int)(loop_counter/1000000));
        }
    

        loop_counter++;*/
        // 简单的延时，避免CPU空转过快
        volatile int d = 100; while(d--);

    }

    return 0;
}




