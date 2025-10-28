`timescale 1 ns / 1 ps

// 测试选项定义
// `define TEST_GPIO
`define TEST_ADC
//`define TEST_UART
//`define TEST_SPI
//`define TEST_I2C

module tinyriscv_soc_tb;

    // 时钟和复位信号
    reg clk;
    reg clk_125m;
    reg rst_ext_i;
    
    // 仿真控制
    reg end_simulation;
    
    // 时钟生成
    always #10 clk = ~clk;        // 50MHz
    always #4 clk_125m = ~clk_125m; // 125MHz
    
    // GPIO测试相关
`ifdef TEST_GPIO
    reg [1:0] test_gpio_input;
    initial begin
        test_gpio_input = 2'b00;
        $display("TEST_GPIO enabled...");
        #100000
        test_gpio_input = 2'b01;
        #100000
        test_gpio_input = 2'b10;
        #100000
        test_gpio_input = 2'b11;
    end
`endif

    // ADC测试相关
`ifdef TEST_ADC
    reg serial_data_in;
    reg data_valid_in;
    reg [23:0] adc_test_data;
    integer bit_counter;

initial begin
    // 1. 初始化
    serial_data_in = 0;
    data_valid_in = 0;
    adc_test_data = 24'h000001;
    $display("TEST_ADC enabled...");
    
    // 2. 等待复位结束 (假设复位信号 rst_n 已经处理)
    @(posedge clk);

    // 3. 循环发送数据
    forever begin
        $display("[%0t] TB: Preparing to send data 0x%h", $time, adc_test_data);
        
        // 用阻塞赋值 (=)，保证信号在 posedge clk 前就生效
        for (bit_counter = 0; bit_counter < 24; bit_counter = bit_counter + 1) begin
            data_valid_in  = 1'b1;
            serial_data_in = adc_test_data[23 - bit_counter]; // MSB first
            @(posedge clk);
        end

        // 4. 发送完最后一个bit后，再过一个周期将 valid 拉低
        data_valid_in  = 1'b0;
        serial_data_in = 1'b0;
        @(posedge clk);

        // 5. 准备下一次发送
        adc_test_data = adc_test_data + 24'h001001;
        
        // 6. 两次传输之间的空闲间隔
        repeat(100) @(posedge clk);
    end
end

`endif

    // UART测试相关
`ifdef TEST_UART
    reg uart_test_rx;
    reg [7:0] uart_test_data;
    reg [3:0] uart_bit_counter;
    reg uart_test_active;
    
    initial begin
        uart_test_rx = 1'b1; // 空闲状态为高
        uart_test_data = 8'h55;
        uart_bit_counter = 0;
        uart_test_active = 0;
        $display("TEST_UART enabled...");
        
        // 定期发送UART数据
        forever begin
            #100000; // 每100us发送一次
            uart_test_active = 1;
            uart_test_rx = 1'b0; // 起始位
            #8680;   // 115200波特率的位时间
            
            for (uart_bit_counter = 0; uart_bit_counter < 8; uart_bit_counter = uart_bit_counter + 1) begin
                uart_test_rx = uart_test_data[uart_bit_counter];
                #8680;
            end
            
            uart_test_rx = 1'b1; // 停止位
            #8680;
            uart_test_active = 0;
            
            uart_test_data = uart_test_data + 8'h01; // 递增测试数据
        end
    end
`endif

    // 初始化
    initial begin
        // 初始化信号
        clk = 0;
        clk_125m = 0;
        rst_ext_i = 1'b0;
        end_simulation = 0;
        
        $display("TinyRISC-V SoC Testbench Starting...");
        
        // 复位序列
        #40;
        rst_ext_i = 1'b1;
        #100;
        
        $display("Reset released, simulation running...");
        
        // 设置仿真结束时间
        #10000000; // 10ms仿真时间
        end_simulation = 1;
        $display("Simulation completed successfully");
        $finish;
    end
    
    // 监视关键信号
    always @(posedge clk) begin
        if (tinyriscv_soc_top_0.halted_ind == 1'b0) begin
            $display("CPU is running at time %t", $time);
        end
    end
    
    // 读取指令存储器内容
    initial begin
        // 使用正确的路径指向你的指令文件
        //$readmemh("E:/FPGA/Testbench_bram/tools/my_adc.data", tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);

        // Path for shoudong
        $readmemh("D:/RISCV_Project/fpga/Testbench_bram/sdk/examples/my_adc/inst.data", tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);
        $display("Instruction memory loaded successfully");
    end

    // DUT实例化
    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .clk_125m(clk_125m),
        .halted_ind(),           // 输出，不需要驱动
        
        // UART接口
        .uart_tx_pin(),          // 输出
`ifdef TEST_UART
        .uart_rx_pin(uart_test_rx), // 输入
`else
        .uart_rx_pin(1'b1),      // 保持空闲状态
`endif
        
        // GPIO接口
`ifdef TEST_GPIO
    //    .gpio(test_gpio_input),  // 双向，作为输入测试
`else
      //  .gpio(2'bzz),           // 高阻态
`endif
        
        // JTAG接口
        .jtag_TCK(1'b0),        // 测试中不使能JTAG
        .jtag_TMS(1'b0),
        .jtag_TDI(1'b0),
        .jtag_TDO(),
        
        // 电源引脚
        .vcc3v3(),
        
        // I2C接口
`ifdef TEST_I2C
     //   .i2c_scl(),             // 双向
     //   .i2c_sda(),             // 双向
`else
    //    .i2c_scl(1'bz),         // 高阻态
     ////   .i2c_sda(1'bz),
`endif
        
        // SPI接口
`ifdef TEST_SPI
        .spi_sck(),             // 输出
        .spi_mosi(),            // 输出
        .spi_miso(1'b0),        // 输入，接地测试
        .spi_csn(),             // 输出
`else
        .spi_sck(),
        .spi_mosi(),
        .spi_miso(1'bz),
        .spi_csn(),
`endif
        
        // ADC接口
`ifdef TEST_ADC
        .serial_data_in(serial_data_in),
        .data_valid_in(data_valid_in),
`else
        .serial_data_in(1'b0),
        .data_valid_in(1'b0),
`endif
        
        // 以太网接口
        .eth_txc(),
        .eth_tx_ctl(),
        .eth_rst_n(),
        .eth_txd()
    );

endmodule