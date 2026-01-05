module tdc_finetime_decoder (
    input  logic [29:0] raw_data,
    output logic [4:0]  fine_time,
    output logic        valid,       // 1 if data is usable (Perfect or Bubble-but-15-ones)
    output logic        has_bubble,  // 1 if pattern is imperfect but count is 15
    output logic        err_no_edge, // 1 if no 0->1 transition found
    output logic        err_bad_cnt  // 1 if total 1s is not 15
);

    // 1. Population Count (Count total number of 1s)
    //  verify if total 1s == 15
    logic [4:0] pop_count;
    
    always_comb begin
        pop_count = 5'd0;
        for (int i = 0; i < 30; i++) begin
            pop_count = pop_count + raw_data[i];
        end
    end

    // 2. Edge Detection (Mimicking C++ 'getfinecode' loop)
    // C Code scans i=0..29. 
    // ps (Current) = bit[29-i]
    // ns (Next)    = bit[29-i-1] (Wrap to 29 if i=29)
    // Finds first occurrence of ps=0 AND ns=1
    
    logic [4:0] ic_found;
    logic       edge_detected;
    
    always_comb begin
        ic_found = 5'd0;
        edge_detected = 1'b0;
        
        // Priority Encoder Logic
        // Loop from 0 to 29 to match C++ priority (first match wins)
        for (int i = 0; i < 30; i++) begin
            // Calculate bit indices based on C code logic
            int curr_idx = 29 - i;
            int next_idx = (i == 29) ? 29 : (29 - i - 1);
            
            logic ps = raw_data[curr_idx];
            logic ns = raw_data[next_idx];
            
            if (!edge_detected && !ps && ns) begin
                ic_found = i[4:0];
                edge_detected = 1'b1;
            end
        end
    end

    // 3. Strict Pattern Verification (Optional but good for 'has_bubble' flag)
    // We rotate the raw data so the detected edge moves to a known position
    // and compare it against the perfect pattern (15 zeros, 15 ones).
    
    logic [29:0] rotated_data;
    // Perfect pattern for a standard thermometer code often looks like 00...0011...11
    // Based on C logic: after 0->1 transition, we expect 15 1s then 15 0s.
    // The "Start" is at ic+1.
    
    // Barrel Shifter: Rotate Right by (ic_found + 1)
    // This moves the "15 ones" to the LSBs.
    always_comb begin
        // SystemVerilog supports variable shift
        // If we rotate right by (ic+1), the bit at (ic+1) moves to bit 0.
        // We expect bits [14:0] to be 1, and [29:15] to be 0.
        // Note: raw_data is 30 bits. 
        // Logic: (raw >> shift) | (raw << (30-shift))
        logic [5:0] shift_amt; // 30 + 1 needs 6 bits range
        shift_amt = {1'b0, ic_found} + 1;
        
        // Handle wrap around for shift amount 30
        if (shift_amt >= 30) shift_amt = shift_amt - 30;
        
        rotated_data = (raw_data >> shift_amt) | (raw_data << (30 - shift_amt));
    end
    
    logic pattern_perfect;
    always_comb begin
        // Check if lower 15 bits are 1 and upper 15 bits are 0
        if (rotated_data == 30'h00007FFF) begin
            pattern_perfect = 1'b1;
        end else begin
            pattern_perfect = 1'b0;
        end
    end

    // 4. Final Output Logic
    always_comb begin
        fine_time   = ic_found;
        err_no_edge = !edge_detected;
        err_bad_cnt = (pop_count != 5'd15);
        
       
        if (!edge_detected) begin
            valid      = 1'b0;
            has_bubble = 1'b0;
        end else begin
            if (pop_count == 5'd15) begin
                valid      = 1'b1;
                has_bubble = !pattern_perfect; // It's valid, but might have bubbles
            end else begin
                valid      = 1'b0; // Count is wrong, strict reject
                has_bubble = 1'b0;
            end
        end
    end

endmodule