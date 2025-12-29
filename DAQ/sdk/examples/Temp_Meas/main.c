#include <stdint.h>
#include <stdio.h>
#include <math.h>

// Assume these header files provide uart_init() and xprintf()
#include "../../bsp/include/uart.h"
#include "../../bsp/include/xprintf.h"

//---------------------------------------------
// Global ADC Constants
//---------------------------------------------
#define ADCWIDTH 12         // Actual ADC bit width (used as a mask for bulk_read/write)
#define NUM_VT_CHANNELS 2   // Number of Voltage/Temperature channels: 0=Volt, 1=Temp

//---------------------------------------------
// Register Base Address Definition
//---------------------------------------------
#define FPGA_REG_BASE_ADDR 0x70000000

// REG_UDP_CONFIG_OFFSET 位掩码和移位
#define UDP_CONFIG_TX_DATA_NUM_MASK   (0x0000FFFF)
#define UDP_CONFIG_TX_DATA_NUM_SHIFT  (0)
#define UDP_CONFIG_UDP_TX_ENABLE_MASK (1 << 16)
#define UDP_CONFIG_UDP_TX_ENABLE_SHIFT (16)
#define UDP_CONFIG_FIFO_WR_EN_MASK    (1 << 17)
#define UDP_CONFIG_FIFO_WR_EN_SHIFT   (17)

// Register Offsets (4-byte aligned)
typedef enum {
    // 新增/修改的寄存器定义
    REG_UDP_CONFIG_OFFSET = 0x10,  // W/R: [17]=fifo_wr_en, [16]=udp_tx_enable, [15:0]=tx_data_num
    REG_BOARD_IP_OFFSET   = 0x14,  // W/R: 本机IP地址
    REG_DES_IP_OFFSET     = 0x18,  // W/R: 目标IP地址
    REG_BOARD_PORT_OFFSET = 0x1C,  // W/R: 本机端口
    REG_DES_PORT_OFFSET   = 0x20,  //目标端口 
    REG_ADC_CONFIG_OFFSET = 0x24, // ADC Configuration
    REG_SYS_STATUS_OFFSET = 0x28, // System Status
    REG_SYS_MODE_OFFSET   = 0x30, // System Mode Control

    // Voltage/Temperature Data and Thresholds
    REG_VOLT_THRESH_OFFSET = 0x3C, // W/R: Voltage threshold (exceeding this value triggers a warning/control)
    REG_TEMP_THRESH_OFFSET = 0x40, // W/R: Temperature threshold (exceeding this value triggers a warning/control)

    // Bulk Data Offset
    REG_VT_DATA_OFFSET = 0x1000,
	     REG_ADC_BASELINE_OFFSET=0x2000
} FpgaRegOffset;

//---------------------------------------------
// Register Access Macros
//---------------------------------------------
#define REG_WRITE(offset, value) \
    (*(volatile uint32_t *)(FPGA_REG_BASE_ADDR + (offset)) = (value))

#define REG_READ(offset) \
    (*(volatile uint32_t *)(FPGA_REG_BASE_ADDR + (offset)))

//---------------------------------------------
// Generic Bulk Data Read/Write (Core Interface)
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
}
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
// Bulk read data from FPGA to a buffer and apply the ADCWIDTH mask
static void bulk_read(uint32_t base_addr, uint16_t* buffer, uint16_t count) {
    for (uint16_t i = 0; i < count; i++) {
        // base_addr + i*8 matches the 8-byte stride register access pattern
        buffer[i] = (uint16_t)(REG_READ(base_addr + i*8) & (0xFFFF>>(16-ADCWIDTH)));
    }
}

// Bulk write data from a buffer to the FPGA, including the channel ID (i)
static void bulk_write(uint32_t base_addr, const uint16_t* buffer, uint16_t count) {
    for (uint16_t i = 0; i < count; i++) {
        // Write data (lower bits) and add the channel ID (upper bits 12-15)
        REG_WRITE(base_addr + i*8, (buffer[i] & (0xFFFF>>(16-ADCWIDTH)) | ((i & 0xF) << 12)));
    }
}

//---------------------------------------------
// Control Command Definitions (written to REG_SYS_STATUS_OFFSET)
//---------------------------------------------
#define CTRL_CMD_NORMAL           0x00000010 // Normal operation (default)
#define CTRL_CMD_TEMP_ULTRAL_HIGH 0x00000011 // Temperature too high:
#define CTRL_CMD_TEMP_HIGH        0x00000012 // Temperature high:
#define CTRL_CMD_VOLT_ADJ         0x00000014 // Voltage anomaly: Request power adjustment
#define CTRL_CMD_SHUTDOWN         0x00000018 // Severe anomaly: Emergency shutdown

//---------------------------------------------
// Default Thresholds and System Parameters
//---------------------------------------------
#define DEFAULT_TEMP_THRESH 250  // 70.00 degrees Celsius
#define DEFAULT_VOLT_THRESH 3400  // 3400 mV (e.g., for a 3.3V domain, the threshold is set to 3.4V)

// V/T sample count 
#define VT_SAMPLE_COUNT 16        // Voltage/Temperature sample count

//---------------------------------------------
// Function: Initialize thresholds and control registers
//---------------------------------------------
void initialize_thresholds() {
    // Set default voltage threshold
    REG_WRITE(REG_VOLT_THRESH_OFFSET, DEFAULT_VOLT_THRESH);
    xprintf("Volt Threshold set to: %u mV\n", (unsigned int)DEFAULT_VOLT_THRESH);

    // Set default temperature threshold
    REG_WRITE(REG_TEMP_THRESH_OFFSET, DEFAULT_TEMP_THRESH);
    xprintf("Temp Threshold set to: %u (x0.01C)\n", (unsigned int)DEFAULT_TEMP_THRESH);

    // Initialize control output to normal
    REG_WRITE(REG_SYS_STATUS_OFFSET, CTRL_CMD_NORMAL);
    xprintf("Control Output initialized to: NORMAL (0x%X)\n", (unsigned int)CTRL_CMD_NORMAL);
}

//---------------------------------------------
// Function: Read, check, and control
//---------------------------------------------
void measure_check_and_control() {
    // Use a 32-bit accumulator to prevent overflow from 16 samples
    uint32_t temp_sum = 0;
    uint32_t volt_sum = 0;
    uint16_t current_batch[NUM_VT_CHANNELS]; // [0]=Volt,[1],=Temp
 uint16_t Average_batch[NUM_VT_CHANNELS];
    // 1. **Multi-round sampling and averaging**
    for (int s = 0; s < VT_SAMPLE_COUNT; ++s) {
        // Trigger hardware sampling
        REG_WRITE(REG_SYS_STATUS_OFFSET, 6);
        REG_WRITE(REG_SYS_STATUS_OFFSET, 0);

        // Bulk read V/T data (reading 2 channels starting from REG_VT_DATA_OFFSET)
        bulk_read(REG_VT_DATA_OFFSET, current_batch, NUM_VT_CHANNELS);

        // Accumulate values
        volt_sum += current_batch[0]; // Channel 0: Voltage
        temp_sum += current_batch[1]; // Channel 1: Temperature
    }

    // Calculate average values
    uint32_t current_volt_avg = volt_sum / VT_SAMPLE_COUNT;
    uint32_t current_temp_avg = temp_sum / VT_SAMPLE_COUNT;
Average_batch[0]=current_volt_avg;
Average_batch[1]=current_volt_avg;
    // Read the currently set thresholds from the registers
uint32_t temp_thresh = DEFAULT_TEMP_THRESH;
uint32_t volt_thresh = DEFAULT_VOLT_THRESH;
    //uint32_t temp_thresh = REG_READ(REG_TEMP_THRESH_OFFSET);
    //uint32_t volt_thresh = REG_READ(REG_VOLT_THRESH_OFFSET);
    uint32_t control_command = CTRL_CMD_NORMAL;

    // 2. **Voltage Check**
    if (current_volt_avg > volt_thresh) {
        // Voltage exceeded (e.g., voltage too high)
        xprintf("[WARNING] Voltage Exceeded! AVG %u mV > THRESH %u mV\n", (unsigned int)current_volt_avg, (unsigned int)volt_thresh);
        control_command |= CTRL_CMD_VOLT_ADJ; // Request power adjustment
    }

    // 3. **Temperature Check**
    if (current_temp_avg > temp_thresh) {
        // Temperature exceeded (over 70.00°C)
        xprintf("[CRITICAL] Temperature Overheat! AVG %u (x0.01C) > THRESH %u (x0.01C)\n", (unsigned int)current_temp_avg, (unsigned int)temp_thresh);
        control_command |= CTRL_CMD_TEMP_ULTRAL_HIGH;

        // Add a secondary severe threshold check (e.g., emergency shutdown if it exceeds 85.00°C)
        if (current_temp_avg > (temp_thresh + 150)) { // 85.00°C
            xprintf("[EMERGENCY] Severe Overheat! Initiating Shutdown.\n");
            control_command |= CTRL_CMD_SHUTDOWN;
        }
    } else if (current_temp_avg > (temp_thresh * 0.8)) {
        // Approaching threshold (e.g., 56.00°C)
        xprintf("[INFO] Temp approaching threshold: %u (x0.01C)\n", (unsigned int)current_temp_avg);
        control_command |= CTRL_CMD_TEMP_HIGH;
    }

    // 4. **Execute Control Command**
    /*
    // Prioritize executing the shutdown command (if set)
    if (control_command & CTRL_CMD_SHUTDOWN) {
        REG_WRITE(REG_SYS_STATUS_OFFSET, CTRL_CMD_SHUTDOWN);
        xprintf("Control Action: SYSTEM SHUTDOWN (0x%X)\n", (unsigned int)CTRL_CMD_SHUTDOWN);
    }*/
 //bulk_write(REG_ADC_BASELINE_OFFSET, Average_batch, 2);
    // If not shutting down, write other control commands
    if (control_command != CTRL_CMD_NORMAL) {
        REG_WRITE(REG_SYS_STATUS_OFFSET, control_command);
        xprintf("Control Action: Adjustments Applied (0x%X)\n", (unsigned int)control_command);
    } else {
        // Ensure the control register is kept at the normal value during normal state
        REG_WRITE(REG_SYS_STATUS_OFFSET, CTRL_CMD_NORMAL);
    }
        REG_WRITE(REG_SYS_STATUS_OFFSET, control_command);
    xprintf("--- AVG V: %u mV, AVG T: %u (x0.01C). Next check...\n\n", (unsigned int)current_volt_avg, (unsigned int)current_temp_avg);
}

//---------------------------------------------
// Main function: System initialization and measurement loop
//---------------------------------------------
int main() {
    // 1. Initialize UART
   // uart_init();
    xprintf("\n--- FPGA Monitoring System Start ---\n");

    // 2. Write initial thresholds
    initialize_thresholds();
     uint32_t new_board_ip = (192 << 24) | (168 << 16) | (185 << 8) | 111; // 192.168.185.111
    uint32_t new_des_ip   = (192 << 24) | (168 << 16) | (185<< 8) | 243;   // 192.168.185.243
    uint32_t new_board_port =1234;
    uint32_t new_des_port =1234;
    set_board_ip(new_board_ip);
    set_board_port(new_board_port);
    set_des_ip(new_des_ip);
    set_des_port(new_des_port);  
     configure_udp_settings(1024, 1, 1);
     REG_WRITE(REG_SYS_STATUS_OFFSET,1);
    // 3. Simulate entering measurement mode
    REG_WRITE(REG_SYS_STATUS_OFFSET, 2); // Assume 2: Start Measure Mode
    uint32_t loop_counter = 0;

    // 4. Main monitoring loop
    while (1) {
        // Simulate hardware measurement and execute control logic
        measure_check_and_control();
        
        // Simple delay to determine sampling frequency
        volatile int d = 500000;
        while(d--);
        loop_counter++;
    }
    return 0;
}
