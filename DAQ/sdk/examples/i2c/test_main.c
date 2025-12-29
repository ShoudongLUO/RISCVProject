#include "unity.h"
#include "mock_uart.h"
#include "mock_xprintf.h"
#include "main.c" // Include the source file for testing

void setUp(void) {
    // Initialize any test-specific setup
}

void tearDown(void) {
    // Clean up after each test
}

void test_i2c_init(void) {
    // Test initialization with valid clock and SCL frequencies
    i2c_init(50000000, 100000);
    TEST_ASSERT_EQUAL_HEX32(125, I2C_PRESCALE); // 50MHz / (4 * 100kHz) = 125

    // Test initialization with zero SCL frequency (should handle gracefully)
    i2c_init(50000000, 0);
    TEST_ASSERT_EQUAL_HEX32(0, I2C_PRESCALE);
}

void test_eeprom_write_byte(void) {
    // Test successful write operation
    eeprom_write_byte(0x1234, 0xAB);
    TEST_ASSERT_EQUAL_HEX32(0x53, I2C_SLAVE_ADDR);
    TEST_ASSERT_EQUAL_HEX32(0x1234, I2C_MEM_ADDR);
    TEST_ASSERT_EQUAL_HEX32(0xAB, I2C_DATA);
    TEST_ASSERT_EQUAL_HEX32(CMD_GO | CMD_WRITE, I2C_CMD);

    // Test NACK error detection
    I2C_STATUS = STATUS_ACK_ERROR;
    eeprom_write_byte(0x1234, 0xAB);
    TEST_ASSERT_EQUAL_HEX32(STATUS_ACK_ERROR, I2C_STATUS);
}

void test_eeprom_read_byte(void) {
    // Test successful read operation
    I2C_DATA = 0xCD; // Simulate read data
    uint8_t data = eeprom_read_byte(0x1234);
    TEST_ASSERT_EQUAL_HEX32(0x53, I2C_SLAVE_ADDR);
    TEST_ASSERT_EQUAL_HEX32(0x1234, I2C_MEM_ADDR);
    TEST_ASSERT_EQUAL_HEX32(CMD_GO | CMD_READ, I2C_CMD);
    TEST_ASSERT_EQUAL_HEX8(0xCD, data);

    // Test NACK error detection
    I2C_STATUS = STATUS_ACK_ERROR;
    data = eeprom_read_byte(0x1234);
    TEST_ASSERT_EQUAL_HEX8(0xFF, data);
}

int main(void) {
    UNITY_BEGIN();
    RUN_TEST(test_i2c_init);
    RUN_TEST(test_eeprom_write_byte);
    RUN_TEST(test_eeprom_read_byte);
    return UNITY_END();
}