#include <stdint.h>
#include "../include/uart.h"   // 假设 uart_init() 和 xprintf() 在这里
#include "../include/xprintf.h" // 假设 xprintf() 在这里

//---------------------------------------------
// 寄存器基地址定义
//---------------------------------------------
#define FPGA_CTRL_BASE_ADDR  0x50000000 // 改个更通用的名字

// 寄存器偏移（4字节对齐）
typedef enum {
    REG_DRP_ADDR_OFFSET   = 0x00,  // W: 设置 DRP 目标地址 (Verilog: drp_addr)
                                 // R: 读回 DRP 目标地址
    REG_DRP_DATA_OFFSET   = 0x04,  // W: 写入 DRP 数据并触发DRP写 (Verilog: drp_di, drp_we, drp_en)
                                 // R: 读回 DRP DO (Verilog: drp_do) - 注意Verilog中此地址用于读drp_do
    REG_STATUS_OFFSET     = 0x08,  // W: (可选，如果写此地址也触发DRP读)
                                 // R: 状态: drp_rdy(bit1), pll_locked(bit0) (Verilog: drp_rdy_latched, pll_locked)
                                 //    Verilog中写此地址会触发一次DRP读 (drp_en=1, drp_we=0)
    REG_PLL_RST_OFFSET    = 0x0C,  // W/R: 控制/读取 PLL 复位状态 (Verilog: pll_rst)

    // 新增/修改的寄存器定义
    REG_UDP_CONFIG_OFFSET = 0x10,  // W/R: [17]=fifo_wr_en, [16]=udp_tx_enable, [15:0]=tx_data_num
    REG_BOARD_IP_OFFSET   = 0x14,  // W/R: 本机IP地址
    REG_DES_IP_OFFSET     = 0x18,  // W/R: 目标IP地址
    REG_ADC_TEST_OFFSET   = 0x1C   // W/R: 测试寄存器 (Verilog: adc_test)

    // YUXIN_COMMENT: 原来的 FIFO_DATA 和 FIFO_STAT 宏与Verilog的REG_UDP_CONFIG功能重叠或不同
    // 我们现在使用 REG_UDP_CONFIG 来控制FIFO写使能。
    // 如果需要直接读写FIFO数据或状态（绕过UDP），Verilog中需要单独实现这些地址的逻辑。
    // 目前Verilog中没有直接读写FIFO数据和状态的地址（0x10, 0x14被新功能占用）

} FpgaRegOffset;

// 寄存器访问宏
#define REG_WRITE(offset, value) \
    (*(volatile uint32_t *)(FPGA_CTRL_BASE_ADDR + (offset)) = (value))

#define REG_READ(offset) \
    (*(volatile uint32_t *)(FPGA_CTRL_BASE_ADDR + (offset)))

// REG_STATUS_OFFSET 状态位掩码
#define STATUS_DRP_RDY_MASK    (1 << 1)  // bit1: drp_rdy
#define STATUS_PLL_LOCKED_MASK (1 << 0)  // bit0: pll_locked

// REG_UDP_CONFIG_OFFSET 位掩码和移位
#define UDP_CONFIG_TX_DATA_NUM_MASK   (0x0000FFFF)
#define UDP_CONFIG_TX_DATA_NUM_SHIFT  (0)
#define UDP_CONFIG_UDP_TX_ENABLE_MASK (1 << 16)
#define UDP_CONFIG_UDP_TX_ENABLE_SHIFT (16)
#define UDP_CONFIG_FIFO_WR_EN_MASK    (1 << 17)
#define UDP_CONFIG_FIFO_WR_EN_SHIFT   (17)


//---------------------------------------------
// 函数：等待 DRP 操作完成
//---------------------------------------------
static void wait_drp_ready() {
    // 触发一次DRP读操作 (Verilog中写此地址会触发 drp_en=1, drp_we=0)
    // 这一步是为了确保最新的drp_rdy状态能被锁存到drp_rdy_latched
    // 如果Verilog中写DRP_DATA后drp_rdy会自动更新并锁存，则此步可能非必需，
    // 但为了保险起见，在轮询前触发一次读。
    REG_WRITE(REG_STATUS_OFFSET, 0); // 写任意值到状态寄存器以触发DRP读

    uint32_t timeout = 100000; // 简单的超时计数器
    while ((REG_READ(REG_STATUS_OFFSET) & STATUS_DRP_RDY_MASK) == 0) {
        if (--timeout == 0) {
            xprintf("Error: DRP ready timeout!\n");
            break;
        }
    }
    // 读取REG_STATUS_OFFSET会清除Verilog中的drp_rdy_latched位
}

//---------------------------------------------
// 函数：DRP 写操作
//---------------------------------------------
static void drp_write_reg(uint8_t drp_reg_addr, uint16_t data) {
    // Step 1: 设置 DRP 目标地址
    REG_WRITE(REG_DRP_ADDR_OFFSET, drp_reg_addr);

    // Step 2: 写入数据并触发 DRP 写操作
    REG_WRITE(REG_DRP_DATA_OFFSET, data);

    // Step 3: 等待 DRP 操作完成 (DRP_RDY变为高，然后读取状态寄存器后清零)
    wait_drp_ready();
}

//---------------------------------------------
// 函数：DRP 读操作 (如果需要从特定DRP地址读回数据)
// 返回16位数据
//---------------------------------------------
static uint16_t drp_read_reg(uint8_t drp_reg_addr) {
    // Step 1: 设置 DRP 目标地址
    REG_WRITE(REG_DRP_ADDR_OFFSET, drp_reg_addr);

    // Step 2: 触发 DRP 读操作 (通过写 REG_STATUS_OFFSET, Verilog中会设置 drp_en=1, drp_we=0)
    REG_WRITE(REG_STATUS_OFFSET, 0); // Value doesn't matter for triggering read

    // Step 3: 等待 DRP 操作完成
    wait_drp_ready(); // DRP_RDY 变为高

    // Step 4: 从 REG_DRP_DATA_OFFSET 读取数据 (Verilog 中 drp_do 连接到此地址的读)
    return (uint16_t)(REG_READ(REG_DRP_DATA_OFFSET) & 0xFFFF);
}


//---------------------------------------------
// 函数：控制 PLL 复位
//---------------------------------------------
static void pll_set_reset(int assert_reset) {
    REG_WRITE(REG_PLL_RST_OFFSET, assert_reset ? 1 : 0);
}

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

//---------------------------------------------
// 函数：设置本机IP地址
//---------------------------------------------
void set_board_ip(uint32_t ip_addr) {
    REG_WRITE(REG_BOARD_IP_OFFSET, ip_addr);
    xprintf("Board IP set to: %d.%d.%d.%d (0x%08X)\n",
           (ip_addr >> 24) & 0xFF, (ip_addr >> 16) & 0xFF,
           (ip_addr >> 8) & 0xFF, ip_addr & 0xFF, (unsigned int)ip_addr);
}

//---------------------------------------------
// 函数：设置目标IP地址
//---------------------------------------------
void set_des_ip(uint32_t ip_addr) {
    REG_WRITE(REG_DES_IP_OFFSET, ip_addr);
     xprintf("Destination IP set to: %d.%d.%d.%d (0x%08X)\n",
           (ip_addr >> 24) & 0xFF, (ip_addr >> 16) & 0xFF,
           (ip_addr >> 8) & 0xFF, ip_addr & 0xFF, (unsigned int)ip_addr);
}

//---------------------------------------------
// 主函数：PLL配置, IP修改, ADC采集
//---------------------------------------------
void pll_dynamic_config_example(uint16_t M_val, uint16_t D_val, uint16_t O_val) {
    // (你的原始PLL配置代码基本可以保留，只需将drp_write改为drp_write_reg, pll_reset改为pll_set_reset)
    xprintf("Starting PLL dynamic configuration...\n");

    // Step 1: 拉起 PLL 复位
    pll_set_reset(1);
    xprintf("PLL Reset Asserted.\n");

    // Step 2: 写入 PowerReg (DRP地址0x28) 全1
    drp_write_reg(0x28, 0xFFFF);
    xprintf("DRP 0x28 (PowerReg) written with 0xFFFF.\n");

    // Step 5: 配置 DIVCLK Register (0x16) for D_val
    // 假设 D_val 是已经格式化好的值
    drp_write_reg(0x16, D_val);
    xprintf("DRP 0x16 (DIVCLK) written with 0x%04X.\n", D_val);

    // Step 3: 配置 CLKFBOUT Register 1 (0x14) for M_val
    // 假设 M_val 是已经格式化好的值
    drp_write_reg(0x14, M_val);
    xprintf("DRP 0x14 (CLKFBOUT1) written with 0x%04X.\n", M_val);

    // Step 4: 配置 CLKFBOUT Register 2 (0x15)
    drp_write_reg(0x15, 0x0000); // 根据需要调整
    xprintf("DRP 0x15 (CLKFBOUT2) written with 0x0000.\n");

    // 配置 CLKOUT0 Register 1 (0x08) for O_val
    // 假设 O_val 是已经格式化好的值
    drp_write_reg(0x08, O_val);
    xprintf("DRP 0x08 (CLKOUT0_1) written with 0x%04X.\n", O_val);

    // 配置 CLKOUT0 Register 2 (0x09)
    drp_write_reg(0x09, 0x0000); // 根据需要调整
    xprintf("DRP 0x09 (CLKOUT0_2) written with 0x0000.\n");

    // Step 8: 释放 PLL 复位
    pll_set_reset(0);
    xprintf("PLL Reset De-asserted.\n");

    // Step 9: 等待 PLL 锁定
    xprintf("Waiting for PLL lock...\n");
    uint32_t timeout = 1000000; // 增加超时值
    while ((REG_READ(REG_STATUS_OFFSET) & STATUS_PLL_LOCKED_MASK) == 0) {
         if (--timeout == 0) {
            xprintf("Error: PLL lock timeout!\n");
            break;
        }
    }
    if (timeout > 0) {
        xprintf("PLL Locked!\n");
    }
}

// YUXIN_COMMENT: 原始的 adc_read_blocking 函数依赖于 FIFO_STAT 和 FIFO_DATA 宏。
// Verilog 中没有实现独立的 FIFO 状态和数据寄存器。
// ADC 数据现在通过 UDP 发送。如果需要CPU直接读 ADC 数据（例如用于测试），
// 则需要在 Verilog 中为 ADC_TEST 寄存器实现数据捕获逻辑，或者
// 实现一个简单的 FIFO 读接口给 CPU（但这会与UDP的FIFO读取冲突）。
// 假设这里的目标是启动UDP发送，而不是CPU直接读ADC值。

int main() {
    uart_init(); // 初始化UART用于xprintf
    xprintf("\n--- System Initialization ---\n");

    // 1. PLL动态配置 (使用示例值，请根据你的PLL手册调整M,D,O的实际DRP寄存器值)
    // 假设这些值是已经根据DRP手册格式化好的
    // 例如，对于Xilinx 7系列MMCM:
    // M (CLKFBOUT_MULT_F): 0x14 -> CLKFBOUT_MULT (float, e.g., 10.125 requires specific bit encoding)
    // D (DIVCLK_DIVIDE):   0x16 -> DIVCLK_DIVIDE (integer, e.g., 1)
    // O (CLKOUT0_DIVIDE_F):0x08 -> CLKOUT0_DIVIDE (float, e.g., 5.0625 requires specific bit encoding)
    // 这些值通常不是直接的 M, D, O 整数，而是编码后的。
    // 你的原始代码用了：M = 0x0040 (for 0x14), D = 0x0001 (for 0x16), O = 0x0008 (for 0x08)
    // 我们将沿用这些值，但请确认它们对于你的PLL是正确的DRP配置值。
    // 你的原始drp_write(0x16, DI) DI=(1<<6)|(1<<0) = 0x41. D=0x0001可能不对。
    // drp_write(0x14, 0x1514) -> M
    // drp_write(0x08, 0x1104) -> O
    pll_dynamic_config_example(0x1514, 0x0041, 0x1104); // 使用你原始代码中的值

    // 等待PLL稳定
    volatile int delay_count = 100000;
    while(delay_count--);
    xprintf("Initial delay after PLL config complete.\n");


    // 2. 尝试修改IP地址
    xprintf("\n--- Configuring Network Settings ---\n");
    uint32_t new_board_ip = (192 << 24) | (168 << 16) | (1 << 8) | 111; // 192.168.1.111
    uint32_t new_des_ip   = (192 << 24) | (168 << 16) | (1 << 8) | 222;   // 192.168.1.222

    set_board_ip(new_board_ip);
    set_des_ip(new_des_ip);

    // 可以通过读取寄存器来验证 (可选)
    uint32_t read_board_ip = REG_READ(REG_BOARD_IP_OFFSET);
    uint32_t read_des_ip = REG_READ(REG_DES_IP_OFFSET);
    xprintf("Read back Board IP: 0x%08X\n", (unsigned int)read_board_ip);
    xprintf("Read back Dest IP:  0x%08X\n", (unsigned int)read_des_ip);


    // 3. 打开FIFO读取使能 (实际是FIFO写入使能)，并使能UDP发送
    xprintf("\n--- Enabling Data Acquisition and UDP Transmission ---\n");
    // 参数: tx_data_num, udp_tx_enable, fifo_wr_enable
    configure_udp_settings(1024, 1, 1); // 发送1024个数据点(32-bit words), 使能UDP发送, 使能FIFO写入

    // 读取UDP配置寄存器验证
    uint32_t udp_cfg_val = REG_READ(REG_UDP_CONFIG_OFFSET);
    xprintf("UDP Config Reg (0x%02X) read back: 0x%08X\n", (unsigned int)REG_UDP_CONFIG_OFFSET, (unsigned int)udp_cfg_val);
    xprintf("  TX Data Num: %u\n", (unsigned int)((udp_cfg_val & UDP_CONFIG_TX_DATA_NUM_MASK) >> UDP_CONFIG_TX_DATA_NUM_SHIFT));
    xprintf("  UDP TX Enable: %d\n", (udp_cfg_val & UDP_CONFIG_UDP_TX_ENABLE_MASK) ? 1 : 0);
    xprintf("  FIFO WR Enable: %d\n", (udp_cfg_val & UDP_CONFIG_FIFO_WR_EN_MASK) ? 1 : 0);


    xprintf("\n--- System Running ---\n");
    // 主循环 - CPU现在不直接读取ADC数据，而是让FPGA通过UDP发送
    // 如果需要监控，可以读取一些状态寄存器或测试寄存器
    uint32_t loop_counter = 0;
    while (1) {
        // 例如，周期性地打印一条消息或检查某个状态
        if ((loop_counter % 1000000) == 0) { // 每隔一段时间
            xprintf("Main loop heartbeat. Loop count: %u\n", (unsigned int)(loop_counter/1000000));
            // 可以读取 REG_ADC_TEST_OFFSET 如果Verilog中实现了ADC数据写入该测试寄存器
            // uint32_t test_val = REG_READ(REG_ADC_TEST_OFFSET);
            // xprintf("ADC Test Reg: 0x%08X\n", test_val);
        }
        loop_counter++;
        // 简单的延时，避免CPU空转过快
        volatile int d = 100; while(d--);
    }

    return 0;
}