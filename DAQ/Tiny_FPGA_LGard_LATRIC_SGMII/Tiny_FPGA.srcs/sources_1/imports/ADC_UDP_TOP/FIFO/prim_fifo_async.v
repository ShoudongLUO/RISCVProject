// Copyright lowRISC contributors (OpenTitan project.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Generic asynchronous fifo for use in a variety of devices.

module prim_fifo_async #(
  parameter Width  = 32,
  parameter Depth  = 1024,
  parameter OutputZeroIfEmpty   = 1'b1,
  parameter OutputZeroIfInvalid = 1'b1,
  parameter DepthW = $clog2(Depth+1)
) (
  input  clk_wr_i,
  input  rst_wr_ni,
  input  wvalid_i,
  output wready_o,
  input  [Width-1:0] wdata_i,
  output [DepthW-1:0] wdepth_o,

  input  clk_rd_i,
  input  rst_rd_ni,
  output rvalid_o,
  input  rready_i,
  output [Width-1:0] rdata_o,
  output [DepthW-1:0] rdepth_o
);

  // Depth must be a power of 2 for the gray code pointers to work
  initial begin
    if (Depth != (1 << $clog2(Depth))) begin
      $error("Depth must be a power of 2!");
    end
  end

  localparam PTRV_W    = (Depth == 1) ? 1 : $clog2(Depth);
  localparam PTR_WIDTH = (Depth == 1) ? 1 : PTRV_W+1;

  // Pointer registers
  reg  [PTR_WIDTH-1:0] fifo_wptr_q, fifo_wptr_gray_q;
  wire [PTR_WIDTH-1:0] fifo_wptr_d, fifo_wptr_gray_d;

  reg  [PTR_WIDTH-1:0] fifo_rptr_q, fifo_rptr_gray_q;
  wire [PTR_WIDTH-1:0] fifo_rptr_d, fifo_rptr_gray_d;

  reg  [PTR_WIDTH-1:0] fifo_rptr_sync_q;
  wire [PTR_WIDTH-1:0] fifo_wptr_sync_combi, fifo_rptr_sync_combi;
  wire [PTR_WIDTH-1:0] fifo_wptr_gray_sync, fifo_rptr_gray_sync;

  wire fifo_incr_wptr, fifo_incr_rptr;
  wire full_wclk, full_rclk, empty_rclk;

  reg [Width-1:0] storage [0:Depth-1];

  ///////////////////
  // Write Pointer //
  ///////////////////
  assign fifo_incr_wptr = wvalid_i & wready_o;
  assign fifo_wptr_d = fifo_wptr_q + 1'b1;

  always @(posedge clk_wr_i or negedge rst_wr_ni) begin
    if (!rst_wr_ni)
      fifo_wptr_q <= 0;
    else if (fifo_incr_wptr)
      fifo_wptr_q <= fifo_wptr_d;
  end

  always @(posedge clk_wr_i or negedge rst_wr_ni) begin
    if (!rst_wr_ni)
      fifo_wptr_gray_q <= 0;
    else if (fifo_incr_wptr)
      fifo_wptr_gray_q <= fifo_wptr_gray_d;
  end


  // sync gray-coded pointer to read clk
  prim_flop_2sync_v #(.Width(PTR_WIDTH)) sync_wptr (
    .clk_i  (clk_rd_i),
    .rst_ni (rst_rd_ni),
    .d_i    (fifo_wptr_gray_q),
    .q_o    (fifo_wptr_gray_sync)
  );

  //////////////////
  // Read Pointer //
  //////////////////
  assign fifo_incr_rptr = rvalid_o & rready_i;
  assign fifo_rptr_d = fifo_rptr_q + 1'b1;

  always @(posedge clk_rd_i or negedge rst_rd_ni) begin
    if (!rst_rd_ni)
      fifo_rptr_q <= 0;
    else if (fifo_incr_rptr)
      fifo_rptr_q <= fifo_rptr_d;
  end

  always @(posedge clk_rd_i or negedge rst_rd_ni) begin
    if (!rst_rd_ni)
      fifo_rptr_gray_q <= 0;
    else if (fifo_incr_rptr)
      fifo_rptr_gray_q <= fifo_rptr_gray_d;
  end

  // sync gray-coded pointer to write clk
  prim_flop_2sync_v #(.Width(PTR_WIDTH)) sync_rptr (
    .clk_i  (clk_wr_i),
    .rst_ni (rst_wr_ni),
    .d_i    (fifo_rptr_gray_q),
    .q_o    (fifo_rptr_gray_sync)
  );

  // Registered version of synced read pointer
  always @(posedge clk_wr_i or negedge rst_wr_ni) begin
    if (!rst_wr_ni)
      fifo_rptr_sync_q <= 0;
    else
      fifo_rptr_sync_q <= fifo_rptr_sync_combi;
  end

  //////////////////
  // Empty / Full //
  //////////////////
  wire [PTR_WIDTH-1:0] xor_mask = 1'b1 << (PTR_WIDTH-1);
  assign full_wclk  = (fifo_wptr_q == (fifo_rptr_sync_q ^ xor_mask));
  assign full_rclk  = (fifo_wptr_sync_combi == (fifo_rptr_q ^ xor_mask));
  assign empty_rclk = (fifo_wptr_sync_combi == fifo_rptr_q);

  // Depth calculation
  generate
    if (Depth > 1) begin : g_depth_calc
      wire wptr_msb = fifo_wptr_q[PTR_WIDTH-1];
      wire rptr_sync_msb = fifo_rptr_sync_q[PTR_WIDTH-1];
      wire [PTRV_W-1:0] wptr_value = fifo_wptr_q[0+:PTRV_W];
      wire [PTRV_W-1:0] rptr_sync_value = fifo_rptr_sync_q[0+:PTRV_W];

      assign wdepth_o = (full_wclk) ? Depth :
                        (wptr_msb == rptr_sync_msb) ? wptr_value - rptr_sync_value :
                        (Depth - rptr_sync_value + wptr_value);

      wire rptr_msb = fifo_rptr_q[PTR_WIDTH-1];
      wire wptr_sync_msb = fifo_wptr_sync_combi[PTR_WIDTH-1];
      wire [PTRV_W-1:0] rptr_value = fifo_rptr_q[0+:PTRV_W];
      wire [PTRV_W-1:0] wptr_sync_value = fifo_wptr_sync_combi[0+:PTRV_W];

      assign rdepth_o = (full_rclk) ? Depth :
                        (wptr_sync_msb == rptr_msb) ? wptr_sync_value - rptr_value :
                        (Depth - rptr_value + wptr_sync_value);
    end else begin : g_no_depth_calc
      assign rdepth_o = full_rclk;
      assign wdepth_o = full_wclk;
    end
  endgenerate

  assign wready_o = ~full_wclk;
  assign rvalid_o = ~empty_rclk;

  // Storage
  wire [Width-1:0] rdata_int;
  
  generate
    if (Depth > 1) begin : g_storage_mux
      integer i;
      always @(posedge clk_wr_i or negedge rst_wr_ni) begin  // 添加复位
            if (!rst_wr_ni) begin
                // 复位时初始化所有存储单元
                for (i = 0; i < Depth; i = i + 1) begin
                    storage[i] <= {Width{1'b0}};
                end
            end else if (fifo_incr_wptr) begin
                storage[fifo_wptr_q[PTRV_W-1:0]] <= wdata_i;
            end
        end
      assign rdata_int = storage[fifo_rptr_q[PTRV_W-1:0]];
    end else begin : g_storage_simple
              always @(posedge clk_wr_i or negedge rst_wr_ni) begin  // 添加复位
            if (!rst_wr_ni) begin
                storage[0] <= {Width{1'b0}};
            end else if (fifo_incr_wptr) begin
                storage[0] <= wdata_i;
            end
        end
      assign rdata_int = storage[0];
    end
  endgenerate

  // Output qualification
  generate
    if (OutputZeroIfEmpty) begin : gen_output_zero
      if (OutputZeroIfInvalid)
        assign rdata_o = empty_rclk ? 0 : (rvalid_o ? rdata_int : 0);
      else
        assign rdata_o = empty_rclk ? 0 : rdata_int;
    end else begin : gen_no_output_zero
      if (OutputZeroIfInvalid)
        assign rdata_o = rvalid_o ? rdata_int : 0;
      else
        assign rdata_o = rdata_int;
    end
  endgenerate

  ////////////////////////////////
  // Decimal <-> Gray conversion
  ////////////////////////////////
  generate
    if (Depth > 2) begin : g_full_gray
      integer i;
      function [PTR_WIDTH-1:0] dec2gray;
        input [PTR_WIDTH-1:0] decval;
        reg [PTR_WIDTH-1:0] decval_sub, decval_in;
        reg unused_msb;
        begin
          decval_sub = Depth - {1'b0, decval[PTR_WIDTH-2:0]} - 1'b1;
          decval_in = decval[PTR_WIDTH-1] ? decval_sub : decval;
          unused_msb = decval_in[PTR_WIDTH-1];
          decval_in[PTR_WIDTH-1] = 0;
          dec2gray = decval_in ^ (decval_in >> 1);
          dec2gray[PTR_WIDTH-1] = decval[PTR_WIDTH-1];
        end
      endfunction

      function [PTR_WIDTH-1:0] gray2dec;
        input [PTR_WIDTH-1:0] grayval;
        reg [PTR_WIDTH-1:0] dec_tmp, dec_tmp_sub;
        reg unused_msb;
        begin
          dec_tmp = 0;
          for (i=PTR_WIDTH-1; i>0; i=i-1)
            dec_tmp[i-1] = dec_tmp[i] ^ grayval[i-1];
          dec_tmp_sub = Depth - dec_tmp - 1'b1;
          if (grayval[PTR_WIDTH-1]) begin
            gray2dec = dec_tmp_sub;
            gray2dec[PTR_WIDTH-1] = 1'b1;
            unused_msb = dec_tmp_sub[PTR_WIDTH-1];
          end else
            gray2dec = dec_tmp;
        end
      endfunction

      assign fifo_rptr_sync_combi = gray2dec(fifo_rptr_gray_sync);
      assign fifo_wptr_sync_combi = gray2dec(fifo_wptr_gray_sync);
      assign fifo_rptr_gray_d = dec2gray(fifo_rptr_d);
      assign fifo_wptr_gray_d = dec2gray(fifo_wptr_d);

    end else if (Depth == 2) begin : g_simple_gray
      assign fifo_rptr_sync_combi = {fifo_rptr_gray_sync[PTR_WIDTH-1], ^fifo_rptr_gray_sync};
      assign fifo_wptr_sync_combi = {fifo_wptr_gray_sync[PTR_WIDTH-1], ^fifo_wptr_gray_sync};
      assign fifo_rptr_gray_d = {fifo_rptr_d[PTR_WIDTH-1], ^fifo_rptr_d};
      assign fifo_wptr_gray_d = {fifo_wptr_d[PTR_WIDTH-1], ^fifo_wptr_d};
    end else begin : g_no_gray
      assign fifo_rptr_sync_combi = fifo_rptr_gray_sync;
      assign fifo_wptr_sync_combi = fifo_wptr_gray_sync;
      assign fifo_rptr_gray_d = fifo_rptr_d;
      assign fifo_wptr_gray_d = fifo_wptr_d;
    end
  endgenerate

endmodule
