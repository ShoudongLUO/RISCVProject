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

    // =========================================================================
    // 3. DUT INSTANTIATION
    // =========================================================================
    fpga_tdc_test dut (
        .clk          (clk),
        .rst_ext_i    (rst_n),
        .clk_125m     (clk_125m),
        .clk_fast     (clk_fast),
        .start_btn    (start_btn),
        .leds         (leds),
        .halted_ind   (halted_ind),

        .uart_rx_pin  (1'b1),
        .spi_miso     (1'b0),
        .jtag_TCK     (0),
        .jtag_TMS     (0),
        .jtag_TDI     (0),

        .gpio         (),
        .vcc3v3       (),
        .i2c_scl      (),
        .i2c_sda      (),
        .spi_sck      (),
        .spi_mosi     (),
        .spi_csn      (),
        .eth_txc      (),
        .eth_tx_ctl   (),
        .eth_rst_n    (),
        .eth_txd      (),
        .uart_tx_pin  (),
        .jtag_TDO     ()
    );

    // =========================================================================
    // 4. TEST SCENARIO
    // =========================================================================
    initial begin
        $display("========================================");
        $display("   TDC SYSTEM SIMULATION STARTING");
        $display("   (Host PC Integration Verification)");
        $display("========================================");

        rst_n     = 0;
        start_btn = 0;

        repeat (50) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset Released", $time);
        repeat (50) @(posedge clk);

        $display("[%0t] Pressing Start Button...", $time);
        start_btn = 1;
        repeat (20) @(posedge clk);
        start_btn = 0;

        #(200 * 1000);  // Wait 200 us

        $display("========================================");
        $display("   SIMULATION FINISHED");
        $display("   Captured %0d UDP packets", pkt_count);
        $display("   Output: host_pc_udp_payloads.bin");
        $display("========================================");
        $display("   Run verify_with_host_pc.py to check");
        $display("   protocol compatibility.");
        $display("========================================");
        $stop;
    end

    // =========================================================================
    // 5. RGMII PACKET CAPTURE → UDP PAYLOAD DUMP
    // =========================================================================
    // Captures RGMII DDR TX from DUT, reassembles Ethernet frames,
    // strips headers (Eth 14B + IP 20B + UDP 8B = 42B), writes only the
    // UDP payload to a binary file — identical to what QUdpSocket.readDatagram()
    // would deliver to the Python host application.

    localparam int ETH_HDR  = 14;
    localparam int IP_HDR   = 20;
    localparam int UDP_HDR  = 8;
    localparam int ALL_HDR  = ETH_HDR + IP_HDR + UDP_HDR;  // 42

    // RGMII signals tapped from DUT internals
    wire        rgmii_clk = dut.eth_txc;
    wire        rgmii_ctl = dut.eth_tx_ctl;
    wire [3:0]  rgmii_dat = dut.eth_txd;

    // Capture state
    reg  [3:0]  low_nibble;
    reg         receiving_packet;
    reg  [7:0]  frame_buf [0:1600];
    int         frame_len;
    int         pkt_count;

    // Output file
    integer f_out;

    initial begin
        receiving_packet = 0;
        frame_len        = 0;
        pkt_count        = 0;

        f_out = $fopen("host_pc_udp_payloads.bin", "wb");
        if (f_out == 0) begin
            $display("ERROR: Cannot open host_pc_udp_payloads.bin");
            $stop;
        end
    end

    // RGMII DDR: rising edge → low nibble, falling edge → high nibble
    always @(posedge rgmii_clk) begin
        if (rgmii_ctl) begin
            low_nibble       <= rgmii_dat;
            receiving_packet <= 1;
        end else begin
            if (receiving_packet) begin
                receiving_packet <= 0;
                dump_udp_payload();
            end
        end
    end

    always @(negedge rgmii_clk) begin
        if (receiving_packet) begin
            frame_buf[frame_len] = {rgmii_dat, low_nibble};
            frame_len++;
        end else begin
            frame_len = 0;
        end
    end

    // Strip Eth/IP/UDP headers, write raw UDP payload to binary file
    task dump_udp_payload;
        int payload_len;
        int i;

        if (frame_len <= ALL_HDR)
            return;  // Not a valid UDP frame

        payload_len = frame_len - ALL_HDR;
        pkt_count++;

        $display("[%0t] RGMII: Packet #%0d  frame=%0d bytes  UDP payload=%0d bytes",
                 $time, pkt_count, frame_len, payload_len);

        // Write 2-byte little-endian length prefix
        $fwrite(f_out, "%c%c",
                payload_len[7:0],
                payload_len[15:8]);

        // Write raw UDP payload bytes
        for (i = 0; i < payload_len; i++) begin
            $fwrite(f_out, "%c", frame_buf[ALL_HDR + i]);
        end

        $fflush(f_out);
    endtask

    final begin
        $fclose(f_out);
    end

endmodule
