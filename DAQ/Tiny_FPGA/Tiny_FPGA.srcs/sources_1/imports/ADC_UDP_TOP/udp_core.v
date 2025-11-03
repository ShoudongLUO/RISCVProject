module udp_core  #(
        parameter ADC_WIDTH = 8,
parameter DATAWIDTH = 16,
parameter ADC_CHANEL = 1
    )(
    // System Interface
    input         clk_udp,          // UDP clock (125MHz typical)
    input         rst_n,            // Active-low reset (synchronized)
    
    // Configuration Interface
    input  [31:0] board_ip,         
    input  [31:0] des_ip,           
    input  [15:0] tx_data_num,      
    input         udp_tx_enable,    
    input  [15:0] board_port,
    input  [15:0] des_port,
    
    // FIFO Interface
    input  [ADC_CHANEL*DATAWIDTH-1:0] tx_udp_data,           
    (* MARK_DEBUG="true" *)output        tx_req,           
    input         DataAccept,       // Pulse signal (1-cycle)
    
    // RGMII Interface
    output        eth_txc,          // RGMII transmit clock
    output        eth_tx_ctl,       // RGMII transmit control
    output [3:0]  eth_txd,          // RGMII transmit data
    
    // Status Interface
    output        udp_tx_done,      // UDP transmission complete
    output        udp_busy          // UDP core busy signal
);

    // Internal Signals
     (* MARK_DEBUG="true" *)wire          gmii_tx_en;
     (* MARK_DEBUG="true" *)wire  [7:0]   gmii_txd;
    (* MARK_DEBUG="true" *)reg           internal_tx_start_en_pulse;
    wire          data_req;
  //  reg           fifo_rd_en;
  //  reg           fifo_wr_en;
  //  reg           fifo_reset;
  //  wire          fifo_empty;
    reg   [ADC_CHANEL*DATAWIDTH-1:0]  udp_tx_data_mux;
    
    // FIFO Data Storage
   // reg  [15:0]   fifo_data_reg;
   // reg           fifo_data_valid;
    reg           need_retry;
    
    // UDP State Machine
    reg           udp_busy_state;
    localparam S_IDLE    = 1'b0;
    localparam S_SENDING = 1'b1;
    
    // MAC Address Parameters
    localparam BOARD_MAC = 48'h12_34_56_78_9a_bc;
    localparam DES_MAC   = 48'hff_ff_ff_ff_ff_ff;

    // Reset Synchronizer 
    reg rst_s1_udp, rst_s2_udp;
    wire udp_rst_n_sync;
    reg [5:0]retry_number ;
    always @(posedge clk_udp or negedge rst_n) begin
        if (!rst_n) begin
            rst_s1_udp <= 1'b0;
            rst_s2_udp <= 1'b0;
        end else begin
            rst_s1_udp <= 1'b1;
            rst_s2_udp <= rst_s1_udp;
        end
    end
    assign udp_rst_n_sync = rst_s2_udp;

    // UDP Busy Status
    assign udp_busy = (udp_busy_state == S_SENDING);

    //---------------------------------------------------------------------
    // 等待 DataAccept 脉冲，直到当前传输完成
    //---------------------------------------------------------------------
   /* reg data_accepted;        // 标记是否进入正常模式（接收新数据）
    reg pending_data_accept;  // 锁存 DataAccept 脉冲，等待传输完成

    always @(posedge clk_udp or negedge udp_rst_n_sync) begin
        if (!udp_rst_n_sync) begin
            data_accepted <= 1'b0;
            pending_data_accept <= 1'b0;
            //fifo_reset <= 1'b1;
            retry_number <=0;
        end else begin
            // 锁存 DataAccept 脉冲
            if (DataAccept) begin
                pending_data_accept <= 1'b1;
                retry_number<=0;
            end

            if (udp_busy_state==S_IDLE && udp_tx_enable) begin//每次传输开始时，检查是否检测到上一个数据包是否被接受
                if (pending_data_accept || retry_number <4'd5) begin
                    data_accepted <= 1'b1;       // 进入正常模式
                    pending_data_accept <= 1'b0;
                    //fifo_reset <= 1'b1;          // 复位 FIFO（仅 1 周期）
                end else begin
                    data_accepted <= 1'b0;       // 进入重传模式
                    //fifo_reset <= 1'b0;
                    retry_number <=retry_number +2'd1;
                end
            end
        end
    end*/
       //---------------------------------------------------------------------
    // External Data Request
    //---------------------------------------------------------------------
   // assign tx_req = data_accepted ? data_req : 1'b0;
   assign tx_req = data_req;
    //---------------------------------------------------------------------
    // Data MUX
    //---------------------------------------------------------------------
    always @(*) begin
      //  if (data_accepted) begin
            udp_tx_data_mux = tx_udp_data;   // 使用外部数据
        //end else begin
          //  udp_tx_data_mux = fifo_dout;     // 使用 FIFO 数据（重传模式）
        //end
    end

 

    //---------------------------------------------------------------------
    // UDP Transmission State Machine
    //---------------------------------------------------------------------
    always @(posedge clk_udp or negedge udp_rst_n_sync) begin
        if (!udp_rst_n_sync) begin
            udp_busy_state <= S_IDLE;
            internal_tx_start_en_pulse <= 1'b0;
        end else begin
            internal_tx_start_en_pulse <= 1'b0; // Default
            
            case(udp_busy_state)
                S_IDLE: begin
                    if (udp_tx_enable) begin
                        internal_tx_start_en_pulse <= 1'b1;
                        udp_busy_state <= S_SENDING;
                    end
                end
                
                S_SENDING: begin
                    if (udp_tx_done) begin
                        udp_busy_state <= S_IDLE;
                    end
                end
                
                default: udp_busy_state <= S_IDLE;
            endcase
        end
    end

    //---------------------------------------------------------------------
    // Module Instantiations
    //---------------------------------------------------------------------
    rgmii_tx u_rgmii_tx(
        .gmii_tx_clk   (clk_udp),
        .gmii_tx_en    (gmii_tx_en),
        .gmii_txd      (gmii_txd),
        .rgmii_txc     (eth_txc),
        .rgmii_tx_ctl  (eth_tx_ctl),
        .rgmii_txd     (eth_txd)
    );

    udp #(
        .ADC_CHANEL(ADC_CHANEL)
    )u_udp 
    (
        .BOARD_MAC     (BOARD_MAC),
        .BOARD_IP      (board_ip),
        .BOARD_PORT    (board_port),
        .DES_MAC       (DES_MAC),
        .DES_IP        (des_ip),
        .DES_PORT      (des_port),
        .rst_n         (udp_rst_n_sync),
        .gmii_tx_clk   (clk_udp),
        .gmii_tx_en    (gmii_tx_en),
        .gmii_txd      (gmii_txd),
        .tx_start_en   (internal_tx_start_en_pulse),
        .tx_data       (udp_tx_data_mux),
        .tx_byte_num   (tx_data_num),
        .tx_done       (udp_tx_done),
        .tx_req        (data_req)
    );
/*
    fifo_generator_2 fifo_udp_data (
        .clk(clk_udp),
        .srst (fifo_reset),
        .din (udp_tx_data_mux),
        .wr_en (fifo_wr_en),
        .rd_en(fifo_rd_en),
        .dout (fifo_dout),
        .full (),
        .empty (fifo_empty)
    );*/

endmodule
