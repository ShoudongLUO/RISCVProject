//------------------------------------------------------------------------------
// File       : gig_ethernet_pcs_pma_0_sgmii_phy_clk_gen.v
// Author     : AMD
//------------------------------------------------------------------------------
// (c) Copyright 2006 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES. 

//
//
//------------------------------------------------------------------------------
// Description:   This module takes in a 125 MHz clock from the MB and builds all the clocks
// neccessary for GPIO-SGMII.
//------------------------------------------------------------------------------


`timescale 1ns / 1ps
module gig_ethernet_pcs_pma_0_sgmii_phy_clk_gen(
    input  wire refclk625_p,
    input  wire refclk625_n,
    input  wire rst,
    output wire o_clk625,
    output wire idelayctrl_rdy, 
    output wire o_clk312,
    output wire o_clk125,

    output wire o_mmcm_locked
    );
    
wire clk625_i;
wire clk312_i;
wire o_clk312_i;
wire idelayctrl_reset_sync;
wire clk125_i;
wire clk625_in;
wire o_clk625_i;
wire o_clk125_i;
wire o_mmcm_locked_i;
wire clk_fb, clk_fb_i;
// Global Clock Inputs
IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")	
) clk625_ibufg (
   .O   (clk625_in),  
   .I   (refclk625_p),  
   .IB  (refclk625_n) 
);   

  MMCME3_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .CLKFBOUT_MULT_F      (2.000),
    .CLKIN1_PERIOD        (1.6),
    .DIVCLK_DIVIDE        (2),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("AUTO"),
    .STARTUP_WAIT         ("FALSE"),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (5.000),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (2),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT1_USE_FINE_PS  ("FALSE"),
    .CLKOUT2_DIVIDE       (1),
    .CLKOUT2_PHASE        (0.000),
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKOUT2_USE_FINE_PS  ("FALSE"),
    .REF_JITTER1          (0.010))
  mmcme3_adv_inst
    // Output clocks
   (
    .CLKFBOUT            (clk_fb_i),
    .CLKFBOUTB           (),
    .CLKOUT0             (clk125_i),
    .CLKOUT0B            (),
    .CLKOUT1             (clk312_i),
    .CLKOUT1B            (),
    .CLKOUT2             (clk625_i),
    .CLKOUT2B            (),
    .CLKOUT3             (),
    .CLKOUT3B            (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    .CLKOUT6             (),
     // Input clock control
    .CLKFBIN             (clk_fb),
    .CLKIN1              (clk625_in),
    .CLKIN2              (1'b0),
     // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (),
    .DRDY                (),
    .DWE                 (1'b0),
    .CDDCDONE            (),
    .CDDCREQ             (1'b0),
    // Ports for dynamic phase shift
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0),
    .PSDONE              (),
    // Other control and status signals
    .LOCKED              (o_mmcm_locked_i),
    .CLKINSTOPPED        (),
    .CLKFBSTOPPED        (),
    .PWRDWN              (1'b0),
    .RST                 (rst));


  // Output buffering
  //-----------------------------------
BUFG clkf_buf
(.O (clk_fb),
 .I (clk_fb_i));

BUFG clk625_buf
(.O (o_clk625_i),
 .I (clk625_i));


BUFGCE_DIV #(
      .BUFGCE_DIVIDE(2) ) clk312_buf
(.O (o_clk312_i),
 .CE (1'b1),
 .CLR (1'b0),
 .I (clk625_i));

assign o_clk312 = o_clk312_i;


BUFG clk125_buf
(.O (o_clk125_i),
 .I (clk125_i));

assign o_clk625 = o_clk625_i;
assign o_clk125 = o_clk125_i;
assign o_mmcm_locked = o_mmcm_locked_i & idelayctrl_rdy;

 // Create a synchronous reset in the IDELAYCTRL clock domain.
   gig_ethernet_pcs_pma_0_reset_sync idelayctrl_reset_gen (
      .clk       (o_clk625_i),
      .reset_in  (~o_mmcm_locked_i),
      .reset_out (idelayctrl_reset_sync)
   );   

gig_ethernet_pcs_pma_0_idelayctrl core_idelayctrl_i 
 (
   .refclk                      (o_clk625_i),
   .rst                         (idelayctrl_reset_sync),
   .rdy                         (idelayctrl_rdy)
 );

endmodule
