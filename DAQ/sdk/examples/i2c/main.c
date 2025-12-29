#include <stdint.h>
#include "../../bsp/include/uart.h"
#include "../../bsp/include/xprintf.h"

// ===================================================================
// == THE CRITICAL FIX: Base address updated to the correct value   ==
// ===================================================================
#define I2C_MASTER_BASE_ADDR 0x50000000

#define I2C_REG_PRESCALE   0x00
#define I2C_REG_CMD        0x04
#define I2C_REG_SLAVE_ADDR 0x08
#define I2C_REG_MEM_ADDR   0x0C
#define I2C_REG_DATA       0x10
#define I2C_REG_STATUS     0x20

#define I2C_PRESCALE   (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_PRESCALE))
#define I2C_CMD        (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_CMD))
#define I2C_SLAVE_ADDR (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_SLAVE_ADDR))
#define I2C_MEM_ADDR   (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_MEM_ADDR))
#define I2C_DATA       (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_DATA))
#define I2C_STATUS     (*(volatile uint32_t *)(I2C_MASTER_BASE_ADDR + I2C_REG_STATUS))

#define CMD_GO    (1 << 31)
#define CMD_WRITE (1 << 30)
#define CMD_READ  (1 << 29)
#define STATUS_BUSY      (1 << 0)
#define STATUS_ACK_ERROR (1 << 1)

void delay_ms(volatile uint32_t ms) { for (uint32_t i = 0; i < ms; ++i) for (volatile uint32_t j = 0; j < 5000; ++j); }

void i2c_init(uint32_t f_clk, uint32_t f_scl) {
    while(I2C_STATUS & STATUS_BUSY);
    I2C_PRESCALE = f_clk / (4 * f_scl);
}

#define EEPROM_SLAVE_ADDR 0x53 // The address you confirmed works

void eeprom_write_byte(uint16_t mem_addr, uint8_t data) {
    xprintf("[I2C] Write: Addr=0x%04X Data=0x%02X\n", mem_addr, data);
    while(I2C_STATUS & STATUS_BUSY);

    // Phase 1: Configure
    I2C_SLAVE_ADDR = EEPROM_SLAVE_ADDR;
    I2C_MEM_ADDR   = mem_addr;
    I2C_DATA       = data;

    // Optional but recommended: A quick readback to confirm writes were received
    xprintf("  > Config Check: Slave=0x%X, Addr=0x%X, Data=0x%X\n", (uint8_t)I2C_SLAVE_ADDR, (uint16_t)I2C_MEM_ADDR, (uint8_t)I2C_DATA);

    // Phase 2: Execute
    I2C_CMD = CMD_GO | CMD_WRITE;

    while(I2C_STATUS & STATUS_BUSY);
    if (I2C_STATUS & STATUS_ACK_ERROR) {
        xprintf("[I2C] ERROR: NACK detected during write!\n");
    }
}

uint8_t eeprom_read_byte(uint16_t mem_addr) {
    xprintf("[I2C] Read: Addr=0x%04X\n", mem_addr);
    while(I2C_STATUS & STATUS_BUSY);

    // Phase 1: Configure
    I2C_SLAVE_ADDR = EEPROM_SLAVE_ADDR;
    I2C_MEM_ADDR   = mem_addr;

    // Phase 2: Execute
    I2C_CMD = CMD_GO | CMD_READ;

    while(I2C_STATUS & STATUS_BUSY);
    if (I2C_STATUS & STATUS_ACK_ERROR) {
        xprintf("[I2C] ERROR: NACK detected during read!\n");
        return 0xFF;
    }
    return (uint8_t)I2C_DATA;
}

int main() {
    uart_init();
    xprintf("\n=== I2C Master Final Test Program ===\n");
    i2c_init(50000000, 100000);

    uint16_t test_addr = 0x1234;
    uint8_t test_data  = 0xAC;

    eeprom_write_byte(test_addr, test_data);
    uint8_t read_back = eeprom_read_byte(test_addr);

    xprintf("[I2C] Verification: Wrote 0x%02X, Read back 0x%02X\n", test_data, read_back);
    if (read_back == test_data) {
        xprintf("[I2C] SUCCESS!\n");
    } else {
        xprintf("[I2C] FAILURE!\n");
    }

    while(1);
    return 0;
}