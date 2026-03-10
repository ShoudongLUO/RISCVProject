`timescale 1ns / 1ps

// =============================================================================
// FPGA_TDC_SoC_HostPC_tb.sv
//
// Integration testbench for SGMII-based FPGA DAQ SoC.
// Provides proper reset sequence, clock generation, and data stimulus.
// =============================================================================

module FPGA_TDC_SoC_HostPC_tb;

    // =========================================================================
    // 1. SIGNALS
    // =========================================================================
    logic clk, clk_125m, clk_fast;
    logic rst_n;
    logic start_btn;

    // DUT outputs
    logic        halted_ind;
    logic        uart_tx_pin;
    wire  [1:0]  gpio;
    logic        jtag_TDO;
    logic [1:0]  vcc3v3;
    wire         i2c_scl, i2c_sda;
    logic        spi_sck, spi_mosi;
    logic [1:0]  spi_csn;
    logic        phy_reset_n;
    logic [15:0] sgmii_status_vector;
    logic [3:0]  leds;

    // SGMII signals
    wire phy_sgmii_tx_p, phy_sgmii_tx_n;
    logic phy_sgmii_clk_p, phy_sgmii_clk_n;

    // =========================================================================
    // 2. CLOCK GENERATION
    // =========================================================================
    initial clk = 0;
    always #10 clk = ~clk;              // 50 MHz  (20 ns period)

    initial clk_125m = 0;
    always #4 clk_125m = ~clk_125m;     // 125 MHz (8 ns period)

    initial clk_fast = 0;
    always #2.5 clk_fast = ~clk_fast;   // 200 MHz (5 ns period)

    // SGMII Reference Clock — 625 MHz for PCS/PMA IP (refclk625)
    initial phy_sgmii_clk_p = 0;
    always #0.8 phy_sgmii_clk_p = ~phy_sgmii_clk_p;  // 625 MHz (1.6 ns period)
    assign phy_sgmii_clk_n = ~phy_sgmii_clk_p;

    // =========================================================================
    // 3. RESET & STIMULUS SEQUENCE
    // =========================================================================
    initial begin
        rst_n     = 1'b0;
        start_btn = 1'b0;

        // Hold reset for 500 ns
        #500;
        rst_n = 1'b1;
        $display("[%0t] Reset released", $time);

        // Wait for PCS/PMA initialization and system stabilization
        #50000;

        // Pulse start_btn to trigger data generation
        $display("[%0t] Triggering data generation (start_btn pulse)", $time);
        start_btn = 1'b1;
        #200;                            // Hold for multiple clk cycles
        start_btn = 1'b0;

        // Let simulation run for data to flow through the pipeline
        #1000000;

        $display("[%0t] === Simulation Complete ===", $time);
        $finish;
    end

    // =========================================================================
    // 4. MONITORING
    // =========================================================================
    always @(sgmii_status_vector) begin
        $display("[%0t] SGMII Status: 0x%04h (link=%b, sync=%b, speed=%b)",
                 $time, sgmii_status_vector,
                 sgmii_status_vector[0],      // link status
                 sgmii_status_vector[1],      // link synchronization
                 sgmii_status_vector[11:10]); // speed
    end

    always @(leds) begin
        $display("[%0t] LEDs changed to: %04b", $time, leds);
    end

    // =========================================================================
    // 5. DUT INSTANTIATION
    // =========================================================================
    fpga_tdc_test dut (
        .clk             (clk),
        .rst_ext_i       (rst_n),
        .clk_125m        (clk_125m),
        .clk_fast        (clk_fast),
        .start_btn       (start_btn),

        // SGMII Interface — loopback TX→RX for link establishment
        .phy_sgmii_rx_p  (phy_sgmii_tx_p),
        .phy_sgmii_rx_n  (phy_sgmii_tx_n),
        .phy_sgmii_tx_p  (phy_sgmii_tx_p),
        .phy_sgmii_tx_n  (phy_sgmii_tx_n),
        .phy_sgmii_clk_p (phy_sgmii_clk_p),
        .phy_sgmii_clk_n (phy_sgmii_clk_n),

        // Outputs
        .halted_ind          (halted_ind),
        .phy_reset_n         (phy_reset_n),
        .sgmii_status_vector (sgmii_status_vector),
        .leds                (leds),

        // UART
        .uart_tx_pin     (uart_tx_pin),
        .uart_rx_pin     (1'b1),           // UART idle = high

        // GPIO (inout — leave floating for simulation)
        .gpio            (gpio),

        // JTAG — tie inputs low (inactive)
        .jtag_TCK        (1'b0),
        .jtag_TMS        (1'b0),
        .jtag_TDI        (1'b0),
        .jtag_TDO        (jtag_TDO),

        // Power
        .vcc3v3          (vcc3v3),

        // I2C (inout — leave floating for simulation)
        .i2c_scl         (i2c_scl),
        .i2c_sda         (i2c_sda),

        // SPI
        .spi_sck         (spi_sck),
        .spi_mosi        (spi_mosi),
        .spi_miso        (1'b0),
        .spi_csn         (spi_csn)
    );

endmodule
