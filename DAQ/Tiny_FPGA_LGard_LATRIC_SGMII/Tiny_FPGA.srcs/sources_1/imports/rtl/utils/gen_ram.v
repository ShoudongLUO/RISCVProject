
/* ===========================================================
 *  Project      : Tiny_FPGA
 *  Unique Tag   : Auto‑generated header (do not remove this line!!!)
 *  Log（开发日志）:
    1. 2025-07-25 Created header by Albert
    2. 2025-09-03 Add a new parameter for the initialization file. by Yuxin
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


module gen_ram #(
    parameter DP = 512,
    parameter DW = 32,
    parameter MW = 4,
    parameter AW = 32,
    // Add a new parameter for the initialization file.
    // Default is "NONE" which means no initialization.
    parameter INIT_HEX_FILE = "NONE" 
    )(

    input wire clk,
    input wire[AW-1:0] addr_i,
    input wire[DW-1:0] data_i,
    input wire[MW-1:0] sel_i,
    input wire we_i,

	output wire[DW-1:0] data_o

    );

    reg[DW-1:0] ram [0:DP-1];
    reg[AW-1:0] addr_r;
    wire[MW-1:0] wen;
    wire ren;

    // ==========================================================
    // == THIS IS THE ONLY ADDITION TO THE MODULE'S LOGIC      ==
    // ==========================================================
    // This `initial` block will be executed by the synthesis tool.
    initial begin
        // The `if` statement checks if a valid file path was provided.
        // The synthesis tool can evaluate this at compile time.
        if (INIT_HEX_FILE != "NONE") begin
            $readmemh(INIT_HEX_FILE, ram);
        end
    end
    // ==========================================================

    assign ren = (~we_i);
    assign wen = ({MW{we_i}} & sel_i);

    always @ (posedge clk) begin
        if (ren) begin
            addr_r <= addr_i;
        end
    end

    assign data_o = ram[addr_r];

    genvar i;

    generate
        for (i = 0; i < MW; i = i + 1) begin: sel_width
            if ((8 * i + 8) > DW) begin: i_gt_8
                always @ (posedge clk) begin: i_gt_8_ff
                    if (wen[i]) begin: gt_8_wen
                        ram[addr_i][DW-1:8*i] <= data_i[DW-1:8*i];
                    end
                end
            end else begin: i_lt_8
                always @ (posedge clk) begin: i_lt_8_ff
                    if (wen[i]) begin: lt_8_wen
                        ram[addr_i][8*i+7:8*i] <= data_i[8*i+7:8*i];
                    end
                end
            end
        end
    endgenerate

endmodule
