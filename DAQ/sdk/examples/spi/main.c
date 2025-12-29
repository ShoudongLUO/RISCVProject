#include <stdint.h>
#include <string.h> // For using memset() and memcmp()
#include "../../bsp/include/uart.h"
#include "../../bsp/include/xprintf.h"

// Include our unified SPI driver header
#include "../../bsp/include/spi.h"

/* =============================================================================
 *                  APPLICATION-LEVEL HARDWARE CONFIGURATION
 * =============================================================================
 *  Description:
 *      Define which SPI channel (CS line) each physical device is connected to.
 *      If you change your hardware wiring, this is the only place you need
 *      to update the configuration.
 * =============================================================================
 */
#define MY_FLASH_CHIP_SPI_CHANNEL    0  // W25Q64 Flash chip is connected to CS0
#define MY_SD_CARD_SPI_CHANNEL       1  // SD Card is connected to CS1


/* =============================================================================
 *                      W25Q64 Test Function
 * =============================================================================
 */
void test_w25q64_flash(void) {
    xprintf("\n----------------------------------------\n");
    xprintf("--- Running W25Q64 Flash Memory Test ---\n");
    xprintf("----------------------------------------\n");

    // Step 1: Check if the chip is present by reading its JEDEC ID.
    // This is a great first step to verify basic communication.
    w25q64_read_jedec_id();

    // Step 2: Prepare data for a write/read test.
    const uint32_t test_address = 0x001000; // Use an arbitrary address for testing (e.g., 4KB offset)
    const uint16_t data_len = 32;
    uint8_t write_buffer[data_len];
    uint8_t read_buffer[data_len];
    
    // Create some test data
    for (int i = 0; i < data_len; i++) {
        write_buffer[i] = (uint8_t)(i + 0x30); // Fill with '0', '1', '2', ...
    }
    // Clear the read buffer to ensure we are not reading old data from memory
    memset(read_buffer, 0, data_len);

    // Step 3: Erase the sector where we plan to write.
    // Flash memory must be erased (all bits set to 1) before it can be programmed (bits set to 0).
    xprintf("1. Erasing 4KB sector at address 0x%06X...\n", test_address);
    w25q64_sector_erase(test_address);
    xprintf("   > Erase command sent. Waiting for completion...\n");
    // The driver's erase function includes a wait for the busy flag, so it blocks until done.
    xprintf("   > Erase complete.\n");

    // Step 4: Write the test data to the flash memory.
    xprintf("2. Writing %d bytes to address 0x%06X...\n", data_len, test_address);
    w25q64_page_program(test_address, write_buffer, data_len);
    xprintf("   > Write complete.\n");

    // Step 5: Read the data back from the same location.
    xprintf("3. Reading %d bytes from address 0x%06X...\n", data_len, test_address);
    w25q64_read_data(test_address, read_buffer, data_len);
    xprintf("   > Read complete.\n");
    
    // Step 6: Verify if the data read back matches the data that was written.
    xprintf("4. Verifying data...\n");
    if (memcmp(write_buffer, read_buffer, data_len) == 0) {
        xprintf("\n[SUCCESS] W25Q64 test passed! Data matches.\n");
    } else {
        xprintf("\n[FAILURE] W25Q64 test failed! Data mismatch detected.\n");
        // Print out the buffers to see the difference
        xprintf("   Wrote -> ");
        for(int i=0; i<data_len; ++i) xprintf("%02X ", write_buffer[i]);
        xprintf("\n   Read  -> ");
        for(int i=0; i<data_len; ++i) xprintf("%02X ", read_buffer[i]);
        xprintf("\n");
    }
}


/* =============================================================================
 *                      SD Card Test Function
 * =============================================================================
 */
void test_sd_card(void) {
    xprintf("\n-----------------------------------\n");
    xprintf("--- Running SD Card Test (SPI) ---\n");
    xprintf("-----------------------------------\n");

    // Step 1: Check if the SD card was initialized successfully in main().
    if (!sd_card_is_initialized()) {
        xprintf("[SKIPPED] SD Card was not initialized. Halting test.\n");
        return;
    }

    // Step 2: Prepare a full 512-byte block of data for writing.
    const uint32_t test_block_addr = 1000; // Use a high block number to avoid overwriting filesystem data
    uint8_t write_block[SD_BLOCK_SIZE];
    uint8_t read_block[SD_BLOCK_SIZE];

    // Create a pattern in the write buffer
    for (int i = 0; i < SD_BLOCK_SIZE; i++) {
        write_block[i] = (uint8_t)((i+5) % 256); // Fill with a repeating 0-255 pattern
    }
    // Clear the read buffer
    memset(read_block, 0, SD_BLOCK_SIZE);

    // Step 3: Write the block to the SD card.
    xprintf("1. Writing 512 bytes to block address %d...\n", test_block_addr);
    if (sd_card_write_block(test_block_addr, write_block) == 0) {
        xprintf("   > Write complete.\n");
    } else {
        xprintf("[FAILURE] Failed to write block. Halting SD card test.\n");
        return; // Stop the test if writing fails
    }

    // Step 4: Read the block back from the SD card.
    xprintf("2. Reading 512 bytes from block address %d...\n", test_block_addr);
    if (sd_card_read_block(test_block_addr, read_block) == 0) {
        xprintf("   > Read complete.\n");
    } else {
        xprintf("[FAILURE] Failed to read block. Halting SD card test.\n");
        return; // Stop the test if reading fails
    }

    for(int i=0; i<SD_BLOCK_SIZE; ++i) {
        xprintf("write data is:%02X, read data: %02X\n", write_block[i], read_block[i]);
    }

    // Step 5: Verify the data.
    xprintf("3. Verifying data...\n");
    if (memcmp(write_block, read_block, SD_BLOCK_SIZE) == 0) {
        xprintf("\n[SUCCESS] SD Card test passed! Data matches.\n");
    } else {
        xprintf("\n[FAILURE] SD Card test failed! Data mismatch detected.\n");
        // Find and print the first mismatch
        for(int i=0; i<SD_BLOCK_SIZE; ++i) {
            if(write_block[i] != read_block[i]) {
                xprintf("   Mismatch found at byte index %d: Wrote 0x%02X, Read 0x%02X\n",
                        i, write_block[i], read_block[i]);
                break; // Only show the first error to avoid flooding the console
            }
        }
    }
}

void read_sd_card(void) {
    xprintf("\n-----------------------------------\n");
    xprintf("--- Running SD Card Test (SPI) ---\n");
    xprintf("-----------------------------------\n");

    // Step 1: Check if the SD card was initialized successfully in main().
    if (!sd_card_is_initialized()) {
        xprintf("[SKIPPED] SD Card was not initialized. Halting test.\n");
        return;
    }

    // Step 2: Prepare a full 512-byte block of data for writing.
    const uint32_t test_block_addr = 0; // Use a high block number to avoid overwriting filesystem data

    uint8_t read_block[SD_BLOCK_SIZE];
    memset(read_block, 0, SD_BLOCK_SIZE);

    // Read the block back from the SD card.
    xprintf("2. Reading 512 bytes from block address %d...\n", test_block_addr);
    if (sd_card_read_block(test_block_addr, read_block) == 0) {
        xprintf("   > Read complete.\n");
    } else {
        xprintf("[FAILURE] Failed to read block. Halting SD card test.\n");
        return; // Stop the test if reading fails
    }

    int count = 0;
    for(int i=0; i<SD_BLOCK_SIZE; ++i) {
        xprintf("  %02X",  read_block[i]);
        if(count%16 == 15) {
            xprintf("\n");
        }
        count++;
    }

}

/* =============================================================================
 *                      Main Application Entry Point
 * =============================================================================
 */
int main() {
    // Basic hardware initialization
    uart_init();
    xprintf("\n\n SPI Test\n");

    // // This is where you tell each driver which physical SPI channel it should use.
    // xprintf("Initializing drivers with hardware configuration...\n");
    // w25q64_init(MY_FLASH_CHIP_SPI_CHANNEL);

    // // Run the test for the W25Q64 Flash Memory
    // test_w25q64_flash();
    

    // ======================== SD Card Test ===========================
    // The SD card initialization is more complex and can fail, so we check its return value.
    if (sd_card_init(MY_SD_CARD_SPI_CHANNEL) != 0) {
        xprintf("!!! WARNING: SD Card initialization failed. The SD card test will be skipped. !!!\n");
    }
    // // Run the test for the SD Card
    // test_sd_card();

    read_sd_card();

    // ======================== All Tests Finished ===========================
    xprintf("\n===== All Tests Finished =====\n");
    
    // Loop forever
    while(1);

    return 0;
}