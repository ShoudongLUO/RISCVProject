module coincidence_analyzer #(
    parameter FIFO_DEPTH        = 64,
    parameter DATA_WIDTH        = 16,
    parameter signed [63:0] MATCH_WINDOW_PS = 64'd3000,  // 3 ns Match Window
    parameter signed [63:0] REF_PERIOD_PS   = 64'd55555  // 18 MHz Clock Period (~55.5ns)
)(
    // =========================================================================
    // DOMAIN 1: TDC WRITE DOMAIN (Fast Clock)
    // =========================================================================
    input  logic        tdc_clk,
    input  logic        rst_n,       // Global Asynchronous Reset

    // Channel 1 Input (From TDC Module)
    input  logic        ch1_valid_in,
    input  logic [DATA_WIDTH-1:0] ch1_time_in, // Absolute Timestamp (Coarse + Fine)

    // Channel 2 Input (From TDC Module)
    input  logic        ch2_valid_in,
    input  logic [DATA_WIDTH-1:0] ch2_time_in,

    // =========================================================================
    // DOMAIN 2: SYSTEM ANALYSIS DOMAIN (Slow/Sys Clock)
    // =========================================================================
    input  logic        sys_clk,

    // Combined Output (Matched & Corrected)
    output logic        match_valid_out,
    output logic signed [DATA_WIDTH-1:0] time_diff_out // dtm (Corrected Delta)
);

    // =========================================================================
    // 1. RESET SYNCHRONIZATION
    // =========================================================================
    // Sync the async reset 'rst_n' into both clock domains
    wire [1:0] rst_sync; 

    cdc_sync_level rst_tdc_inst (
        .clk_dest(tdc_clk), .rst_dest_n(rst_n), .data_src(rst_n), .data_dest(rst_sync[0])
    );

    cdc_sync_level rst_sys_inst (
        .clk_dest(sys_clk), .rst_dest_n(rst_n), .data_src(rst_n), .data_dest(rst_sync[1])
    );

    // =========================================================================
    // 2. ASYNC FIFOs (Buffers)
    // =========================================================================
    
    // Internal Signals
    logic        ch1_wr_ready, ch2_wr_ready;
    logic        ch1_rvalid,   ch2_rvalid;
    logic [15:0] ch1_dout,     ch2_dout;
    logic        ch1_pop_req,  ch2_pop_req;
    
  
    logic [$clog2(FIFO_DEPTH+1)-1:0] unused_depth1, unused_depth2;

    // FIFO Channel 1
    prim_fifo_async #( .Width(DATA_WIDTH), .Depth(FIFO_DEPTH) ) u_fifo_ch1 (
        .clk_wr_i (tdc_clk),      .rst_wr_ni(rst_sync[0]),
        .wvalid_i (ch1_valid_in), .wready_o (ch1_wr_ready),
        .wdata_i  (ch1_time_in),  .wdepth_o (),
        
        .clk_rd_i (sys_clk),      .rst_rd_ni(rst_sync[1]),
        .rvalid_o (ch1_rvalid),   .rready_i (ch1_pop_req),
        .rdata_o  (ch1_dout),     .rdepth_o (unused_depth1)
    );

    // FIFO Channel 2
    prim_fifo_async #( .Width(16), .Depth(FIFO_DEPTH) ) u_fifo_ch2 (
        .clk_wr_i (tdc_clk),      .rst_wr_ni(rst_sync[0]),
        .wvalid_i (ch2_valid_in), .wready_o (ch2_wr_ready),
        .wdata_i  (ch2_time_in),  .wdepth_o (),
        
        .clk_rd_i (sys_clk),      .rst_rd_ni(rst_sync[1]),
        .rvalid_o (ch2_rvalid),   .rready_i (ch2_pop_req),
        .rdata_o  (ch2_dout),     .rdepth_o (unused_depth2)
    );

    // =========================================================================
    // 3. STAGE A: SLIDING WINDOW MATCHING (Combinational)
    // =========================================================================
    
    logic signed [DATA_WIDTH-1:0] raw_delta_t;
    logic               match_detected;
    
    always_comb begin
        // Default: Do not pop, no match
        ch1_pop_req = 1'b0;
        ch2_pop_req = 1'b0;
        match_detected = 1'b0;
        
        // Calculate raw difference: T1 - T2
        raw_delta_t = $signed(ch1_dout) - $signed(ch2_dout);

        // Only process if BOTH FIFOs have data ready
        if (ch1_rvalid && ch2_rvalid) begin
            
            // Check 1: Is it a match? (Within Window)
            // e.g. -3000ps <= delta <= +3000ps
            if ((raw_delta_t >= -MATCH_WINDOW_PS) && (raw_delta_t <= MATCH_WINDOW_PS)) begin
                match_detected = 1'b1;
                ch1_pop_req = 1'b1; // Consume both
                ch2_pop_req = 1'b1;
            end
            
            // Check 2: No match. Is Ch2 too old? (Ch1 is way ahead of Ch2)
            // delta > 3000 -> T1 > T2 + 3000
            else if (raw_delta_t > MATCH_WINDOW_PS) begin
                ch2_pop_req = 1'b1; // Discard Ch2 to catch up
            end
            
            // Check 3: No match. Is Ch1 too old? (Ch1 is way behind Ch2)
            else begin
                ch1_pop_req = 1'b1; // Discard Ch1 to catch up
            end
        end
    end

    // =========================================================================
    // 4. STAGE B: CYCLE CORRECTION & OUTPUT (Pipeline Sequential)
    // =========================================================================
    // folding the delta into +/- Half Period range.
    
    localparam signed [DATA_WIDTH-1:0] HALF_PERIOD = REF_PERIOD_PS >>> 1; // Divide by 2

    always_ff @(posedge sys_clk or negedge rst_sync[1]) begin
        if (!rst_sync[1]) begin
            match_valid_out <= 1'b0;
            time_diff_out   <= '0;
        end else begin
            // Latency: Output appears 1 clock cycle after FIFO read happens
            match_valid_out <= match_detected;
            
            if (match_detected) begin
                // --- CYCLE CORRECTION LOGIC ---
                // If the difference is huge (larger than half a clock cycle),
                // we assume it's a "cycle slip" and wrap it around.
                // (Note: With a 3ns window and 55ns period, this effectively passes raw_delta_t,
                //  but keeps the logic ready if increase MATCH_WINDOW_PS later).

                if (raw_delta_t > HALF_PERIOD) begin
                    // Case: Ch1 is ahead by 1 full cycle -> Subtract Period
                    time_diff_out <= raw_delta_t - REF_PERIOD_PS;
                end 
                else if (raw_delta_t < -HALF_PERIOD) begin
                    // Case: Ch1 is behind by 1 full cycle -> Add Period
                    time_diff_out <= raw_delta_t + REF_PERIOD_PS;
                end 
                else begin
                    // Case: Normal match
                    time_diff_out <= raw_delta_t;
                end
            end else begin
                // Optional: clear output when invalid
                time_diff_out <= '0; 
            end
        end
    end

endmodule