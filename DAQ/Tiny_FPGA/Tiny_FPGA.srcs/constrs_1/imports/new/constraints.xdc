# 时钟约束50MHz
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} -add [get_ports clk]

# 时钟引脚
#set_property IOSTANDARD LVCMOS33 [get_ports clk]
#set_property PACKAGE_PIN N14 [get_ports clk]

# 复位引脚
set_property IOSTANDARD LVCMOS33 [get_ports rst_ext_i]
set_property PACKAGE_PIN Y19 [get_ports rst_ext_i]

# CPU停住指示引脚
set_property IOSTANDARD LVCMOS33 [get_ports halted_ind]
set_property PACKAGE_PIN H22 [get_ports halted_ind]

# 串口发送引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property PACKAGE_PIN V17 [get_ports uart_tx_pin]

# 串口接收引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN W17 [get_ports uart_rx_pin]

# GPIO0引脚
set_property IOSTANDARD LVCMOS33 [get_ports {gpio[0]}]
set_property PACKAGE_PIN J16 [get_ports {gpio[0]}]

# GPIO1引脚
set_property IOSTANDARD LVCMOS33 [get_ports {gpio[1]}]
set_property PACKAGE_PIN P15 [get_ports {gpio[1]}]

# JTAG TCK引脚
set_property IOSTANDARD LVCMOS33 [get_ports jtag_TCK]
set_property PACKAGE_PIN M21 [get_ports jtag_TCK]

#create_clock -name jtag_clk_pin -period 300 [get_ports {jtag_TCK}];

# JTAG TMS引脚
set_property IOSTANDARD LVCMOS33 [get_ports jtag_TMS]
set_property PACKAGE_PIN L21 [get_ports jtag_TMS]

# JTAG TDI引脚
set_property IOSTANDARD LVCMOS33 [get_ports jtag_TDI]
set_property PACKAGE_PIN L19 [get_ports jtag_TDI]

# JTAG TDO引脚
set_property IOSTANDARD LVCMOS33 [get_ports jtag_TDO]
set_property PACKAGE_PIN L20 [get_ports jtag_TDO]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_TCK]

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

set_property PACKAGE_PIN J22 [get_ports i2c_sda]
set_property PACKAGE_PIN K19 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
set_property PACKAGE_PIN P16 [get_ports spi_miso]
set_property PACKAGE_PIN R17 [get_ports spi_mosi]
set_property PACKAGE_PIN P14 [get_ports spi_sck]
set_property PACKAGE_PIN R14 [get_ports {spi_csn[1]}]
set_property PACKAGE_PIN T21 [get_ports {spi_csn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {spi_csn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {spi_csn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sck]

set_property PACKAGE_PIN AB18 [get_ports {vcc3v3[1]}]
set_property PACKAGE_PIN N15 [get_ports {vcc3v3[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vcc3v3[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vcc3v3[0]}]



connect_debug_port u_ila_0/probe0 [get_nets [list {spi_0/dbg_spi_csn[0]} {spi_0/dbg_spi_csn[1]}]]
connect_debug_port u_ila_0/probe1 [get_nets [list spi_0/dbg_spi_miso]]
connect_debug_port u_ila_0/probe2 [get_nets [list spi_0/dbg_spi_mosi]]
connect_debug_port u_ila_0/probe3 [get_nets [list spi_0/dbg_spi_sck]]

set_property PACKAGE_PIN F20 [get_ports eth_tx_ctl]
set_property IOSTANDARD LVCMOS33 [get_ports eth_tx_ctl]
set_property PACKAGE_PIN C19 [get_ports eth_txc]
set_property IOSTANDARD LVCMOS33 [get_ports eth_txc]
set_property PACKAGE_PIN G15 [get_ports {eth_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_txd[3]}]
set_property PACKAGE_PIN G22 [get_ports {eth_txd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_txd[2]}]
set_property PACKAGE_PIN G21 [get_ports {eth_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_txd[1]}]
set_property PACKAGE_PIN D21 [get_ports {eth_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_txd[0]}]


set_property PACKAGE_PIN H14 [get_ports eth_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rst_n]
set_property PACKAGE_PIN C18 [get_ports clk_125m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_125m]


#TEST 引脚

set_property IOSTANDARD LVCMOS33 [get_ports start_btn]
set_property PACKAGE_PIN R16 [get_ports start_btn]

set_property PACKAGE_PIN N20 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN M20 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property PACKAGE_PIN N22 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]
set_property PACKAGE_PIN M22 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]




connect_debug_port u_ila_0/probe1 [get_nets [list {parallel_data_out[0]} {parallel_data_out[1]} {parallel_data_out[2]} {parallel_data_out[3]} {parallel_data_out[4]} {parallel_data_out[5]} {parallel_data_out[6]} {parallel_data_out[7]} {parallel_data_out[8]} {parallel_data_out[9]} {parallel_data_out[10]} {parallel_data_out[11]} {parallel_data_out[12]} {parallel_data_out[13]} {parallel_data_out[14]} {parallel_data_out[15]} {parallel_data_out[16]} {parallel_data_out[17]} {parallel_data_out[18]} {parallel_data_out[19]} {parallel_data_out[20]} {parallel_data_out[21]} {parallel_data_out[22]} {parallel_data_out[23]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {expected_data[0]} {expected_data[1]} {expected_data[2]} {expected_data[3]} {expected_data[4]} {expected_data[5]} {expected_data[6]} {expected_data[7]} {expected_data[8]} {expected_data[9]} {expected_data[10]} {expected_data[11]} {expected_data[12]} {expected_data[13]} {expected_data[14]} {expected_data[15]} {expected_data[16]} {expected_data[17]} {expected_data[18]} {expected_data[19]} {expected_data[20]} {expected_data[21]} {expected_data[22]} {expected_data[23]}]]
connect_debug_port u_ila_1/clk [get_nets [list clk_125m_IBUF_BUFG]]
connect_debug_port dbg_hub/clk [get_nets clk_125m_IBUF_BUFG]




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 7 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/write_depth[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 7 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_adc_core/read_depth[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 24 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[7]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[8]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[9]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[10]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[11]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[12]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[13]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[14]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[15]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[16]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[17]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[18]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[19]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[20]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[21]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[22]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/adc_data_dly[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[7]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[8]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[9]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[10]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[11]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[12]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[13]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[14]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[15]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[16]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[17]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[18]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[19]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[20]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[21]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[22]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[23]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[24]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[25]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[26]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[27]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[28]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[29]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[30]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/baseline_rib_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[7]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[8]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[9]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[10]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[11]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[12]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[13]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[14]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[15]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[16]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[17]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[18]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[19]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[20]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[21]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[22]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[23]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[24]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[25]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[26]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[27]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[28]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[29]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[30]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cal_adc_value[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 5 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fee_mode[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fee_mode[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fee_mode[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fee_mode[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fee_mode[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[7]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[8]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[9]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[10]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[11]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[12]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[13]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[14]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[15]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[16]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[17]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[18]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[19]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[20]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[21]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[22]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[23]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[24]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[25]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[26]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[27]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[28]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[29]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[30]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/fifo_data_out[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 5 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fee_mode[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fee_mode[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fee_mode[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fee_mode[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fee_mode[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 2 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {tinyriscv_soc_top_0/spi_0/dbg_spi_csn[0]} {tinyriscv_soc_top_0/spi_0/dbg_spi_csn[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 24 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {tinyriscv_soc_top_0/adc_data_1[0]} {tinyriscv_soc_top_0/adc_data_1[1]} {tinyriscv_soc_top_0/adc_data_1[2]} {tinyriscv_soc_top_0/adc_data_1[3]} {tinyriscv_soc_top_0/adc_data_1[4]} {tinyriscv_soc_top_0/adc_data_1[5]} {tinyriscv_soc_top_0/adc_data_1[6]} {tinyriscv_soc_top_0/adc_data_1[7]} {tinyriscv_soc_top_0/adc_data_1[8]} {tinyriscv_soc_top_0/adc_data_1[9]} {tinyriscv_soc_top_0/adc_data_1[10]} {tinyriscv_soc_top_0/adc_data_1[11]} {tinyriscv_soc_top_0/adc_data_1[12]} {tinyriscv_soc_top_0/adc_data_1[13]} {tinyriscv_soc_top_0/adc_data_1[14]} {tinyriscv_soc_top_0/adc_data_1[15]} {tinyriscv_soc_top_0/adc_data_1[16]} {tinyriscv_soc_top_0/adc_data_1[17]} {tinyriscv_soc_top_0/adc_data_1[18]} {tinyriscv_soc_top_0/adc_data_1[19]} {tinyriscv_soc_top_0/adc_data_1[20]} {tinyriscv_soc_top_0/adc_data_1[21]} {tinyriscv_soc_top_0/adc_data_1[22]} {tinyriscv_soc_top_0/adc_data_1[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_fifo_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/cfg_udp_tx_enable]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/ctrl_fifo_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/ctrl_udp_tx_enable]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list tinyriscv_soc_top_0/data_ready_out_1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list tinyriscv_soc_top_0/spi_0/dbg_spi_miso]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list tinyriscv_soc_top_0/spi_0/dbg_spi_mosi]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list tinyriscv_soc_top_0/spi_0/dbg_spi_sck]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list eth_txc_OBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 8 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_txd[7]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 32 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[0]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[1]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[2]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[3]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[4]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[5]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[6]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[7]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[8]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[9]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[10]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[11]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[12]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[13]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[14]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[15]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[16]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[17]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[18]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[19]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[20]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[21]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[22]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[23]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[24]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[25]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[26]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[27]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[28]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[29]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[30]} {tinyriscv_soc_top_0/u_ADC_UDP_top_inst/udp_tx_data[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/gmii_tx_en]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/internal_tx_start_en_pulse]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list tinyriscv_soc_top_0/u_ADC_UDP_top_inst/u_udp_core/tx_req]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets eth_txc_OBUF_BUFG]
