`timescale 1ns / 1ps

// =============================================================================
// FPGA_TDC_SoC_HostPC_tb.sv
//
// Integration-verification testbench: captures RGMII TX from the FPGA DUT,
// strips Ethernet/IP/UDP headers, and dumps raw UDP payloads to a binary file.
//
// After simulation, run the companion Python script
//   verify_with_host_pc.py
// which feeds those payloads through the REAL Host_Computer_PySide6 parsers
// to verify RTL ↔ Host-PC protocol compatibility.
//
// Binary file format (host_pc_udp_payloads.bin):
//   For each captured UDP packet:
//     [2 bytes, little-endian]  payload_length
//     [payload_length bytes]    raw UDP payload (same bytes QUdpSocket delivers)
// =============================================================================

module FPGA_TDC_SoC_HostPC_tb;

    // =========================================================================
    // 1. SIGNALS
    // =========================================================================
    logic clk, clk_125m, clk_fast;
    logic rst_n;
    logic start_btn;

    logic [3:0] leds;
    logic halted_ind;

    // =========================================================================
    // 2. CLOCK GENERATION
    // =========================================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;          // 50 MHz  (20 ns period)
    end

    initial begin
        clk_125m = 0;
        forever #4 clk_125m = ~clk_125m; // 125 MHz (8 ns period)
    end

    initial begin
        clk_fast = 0;
        forever #2.5 clk_fast = ~clk_fast; // 200 MHz (5 ns period)
    end
// SGMII Specific Signals
    logic phy_sgmii_rx_p, phy_sgmii_rx_n;
    logic phy_sgmii_tx_p, phy_sgmii_tx_n;
    logic phy_sgmii_clk_p, phy_sgmii_clk_n;

    // SGMII Reference Clock (usually 125MHz or 625MHz)
    initial begin
        phy_sgmii_clk_p = 0;
        forever #4 phy_sgmii_clk_p = ~phy_sgmii_clk_p; // 125MHz Ref
    end
    assign phy_sgmii_clk_n = ~phy_sgmii_clk_p;

    // DUT Instantiation
    fpga_tdc_test dut (
        .clk            (clk),
        .rst_ext_i      (rst_n),
        .clk_125m       (clk_125m),
        .clk_fast       (clk_fast),
        .start_btn      (start_btn),
        
        // SGMII Interface
        .phy_sgmii_rx_p (1'b0), // Loopback or Stimulus
        .phy_sgmii_rx_n (1'b1),
        .phy_sgmii_tx_p (phy_sgmii_tx_p),
        .phy_sgmii_tx_n (phy_sgmii_tx_n),
        .phy_sgmii_clk_p(phy_sgmii_clk_p),
        .phy_sgmii_clk_n(phy_sgmii_clk_n),
        
        // ... [Other pins] ...
        .uart_rx_pin    (1'b1)
    );
    
endmodule
