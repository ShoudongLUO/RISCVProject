`timescale 1ns/1ps

module tb_udp_sgmii_real;

    parameter ADC_WIDTH = 8;
    parameter DATAWIDTH = 16;
    parameter ADC_CHANEL = 1;

    // ---------------------------------------------------------
    // 1. 信号声明 
    // ---------------------------------------------------------
    reg         refclk625_p, refclk625_n;
    reg         free_clk; 
    reg         rst_n;
    reg  [31:0] board_ip, des_ip;
    reg  [15:0] board_port, des_port;
    reg  [15:0] tx_data_num;
    reg         udp_tx_enable;
    reg  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data;
    
    wire        sgmii_txp, sgmii_txn;
    wire        sgmii_rxp, sgmii_rxn; 
    wire        tx_req, udp_tx_done, udp_busy, link_status, phy_rst_n;
    
    // --- TB 专用：用于观察的 GMII 并行信号 ---
    wire [7:0]  tb_recovered_gmii_rxd;
    wire        tb_recovered_gmii_rx_dv;
    wire        tb_recovered_gmii_rx_er;
    wire        tb_recovered_clk125;
    wire [15:0] tb_receiver_status;

    reg  [15:0] test_data_cnt;

    // ---------------------------------------------------------
    // 2. 时钟生成 (修正频率)
    // ---------------------------------------------------------
    // 625MHz 参考时钟: 周期 = 1.6ns, 半周期 = 0.8ns
    initial begin
        refclk625_p = 0;
        forever #0.8 refclk625_p = ~refclk625_p; // 修正：之前 #4 是 125MHz
    end
    always @(*) refclk625_n = ~refclk625_p;

    initial begin
        free_clk = 0;
        forever #2.5 free_clk = ~free_clk;
    end

    // ---------------------------------------------------------
    // 3. 实例化 DUT (发送端)
    // ---------------------------------------------------------
    udp_core_sgmii #(
        .ADC_WIDTH(ADC_WIDTH), 
        .DATAWIDTH(DATAWIDTH), 
        .ADC_CHANEL(ADC_CHANEL)
    ) u_dut (
        .refclk625_p    (refclk625_p), 
        .refclk625_n    (refclk625_n), 
        .rst_n          (rst_n),
        .board_ip       (board_ip), 
        .des_ip         (des_ip),
        .tx_data_num    (tx_data_num), 
        .udp_tx_enable  (udp_tx_enable),
        .board_port     (board_port),  
        .des_port       (des_port),      
        .tx_udp_data    (tx_udp_data), 
        .tx_req         (tx_req), 
        .sgmii_txp      (sgmii_txp), 
        .sgmii_txn      (sgmii_txn),
        .sgmii_rxp      (sgmii_rxp), 
        .sgmii_rxn      (sgmii_rxn),
        .phy_rst_n      (phy_rst_n),
        .udp_tx_done    (udp_tx_done), 
        .udp_busy       (udp_busy), 
        .link_status    (link_status)
    );

    // ---------------------------------------------------------
    // 4. TB 接收端：将 SGMII 转换回 GMII (模拟外部 PHY)
    // ---------------------------------------------------------
    // 我们直接实例化 IP 核的原始模块来做解码
    gig_ethernet_pcs_pma_0 u_receiver_decoder (
        .txp                    (), // 不发送
        .txn                    (),
        .rxp                    (sgmii_txp), // 接收来自 DUT 的串行正极信号
        .rxn                    (sgmii_txn), // 接收来自 DUT 的串行负极信号

        .refclk625_p            (refclk625_p),
        .refclk625_n            (refclk625_n),
        .clk125_out             (tb_recovered_clk125), // 解码出的并行时钟
        .idelay_rdy_out          (),
        .clk625_out             (),
        .clk312_out             (),
        .rst_125_out            (),
        .mmcm_locked_out        (),

        .sgmii_clk_en           (),
        .speed_is_10_100        (1'b0),
        .speed_is_100           (1'b0),

        // --- 这里就是你要的并行 GMII 输出 ---
        .gmii_txd               (8'b0),
        .gmii_tx_en             (1'b0),
        .gmii_tx_er             (1'b0),
        .gmii_rxd               (tb_recovered_gmii_rxd),   // 并行数据
        .gmii_rx_dv             (tb_recovered_gmii_rx_dv),  // 数据有效标志
        .gmii_rx_er             (tb_recovered_gmii_rx_er),  // 错误标志
        .gmii_isolate           (),

        .configuration_vector   (5'b0000), // 开启自协商
        .configuration_valid    (1'b1),
        .an_adv_config_vector   (16'h0020),
        .an_adv_config_val      (1'b1),
        .an_restart_config      (1'b0),

        .status_vector          (tb_receiver_status),
        .reset                  (!rst_n),
        .signal_detect          (1'b1)
    );

    // 这里的回环是为了让 DUT 的 RX 也能起来 (Link Up)
    assign #0.1 sgmii_rxp = sgmii_txp;
    assign #0.1 sgmii_rxn = sgmii_txn;

    // ---------------------------------------------------------
    // 5. 数据生成
    // ---------------------------------------------------------
    always @(posedge u_dut.clk_udp or negedge rst_n) begin
        if (!rst_n) begin
            test_data_cnt <= 16'd0;
            tx_udp_data   <= 0;
        end else if (tx_req) begin
            test_data_cnt <= test_data_cnt + 1;
            tx_udp_data   <= {(ADC_CHANEL*DATAWIDTH/16){test_data_cnt}}; 
        end
    end

    // ---------------------------------------------------------
    // 6. 主仿真流程
    // ---------------------------------------------------------
    initial begin
        rst_n = 0;
        udp_tx_enable = 0;
        board_ip    = {8'd192, 8'd168, 8'd1, 8'd10};
        des_ip      = {8'd192, 8'd168, 8'd1, 8'd100};
        board_port  = 16'd8080;
        des_port    = 16'd8080;
        tx_data_num = 16'd100; 

        #200;
        rst_n = 1;
        
        wait(link_status == 1 && tb_receiver_status[0] == 1);
        $display("[%0t] BOTH SIDES LINK UP!", $time);
        
        #2000;
        @(posedge u_dut.clk_udp);
        udp_tx_enable = 1;
        @(posedge u_dut.clk_udp);
        udp_tx_enable = 0;

        // 监视还原后的并行 GMII 数据
        $display("Watching Recovered Parallel Data...");
        wait(tb_recovered_gmii_rx_dv == 1);
        $display("[%0t] First Parallel Byte Received: %h", $time, tb_recovered_gmii_rxd);
        
        wait(udp_tx_done);
        #5000;
        $finish;
    end

endmodule