`timescale 1ns/1ps

module tb_udp_sgmii_real;

    parameter ADC_WIDTH = 8;
    parameter DATAWIDTH = 16;
    parameter ADC_CHANEL = 1;

    // ---------------------------------------------------------
    // 信号声明 
    // ---------------------------------------------------------
    reg         refclk625_p, refclk625_n;
    reg         free_clk; 
    reg         rst_n;
    reg  [31:0] board_ip, des_ip;
    reg  [15:0] board_port, des_port; //
    reg  [15:0] tx_data_num;
    reg         udp_tx_enable;
    reg  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data;
    reg         DataAccept;
    
    wire        sgmii_txp, sgmii_txn;
    reg         sgmii_rxp, sgmii_rxn; 
    wire        tx_req, udp_tx_done, udp_busy, link_status, phy_rst_n;
    
    reg  [15:0] test_data_cnt;

    // ---------------------------------------------------------
    // 实例化 DUT
    // ---------------------------------------------------------
    udp_core_sgmii #(
        .ADC_WIDTH(ADC_WIDTH), 
        .DATAWIDTH(DATAWIDTH), 
        .ADC_CHANEL(ADC_CHANEL)
    ) u_dut (
        .refclk625_p(refclk625_p), 
        .refclk625_n(refclk625_n), 
        .free_clk(free_clk),
        .rst_n(rst_n),
        .board_ip(board_ip), 
        .des_ip(des_ip),
        .tx_data_num(tx_data_num), 
        .udp_tx_enable(udp_tx_enable),
        .board_port(board_port),  // 已正确连接
        .des_port(des_port),      // 已正确连接
        .tx_udp_data(tx_udp_data), 
        .tx_req(tx_req), 
        .DataAccept(DataAccept),
        .sgmii_txp(sgmii_txp), 
        .sgmii_txn(sgmii_txn),
        .sgmii_rxp(sgmii_rxp), 
        .sgmii_rxn(sgmii_rxn),
        .phy_rst_n(phy_rst_n),
        .udp_tx_done(udp_tx_done), 
        .udp_busy(udp_busy), 
        .link_status(link_status)
    );

    // 1. 生成 625MHz 参考时钟 (1.6ns 周期)
    initial begin
        refclk625_p = 0;
        forever #0.8 refclk625_p = ~refclk625_p; 
    end
    always @(*) refclk625_n = ~refclk625_p;

    // 2. 生成 200MHz 自由时钟 (5ns 周期)
    initial begin
        free_clk = 0;
        forever #2.5 free_clk = ~free_clk;
    end

    // 3. 数据生成逻辑 (基于内部时钟 clk_udp)
    always @(posedge u_dut.clk_udp) begin
        if (!rst_n) begin
            test_data_cnt <= 16'd0;
            tx_udp_data   <= 0;
        end else if (tx_req) begin
            test_data_cnt <= test_data_cnt + 1;
            tx_udp_data   <= {ADC_CHANEL{test_data_cnt}}; // 填充所有通道
        end
    end

    // 4. 主仿真流程
    initial begin
        // 初始化信号
        rst_n = 0;
        udp_tx_enable = 0;
        DataAccept = 1;         // 默认接受数据
        sgmii_rxp = 0; sgmii_rxn = 1;
        
        board_ip   = {8'd192, 8'd168, 8'd1, 8'd10};
        des_ip     = {8'd192, 8'd168, 8'd1, 8'd100};
        board_port = 16'd8080;  // <--- 初始化赋值
        des_port   = 16'd8080;  // <--- 初始化赋值
        tx_data_num = 16'd100;

        #200;
        rst_n = 1;
        $display("[TB] Reset Released");

        // 模拟 SGMII 回环 (关键：如果不自环，link_status 可能永远为 0)
        // force u_dut.sgmii_rxp = u_dut.sgmii_txp;
        // force u_dut.sgmii_rxn = u_dut.sgmii_txn;

        fork
            begin
                wait(link_status == 1);
                $display("[TB] Link Up detected!");
                #1000;
                @(posedge u_dut.clk_udp);
                udp_tx_enable = 1;
                @(posedge u_dut.clk_udp);
                udp_tx_enable = 0;
                wait(udp_tx_done);
                $display("[TB] UDP Packet Sent!");
                #2000;
                $finish;
            end
            begin
                #100000; // 延长超时到 100us
                $display("[TB] TIMEOUT: Link not up.");
                $stop;
            end
        join_any
    end

endmodule