`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/29 13:32:35
// Module Name: Baseline_Volt_Cal (Handshake Version)
// Description: Baseline voltage calculation with handshake-based
//              cross-clock domain transfer to UDP domain.
// 
//////////////////////////////////////////////////////////////////////////////////

module Baseline_Volt_Cal#(
    parameter ADC_WIDTH = 8,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 8
)(
    input [4:0] fee_mode,                
    input [4:0] sys_status,
    input  tx_req,
    input udp_clk,
    input sys_message_sending,
    input         sys_clk,               
    input         sys_rst_n,             
    input wire [ADC_CHANEL*DATAWIDTH-1:0] tx_data_fifo,     
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_baseline,     
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_noise,
    output reg [ADC_CHANEL*DATAWIDTH-1:0] udp_tx_data       
);

    // Mode/Status parameters
    localparam MODE_IDLE        = 4'd0;
    localparam MODE_CALIBRATION = 4'd1;
    localparam MODE_ACQUISITION = 4'd2;
    localparam STAT_WAIT = 4'd0;
    localparam STAT_INIT_FINISH = 4'd1;
    localparam STAT_MEASURE_START = 4'd2;
    localparam STAT_MEASURE_FINISH = 4'd3;
    localparam STAT_CLUSTER_FINGDING=4'd4;
    localparam STAT_CLUSTER_FINGDED = 4'd5;
    localparam STAT_DATA_ACQUIISITION = 4'd6;

    // Calibration / Message markers
    localparam [DATAWIDTH-1:0] CALIBRATION_MARKER = 16'h3456;
    localparam [DATAWIDTH-1:0] MESSAGE_MARKER = 16'h0666;

// ------------------------
// 系统时钟域 (sys_clk)
// ------------------------
reg [3*ADC_CHANEL*DATAWIDTH-1:0] sys_udp_tx_data;
reg data_valid_sys;    // 数据准备完成标志
reg ack_sys_clk;       // 来自 UDP 域的确认信号

reg [DATAWIDTH-1:0] baseline [ADC_CHANEL-1:0];
reg [DATAWIDTH-1:0] noise [ADC_CHANEL-1:0];

generate
    genvar i;
    for (i = 0; i < ADC_CHANEL; i = i + 1) begin : CHANNEL_PROCESSING
        localparam integer DATA_OFFSET = i * DATAWIDTH;
        localparam integer PACKET_OFFSET = i * 3 * DATAWIDTH;

        wire [3*DATAWIDTH-1:0] tx_data = 
            (sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) ?
            {adc_baseline[DATA_OFFSET +: DATAWIDTH], adc_noise[DATA_OFFSET +: DATAWIDTH], CALIBRATION_MARKER} :
            {16'h0, 11'h0, fee_mode, MESSAGE_MARKER};

        always @(posedge sys_clk or negedge sys_rst_n) begin
            if (!sys_rst_n) begin
                baseline[i] <= 0;
                noise[i] <= 0;
                sys_udp_tx_data[PACKET_OFFSET +: 3*DATAWIDTH] <= 0;
            end else if(!data_valid_sys || ack_sys_clk) begin
                // 更新数据前必须确认上一组数据已被 UDP 域读取
                sys_udp_tx_data[PACKET_OFFSET +: 3*DATAWIDTH] <= tx_data;
                if(sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) begin
                    baseline[i] <= adc_baseline[DATA_OFFSET +: DATAWIDTH];
                    noise[i] <= adc_noise[DATA_OFFSET +: DATAWIDTH];
                end
            end
        end
    end
endgenerate

// 更新数据有效标志
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        data_valid_sys <= 0;
    end else begin
        if(ack_sys_clk)
            data_valid_sys <= 0;
        else if(sys_message_sending || (sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION))
            data_valid_sys <= 1;
    end
end

// ------------------------
// UDP 时钟域 (udp_clk)
// ------------------------
reg data_valid_sys_sync1, data_valid_sys_sync2;
wire data_ready_udp;

// 同步 sys_clk 域的 tx_data_fifo 到 udp_clk 域
reg [ADC_CHANEL*DATAWIDTH-1:0] tx_data_fifo_sync1, tx_data_fifo_sync2;

always @(posedge udp_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        tx_data_fifo_sync1 <= 0;
        tx_data_fifo_sync2 <= 0;
    end else begin
        tx_data_fifo_sync1 <= tx_data_fifo;  // 同步信号到 udp_clk 域
        tx_data_fifo_sync2 <= tx_data_fifo_sync1;
    end
end
assign data_ready_udp = data_valid_sys_sync2;

// 双 flop 同步 data_valid_sys
always @(posedge udp_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        data_valid_sys_sync1 <= 0;
        data_valid_sys_sync2 <= 0;
    end else begin
        data_valid_sys_sync1 <= data_valid_sys;
        data_valid_sys_sync2 <= data_valid_sys_sync1;
    end
end

// UDP 数据缓冲寄存器
reg ack_udp;
reg [3*ADC_CHANEL*DATAWIDTH-1:0] udp_data_buffer;
reg [1:0] bit_sel;
reg FirstByte;
reg [10:0] package_cnt;

always @(posedge udp_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        udp_tx_data <= 0;
        ack_udp <= 0;
        udp_data_buffer <= 0;
        bit_sel <= 0;
        FirstByte <= 1'b1;
        package_cnt <= 0;
    end else begin
        if(data_ready_udp && !ack_udp) begin
            udp_data_buffer <= sys_udp_tx_data;  // 读取系统域数据
            if(tx_req)begin 
            udp_tx_data <= udp_data_buffer[bit_sel*DATAWIDTH*ADC_CHANEL +: DATAWIDTH*ADC_CHANEL];
        bit_sel <= bit_sel + 1;
            
            if(bit_sel == 2) begin
                bit_sel <= 0;
                ack_udp <= 1; // 发送确认
            end
            end
        end else if(!data_ready_udp&&tx_req&&fee_mode==MODE_ACQUISITION) begin
            ack_udp <= 0;
            // 正常ADC数据模式
            if (FirstByte) begin
                package_cnt <= package_cnt + 1'b1;
                udp_tx_data <= package_cnt;
                FirstByte <= 1'b0;
            end else begin
                udp_tx_data <= tx_data_fifo_sync2;  // 使用同步后的 tx_data_fifo 数据
            end
        end
        else if(!data_ready_udp)begin
                      ack_udp <= 0;  
        end
    end
end

// ------------------------
// ack 同步回系统域
// ------------------------
reg ack_sys_sync1, ack_sys_sync2;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        ack_sys_sync1 <= 0;
        ack_sys_sync2 <= 0;
        ack_sys_clk <= 0;
    end else begin
        ack_sys_sync1 <= ack_udp;
        ack_sys_sync2 <= ack_sys_sync1;
        ack_sys_clk <= ack_sys_sync2;
    end
end

endmodule
