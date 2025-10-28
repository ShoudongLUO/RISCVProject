`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/11 10:28:44
// Design Name: 
// Module Name: FPGA_TEST
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

`timescale 1 ns / 1 ps

module fpga_sipo_test (
 input wire clk,
    input wire rst_ext_i,
    input wire clk_125m,
    output wire halted_ind,  // jtag是否已经halt住CPU信号

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚

    inout wire[1:0] gpio,    // GPIO引脚

    input wire jtag_TCK,     // JTAG TCK引脚
    input wire jtag_TMS,     // JTAG TMS引脚
    input wire jtag_TDI,     // JTAG TDI引脚
    output wire jtag_TDO,    // JTAG TDO引脚

    // 3.3 vcc输出引脚（2个）
    output wire[1:0] vcc3v3,

    // I2C 接口
    inout wire i2c_scl, 
    inout wire i2c_sda,

    // ADD SPI Interface
    output wire spi_sck,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire[1:0] spi_csn,
    //ADC UDP Interface
     

    output             eth_txc   , //RGMII发送数据时钟
    output             eth_tx_ctl, //RGMII输出数据有效信号
    output           eth_rst_n,
    output      [3:0]  eth_txd,    //RGMII输出数
    input wire          start_btn,  // 开始测试按键
    output reg [3:0]    leds
);

    // 测试参数
    parameter TEST_PATTERN = 24'h001002;
    
    // 测试状态
    reg [1:0] state;
    localparam S_IDLE = 2'b00;
    localparam S_SENDING = 2'b01;
    localparam S_WAITING = 2'b10;
    localparam S_CHECKING = 2'b11;
    
    reg [4:0] bit_counter;
    reg data_valid_in;
    reg serial_data_in;
    reg [23:0] expected_data;
    
    // 边沿检测用于按键消抖
    reg [2:0] btn_sync;
    always @(posedge clk or negedge rst_ext_i) begin
        if (!rst_ext_i) btn_sync <= 3'b0;
        else btn_sync <= {btn_sync[1:0], start_btn};
    end
    
    wire start_pulse = (btn_sync[2:1] == 2'b01);
    
    // 实例化SIPO转换器
    wire [23:0] parallel_data_out;
    wire data_ready_out;
    reg [10:0] data_count;
 
    
    // 主测试状态机
    always @(posedge clk or negedge rst_ext_i) begin
        if (!rst_ext_i) begin
            state <= S_IDLE;
            data_valid_in <= 0;
            serial_data_in <= 0;
            bit_counter <= 0;
            expected_data <= TEST_PATTERN;
            leds <= 4'h01;
              data_count<=0;
        end else begin
            case (state)
                S_IDLE: begin
                    
            data_count <= data_count+1'b1;
                    if (start_pulse) begin
                       data_count <=0;
                       expected_data<=TEST_PATTERN;
                    end
                    else if(data_count < 11'd512)begin
                     state <= S_SENDING;
                     expected_data <= expected_data+ 24'h001001;
                        bit_counter <= 23;
                        data_valid_in <= 1'b1;
                        serial_data_in <= expected_data[23];
                        leds <= 4'h02; // 发送状态
                        data_count <= data_count +1'b1;
                    end
                    else 
                        leds <= 4'h01; // 待机状态
                end
                
                S_SENDING: begin

                    if (bit_counter > 0) begin
                        serial_data_in <= expected_data[bit_counter-1];
                        bit_counter <= bit_counter - 1;
                    end else begin
                        state <= S_WAITING;
                        data_valid_in <= 1'b0;
                        leds <= 4'h03; // 等待状态
                    end
                end
                
                S_WAITING: begin
                    if (data_ready_out) begin
                        state <= S_CHECKING;
                    end
                end
                
                S_CHECKING: begin
                    if (parallel_data_out == expected_data) begin
                        leds <= 4'hf; // 测试通过
                    end else begin
                        leds <= 4'h0; // 测试失败
                    end
                    if (start_pulse||data_count < 11'd512) begin
                    state <= S_IDLE;
                    end
                end
            endcase
        end
    end
    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .clk_125m(clk_125m),
        .halted_ind(halted_ind),           // 输出，不需要驱动
        
        // UART接口
        .uart_tx_pin(uart_tx_pin),          // 输出

        .uart_rx_pin(uart_rx_pin),      // 保持空闲状态


        
        // JTAG接口
        .jtag_TCK(jtag_TCK),        // 测试中不使能JTAG
        .jtag_TMS(jtag_TMS),
        .jtag_TDI(jtag_TDI),
        .jtag_TDO(jtag_TDO),
        
        // 电源引脚
        .vcc3v3(vcc3v3),
        
        
        // SPI接口

        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_csn(spi_csn),

        
        // ADC接口

        .serial_data_in(serial_data_in),
        .data_valid_in(data_valid_in),
        .adc_data(parallel_data_out),
        .data_ready_out(data_ready_out),
        // 以太网接口
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_rst_n(eth_rst_n),
        .eth_txd(eth_txd)
    );
endmodule
