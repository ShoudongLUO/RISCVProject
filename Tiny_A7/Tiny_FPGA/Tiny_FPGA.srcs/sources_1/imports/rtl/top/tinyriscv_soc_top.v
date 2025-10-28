
/* ===========================================================
 *  Project      : Tiny_FPGA
 *  Unique Tag   : Auto‑generated header (do not remove this line!!!)
 *  Log（开发日志）:
    1. 2025-07-25 Created header by Albert
    2. ...
 * =========================================================== */
 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "../core/defines.v"

// tinyriscv soc顶层模块
module tinyriscv_soc_top(

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
    input wire serial_data_in,
    input wire data_valid_in,
    output wire  [ADC_WIDTH*ADC_CHANEL-1:0]adc_data,
    output wire  data_ready_out, // JUST FOR ADC FPGA TEST!
    //ADC UDP Interface
     

    output             eth_txc   , //RGMII发送数据时钟
    output             eth_tx_ctl, //RGMII输出数据有效信号
    output           eth_rst_n,
    output      [3:0]  eth_txd    //RGMII输出数

    );

    // vcc3v3输出引脚
    assign vcc3v3 = 2'b11; // 固定输出3.3V

    // master 0 interface
    wire[31:0] m0_addr_i;
    wire[31:0] m0_data_i;
    wire[3:0] m0_sel_i;
    wire m0_req_vld_i;
    wire m0_rsp_rdy_i;
    wire m0_we_i;
    wire m0_req_rdy_o;
    wire m0_rsp_vld_o;
    wire[31:0] m0_data_o;

    // master 1 interface
    wire[31:0] m1_addr_i;
    wire[31:0] m1_data_i;
    wire[3:0] m1_sel_i;
    wire m1_req_vld_i;
    wire m1_rsp_rdy_i;
    wire m1_we_i;
    wire m1_req_rdy_o;
    wire m1_rsp_vld_o;
    wire[31:0] m1_data_o;

    // master 2 interface
    wire[31:0] m2_addr_i;
    wire[31:0] m2_data_i;
    wire[3:0] m2_sel_i;
    wire m2_req_vld_i;
    wire m2_rsp_rdy_i;
    wire m2_we_i;
    wire m2_req_rdy_o;
    wire m2_rsp_vld_o;
    wire[31:0] m2_data_o;

    // master 3 interface
    wire[31:0] m3_addr_i;
    wire[31:0] m3_data_i;
    wire[3:0] m3_sel_i;
    wire m3_req_vld_i;
    wire m3_rsp_rdy_i;
    wire m3_we_i;
    wire m3_req_rdy_o;
    wire m3_rsp_vld_o;
    wire[31:0] m3_data_o;

    // slave 0 interface
    wire[31:0] s0_data_i;
    wire s0_req_rdy_i;
    wire s0_rsp_vld_i;
    wire[31:0] s0_addr_o;
    wire[31:0] s0_data_o;
    wire[3:0] s0_sel_o;
    wire s0_req_vld_o;
    wire s0_rsp_rdy_o;
    wire s0_we_o;

    // slave 1 interface
    wire[31:0] s1_data_i;
    wire s1_req_rdy_i;
    wire s1_rsp_vld_i;
    wire[31:0] s1_addr_o;
    wire[31:0] s1_data_o;
    wire[3:0] s1_sel_o;
    wire s1_req_vld_o;
    wire s1_rsp_rdy_o;
    wire s1_we_o;

    // slave 2 interface
    wire[31:0] s2_data_i;
    wire s2_req_rdy_i;
    wire s2_rsp_vld_i;
    wire[31:0] s2_addr_o;
    wire[31:0] s2_data_o;
    wire[3:0] s2_sel_o;
    wire s2_req_vld_o;
    wire s2_rsp_rdy_o;
    wire s2_we_o;

    // slave 3 interface
    wire[31:0] s3_data_i;
    wire s3_req_rdy_i;
    wire s3_rsp_vld_i;
    wire[31:0] s3_addr_o;
    wire[31:0] s3_data_o;
    wire[3:0] s3_sel_o;
    wire s3_req_vld_o;
    wire s3_rsp_rdy_o;
    wire s3_we_o;
 
    // slave 4 interface
    wire[31:0] s4_data_i;
    wire s4_req_rdy_i;
    wire s4_rsp_vld_i;
    wire[31:0] s4_addr_o;
    wire[31:0] s4_data_o;
    wire[3:0] s4_sel_o;
    wire s4_req_vld_o;
    wire s4_rsp_rdy_o;
    wire s4_we_o;

    // slave 5 interface (for I2C)
    wire[31:0] s5_data_i;
    wire s5_req_rdy_i;
    wire s5_rsp_vld_i;
    wire[31:0] s5_addr_o;
    wire[31:0] s5_data_o;
    wire[3:0] s5_sel_o;
    wire s5_req_vld_o;
    wire s5_rsp_rdy_o;
    wire s5_we_o;

    // slave 6 interface (for SPI)
    wire[31:0] s6_data_i;
    wire s6_req_rdy_i;
    wire s6_rsp_vld_i;
    wire[31:0] s6_addr_o;
    wire[31:0] s6_data_o;
    wire[3:0] s6_sel_o;
    wire s6_req_vld_o;
    wire s6_rsp_rdy_o;
    wire s6_we_o;

    // slave 7 interface (for ADC)
    wire[31:0] s7_data_i;
    wire s7_req_rdy_i;
    wire s7_rsp_vld_i;
    wire[31:0] s7_addr_o;
    wire[31:0] s7_data_o;
    wire[3:0] s7_sel_o;
    wire s7_req_vld_o;
    wire s7_rsp_rdy_o;
    wire s7_we_o;

    // jtag
    wire jtag_halt_req_o;
    wire jtag_reset_req_o;
    wire[4:0] jtag_reg_addr_o;
    wire[31:0] jtag_reg_data_o;
    wire jtag_reg_we_o;
    wire[31:0] jtag_reg_data_i;

    // tinyriscv
    wire[`INT_WIDTH-1:0] int_flag;
    wire rst_n;
    wire jtag_rst_n;

    // timer0
    wire timer0_int;

    // gpio
    wire[1:0] io_in;
    wire[31:0] gpio_ctrl;
    wire[31:0] gpio_data;

    assign int_flag = {{(`INT_WIDTH-1){1'b0}}, timer0_int};

    // 复位控制模块例化
    rst_ctrl u_rst_ctrl(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .rst_jtag_i(jtag_reset_req_o),
        .core_rst_n_o(rst_n),
        .jtag_rst_n_o(jtag_rst_n)
    );

    // 低电平点亮LED
    // 低电平表示已经halt住CPU
    assign halted_ind = ~jtag_halt_req_o;

    wire jtag_pc_we;
    wire [31:0] jtag_pc_wdata;

    // tinyriscv处理器核模块例化
    tinyriscv_core u_tinyriscv_core(
        .clk(clk),
        .rst_n(rst_n),

        // 指令总线
        .ibus_addr_o(m0_addr_i),
        .ibus_data_i(m0_data_o),
        .ibus_data_o(m0_data_i),
        .ibus_we_o(m0_we_i),
        .ibus_sel_o(m0_sel_i),
        .ibus_req_valid_o(m0_req_vld_i),
        .ibus_req_ready_i(m0_req_rdy_o),
        .ibus_rsp_valid_i(m0_rsp_vld_o),
        .ibus_rsp_ready_o(m0_rsp_rdy_i),

        // 数据总线
        .dbus_addr_o(m1_addr_i),
        .dbus_data_i(m1_data_o),
        .dbus_data_o(m1_data_i),
        .dbus_we_o(m1_we_i),
        .dbus_sel_o(m1_sel_i),
        .dbus_req_valid_o(m1_req_vld_i),
        .dbus_req_ready_i(m1_req_rdy_o),
        .dbus_rsp_valid_i(m1_rsp_vld_o),
        .dbus_rsp_ready_o(m1_rsp_rdy_i),

        .jtag_pc_we_i(jtag_pc_we),
        .jtag_pc_wdata_i(jtag_pc_wdata),

        .jtag_halt_i(jtag_halt_req_o),
        .int_i(int_flag)
    );

    // 指令存储器
    rom #(
        .DP(`ROM_DEPTH)
    ) u_rom(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s0_addr_o),
        .data_i(s0_data_o),
        .sel_i(s0_sel_o),
        .we_i(s0_we_o),
        .data_o(s0_data_i),
        .req_valid_i(s0_req_vld_o),
        .req_ready_o(s0_req_rdy_i),
        .rsp_valid_o(s0_rsp_vld_i),
        .rsp_ready_i(s0_rsp_rdy_o)
    );

    // 数据存储器
    ram #(
        .DP(`RAM_DEPTH)
    ) u_ram(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s1_addr_o),
        .data_i(s1_data_o),
        .sel_i(s1_sel_o),
        .we_i(s1_we_o),
        .data_o(s1_data_i),
        .req_valid_i(s1_req_vld_o),
        .req_ready_o(s1_req_rdy_i),
        .rsp_valid_o(s1_rsp_vld_i),
        .rsp_ready_i(s1_rsp_rdy_o)
    );

    // timer模块例化
    timer timer_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s2_addr_o),
        .data_i(s2_data_o),
        .sel_i(s2_sel_o),
        .we_i(s2_we_o),
        .data_o(s2_data_i),
        .req_valid_i(s2_req_vld_o),
        .req_ready_o(s2_req_rdy_i),
        .rsp_valid_o(s2_rsp_vld_i),
        .rsp_ready_i(s2_rsp_rdy_o),
        .int_sig_o(timer0_int)
    );

    // uart模块例化
    uart uart_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .sel_i(s3_sel_o),
        .we_i(s3_we_o),
        .data_o(s3_data_i),
        .req_valid_i(s3_req_vld_o),
        .req_ready_o(s3_req_rdy_i),
        .rsp_valid_o(s3_rsp_vld_i),
        .rsp_ready_i(s3_rsp_rdy_o),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // io0
    assign gpio[0] = (gpio_ctrl[1:0] == 2'b01)? gpio_data[0]: 1'bz;
    assign io_in[0] = gpio[0];
    // io1
    assign gpio[1] = (gpio_ctrl[3:2] == 2'b01)? gpio_data[1]: 1'bz;
    assign io_in[1] = gpio[1];

    // gpio模块例化
    gpio gpio_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s4_addr_o),
        .data_i(s4_data_o),
        .sel_i(s4_sel_o),
        .we_i(s4_we_o),
        .data_o(s4_data_i),
        .req_valid_i(s4_req_vld_o),
        .req_ready_o(s4_req_rdy_i),
        .rsp_valid_o(s4_rsp_vld_i),
        .rsp_ready_i(s4_rsp_rdy_o),
        .io_pin_i(io_in),
        .reg_ctrl(gpio_ctrl),
        .reg_data(gpio_data)
    );

// // I2C Wrapper的输入输出信号
// wire scl_o, scl_t, sda_o, sda_t;
// wire scl_i, sda_i;

// // 使用IOBUF原语
// // SCL引脚
// IOBUF scl_iobuf (
//     .I    (scl_o),   // 从Wrapper到IO
//     .O    (scl_i),   // 从IO到Wrapper
//     .T    (scl_t),   // Wrapper的三态控制信号
//     .IO   (i2c_scl) // 连接到FPGA物理引脚
// );

// // SDA引脚
// IOBUF sda_iobuf (
//     .I    (sda_o),
//     .O    (sda_i),
//     .T    (sda_t),
//     .IO   (i2c_sda)
// );

// 实例化修正后的Wrapper
i2c_controller u_i2c (
    // RIB总线接口
    .clk(clk),
    .rst_n(rst_n),
    .addr_i(s5_addr_o),
    .data_i(s5_data_o),
    .sel_i(s5_sel_o),
    .we_i(s5_we_o),
    .data_o(s5_data_i),      // 向总线提供读数据 
    .req_valid_i(s5_req_vld_o), // 从总线接收请求有效信号 
    .req_ready_o(s5_req_rdy_i), // 向总线提供就绪信号 
    .rsp_valid_o(s5_rsp_vld_i), // 向总线提供响应有效信号 
    .rsp_ready_i(s5_rsp_rdy_o),

    // // I2C物理引脚接口 (连接到IOBUF)
    // .scl_i(scl_i),
    // .scl_o(scl_o),
    // .scl_t(scl_t),
    // .sda_i(sda_i),
    // .sda_o(sda_o),
    // .sda_t(sda_t)
    .io_scl(i2c_scl),
    .io_sda(i2c_sda)
);

    // spi_wrapper module instantiation
    spi_wrapper #(
        .SPI_MODE(0), // Can be 0, 1, 2, or 3
        .CLKS_PER_HALF_BIT(4) // Adjust for desired SPI speed
    ) spi_0 (
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .sel_i(s6_sel_o),
        .we_i(s6_we_o),
        .data_o(s6_data_i),
        .req_valid_i(s6_req_vld_o),
        .req_ready_o(s6_req_rdy_i),
        .rsp_valid_o(s6_rsp_vld_i),
        .rsp_ready_i(s6_rsp_rdy_o),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_csn(spi_csn)
    );

    parameter ADC_WIDTH = 12;
    parameter DATAWIDTH = 16;
    parameter ADC_CHANEL = 2;

    (* MARK_DEBUG="true" *)wire  [ADC_WIDTH*ADC_CHANEL-1:0]adc_data_1;
    (* MARK_DEBUG="true" *)wire  data_ready_out_1;

    sipo_converter #(.DATA_WIDTH(ADC_WIDTH*ADC_CHANEL)) sipo_a (
        .clk(clk), .rst_n(rst_n),
        .data_valid_in(data_valid_in), .serial_data_in(serial_data_in),
        .parallel_data_out(adc_data), .data_ready_out(data_ready_out)
    );
    assign adc_data_1 = adc_data;
    assign data_ready_out_1 =  data_ready_out;
    // top模块例化
    ADC_UDP_top #(
        .ADC_WIDTH(ADC_WIDTH),      // ADC数据宽度12位
        .DATAWIDTH(DATAWIDTH),      // 内部数据处理宽度16位
        .ADC_CHANEL(ADC_CHANEL)      // ADC通道数2个
    ) u_ADC_UDP_top_inst (
        // 时钟和复位
        .clk(clk),
        .clk_udp(clk_125m),
        .rst(rst_n),

        // RIB总线接口
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_we_o(s7_we_o),
        .s7_data_i(s7_data_i),
        .req_valid_i(s7_req_vld_o), // 从总线接收请求有效信号 
        .req_ready_o(s7_req_rdy_i), // 向总线提供就绪信号 
        .rsp_valid_o(s7_rsp_vld_i), // 向总线提供响应有效信号 
        .rsp_ready_i(s7_rsp_rdy_o),

        // ADC输入
        .rec_ADC_data(adc_data_1),
        .adc_data_ready(data_ready_out_1),
        
        // 以太网PHY接口
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_rst_n(eth_rst_n),
        .eth_txd(eth_txd)
        

    );
    // jtag模块例化
    jtag_top #(
        .DMI_ADDR_BITS(6),
        .DMI_DATA_BITS(32),
        .DMI_OP_BITS(2)
    ) u_jtag_top(
        .clk(clk),
        .jtag_rst_n(jtag_rst_n),
        .jtag_pin_TCK(jtag_TCK),
        .jtag_pin_TMS(jtag_TMS),
        .jtag_pin_TDI(jtag_TDI),
        .jtag_pin_TDO(jtag_TDO),

        .jtag_pc_we_o(jtag_pc_we),
        .jtag_pc_wdata_o(jtag_pc_wdata),

        .reg_we_o(jtag_reg_we_o),
        .reg_addr_o(jtag_reg_addr_o),
        .reg_wdata_o(jtag_reg_data_o),
        .reg_rdata_i(jtag_reg_data_i),
        .mem_we_o(m2_we_i),
        .mem_addr_o(m2_addr_i),
        .mem_wdata_o(m2_data_i),
        .mem_rdata_i(m2_data_o),
        .mem_sel_o(m2_sel_i),
        .req_valid_o(m2_req_vld_i),
        .req_ready_i(m2_req_rdy_o),
        .rsp_valid_i(m2_rsp_vld_o),
        .rsp_ready_o(m2_rsp_rdy_i),
        .halt_req_o(jtag_halt_req_o),
        .reset_req_o(jtag_reset_req_o)
    );

    // rib总线模块例化
    rib #(
        .MASTER_NUM(3),
        .SLAVE_NUM(8)
    ) u_rib(
        .clk(clk),
        .rst_n(rst_n),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_sel_i(m0_sel_i),
        .m0_req_vld_i(m0_req_vld_i),
        .m0_rsp_rdy_i(m0_rsp_rdy_i),
        .m0_we_i(m0_we_i),
        .m0_req_rdy_o(m0_req_rdy_o),
        .m0_rsp_vld_o(m0_rsp_vld_o),
        .m0_data_o(m0_data_o),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(m1_data_i),
        .m1_sel_i(m1_sel_i),
        .m1_req_vld_i(m1_req_vld_i),
        .m1_rsp_rdy_i(m1_rsp_rdy_i),
        .m1_we_i(m1_we_i),
        .m1_req_rdy_o(m1_req_rdy_o),
        .m1_rsp_vld_o(m1_rsp_vld_o),
        .m1_data_o(m1_data_o),

        // master 2 interface
        .m2_addr_i(m2_addr_i),
        .m2_data_i(m2_data_i),
        .m2_sel_i(m2_sel_i),
        .m2_req_vld_i(m2_req_vld_i),
        .m2_rsp_rdy_i(m2_rsp_rdy_i),
        .m2_we_i(m2_we_i),
        .m2_req_rdy_o(m2_req_rdy_o),
        .m2_rsp_vld_o(m2_rsp_vld_o),
        .m2_data_o(m2_data_o),

        // master 3 interface
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_sel_i(m3_sel_i),
        .m3_req_vld_i(m3_req_vld_i),
        .m3_rsp_rdy_i(m3_rsp_rdy_i),
        .m3_we_i(m3_we_i),
        .m3_req_rdy_o(m3_req_rdy_o),
        .m3_rsp_vld_o(m3_rsp_vld_o),
        .m3_data_o(m3_data_o),

        // slave 0 interface
        .s0_data_i(s0_data_i),
        .s0_req_rdy_i(s0_req_rdy_i),
        .s0_rsp_vld_i(s0_rsp_vld_i),
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_sel_o(s0_sel_o),
        .s0_req_vld_o(s0_req_vld_o),
        .s0_rsp_rdy_o(s0_rsp_rdy_o),
        .s0_we_o(s0_we_o),

        // slave 1 interface
        .s1_data_i(s1_data_i),
        .s1_req_rdy_i(s1_req_rdy_i),
        .s1_rsp_vld_i(s1_rsp_vld_i),
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_sel_o(s1_sel_o),
        .s1_req_vld_o(s1_req_vld_o),
        .s1_rsp_rdy_o(s1_rsp_rdy_o),
        .s1_we_o(s1_we_o),

        // slave 2 interface
        .s2_data_i(s2_data_i),
        .s2_req_rdy_i(s2_req_rdy_i),
        .s2_rsp_vld_i(s2_rsp_vld_i),
        .s2_addr_o(s2_addr_o),
        .s2_data_o(s2_data_o),
        .s2_sel_o(s2_sel_o),
        .s2_req_vld_o(s2_req_vld_o),
        .s2_rsp_rdy_o(s2_rsp_rdy_o),
        .s2_we_o(s2_we_o),

        // slave 3 interface
        .s3_data_i(s3_data_i),
        .s3_req_rdy_i(s3_req_rdy_i),
        .s3_rsp_vld_i(s3_rsp_vld_i),
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_sel_o(s3_sel_o),
        .s3_req_vld_o(s3_req_vld_o),
        .s3_rsp_rdy_o(s3_rsp_rdy_o),
        .s3_we_o(s3_we_o),

        // slave 4 interface
        .s4_data_i(s4_data_i),
        .s4_req_rdy_i(s4_req_rdy_i),
        .s4_rsp_vld_i(s4_rsp_vld_i),
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_sel_o(s4_sel_o),
        .s4_req_vld_o(s4_req_vld_o),
        .s4_rsp_rdy_o(s4_rsp_rdy_o),
        .s4_we_o(s4_we_o),

        // ADD THE NEW SLAVE 5 INTERFACE
        .s5_data_i(s5_data_i),
        .s5_req_rdy_i(s5_req_rdy_i),
        .s5_rsp_vld_i(s5_rsp_vld_i),
        .s5_addr_o(s5_addr_o),
        .s5_data_o(s5_data_o),
        .s5_sel_o(s5_sel_o),
        .s5_req_vld_o(s5_req_vld_o),
        .s5_rsp_rdy_o(s5_rsp_rdy_o),
        .s5_we_o(s5_we_o),

        // ADD THE NEW SLAVE 6 INTERFACE
        .s6_data_i(s6_data_i),
        .s6_req_rdy_i(s6_req_rdy_i),
        .s6_rsp_vld_i(s6_rsp_vld_i),
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_sel_o(s6_sel_o),
        .s6_req_vld_o(s6_req_vld_o),
        .s6_rsp_rdy_o(s6_rsp_rdy_o),
        .s6_we_o(s6_we_o),

        //ADD the new slave 7 interface

        .s7_data_i(s7_data_i),
        .s7_req_rdy_i(s7_req_rdy_i),
        .s7_rsp_vld_i(s7_rsp_vld_i),
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_sel_o(s7_sel_o),
        .s7_req_vld_o(s7_req_vld_o),
        .s7_rsp_rdy_o(s7_rsp_rdy_o),
        .s7_we_o(s7_we_o)

    );

endmodule
