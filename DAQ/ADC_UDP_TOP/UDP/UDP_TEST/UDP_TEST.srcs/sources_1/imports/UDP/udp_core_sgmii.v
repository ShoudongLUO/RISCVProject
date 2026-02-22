`timescale 1ns/1ps

module udp_core_sgmii #(
    parameter ADC_WIDTH = 8,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 1
)(
    //-------------------------------------------------------------
    // 时钟与复位接口
    //-------------------------------------------------------------
    input         refclk625_p,      // SGMII LVDS 参考时钟 (625MHz)
    input         refclk625_n,
    input         rst_n,            // 异步复位 (Active Low)

    //-------------------------------------------------------------
    // 配置与数据接口
    //-------------------------------------------------------------
    input  [31:0] board_ip,         
    input  [31:0] des_ip,           
    input  [15:0] tx_data_num,      
    input         udp_tx_enable,    
    input  [15:0] board_port,
    input  [15:0] des_port,
    
    input  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data,           
    output        tx_req,           
    
    //-------------------------------------------------------------
    // SGMII 物理接口 (LVDS SelectIO)
    //-------------------------------------------------------------
    output        sgmii_txp,
    output        sgmii_txn,
    input         sgmii_rxp,
    input         sgmii_rxn,
    output        phy_rst_n,        // 外部 PHY 复位
    
    //-------------------------------------------------------------
    // 状态输出
    //-------------------------------------------------------------
    output        udp_tx_done,     
    output        udp_busy,
    output        link_status       
);

    //==========================================================================
    // 1. 内部信号定义
    //==========================================================================
    wire        clk_udp;            // IP 输出的 125MHz 用户时钟
    wire        rst_udp;            // IP 输出的同步复位 (高有效)
    wire [15:0] status_vector;
    
    // GMII 信号
    wire        gmii_tx_en;
    wire [7:0]  gmii_txd;
    wire        gmii_tx_er;
    wire [7:0]  gmii_rxd;
    wire        gmii_rx_dv;
    wire        gmii_rx_er;

    // 配置向量
    wire [4:0]  pcspma_config_vector;
    wire [15:0] pcspma_an_config_vector;
    
    // SGMII 配置：开启自协商 (Standard Alex Forencich settings)
    assign pcspma_config_vector[4] = 1'b1; // autonegotiation enable
    assign pcspma_config_vector[3] = 1'b0; // isolate
    assign pcspma_config_vector[2] = 1'b0; // power down
    assign pcspma_config_vector[1] = 1'b0; // loopback enable
    assign pcspma_config_vector[0] = 1'b0; // unidirectional enable

    // SGMII 自协商通告向量 (1000Mbps, Full Duplex)
    assign pcspma_an_config_vector[15]    = 1'b1;    // SGMII link status
    assign pcspma_an_config_vector[14]    = 1'b1;    // SGMII Acknowledge
    assign pcspma_an_config_vector[13:12] = 2'b01;   // full duplex
    assign pcspma_an_config_vector[11:10] = 2'b10;   // SGMII speed (1000Mbps)
    assign pcspma_an_config_vector[9:1]   = 9'b0;    // reserved
    assign pcspma_an_config_vector[0]     = 1'b1;    // SGMII bit 0

    //==========================================================================
    // 2. 实例化 SGMII IP Core (完全匹配提供的端口)
    //==========================================================================
    gig_ethernet_pcs_pma_0 u_sgmii_ip (
        // LVDS transceiver Interface
        .txp                     (sgmii_txp),
        .txn                     (sgmii_txn),
        .rxp                     (sgmii_rxp),
        .rxn                     (sgmii_rxn),

        .refclk625_p             (refclk625_p),
        .refclk625_n             (refclk625_n),
        .clk125_out              (clk_udp),       // 输出 125MHz 给 UDP
        .idelay_rdy_out          (),
        .clk625_out              (),
        .clk312_out              (),
        .rst_125_out             (rst_udp),       // 同步后的高有效复位
        .mmcm_locked_out         (),

        .sgmii_clk_r             (),
        .sgmii_clk_f             (),
        .sgmii_clk_en            (),

        // Speed Control (基于状态向量判断)
        .speed_is_10_100         (status_vector[11:10] != 2'b10),
        .speed_is_100            (status_vector[11:10] == 2'b01),

        // GMII 接口
        .gmii_txd                (gmii_txd),
        .gmii_tx_en              (gmii_tx_en),
        .gmii_tx_er              (gmii_tx_er),
        .gmii_rxd                (gmii_rxd),
        .gmii_rx_dv              (gmii_rx_dv),
        .gmii_rx_er              (gmii_rx_er),
        .gmii_isolate            (),

        // 管理与配置
       /* .mdc                     (1'b0),
        .mdio_i                  (1'b1),
        .mdio_o                  (),
        .mdio_t                  (),
        .phyaddr                 (5'b00000),*/
        .configuration_vector    (pcspma_config_vector),
       // .configuration_valid     (1'b1),

        .an_interrupt            (),
        .an_adv_config_vector    (pcspma_an_config_vector),
     //   .an_adv_config_val       (1'b1),
        .an_restart_config       (1'b0),

        // 状态与复位
        .status_vector           (status_vector),
        .reset                   (!rst_n),
        .signal_detect           (1'b1)
    );

    //==========================================================================
    // 3. 复位同步与状态逻辑
    //==========================================================================
    assign link_status = status_vector[0];
    assign phy_rst_n   = rst_n;
    
    // 逻辑复位信号：当 IP 复位完成且链路建立时释放 (低有效)
    wire udp_internal_rst_n = (!rst_udp) && link_status;

    //==========================================================================
    // 4. UDP 发送控制
    //==========================================================================
    reg udp_busy_state;
    always @(posedge clk_udp or negedge udp_internal_rst_n) begin
        if (!udp_internal_rst_n) begin
            udp_busy_state <= 1'b0;
        end else begin
            if (udp_tx_enable) 
                udp_busy_state <= 1'b1;
            else if (udp_tx_done)
                udp_busy_state <= 1'b0;
        end
    end

    assign udp_busy = udp_busy_state;
    assign gmii_tx_er = 1'b0;

    udp #(
        .ADC_CHANEL(ADC_CHANEL)
    ) u_udp (
        .BOARD_MAC     (48'h12_34_56_78_9a_bc),
        .BOARD_IP      (board_ip),
        .BOARD_PORT    (board_port),
        .DES_MAC       (48'hff_ff_ff_ff_ff_ff),
        .DES_IP        (des_ip),
        .DES_PORT      (des_port),
        .rst_n         (udp_internal_rst_n),
        .gmii_tx_clk   (clk_udp),
        .gmii_tx_en    (gmii_tx_en),
        .gmii_txd      (gmii_txd),
        .tx_start_en   (udp_tx_enable && !udp_busy),
        .tx_data       (tx_udp_data),
        .tx_byte_num   (tx_data_num),
        .tx_done       (udp_tx_done),
        .tx_req        (tx_req)
    );

endmodule