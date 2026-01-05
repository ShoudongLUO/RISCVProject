// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Double-flop-based synchronizer

module prim_flop_2sync_v #(
    parameter Width      = 16,
    parameter ResetValue = 0,
    parameter EnablePrimCdcRand = 1
  ) (
    input              clk_i,
    input              rst_ni,
    input [Width-1:0]  d_i,
    output [Width-1:0] q_o
  );
  
  wire [Width-1:0] d_o;
  wire  [Width-1:0] intq;

  assign d_o = d_i;


  prim_flop_v #(
    .Width(Width),
    .ResetValue(ResetValue)
  ) u_sync_1 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .d_i(d_o),
    .q_o(intq)
  );

  prim_flop_v #(
    .Width(Width),
    .ResetValue(ResetValue)
  ) u_sync_2 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .d_i(intq),
    .q_o(q_o)
  );

endmodule