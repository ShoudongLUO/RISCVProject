`timescale 1ns / 1ps

module DataPack_AFIFO#(
    parameter ADC_WIDTH = 8,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 8,
    parameter FIFO_DEPTH = 16 
)(
    input [4:0] fee_mode,
    input [4:0] sys_status,
    input  tx_req,         // 来自 udp_clk 域，表示下游准备好接收
    input udp_clk,
    input sys_message_sending,
    input         sys_clk,
    input         sys_rst_n,             
    input wire [ADC_CHANEL*DATAWIDTH-1:0] tx_data_fifo,     
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_baseline,     
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_noise,
    output reg [ADC_CHANEL*DATAWIDTH-1:0] udp_tx_data       
);

// Mode/Status parameters [cite: 4-7]
localparam MODE_IDLE        = 4'd0;
localparam MODE_CALIBRATION = 4'd1;
localparam MODE_ACQUISITION = 4'd2;
localparam STAT_WAIT = 4'd0;
localparam STAT_INIT_FINISH = 4'd1;
localparam STAT_MEASURE_START = 4'd2;
localparam STAT_MEASURE_FINISH = 4'd3;

// Calibration / Message markers [cite: 7]
localparam [DATAWIDTH-1:0] CALIBRATION_MARKER = 16'h3456;
localparam [DATAWIDTH-1:0] MESSAGE_MARKER = 16'h0666;

localparam FIFO_DEPTH_WIDTH = $clog2(FIFO_DEPTH);
localparam FIFO_WIDTH = ADC_CHANEL*DATAWIDTH;

// -----------------------------------------------------
// 1. 异步FIFO
// -----------------------------------------------------
wire       fifo_wvalid; // 写有效
wire       fifo_wready; // 写准备好 (FIFO 不满)
wire [FIFO_WIDTH-1:0] fifo_wdata;  // 写数据
wire [FIFO_DEPTH_WIDTH-1:0] fifo_wdepth;

wire       fifo_rvalid; // 读有效 (FIFO 不空)
wire       fifo_rready; // 读准备好 
wire [FIFO_WIDTH-1:0] fifo_rdata;  // 读数据
wire [FIFO_DEPTH_WIDTH-1:0] fifo_rdepth;

// -----------------------------------------------------
// 2. 跨时钟域复位同步 
// -----------------------------------------------------
// 为 sys_clk 域同步复位
reg rst_wr_n_sync1, rst_wr_n_sync2;
wire rst_wr_n = rst_wr_n_sync2;
always @(posedge sys_clk) begin
    rst_wr_n_sync1 <= sys_rst_n;
    rst_wr_n_sync2 <= rst_wr_n_sync1;
end

// 为 udp_clk 域同步复位
reg rst_rd_n_sync1, rst_rd_n_sync2;
wire rst_rd_n = rst_rd_n_sync2;
always @(posedge udp_clk) begin
    rst_rd_n_sync1 <= sys_rst_n;
    rst_rd_n_sync2 <= rst_rd_n_sync1;
end


// -----------------------------------------------------
// 3. 系统时钟域 (sys_clk) - 统一的数据打包和FIFO写入
// -----------------------------------------------------

// 状态机，用于处理多周期的数据包（如校准）
reg [1:0] cal_state;
localparam CAL_S_IDLE = 2'd0;
localparam CAL_S_BASE = 2'd1;
localparam CAL_S_NOISE = 2'd2;
localparam CAL_S_MARK = 2'd3;

reg msg_pending; // 消息发送标志
reg acq_first_word; // 采集模式的包计数器标志
reg [10:0] package_cnt_sys; // 包计数器 (在sys_clk域)

// 构建校准和消息的Marker word
wire [FIFO_WIDTH-1:0] cal_marker_word;
wire [FIFO_WIDTH-1:0] msg_marker_word;
generate
    genvar i;
    for (i = 0; i < ADC_CHANEL; i = i + 1) begin : MARKER_BUILD
        localparam integer DATA_OFFSET = i * DATAWIDTH;
        assign cal_marker_word[DATA_OFFSET +: DATAWIDTH] = CALIBRATION_MARKER;
        assign msg_marker_word[DATA_OFFSET +: DATAWIDTH] = MESSAGE_MARKER;
    end
endgenerate

// --- 状态机和计数器 ---
always @(posedge sys_clk or negedge rst_wr_n) begin
    if (!rst_wr_n) begin
        cal_state <= CAL_S_IDLE;
        msg_pending <= 1'b0;
        acq_first_word <= 1'b1;
        package_cnt_sys <= 'd0;
    end else begin
        
        // 1. 处理高优先级触发 (校准和消息)
        if (cal_state == CAL_S_IDLE && msg_pending == 1'b0) begin
            if (sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) begin
                cal_state <= CAL_S_BASE;
                acq_first_word <= 1'b1; // 重置采集包
            end else if (sys_message_sending) begin
                msg_pending <= 1'b1;
                acq_first_word <= 1'b1; // 重置采集包
            end
        end
        
        // 2. 推进校准状态 (当FIFO准备好时)
        if (cal_state != CAL_S_IDLE && fifo_wready) begin
            case (cal_state)
                CAL_S_BASE:  cal_state <= CAL_S_NOISE;
                CAL_S_NOISE: cal_state <= CAL_S_MARK;
                CAL_S_MARK:  cal_state <= CAL_S_IDLE;
            endcase
        end
        
        // 3. 推进消息状态 (当FIFO准备好时)
        if (msg_pending && fifo_wready) begin
            msg_pending <= 1'b0;
        end
        
        // 4. 推进采集状态 (当FIFO准备好且无高优任务)
        if (cal_state == CAL_S_IDLE && !msg_pending && fee_mode == MODE_ACQUISITION && fifo_wready) begin
            if (acq_first_word) begin
                // 刚发送了包计数器，下一拍发送数据
                acq_first_word <= 1'b0;
                package_cnt_sys <= package_cnt_sys + 1; // 增加包计数 
            end else begin
                // 刚发送了数据，下一拍发送新的包计数器
                acq_first_word <= 1'b1;
            end
        end
        
        // 如果退出采集模式，重置包计数器
        if (fee_mode != MODE_ACQUISITION) begin
            acq_first_word <= 1'b1;
        end
    end
end

// --- 组合逻辑: 数据多路选择器 (MUX) ---
// 根据优先级选择要写入FIFO的数据
assign fifo_wdata = 
    (cal_state == CAL_S_BASE)  ? adc_baseline :
    (cal_state == CAL_S_NOISE) ? adc_noise :
    (cal_state == CAL_S_MARK)  ? cal_marker_word :
    (msg_pending)              ? msg_marker_word :
    (fee_mode == MODE_ACQUISITION) ? 
        (acq_first_word ? {{(FIFO_WIDTH-11){1'b0}}, package_cnt_sys} : tx_data_fifo) :
    'd0;

// --- 组合逻辑: 写有效信号 ---
assign fifo_wvalid = 
    (cal_state != CAL_S_IDLE) || 
    (msg_pending) || 
    (fee_mode == MODE_ACQUISITION);


// -----------------------------------------------------
// 4. UDP 时钟域 (udp_clk) - 极简的FIFO读取
// -----------------------------------------------------

// 我们想要读 (rready) 取决于下游 (tx_req)
assign fifo_rready = tx_req;

always @(posedge udp_clk or negedge rst_rd_n) begin
    if (!rst_rd_n) begin
        udp_tx_data <= 'd0;
    end else begin
        // 当下游准备好，且FIFO中有数据
        if (fifo_rready && fifo_rvalid) begin
            udp_tx_data <= fifo_rdata;
        end 
        // 当下游准备好，但FIFO是空的 (欠载)
        else if (fifo_rready) begin
            udp_tx_data <= 'd0; // 发送空包
        end
        // 如果下游没准备好 (tx_req=0)，udp_tx_data 保持不变
    end
end


// -----------------------------------------------------
// 5. 异步 FIFO 实例化
// -----------------------------------------------------
prim_fifo_async #(
    .Width(FIFO_WIDTH), // 数据位宽
    .Depth(FIFO_DEPTH)  // FIFO深度
) u_async_fifo (
    // 写端口 (sys_clk 域)
    .clk_wr_i  (sys_clk),
    .rst_wr_ni (rst_wr_n), // 使用同步后的复位
    .wvalid_i  (fifo_wvalid && fifo_wready), // 仅在FIFO不满时写入
    .wready_o  (fifo_wready),
    .wdata_i   (fifo_wdata),
    .wdepth_o  (fifo_wdepth),
    
    // 读端口 (udp_clk 域)
    .clk_rd_i  (udp_clk),
    .rst_rd_ni (rst_rd_n), // 使用同步后的复位
    .rvalid_o  (fifo_rvalid),
    .rready_i  (fifo_rready && fifo_rvalid), // 仅在FIFO不空时读取
    .rdata_o   (fifo_rdata),
    .rdepth_o  (fifo_rdepth)
);

endmodule