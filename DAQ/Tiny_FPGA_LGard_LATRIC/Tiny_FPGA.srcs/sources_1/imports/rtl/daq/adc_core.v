`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/30 13:46:36
// Design Name: 
// Module Name: adc_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module adc_core
#(
parameter ADC_WIDTH=30,
parameter DATAWIDTH=16,
parameter ADC_CHANEL=12
)
(
    input adc_clk,
    input rst_n,
    input  [ADC_CHANEL*ADC_WIDTH-1:0] adc_data_in,
    input fifo_wr_en,
    input sys_clk,

    // FIFO interface
    output [ADC_CHANEL*DATAWIDTH-1:0] ADC_DATA,
    output fifo_full,
    output fifo_empty,

    // Control
    input [4:0] fee_mode,
    input [4:0] sys_status,
    input data_accepted_rib
   // output reg [15:0] adc_value
);
reg data_req;
        
reg rst_s1_udp, rst_s2_udp;
reg fifo_empty_sync;
wire udp_rst_n_sync;
wire [ADC_CHANEL*DATAWIDTH-1:0] fifo_data_out;

always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_s1_udp <= 1'b0;
        rst_s2_udp <= 1'b0;
        fifo_empty_sync <=1'b0;
    end else begin
        rst_s1_udp <= 1'b1;
        rst_s2_udp <= rst_s1_udp;
        fifo_empty_sync <=fifo_empty;
    end
end
assign udp_rst_n_sync = rst_s2_udp;
// 新增状态检测信号
reg data_req_d1;          // data_req延迟一拍
reg fifo_empty_d1;        // fifo_empty延迟一拍
reg was_empty_before_req; // 记录请求前的空状态
reg data_valid;           // 数据有效标志

// 简化的数据有效判断逻辑
// 数据有效判断逻辑
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        data_req_d1 <= 1'b0;
        fifo_empty_d1 <= 1'b1;
        was_empty_before_req <= 1'b1;
        data_valid <= 1'b0;
    end else begin
        data_req_d1 <= data_req;
        fifo_empty_d1 <= fifo_empty;
        
        if (data_req && !data_req_d1) begin
            was_empty_before_req <= fifo_empty;
        end
        
        if (data_req_d1) begin
            data_valid <= !was_empty_before_req;
        // data_valid <= ! fifo_empty_d1;
        end 
    end
end

reg [4:0] sys_status_prev;
    // ADC data processing
always @(posedge sys_clk or negedge udp_rst_n_sync) begin
    if (!udp_rst_n_sync) begin
        data_req <= 1'b0;
        sys_status_prev <= 3'd0;  // 状态寄存器
    end 
    else begin
        // 保存前一个周期的sys_status用于边沿检测
        sys_status_prev <= sys_status;
       // data_req <= tx_req;
        
        // 上升沿检测逻辑
        if (sys_status_prev != sys_status && sys_status == 4'd6) begin 
            data_req <= 1'b1;
        end
        else if (data_accepted_rib)
            data_req <= 1'b0;
        else 
            data_req <= 1'b0;
    end
end
assign ADC_DATA = fifo_data_out;

// =========================================================================
// Protocol Injection FSM
//   Replaces channel packing with protocol-formatted FIFO words.
//   Generates 3 FIFO words per coincidence event:
//     Word 0 (envelope): {0xAAAA, type=0x03, reserved=0x00, pkt_counter}
//     Word 1 (record p1): {0x7DC2, time_diff_ps, data_flags}
//     Word 2 (record p2): {ch1_err, ch2_err, padding}
//
// adc_data_in field map (packed by tinyriscv_soc_top):
//   [15:0]   = time_diff_ps_out (16 bits)
//   [19:16]  = 4'b0 padding
//   [28:20]  = data_flag[8:0]
//   [29]     = ch1_decode_err
//   [38:30]  = data_flag[17:9]
//   [39]     = ch2_decode_err
// =========================================================================
localparam FIFO_WIDTH = ADC_CHANEL * DATAWIDTH;

reg [ADC_CHANEL*ADC_WIDTH-1:0] evt_data_r;
reg [15:0] pkt_counter;
reg [1:0]  inj_state;
reg [FIFO_WIDTH-1:0] fifo_wr_data;
reg fifo_wr_valid;

wire [15:0] evt_time_diff  = evt_data_r[15:0];
wire [8:0]  evt_flags_lo   = evt_data_r[28:20];
wire        evt_ch1_err    = evt_data_r[29];
wire [8:0]  evt_flags_hi   = evt_data_r[38:30];
wire        evt_ch2_err    = evt_data_r[39];
wire [15:0] evt_data_flags = {evt_flags_hi[6:0], evt_flags_lo};

always @(posedge adc_clk or negedge rst_n) begin
    if (!rst_n) begin
        inj_state      <= 2'd0;
        pkt_counter    <= 16'd0;
        fifo_wr_valid  <= 1'b0;
        fifo_wr_data   <= {FIFO_WIDTH{1'b0}};
        evt_data_r     <= {(ADC_CHANEL*ADC_WIDTH){1'b0}};
    end else begin
        case (inj_state)
            2'd0: begin // IDLE — wait for new event
                fifo_wr_valid <= 1'b0;
                if (fifo_wr_en && !fifo_full) begin
                    evt_data_r <= adc_data_in;
                    inj_state  <= 2'd1;
                end
            end

            2'd1: begin // Word 0 — envelope
                fifo_wr_data  <= {16'hAAAA, 8'h03, 8'h00, pkt_counter};
                fifo_wr_valid <= 1'b1;
                inj_state     <= 2'd2;
            end

            2'd2: begin // Word 1 — coincidence record first 6 bytes
                fifo_wr_data  <= {16'h7DC2, evt_time_diff, evt_data_flags};
                fifo_wr_valid <= 1'b1;
                inj_state     <= 2'd3;
            end

            2'd3: begin // Word 2 — coincidence record last 2 bytes + padding
                fifo_wr_data  <= {{7'b0, evt_ch1_err},
                                   {7'b0, evt_ch2_err},
                                   {(FIFO_WIDTH - 16){1'b0}}};
                fifo_wr_valid <= 1'b1;
                pkt_counter   <= pkt_counter + 16'd1;
                inj_state     <= 2'd0;
            end

            default: begin
                inj_state     <= 2'd0;
                fifo_wr_valid <= 1'b0;
            end
        endcase
    end
end


localparam Depth = 64;
wire write_ready;
(* MARK_DEBUG="true" *)wire [ $clog2(Depth+1)-1:0] write_depth;
(* MARK_DEBUG="true" *)wire [ $clog2(Depth+1)-1:0] read_depth;
wire read_valid;
wire [1:0] rst_test;
cdc_sync_level  rst1(
    .clk_dest(adc_clk),
    .rst_dest_n(rst_n),
    .data_src(rst_n),
    .data_dest(rst_test[0])
);
cdc_sync_level  rst2(
    .clk_dest(sys_clk),
    .rst_dest_n(rst_n),
    .data_src(rst_n),
    .data_dest(rst_test[1])
);

prim_fifo_async #(
    .Width(ADC_CHANEL*DATAWIDTH),      // 数据位宽32位
    .Depth(Depth)       // FIFO深度1024（必须为2的幂）
) u_async_fifo (
    // 写端口
    .clk_wr_i   (adc_clk),
    .rst_wr_ni  (rst_test[0]),
    .wvalid_i   (fifo_wr_valid),
    .wready_o   (write_ready),
    .wdata_i    (fifo_wr_data),
    .wdepth_o   (write_depth),
    
    // 读端口
    .clk_rd_i   (sys_clk),
    .rst_rd_ni  (rst_test[1]),
    .rvalid_o   (read_valid),
    .rready_i   (data_req && !fifo_empty),
    .rdata_o    (fifo_data_out),
    .rdepth_o   (read_depth)
);
assign fifo_full = (write_depth == Depth);  // 深度达到最大值时为满
assign fifo_empty = (read_depth == 0);     // 深度为0时为空
endmodule
