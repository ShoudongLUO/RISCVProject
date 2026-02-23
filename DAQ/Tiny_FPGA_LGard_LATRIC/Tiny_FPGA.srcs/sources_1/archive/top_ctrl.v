`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/30 13:59:13
// Design Name: 
// Module Name: top_ctrl
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

module top_ctrl(
    // System Interface
    input         clk,
    input         rst_n,
    
    // RIB Configuration Inputs (from rib_wr.v)
    input         cfg_fifo_wr_en,     // 来自总线的FIFO写使能
    input         cfg_udp_tx_enable,  // 来自总线的UDP发送使能
    input  [4:0]  cfg_fee_mode,       // 来自总线的工作模式
    
    // Status Inputs
    input         udp_busy_in,        // UDP模块忙状态
    input         end_udp_tran,       // UDP传输结束标志
    input         fifo_prog_empty,    // FIFO可读状态
    input      [4:0]   sys_status,
    input          udp_tx_done,

    // Control Outputs (带总线配置优先级)
    output reg    sys_message_sending,
    output reg    fifo_wr_en,         // 实际FIFO写使能（可被总线或状态机控制）
    output reg    udp_tx_enable,      // 实际UDP发送使能（可被总线或状态机控制）
    output reg [4:0] fee_mode,        // 实际工作模式
    // Status Outputs
    output reg    udp_busy            // UDP忙状态输出
);
    // FSM State Definitions

    localparam  S_IDLE        =4'd0;             // 3'd0
    localparam  S_ADC_CAPTURE =4'd1;      // 3'd1
    localparam  S_UDP_TRANSMIT=4'd2;     // 3'd2
    localparam  S_CALCULATION =4'd3;      // 3'd3
    localparam  S_SENDING_MESSAGE =4'd4;

    
    reg [3:0] current_state, next_state;
    reg sys_run;
// Mode Definitions
    localparam MODE_IDLE        = 5'd0;
    localparam MODE_CALIBRATION = 5'd1;
    localparam MODE_ACQUISITION = 5'd2;

// Status Definitions
    localparam STAT_WAIT = 5'd0;
    localparam STAT_INIT_FINISH = 5'd1;
    localparam STAT_MEASURE_START = 5'd2;
    localparam STAT_MEASURE_FINISH = 5'd3;
    localparam STAT_CLUSTER_FINGDING=5'd4;
    localparam STAT_CLUSTER_FINGDED = 5'd5;
    localparam STAT_DATA_ACQUIISITION = 5'd6;



//System status, 1:Initialization finished; 2: Start Measure Mode; 3:Finish Measure Mode;
//               4:Start Cluster Finding  ; 5: Finish Cluster Finding 
    wire mode_changed;
    reg [4:0]cfg_fee_mode_sync;
    // 控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cfg_fee_mode_sync <= 5'd0;
        else  cfg_fee_mode_sync <= cfg_fee_mode;  
    end

    assign mode_changed = (cfg_fee_mode_sync==cfg_fee_mode)?1'b0:1'b1;
    always @(posedge clk or negedge rst_n  ) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            next_state <=  S_IDLE;
            fee_mode <= MODE_IDLE;
            fifo_wr_en <= 1'b0;
            udp_tx_enable <= 1'b0;
            sys_run <=1'b0;
            udp_busy <=0;
            sys_message_sending<=0;
        end else begin
           if(mode_changed)next_state<=S_SENDING_MESSAGE;
            current_state <= next_state;
            
            // Registered status outputs
            udp_busy <= udp_busy_in;

            // Mode control with priority
            if (cfg_fee_mode == MODE_CALIBRATION) begin
                fee_mode <= MODE_CALIBRATION;
            end else if (cfg_fee_mode == MODE_ACQUISITION) begin
                fee_mode <= MODE_ACQUISITION;
            end else begin
                fee_mode <= cfg_fee_mode;
            end

        if(sys_status==STAT_INIT_FINISH) sys_run <= 1'b1;
        // State machine
            case (next_state)
                S_IDLE: begin
                    udp_tx_enable <= 1'b0;
                    sys_message_sending <=1'b0;
                    if (cfg_fifo_wr_en  && sys_run && fee_mode!=MODE_IDLE) begin
                        fifo_wr_en <= 1'b1;
                        next_state <= S_ADC_CAPTURE;
                    end
                end
                S_ADC_CAPTURE: begin
                    if(cfg_udp_tx_enable&&!end_udp_tran)begin
                        if (fee_mode == MODE_CALIBRATION) begin
                            if(sys_status==STAT_MEASURE_FINISH) begin
                                udp_tx_enable <= 1'b1;
                                next_state <= S_UDP_TRANSMIT;
                            end
                            else begin 
                                udp_tx_enable <= 1'b0;
                            end
                        end 
                        else if (!fifo_prog_empty && fee_mode == MODE_ACQUISITION ) begin
                            udp_tx_enable <= 1'b1;
                            next_state <= S_UDP_TRANSMIT;
                        end
                    end
                end
                 S_UDP_TRANSMIT: begin
                    if (end_udp_tran || !udp_busy_in) begin
                        if(fee_mode == MODE_CALIBRATION && sys_status==STAT_MEASURE_FINISH )fee_mode <=MODE_IDLE;
                        next_state <= S_IDLE;
                    end
                end
                S_SENDING_MESSAGE:begin
                    udp_tx_enable <=1'b1;
                    sys_message_sending <=1'b1;
                    if(end_udp_tran ||udp_tx_done)
                         next_state <= S_IDLE;
                end
                default: next_state <= S_IDLE;

            endcase
    end
end

endmodule 