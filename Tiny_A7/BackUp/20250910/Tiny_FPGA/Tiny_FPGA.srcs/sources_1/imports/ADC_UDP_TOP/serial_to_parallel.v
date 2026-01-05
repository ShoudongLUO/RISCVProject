module serial_to_parallel #(
    parameter ADC_WIDTH = 12,
    parameter ADC_CHANEL = 4
)(
    input clk,              // 串行时钟
    input rst_n,            // 复位
    input serial_data,      // 串行数据输入
    input frame_sync,       // 帧同步信号
    output reg [ADC_CHANEL*ADC_WIDTH-1:0] parallel_data, // 并行数据输出
    output reg data_valid   // 数据有效信号
);

    reg [ADC_WIDTH-1:0] shift_reg;
    // 使用 $clog2 来计算计数器需要的最小位宽，更通用
    localparam CNT_WIDTH = $clog2(ADC_WIDTH);
    localparam CHAN_CNT_WIDTH = $clog2(ADC_CHANEL);
    
    reg [CNT_WIDTH:0] bit_counter;
    reg [CHAN_CNT_WIDTH:0] channel_counter;
    reg frame_sync_prev;
    
    // *** 修改1: 使用寄存器数组来存储每个通道的数据 ***
    // 这样它的深度会根据 ADC_CHANEL 参数自动调整
    reg [ADC_WIDTH-1:0] channel_data [ADC_CHANEL-1:0];

    // *** 修改3 (可选但推荐): 使用 for 循环在 always 块中赋值 ***
    // Verilog-2001 之后支持在 always 块中使用 for 循环
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {ADC_WIDTH{1'b0}};
            bit_counter <= 0;
            channel_counter <= 0;
            parallel_data <= {(ADC_CHANEL*ADC_WIDTH){1'b0}};
            data_valid <= 1'b0;
            frame_sync_prev <= 1'b0;
            // 初始化寄存器数组
            for (i = 0; i < ADC_CHANEL; i = i + 1) begin
                channel_data[i] <= {ADC_WIDTH{1'b0}};
            end
        end else begin
            frame_sync_prev <= frame_sync;
            data_valid <= 1'b0; // 默认情况下拉低 data_valid
            
            // 检测帧同步上升沿
            if (frame_sync && !frame_sync_prev) begin
                // 帧开始，重置所有计数器
                bit_counter <= 0;
                channel_counter <= 0;
                shift_reg <= {ADC_WIDTH{1'b0}};
                $display("Frame start detected, reset counters");
            end 
            // 只有在帧同步之后才开始采集数据
            else if (frame_sync_prev) begin 
                if (channel_counter < ADC_CHANEL) begin
                    if (bit_counter < ADC_WIDTH - 1) begin
                        // 移位数据（MSB first）
                        shift_reg <= {shift_reg[ADC_WIDTH-2:0], serial_data};
                        bit_counter <= bit_counter + 1'b1;
                    end
                    else begin // bit_counter is ADC_WIDTH - 1, last bit for the channel
                        // *** 修改2: 存储数据到数组中 ***
                        // 不再需要 case 语句
                        channel_data[channel_counter] <= {shift_reg[ADC_WIDTH-2:0], serial_data};
                        $display("Channel %0d data captured: %h", channel_counter, {shift_reg[ADC_WIDTH-2:0], serial_data});
                        
                        bit_counter <= 0;
                        channel_counter <= channel_counter + 1'b1;
                        
                        // 如果这是最后一个通道，准备输出
                        if (channel_counter == ADC_CHANEL - 1) begin
                            // *** 修改3: 使用 for 循环将数据拼接到 parallel_data ***
                            // 综合工具会将其展开为并行的硬件连线
                            for (i = 0; i < ADC_CHANEL - 1; i = i + 1) begin
                                parallel_data[i*ADC_WIDTH +: ADC_WIDTH] <= channel_data[i];
                            end
                            // 单独处理最后一个通道的数据，因为它直接来自移位寄存器
                            parallel_data[(ADC_CHANEL-1)*ADC_WIDTH +: ADC_WIDTH] <= {shift_reg[ADC_WIDTH-2:0], serial_data};
                            
                            data_valid <= 1'b1;
                            $display("All channels captured, asserting data_valid");
                        end
                    end
                end
            end
        end
    end

endmodule