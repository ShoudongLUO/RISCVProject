`timescale 1ns / 1ps

module reset_generator (
    input  wire clk,        // 时钟输入
    output wire rst_n       // 低有效复位输出
);

    // 复位计数器
    reg [15:0] reset_counter = 16'h10;
    reg        reset_reg = 1'b0;
    
    // 复位生成逻辑
    always @(posedge clk) begin
        if (reset_counter != 16'h0000) begin
            reset_counter <= reset_counter - 16'h1;
            reset_reg <= 1'b0;  // 保持复位状态
        end else begin
            reset_reg <= 1'b1;  // 释放复位
        end
    end
    
    assign rst_n = reset_reg;
    
endmodule