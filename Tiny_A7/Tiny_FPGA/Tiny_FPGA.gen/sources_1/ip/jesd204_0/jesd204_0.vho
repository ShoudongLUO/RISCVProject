-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2025 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.
-- IP VLNV: xilinx.com:ip:jesd204:7.2
-- IP Revision: 19

-- The following code must appear in the VHDL architecture header.

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT jesd204_0
  PORT (
    gt0_txdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    gt0_txcharisk : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    gt1_txdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    gt1_txcharisk : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    tx_reset_done : IN STD_LOGIC;
    gt_prbssel_out : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    tx_reset_gt : OUT STD_LOGIC;
    tx_core_clk : IN STD_LOGIC;
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    s_axi_awaddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_araddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC;
    tx_reset : IN STD_LOGIC;
    tx_sysref : IN STD_LOGIC;
    tx_start_of_frame : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    tx_start_of_multiframe : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    tx_aresetn : OUT STD_LOGIC;
    tx_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    tx_tready : OUT STD_LOGIC;
    tx_sync : IN STD_LOGIC 
  );
END COMPONENT;
-- COMP_TAG_END ------ End COMPONENT Declaration ------------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
your_instance_name : jesd204_0
  PORT MAP (
    gt0_txdata => gt0_txdata,
    gt0_txcharisk => gt0_txcharisk,
    gt1_txdata => gt1_txdata,
    gt1_txcharisk => gt1_txcharisk,
    tx_reset_done => tx_reset_done,
    gt_prbssel_out => gt_prbssel_out,
    tx_reset_gt => tx_reset_gt,
    tx_core_clk => tx_core_clk,
    s_axi_aclk => s_axi_aclk,
    s_axi_aresetn => s_axi_aresetn,
    s_axi_awaddr => s_axi_awaddr,
    s_axi_awvalid => s_axi_awvalid,
    s_axi_awready => s_axi_awready,
    s_axi_wdata => s_axi_wdata,
    s_axi_wstrb => s_axi_wstrb,
    s_axi_wvalid => s_axi_wvalid,
    s_axi_wready => s_axi_wready,
    s_axi_bresp => s_axi_bresp,
    s_axi_bvalid => s_axi_bvalid,
    s_axi_bready => s_axi_bready,
    s_axi_araddr => s_axi_araddr,
    s_axi_arvalid => s_axi_arvalid,
    s_axi_arready => s_axi_arready,
    s_axi_rdata => s_axi_rdata,
    s_axi_rresp => s_axi_rresp,
    s_axi_rvalid => s_axi_rvalid,
    s_axi_rready => s_axi_rready,
    tx_reset => tx_reset,
    tx_sysref => tx_sysref,
    tx_start_of_frame => tx_start_of_frame,
    tx_start_of_multiframe => tx_start_of_multiframe,
    tx_aresetn => tx_aresetn,
    tx_tdata => tx_tdata,
    tx_tready => tx_tready,
    tx_sync => tx_sync
  );
-- INST_TAG_END ------ End INSTANTIATION Template ---------

-- You must compile the wrapper file jesd204_0.vhd when simulating
-- the core, jesd204_0. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.



