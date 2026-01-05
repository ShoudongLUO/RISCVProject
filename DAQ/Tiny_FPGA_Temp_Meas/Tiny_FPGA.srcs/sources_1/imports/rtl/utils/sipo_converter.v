`timescale 1ns / 1ps

module sipo_converter #(
    parameter DATA_WIDTH = 24
) (
    input wire                      clk,
    input wire                      rst_n,
    input wire                      data_valid_in,
    input wire                      serial_data_in,
    output reg [DATA_WIDTH-1:0]     parallel_data_out,
    output reg                      data_ready_out
);
    // 定义状态
    localparam S_IDLE = 1'b0;
    localparam S_RECEIVING = 1'b1;

    // 状态寄存器
    reg state;

    // 内部寄存器和计数器
    reg [DATA_WIDTH-1:0] build_reg;
    reg [$clog2(DATA_WIDTH)-1:0] count; // 使用 $clog2 自动计算计数器位宽，更通用

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位逻辑
            build_reg         <= 0;
            count             <= 0;
            parallel_data_out <= 0;
            data_ready_out    <= 0;
            state             <= S_IDLE; // 初始状态为空闲
        end else begin
            // 默认每个周期将 ready 信号拉低
            data_ready_out <= 1'b0;

            case (state)
                S_IDLE: begin
                    // 在空闲状态，等待 data_valid_in 信号
                    if (data_valid_in) begin
                        // 检测到传输开始信号
                        state <= S_RECEIVING; // 切换到接收状态
                        
                        // 接收第一个 bit
                        build_reg[DATA_WIDTH - 1] <= serial_data_in; // 第一个 bit 是 MSB
                        count <= 1; // 已经收了1个bit，计数器从1开始
                    end else begin
                        // 保持在 IDLE 状态
                        state <= S_IDLE;
                        count <= 0; // 在IDLE状态，计数器始终为0
                    end
                end

                S_RECEIVING: begin
                    // 在接收状态，持续接收数据
                    // **注意：这里不再检查 data_valid_in，从而忽略传输过程中的毛刺**
                    build_reg[DATA_WIDTH - 1 - count] <= serial_data_in;

                    if (count == DATA_WIDTH - 1) begin
                        // 接收完成最后一个 bit
                        
                        // **仍然使用我们之前讨论过的、解决时序问题的方案一**
                        // 这是因为即使在状态机中，最后一个 bit 的时序问题依然存在
                        parallel_data_out <= {build_reg[DATA_WIDTH-1:1], serial_data_in};
                        
                        data_ready_out <= 1'b1;     // 发出完成脉冲
                        state          <= S_IDLE;     // 回到空闲状态
                        count          <= 0;         // 清零计数器，为下次做准备
                    end else begin
                        // 继续接收
                        count <= count + 1;
                    end
                end

                default: begin
                    // 防止出现意外状态，安全地回到 IDLE
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule