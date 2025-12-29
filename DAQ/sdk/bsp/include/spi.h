/*
 * =====================================================================================
 *
 *       Filename:  spi.h
 *
 *    Description:  Unified SPI driver header for both low-level control and
 *                  high-level device drivers (W25Q64, SD Card).
 *                  This is the single header file needed by the application.
 *
 * =====================================================================================
 */
#ifndef SPI_H_
#define SPI_H_

#include <stdint.h>

/* =============================================================================
 *                      Part 1: W25Q64 Flash Memory Driver API
 * =============================================================================
 */

/**
 * @brief Initializes the W25Q64 driver with its assigned SPI channel.
 * @param spi_channel The physical SPI channel (CS line number, e.g., 0 for CS0).
 */
void w25q64_init(uint8_t spi_channel);

/**
 * @brief Reads the JEDEC ID from the W25Q64 chip to verify its presence.
 */
void w25q64_read_jedec_id(void);

/**
 * @brief Erases a 4KB sector of the W25Q64 flash memory.
 * @param address The starting address of the sector, must be 4KB aligned.
 */
void w25q64_sector_erase(uint32_t address);

/**
 * @brief Programs (writes) data to a page in the W25Q64.
 * @param address The starting byte address to write to.
 * @param data Pointer to the buffer containing data to write.
 * @param len Number of bytes to write (must not cross a 256-byte page boundary).
 */
void w25q64_page_program(uint32_t address, const uint8_t* data, uint16_t len);

/**
 * @brief Reads a block of data from the W25Q64.
 * @param address The starting byte address to read from.
 * @param buffer Pointer to the buffer where the read data will be stored.
 * @param len The number of bytes to read.
 */
void w25q64_read_data(uint32_t address, uint8_t* buffer, uint16_t len);


/* =============================================================================
 *                      Part 2: SD Card (SPI Mode) Driver API
 * =============================================================================
 */

#define SD_BLOCK_SIZE 512 // Standard block size for SD cards is 512 bytes

/**
 * @brief Initializes the SD Card driver with its assigned SPI channel.
 * @param spi_channel The physical SPI channel (CS line number, e.g., 1 for CS1).
 * @return 0 on success, non-zero on failure.
 */
int sd_card_init(uint8_t spi_channel);

/**
 * @brief Reads a single 512-byte block from the SD card.
 * @param block_addr The address of the block (sector) to read.
 * @param buffer Pointer to a 512-byte buffer to store the read data.
 * @return 0 on success, non-zero on failure.
 */
int sd_card_read_block(uint32_t block_addr, uint8_t* buffer);

/**
 * @brief Writes a single 512-byte block to the SD card.
 * @param block_addr The address of the block (sector) to write.
 * @param buffer Pointer to a 512-byte buffer containing the data to write.
 * @return 0 on success, non-zero on failure.
 */
int sd_card_write_block(uint32_t block_addr, const uint8_t* buffer);

/**
 * @brief Checks if the SD card has been successfully initialized.
 * @return 1 if initialized, 0 otherwise.
 */
int sd_card_is_initialized(void);

#endif /* SPI_H_ */