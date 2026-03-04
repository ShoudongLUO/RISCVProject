`timescale 1ns / 1ps

module FPGA_TDC_SoC_tb;

    // =========================================================================
    // 1. SIGNALS
    // =========================================================================
    logic clk, clk_125m, clk_fast;
    logic rst_n;
    logic start_btn;
    
    // Outputs from FPGA
    logic [3:0] leds;
    logic halted_ind;
    // (Other IOs can be left unconnected if not monitored)

    // =========================================================================
    // 2. CLOCK GENERATION
    // =========================================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;       // 50 MHz (20ns period)
    end

    initial begin
        clk_125m = 0;
        forever #4 clk_125m = ~clk_125m; // 125 MHz (8ns period)
    end

    initial begin
        clk_fast = 0;
        forever #2.5 clk_fast = ~clk_fast; // 200 MHz (5ns period)
    end

    // =========================================================================
    // 3. DUT INSTANTIATION
    // =========================================================================
    fpga_tdc_test dut (
        .clk(clk),
        .rst_ext_i(rst_n),
        .clk_125m(clk_125m),
        .clk_fast(clk_fast),
        .start_btn(start_btn),
        .leds(leds),
        .halted_ind(halted_ind),
        
        // Unused inputs driven to inactive state
        .uart_rx_pin(1'b1),
        .spi_miso(1'b0),
        .jtag_TCK(0), .jtag_TMS(0), .jtag_TDI(0),
        
        // IOs
        .gpio(), .vcc3v3(), .i2c_scl(), .i2c_sda(),
        .spi_sck(), .spi_mosi(), .spi_csn(),
        .eth_txc(), .eth_tx_ctl(), .eth_rst_n(), .eth_txd(),
        .uart_tx_pin(), .jtag_TDO()
    );

    // =========================================================================
    // 4. TEST SCENARIO
    // =========================================================================
    initial begin
        $display("========================================");
        $display("   TDC SYSTEM SIMULATION STARTING");
        $display("========================================");

        // 1. Initialize
        rst_n = 0;
        start_btn = 0;
        
        // 2. Reset Sequence
        repeat(50) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset Released", $time);
        repeat(50) @(posedge clk);

        // 3. Start Data Injection (Press Button)
        $display("[%0t] Pressing Start Button...", $time);
        start_btn = 1;
        repeat(20) @(posedge clk); // Hold button
        start_btn = 0;

        // 4. Wait for completion
        // The fpga_sipo_test module will drive data until files are empty
        // We just wait long enough for processing.
        #(200 * 1000); // Wait 200 us

        $display("========================================");
        $display("   SIMULATION FINISHED");
        $display("========================================");
        $stop;
    end
// =========================================================================
    // 6. RGMII PACKET CAPTURE & BRIDGE
    // =========================================================================
    // This logic mimics an Ethernet PHY receiver.
    // It captures eth_txd/eth_tx_ctl DDR signals, reassembles bytes,
    // extracts the UDP payload, and writes it to the pipe file.

    integer f_udp_log;
    initial begin
        f_udp_log = $fopen("C:/Users/ShoudongLUO/Desktop/RISCV/TinyRiscV_My/DAQ/Hosst_simulate/eth_tx_pipe.txt", "w");
        if (f_udp_log == 0) $stop;
    end

    // RGMII Signals from DUT
    wire rgmii_clk = dut.eth_txc;
    wire rgmii_ctl = dut.eth_tx_ctl;
    wire [3:0] rgmii_dat = dut.eth_txd;

    // Capture Logic
    reg [7:0] byte_data;
    reg       byte_valid;
    reg [3:0] low_nibble;
    reg       receiving_packet;
    reg [7:0] packet_buffer [0:1500];
    int       packet_len;
    int       byte_idx;

    // RGMII is Double Data Rate (DDR).
    // We sample on both edges of rgmii_clk.
    // Simplifying assumption for simulation: 
    // Data is stable on rising edge (Low Nibble) and falling edge (High Nibble) 
    // OR vice versa depending on implementation. 
    // Standard RGMII: Rising=Bits[3:0], Falling=Bits[7:4].

    always @(posedge rgmii_clk) begin
        if (rgmii_ctl) begin
            low_nibble <= rgmii_dat; // Store lower 4 bits
            receiving_packet <= 1;
        end else begin
            // End of packet detection
            if (receiving_packet) begin
                receiving_packet <= 0;
                process_packet(); // Function to parse and send
            end
        end
    end

    always @(negedge rgmii_clk) begin
        if (receiving_packet) begin
            // Reassemble Byte: {High_Nibble, Low_Nibble}
            byte_data = {rgmii_dat, low_nibble};
            
            // Store in buffer
            packet_buffer[packet_len] = byte_data;
            packet_len++;
        end else begin
            packet_len = 0;
        end
    end

    // Task to process the captured Ethernet Frame
    task process_packet;
        // Ethernet Frame Structure:
        // [Preamble] [SFD] [Dst MAC] [Src MAC] [Type] [IP Header] [UDP Header] [PAYLOAD] [CRC]
        // We need to strip headers to find the User Payload.
        // Assuming Standard IPv4 UDP Packet.
        
        // Simple Heuristic: Skip headers.
        // Ethernet Header: 14 bytes
        // IP Header: 20 bytes (usually)
        // UDP Header: 8 bytes
        // Total Header size = 42 bytes.
        
        int payload_offset = 42; 
        // Note: Preamble usually not sent to RGMII data path in some MACs, 
        // but if your MAC outputs Preamble (0x55...), offset increases by 8.
        
        // Let's print the raw payload to file
        // Here assuming the payload is just the 64-bit time diff for simplicity of the bridge
        
        // For debugging, let's dump the whole payload as hex string
        int k;
        reg [63:0] extracted_data;
        
        // Check if packet is long enough
        if (packet_len > 60) begin
            $display("[%0t] RGMII: Captured Packet Len=%0d", $time, packet_len);
            
            // Example: Extract 8 bytes of payload starting at offset
            // You might need to adjust 'payload_offset' based on your specific IP/UDP stack implementation
            // Let's assume the first 8 bytes of payload is the time data
            
            // Write to file for Python Bridge
            // Python expects a hex string. We can write the whole payload.
            for (k = 0; k < packet_len; k++) begin
                 $fwrite(f_udp_log, "%02h", packet_buffer[k]);
            end
            $fwrite(f_udp_log, "\n"); // End of packet
            $fflush(f_udp_log);
        end
    endtask

    final begin
        $fclose(f_udp_log);
    end
endmodule