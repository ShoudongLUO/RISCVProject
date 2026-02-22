vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/gig_ethernet_pcs_pma_v16_2_15
vlib modelsim_lib/msim/xil_defaultlib

vmap gig_ethernet_pcs_pma_v16_2_15 modelsim_lib/msim/gig_ethernet_pcs_pma_v16_2_15
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vcom -work gig_ethernet_pcs_pma_v16_2_15  -93  \
"../../../ipstatic/hdl/gig_ethernet_pcs_pma_v16_2_rfs.vhd" \

vlog -work gig_ethernet_pcs_pma_v16_2_15  -incr -mfcu  \
"../../../ipstatic/hdl/gig_ethernet_pcs_pma_v16_2_rfs.v" \

vlog -work xil_defaultlib  -incr -mfcu  \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_sgmii_phy_clk_gen.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_sgmii_phy_reset_gen.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_idelayctrl.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_support.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_reset_wtd_timer.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_adapt/gig_ethernet_pcs_pma_0_clk_gen.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_adapt/gig_ethernet_pcs_pma_0_johnson_cntr.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_reset_sync.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_adapt/gig_ethernet_pcs_pma_0_rx_rate_adapt.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_adapt/gig_ethernet_pcs_pma_0_sgmii_adapt.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_sync_block.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_adapt/gig_ethernet_pcs_pma_0_tx_rate_adapt.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_gearbox_4_to_10.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_gearbox_10_to_4.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_serdes_1_to_10_ser8.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_serdes_10_to_1_ser8.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_delay_controller_wrap.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_lvds_transceiver_ser8.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_decode_8b10b_lut_base.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/sgmii_lvds_transceiver/gig_ethernet_pcs_pma_0_encode_8b10b_lut_base.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_block.v" \
"../../../../UDP_TEST.gen/sources_1/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

