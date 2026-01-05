`timescale 1ns / 1ps

// ============================================================================
// File: sipo_converter.v
//
// Description:
// Core IP module for Serial-In, Parallel-Out conversion.
// This design is 100% compatible with Verilog-2001 and Vivado XSim.
// It converts a serial data stream into a parallel word.
//
// Parameters:
//   DATA_WIDTH: The width of the parallel data output.
//
// Interface:
//   clk, rst_n: System clock and active-low reset.
//   data_valid_in: A pulse indicating a valid serial bit on data_in.
//   serial_data_in: The 1-bit serial data input.
//   parallel_data_out: The stable parallel data output.
//   data_ready_out: A single-cycle pulse indicating parallel_data_out is valid.
// ============================================================================
module sipo_converter #(
    parameter DATA_WIDTH = 8
) (
    input wire                      clk,
    input wire                      rst_n,
    input wire                      data_valid_in,
    input wire                      serial_data_in,
    output reg [DATA_WIDTH-1:0]     parallel_data_out,
    output reg                      data_ready_out
);
    // Internal shift register and counter
    reg [DATA_WIDTH-1:0] shift_reg; 
    // Counter bit width is manually calculated for Verilog-2001 compatibility.
    // For DATA_WIDTH=8, we need 3 bits [2:0].
    reg [20:0] count; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg         <= 0;
            count             <= 0;
            parallel_data_out <= 0;
            data_ready_out    <= 0;
        end else begin
            data_ready_out <= 1'b0; // Default output to invalid

            if (data_valid_in) begin
                // Data is shifted inside the internal register
                shift_reg <= {serial_data_in, shift_reg[DATA_WIDTH-1:1]};

                if (count == DATA_WIDTH-1) begin
                    // After receiving the last bit
                    data_ready_out    <= 1'b1; // Pulse the ready signal
                    parallel_data_out <= {serial_data_in, shift_reg[DATA_WIDTH-1:1]}; // Update the stable output
                    count             <= 0;    // Reset the counter
                end else begin
                    count <= count + 1;
                end
            end else begin
                // If no valid data is coming in, the counter must reset
                count <= 0;
            end
        end
    end
endmodule