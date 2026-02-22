module udp_core_sgmii #(
    parameter ADC_WIDTH = 8,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 1
)(
    //-------------------------------------------------------------
    // 系统时钟/复位 (KCU105通常有一个差分参考时钟给SGMII)
    //-------------------------------------------------------------
    input         refclk625_p,      // KCU105 SGMII LVDS 模式通常需要 625MHz 参考时钟
    input         refclk625_n,      // 或者 200MHz/300MHz 进 PLL 生成
    input         rst_n,            // 异步复位

    //-------------------------------------------------------------
    // 配置接口
    //-------------------------------------------------------------
    input  [31:0] board_ip,         
    input  [31:0] des_ip,           
    input  [15:0] tx_data_num,      
    input         udp_tx_enable,    
    input  [15:0] board_port,
    input  [15:0] des_port,
    
    //-------------------------------------------------------------
    // 数据接口 (写入端)
    //-------------------------------------------------------------
    input  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data,           
    output        tx_req,           
    input         DataAccept, 
    
    //-------------------------------------------------------------
    // 以太网物理接口 (SGMII Differential) --> 连接到顶层管脚
    //-------------------------------------------------------------
    output        sgmii_txp,
    output        sgmii_txn,
    input         sgmii_rxp,
    input         sgmii_rxn,
    // KCU105 PHY 复位引脚
    output        phy_rst_n,
    
    //-------------------------------------------------------------
    // 状态输出
    //-------------------------------------------------------------
    output        udp_tx_done,     
    output        udp_busy,
    output        link_status       // 网线连接状态
);

    //==========================================================================
    // 信号定义
    //==========================================================================
    wire          clk_udp;          // 这是重点：SGMII IP 输出的 125MHz 核心时钟
    wire          udp_rst_n_sync;   // 同步到 clk_udp 的复位信号
    
    // GMII 信号 (连接 UDP 模块 和 SGMII IP)
    wire          gmii_tx_en;
    wire  [7:0]   gmii_txd;
    wire          gmii_tx_er;       // UDP 模块通常不产生错误信号，置0即可
    
    // SGMII IP 接收侧信号 (如果只发不收，这些可以忽略或做伪连接)
    wire          gmii_rx_dv;
    wire          gmii_rx_er;
    wire  [7:0]   gmii_rxd;
    wire          gmii_clk;         // IP 输出的时钟
    
    wire          internal_tx_start_en_pulse;
    wire          data_req;
    reg   [ADC_CHANEL*DATAWIDTH-1:0]  udp_tx_data_mux;
    
    // 状态机相关
    reg           udp_busy_state;
    localparam S_IDLE    = 1'b0;
    localparam S_SENDING = 1'b1;
    
    // MAC Address
    localparam BOARD_MAC = 48'h12_34_56_78_9a_bc;
    localparam DES_MAC   = 48'hff_ff_ff_ff_ff_ff;

    //==========================================================================
    // 1. 实例化 Xilinx SGMII IP Core
    //==========================================================================
    
    // 状态信号
    wire status_link_up;
    assign link_status = status_link_up;
    assign phy_rst_n = 1'b1; // 简单的 PHY 复位控制，实际可能需要上电延时

    gig_ethernet_pcs_pma_0 u_sgmii_ip (
        // --- 时钟和复位 ---
        // SGMII over LVDS 模式在 KCU105 上通常需要差分参考时钟输入
        // 或者是内部时钟。这里假设你配置了 Shared Logic in Core
        .refclk625_in            (refclk625_p), // 此处取决于 IP 配置
        // .refclk625_n          (refclk625_n), // 如果 IP 内部有 BUFDS
        
        .mmcm_locked_out         (),            // 内部 MMCM 锁定
        .userclk2_out            (clk_udp),     // **关键**: 输出 125MHz 给用户逻辑使用
        
        .reset                   (!rst_n),      // 高电平复位
        .signal_detect           (1'b1),        // SGMII 模式下通常置1
        
       
        .gmii_txd                (gmii_txd),
        .gmii_tx_en              (gmii_tx_en),
        .gmii_tx_er              (1'b0),        // 发送错误，置0
        
        .gmii_rxd                (gmii_rxd),    // 接收数据
        .gmii_rx_dv              (gmii_rx_dv),  // 接收有效
        .gmii_rx_er              (gmii_rx_er),  // 接收错误
        .gmii_isolate            (),
        
        // --- SGMII 物理接口 (连接到顶层端口) ---
        .txp                     (sgmii_txp),
        .txn                     (sgmii_txn),
        .rxp                     (sgmii_rxp),
        .rxn                     (sgmii_rxn),
        
        // --- 配置/状态 ---
        .configuration_vector    (5'b10000),    // 开启自动协商等配置
        .status_vector           (),
        .status_link_up          (status_link_up)
    );
    
    //==========================================================================
    // 2. 复位同步 (同步到新的 clk_udp 域)
    //==========================================================================
    reg rst_s1_udp, rst_s2_udp;
    
    // 注意：这里的时钟源变成了 clk_udp (来自 IP 核)
    always @(posedge clk_udp or negedge rst_n) begin
        if (!rst_n) begin
            rst_s1_udp <= 1'b0;
            rst_s2_udp <= 1'b0;
        end else begin
            rst_s1_udp <= 1'b1;
            rst_s2_udp <= rst_s1_udp; // 只有当 IP 核时钟稳定输出时，复位才释放
        end
    end
    assign udp_rst_n_sync = rst_s2_udp & status_link_up; // 建议：链路建立后再开始发数据

    // UDP Busy Status
    assign udp_busy = (udp_busy_state == S_SENDING);
    assign tx_req = data_req;

    // 数据 MUX
    always @(*) begin
        udp_tx_data_mux = tx_udp_data;
    end

    //==========================================================================
    // 3. 简单的发送触发状态机
    //==========================================================================
    always @(posedge clk_udp or negedge udp_rst_n_sync) begin
        if (!udp_rst_n_sync) begin
            udp_busy_state <= S_IDLE;
            // internal_tx_start_en_pulse <= 1'b0; // wire类型不能赋值，需修正
        end else begin
            case(udp_busy_state)
                S_IDLE: begin
                    if (udp_tx_enable) begin
                        udp_busy_state <= S_SENDING;
                    end
                end
                S_SENDING: begin
                    if (udp_tx_done) begin
                        udp_busy_state <= S_IDLE;
                    end
                end
                default: udp_busy_state <= S_IDLE;
            endcase
        end
    end
    
    // 修正脉冲生成逻辑
    assign internal_tx_start_en_pulse = (udp_busy_state == S_IDLE) && udp_tx_enable;

    //==========================================================================
    // 4. 实例化 UDP 协议逻辑模块
    //==========================================================================
    // 这里的 gmii_tx_clk 输入必须接 IP 核输出的 userclk2 (clk_udp)
    
    udp #(
        .ADC_CHANEL(ADC_CHANEL)
    ) u_udp (
        .BOARD_MAC     (BOARD_MAC),
        .BOARD_IP      (board_ip),
        .BOARD_PORT    (board_port),
        .DES_MAC       (DES_MAC),
        .DES_IP        (des_ip),
        .DES_PORT      (des_port),
        
        .rst_n         (udp_rst_n_sync),
        
        .gmii_tx_clk   (clk_udp),      // <--- 关键修改：使用 IP 输出的时钟
        .gmii_tx_en    (gmii_tx_en),   // 输出到 IP
        .gmii_txd      (gmii_txd),     // 输出到 IP
        
        .tx_start_en   (internal_tx_start_en_pulse),
        .tx_data       (udp_tx_data_mux),
        .tx_byte_num   (tx_data_num),
        .tx_done       (udp_tx_done),
        .tx_req        (data_req)
    );

    // 删除了 rgmii_tx 模块实例化
    
endmodule