// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module prim_flop_v #(
  parameter Width      = 1,
  parameter ResetValue = 0
) (
  input clk_i,
  input rst_ni,
  input [Width-1:0] d_i,
  output reg [Width-1:0] q_o
);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q_o <= ResetValue;
    end else begin
      q_o <= d_i;
    end
  end

endmodule