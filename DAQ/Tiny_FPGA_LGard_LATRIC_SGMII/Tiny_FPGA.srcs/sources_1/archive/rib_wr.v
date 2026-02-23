`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/30 18:31:42
// Design Name: 
// Module Name: rib_sigle_channel
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


module rib_wr#(
        parameter ADC_WIDTH = 12,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 20
    )
(
    // System Interface
    input         rib_clk,
    input         rib_rst_n,

    input  [4:0]  fee_mode,
    output reg [4:0]  sys_status,
    output reg [4:0] cfg_fee_mode,
    // RIB Bus Interface
    input  [31:0] rib_addr,
    input  [31:0] rib_data_i,
    input         rib_we,
    output reg [31:0] rib_data_o,
    // UDP Configuration
    output reg [15:0] cfg_tx_data_num,
    output reg        cfg_udp_tx_enable,
    output reg [31:0] cfg_board_ip,
    output reg [31:0] cfg_des_ip,
    output reg [15:0] cfg_board_port,
    output reg [15:0] cfg_des_port,
    output reg        cfg_fifo_wr_en,
    input  wire         udp_tx_req,
    // ADC Interface
    input  wire   [ADC_CHANEL*DATAWIDTH-1:0] adc_value,

    output reg [ADC_CHANEL*DATAWIDTH-1:0] adc_test,
    output reg [3:0]  cfg_adc_width,
    output reg [5:0]  cfg_datawidth,
    output reg [21:0] cfg_num_channels,
    output reg [ADC_CHANEL*DATAWIDTH-1:0] cal_adc_value,

    // Baseline Voltage Interface
    output reg  [ADC_CHANEL*DATAWIDTH-1:0] baseline_rib_data,
    output reg  [ADC_CHANEL*DATAWIDTH-1:0] adc_noise,
    output reg  data_accepted_rib

);

    // Register Address Map (consistent with original adc.v)
localparam REG_UDP_CONFIG    = 6'h10;  // W/R: [17]=fifo_wr_en, [16]=udp_tx_enable, [15:0]=tx_data_num
localparam REG_BOARD_IP      = 6'h14;  // W/R: 本机IP地址
localparam REG_DES_IP        = 6'h18;  // W/R: 目标IP地址
localparam REG_BOARD_PORT    = 6'h1C;  // W/R: 本机端口
localparam REG_DES_PORT      = 6'h20;  // W/R: 目标端口
localparam REG_ADC_CONFIG    = 6'h24;
localparam REG_SYS_STATUS    = 6'h28; //System status, 1:Initialization finished; 2: Start Measure Mode; 3:Finish Measure Mode;
                                       //               4:Start Cluster Finding  ; 5: Finish Cluster Finding ; 6: Data Acquirision
localparam ADC_TEST          = 16'h2C;  // W/R: 测试寄存器
localparam REG_SYS_MODE      = 16'h30;   // System mode control 
localparam REG_ADC_DATA      = 16'h1000; // W/R: ADC 数据
localparam REG_ADC_BASELINE  = 16'h2000; // W/R: 计算得到的基准电压
localparam REG_ADC_NOISE     = 16'h3000; // W/R: Noise 值


// Mode Definitions
    localparam MODE_IDLE        = 5'd0;
    localparam MODE_CALIBRATION = 5'd1;
    localparam MODE_ACQUISITION = 5'd2;

// Status Definitions
    localparam STAT_WAIT = 4'd0;
    localparam STAT_INIT_FINISH = 4'd1;
    localparam STAT_MEASURE_START = 4'd2;
    localparam STAT_MEASURE_FINISH = 4'd3;
    localparam STAT_CLUSTER_FINGDING=4'd4;
    localparam STAT_CLUSTER_FINGDED = 4'd5;
    localparam STAT_DATA_ACQUIISITION = 4'd6;
    localparam STAT_UDP_REQ_WAIT = 4'd7;
    localparam STAT_UDP_REQ = 4'd8;


    wire [DATAWIDTH-1:0] adc_channel [0:ADC_CHANEL-1];
    wire [DATAWIDTH-1:0] baseline_channel [0:ADC_CHANEL-1];
    wire [DATAWIDTH-1:0] noise_channel [0:ADC_CHANEL-1];
    
    generate
        genvar i;
        for (i = 0; i < ADC_CHANEL; i=i+1) begin: ADC_CHANNEL_ASSIGNMENT
            assign adc_channel[i] = adc_value[i*DATAWIDTH +: DATAWIDTH];
            assign baseline_channel[i] = baseline_rib_data[i*DATAWIDTH +: DATAWIDTH];
            assign noise_channel[i] = adc_noise[i*DATAWIDTH +: DATAWIDTH];
        end
    endgenerate
wire [8:0] Nwrite_adc;
wire [15:0] adc_test_index;
assign Nwrite_adc = rib_addr[11:0] >> 3;
assign adc_test_index = rib_addr[15:0] - ADC_TEST;

    // Register Write Logic
    always @(posedge rib_clk or negedge rib_rst_n) begin
        if (!rib_rst_n) begin
            // Initialize all writable registers
            adc_test          <= 32'h0;
            cfg_tx_data_num   <= 12'd100;
            cfg_udp_tx_enable <= 1'b1;
            cfg_board_ip      <= {8'd192,8'd168,8'd185,8'd111};
            cfg_des_ip        <= {8'd192,8'd168,8'd185,8'd243};
            cfg_fifo_wr_en    <= 1'b0;
            cfg_board_port    <=12'd1234;
            cfg_des_port      <=12'd1234;
            cal_adc_value     <=0;
            baseline_rib_data <=0;
            adc_noise         <=0;
            sys_status        <=5'd0;
            cfg_adc_width     <= 0;
            cfg_datawidth     <= 0;
            cfg_num_channels  <= 0;
            cfg_fee_mode      <=5'd1;
        end
        else begin
            if (rib_we) begin
                case (rib_addr[15:0])
                    REG_UDP_CONFIG: begin
                        cfg_tx_data_num   <= rib_data_i[15:0];// Low 16 bits for tx_data_num
                        cfg_udp_tx_enable <= rib_data_i[16];// Bit 16 for UDP transmission enable
                        cfg_fifo_wr_en    <= rib_data_i[17]; // Bit 17 for FIFO write enable
                    end
                    REG_BOARD_IP: cfg_board_ip <= rib_data_i;
                    REG_DES_IP:   cfg_des_ip   <= rib_data_i;
                    REG_BOARD_PORT: cfg_board_port <=rib_data_i;
                    REG_DES_PORT:  cfg_des_port <=rib_data_i;
                    REG_ADC_CONFIG: begin
                        cfg_adc_width  <=rib_data_i[3:0] ;//low 4bit for adc_width
                        cfg_datawidth  <=rib_data_i[9:4]; //Mid 4 Bit  for datawidth
                        cfg_num_channels <=rib_data_i[31:10]; //other for numnber of adc channels
                    end
                    REG_SYS_STATUS:  sys_status <=  rib_data_i[4:0];
                    REG_SYS_MODE :    cfg_fee_mode <=rib_data_i[4:0];

                 /*   REG_ADC_DATA : begin
                          cal_adc_value[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= rib_data_i[DATAWIDTH-1:0];  
                          if(Nwrite_adc<ADC_CHANEL)Nwrite_adc <=Nwrite_adc+1'b1;
                          else Nwrite_adc<=0;

                    end*/
                    default: begin
                        // ADC Data Region (0x1000-0x1FFF)
                        if (rib_addr[15:12] == REG_ADC_DATA[15:12]) begin
                            cal_adc_value[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= rib_data_i[DATAWIDTH-1:0];

                        end
                        // Baseline Region (0x2000-0x2FFF)
                        else if (rib_addr[15:12] == REG_ADC_BASELINE[15:12]) begin
                            baseline_rib_data[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= rib_data_i[DATAWIDTH-1:0];
                        end
                        // Noise Region (0x3000-0x3FFF)
                        else if (rib_addr[15:12] == REG_ADC_NOISE[15:12]) begin
                            adc_noise[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= rib_data_i[DATAWIDTH-1:0];
                        end
                        else if (rib_addr[15:0] >= ADC_TEST && rib_addr[15:0] < ADC_TEST + ADC_CHANEL) begin
                            adc_test[adc_test_index *DATAWIDTH +: DATAWIDTH] <= rib_data_i[DATAWIDTH-1:0];
                        end
                    end
                endcase
            end
        end

    end

    // Register Read Logic
    always @(*) begin
         if (!rib_rst_n) begin

         end
    //    adc_test<={28'h0,fee_mode};
            data_accepted_rib <=1'b0;
        case (rib_addr[15:0])
            ADC_TEST: begin
            if (ADC_CHANEL == 1) begin
                rib_data_o = {16'b0, adc_test[DATAWIDTH-1:0]}; // 单通道直接读
            end
            // 多通道需要配合地址偏移
            else if (rib_addr[15:0] >= ADC_TEST && rib_addr[15:0] < ADC_TEST + ADC_CHANEL) begin
                rib_data_o = {16'b0, adc_test[(rib_addr[3:0]*DATAWIDTH) +: DATAWIDTH]};
            end
            else begin
                rib_data_o = 32'h0; // 默认值
            end
        end
            REG_UDP_CONFIG:rib_data_o = {14'h0, cfg_fifo_wr_en, cfg_udp_tx_enable, cfg_tx_data_num};
            REG_BOARD_IP: rib_data_o = cfg_board_ip;
            REG_DES_IP:   rib_data_o = cfg_des_ip;
            REG_BOARD_PORT: rib_data_o =cfg_board_port ;
            REG_DES_PORT: rib_data_o =cfg_des_port;
            REG_ADC_CONFIG:rib_data_o ={cfg_num_channels,cfg_datawidth,cfg_adc_width};
            REG_SYS_STATUS: if(fee_mode== MODE_CALIBRATION && sys_status != STAT_MEASURE_FINISH)begin
                                rib_data_o =STAT_MEASURE_START;
                            end
                            else if (fee_mode==MODE_IDLE) begin
                                rib_data_o = STAT_WAIT;
                            end
                            else if(fee_mode == MODE_ACQUISITION)begin
                                    rib_data_o =STAT_CLUSTER_FINGDING;
                                    if(sys_status==STAT_UDP_REQ_WAIT)begin
                                    rib_data_o = (udp_tx_req)?STAT_UDP_REQ:32'd0;
                                    end

                            end


            default: begin
                // ADC Data Region (0x1000-0x1FFF)
                if (rib_addr[15:12] == REG_ADC_DATA[15:12]) begin
                    rib_data_o = {16'b0, adc_channel[(rib_addr[11:0]>>3)]};
                    data_accepted_rib <=1'b1;
                end
                // Baseline Region (0x2000-0x2FFF)
               else if (rib_addr[15:12] == REG_ADC_BASELINE[15:12]) begin
                    rib_data_o = {16'b0, baseline_channel[(rib_addr[11:0]>>3)]};
                end
                // Noise Region (0x3000-0x3FFF)
               else if (rib_addr[15:12] == REG_ADC_NOISE[15:12]) begin
                    rib_data_o = {16'b0, noise_channel[(rib_addr[11:0]>>3)]};
                end
                else begin
                    rib_data_o = 32'hDEADBEEF; // Debug value
                end
            end
        endcase
        
    end

endmodule
