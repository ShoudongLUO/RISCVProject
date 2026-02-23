
/* ===========================================================
 *  Project      : Tiny_FPGA
 *  Unique Tag   : Auto‑generated header (do not remove this line!!!)
 *  Log（开发日志）:
    1. 2025-07-25 Created header by Albert
    2. 2025-07-26在注释中整理了主从设备接口的地址空间 by Albert
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

/*
1.3个主设备接口:
Master 0: CPU指令总线（取指）
Master 1: CPU数据总线（访存）  
Master 2: JTAG调试接口

2. 7个从设备接口:
Slave 0: ROM（指令存储器）- 地址空间 0x0xxxxxxx
Slave 1: RAM（数据存储器）- 地址空间 0x1xxxxxxx
Slave 2: Timer（定时器）- 地址空间 0x2xxxxxxx
Slave 3: UART（串口）- 地址空间 0x3xxxxxxx
Slave 4: GPIO（通用IO）- 地址空间 0x4xxxxxxx
Slave 5: I2C（I2C接口）- 地址空间 0x5xxxxxxx
Slave 6: SPI（SPI接口）- 地址空间 0x6xxxxxxx
Slave 7: ADC（ADC接口）- 地址空间 0x7xxxxxxx
3. 当多个主设备同时发起总线请求时，RIB按优先级进行仲裁 Master0 > Master1 > Master2
*/
// RIB总线模块
module rib #(
    parameter MASTER_NUM = 3,
    parameter SLAVE_NUM = 2)(

    input wire clk,
    input wire rst_n,

    // master 0 interface
    input wire[31:0] m0_addr_i,
    input wire[31:0] m0_data_i,
    input wire[3:0] m0_sel_i,
    input wire m0_req_vld_i,
    input wire m0_rsp_rdy_i,
    input wire m0_we_i,
    output wire m0_req_rdy_o,
    output wire m0_rsp_vld_o,
    output wire[31:0] m0_data_o,

    // master 1 interface
    input wire[31:0] m1_addr_i,
    input wire[31:0] m1_data_i,
    input wire[3:0] m1_sel_i,
    input wire m1_req_vld_i,
    input wire m1_rsp_rdy_i,
    input wire m1_we_i,
    output wire m1_req_rdy_o,
    output wire m1_rsp_vld_o,
    output wire[31:0] m1_data_o,

    // master 2 interface
    input wire[31:0] m2_addr_i,
    input wire[31:0] m2_data_i,
    input wire[3:0] m2_sel_i,
    input wire m2_req_vld_i,
    input wire m2_rsp_rdy_i,
    input wire m2_we_i,
    output wire m2_req_rdy_o,
    output wire m2_rsp_vld_o,
    output wire[31:0] m2_data_o,

    // master 3 interface
    input wire[31:0] m3_addr_i,
    input wire[31:0] m3_data_i,
    input wire[3:0] m3_sel_i,
    input wire m3_req_vld_i,
    input wire m3_rsp_rdy_i,
    input wire m3_we_i,
    output wire m3_req_rdy_o,
    output wire m3_rsp_vld_o,
    output wire[31:0] m3_data_o,

    // slave 0 interface
    input wire[31:0] s0_data_i,
    input wire s0_req_rdy_i,
    input wire s0_rsp_vld_i,
    output wire[31:0] s0_addr_o,
    output wire[31:0] s0_data_o,
    output wire[3:0] s0_sel_o,
    output wire s0_req_vld_o,
    output wire s0_rsp_rdy_o,
    output wire s0_we_o,

    // slave 1 interface
    input wire[31:0] s1_data_i,
    input wire s1_req_rdy_i,
    input wire s1_rsp_vld_i,
    output wire[31:0] s1_addr_o,
    output wire[31:0] s1_data_o,
    output wire[3:0] s1_sel_o,
    output wire s1_req_vld_o,
    output wire s1_rsp_rdy_o,
    output wire s1_we_o,

    // slave 2 interface
    input wire[31:0] s2_data_i,
    input wire s2_req_rdy_i,
    input wire s2_rsp_vld_i,
    output wire[31:0] s2_addr_o,
    output wire[31:0] s2_data_o,
    output wire[3:0] s2_sel_o,
    output wire s2_req_vld_o,
    output wire s2_rsp_rdy_o,
    output wire s2_we_o,

    // slave 3 interface
    input wire[31:0] s3_data_i,
    input wire s3_req_rdy_i,
    input wire s3_rsp_vld_i,
    output wire[31:0] s3_addr_o,
    output wire[31:0] s3_data_o,
    output wire[3:0] s3_sel_o,
    output wire s3_req_vld_o,
    output wire s3_rsp_rdy_o,
    output wire s3_we_o,

    // slave 4 interface
    input wire[31:0] s4_data_i,
    input wire s4_req_rdy_i,
    input wire s4_rsp_vld_i,
    output wire[31:0] s4_addr_o,
    output wire[31:0] s4_data_o,
    output wire[3:0] s4_sel_o,
    output wire s4_req_vld_o,
    output wire s4_rsp_rdy_o,
    output wire s4_we_o,

    // ADDED: slave 5 interface for I2C
    input wire[31:0] s5_data_i,
    input wire s5_req_rdy_i,
    input wire s5_rsp_vld_i,
    output wire[31:0] s5_addr_o,
    output wire[31:0] s5_data_o,
    output wire[3:0] s5_sel_o,
    output wire s5_req_vld_o,
    output wire s5_rsp_rdy_o,
    output wire s5_we_o,

    // 为SPI添加slave 6接口
    // slave 6 interface
    input wire[31:0] s6_data_i,
    input wire s6_req_rdy_i,
    input wire s6_rsp_vld_i,
    output wire[31:0] s6_addr_o,
    output wire[31:0] s6_data_o,
    output wire[3:0] s6_sel_o,
    output wire s6_req_vld_o,
    output wire s6_rsp_rdy_o,
    output wire s6_we_o,


    // 为ADC添加slave 7接口
    // slave 7 interface
    input wire[31:0] s7_data_i,
    input wire s7_req_rdy_i,
    input wire s7_rsp_vld_i,
    output wire[31:0] s7_addr_o,
    output wire[31:0] s7_data_o,
    output wire[3:0] s7_sel_o,
    output wire s7_req_vld_o,
    output wire s7_rsp_rdy_o,
    output wire s7_we_o


    );

    /////////////////////////////// mux master //////////////////////////////

    wire[MASTER_NUM-1:0] master_req;
    wire[31:0] master_addr[MASTER_NUM-1:0];
    wire[31:0] master_data[MASTER_NUM-1:0];
    wire[3:0] master_sel[MASTER_NUM-1:0];
    wire[MASTER_NUM-1:0] master_rsp_rdy;
    wire[MASTER_NUM-1:0] master_we;

    genvar i;
    generate

    if (MASTER_NUM == 2) begin: if_m_num_2
        assign master_req = {m0_req_vld_i, m1_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_2
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    if (MASTER_NUM == 3) begin: if_m_num_3
        assign master_req = {m0_req_vld_i, m1_req_vld_i, m2_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i, m2_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i, m2_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i, m2_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i, m2_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i, m2_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_3
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    if (MASTER_NUM == 4) begin: if_m_num_4
        assign master_req = {m0_req_vld_i, m1_req_vld_i, m2_req_vld_i, m3_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i, m2_rsp_rdy_i, m3_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i, m2_we_i, m3_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i, m2_addr_i, m3_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i, m2_data_i, m3_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i, m2_sel_i, m3_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_4
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    wire[MASTER_NUM-1:0] master_req_vec;
    wire[MASTER_NUM-1:0] master_sel_vec;

    // 优先级仲裁机制，LSB优先级最高，MSB优先级最低
    for (i = 0; i < MASTER_NUM; i = i + 1) begin: m_arb
        if (i == 0) begin: m_is_0
            assign master_req_vec[i] = 1'b1;
        end else begin: m_is_not_0
            assign master_req_vec[i] = ~(|master_req[i-1:0]);
        end
        assign master_sel_vec[i] = master_req_vec[i] & master_req[i];
    end

    reg[31:0] mux_m_addr;
    reg[31:0] mux_m_data;
    reg[3:0] mux_m_sel;
    reg mux_m_req_vld;
    reg mux_m_rsp_rdy;
    reg mux_m_we;

    integer j;

    always @ (*) begin: m_out
        mux_m_addr = 32'h0;
        mux_m_data = 32'h0;
        mux_m_sel = 4'h0;
        mux_m_req_vld = 1'b0;
        mux_m_rsp_rdy = 1'b0;
        mux_m_we = 1'b0;
        for (j = 0; j < MASTER_NUM; j = j + 1) begin: m_sig_out
            mux_m_addr    = mux_m_addr    | ({32{master_sel_vec[j]}} & master_addr[j]);
            mux_m_data    = mux_m_data    | ({32{master_sel_vec[j]}} & master_data[j]);
            mux_m_sel     = mux_m_sel     | ({4 {master_sel_vec[j]}} & master_sel[j]);
            mux_m_req_vld = mux_m_req_vld | ({1 {master_sel_vec[j]}} & master_req[j]);
            mux_m_rsp_rdy = mux_m_rsp_rdy | ({1 {master_sel_vec[j]}} & master_rsp_rdy[j]);
            mux_m_we      = mux_m_we      | ({1 {master_sel_vec[j]}} & master_we[j]);
        end
    end

    /////////////////////////////// mux slave /////////////////////////////////

    wire[SLAVE_NUM-1:0] slave_sel;

    // 访问地址的最高4位决定要访问的是哪一个从设备
    // 因此最多支持16个从设备
    for (i = 0; i < SLAVE_NUM; i = i + 1) begin: s_sel
        assign slave_sel[i] = (mux_m_addr[31:28] == i);
    end

    wire[SLAVE_NUM-1:0] slave_req_rdy;
    wire[SLAVE_NUM-1:0] slave_rsp_vld;
    wire[31:0] slave_data[SLAVE_NUM-1:0];

    if (SLAVE_NUM == 2) begin: if_s_num_2
        assign slave_req_rdy = {s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_2
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 3) begin: if_s_num_3
        assign slave_req_rdy = {s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_3
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 4) begin: if_s_num_4
        assign slave_req_rdy = {s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_4
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 5) begin: if_s_num_5
        assign slave_req_rdy = {s4_req_rdy_i, s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s4_rsp_vld_i, s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s4_data_i, s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_5
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    // ADDED: Logic for SLAVE_NUM = 6
    if (SLAVE_NUM == 6) begin: if_s_num_6
        assign slave_req_rdy = {s5_req_rdy_i, s4_req_rdy_i, s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s5_rsp_vld_i, s4_rsp_vld_i, s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s5_data_i, s4_data_i, s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_6
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    // 为SLAVE_NUM = 7添加逻辑
    if (SLAVE_NUM == 7) begin: if_s_num_7
        assign slave_req_rdy = {s6_req_rdy_i, s5_req_rdy_i, s4_req_rdy_i, s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s6_rsp_vld_i, s5_rsp_vld_i, s4_rsp_vld_i, s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s6_data_i, s5_data_i, s4_data_i, s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_7
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    // 为SLAVE_NUM = 8添加逻辑
    if (SLAVE_NUM == 8) begin: if_s_num_8
        assign slave_req_rdy = {s7_req_rdy_i,s6_req_rdy_i, s5_req_rdy_i, s4_req_rdy_i, s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s7_rsp_vld_i,s6_rsp_vld_i, s5_rsp_vld_i, s4_rsp_vld_i, s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s7_data_i,s6_data_i, s5_data_i, s4_data_i, s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_8
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end
    reg[31:0] mux_s_data;
    reg mux_s_req_rdy;
    reg mux_s_rsp_vld;

    always @ (*) begin: s_out
        mux_s_data = 32'h0;
        mux_s_req_rdy = 1'b0;
        mux_s_rsp_vld = 1'b0;
        for (j = 0; j < SLAVE_NUM; j = j + 1) begin: s_sig_out
            mux_s_data    = mux_s_data    | ({32{slave_sel[j]}} & slave_data[j]);
            mux_s_req_rdy = mux_s_req_rdy | ({1 {slave_sel[j]}} & slave_req_rdy[j]);
            mux_s_rsp_vld = mux_s_rsp_vld | ({1 {slave_sel[j]}} & slave_rsp_vld[j]);
        end
    end

    /////////////////////////////// demux master //////////////////////////////

    wire[MASTER_NUM-1:0] demux_m_req_rdy;
    wire[MASTER_NUM-1:0] demux_m_rsp_vld;
    wire[32*MASTER_NUM-1:0] demux_m_data;

    for (i = 0; i < MASTER_NUM; i = i + 1) begin: demux_m_sig
        assign demux_m_req_rdy[i]            = {1 {master_sel_vec[i]}} & mux_s_req_rdy;
        assign demux_m_rsp_vld[i]            = {1 {master_sel_vec[i]}} & mux_s_rsp_vld;
        assign demux_m_data[(i+1)*32-1:32*i] = {32{master_sel_vec[i]}} & mux_s_data;
    end

    if (MASTER_NUM == 2) begin: demux_m_sig_2
        assign {m0_req_rdy_o, m1_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o} = demux_m_data;
    end

    if (MASTER_NUM == 3) begin: demux_m_sig_3
        assign {m0_req_rdy_o, m1_req_rdy_o, m2_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o, m2_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o, m2_data_o} = demux_m_data;
    end

    if (MASTER_NUM == 4) begin: demux_m_sig_4
        assign {m0_req_rdy_o, m1_req_rdy_o, m2_req_rdy_o, m3_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o, m2_rsp_vld_o, m3_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o, m2_data_o, m3_data_o} = demux_m_data;
    end

    /////////////////////////////// demux slave //////////////////////////////

    wire[32*SLAVE_NUM-1:0] demux_s_addr;
    wire[32*SLAVE_NUM-1:0] demux_s_data;
    wire[4*SLAVE_NUM-1:0] demux_s_sel;
    wire[SLAVE_NUM-1:0] demux_s_req_vld;
    wire[SLAVE_NUM-1:0] demux_s_rsp_rdy;
    wire[SLAVE_NUM-1:0] demux_s_we;

    for (i = 0; i < SLAVE_NUM; i = i + 1) begin: demux_s_sig
        // 去掉外设基地址，只保留offset
        assign demux_s_addr[(i+1)*32-1:32*i] = {32{slave_sel[i]}} & {4'h0, mux_m_addr[27:0]};
        assign demux_s_data[(i+1)*32-1:32*i] = {32{slave_sel[i]}} & mux_m_data;
        assign demux_s_sel[(i+1)*4-1:4*i]    = {4 {slave_sel[i]}} & mux_m_sel;
        assign demux_s_req_vld[i]            = {1 {slave_sel[i]}} & mux_m_req_vld;
        assign demux_s_rsp_rdy[i]            = {1 {slave_sel[i]}} & mux_m_rsp_rdy;
        assign demux_s_we[i]                 = {1 {slave_sel[i]}} & mux_m_we;
    end

    if (SLAVE_NUM == 2) begin: demux_s_sig_2
        assign {s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s1_data_o, s0_data_o} = demux_s_data;
        assign {s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 3) begin: demux_s_sig_3
        assign {s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 4) begin: demux_s_sig_4
        assign {s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 5) begin: demux_s_sig_5
        assign {s4_addr_o, s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s4_data_o, s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s4_sel_o, s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s4_req_vld_o, s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s4_rsp_rdy_o, s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s4_we_o, s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    // ADDED: Logic for SLAVE_NUM = 6
    if (SLAVE_NUM == 6) begin: demux_s_sig_6
        assign {s5_addr_o, s4_addr_o, s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s5_data_o, s4_data_o, s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s5_sel_o, s4_sel_o, s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s5_req_vld_o, s4_req_vld_o, s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s5_rsp_rdy_o, s4_rsp_rdy_o, s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s5_we_o, s4_we_o, s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    // 为SLAVE_NUM = 7添加逻辑
    if (SLAVE_NUM == 7) begin: demux_s_sig_7
        assign {s6_addr_o, s5_addr_o, s4_addr_o, s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s6_data_o, s5_data_o, s4_data_o, s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s6_sel_o, s5_sel_o, s4_sel_o, s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s6_req_vld_o, s5_req_vld_o, s4_req_vld_o, s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s6_rsp_rdy_o, s5_rsp_rdy_o, s4_rsp_rdy_o, s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s6_we_o, s5_we_o, s4_we_o, s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    // 为SLAVE_NUM = 8添加逻辑
    if (SLAVE_NUM == 8) begin: demux_s_sig_8
        assign {s7_addr_o,s6_addr_o, s5_addr_o, s4_addr_o, s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s7_data_o,s6_data_o, s5_data_o, s4_data_o, s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s7_sel_o,s6_sel_o, s5_sel_o, s4_sel_o, s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s7_req_vld_o,s6_req_vld_o, s5_req_vld_o, s4_req_vld_o, s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s7_rsp_rdy_o,s6_rsp_rdy_o, s5_rsp_rdy_o, s4_rsp_rdy_o, s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s7_we_o,s6_we_o, s5_we_o, s4_we_o, s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end
    endgenerate


endmodule
