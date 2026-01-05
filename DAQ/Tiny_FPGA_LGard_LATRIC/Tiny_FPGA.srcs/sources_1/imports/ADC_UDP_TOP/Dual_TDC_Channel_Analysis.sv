`timescale 1ns / 1ps

module top_dual_channel_analysis #(
    parameter signed [63:0] MATCH_WINDOW_PS = 64'd3000,  // 3ns Window
    parameter int           FIFO_DEPTH      = 64
)(
    // ==========================================
    // CLOCKS & RESET
    // ==========================================
    input  logic         clk_fast,      // 200MHz+ (Decoding Domain)
    input  logic         clk_sys,       // 100MHz  (Analysis Domain)
    input  logic         rst_n,         // Global Async Reset

    // ==========================================
    // CHANNEL 1 INPUT (Raw 128-bit)
    // ==========================================
    input  logic [127:0] ch1_data_in,
    input  logic         ch1_data_valid,

    // ==========================================
    // CHANNEL 2 INPUT (Raw 128-bit)
    // ==========================================
    input  logic [127:0] ch2_data_in,
    input  logic         ch2_data_valid,

    // ==========================================
    // ANALYSIS OUTPUT (Synced to clk_sys)
    // ==========================================
    output logic         match_valid_out,
    output logic signed [63:0] time_diff_ps_out, // The final 'dtm' result

    // Optional: Debugging / Monitoring ports
    output logic         ch1_decode_error,
    output logic         ch2_decode_error
);

    // =========================================================================
    // 1. CHANNEL 1 DECODING
    // =========================================================================
    logic        c1_core_valid;
    logic [11:0] c1_ticks [2:0]; // [0]=CAL, [1]=TOA, [2]=TOT
    logic [31:0] c1_lsb;
    logic [2:0]  c1_errs;
    logic [63:0] c1_abs_time_ps;

    tdc_channel_core u_core_ch1 (
        .clk             (clk_fast),
        .rst_n           (rst_n),
        .data_in         (ch1_data_in),
        .data_valid      (ch1_data_valid),
        .out_valid       (c1_core_valid),
        .total_ticks_out (c1_ticks),
        .lsb_ps_out      (c1_lsb),
        .err_flags       (c1_errs)
    );

    // =========================================================================
    // 2. CHANNEL 2 DECODING
    // =========================================================================
    logic        c2_core_valid;
    logic [11:0] c2_ticks [2:0];
    logic [31:0] c2_lsb;
    logic [2:0]  c2_errs;
    logic [63:0] c2_abs_time_ps;

    tdc_channel_core u_core_ch2 (
        .clk             (clk_fast),
        .rst_n           (rst_n),
        .data_in         (ch2_data_in),
        .data_valid      (ch2_data_valid),
        .out_valid       (c2_core_valid),
        .total_ticks_out (c2_ticks),
        .lsb_ps_out      (c2_lsb),
        .err_flags       (c2_errs)
    );

    // =========================================================================
    // 3. ABSOLUTE TIME CONVERSION
    // =========================================================================
    // The Core gives us "Ticks" and "LSB value". 
    // We must convert this to absolute Picoseconds before sending to the Analyzer.
    // Formula: Time = TOA_Ticks * LSB_Value
    // Note: LSB is Fixed Point (Q16.16), so we Multiply then Shift Right by 16.

    localparam int IDX_TOA = 1; // Index 1 is TOA based on C code

    always_ff @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            c1_abs_time_ps <= '0;
            c2_abs_time_ps <= '0;
        end else begin
            // Convert Channel 1
            if (c1_core_valid) begin
                c1_abs_time_ps <= (c1_ticks[IDX_TOA] * c1_lsb) >> 16;
            end

            // Convert Channel 2
            if (c2_core_valid) begin
                c2_abs_time_ps <= (c2_ticks[IDX_TOA] * c2_lsb) >> 16;
            end
        end
    end

    // =========================================================================
    // 4. COINCIDENCE ANALYSIS (The FIFO & Matching Engine)
    // =========================================================================
    coincidence_analyzer #(
        .FIFO_DEPTH      (FIFO_DEPTH),
        .MATCH_WINDOW_PS (MATCH_WINDOW_PS)
    ) u_analyzer (
        // Write Domain (Fast)
        .adc_clk         (clk_fast),
        .rst_n           (rst_n),
        
        .ch1_valid_in    (c1_core_valid), // Use validity flag to push to FIFO
        .ch1_time_in     (c1_abs_time_ps),
        
        .ch2_valid_in    (c2_core_valid),
        .ch2_time_in     (c2_abs_time_ps),

        // Read/Analysis Domain (Slow)
        .sys_clk         (clk_sys),
        .match_valid_out (match_valid_out),
        .time_diff_out   (time_diff_ps_out)
    );

    // =========================================================================
    // 5. STATUS OUTPUTS
    // =========================================================================
    assign ch1_decode_error = |c1_errs; // Output high if any error bit is set
    assign ch2_decode_error = |c2_errs;

endmodule