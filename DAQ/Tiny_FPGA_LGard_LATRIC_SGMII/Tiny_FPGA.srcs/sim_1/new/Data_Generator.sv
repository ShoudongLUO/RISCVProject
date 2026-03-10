`timescale 1ns / 1ps

module fpga_tdc_test (
    input  wire clk,
    input  wire rst_ext_i,
    input  wire clk_125m,
    
    // Added Fast Clock for TDC simulation
    input  wire clk_fast, 
    input  wire start_btn,

    output wire halted_ind,
    output wire uart_tx_pin,
    input  wire uart_rx_pin,
    inout  wire [1:0] gpio,
    input  wire jtag_TCK, jtag_TMS, jtag_TDI,
    output wire jtag_TDO,
    output wire [1:0] vcc3v3,
    inout  wire i2c_scl, i2c_sda,
    output wire spi_sck, spi_mosi, 
    input  wire spi_miso, 
    output wire [1:0] spi_csn,
// Updated SGMII Interface
    input  wire phy_sgmii_rx_p, phy_sgmii_rx_n,
    output wire phy_sgmii_tx_p, phy_sgmii_tx_n,
    input  wire phy_sgmii_clk_p, phy_sgmii_clk_n,
    output wire phy_reset_n,
    
    // Status/Debug
    output wire [15:0] sgmii_status_vector,
    output reg  [3:0] leds
    
);

    // =========================================================================
    // 1. DATA GENERATION LOGIC
    // =========================================================================
    
    logic [127:0] ch1_data;
    logic         ch1_valid;
    logic [127:0] ch2_data;
    logic         ch2_valid;

    // Simulation Memory
    reg [127:0] mem_ch1 [0:9999];
    reg [127:0] mem_ch2 [0:9999];
    int     ptr_ch1, ptr_ch2;

    initial begin
        // Load the C++ generated vectors
        $readmemh("C:/Users/ShoudongLUO/Desktop/RISCV/TinyRiscV_My/DAQ/Tiny_FPGA_LGard_LATRIC/Tiny_FPGA.srcs/sources_1/imports/ADC_UDP_TOP/ch1_vectors.txt", mem_ch1);
        $readmemh("C:/Users/ShoudongLUO/Desktop/RISCV/TinyRiscV_My/DAQ/Tiny_FPGA_LGard_LATRIC/Tiny_FPGA.srcs/sources_1/imports/ADC_UDP_TOP/ch2_vectors.txt", mem_ch2);
        
        // === 修改这里 ===
        // 删除这里的 ptr_ch1 = 0; 和 ptr_ch2 = 0;
        // 这一步已经由下面的 always_ff 中的复位逻辑完成了。
        // ================
    end

    // State Machine to drive data
    typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
    state_t state;

    // Button Debounce / Edge Det
    logic [2:0] btn_sync;
    always_ff @(posedge clk or negedge rst_ext_i) begin
        if(!rst_ext_i) btn_sync <= 0;
        else btn_sync <= {btn_sync[1:0], start_btn};
    end
    wire start_pulse = (btn_sync[2:1] == 2'b01);

    always_ff @(posedge clk_fast or negedge rst_ext_i) begin
        if (!rst_ext_i) begin
            state      <= IDLE;
            ch1_valid  <= 0;
            ch2_valid  <= 0;
            // === 这里是唯一的驱动源，用于复位 ===
            ptr_ch1    <= 0; 
            ptr_ch2    <= 0;
            // =================================
            leds       <= 4'h1;
        end else begin
            case(state)
                IDLE: begin
                    if (start_pulse) begin
                        state <= RUN;
                        leds <= 4'h2;
                        ptr_ch1 <= 0; // 重新开始时归零
                        ptr_ch2 <= 0;
                    end
                end

                RUN: begin
                    // Feed Channel 1
                    if (mem_ch1[ptr_ch1] !== 128'bx && mem_ch1[ptr_ch1] != 0) begin
                        ch1_data  <= mem_ch1[ptr_ch1];
                        ch1_valid <= 1'b1;
                        ptr_ch1   <= ptr_ch1 + 1;
                    end else begin
                        ch1_valid <= 1'b0;
                    end

                    // Feed Channel 2
                    if (mem_ch2[ptr_ch2] !== 128'bx && mem_ch2[ptr_ch2] != 0) begin
                        ch2_data  <= mem_ch2[ptr_ch2];
                        ch2_valid <= 1'b1;
                        ptr_ch2   <= ptr_ch2 + 1;
                    end else begin
                        ch2_valid <= 1'b0;
                    end

                    // Stop if both done
                    if ((mem_ch1[ptr_ch1] == 0) && (mem_ch2[ptr_ch2] == 0)) begin
                        state <= DONE;
                        leds  <= 4'hF;
                    end
                end

                DONE: begin
                   if (start_pulse) state <= IDLE; // Restart capability
                end
            endcase
        end
    end

    // =========================================================================
    // SGMII SOC INSTANTIATION
    // =========================================================================
    tinyriscv_soc_top_sgmii tinyriscv_soc_top_0 (
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .clk_125m(clk_125m),
        .clk_fast(clk_fast),
        
        // Data from Simulation Memory
        .ch1_data_in(ch1_data),
        .ch1_data_valid(ch1_valid),
        .ch2_data_in(ch2_data),
        .ch2_data_valid(ch2_valid),

        // SGMII PHY Interface
        .phy_sgmii_rx_p(phy_sgmii_rx_p),
        .phy_sgmii_rx_n(phy_sgmii_rx_n),
        .phy_sgmii_tx_p(phy_sgmii_tx_p),
        .phy_sgmii_tx_n(phy_sgmii_tx_n),
        .phy_sgmii_clk_p(phy_sgmii_clk_p),
        .phy_sgmii_clk_n(phy_sgmii_clk_n),
        .phy_reset_n(phy_reset_n),
        .sgmii_status_vector(sgmii_status_vector),
       
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .gpio(gpio),
        .jtag_TCK(jtag_TCK), .jtag_TMS(jtag_TMS), .jtag_TDI(jtag_TDI), .jtag_TDO(jtag_TDO),
        .vcc3v3(vcc3v3),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_csn(spi_csn)
    );

endmodule