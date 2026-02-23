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
parameter ADC_CHANEL=12,
parameter IsSplitData = 1'b1,
parameter REAL_DATA_WIDTH = 128,
parameter REAL_DATA_CHANEL=2
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
wire BadData = (adc_data_in == {ADC_CHANEL*ADC_WIDTH{1'b0}});

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
assign ADC_DATA =fifo_data_out;
wire [ADC_CHANEL*DATAWIDTH-1:0] all_channel_data;
 localparam LOGICAL_PER_PHY = ADC_CHANEL /REAL_DATA_CHANEL;
    generate
        genvar i;

        for (i = 0; i < ADC_CHANEL; i = i + 1) begin : CHANNEL_PACKING
            
            if (IsSplitData) begin
                // =========================================================
                // Mode A: Split Data Mode
                // One header and several other 32-bits date
                // =========================================================
                
                // 1. Calculate current logical index  i base on physical channel
                // For example i=0~4 -> Phy0; i=5~9 -> Phy1
                localparam PHY_ID = i / LOGICAL_PER_PHY;

                // 2. Current offset in group (0 is header , 1~N is data)
                localparam G_OFFSET = i % LOGICAL_PER_PHY;

                if ( i % LOGICAL_PER_PHY == 0) begin
                    // --->Header Channel <---
                    // [MagicNum] + [Reserved] + [PhyID]
                    wire [3:0] phy_id_bits = PHY_ID[3:0];
                    assign all_channel_data[i*DATAWIDTH +: DATAWIDTH] = {
                        16'hAAAA,        // [31:16] Magic Number ( header tag)
                        8'h00,           // [15:8]  Reserved / Counter
                        4'h0,            // [7:4]   Reserved
                        phy_id_bits      // [3:0]   Physical Channel ID
                    };
                end else begin
                    // ---> Data Chunk <---
                    // DataShitft = Current group shift- 1 (packet head is 0)
                    localparam DATA_SLICE_IDX = G_OFFSET - 1;
                    
                    
                    // Bit Start = (Physical Channel ID * Physical Datawidth) + (Slice ID * Scile Data Width)
                    wire [31:0] BIT_START = (PHY_ID * REAL_DATA_WIDTH) + (DATA_SLICE_IDX * DATAWIDTH);

                    assign all_channel_data[i*DATAWIDTH +: DATAWIDTH] =   adc_data_in[BIT_START +: DATAWIDTH];
                end

            end else begin
                // =========================================================
                // 模式 B:Standard Packing Mode
                // =========================================================
                wire [3:0] channel_id = i[3:0];
                localparam PADDING_WIDTH = DATAWIDTH - ADC_WIDTH - 4; 
                
                assign all_channel_data[i*DATAWIDTH +: DATAWIDTH] = {
                    {(PADDING_WIDTH){1'b0}},                 // 高位填充
                    channel_id,                              // 通道ID
                    adc_data_in[i*ADC_WIDTH +: ADC_WIDTH]    // 原始数据
                };
            end
        end
    endgenerate


localparam Depth = 4;
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
    .wvalid_i   (fifo_wr_en&&!BadData),
    .wready_o   (write_ready),
    .wdata_i    (all_channel_data),
    .wdepth_o   (write_depth),
    
    // 读端口
    .clk_rd_i   (sys_clk),
    .rst_rd_ni  (rst_test[1]),
    .rvalid_o   (read_valid),
    .rready_i   (data_req && !fifo_empty),
    .rdata_o    (fifo_data_out),
    .rdepth_o   (read_depth)
);
assign fifo_full = (write_depth == 11'd64);  // 深度达到最大值时为满
assign fifo_empty = (read_depth == 11'd0);     // 深度为0时为空
endmodule
