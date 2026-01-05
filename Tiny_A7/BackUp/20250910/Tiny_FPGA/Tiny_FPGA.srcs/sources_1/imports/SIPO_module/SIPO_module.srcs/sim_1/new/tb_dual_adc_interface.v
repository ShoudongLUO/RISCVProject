`timescale 1ns / 1ps

// ============================================================================
// File: tb_dual_adc_interface.v
//
// Description:
// Standalone testbench for verifying the 'dual_adc_interface' module.
// This testbench is written in pure Verilog-2001 to ensure compatibility
// with Vivado XSim.
// ============================================================================
module tb_dual_adc_interface;

    parameter DATA_WIDTH = 8;
    parameter PERIOD     = 10;

    // Testbench registers
    reg clk;
    reg rst_n;
    reg data_valid_in_a;
    reg serial_data_in_a;
    reg data_valid_in_b;
    reg serial_data_in_b;

    // Wires to connect to the DUT
    wire [DATA_WIDTH-1:0] parallel_data_out_a;
    wire data_ready_a;
    wire [DATA_WIDTH-1:0] parallel_data_out_b;
    wire data_ready_b;

    // Verilog-2001 requires variables to be declared at the top of the module
    integer i;
    reg [DATA_WIDTH-1:0] data_a;
    reg [DATA_WIDTH-1:0] data_b;

    // Instantiate the Device Under Test (DUT)
    dual_adc_interface #(.DATA_WIDTH(DATA_WIDTH)) uut (
        .clk(clk), .rst_n(rst_n),
        .data_valid_in_a(data_valid_in_a), .serial_data_in_a(serial_data_in_a),
        .data_valid_in_b(data_valid_in_b), .serial_data_in_b(serial_data_in_b),
        .parallel_data_out_a(parallel_data_out_a), .data_ready_a(data_ready_a),
        .parallel_data_out_b(parallel_data_out_b), .data_ready_b(data_ready_b)
    );

    // Clock generator
    always #(PERIOD/2) clk = ~clk;

    // Test sequence
    initial begin
        clk = 0; rst_n = 0;
        data_valid_in_a = 0; serial_data_in_a = 0;
        data_valid_in_b = 0; serial_data_in_b = 0;
        # (PERIOD * 2);
        rst_n = 1;
        $display("Time:%0tns [TB] Reset Released.", $time);
        
        // --- Test 1: Channel A Only ---
        $display("\n[TB] Test 1: Sending 0xA5 to Channel A...");
        data_a = 8'hA5;
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            @(posedge clk);
            serial_data_in_a <= data_a[i]; data_valid_in_a  <= 1'b1;
        end
        @(posedge clk);
        data_valid_in_a <= 1'b0;
        
        # (PERIOD * 2);

        // --- Test 2: Channel B Only ---
        $display("\n[TB] Test 2: Sending 0xC3 to Channel B...");
        data_b = 8'hC3;
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            @(posedge clk);
            serial_data_in_b <= data_b[i]; data_valid_in_b  <= 1'b1;
        end
        @(posedge clk);
        data_valid_in_b <= 1'b0;

        # (PERIOD * 2);

        // --- Test 3: Concurrent Send ---
        $display("\n[TB] Test 3: Sending 0xDE to A and 0xAD to B simultaneously...");
        data_a = 8'hDE;
        data_b = 8'hAD;
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            @(posedge clk);
            serial_data_in_a <= data_a[i]; data_valid_in_a <= 1'b1;
            serial_data_in_b <= data_b[i]; data_valid_in_b <= 1'b1;
        end
        @(posedge clk);
        data_valid_in_a <= 1'b0;
        data_valid_in_b <= 1'b0;
        
        # (PERIOD * 10);
        $display("\nTime:%0tns [TB] Simulation Finished.", $time);
        $finish;
    end

    // Monitors
    always @(posedge data_ready_a)
        $display("Time:%0tns [MONITOR] Channel A DONE! Received: 0x%h", $time, parallel_data_out_a);
    always @(posedge data_ready_b)
        $display("Time:%0tns [MONITOR] Channel B DONE! Received: 0x%h", $time, parallel_data_out_b);

endmodule