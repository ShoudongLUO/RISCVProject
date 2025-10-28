`timescale 1ns / 1ps

module cdc_sync_level #(
    parameter WIDTH = 1
) (
    input               clk_dest,
    input               rst_dest_n,
    input      [WIDTH-1:0] data_src,
    output reg [WIDTH-1:0] data_dest
);

    (* ASYNC_REG = "TRUE" *)
    reg [WIDTH-1:0] sync_reg1;

    always @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            sync_reg1   <= {WIDTH{1'b0}};
            data_dest   <= {WIDTH{1'b0}};
        end else begin
            sync_reg1   <= data_src;
            data_dest   <= sync_reg1;
        end
    end

endmodule