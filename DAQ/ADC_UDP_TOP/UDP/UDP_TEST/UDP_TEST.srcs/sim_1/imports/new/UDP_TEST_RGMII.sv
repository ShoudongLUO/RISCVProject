`timescale 1ns/1ps

module tb_udp_core_rgmii;

    // 参数定义
    parameter ADC_WIDTH = 8;
    parameter DATAWIDTH = 16;
    parameter ADC_CHANEL = 1;

    // ---------------------------------------------------------
    // 信号声明
    // ---------------------------------------------------------
    reg          clk_udp;
    reg          rst_n;
    reg  [31:0]  board_ip, des_ip;
    reg  [15:0]  board_port, des_port;
    reg  [15:0]  tx_data_num;
    reg          udp_tx_enable;
    reg  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data;
    reg          DataAccept;

    wire         eth_txc;
    wire         eth_tx_ctl;
    wire [3:0]   eth_txd;
    wire         tx_req;
    wire         udp_tx_done;
    wire         udp_busy;

    // 用于验证的数据计数器
    reg [15:0]   test_data_cnt;

    // ---------------------------------------------------------
    // 实例化 DUT (Design Under Test)
    // ---------------------------------------------------------
    udp_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .DATAWIDTH(DATAWIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_dut (
        .clk_udp        (clk_udp),
        .rst_n          (rst_n),
        .board_ip       (board_ip),
        .des_ip         (des_ip),
        .tx_data_num    (tx_data_num),
        .udp_tx_enable  (udp_tx_enable),
        .board_port     (board_port),
        .des_port       (des_port),
        .tx_udp_data    (tx_udp_data),
        .tx_req         (tx_req),
        .DataAccept     (DataAccept),
        .eth_txc        (eth_txc),
        .eth_tx_ctl     (eth_tx_ctl),
        .eth_txd        (eth_txd),
        .udp_tx_done    (udp_tx_done),
        .udp_busy       (udp_busy)
    );

    // ---------------------------------------------------------
    // 时钟生成 (125MHz -> 8ns period)
    // ---------------------------------------------------------
    initial begin
        clk_udp = 0;
        forever #4 clk_udp = ~clk_udp;
    end

    // ---------------------------------------------------------
    // 数据生成逻辑
    // ---------------------------------------------------------
    always @(posedge clk_udp or negedge rst_n) begin
        if (!rst_n) begin
            test_data_cnt <= 16'd0;
            tx_udp_data   <= 0;
        end else if (tx_req) begin
            test_data_cnt <= test_data_cnt + 1;
            // 模拟发送递增序列数据
            tx_udp_data   <= {ADC_CHANEL{test_data_cnt}};
        end
    end

    // ---------------------------------------------------------
    // 仿真主流程
    // ---------------------------------------------------------
    initial begin
        // 初始化
        rst_n = 0;
        udp_tx_enable = 0;
        DataAccept = 0;
        board_ip   = {8'd192, 8'd168, 8'd1, 8'd10};
        des_ip     = {8'd192, 8'd168, 8'd1, 8'd100};
        board_port = 16'd8080;
        des_port   = 16'd8080;
        tx_data_num = 16'd64;   // 发送 64 字节数据

        #100;
        rst_n = 1;
        #200;

        // --- 第一次传输演示 ---
        $display("[TB] Starting First Transmission...");
        @(posedge clk_udp);
        udp_tx_enable = 1;
        @(posedge clk_udp);
        udp_tx_enable = 0;

        // 等待传输开始
        wait(tx_req);
        $display("[TB] Data Request detected, sending data...");

        // 等待传输完成
        wait(udp_tx_done);
        $display("[TB] Transmission Done!");

        #1000;
        
        // --- 第二次传输演示 (DataAccept 模拟) ---
        $display("[TB] Starting Second Transmission...");
        @(posedge clk_udp);
        udp_tx_enable = 1;
        @(posedge clk_udp);
        udp_tx_enable = 0;

        wait(udp_tx_done);
        #100;
        DataAccept = 1; // 触发接受脉冲
        @(posedge clk_udp);
        DataAccept = 0;

        #2000;
        $display("[TB] Simulation Finished.");
        $finish;
    end

    // ---------------------------------------------------------
    // RGMII 辅助解调逻辑 (仅用于仿真观察波形)
    // ---------------------------------------------------------
    // 作用：将 4-bit DDR 数据还原为 8-bit GMII 格式，方便验证包头
    reg [3:0] eth_txd_r1, eth_txd_r2;
    reg       eth_tx_ctl_r1, eth_tx_ctl_r2;
    wire [7:0] debug_gmii_txd;
    wire       debug_gmii_tx_en;

    always @(posedge eth_txc) begin
        eth_txd_r1    <= eth_txd;
        eth_tx_ctl_r1 <= eth_tx_ctl;
    end

    always @(negedge eth_txc) begin
        eth_txd_r2    <= eth_txd;
        eth_tx_ctl_r2 <= eth_tx_ctl;
    end

    // RGMII 协议：上升沿传[3:0]，下降沿传[7:4]
    assign debug_gmii_txd   = {eth_txd_r2, eth_txd_r1};
    assign debug_gmii_tx_en = eth_tx_ctl_r1; // 简化观察，忽略错误校验位

endmodule