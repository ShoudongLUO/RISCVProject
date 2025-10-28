`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author  : EmbedFire
// 实验平台: 野火FPGA系列开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module udp #(
parameter ADC_WIDTH = 8,
parameter DATAWIDTH = 16,
parameter ADC_CHANEL = 8
)(
input [47:0] BOARD_MAC,
    input [31:0] BOARD_IP,
    input [47:0] DES_MAC,
    input [31:0] DES_IP,
	input [15:0] BOARD_PORT,
    input [15:0] DES_PORT,
	
    input                rst_n       , //复位信号，低电平有效
    //GMII接口
 
    input                gmii_tx_clk , //GMII发送数据时钟
    output               gmii_tx_en  , //GMII输出数据有效信号
    output       [7:0]   gmii_txd    , //GMII输出数据
    //用户接口
    input                tx_start_en , //以太网开始发送信号
    input wire [ADC_CHANEL*DATAWIDTH-1:0]tx_data,//数据
    input        [15:0]  tx_byte_num , //以太网发送的有效字节数 单位:byte
    output               tx_done     , //以太网发送完成信号
    output               tx_req        //读数据请求信号

    );


//wire define
wire          crc_en  ; //CRC开始校验使能
wire          crc_clr ; //CRC数据复位信号
wire  [7:0]   crc_d8  ; //输入待校验8位数据

wire  [31:0]  crc_data; //CRC校验数据
wire  [31:0]  crc_next; //CRC下次校验完成数据

//*****************************************************
//**                    main code
//*****************************************************

assign  crc_d8 = gmii_txd;

//以太网发送模块
udp_tx    #(
        .ADC_CHANEL(ADC_CHANEL)
    )
    u_udp_tx
    (
  .BOARD_MAC     (BOARD_MAC),
    .BOARD_IP      (BOARD_IP ),
    .BOARD_PORT     (BOARD_PORT),
    .DES_MAC       (DES_MAC  ),
    .DES_IP        (DES_IP   ),
	.DES_PORT       (DES_PORT),
    .clk             (gmii_tx_clk),
    .rst_n           (rst_n      ),
    .tx_start_en     (tx_start_en),
    .tx_data         (tx_data    ),
    .tx_byte_num     (tx_byte_num),
    .crc_data        (crc_data   ),
    .crc_next        (crc_next[31:24]),
    .tx_done         (tx_done    ),
    .tx_req          (tx_req     ),
    .gmii_tx_en      (gmii_tx_en ),
    .gmii_txd        (gmii_txd   ),
    .crc_en          (crc_en     ),
    .crc_clr         (crc_clr    )
    );

//以太网发送CRC校验模块
crc32_d8   u_crc32_d8(
    .clk             (gmii_tx_clk),
    .rst_n           (rst_n      ),
    .data            (crc_d8     ),
    .crc_en          (crc_en     ),
    .crc_clr         (crc_clr    ),
    .crc_data        (crc_data   ),
    .crc_next        (crc_next   )
    );

endmodule
