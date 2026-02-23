`timescale 1ns / 1ps

module DAQ_UDP_top #(
    parameter ADC_WIDTH = 12,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 20,
parameter IsSplitData = 1'b1,
parameter REAL_DATA_WIDTH = 128,
parameter REAL_DATA_CHANEL=2
)(
    // System clocks and reset
    input clk,           // System clock (50MHz)
    input clk_udp,       // UDP clock (125MHz)
    input rst_n,         // Active low reset
    
    // RIB Bus Interface (from processor)
    input [31:0] s7_addr_o,
    input [31:0] s7_data_o,
    input s7_we_o,
    output reg [31:0] s7_data_i,
    
    
    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,
    // ADC Input
    input [ADC_CHANEL*ADC_WIDTH-1:0] rec_ADC_data,
    (* MARK_DEBUG="true" *)input wire adc_data_ready,
    // Ethernet PHY Interface (RGMII)
    output eth_txc,      // RGMII TX Clock
    output eth_tx_ctl,   // RGMII TX Control
    output eth_rst_n,    // PHY reset (active low)
    output [3:0] eth_txd // RGMII TX Data
   
);

    // =========================================================================
    // 1. Internal Signals
    // =========================================================================
    
    // Configuration Registers
    reg [31:0] cfg_board_ip;
    reg [31:0] cfg_des_ip;
    reg [15:0] cfg_board_port;
    reg [15:0] cfg_des_port;
    reg [15:0] cfg_tx_data_num;
    
    // ADC Config (Placeholder for compatibility)
    reg [3:0]  cfg_adc_width;
    reg [5:0]  cfg_datawidth;
    reg [21:0] cfg_num_channels;

    // FIFO & Data Path
    (* MARK_DEBUG="true" *) wire [ADC_CHANEL*ADC_WIDTH-1:0] adc_data_dly;
    (* MARK_DEBUG="true" *) wire [ADC_CHANEL*DATAWIDTH-1:0] fifo_data_out;
    wire fifo_full;
    wire fifo_empty;

    // UDP Control
    wire udp_tx_done;
    wire tx_req;
    wire udp_busy;

    // Assignments
    assign eth_rst_n = rst_n;
    // 如果 adc_data_ready 有效则采样，否则为0
    assign adc_data_dly = adc_data_ready ? rec_ADC_data : {ADC_CHANEL*ADC_WIDTH{1'b0}};

    // =========================================================================
    // 2. RIB Register Map (仅保留必要的配置)
    // =========================================================================
    localparam REG_UDP_CONFIG    = 6'h10; 
    localparam REG_BOARD_IP      = 6'h14; 
    localparam REG_DES_IP        = 6'h18; 
    localparam REG_BOARD_PORT    = 6'h1C; 
    localparam REG_DES_PORT      = 6'h20; 
    localparam REG_ADC_CONFIG    = 6'h24; 

    // =========================================================================
    // 3. Register Write Logic (Configuration)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 默认网络配置 (Reset values)
            cfg_tx_data_num   <= 16'd100;
            cfg_board_ip      <= {8'd192, 8'd168, 8'd185, 8'd111};
            cfg_des_ip        <= {8'd192, 8'd168, 8'd185, 8'd243};
            cfg_board_port    <= 16'd1234;
            cfg_des_port      <= 16'd1234;
            
            // 默认 ADC 配置
            cfg_adc_width     <= 0;
            cfg_datawidth     <= 0;
            cfg_num_channels  <= 0;
        end else begin
            if (s7_we_o) begin
                case (s7_addr_o[15:0])
                    REG_UDP_CONFIG: begin
                        cfg_tx_data_num <= s7_data_o[15:0]; 
                        // 注意：这里不再配置 enable 位，因为下面已经硬连线了
                    end
                    REG_BOARD_IP:   cfg_board_ip   <= s7_data_o;
                    REG_DES_IP:     cfg_des_ip     <= s7_data_o;
                    REG_BOARD_PORT: cfg_board_port <= s7_data_o[15:0];
                    REG_DES_PORT:   cfg_des_port   <= s7_data_o[15:0];
                    REG_ADC_CONFIG: begin
                        cfg_adc_width    <= s7_data_o[3:0];
                        cfg_datawidth    <= s7_data_o[9:4];
                        cfg_num_channels <= s7_data_o[31:10];
                    end
                    default: ; 
                endcase
            end
        end
    end

    // =========================================================================
    // 4. Register Read Logic (Readback check)
    // =========================================================================
    always @(*) begin
        case (s7_addr_o[15:0])
            REG_UDP_CONFIG: s7_data_i = {16'h0, cfg_tx_data_num};
            REG_BOARD_IP:   s7_data_i = cfg_board_ip;
            REG_DES_IP:     s7_data_i = cfg_des_ip;
            REG_BOARD_PORT: s7_data_i = {16'h0, cfg_board_port};
            REG_DES_PORT:   s7_data_i = {16'h0, cfg_des_port};
            REG_ADC_CONFIG: s7_data_i = {cfg_num_channels, cfg_datawidth, cfg_adc_width};
            default:        s7_data_i = 32'hDEADBEEF; // 无效地址返回 Debug 值
        endcase
    end

    // =========================================================================
    // 5. Core Instantiations (Hardwired Control)
    // =========================================================================

    // ADC Core
    // 逻辑：只要复位完成，始终尝试将数据写入 FIFO (fifo_wr_en = 1)
    // 模式：固定为采集模式 (MODE_ACQUISITION = 2)
    adc_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .DATAWIDTH(DATAWIDTH),
        .REAL_DATA_WIDTH(REAL_DATA_WIDTH),
        .REAL_DATA_CHANEL(REAL_DATA_CHANEL),
        .IsSplitData(IsSplitData),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_adc_core (
        .adc_clk(clk),
        .sys_clk(clk_udp),
        .rst_n(rst_n),
        .data_accepted_rib(1'b0), // 不再使用总线读取 ADC 数据
        .adc_data_in(adc_data_dly),
        
        // --- 优化点：直接拉高写使能 ---
        .fifo_wr_en(1'b1),        
        
        // 维持原有的 FIFO 反压逻辑: 
        // 当 UDP 正在请求数据(tx_req=1)时，sys_status=6，允许 FIFO 读出
        // 当 UDP 不请求时，sys_status=7，可能暂停 FIFO 某些操作
        .sys_status(5'd6 | {4'd0, ~tx_req}), 
        
        .ADC_DATA(fifo_data_out),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        
        // --- 优化点：固定为采集模式 ---
        .fee_mode(5'd2)           
    );

    // UDP Core
    // 逻辑：只要 FIFO 里有足够的数据（由内部 tx_req 判断），就始终允许发送
    udp_core #(
        .DATAWIDTH(REAL_DATA_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_udp_core (
        .clk_udp(clk_udp),
        .rst_n(rst_n),
        .board_ip(cfg_board_ip),
        .des_ip(cfg_des_ip),
        .board_port(cfg_board_port),
        .des_port(cfg_des_port),
        .tx_data_num(cfg_tx_data_num),
        
        // --- 优化点：直接拉高发送使能 ---
        .udp_tx_enable(1'b1),     
        
        .tx_udp_data(fifo_data_out),
        .tx_req(tx_req),
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_txd(eth_txd),
        .udp_tx_done(udp_tx_done),
        .DataAccept(1'b1),
        .udp_busy(udp_busy)
    );

    // 握手模块 (保持不变)
   vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst_n),
        .vld_i(req_valid_i),
        .rdy_o(req_ready_o),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

endmodule