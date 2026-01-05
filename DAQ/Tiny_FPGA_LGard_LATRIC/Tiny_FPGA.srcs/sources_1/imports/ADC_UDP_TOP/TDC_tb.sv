`timescale 1ns / 1ps

module tb_top;

    // =========================================================================
    // 1. SIGNALS & PARAMETERS
    // =========================================================================
    
    // Clocks
    logic clk_fast; // 200 MHz
    logic clk_sys;  // 100 MHz
    logic rst_n;
    
    // DUT Inputs
    logic [127:0] ch1_data_in;
    logic         ch1_data_valid;
    logic [127:0] ch2_data_in;
    logic         ch2_data_valid;
    
    // DUT Outputs
    logic         match_valid_out;
    logic signed [63:0] time_diff_ps_out;
    logic         ch1_decode_err, ch2_decode_err;

    // Simulation Memory (Buffers for vectors)
    logic [127:0] mem_ch1 [0:9999]; // Adjust depth if needed
    logic [127:0] mem_ch2 [0:9999];
    int           cnt_ch1, cnt_ch2;
    int           ptr_ch1, ptr_ch2;

    // =========================================================================
    // 2. DUT INSTANTIATION
    // =========================================================================
    top_dual_channel_analysis #(
        .MATCH_WINDOW_PS (64'd10000), // Relaxed window for testing (10ns)
        .FIFO_DEPTH      (64)
    ) dut (
        .clk_fast       (clk_fast),
        .clk_sys        (clk_sys),
        .rst_n          (rst_n),
        
        .ch1_data_in    (ch1_data_in),
        .ch1_data_valid (ch1_data_valid),
        
        .ch2_data_in    (ch2_data_in),
        .ch2_data_valid (ch2_data_valid),
        
        .match_valid_out(match_valid_out),
        .time_diff_ps_out(time_diff_ps_out),
        
        .ch1_decode_error(ch1_decode_err),
        .ch2_decode_error(ch2_decode_err)
    );

    // =========================================================================
    // 3. CLOCK GENERATION
    // =========================================================================
    initial begin
        clk_fast = 0;
        forever #2.5 clk_fast = ~clk_fast; // 200 MHz (Period 5ns)
    end

    initial begin
        clk_sys = 0;
        forever #5 clk_sys = ~clk_sys;     // 100 MHz (Period 10ns)
    end

    // =========================================================================
    // 4. MAIN STIMULUS
    // =========================================================================
    initial begin
        // A. Load Vectors
        $display("Loading vectors...");
        // Ensure these files exist in simulation directory
        $readmemh("ch1_vectors.txt", mem_ch1);
        $readmemh("ch2_vectors.txt", mem_ch2);
        
        // Count how many vectors we loaded (naive way or hardcode)
        // Here assuming we just run until we hit 0s or max count
        
        // B. Reset System
        rst_n = 0;
        ch1_data_valid = 0;
        ch2_data_valid = 0;
        ch1_data_in = 0;
        ch2_data_in = 0;
        ptr_ch1 = 0;
        ptr_ch2 = 0;
        
        repeat(20) @(posedge clk_fast);
        rst_n = 1;
        repeat(10) @(posedge clk_fast);
        
        $display("Starting Packet Injection...");

        // C. Drive Data
        // Since the vectors from C++ are stripped of their relative timestamps 
        // (we only dumped the packet data), we will feed them continuously
        // but with random small delays to test the FIFO logic.
        
        fork
            // Process Channel 1
            begin
                while(mem_ch1[ptr_ch1] != 0) begin
                    @(posedge clk_fast);
                    ch1_data_in    <= mem_ch1[ptr_ch1];
                    ch1_data_valid <= 1;
                    
                    @(posedge clk_fast);
                    ch1_data_valid <= 0;
                    
                    // Wait random cycles (simulating sparse events)
                    // repeat($urandom_range(5, 20)) @(posedge clk_fast);
                    repeat(10) @(posedge clk_fast); 
                    
                    ptr_ch1++;
                end
            end
            
            // Process Channel 2
            begin
                while(mem_ch2[ptr_ch2] != 0) begin
                    @(posedge clk_fast);
                    ch2_data_in    <= mem_ch2[ptr_ch2];
                    ch2_data_valid <= 1;
                    
                    @(posedge clk_fast);
                    ch2_data_valid <= 0;
                    
                    // Wait random cycles (simulating sparse events)
                    // repeat($urandom_range(5, 20)) @(posedge clk_fast);
                    repeat(10) @(posedge clk_fast);
                    
                    ptr_ch2++;
                end
            end
        join

        $display("All vectors injected. Waiting for pipeline to drain...");
        repeat(200) @(posedge clk_sys);
        $stop;
    end

    // =========================================================================
    // 5. MONITOR & VERIFICATION
    // =========================================================================
    always @(posedge clk_sys) begin
        if(match_valid_out) begin
            $display("Time: %t | MATCH FOUND! Delta = %0d ps", $time, time_diff_ps_out);
        end
        
        if(ch1_decode_err) $display("Time: %t | ERROR: Ch1 Decoding Failed", $time);
        if(ch2_decode_err) $display("Time: %t | ERROR: Ch2 Decoding Failed", $time);
    end

endmodule