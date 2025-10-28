// Language: Verilog 2001
`timescale 1ns / 1ps

/*
 * SPI Wrapper Module (Corrected Architecture)
 * Fixes the bug where a CS-only write incorrectly modified the TX data register.
 * Data is now latched ONLY when a transfer is explicitly started.
 */
module spi_wrapper #(
    parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 4
)(
    // ... (接口与之前完全相同)
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
    output wire spi_sck,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire[1:0] spi_csn
);

    // ... (localparam 和内部信号定义与之前相同)
    localparam SPI_CTRL_DATA  = 5'h00;
    localparam SPI_STATUS_DATA = 5'h04;
    reg  [7:0] tx_byte_reg;
    reg        tx_dv_pulse;
    wire       tx_ready_from_core;
    wire       rx_dv_from_core;
    wire [7:0] rx_byte_from_core;
    reg [1:0]  csn_reg;
    reg        rx_valid_flag;
    wire wen = we_i & req_valid_i;
    wire ren = (~we_i) & req_valid_i;
    
    // ... (SPI_Master 实例化与之前相同)
    SPI_Master #(
        .SPI_MODE(SPI_MODE), 
        .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
    ) u_SPI_Master ( 
        .i_Rst_L(rst_n), 
        .i_Clk(clk), 
        .i_TX_Byte(tx_byte_reg), 
        .i_TX_DV(tx_dv_pulse), 
        .o_TX_Ready(tx_ready_from_core), 
        .o_RX_DV(rx_dv_from_core), 
        .o_RX_Byte(rx_byte_from_core), 
        .o_SPI_Clk(spi_sck), 
        .i_SPI_MISO(spi_miso), 
        .o_SPI_MOSI(spi_mosi) 
    );
    
    assign spi_csn = csn_reg;

    // --- Register Write Logic & Control Pulse Generation (THE FIX is here) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_byte_reg <= 8'h00;
            csn_reg     <= 2'b11;
            tx_dv_pulse <= 1'b0;
        end else begin
            tx_dv_pulse <= 1'b0; // Pulse is always single-cycle
            
            if (wen && addr_i[4:0] == SPI_CTRL_DATA) begin
                // This logic is now unambiguous.
                // It always updates the CS based on the low byte's content.
                csn_reg <= data_i[1:0];
                
                // It ONLY latches data and starts a transfer if the start bit is set.
                if (data_i[2]) begin
                    tx_byte_reg <= data_i[15:8]; // Latch data ONLY when starting
                    tx_dv_pulse <= 1'b1;
                end
            end
        end
    end

    // --- RX Data Latching and Status Flag Logic (Using the previously corrected logic) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_valid_flag <= 1'b0;
        end else begin
            if (rx_dv_from_core) begin
                rx_valid_flag <= 1'b1;
            end else if (tx_dv_pulse) begin // Cleared when next transfer starts
                rx_valid_flag <= 1'b0;
            end
        end
    end

    // ... (Bus Read Logic and vld_rdy instantiation are unchanged)
    reg [7:0] rx_byte_latched;
    always @(posedge clk) begin
        if (rx_dv_from_core) begin
            rx_byte_latched <= rx_byte_from_core;
        end
    end
    assign data_o = (ren && addr_i[4:0] == SPI_STATUS_DATA) ? 
                    {15'b0, rx_byte_latched, 6'b0, rx_valid_flag, tx_ready_from_core} : 
                    32'h0;
    vld_rdy #(.CUT_READY(0)) u_vld_rdy ( 
        .clk(clk), 
        .rst_n(rst_n), 
        .vld_i(req_valid_i), 
        .rdy_o(req_ready_o), 
        .rdy_i(rsp_ready_i), 
        .vld_o(rsp_valid_o) );

    (* MARK_DEBUG="true" *) wire       dbg_spi_sck               = spi_sck;
    (* MARK_DEBUG="true" *) wire       dbg_spi_mosi               = spi_mosi;
    (* MARK_DEBUG="true" *) wire       dbg_spi_miso               = spi_miso;
    (* MARK_DEBUG="true" *) wire   [1:0]    dbg_spi_csn                = spi_csn;

endmodule