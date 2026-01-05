`timescale 1ns / 1ps

module ADC_UDP_top #(
    parameter ADC_WIDTH = 12,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 20
)(
    // System clocks and reset
    input clk,           // System clock (50MHz)
    input clk_udp,       // UDP clock (125MHz)
    input rst,           // Active low reset
    
    // RIB Bus Interface (from processor)
    input [31:0] s7_addr_o,
    input [31:0] s7_data_o,
    input s7_we_o,
    output [31:0] s7_data_i,
    
    
    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,
    // ADC Input
    input [ADC_CHANEL*ADC_WIDTH-1:0] rec_ADC_data,
    (* MARK_DEBUG="true" *)input wire adc_data_ready,
    // Ethernet PHY Interface (RGMII)
    output eth_txc,      // RGMII发送数据时钟
    output eth_tx_ctl,   // RGMII输出数据有效信号
    output eth_rst_n,    // PHY reset (active low)
    output [3:0] eth_txd // RGMII输出数据
   
);

    // Internal wire definitions
    wire [4:0] sys_status;
    (* MARK_DEBUG="true" *)wire [4:0] fee_mode;

    // UDP Configuration
    wire [15:0] cfg_tx_data_num;
    (* MARK_DEBUG="true" *)wire cfg_udp_tx_enable;
    wire [31:0] cfg_board_ip;
    wire [31:0] cfg_des_ip;
    wire [15:0] cfg_board_port;
    wire [15:0] cfg_des_port;
   (* MARK_DEBUG="true" *) wire cfg_fifo_wr_en;

    // ADC and Data Interface
    wire [ADC_CHANEL*DATAWIDTH-1:0] baseline_rib_data;
    wire [ADC_CHANEL*DATAWIDTH-1:0] adc_noise;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] cal_adc_value;
    wire [ADC_CHANEL*DATAWIDTH-1:0] adc_test;
    wire data_accepted_rib;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*ADC_WIDTH-1:0] adc_data_dly;

    // FIFO Interface
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] fifo_data_out;
    wire fifo_full;
    wire fifo_empty;

    // UDP Control
    wire udp_tx_done;
    wire tx_req;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] udp_tx_data;
    wire udp_busy;

    // top_ctrl module signals
   (* MARK_DEBUG="true" *) wire ctrl_fifo_wr_en;
   (* MARK_DEBUG="true" *) wire ctrl_udp_tx_enable;
    wire sys_message_sending;
    (* MARK_DEBUG="true" *)wire [4:0]cfg_fee_mode;
    // Additional control signals
    wire [3:0] req_channel;

    // Data accept control logic
    reg udp_tx_done_sync;
    reg tx_done_pulse;
    reg data_accept;
    reg monitoring;
    reg first_packet_sent;
    reg cfg_udp_tx_enable_sync;

    // Assign eth_rst_n
    assign eth_rst_n = rst;

    assign adc_data_dly = (adc_data_ready==1'b1)?rec_ADC_data:0;
    // Data accept control logic
    always @(posedge clk_udp or negedge rst) begin
        if (!rst) begin
            first_packet_sent <= 1'b0;
            monitoring <= 1'b0;
            data_accept <= 1'b0;
            udp_tx_done_sync <= 1'b0;
            tx_done_pulse <= 1'b0;
            cfg_udp_tx_enable_sync <= 1'b0;
        end else begin       
            // 检测 udp_tx_done 上升沿
            udp_tx_done_sync <= udp_tx_done;
            tx_done_pulse <= (udp_tx_done && !udp_tx_done_sync);
            
            if (tx_done_pulse) begin
                monitoring <= 1'b1;
            end
            
            // 首次传输或发送状态/标定值
            if ((ctrl_udp_tx_enable && !first_packet_sent)|| sys_status == 4'd3) begin
                data_accept <= 1'b1;
                first_packet_sent <= 1'b1;
                monitoring <= 1'b0;
            end
            else if (monitoring ) begin
                data_accept <= 1'b1;
                monitoring <= 1'b0;
            end else begin
                data_accept <= 1'b0;
            end
        end
    end

    // top_ctrl Instance
    top_ctrl u_top_ctrl(
        .clk(clk),
        .rst_n(rst),
        .cfg_fifo_wr_en(cfg_fifo_wr_en),
        .cfg_udp_tx_enable(cfg_udp_tx_enable),
        .cfg_fee_mode(cfg_fee_mode),
        .udp_busy_in(udp_busy),
        .end_udp_tran(1'b0),
        .fifo_prog_empty(fifo_empty),
        .sys_status(sys_status),
        .udp_tx_done(udp_tx_done),
        .fifo_wr_en(ctrl_fifo_wr_en),
        .udp_tx_enable(ctrl_udp_tx_enable),
        .sys_message_sending(sys_message_sending),
        .fee_mode(fee_mode),
        .udp_busy()
    );

    // ADC Core Instance
    adc_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_adc_core (
        .adc_clk(clk),
        .sys_clk(clk),
        .rst_n(rst),
        .data_accepted_rib(data_accepted_rib),
        .adc_data_in(adc_data_dly),
        .fifo_wr_en(ctrl_fifo_wr_en),
        .sys_status(sys_status),
        .ADC_DATA(fifo_data_out),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fee_mode(fee_mode)
    );

    // RIB Write Instance
    rib_wr #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_rib_wr(
        .rib_clk(clk),
        .rib_rst_n(rst),
        .fee_mode(fee_mode),
        .rib_addr(s7_addr_o),
        .rib_data_i(s7_data_o),
        .rib_we(s7_we_o),
        .rib_data_o(s7_data_i),
       // .req_valid_i(req_valid_i),
        .cfg_tx_data_num(cfg_tx_data_num),
        .cfg_udp_tx_enable(cfg_udp_tx_enable),
        .cfg_board_ip(cfg_board_ip),
        .cfg_des_ip(cfg_des_ip),
        .cfg_board_port(cfg_board_port),
        .cfg_des_port(cfg_des_port),
        .cfg_fifo_wr_en(cfg_fifo_wr_en),
        .adc_value(fifo_data_out),
        .baseline_rib_data(baseline_rib_data),
        .adc_test(adc_test),
        .adc_noise(adc_noise),
        .cal_adc_value(cal_adc_value),
        .sys_status(sys_status),
        .data_accepted_rib(data_accepted_rib),
        .cfg_fee_mode(cfg_fee_mode),
        .cfg_adc_width(),
        .cfg_datawidth(),
        .cfg_num_channels()
    );

    // UDP Core Instance
    udp_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_udp_core (
        .clk_udp(clk_udp),
        .rst_n(rst),
        .board_ip(cfg_board_ip),
        .des_ip(cfg_des_ip),
        .board_port(cfg_board_port),
        .des_port(cfg_des_port),
        .tx_data_num(cfg_tx_data_num),
        .udp_tx_enable(ctrl_udp_tx_enable),
        .tx_udp_data(udp_tx_data),
        .tx_req(tx_req),
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_txd(eth_txd),
        .udp_tx_done(udp_tx_done),
        .DataAccept(data_accept),
        .udp_busy(udp_busy)
    );

    // Baseline Voltage Calibration Instance
    Baseline_Volt_Cal #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_baseline_volt_cal(
        .fee_mode(fee_mode),
        .sys_status(sys_status),
        .tx_req(tx_req),
        .udp_clk(clk_udp),
        .sys_clk(clk),
        .sys_rst_n(rst),
        .sys_message_sending(sys_message_sending),
        .tx_data_fifo(cal_adc_value),
        .adc_baseline(baseline_rib_data),
        .adc_noise(adc_noise),
        .udp_tx_data(udp_tx_data)
    );
   vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst),
        .vld_i(req_valid_i),
        .rdy_o(req_ready_o),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

endmodule