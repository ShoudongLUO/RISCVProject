`timescale 1ns / 1ps

module ADC_UDP_top #(
    parameter ADC_WIDTH = 12,
    parameter DATAWIDTH = 16,
    parameter ADC_CHANEL = 20
)(
    // System clocks and reset
    input clk,           // System clock (50MHz)
    input clk_udp,       // UDP clock (125MHz)
    input rst,           // Active low reset
    
    // RIB Bus Interface (from processor)
    input [31:0] s7_addr_o,
    input [31:0] s7_data_o,
    input s7_we_o,
    output [31:0] s7_data_i,
    
    
    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,
    // ADC Input
    input [ADC_CHANEL*ADC_WIDTH-1:0] rec_ADC_data,
    (* MARK_DEBUG="true" *)input wire adc_data_ready,
    // Ethernet PHY Interface (RGMII)
    output eth_txc,      // RGMII发送数据时钟
    output eth_tx_ctl,   // RGMII输出数据有效信号
    output eth_rst_n,    // PHY reset (active low)
    output [3:0] eth_txd // RGMII输出数据
   
);

    // Internal wire definitions
    wire [4:0] sys_status;
    (* MARK_DEBUG="true" *)wire [4:0] fee_mode;

    // UDP Configuration
    wire [15:0] cfg_tx_data_num;
    (* MARK_DEBUG="true" *)wire cfg_udp_tx_enable;
    wire [31:0] cfg_board_ip;
    wire [31:0] cfg_des_ip;
    wire [15:0] cfg_board_port;
    wire [15:0] cfg_des_port;
   (* MARK_DEBUG="true" *) wire cfg_fifo_wr_en;

    // ADC and Data Interface
    wire [ADC_CHANEL*DATAWIDTH-1:0] baseline_rib_data;
    wire [ADC_CHANEL*DATAWIDTH-1:0] adc_noise;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] cal_adc_value;
    wire [ADC_CHANEL*DATAWIDTH-1:0] adc_test;
    wire data_accepted_rib;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*ADC_WIDTH-1:0] adc_data_dly;

    // FIFO Interface
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] fifo_data_out;
    wire fifo_full;
    wire fifo_empty;

    // UDP Control
    wire udp_tx_done;
    wire tx_req;
    (* MARK_DEBUG="true" *)wire [ADC_CHANEL*DATAWIDTH-1:0] udp_tx_data;
    wire udp_busy;

    // top_ctrl module signals
   (* MARK_DEBUG="true" *) wire ctrl_fifo_wr_en;
   (* MARK_DEBUG="true" *) wire ctrl_udp_tx_enable;
    wire sys_message_sending;
    (* MARK_DEBUG="true" *)wire [4:0]cfg_fee_mode;
    // Additional control signals
    wire [3:0] req_channel;

    // Data accept control logic
    reg udp_tx_done_sync;
    reg tx_done_pulse;
    reg data_accept;
    reg monitoring;
    reg first_packet_sent;
    reg cfg_udp_tx_enable_sync;

    // Assign eth_rst_n
    assign eth_rst_n = rst;

    assign adc_data_dly = (adc_data_ready==1'b1)?rec_ADC_data:0;
    // Data accept control logic
    always @(posedge clk_udp or negedge rst) begin
        if (!rst) begin
            first_packet_sent <= 1'b0;
            monitoring <= 1'b0;
            data_accept <= 1'b0;
            udp_tx_done_sync <= 1'b0;
            tx_done_pulse <= 1'b0;
            cfg_udp_tx_enable_sync <= 1'b0;
        end else begin       
            // 检测 udp_tx_done 上升沿
            udp_tx_done_sync <= udp_tx_done;
            tx_done_pulse <= (udp_tx_done && !udp_tx_done_sync);
            
            if (tx_done_pulse) begin
                monitoring <= 1'b1;
            end
            
            // 首次传输或发送状态/标定值
            if ((ctrl_udp_tx_enable && !first_packet_sent)|| sys_status == 4'd3) begin
                data_accept <= 1'b1;
                first_packet_sent <= 1'b1;
                monitoring <= 1'b0;
            end
            else if (monitoring ) begin
                data_accept <= 1'b1;
                monitoring <= 1'b0;
            end else begin
                data_accept <= 1'b0;
            end
        end
    end

/******************************************/
//System Control Logic
/******************************************/

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


    // ADC Core Instance
    adc_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_adc_core (
        .adc_clk(clk),
        .sys_clk(clk),
        .rst_n(rst),
        .data_accepted_rib(data_accepted_rib),
        .adc_data_in(adc_data_dly),
        .fifo_wr_en(ctrl_fifo_wr_en),
        .sys_status(sys_status),
        .ADC_DATA(fifo_data_out),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fee_mode(fee_mode)
    );

    // RIB Write Instance
    // Register Address Map (consistent with original adc.v)
localparam REG_UDP_CONFIG    = 6'h10;  // W/R: [17]=fifo_wr_en, [16]=udp_tx_enable, [15:0]=tx_data_num
localparam REG_BOARD_IP      = 6'h14;  // W/R: 本机IP地址
localparam REG_DES_IP        = 6'h18;  // W/R: 目标IP地址
localparam REG_BOARD_PORT    = 6'h1C;  // W/R: 本机端口
localparam REG_DES_PORT      = 6'h20;  // W/R: 目标端口
localparam REG_ADC_CONFIG    = 6'h24;
localparam REG_SYS_STATUS    = 6'h28; //System status, 1:Initialization finished; 2: Start Measure Mode; 3:Finish Measure Mode;
                                       //               4:Start Cluster Finding  ; 5: Finish Cluster Finding ; 6: Data Acquirision
localparam ADC_TEST          = 16'h2C;  // W/R: 测试寄存器
localparam REG_SYS_MODE      = 16'h30;   // System mode control 
localparam REG_ADC_DATA      = 16'h1000; // W/R: ADC 数据
localparam REG_ADC_BASELINE  = 16'h2000; // W/R: 计算得到的基准电压
localparam REG_ADC_NOISE     = 16'h3000; // W/R: Noise 值


// Mode Definitions
    localparam MODE_IDLE        = 5'd0;
    localparam MODE_CALIBRATION = 5'd1;
    localparam MODE_ACQUISITION = 5'd2;

// Status Definitions
    localparam STAT_WAIT = 4'd0;
    localparam STAT_INIT_FINISH = 4'd1;
    localparam STAT_MEASURE_START = 4'd2;
    localparam STAT_MEASURE_FINISH = 4'd3;
    localparam STAT_CLUSTER_FINGDING=4'd4;
    localparam STAT_CLUSTER_FINGDED = 4'd5;
    localparam STAT_DATA_ACQUIISITION = 4'd6;
    localparam STAT_UDP_REQ_WAIT = 4'd7;
    localparam STAT_UDP_REQ = 4'd8;


    wire [DATAWIDTH-1:0] adc_channel [0:ADC_CHANEL-1];
    wire [DATAWIDTH-1:0] baseline_channel [0:ADC_CHANEL-1];
    wire [DATAWIDTH-1:0] noise_channel [0:ADC_CHANEL-1];
    
    generate
        genvar i;
        for (i = 0; i < ADC_CHANEL; i=i+1) begin: ADC_CHANNEL_ASSIGNMENT
            assign adc_channel[i] = fifo_data_out[i*DATAWIDTH +: DATAWIDTH];
            assign baseline_channel[i] = baseline_rib_data[i*DATAWIDTH +: DATAWIDTH];
            assign noise_channel[i] = adc_noise[i*DATAWIDTH +: DATAWIDTH];
        end
    endgenerate
wire [8:0] Nwrite_adc;
wire [15:0] adc_test_index;
assign Nwrite_adc = s7_addr_o[11:0] >> 3;
assign adc_test_index = s7_addr_o[15:0] - ADC_TEST;

    // Register Write Logic
    always @(posedge rib_clk or negedge rst) begin
        if (!rst) begin
            // Initialize all writable registers
            adc_test          <= 32'h0;
            cfg_tx_data_num   <= 12'd100;
            cfg_udp_tx_enable <= 1'b1;
            cfg_board_ip      <= {8'd192,8'd168,8'd185,8'd111};
            cfg_des_ip        <= {8'd192,8'd168,8'd185,8'd243};
            cfg_fifo_wr_en    <= 1'b0;
            cfg_board_port    <=12'd1234;
            cfg_des_port      <=12'd1234;
            cal_adc_value     <=0;
            baseline_rib_data <=0;
            adc_noise         <=0;
            sys_status        <=5'd0;
            cfg_adc_width     <= 0;
            cfg_datawidth     <= 0;
            cfg_num_channels  <= 0;
            cfg_fee_mode      <=5'd1;
        end
        else begin
            if (s7_we_o) begin
                case (s7_addr_o[15:0])
                    REG_UDP_CONFIG: begin
                        cfg_tx_data_num   <= s7_data_o[15:0];// Low 16 bits for tx_data_num
                        cfg_udp_tx_enable <= s7_data_o[16];// Bit 16 for UDP transmission enable
                        cfg_fifo_wr_en    <= s7_data_o[17]; // Bit 17 for FIFO write enable
                    end
                    REG_BOARD_IP: cfg_board_ip <= s7_data_o;
                    REG_DES_IP:   cfg_des_ip   <= s7_data_o;
                    REG_BOARD_PORT: cfg_board_port <=s7_data_o;
                    REG_DES_PORT:  cfg_des_port <=s7_data_o;
                    REG_ADC_CONFIG: begin
                        cfg_adc_width  <=s7_data_o[3:0] ;//low 4bit for adc_width
                        cfg_datawidth  <=s7_data_o[9:4]; //Mid 4 Bit  for datawidth
                        cfg_num_channels <=s7_data_o[31:10]; //other for numnber of adc channels
                    end
                    REG_SYS_STATUS:  sys_status <=  s7_data_o[4:0];
                    REG_SYS_MODE :    cfg_fee_mode <=s7_data_o[4:0];

                 /*   REG_ADC_DATA : begin
                          cal_adc_value[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= s7_data_o[DATAWIDTH-1:0];  
                          if(Nwrite_adc<ADC_CHANEL)Nwrite_adc <=Nwrite_adc+1'b1;
                          else Nwrite_adc<=0;

                    end*/
                    default: begin
                        // ADC Data Region (0x1000-0x1FFF)
                        if (s7_addr_o[15:12] == REG_ADC_DATA[15:12]) begin
                            cal_adc_value[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= s7_data_o[DATAWIDTH-1:0];

                        end
                        // Baseline Region (0x2000-0x2FFF)
                        else if (s7_addr_o[15:12] == REG_ADC_BASELINE[15:12]) begin
                            baseline_rib_data[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= s7_data_o[DATAWIDTH-1:0];
                        end
                        // Noise Region (0x3000-0x3FFF)
                        else if (s7_addr_o[15:12] == REG_ADC_NOISE[15:12]) begin
                            adc_noise[(Nwrite_adc*DATAWIDTH) +: DATAWIDTH] <= s7_data_o[DATAWIDTH-1:0];
                        end
                        else if (s7_addr_o[15:0] >= ADC_TEST && s7_addr_o[15:0] < ADC_TEST + ADC_CHANEL) begin
                            adc_test[adc_test_index *DATAWIDTH +: DATAWIDTH] <= s7_data_o[DATAWIDTH-1:0];
                        end
                    end
                endcase
            end
        end

    end

    // Register Read Logic
    always @(*) begin
         if (!rst) begin

         end
    //    adc_test<={28'h0,fee_mode};
            data_accepted_rib <=1'b0;
        case (s7_addr_o[15:0])
            ADC_TEST: begin
            if (ADC_CHANEL == 1) begin
                s7_data_i = {16'b0, adc_test[DATAWIDTH-1:0]}; // 单通道直接读
            end
            // 多通道需要配合地址偏移
            else if (s7_addr_o[15:0] >= ADC_TEST && s7_addr_o[15:0] < ADC_TEST + ADC_CHANEL) begin
                s7_data_i = {16'b0, adc_test[(s7_addr_o[3:0]*DATAWIDTH) +: DATAWIDTH]};
            end
            else begin
                s7_data_i = 32'h0; // 默认值
            end
        end
            REG_UDP_CONFIG:s7_data_i = {14'h0, cfg_fifo_wr_en, cfg_udp_tx_enable, cfg_tx_data_num};
            REG_BOARD_IP: s7_data_i = cfg_board_ip;
            REG_DES_IP:   s7_data_i = cfg_des_ip;
            REG_BOARD_PORT: s7_data_i =cfg_board_port ;
            REG_DES_PORT: s7_data_i =cfg_des_port;
            REG_ADC_CONFIG:s7_data_i ={cfg_num_channels,cfg_datawidth,cfg_adc_width};
            REG_SYS_STATUS: if(fee_mode== MODE_CALIBRATION && sys_status != STAT_MEASURE_FINISH)begin
                                s7_data_i =STAT_MEASURE_START;
                            end
                            else if (fee_mode==MODE_IDLE) begin
                                s7_data_i = STAT_WAIT;
                            end
                            else if(fee_mode == MODE_ACQUISITION)begin
                                    s7_data_i =STAT_CLUSTER_FINGDING;
                                    if(sys_status==STAT_UDP_REQ_WAIT)begin
                                    s7_data_i = (udp_tx_req)?STAT_UDP_REQ:32'd0;
                                    end

                            end


            default: begin
                // ADC Data Region (0x1000-0x1FFF)
                if (s7_addr_o[15:12] == REG_ADC_DATA[15:12]) begin
                    s7_data_i = {16'b0, adc_channel[(s7_addr_o[11:0]>>3)]};
                    data_accepted_rib <=1'b1;
                end
                // Baseline Region (0x2000-0x2FFF)
               else if (s7_addr_o[15:12] == REG_ADC_BASELINE[15:12]) begin
                    s7_data_i = {16'b0, baseline_channel[(s7_addr_o[11:0]>>3)]};
                end
                // Noise Region (0x3000-0x3FFF)
               else if (s7_addr_o[15:12] == REG_ADC_NOISE[15:12]) begin
                    s7_data_i = {16'b0, noise_channel[(s7_addr_o[11:0]>>3)]};
                end
                else begin
                    s7_data_i = 32'hDEADBEEF; // Debug value
                end
            end
        endcase
        
    end


    // UDP Core Instance
    udp_core #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_udp_core (
        .clk_udp(clk_udp),
        .rst_n(rst),
        .board_ip(cfg_board_ip),
        .des_ip(cfg_des_ip),
        .board_port(cfg_board_port),
        .des_port(cfg_des_port),
        .tx_data_num(cfg_tx_data_num),
        .udp_tx_enable(ctrl_udp_tx_enable),
        .tx_udp_data(udp_tx_data),
        .tx_req(tx_req),
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_txd(eth_txd),
        .udp_tx_done(udp_tx_done),
        .DataAccept(data_accept),
        .udp_busy(udp_busy)
    );

    // Baseline Voltage Calibration Instance
    DataPack #(
        .ADC_WIDTH(ADC_WIDTH),
        .ADC_CHANEL(ADC_CHANEL)
    ) u_data_pack(
        .fee_mode(fee_mode),
        .sys_status(sys_status),
        .tx_req(tx_req),
        .udp_clk(clk_udp),
        .sys_clk(clk),
        .sys_rst_n(rst),
        .sys_message_sending(sys_message_sending),
        .tx_data_fifo(cal_adc_value),
        .adc_baseline(baseline_rib_data),
        .adc_noise(adc_noise),
        .udp_tx_data(udp_tx_data)
    );
   vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst),
        .vld_i(req_valid_i),
        .rdy_o(req_ready_o),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

endmodule