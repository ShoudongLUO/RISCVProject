`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author  : EmbedFire
// ʵ��ƽ̨: Ұ��FPGAϵ�п�����
// ��˾    : http://www.embedfire.com
// ��̳    : http://www.firebbs.cn
// �Ա�    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module rgmii_tx(
    //GMII���Ͷ˿�
    input              gmii_tx_clk , //GMII����ʱ��
    input              gmii_tx_en  , //GMII���������Ч�ź�
    input       [7:0]  gmii_txd    , //GMII�������

    //RGMII���Ͷ˿�
    output             rgmii_txc   , //RGMII��������ʱ��
    output             rgmii_tx_ctl, //RGMII���������Ч�ź�
    output      [3:0]  rgmii_txd     //RGMII�������
    );

//*****************************************************
//**                    main code
//*****************************************************

assign rgmii_txc = gmii_tx_clk;

ODDR2 #(
   .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
   .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
   .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) ODDR_inst (
   .Q(rgmii_tx_ctl),   // 1-bit DDR output data
   .C0(gmii_tx_clk),   // 1-bit clock input
   .C1(~gmii_tx_clk),   // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D0(gmii_tx_en), // 1-bit data input (associated with C0)
   .D1(gmii_tx_en), // 1-bit data input (associated with C1)
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
        //���˫�ز����Ĵ��� (rgmii_txd)

    ODDR2 #(
       .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
       .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
       .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
    ) ODDR_inst (
       .Q(rgmii_txd[i]),   // 1-bit DDR output data
       .C0(gmii_tx_clk),   // 1-bit clock input
       .C1(~gmii_tx_clk),   // 1-bit clock input
       .CE(1'b1), // 1-bit clock enable input
       .D0(gmii_txd[i]), // 1-bit data input (associated with C0)
       .D1(gmii_txd[4+i]), // 1-bit data input (associated with C1)
       .R(1'b0),   // 1-bit reset input
       .S(1'b0)    // 1-bit set input
    );
    end
endgenerate

endmodule