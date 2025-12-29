#include <stdint.h>
#include "../include/uart.h"
#include "../include/xprintf.h"
//---------------------------------------------
// 寄存器基地址定义
//---------------------------------------------
#define PLL_BASE_ADDR  0x50000000

// 寄存器偏移（4字节对齐）
typedef enum {
    REG_DRP_ADDR   = 0x0,  // 设置 DRP 地址（drp_addr）
    REG_DRP_DATA   = 0x4,  // 触发 DRP 写操作（drp_di）
    REG_STATUS     = 0x8,  // 状态：drp_rdy(bit1), pll_locked(bit0)
    REG_PLL_RST    = 0xC,   // 控制 PLL 复位（pll_rst）
    FIFO_DATA      = 0x10, // FIFO 数据寄存器
    FIFO_STAT      = 0x14, // FIFO 状态寄存器
    ADC_TEST       = 0x1C, // 测试寄存器
} PLL_RegOffset;

#define STAT_FIFO_EMPTY 0x00000001

// 寄存器访问宏（volatile 确保编译器不优化）
#define REG_WRITE(offset, value) \
    (*(volatile uint32_t *)(PLL_BASE_ADDR + (offset)) = (value))

#define REG_READ(offset) \
    (*(volatile uint32_t *)(PLL_BASE_ADDR + (offset)))

// 状态寄存器掩码
#define STATUS_DRP_RDY    (1 << 1)  // bit1: drp_rdy
#define STATUS_PLL_LOCKED (1 << 0)  // bit0: pll_locked

//---------------------------------------------
// 函数：等待 DRP 操作完成
//---------------------------------------------
static void wait_drp_ready() {
    while ((REG_READ(REG_STATUS) & STATUS_DRP_RDY) == 0) {
        // 可选：添加超时检测，避免死循环
    }
}

//---------------------------------------------
// 函数：DRP 写操作（核心步骤）
//   - addr: DRP寄存器地址（7-bit，如0x14, 0x28等）
//   - data: 写入的数据（16-bit）
//---------------------------------------------
static void drp_write(uint8_t addr, uint16_t data) {
    // Step 1: 设置 DRP 地址
    REG_WRITE(REG_DRP_ADDR, addr);

    // Step 2: 写入数据并触发 DRP 写操作
    REG_WRITE(REG_DRP_DATA, data);

    // Step 3: 等待 DRP 操作完成
    wait_drp_ready();
}

//---------------------------------------------
// 函数：控制 PLL 复位
//   - assert: 1-复位，0-释放
//---------------------------------------------
static void pll_reset(int assert) {
    REG_WRITE(REG_PLL_RST, assert ? 1 : 0);
}


//---------------------------------------------
// 主函数：动态配置 PLL 频率
//---------------------------------------------
void pll_dynamic_config(uint16_t M, uint16_t D, uint16_t O) {
    // Step 1: 拉起 PLL 复位
    pll_reset(1);

    // Step 2: 写入 PowerReg (DRP地址0x28) 全1
    drp_write(0x28, 0xFFFF);  // 正确操作：先设地址0x28，再写数据0xFFFF

    // Step 5: 配置 DIVCLK Register (0x16)
    uint16_t DI = (1 << 6) | (1 << 0);
    drp_write(0x16, DI);      // 写入分频值 D

    // Step 3: 配置 CLKFBOUT Register 1 (0x14)
    // bit 12 必须为1
    drp_write(0x14, 0x1514);       // 写入倍频值 M

    // Step 4: 配置 CLKFBOUT Register 2 (0x15)
    drp_write(0x15, 0x0000); // 相位/延时配置（根据需求调整）


    // 08 09 为out1 register 1为分频，2为相位/边沿配置
    // bit 12 必须为1
    drp_write(0x08, 0x1104);     // 分频值 O（高8位可为相位）

    drp_write(0x09, 0x0000); // 相位/边沿配置（根据需求调整）

    // Step 8: 释放 PLL 复位
    pll_reset(0);

    // Step 9: 等待 PLL 锁定
    while ((REG_READ(REG_STATUS) & STATUS_PLL_LOCKED) == 0);
}

uint8_t adc_read_blocking(void) {
    // 等待FIFO非空
    while (REG_READ(FIFO_STAT) & STAT_FIFO_EMPTY){
//        REG_READ(FIFO_DATA);  // 触发 rd_en 拉高，推动 FIFO 输出
    }
    return REG_READ(FIFO_DATA) & 0xFF;  // 返回ADC数据
}


int main() {
//    uart_init();
    // 假设 M/D/O 已根据 DRP 格式转换（需参考 PLL 手册）
    uint16_t M = 0x0040;  // CLKFBOUT1 寄存器值（对应M=64）
    uint16_t D = 0x0001;  // DIVCLK 寄存器值（对应D=1）
    uint16_t O = 0x0008;  // ClkReg1 寄存器值（对应O=8）

    // 执行配置
    pll_dynamic_config(M, D, O);
xprintf("123");
    while ((REG_READ(REG_STATUS) & STATUS_PLL_LOCKED) == 0);

    xprintf("456");
    // 主循环采集数据
    while (1) {
        uint8_t adc_value = adc_read_blocking();
        xprintf("ADC Value: %u\n", adc_value+2);
//        xprintf("789");
    //    REG_WRITE(ADC_TEST, adc_value);
    }

    return 0;
}