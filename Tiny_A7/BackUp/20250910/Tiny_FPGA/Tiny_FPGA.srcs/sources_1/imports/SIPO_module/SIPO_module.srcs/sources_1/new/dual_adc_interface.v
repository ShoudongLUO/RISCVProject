`timescale 1ns / 1ps

// ============================================================================
// File: dual_adc_interface.v
//
// Description:
// Top-level module for a dual-channel ADC serial interface.
// It instantiates two 'sipo_converter' IPs to handle two independent
// serial data streams. This is the module you will connect to your
// system bus and data processing logic.
// ============================================================================
module dual_adc_interface #(
    parameter DATA_WIDTH = 8
) (
    input wire                      clk,
    input wire                      rst_n,
    // Channel A
    input wire                      data_valid_in_a,
    input wire                      serial_data_in_a,
    output wire [DATA_WIDTH-1:0]    parallel_data_out_a,
    output wire                     data_ready_a,
    // Channel B
    input wire                      data_valid_in_b,
    input wire                      serial_data_in_b,
    output wire [DATA_WIDTH-1:0]    parallel_data_out_b,
    output wire                     data_ready_b
);

    // Instantiate for Channel A
    sipo_converter #(.DATA_WIDTH(DATA_WIDTH)) sipo_a (
        .clk(clk), .rst_n(rst_n),
        .data_valid_in(data_valid_in_a), .serial_data_in(serial_data_in_a),
        .parallel_data_out(parallel_data_out_a), .data_ready_out(data_ready_a)
    );

    // Instantiate for Channel B
    sipo_converter #(.DATA_WIDTH(DATA_WIDTH)) sipo_b (
        .clk(clk), .rst_n(rst_n),
        .data_valid_in(data_valid_in_b), .serial_data_in(serial_data_in_b),
        .parallel_data_out(parallel_data_out_b), .data_ready_out(data_ready_b)
    );
endmodule