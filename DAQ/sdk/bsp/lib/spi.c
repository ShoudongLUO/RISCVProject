/*
 * =====================================================================================
 *
 *       Filename:  spi.c
 *
 *    Description:  Unified SPI driver implementation. Contains low-level HAL
 *                  and high-level device drivers in a single file for simplicity.
 *
 * =====================================================================================
 */
#include "../../bsp/include/spi.h"
#include "../../bsp/include/xprintf.h" // Assumes xprintf is available for debug output

/* =============================================================================
 *                 Part 1: Low-Level Hardware Abstraction Layer (HAL)
 * =============================================================================
 */

// Hardware configuration
#define SPI_MASTER_BASE_ADDR 0x60000000
#define SPI_CTRL_DATA   (*(volatile uint32_t *)(SPI_MASTER_BASE_ADDR + 0x00))
#define SPI_STATUS_DATA (*(volatile uint32_t *)(SPI_MASTER_BASE_ADDR + 0x04))

// Register bit definitions
#define STATUS_TX_READY (1 << 0)
#define STATUS_RX_VALID (1 << 1)
#define CTRL_START_TX   (1 << 2)
#define CTRL_CSN_DESELECT_ALL 3 // Assumes CS bits are [1:0], value 3 (binary 11) deselects all

// A special value for transfers where CS should remain high
#define SPI_CHAN_NONE 0xFF

/**
 * @brief Low-level function to select an SPI channel by pulling its CS line low.
 */
static void spi_select(uint8_t channel) {
    while (!(SPI_STATUS_DATA & STATUS_TX_READY));
    SPI_CTRL_DATA = channel;
}

/**
 * @brief Low-level function to deselect all SPI channels.
 */
static void spi_deselect(void) {
    while (!(SPI_STATUS_DATA & STATUS_TX_READY));
    SPI_CTRL_DATA = CTRL_CSN_DESELECT_ALL;
}

/**
 * @brief The core low-level function for a single byte SPI transaction.
 */
static uint8_t spi_transfer(uint8_t channel, uint8_t tx_byte) {
    uint32_t ctrl_val = (tx_byte << 8) | CTRL_START_TX;
    if (channel != SPI_CHAN_NONE) {
        ctrl_val |= channel; // Select the specified channel
    } else {
        ctrl_val |= CTRL_CSN_DESELECT_ALL; // Keep all channels deselected
    }
    
    while (!(SPI_STATUS_DATA & STATUS_TX_READY));
    SPI_CTRL_DATA = ctrl_val;
    
    while (!(SPI_STATUS_DATA & STATUS_RX_VALID));
    return (uint8_t)(SPI_STATUS_DATA >> 8);
}


/* =============================================================================
 *                      Part 2: W25Q64 Flash Memory Driver
 * =============================================================================
 */

static uint8_t w25q64_spi_channel;

// W25Q64 Command Opcodes
#define W25Q64_CMD_WRITE_ENABLE       0x06
#define W25Q64_CMD_READ_STATUS_REG1   0x05
#define W25Q64_CMD_READ_JEDEC_ID      0x9F
#define W25Q64_CMD_SECTOR_ERASE       0x20
#define W25Q64_CMD_PAGE_PROGRAM       0x02
#define W25Q64_CMD_READ_DATA          0x03
#define W25Q64_STATUS_BUSY_BIT        (1 << 0)

static void w25q64_wait_busy() {
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_READ_STATUS_REG1);
    while (spi_transfer(w25q64_spi_channel, 0x00) & W25Q64_STATUS_BUSY_BIT);
    spi_deselect();
}

static void w25q64_write_enable() {
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_WRITE_ENABLE);
    spi_deselect();
}

void w25q64_init(uint8_t spi_channel) {
    w25q64_spi_channel = spi_channel;
}

void w25q64_read_jedec_id(void) {
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_READ_JEDEC_ID);
    uint8_t manufacturer_id = spi_transfer(w25q64_spi_channel, 0x00);
    uint8_t device_id_hi = spi_transfer(w25q64_spi_channel, 0x00);
    uint8_t device_id_lo = spi_transfer(w25q64_spi_channel, 0x00);
    spi_deselect();
    xprintf("W25Q64 on SPI CH-%d -> JEDEC ID: Man=0x%02X, Dev=0x%02X%02X\n", 
            w25q64_spi_channel, manufacturer_id, device_id_hi, device_id_lo);
}

void w25q64_sector_erase(uint32_t address) {
    w25q64_write_enable();
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_SECTOR_ERASE);
    spi_transfer(w25q64_spi_channel, (address >> 16) & 0xFF);
    spi_transfer(w25q64_spi_channel, (address >> 8) & 0xFF);
    spi_transfer(w25q64_spi_channel, address & 0xFF);
    spi_deselect();
    w25q64_wait_busy();
}

void w25q64_page_program(uint32_t address, const uint8_t* data, uint16_t len) {
    w25q64_write_enable();
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_PAGE_PROGRAM);
    spi_transfer(w25q64_spi_channel, (address >> 16) & 0xFF);
    spi_transfer(w25q64_spi_channel, (address >> 8) & 0xFF);
    spi_transfer(w25q64_spi_channel, address & 0xFF);
    for (uint16_t i = 0; i < len; i++) {
        spi_transfer(w25q64_spi_channel, data[i]);
    }
    spi_deselect();
    w25q64_wait_busy();
}

void w25q64_read_data(uint32_t address, uint8_t* buffer, uint16_t len) {
    spi_select(w25q64_spi_channel);
    spi_transfer(w25q64_spi_channel, W25Q64_CMD_READ_DATA);
    spi_transfer(w25q64_spi_channel, (address >> 16) & 0xFF);
    spi_transfer(w25q64_spi_channel, (address >> 8) & 0xFF);
    spi_transfer(w25q64_spi_channel, address & 0xFF);
    for (uint16_t i = 0; i < len; i++) {
        buffer[i] = spi_transfer(w25q64_spi_channel, 0x00);
    }
    spi_deselect();
}


/* =============================================================================
 *                      Part 3: SD Card (SPI Mode) Driver
 * =============================================================================
 */

static uint8_t sd_card_spi_channel;
static int sd_card_initialized_flag = 0;

// SD Card Commands
#define CMD0    0   // GO_IDLE_STATE
#define CMD8    8   // SEND_IF_COND
#define CMD55   55  // APP_CMD
#define ACMD41  41  // SD_SEND_OP_COND
#define CMD17   17  // READ_SINGLE_BLOCK
#define CMD24   24  // WRITE_SINGLE_BLOCK

static uint8_t sd_send_command(uint8_t cmd, uint32_t arg) {
    uint8_t response;
    
    // For APP commands, CMD55 must be sent first
    if (cmd & 0x80) {
        cmd &= 0x7F; // Clear the APP command flag
        response = sd_send_command(CMD55, 0);
        if (response > 1) return response; // Return on error
    }

    // Wait until the card is not busy
    while(spi_transfer(sd_card_spi_channel, 0xFF) != 0xFF);

    // Send command packet
    spi_transfer(sd_card_spi_channel, 0x40 | cmd);
    spi_transfer(sd_card_spi_channel, (uint8_t)(arg >> 24));
    spi_transfer(sd_card_spi_channel, (uint8_t)(arg >> 16));
    spi_transfer(sd_card_spi_channel, (uint8_t)(arg >> 8));
    spi_transfer(sd_card_spi_channel, (uint8_t)(arg));
    
    uint8_t crc = 0x01; // Dummy CRC + stop bit
    if (cmd == CMD0) crc = 0x95;
    if (cmd == CMD8) crc = 0x87;
    spi_transfer(sd_card_spi_channel, crc);

    // Wait for the response; max 10 attempts
    for (int i = 0; i < 10; ++i) {
        response = spi_transfer(sd_card_spi_channel, 0xFF);
        if (!(response & 0x80)) break;
    }
    
    // Read the rest of the R7 response for CMD8
    if (response == 0x01 && cmd == CMD8) {
        for(int i = 0; i < 4; ++i) spi_transfer(sd_card_spi_channel, 0xFF);
    }

    return response;
}


int sd_card_init(uint8_t spi_channel) {
    sd_card_spi_channel = spi_channel;
    sd_card_initialized_flag = 0;

    // Power-on sequence: send at least 74 clock cycles with CS high
    spi_deselect();
    for (int i = 0; i < 10; ++i) {
        spi_transfer(SPI_CHAN_NONE, 0xFF);
    }
    
    spi_select(sd_card_spi_channel);

    // Enter idle state
    if (sd_send_command(CMD0, 0) != 0x01) {
        spi_deselect();
        xprintf("SD_INIT: Failed on CMD0\n");
        return 1;
    }

    // Check card version
    if (sd_send_command(CMD8, 0x1AA) != 0x01) {
        spi_deselect();
        xprintf("SD_INIT: Failed on CMD8 (maybe an old card?)\n");
        return 1;
    }

    // Initialize the card
    int timeout = 1000;
    while (timeout--) {
        if (sd_send_command(ACMD41 | 0x80, 0x40000000) == 0x00) {
            spi_deselect();
            sd_card_initialized_flag = 1;
            xprintf("SD Card on SPI CH-%d initialized successfully.\n", sd_card_spi_channel);
            return 0; // Success
        }
    }

    spi_deselect();
    xprintf("SD_INIT: Failed on ACMD41 (timeout)\n");
    return 1; // Failure
}

int sd_card_read_block(uint32_t block_addr, uint8_t* buffer) {
    if (!sd_card_initialized_flag) return -1;
    
    spi_select(sd_card_spi_channel);
    
    if (sd_send_command(CMD17, block_addr) != 0x00) {
        spi_deselect();
        xprintf("SD_READ: Failed on CMD17\n");
        return 1;
    }

    // Wait for data start token (0xFE)
    int timeout = 2000; // ~200ms timeout
    while (timeout-- && spi_transfer(sd_card_spi_channel, 0xFF) != 0xFE);
    if(timeout < 0) {
        spi_deselect();
        xprintf("SD_READ: Timeout waiting for data token.\n");
        return 1;
    }

    // Read 512 data bytes
    for (int i = 0; i < SD_BLOCK_SIZE; ++i) {
        buffer[i] = spi_transfer(sd_card_spi_channel, 0xFF);
    }

    // Discard 2-byte CRC
    spi_transfer(sd_card_spi_channel, 0xFF);
    spi_transfer(sd_card_spi_channel, 0xFF);

    spi_deselect();
    return 0; // Success
}

int sd_card_write_block(uint32_t block_addr, const uint8_t* buffer) {
    if (!sd_card_initialized_flag) return -1;
    
    spi_select(sd_card_spi_channel);

    if (sd_send_command(CMD24, block_addr) != 0x00) {
        spi_deselect();
        xprintf("SD_WRITE: Failed on CMD24\n");
        return 1;
    }

    // Send start token
    spi_transfer(sd_card_spi_channel, 0xFE);

    // Send 512 data bytes
    for (int i = 0; i < SD_BLOCK_SIZE; ++i) {
        spi_transfer(sd_card_spi_channel, buffer[i]);
    }

    // Send dummy CRC
    spi_transfer(sd_card_spi_channel, 0xFF);
    spi_transfer(sd_card_spi_channel, 0xFF);

    // Wait for data response token
    if ((spi_transfer(sd_card_spi_channel, 0xFF) & 0x1F) != 0x05) {
        spi_deselect();
        xprintf("SD_WRITE: Write not accepted by card.\n");
        return 1;
    }

    // Wait until card is not busy
    while(spi_transfer(sd_card_spi_channel, 0xFF) != 0xFF);

    spi_deselect();
    return 0; // Success
}

int sd_card_is_initialized(void) {
    return sd_card_initialized_flag;
}