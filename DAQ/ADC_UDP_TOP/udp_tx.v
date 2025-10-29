`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 11:46:06
// Design Name: 
// Module Name: udp_tx
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


module udp_tx #(
parameter DATAWIDTH = 16,
parameter ADC_CHANEL = 8
)
(

    input [47:0] BOARD_MAC,
    input [31:0] BOARD_IP,
    input [47:0] DES_MAC,
    input [31:0] DES_IP,
	input [15:0] BOARD_PORT,
    input [15:0] DES_PORT,
input wire clk,
input wire rst_n,
input wire tx_start_en,//以太网开始发送信号标志
input wire [ADC_CHANEL*DATAWIDTH-1:0]tx_data,//数据
input wire [15:0] tx_byte_num,//有效数据长度
input wire [31:0] crc_data,//crc校验数据
input wire [7:0] crc_next,//下一个crc校验数据
output reg tx_done,//以太网发送数据完成
output reg tx_req,//数据读取请求信号
output reg gmii_tx_en,//GMII输出数据有效信号
output reg [7:0] gmii_txd,//GMII输出数据
output reg crc_en,//CRC使能信号
output reg crc_clr//CRC数据复位信号
    );

localparam IPLEN = 16'd28;
localparam UDPLEN = 16'd8;

reg [7:0]test;
localparam  IDLE      = 7'b000_0001; //初始状态，等待开始发送信号
localparam  CHECKSUM = 7'b000_0010; //IP首部校验和
localparam  PACKET_HEAD  = 7'b000_0100; //发送前导码+帧起始界定符
localparam  ETH_HEAD  = 7'b000_1000; //发送以太网帧头
localparam  IP_UDP_HEAD   = 7'b001_0000; //发送IP首部+UDP首部
localparam  SEND_DATA   = 7'b010_0000; //发送数据
localparam  CRC       = 7'b100_0000; //发送CRC校验值

localparam  ETH_TYPE     = 16'h0800  ;  //以太网协议类型 IP协议
//以太网数据最小46个字节，IP首部20个字节+UDP首部8个字节
//所以数据至少46-20-8=18个字节
localparam  MIN_DATA_NUM = 16'd18    ;

//reg define
reg  [6:0]   cur_stat      ;
reg  [6:0]   next_stat     ;

reg  [7:0]   packet_head[7:0]  ; //前导码
reg  [7:0]   eth_head[13:0] ; //以太网首部
reg  [31:0]  ip_udp_head[6:0]   ; //IP首部 + UDP首部

reg          start_en_d0    ;
reg          start_en_d1    ;
reg  [15:0] data_len    ; //发送的有效数据字节个数
reg  [15:0]  ip_len      ; //总字节数
reg          trig_tx_en     ;
reg  [15:0]  udp_len        ; //UDP字节数
reg          sw_en        ; //控制状态跳转使能信号
reg  [4:0]   cnt            ;
reg  [31:0]  check_sum   ; //首部校验和
reg  [10:0]   tx_bit_sel     ;
reg  [15:0]  data_cnt       ; //发送数据个数计数器
reg          tx_done_t      ;
reg  [4:0]   cnt_add   ; //以太网数据实际多发的字节数

//wire define
wire         pos_start_en    ;//开始发送数据上升沿
wire [15:0]  real_tx_data_len;//实际发送的字节数(以太网最少字节要求)
//*****************************************************
//**                    main code
//*****************************************************

assign  pos_start_en = (~start_en_d1) & start_en_d0;
assign  real_tx_data_len = (data_len >= MIN_DATA_NUM)
                           ?data_len : MIN_DATA_NUM;

//采tx_start_en的上升沿
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        start_en_d0 <= 1'b0;
        start_en_d1 <= 1'b0;
    end
    else begin
        start_en_d0 <= tx_start_en;
        start_en_d1 <= start_en_d0;
    end
end

//寄存数据有效字节
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
       data_len <= 16'd0;
        ip_len <= 16'd0;
        udp_len <= 16'd0;
    end
    else begin
        if(pos_start_en && cur_stat==IDLE) begin
            //数据长度
           data_len <= tx_byte_num;
            //IP长度：有效数据+IP首部长度
            ip_len <= tx_byte_num + IPLEN;
            //UDP长度：有效数据+UDP首部长度
            udp_len <= tx_byte_num + UDPLEN;
        end
    end
end

//触发发送信号
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        trig_tx_en <= 1'b0;
    else
        trig_tx_en <= pos_start_en;

end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cur_stat <= IDLE;
    else
        cur_stat <= next_stat;
end

always @(*) begin
    next_stat = IDLE;
    case(cur_stat)
        IDLE     : begin                               //等待发送数据
            if(sw_en)
                next_stat = CHECKSUM;
            else
                next_stat = IDLE;
        end
        CHECKSUM: begin                               //IP首部校验
            if(sw_en)
                next_stat = PACKET_HEAD;
            else
                next_stat = CHECKSUM;
        end
        PACKET_HEAD : begin                               //发送前导码+帧起始界定符
            if(sw_en)
                next_stat = ETH_HEAD;
            else
                next_stat = PACKET_HEAD;
        end
        ETH_HEAD : begin                               //发送以太网首部
            if(sw_en)
                next_stat = IP_UDP_HEAD;
            else
                next_stat = ETH_HEAD;
        end
        IP_UDP_HEAD : begin                                //发送IP首部+UDP首部
            if(sw_en)
                next_stat = SEND_DATA;
            else
                next_stat = IP_UDP_HEAD;
        end
        SEND_DATA : begin                                //发送数据
            if(sw_en)
                next_stat = CRC;
            else
                next_stat = SEND_DATA;
        end
        CRC: begin                                     //发送CRC校验值
            if(sw_en)
                next_stat = IDLE;
            else
                next_stat = CRC;
        end
        default : next_stat = IDLE;
    endcase
end

//发送数据
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        sw_en <= 1'b0;
        cnt <= 5'd0;
        check_sum <= 32'd0;
        ip_udp_head[1][31:16] <= 16'd0;
        tx_bit_sel <= 0;
        crc_en <= 1'b0;
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'd0;
        tx_req <= 1'b0;
        test <=0;
        tx_done_t <= 1'b0;
        data_cnt <= 16'd0;
        cnt_add <= 5'd0;
        //初始化数组
        //前导码 7个8'h55 + 1个8'hd5
        packet_head[0] <= 8'h55;
        packet_head[1] <= 8'h55;
        packet_head[2] <= 8'h55;
        packet_head[3] <= 8'h55;
        packet_head[4] <= 8'h55;
        packet_head[5] <= 8'h55;
        packet_head[6] <= 8'h55;
        packet_head[7] <= 8'hd5;
        //目的MAC地址
        eth_head[0] <= 0;
        eth_head[1] <= 0;
        eth_head[2] <= 0;
        eth_head[3] <= 0;
        eth_head[4] <= 0;
        eth_head[5] <= 0;
        //源MAC地址
        eth_head[6] <= 0;
        eth_head[7] <= 0;
        eth_head[8] <= 0;
        eth_head[9] <= 0;
        eth_head[10] <= 0;
        eth_head[11] <= 0;
        //以太网类型
        eth_head[12] <= 0;
        eth_head[13] <= 0;
        //ip 
        ip_udp_head[0]<=0;
        ip_udp_head[1]<=0;
        ip_udp_head[2]<=0;
        ip_udp_head[3]<=0;
        ip_udp_head[4]<=0;
        ip_udp_head[5]<=0;
        ip_udp_head[6]<=0;
    end

   else begin
		sw_en <=1'b0;
		tx_req <=1'b0;
		crc_en <=1'b0;
		gmii_tx_en <=1'b0;
		tx_done_t <= 1'b0;
		case(next_stat)
			IDLE :
				if(trig_tx_en) begin
					sw_en<=1'b1;
					//8'h45 :4 表示版本为ipv4 , 5表示首部长度位5 个32位bit (总长度20字节，20/4=5) ;
					//8'h00：服务类型（优先级等）默认为0
					ip_udp_head[0] <= {8'h45,8'h00,ip_len};
					//16位标识，每次发送累加1，用于跟踪每个发送的数据包
                			ip_udp_head[1][31:16] <= ip_udp_head[1][31:16] + 1'b1;
                			//bit[15:13]: 010表示不分片，000000000000 表示片偏移为 0
                			ip_udp_head[1][15:0] <= 16'h4000;
                    			//8'h40 :生存时间 8'd17:协议：17(udp),16'h0:ip校验和
                    			ip_udp_head[2] <= {8'h40,8'd17,16'h0};
                   		 	//源IP地址
                    			ip_udp_head[3] <= BOARD_IP;
                    			//目的IP地址
                    			ip_udp_head[4] <= DES_IP;
                    			//16位源端口号：1234  16位目的端口号：1234,UDP传输为两台电脑之间程序端口端口之间的传输
                    			ip_udp_head[5] <= {BOARD_PORT,DES_PORT};
                    			//16位udp长度，16位udp校验和
                    			ip_udp_head[6] <= {udp_len,16'h0000};
 				end
			CHECKSUM :begin 
		                 //IP首部校验
                		cnt <= cnt + 5'd1;
				if(cnt == 5'd0)
                   			check_sum <= ip_udp_head[0][31:16] + ip_udp_head[0][15:0]
                                    		   + ip_udp_head[1][31:16] + ip_udp_head[1][15:0]
                                 		   + ip_udp_head[2][31:16] + ip_udp_head[2][15:0]
                       				   + ip_udp_head[3][31:16] + ip_udp_head[3][15:0]
                               			   + ip_udp_head[4][31:16] + ip_udp_head[4][15:0];
                		
               			else if(cnt == 5'd1)    //可能出现进位,即十六位的数相加结果位17位,有溢出，需要将溢出的进位加到低位，累加一次
                    			check_sum <= check_sum[31:16] + check_sum[15:0];
                		else if(cnt == 5'd2)              
                    			check_sum <= check_sum[31:16] + check_sum[15:0];
				else if(cnt == 5'd3)begin               //按位取反
                    			sw_en <= 1'b1;
                   			cnt <= 5'd0;
                    			ip_udp_head[2][15:0] <= ~check_sum[15:0]; 
				end
			end
			PACKET_HEAD :begin                     //发送前导码+帧起始界定符
                			gmii_tx_en <= 1'b1;
                			gmii_txd <= packet_head[cnt];
                			if(cnt == 5'd7) begin
                    				sw_en <= 1'b1;
                    				cnt <= 5'd0;
                			end
                			else
                   			 cnt <= cnt + 5'd1;
			 end
			 ETH_HEAD : begin                         //发送以太网首部
                		gmii_tx_en <= 1'b1;
                		crc_en <= 1'b1;
                        if(cnt==5'd0)begin
                           //目的MAC地址
        eth_head[0] <= DES_MAC[47:40];
        eth_head[1] <= DES_MAC[39:32];
        eth_head[2] <= DES_MAC[31:24];
        eth_head[3] <= DES_MAC[23:16];
        eth_head[4] <= DES_MAC[15:8];
        eth_head[5] <= DES_MAC[7:0];
        //源MAC地址
        eth_head[6] <= BOARD_MAC[47:40];
        eth_head[7] <= BOARD_MAC[39:32];
        eth_head[8] <= BOARD_MAC[31:24];
        eth_head[9] <= BOARD_MAC[23:16];
        eth_head[10] <= BOARD_MAC[15:8];
        eth_head[11] <= BOARD_MAC[7:0];
        //以太网类型
        eth_head[12] <= ETH_TYPE[15:8];
        eth_head[13] <= ETH_TYPE[7:0];

                        end
                		gmii_txd <= eth_head[cnt];
                		if (cnt == 5'd13) begin
                    			sw_en <= 1'b1;
                   	 		cnt <= 5'd0;
                		end
                		else
                    			cnt <= cnt + 5'd1;
			end
			IP_UDP_HEAD :begin
				crc_en <= 1'b1;
                		gmii_tx_en <= 1'b1;
                		tx_bit_sel <= tx_bit_sel + 2'd1;
               			if(tx_bit_sel == 3'd0)
                    			gmii_txd <= ip_udp_head[cnt][31:24];
                		else if(tx_bit_sel == 3'd1)
                    			gmii_txd <= ip_udp_head[cnt][23:16];
                		else if(tx_bit_sel == 3'd2) begin
                    			gmii_txd <= ip_udp_head[cnt][15:8];
                    			if(cnt == 5'd6) begin
                        		//提前读请求数据，等待数据有效时发送
                       	 		tx_req <= 1'b1;
                    			end
               	 		end
                		else if(tx_bit_sel == 3'd3) begin
                    			gmii_txd <= ip_udp_head[cnt][7:0];
                                tx_bit_sel<=0;
                    			if(cnt == 5'd6) begin
                        			sw_en <= 1'b1;
                        			cnt <= 5'd0;  
                    			end
                    			else
                        			cnt <= cnt + 5'd1;
                		end
			end
			SEND_DATA :    begin                       //发送数据
                			crc_en <= 1'b1;
                			gmii_tx_en <= 1'b1;
                			tx_bit_sel <= tx_bit_sel + 3'd1;
                			if(data_cnt < data_len - 16'd1)
                    				data_cnt <= data_cnt + 16'd1;
                			else if(data_cnt == data_len - 16'd1)begin
                    			//如果发送的有效数据少于18个字节，在后面填补充位,补充的值为最后一次发送的有效数据
                    				//gmii_txd <= 8'd0;
                    				if(data_cnt + cnt_add < real_tx_data_len - 16'd1)
                        				cnt_add <= cnt_add + 5'd1;
                    				else begin
                        				sw_en <= 1'b1;
                        				data_cnt <= 16'd0;
                        				cnt_add <= 5'd0;
                        				tx_bit_sel<=0;
                    					end
                			end
                            
					if (data_cnt < data_len) begin // Sending actual payload data from FIFO
                  		 gmii_txd <= tx_data[ADC_CHANEL*DATAWIDTH-tx_bit_sel*8-8 +: 8];	
                        if (data_cnt < data_len - (((ADC_CHANEL*DATAWIDTH)>>3)+1)&&tx_bit_sel==((ADC_CHANEL*DATAWIDTH)>>3)-2)  // Check if more bytes needed after this one
                           				tx_req <= 1'b1;
						else if(tx_bit_sel==(((ADC_CHANEL*DATAWIDTH)>>3)-1))begin  // Byte 2
                            tx_bit_sel <= 0; 
						end
               		end 
					else // Sending padding bytes
                  				gmii_txd <= 8'd0; // Send zero for padding
				end
				CRC      :  begin                         //发送CRC校验值
                		gmii_tx_en <= 1'b1;
                		tx_bit_sel <= tx_bit_sel + 3'd1;
                		if(tx_bit_sel == 3'd0)
                    			gmii_txd <= {~crc_next[0], ~crc_next[1], ~crc_next[2],~crc_next[3], ~crc_next[4], ~crc_next[5], ~crc_next[6],~crc_next[7]};
                		else if(tx_bit_sel == 3'd1)
                    			gmii_txd <= {~crc_data[16], ~crc_data[17], ~crc_data[18],~crc_data[19],~crc_data[20], ~crc_data[21], ~crc_data[22],~crc_data[23]};
                		else if(tx_bit_sel == 3'd2)
                    			gmii_txd <= {~crc_data[8], ~crc_data[9], ~crc_data[10],~crc_data[11], ~crc_data[12], ~crc_data[13], ~crc_data[14],~crc_data[15]};
                		else if(tx_bit_sel == 3'd3) begin
                    			gmii_txd <= {~crc_data[0], ~crc_data[1], ~crc_data[2],~crc_data[3], ~crc_data[4], ~crc_data[5], ~crc_data[6],~crc_data[7]};
                    			tx_done_t <= 1'b1;
                    			sw_en <= 1'b1;
                                tx_bit_sel <=0;
                		end
			end
            default :;
        endcase
    end
end
/*
ila_0 ila_inst1 (
    .clk(clk), // input wire clk
  //  .probe0({DataAccept,pending_data_accept,data_accepted}), // input wire [99:0] probe0
  .probe0({tx_bit_sel,next_stat,tx_start_en}),
.probe1({gmii_tx_en,gmii_txd,tx_req,tx_data})
);*/
//发送完成信号及crc值复位信号
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tx_done <= 1'b0;
        crc_clr <= 1'b0;
    end
    else begin
        tx_done <= tx_done_t;
        crc_clr <= tx_done_t;
    end
end

endmodule

