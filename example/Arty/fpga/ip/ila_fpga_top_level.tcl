
# ila_fpga_top_level #() inst_ila_fpga_top_level (
#   .clk (clk),
#   .probe0 (phy_ref_clk), //! output wire   
#   .probe1 (phy_rx_clk),  //! input  wire   
#   .probe2 (phy_rxd),     //! input  wire [3:0] 
#   .probe3 (phy_rx_dv),   //! input  wire   
#   .probe4 (phy_rx_er),   //! input  wire   
#   .probe5 (phy_tx_clk),  //! input  wire   
#   .probe6 (phy_txd),     //! output wire [3:0] 
#   .probe7 (phy_tx_en),   //! output wire   
#   .probe8 (phy_col),     //! input  wire   
#   .probe9 (phy_crs),     //! input  wire   
#   .probe10(phy_reset_n)  //! output wire   
# );

set module_name {ila_fpga_top_level}
set mii_d_width {4}
set mii_dv_width [expr {int($mii_d_width/4)}]
set config [dict create]

# settings
dict set config C_NUM_OF_PROBES 11;
dict set config C_DATA_DEPTH 2048;
dict set config C_INPUT_PIPE_STAGES 2;

# probes
dict set config C_PROBE0_WIDTH 1; 
dict set config C_PROBE1_WIDTH 1; 
dict set config C_PROBE2_WIDTH 1; 
dict set config C_PROBE3_WIDTH $mii_d_width; 
dict set config C_PROBE4_WIDTH 1; 
dict set config C_PROBE5_WIDTH 1; 
dict set config C_PROBE6_WIDTH 1;
dict set config C_PROBE7_WIDTH $mii_d_width;
dict set config C_PROBE8_WIDTH 1;  
dict set config C_PROBE9_WIDTH 1;  
dict set config C_PROBE10_WIDTH 1; 
dict set config C_PROBE11_WIDTH 1;

proc create_ila_ip {name config} {
  create_ip -name ila -vendor xilinx.com -library ip -module_name $name
  set ip [get_ips $name]
  set config_list {}
  dict for {name value} $config {
  lappend config_list "CONFIG.${name}" $value
  }
  set_property -dict $config_list $ip
}

create_ila_ip "${module_name}" $config