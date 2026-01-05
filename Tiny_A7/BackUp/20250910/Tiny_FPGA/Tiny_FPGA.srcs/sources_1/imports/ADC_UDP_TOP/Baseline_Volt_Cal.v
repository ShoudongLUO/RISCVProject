`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/29 13:32:35
// Design Name: 
// Module Name: Baseline_Volt_Cal
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

 module Baseline_Volt_Cal#(
        parameter ADC_WIDTH = 8,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 8
    )(
    input [4:0] fee_mode,                // Fee mode control input 
    input [4:0] sys_status,
    input  tx_req,
    input udp_clk,
    input rec_data_fifo,
    // RIB bus interface
    input         sys_clk,               // System Clock signal
    input         sys_rst_n,             // Active low reset signal
    input wire [ADC_CHANEL*DATAWIDTH-1:0] tx_data_fifo,     // Input ADC data from FIFO
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_baseline,     // Baseline value for comparison
    input wire [ADC_CHANEL*DATAWIDTH-1:0] adc_noise,
    output reg [ADC_CHANEL*DATAWIDTH-1:0] udp_tx_data       // Output data to UDP
);

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
// Internal wire to hold the ADC difference
    wire [ADC_CHANEL*DATAWIDTH-1:0] adc_diff;




reg sys_meas;
reg [DATAWIDTH-1:0]baseline [ADC_CHANEL-1:0];
reg [DATAWIDTH-1:0]noise [ADC_CHANEL-1:0];
reg signal;
reg test;

// Handle reset and clocking to calculate the output

reg sys_data_valid_sync;
reg [3*ADC_CHANEL*DATAWIDTH-1:0] sys_udp_tx_data_sync;
reg [3*ADC_CHANEL*DATAWIDTH-1:0] sys_udp_tx_data;
reg tx_req_sync;
reg tx_req_pulse;
reg message_sended[1:0];
//reg sys_message_sending_sync[1:0];

// 系统时钟域 (50MHz)

// 预计算数据包格式
localparam [DATAWIDTH-1:0] CALIBRATION_MARKER = 16'h3456;
localparam [DATAWIDTH-1:0] MESSAGE_MARKER = 16'h666;

generate
    genvar i;
    for (i = 0; i < ADC_CHANEL; i = i + 1) begin : CHANNEL_PROCESSING
        // 预计算数据段偏移
        localparam integer DATA_OFFSET = i * DATAWIDTH;
        localparam integer PACKET_OFFSET = i * 3 * DATAWIDTH;
        
        // 组合逻辑选择数据
        wire [3*DATAWIDTH-1:0] tx_data = 
            (sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) ?
            {adc_baseline[DATA_OFFSET +: DATAWIDTH], 
             adc_noise[DATA_OFFSET +: DATAWIDTH], 
             CALIBRATION_MARKER} :
            {16'h0, 11'h0, fee_mode, MESSAGE_MARKER};
        
        // 时序逻辑更新
        always @(posedge sys_clk or negedge sys_rst_n) begin
            if (!sys_rst_n) begin
                sys_udp_tx_data[PACKET_OFFSET +: 3*DATAWIDTH] <= 0;
                baseline[i] <= 0;
                noise[i] <= 0;
            end else if ((sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION)) begin
                sys_udp_tx_data[PACKET_OFFSET +: 3*DATAWIDTH] <= tx_data;
                if (sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) begin
                    baseline[i] <= adc_baseline[DATA_OFFSET +: DATAWIDTH];
                    noise[i] <= adc_noise[DATA_OFFSET +: DATAWIDTH];
                end
            end
        end
    end
endgenerate

// UDP时钟域 (125MHz)
reg tx_req_dly;
reg [1:0]bit_sel;
reg FirstByte;
reg [10:0]package_cnt;
always @(posedge udp_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        udp_tx_data <= 0;
        sys_udp_tx_data_sync <= 0;
        sys_data_valid_sync <= 0;
        tx_req_sync <= 0;
        tx_req_pulse <= 0;
        tx_req_dly <= 0;
        bit_sel <=2'b0;
        FirstByte <=1'b1;
        package_cnt <=0;
    end else begin
        sys_udp_tx_data_sync <= sys_udp_tx_data;
        sys_data_valid_sync <= ((sys_status == STAT_MEASURE_FINISH && fee_mode == MODE_CALIBRATION) );
        if(!sys_data_valid_sync) bit_sel <=2'b0;
        // 数据选择逻辑
        if (tx_req) begin
            if (sys_data_valid_sync) begin
                // 使用来自系统域的有效数据
                udp_tx_data <=sys_udp_tx_data_sync[bit_sel*DATAWIDTH*ADC_CHANEL +: DATAWIDTH*ADC_CHANEL];
                bit_sel <=bit_sel +1'b1;
                if(bit_sel==2'd2)bit_sel<=2'b0;
            end else begin
                // 正常ADC数据模式
                if(FirstByte)begin
                package_cnt <= package_cnt +1'b1;
                udp_tx_data <= package_cnt;
                FirstByte <= 1'b0;
                end
                else
                udp_tx_data <= tx_data_fifo;
            end
        end
    end
end

endmodule
