`timescale 1 ns / 1 ps

`define SIMULATION

module soc_with_adc_tb;

    // --- Parameters from your top file ---
    localparam ADC_CHANNEL = 2;
    localparam ADC_WIDTH   = 12;
    localparam DATAWIDTH   = 16;

    // --- Clock and Reset Signals ---
    reg clk;           // 50MHz for CPU
    reg clk_125m;      // 125MHz for ADC/UDP
    reg rst_ext_i;     // External reset signal for rst_ctrl, active high as input to rst_ctrl

    // --- ADC Input Simulation ---
    reg [ADC_WIDTH*ADC_CHANNEL-1:0] adc_data_sim;
    
    // --- Internal Reset Signal for ADC data stimulus ---
    // The SoC's rst_n is not directly available here, so we generate a synchronized reset for stimulus
    wire soc_rst_n; 
    
    // --- DUT Connections ---
    wire uart_tx_pin;
    wire [1:0] gpio;

    // --- Clock Generation ---
    initial begin
        clk = 1'b0;
        clk_125m = 1'b0;
    end
    always #10 clk = ~clk;       // 50MHz period = 20ns
    always #4  clk_125m = ~clk_125m; // 125MHz period = 8ns

    // --- Reset Generation ---
    initial begin
        rst_ext_i = 1'b0; // Assert external reset (active high)
        adc_data_sim = 0;
        
        $display("[%t ns] Test running, external reset asserted.", $time);
        
        #200; // Hold reset for 200ns
        rst_ext_i = 1'b1; // De-assert external reset
        $display("[%t ns] External reset de-asserted. SoC should start executing.", $time);
    end

    // --- ADC Data Stimulus ---
    // Stimulus should be gated by the internal low-active reset `soc_rst_n`
    assign soc_rst_n = tinyriscv_soc_top_0.rst_n; // Get internal reset from DUT
    always @(posedge clk_125m) begin
        if (soc_rst_n) begin // Only generate data when not in reset (rst_n is high)
            // Simple counter for each channel
            adc_data_sim[ADC_WIDTH-1:0] <= adc_data_sim[ADC_WIDTH-1:0] + 1; // Channel 0
            adc_data_sim[2*ADC_WIDTH-1:ADC_WIDTH] <= adc_data_sim[2*ADC_WIDTH-1:ADC_WIDTH] + 2; // Channel 1
        end else begin
            adc_data_sim <= 0;
        end
    end
    

    // --- Load Program into ROM ---
    initial begin
        // **FIXED**: Using the exact path you provided.
        // Make sure your simulator has access to this path.
        $readmemh("E:/FPGA/Testbench_bram/tools/my_adc.data", tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);
        $display("[%t ns] Loaded E:/FPGA/Testbench_bram/tools/my_adc.data into instruction memory.", $time);
    end

    // --- DUT (Device Under Test) Instantiation ---
    tinyriscv_soc_top #(
        .ADC_CHANNEL(ADC_CHANNEL),
        .ADC_WIDTH(ADC_WIDTH),
        .DATAWIDTH(DATAWIDTH)
    ) tinyriscv_soc_top_0 (
        // Clocks and Reset
        .clk        (clk),
        .clk_125m   (clk_125m),
        .rst_ext_i  (rst_ext_i),

        // ADC UDP Interface
        .adc_data   (adc_data_sim),
        .eth_txc    (), // Outputs, leave open
        .eth_tx_ctl (),
        .eth_rst_n  (),
        .eth_txd    ()
    );

endmodule