`timescale 1ns / 1ps

module tb_fpga_sipo_test;

    // 时钟和复位信号
    reg clk;
    reg clk_125m;
    reg rst_ext_i;
    
    // 测试控制信号
    reg start_btn;
    
    // 输出信号
    wire halted_ind;
    wire uart_tx_pin;
    wire [1:0] vcc3v3;
    wire spi_sck;
    wire spi_mosi;
    wire [1:0] spi_csn;
    wire eth_txc;
    wire eth_tx_ctl;
    wire eth_rst_n;
    wire [3:0] eth_txd;
    wire [3:0] leds;
    wire jtag_TDO;
    
    // 输入信号
    reg uart_rx_pin;
    reg [1:0] gpio;
    reg jtag_TCK;
    reg jtag_TMS;
    reg jtag_TDI;
    reg i2c_scl;
    reg i2c_sda;
    reg spi_miso;
    
    // 时钟生成
    always #10 clk = ~clk;        // 50MHz
    always #4 clk_125m = ~clk_125m; // 125MHz
    
    // 实例化被测模块
    fpga_sipo_test dut (
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .clk_125m(clk_125m),
        .halted_ind(),           // 输出，不需要驱动
        // UART接口
        .uart_tx_pin(),          // 输出
        .uart_rx_pin(1'b1),      // 保持空闲状态

        

        
        // JTAG接口
        .jtag_TCK(1'b0),        // 测试中不使能JTAG
        .jtag_TMS(1'b0),
        .jtag_TDI(1'b0),
        .jtag_TDO(),
        
        // 电源引脚
        .vcc3v3(),
        

        
        // SPI接口

        .spi_sck(),
        .spi_mosi(),
        .spi_miso(1'bz),
        .spi_csn(),

        
        // ADC接口

        // 以太网接口
        .eth_txc(),
        .eth_tx_ctl(),
        .eth_rst_n(),
        .eth_txd(),
        
        .start_btn(start_btn),
        .leds(leds)
    );
    
    // 测试序列
    initial begin
        // 初始化信号
        clk = 0;
        clk_125m = 0;
        rst_ext_i = 0;
        start_btn = 0;
        uart_rx_pin = 1;
        gpio = 2'bzz;
        jtag_TCK = 0;
        jtag_TMS = 0;
        jtag_TDI = 0;
        i2c_scl = 1'bz;
        i2c_sda = 1'bz;
        spi_miso = 1'bz;
        
        $display("==========================================");
        $display("FPGA SIPO Converter Testbench Starting...");
        $display("Time: %t", $time);
        $display("==========================================");
        
        // 复位序列
        #100;
        rst_ext_i = 1;
        #800000;

        // 测试1：正常数据转换
        $display("\n[%0t] Test 1: Normal data conversion (0xA5A5A5)", $time);
        start_btn = 1;
        #100;
        start_btn = 0;
        
        // 等待转换完成
        #50000;
        
        // 检查LED状态
        if (leds == 4'h7) begin
            $display("[%0t] Test 1 PASSED - LEDs: 0x%h", $time, leds);
        end else begin
            $display("[%0t] Test 1 FAILED - LEDs: 0x%h (expected: 0x7)", $time, leds);
        end
        
        // 测试间隔
        #10000;
        
        // 测试2：再次测试
        $display("\n[%0t] Test 2: Second test", $time);
        start_btn = 1;
        #100;
        start_btn = 0;
        
        // 等待转换完成
        #50000;
        
        // 检查LED状态
        if (leds == 4'h7) begin
            $display("[%0t] Test 2 PASSED - LEDs: 0x%h", $time, leds);
        end else begin
            $display("[%0t] Test 2 FAILED - LEDs: 0x%h (expected: 0x7)", $time, leds);
        end
        
        // 测试3：快速连续测试
        $display("\n[%0t] Test 3: Rapid consecutive tests", $time);
        repeat (3) begin
            start_btn = 1;
            #100;
            start_btn = 0;
            #50000;
            
            $display("[%0t] Test iteration - LEDs: 0x%h", $time, leds);
        end
        

        
        $display("[%0t] Reset applied during transmission", $time);
        
        // 完成测试
        #10000;
        
        $display("\n==========================================");
        $display("All tests completed at time %t", $time);
        $display("Final LED status: 0x%h", leds);
        $display("==========================================");
        

    end
    
    // 监控器：实时显示关键信号
    always @(posedge clk) begin
        if (dut.data_valid_in) begin
            $display("[%0t] MON: data_valid_in=1, serial_data_in=%b", 
                     $time, dut.serial_data_in);
        end
        
        if (dut.data_ready_out) begin
            $display("[%0t] MON: data_ready_out pulse detected", $time);
        end
        
        // 显示状态变化
        if (dut.state != dut.state) begin
            $display("[%0t] MON: State changed to %0d", $time, dut.state);
        end
    end
    
    // 监视LED状态变化
    reg [3:0] prev_leds;
    always @(posedge clk) begin
        if (leds !== prev_leds) begin
            $display("[%0t] MON: LED status changed: 0x%h -> 0x%h", 
                     $time, prev_leds, leds);
            prev_leds = leds;
        end
    end
        initial begin
        // 使用正确的路径指向你的指令文件
        //$readmemh("E:/FPGA/Testbench_bram/tools/my_adc.data", tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);

        // Path for shoudong
        $readmemh("D:/RISCV_Project/fpga/Testbench_bram/sdk/examples/my_adc/inst.data", fpga_sipo_test.tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);
        $display("Instruction memory loaded successfully");
    end
    // 超时保护

    

    



endmodule