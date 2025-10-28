/* ===========================================================
 *  Project      : Tiny_FPGA
 *  Unique Tag   : Auto‑generated header (do not remove this line!!!)
 *  Log（开发日志）:
    1. 2025-07-25 Created header by Albert
    2. 2025-07-30 Corrected by Gemini to fix receiver overrun and bit order issues.
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

// 串口收发模块(默认: 115200, 8，N，1)
module uart(

    input wire clk,
    input wire rst_n,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire[3:0] sel_i,
    input wire we_i,
	output wire[31:0] data_o,

    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,

	output wire tx_pin,
    input wire rx_pin

    );

    // 波特率115200bps
    localparam BAUD_115200 = `CPU_CLOCK_HZ / 115200;

    localparam S_IDLE       = 4'b0001;
    localparam S_START      = 4'b0010;
    localparam S_SEND_BYTE  = 4'b0100;
    localparam S_STOP       = 4'b1000;


    reg[3:0] state;
    reg[3:0] next_state;
    reg[15:0] cycle_cnt;
    reg tx_bit;
    reg[3:0] bit_cnt;

    reg rx_q0;
    reg rx_q1;
    wire rx_negedge;
    reg rx_start;                      // RX使能
    reg[3:0] rx_clk_edge_cnt;          // clk沿的个数
    reg rx_clk_edge_level;             // clk沿电平
    reg rx_done_pulse;                 // ★ 新增: 接收完成脉冲信号
    reg[15:0] rx_clk_cnt;
    reg[15:0] rx_div_cnt;
    reg[7:0] rx_data;
    reg rx_over;

    // 寄存器(偏移)地址
    localparam UART_CTRL    = 8'h0;
    localparam UART_STATUS  = 8'h4;
    localparam UART_BAUD    = 8'h8;
    localparam UART_TXDATA  = 8'hc;
    localparam UART_RXDATA  = 8'h10;

    // UART控制寄存器，可读可写
    // bit[0]: UART TX使能, 1: enable, 0: disable
    // bit[1]: UART RX使能, 1: enable, 0: disable
    reg[31:0] uart_ctrl;

    // UART状态寄存器
    // bit[0]: TX忙标志, 1: busy, 0: idle (只读)
    // bit[1]: RX接收完成标志, 1: over, 0: not over (读/写清除)
    reg[31:0] uart_status;

    // UART波特率寄存器(分频系数)，可读可写
    reg[31:0] uart_baud;

    // UART发送数据寄存器，可读可写
    reg[31:0] uart_tx;

    // UART接收数据寄存器，只读
    reg[31:0] uart_rx;

    wire wen = we_i & req_valid_i;
    wire ren = (~we_i) & req_valid_i;
    wire write_reg_ctrl_en = wen & (addr_i[7:0] == UART_CTRL);
    wire write_reg_status_en = wen & (addr_i[7:0] == UART_STATUS);
    wire write_reg_baud_en = wen & (addr_i[7:0] == UART_BAUD);
    wire write_reg_txdata_en = wen & (addr_i[7:0] == UART_TXDATA);
    wire tx_start = write_reg_txdata_en & sel_i[0] & uart_ctrl[0] & (~uart_status[0]);
    wire rx_recv_over = uart_ctrl[1] & rx_over;

    assign tx_pin = tx_bit;


    // 写uart_rxdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx <= 32'h0;
        end else begin
            // 接收完成时，保存接收到的数据
            if (rx_recv_over) begin
                uart_rx[7:0] <= rx_data;
            end
        end
    end

    // 写uart_txdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx <= 32'h0;
        end else begin
            // 开始发送时，保存要发送的数据
            if (tx_start) begin
                uart_tx[7:0] <= data_i[7:0];
            end
        end
    end

    // 写uart_status
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_status <= 32'h0;
        end else begin
            // 写操作优先
            if (write_reg_status_en & sel_i[0]) begin
                // CPU通过写0来清除RX完成标志
                uart_status[1] <= data_i[1];
            end else begin
                // TX状态更新
                if (tx_start) begin
                    uart_status[0] <= 1'b1;
                end else if ((state == S_STOP) & (cycle_cnt == uart_baud[15:0])) begin
                    uart_status[0] <= 1'b0;
                end
                
                // RX状态更新
                if (rx_recv_over) begin
                    uart_status[1] <= 1'b1;
                end
            end
        end
    end

    // 写uart_ctrl
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ctrl <= 32'h0;
        end else begin
            if (write_reg_ctrl_en & sel_i[0]) begin
                uart_ctrl[7:0] <= data_i[7:0];
            end
        end
    end

    // 写uart_baud
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_baud <= BAUD_115200;
        end else begin
            if (write_reg_baud_en) begin
                if (sel_i[0]) begin
                    uart_baud[7:0] <= data_i[7:0];
                end
                if (sel_i[1]) begin
                    uart_baud[15:8] <= data_i[15:8];
                end
            end
        end
    end

    reg[31:0] data_r;

    // 读寄存器
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_r <= 32'h0;
        end else begin
            if (ren) begin
                case (addr_i[7:0])
                    UART_CTRL:   data_r <= uart_ctrl;
                    UART_STATUS: data_r <= uart_status;
                    UART_BAUD:   data_r <= uart_baud;
                    UART_RXDATA: data_r <= uart_rx;
                    default:     data_r <= 32'h0;
                endcase
            end else begin
                data_r <= 32'h0;
            end
        end
    end

    assign data_o = data_r;

    // *************************** TX发送 (无修改) ****************************
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @ (*) begin
        case (state)
            S_IDLE: next_state = tx_start ? S_START : S_IDLE;
            S_START: next_state = (cycle_cnt == uart_baud[15:0]) ? S_SEND_BYTE : S_START;
            S_SEND_BYTE: next_state = ((cycle_cnt == uart_baud[15:0]) && (bit_cnt == 4'd7)) ? S_STOP : S_SEND_BYTE;
            S_STOP: next_state = (cycle_cnt == uart_baud[15:0]) ? S_IDLE : S_STOP;
            default: next_state = S_IDLE;
        endcase
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin cycle_cnt <= 16'h0; end
        else if (state == S_IDLE) begin cycle_cnt <= 16'h0; end
        else if (cycle_cnt == uart_baud[15:0]) begin cycle_cnt <= 16'h0; end
        else begin cycle_cnt <= cycle_cnt + 16'h1; end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin bit_cnt <= 4'h0; end
        else case (state)
            S_IDLE: bit_cnt <= 4'h0;
            S_SEND_BYTE: if (cycle_cnt == uart_baud[15:0]) bit_cnt <= bit_cnt + 4'h1;
        endcase
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin tx_bit <= 1'b1; end // ★ 复位时应为高电平
        else case (state)
            S_IDLE: tx_bit <= 1'b1;
            S_START: tx_bit <= 1'b0;
            S_SEND_BYTE: tx_bit <= uart_tx[bit_cnt];
            S_STOP: tx_bit <= 1'b1;
            default: tx_bit <= 1'b1;
        endcase
    end

    // *************************** RX接收 (已修正) ****************************

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_q0 <= 1'b1; // ★ 复位时应为高电平
            rx_q1 <= 1'b1;
        end else begin
            rx_q0 <= rx_pin;
            rx_q1 <= rx_q0;
        end
    end

    // 下降沿检测(检测起始信号)
    assign rx_negedge = rx_q1 & (~rx_q0);

    // ★★★ 修正点 1: 启动接收的条件 ★★★
    // 只有在接收使能、检测到下降沿、且上一个字符已被读取(状态位为0)时，才开始新一轮接收
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_start <= 1'b0;
        end else if (uart_ctrl[1]) begin
            if (rx_negedge && !uart_status[1]) begin // 增加 !uart_status[1] 条件
                rx_start <= 1'b1;
            end else if (rx_done_pulse) begin // 使用接收完成脉冲来停止
                rx_start <= 1'b0;
            end
        end else begin
            rx_start <= 1'b0;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_div_cnt <= 16'h0;
        end else begin
            // 第一个时钟沿只需波特率分频系数的一半
            if (rx_start && rx_clk_edge_cnt == 4'h0) begin
                rx_div_cnt <= {1'b0, uart_baud[15:1]};
            end else begin
                rx_div_cnt <= uart_baud[15:0];
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin rx_clk_cnt <= 16'h0; end
        else if (rx_start) begin
            if (rx_clk_cnt == rx_div_cnt) rx_clk_cnt <= 16'h0;
            else rx_clk_cnt <= rx_clk_cnt + 16'h1;
        end else begin
            rx_clk_cnt <= 16'h0;
        end
    end
    
    // 产生采样时刻脉冲 (rx_clk_edge_level) 和接收完成脉冲 (rx_done_pulse)
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
            rx_done_pulse <= 1'b0;
        end else begin
            rx_clk_edge_level <= 1'b0; // 默认为0
            rx_done_pulse <= 1'b0;   // 默认为0

            if (rx_start) begin
                if (rx_clk_cnt == rx_div_cnt) begin
                    rx_clk_edge_level <= 1'b1; // 产生一个时钟周期的采样脉冲
                    if (rx_clk_edge_cnt == 9) begin
                        rx_clk_edge_cnt <= 4'h0;
                        rx_done_pulse <= 1'b1; // ★ 接收完成，产生停止脉冲
                    end else begin
                        rx_clk_edge_cnt <= rx_clk_edge_cnt + 4'h1;
                    end
                end
            end else begin
                rx_clk_edge_cnt <= 4'h0;
            end
        end
    end
    
    // ★★★ 修正点 2: 硬件接收完成标志 (rx_over) 的管理 ★★★
    // 该标志在接收完成后置位，在CPU清除状态位后清零
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rx_over <= 1'b0;
        end else begin
            // 当接收完成脉冲有效时，置位
            if(rx_done_pulse) begin
                rx_over <= 1'b1;
            // 当CPU通过写状态寄存器清零标志位时，硬件也同步清零
            end else if (write_reg_status_en && !data_i[1]) begin
                rx_over <= 1'b0;
            end
        end
    end

    // ★★★ 修正点 3: 修正数据位组合顺序 ★★★
    // UART LSB先行，应按位序存入
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h0;
        end else begin
            // 在采样脉冲有效时，根据时钟沿计数器将数据存入正确位置
            if (rx_start && rx_clk_edge_level) begin
                case (rx_clk_edge_cnt)
                    'd2: rx_data[0] <= rx_pin; // 第1个数据位 (LSB)
                    'd3: rx_data[1] <= rx_pin;
                    'd4: rx_data[2] <= rx_pin;
                    'd5: rx_data[3] <= rx_pin;
                    'd6: rx_data[4] <= rx_pin;
                    'd7: rx_data[5] <= rx_pin;
                    'd8: rx_data[6] <= rx_pin;
                    'd9: rx_data[7] <= rx_pin; // 第8个数据位 (MSB)
                endcase
            end
        end
    end

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
