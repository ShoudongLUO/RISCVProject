`timescale 1ns/1ns

module rgmii_tx(
    input      gmii_tx_clk,
    input      gmii_tx_en,
    input [7:0] gmii_txd,
    
    output     rgmii_txc,
    output     rgmii_tx_ctl,
    output [3:0] rgmii_txd
);

assign rgmii_txc = gmii_tx_clk;

// 采样寄存器
reg [3:0] data_rise, data_fall;
reg ctl_rise, ctl_fall;

// 在时钟上升沿采样所有数据
always @(posedge gmii_tx_clk) begin
    data_rise <= gmii_txd[3:0];  // 上升沿输出的数据
    data_fall <= gmii_txd[7:4];  // 下降沿输出的数据
    ctl_rise  <= gmii_tx_en;     // 上升沿输出的控制
    ctl_fall  <= gmii_tx_en;     // 下降沿输出的控制
end

// 使用时钟选择输出
assign rgmii_txd = gmii_tx_clk ? data_rise : data_fall;
assign rgmii_tx_ctl = gmii_tx_clk ? ctl_rise : ctl_fall;

endmodule