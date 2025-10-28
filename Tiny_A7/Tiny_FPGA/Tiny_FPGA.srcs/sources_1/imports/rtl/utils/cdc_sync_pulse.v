`timescale 1ns / 1ps

// Safely synchronizes a single-cycle pulse from a source clock domain
// to a destination clock domain.
module cdc_sync_pulse (
    input clk_dest,
    input rst_dest_n,
    input pulse_src,
    output reg pulse_dest
);

    (* ASYNC_REG = "TRUE" *)
    reg sync_reg1, sync_reg2;
    wire edge_detect;

    always @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            sync_reg1 <= 1'b0;
            sync_reg2 <= 1'b0;
        end else begin
            sync_reg1 <= pulse_src;
            sync_reg2 <= sync_reg1;
        end
    end

    // Detect the rising edge of the synchronized signal
    assign edge_detect = sync_reg2 & ~sync_reg1;

    always @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            pulse_dest <= 1'b0;
        end else begin
            // Generate a single-cycle pulse in the destination domain
            pulse_dest <= edge_detect;
        end
    end

endmodule