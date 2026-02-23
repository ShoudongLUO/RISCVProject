module tdc_channel_core (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [127:0] data_in,
    input  logic         data_valid,
    
    output logic         out_valid,
    output logic [11:0]  total_ticks_out [2:0], // [0]=TOT, [1]=TOA, [2]=CAL
    output logic [31:0]  lsb_ps_out,            // Q16.16 Fixed Point
    output logic [2:0]   data_flag[2:0],
    output logic [2:0]   err_flags              // [0]=CAL err, etc.
);
    
    // Configuration Constants
    // Constant from C code: (1000/18 MHz) * 1000 = 55555.555 ps per clock cycle
// 55555.555 * 2^16 = 3640885587 (approx)
    localparam logic [47:0] CLOCK_PERIOD_SCALED = 48'd3640885587; // 55.55ns in Q16.16
    localparam logic [2:0]  TIME_TYPE [2:0]     = {3'd0, 3'd1, 3'd2};
    localparam logic [5:0]  DELAY_LINE_NUM      = 30;

    // --- Signals ---
    logic [29:0] raw_fine [2:0];
    logic [6:0]  raw_coarse [2:0];
    logic [4:0]  dec_fine [2:0];
    logic        dec_valid [2:0];       
    logic        s1_valid, s2_valid, s3_valid;
    logic [4:0]  s1_fine [2:0];
    logic [6:0]  s1_coarse [2:0];
    logic [2:0]  s1_err_flags, s2_err_flags, s3_err_flags;
    logic [2:0]  data_flag1,data_flag2,data_flag3;
    logic [11:0] total_ticks [2:0];
    logic signed [12:0] dcode;
    logic [31:0] calc_lsb;

    // --- Bit Mapping ---
    assign raw_fine[0]   = data_in[127:98];
    assign raw_fine[1]   = data_in[97:68];
    assign raw_fine[2]   = data_in[67:38];
    assign raw_coarse[0] = data_in[37:31];
    assign raw_coarse[1] = data_in[30:24];
    assign raw_coarse[2] = data_in[23:17];

    // --- Submodules ---
    genvar i;
    generate
        for (i = 0; i < 3; i++) begin : gen_decoders
            tdc_finetime_decoder u_dec (
                .raw_data(raw_fine[i]), 
                .fine_time(dec_fine[i]),
                .valid(dec_valid[i]), 
                .has_bubble(data_flag1[i]), .err_no_edge(data_flag2[i]), .err_bad_cnt(data_flag3[i])
            );
        end
    endgenerate

    // --- Stage 1: Register Decoding Results ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 0; s1_err_flags <= 0;
            for(int k=0; k<3; k++) begin s1_fine[k] <= 0; s1_coarse[k] <= 0; end
        end else begin
            s1_valid <= data_valid;
            if (data_valid) begin
                for(int k=0; k<3; k++) begin
                    s1_fine[TIME_TYPE[k]]   <= dec_fine[k];
                    s1_coarse[TIME_TYPE[k]] <= raw_coarse[k];
                    s1_err_flags[TIME_TYPE[k]] <= ~dec_valid[k]; 
                end
            end
            for(int k=0; k<3; k++) begin
                data_flag[k] <={data_flag3[k], data_flag2[k], data_flag1[k]};
            end
        end
    end

    // --- Stage 2: Calculate Total Ticks ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 0; s2_err_flags <= 0;
            for(int k=0; k<3; k++) total_ticks[k] <= 0;
        end else begin
            s2_valid     <= s1_valid;
            s2_err_flags <= s1_err_flags;
            if (s1_valid) begin
                for(int k=0; k<3; k++) begin
                    total_ticks[k] <= (s1_coarse[TIME_TYPE[k]] * DELAY_LINE_NUM) + s1_fine[TIME_TYPE[k]];
                end
            end
        end
    end

    // --- Stage 3: LSB Calculation (DCode) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid <= 0; dcode <= 0; calc_lsb <= 0; s3_err_flags <= 0;
        end else begin
            s3_valid        <= s2_valid;
            total_ticks_out <= total_ticks;
            err_flags       <= s2_err_flags;

            if (s2_valid) begin
                dcode <= $signed({1'b0, total_ticks[2]}) - $signed({1'b0, total_ticks[1]}); // CAL - TOA
                if (dcode > 0 && !s2_err_flags[1] && !s2_err_flags[2]) begin
                    calc_lsb <= CLOCK_PERIOD_SCALED / $unsigned(dcode); 
                end else begin
                    calc_lsb <= 32'd0; 
                end
            end
        end
    end

    assign out_valid  = s3_valid;
    assign lsb_ps_out = calc_lsb;

endmodule