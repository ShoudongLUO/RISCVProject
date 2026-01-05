// Language: Verilog 2001
`timescale 1ns / 1ps

/*
 * =============================================================================
 * Module: i2c_controller (The Correct, Working Version)
 * Description:
 *   This is the logically correct version. Its functionality depends on the
 *   CPU accessing it at the correct base address defined in the top-level system.
 * =============================================================================
 */
module i2c_controller (
    // System bus
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    input  wire [3:0]  sel_i,
    input  wire        we_i,
    output wire [31:0] data_o,

    input  wire        req_valid_i,
    output wire        req_ready_o,
    output wire        rsp_valid_o,
    input  wire        rsp_ready_i,

    // I2C physical pins
    inout  wire        io_scl,
    inout  wire        io_sda
);
    // -----------------------------
    // Register map (byte address)
    // -----------------------------
    localparam [5:0] PRESCALE_OFFSET    = 6'h00; // [15:0] I2C prescale
    localparam [5:0] CMD_OFFSET         = 6'h04; // [31]=GO, [30]=WRITE, [29]=READ
    localparam [5:0] SLAVE_ADDR_OFFSET  = 6'h08; // [6:0] 7-bit slave addr
    localparam [5:0] MEM_ADDR_OFFSET    = 6'h0C; // [15:0] word addr in EEPROM
    localparam [5:0] DATA_OFFSET        = 6'h10; // [7:0]  data (write or last read)
    localparam [5:0] WR_DELAY_OFFSET    = 6'h14; // [19:0] tWR in clk cycles
    localparam [5:0] STATUS_OFFSET      = 6'h20; // [0]=BUSY, [1]=ACK_ERR

    // CMD bits
    localparam GO_BIT    = 31;
    localparam WRITE_BIT = 30;
    localparam READ_BIT  = 29;

    // -----------------------------
    // State machine (Replicated from the proven example)
    // -----------------------------
    localparam [4:0]
        S_IDLE         = 5'd0,
        S_WR_START     = 5'd1, S_WR_CMD_MSB   = 5'd2, S_WR_DAT_MSB   = 5'd3,
        S_WR_CMD_LSB   = 5'd4, S_WR_DAT_LSB   = 5'd5, S_WR_CMD_DATA  = 5'd6,
        S_WR_DAT_DATA  = 5'd7, S_WR_STOP      = 5'd8, S_WR_DELAY     = 5'd9,
        S_RD_START     = 5'd11, S_RD_CMD_MSB   = 5'd12, S_RD_DAT_MSB   = 5'd13,
        S_RD_CMD_LSB   = 5'd14, S_RD_DAT_LSB   = 5'd15, S_RD_EXEC      = 5'd16,
        S_RD_WAIT      = 5'd17;

    reg [4:0] state, state_nxt;

    // -----------------------------
    // Config/Status registers
    // -----------------------------
    reg [15:0] reg_prescale;
    reg [6:0]  reg_slave_addr;
    reg [15:0] reg_mem_addr;
    reg [7:0]  reg_data;
    reg [19:0] reg_wr_delay;
    reg        stat_ack_error;
    reg [19:0] wr_cnt;
    reg [6:0]  fsm_slave_addr_latched;

    // -----------------------------
    // i2c_master interface signals
    // -----------------------------
    wire        i_rst = ~rst_n;
    reg         cmd_valid, cmd_start, cmd_read, cmd_write, cmd_stop;
    reg         data_valid;
    reg  [7:0]  data_w;
    wire        i2c_cmd_ready, i2c_data_ready;
    wire [7:0]  i2c_m_axis_data;
    wire        i2c_m_axis_valid, i2c_missed_ack;
    wire scl_i, scl_o, scl_t, sda_i, sda_o, sda_t;

    i2c_master i2c_master_inst ( 
        .clk(clk), 
        .rst(i_rst), 
        .s_axis_cmd_address(fsm_slave_addr_latched), 
        .s_axis_cmd_start(cmd_start), 
        .s_axis_cmd_read(cmd_read), 
        .s_axis_cmd_write(cmd_write), 
        .s_axis_cmd_write_multiple(1'b0), 
        .s_axis_cmd_stop(cmd_stop), 
        .s_axis_cmd_valid(cmd_valid), 
        .s_axis_cmd_ready(i2c_cmd_ready), 
        .s_axis_data_tdata (data_w), 
        .s_axis_data_tvalid(data_valid), 
        .s_axis_data_tready(i2c_data_ready), 
        .s_axis_data_tlast (1'b1), 
        .m_axis_data_tdata (i2c_m_axis_data), 
        .m_axis_data_tvalid(i2c_m_axis_valid), 
        .m_axis_data_tready(1'b1), 
        .m_axis_data_tlast (), 
        .scl_i(scl_i), 
        .scl_o(scl_o), 
        .scl_t(scl_t), 
        .sda_i(sda_i), 
        .sda_o(sda_o), 
        .sda_t(sda_t), 
        .busy(), 
        .bus_control(), 
        .bus_active(), 
        .missed_ack(i2c_missed_ack), 
        .prescale(reg_prescale), 
        .stop_on_idle(1'b0) 
    );

    assign scl_i = io_scl, io_scl = scl_t ? 1'bz : 1'b0;
    assign sda_i = io_sda, io_sda = sda_t ? 1'bz : 1'b0;

    // -----------------------------
    // Bus Write & Trigger Logic
    // -----------------------------
    wire wen = we_i & req_valid_i;
    wire ren = (~we_i) & req_valid_i;
    wire is_cmd_fire = wen && (addr_i[5:0] == CMD_OFFSET) && data_i[GO_BIT];

    // -----------------------------
    // FSM Sequential Logic
    // -----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= state_nxt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wr_cnt <= 20'd0;
        else if (state == S_WR_DELAY) wr_cnt <= wr_cnt + 1'b1;
        else wr_cnt <= 20'd0;
    end

    // -----------------------------
    // Configuration & Status Register Logic
    // -----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_prescale     <= 16'd125;
            reg_slave_addr   <= 7'h53;
            reg_mem_addr     <= 16'h0000;
            reg_data         <= 8'h00;
            reg_wr_delay     <= 20'd250000;
            stat_ack_error   <= 1'b0;
            fsm_slave_addr_latched <= 7'h00;
        end else begin
            if (is_cmd_fire) begin
                fsm_slave_addr_latched <= reg_slave_addr;
                stat_ack_error         <= 1'b0;
            end
            if (i2c_m_axis_valid) reg_data <= i2c_m_axis_data;
            if (i2c_missed_ack) stat_ack_error <= 1'b1;
            if (wen) begin
                case (addr_i[5:0])
                    PRESCALE_OFFSET:    reg_prescale   <= data_i[15:0];
                    SLAVE_ADDR_OFFSET:  reg_slave_addr <= data_i[6:0];
                    MEM_ADDR_OFFSET:    reg_mem_addr   <= data_i[15:0];
                    DATA_OFFSET:        reg_data       <= data_i[7:0];
                    WR_DELAY_OFFSET:    reg_wr_delay   <= data_i[19:0];
                endcase
            end
        end
    end

    // -----------------------------
    // FSM Combinational Logic
    // -----------------------------
    always @* begin
        state_nxt = state;
        cmd_valid=0; cmd_start=0; cmd_read=0; cmd_write=0; cmd_stop=0;
        data_valid=0; data_w=0;

        case (state)
            S_IDLE: if (is_cmd_fire) begin
                        if (data_i[WRITE_BIT]) state_nxt = S_WR_START;
                        else if (data_i[READ_BIT]) state_nxt = S_RD_START;
                    end
            S_WR_START:   begin cmd_valid=1; cmd_start=1; if (i2c_cmd_ready) state_nxt = S_WR_CMD_MSB; end
            S_WR_CMD_MSB: begin cmd_valid=1; cmd_write=1; if (i2c_cmd_ready) state_nxt = S_WR_DAT_MSB; end
            S_WR_DAT_MSB: begin data_valid=1; data_w = reg_mem_addr[15:8]; if (i2c_data_ready) state_nxt = S_WR_CMD_LSB; end
            S_WR_CMD_LSB: begin cmd_valid=1; cmd_write=1; if (i2c_cmd_ready) state_nxt = S_WR_DAT_LSB; end
            S_WR_DAT_LSB: begin data_valid=1; data_w = reg_mem_addr[7:0];  if (i2c_data_ready) state_nxt = S_WR_CMD_DATA; end
            S_WR_CMD_DATA:begin cmd_valid=1; cmd_write=1; if (i2c_cmd_ready) state_nxt = S_WR_DAT_DATA; end
            S_WR_DAT_DATA:begin data_valid=1; data_w = reg_data;           if (i2c_data_ready) state_nxt = S_WR_STOP; end
            S_WR_STOP:    begin cmd_valid=1; cmd_stop=1;  if (i2c_cmd_ready) state_nxt = S_WR_DELAY; end
            S_WR_DELAY:   if (wr_cnt >= reg_wr_delay - 1) state_nxt = S_IDLE;
            S_RD_START:   begin cmd_valid=1; cmd_start=1; if (i2c_cmd_ready) state_nxt = S_RD_CMD_MSB; end
            S_RD_CMD_MSB: begin cmd_valid=1; cmd_write=1; if (i2c_cmd_ready) state_nxt = S_RD_DAT_MSB; end
            S_RD_DAT_MSB: begin data_valid=1; data_w = reg_mem_addr[15:8]; if (i2c_data_ready) state_nxt = S_RD_CMD_LSB; end
            S_RD_CMD_LSB: begin cmd_valid=1; cmd_write=1; if (i2c_cmd_ready) state_nxt = S_RD_DAT_LSB; end
            S_RD_DAT_LSB: begin data_valid=1; data_w = reg_mem_addr[7:0];  if (i2c_data_ready) state_nxt = S_RD_EXEC; end
            S_RD_EXEC:    begin cmd_valid=1; cmd_start=1; cmd_read=1; cmd_stop=1; if (i2c_cmd_ready) state_nxt = S_RD_WAIT; end
            S_RD_WAIT:    if (i2c_m_axis_valid) state_nxt = S_IDLE;
        endcase
        if (i2c_missed_ack) state_nxt = S_IDLE;
    end

    // -----------------------------
    // Bus Read Mux
    // -----------------------------
    wire stat_busy = (state != S_IDLE);
    reg [31:0] rdata_mux;
    always @* begin
        case (addr_i[5:0])
            PRESCALE_OFFSET:    rdata_mux = {16'b0, reg_prescale};
            SLAVE_ADDR_OFFSET:  rdata_mux = {25'b0, reg_slave_addr};
            MEM_ADDR_OFFSET:    rdata_mux = {16'b0, reg_mem_addr};
            DATA_OFFSET:        rdata_mux = {24'b0, reg_data};
            WR_DELAY_OFFSET:    rdata_mux = {12'b0, reg_wr_delay};
            STATUS_OFFSET:      rdata_mux = {30'b0, stat_ack_error, stat_busy};
            default:            rdata_mux = 32'h0;
        endcase
    end
    assign data_o = (ren) ? rdata_mux : 32'h0;

    // -----------------------------
    // Bus Handshake Logic
    // -----------------------------
    vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy ( 
        .clk(clk), 
        .rst_n(rst_n), 
        .vld_i(req_valid_i), 
        .rdy_o(req_ready_o), 
        .rdy_i(rsp_ready_i), 
        .vld_o(rsp_valid_o) 
    );
    
endmodule