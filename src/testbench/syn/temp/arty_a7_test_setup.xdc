## This file is a general .xdc for the Arty A7-100 Rev. A

## For default neorv32_test_setup.vhd top entity

## Clock signal
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { SYS_CLK }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name SYS_CLK -period 10.00 -waveform {0 5} [get_ports { SYS_CLK }];

## LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led_0 }]; #IO_L24N_T3_35 Sch=led[4]
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led_1 }]; #IO_25_35 Sch=led[5]
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led_2 }]; #IO_L24P_T3_A01_D17_14 Sch=led[6]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led_3 }]; #IO_L24N_T3_A00_D16_14 Sch=led[7]

## Pmod Header JA (unused GPIO outputs)
#set_property -dict { PACKAGE_PIN G13  IOSTANDARD LVCMOS33 } [get_ports { gpio_o[4] }]; #IO_0_15 Sch=ja[1]
#set_property -dict { PACKAGE_PIN B11  IOSTANDARD LVCMOS33 } [get_ports { gpio_o[5] }]; #IO_L4P_T0_15 Sch=ja[2]
#set_property -dict { PACKAGE_PIN A11  IOSTANDARD LVCMOS33 } [get_ports { gpio_o[6] }]; #IO_L4N_T0_15 Sch=ja[3]
#set_property -dict { PACKAGE_PIN D12  IOSTANDARD LVCMOS33 } [get_ports { gpio_o[7] }]; #IO_L6P_T0_15 Sch=ja[4]

## USB-UART Interface
set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { UART0_RXD }]; #IO_L14N_T2_SRCC_16 Sch=uart_txd_in
set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33 } [get_ports { UART0_TXD }]; #IO_L19N_T3_VREF_16 Sch=uart_rxd_out

## SMSC Ethernet PHY
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { mcoll_pad_i }]; #IO_L16N_T2_A27_15 Sch=eth_col
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { mcrs_pad_i }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=eth_crs
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { mdc_pad_o }]; #IO_L14N_T2_SRCC_15 Sch=eth_mdc
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { mdio_pad_io }]; #IO_L17P_T2_A26_15 Sch=eth_mdio

# Generated 25 MHz ref clock from SYS_CLK/4
create_generated_clock -name ETH_REFCLK -source [get_ports SYS_CLK] -divide_by 4 [get_ports eth_ref_clk]
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { eth_rstn }]; #IO_L20P_T3_A20_15 Sch=eth_rstn

set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { mrx_clk_pad_i }]; #IO_L14P_T2_SRCC_15 Sch=eth_rx_clk
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { mrxdv_pad_i }]; #IO_L13N_T2_MRCC_15 Sch=eth_rx_dv
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { mrxd_pad_i[0] }]; #IO_L21N_T3_DQS_A18_15 Sch=eth_rxd[0]
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { mrxd_pad_i[1] }]; #IO_L16P_T2_A28_15 Sch=eth_rxd[1]
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { mrxd_pad_i[2] }]; #IO_L21P_T3_DQS_15 Sch=eth_rxd[2]
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { mrxd_pad_i[3] }]; #IO_L18N_T2_A23_15 Sch=eth_rxd[3]
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { mrxerr_pad_i }]; #IO_L20N_T3_A19_15 Sch=eth_rxerr

set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { mtx_clk_pad_i }]; #IO_L13P_T2_MRCC_15 Sch=eth_tx_clk
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { mtxen_pad_o }]; #IO_L19N_T3_A21_VREF_15 Sch=eth_tx_en
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { mtxd_pad_o[0] }]; #IO_L15P_T2_DQS_15 Sch=eth_txd[0]
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { mtxd_pad_o[1] }]; #IO_L19P_T3_A22_15 Sch=eth_txd[1]
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { mtxd_pad_o[2] }]; #IO_L17N_T2_A25_15 Sch=eth_txd[2]
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { mtxd_pad_o[3] }]; #IO_L18P_T2_A24_15 Sch=eth_txd[3]

## Misc.
set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS33 } [get_ports { SYS_RST }]; #IO_L16P_T2_35 Sch=ck_rst

set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports { SYS_RST } ]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports { UART0_RXD } ]

# Allow up to 20 ns combinational+route from SYS_CLK flops to the pad
set_max_delay -datapath_only 20.0 -from [get_clocks SYS_CLK] -to [get_ports UART0_TXD]
# Hold can be 0 for outputs (no latch at the receiver), but specify explicitly:
set_min_delay 0.0 -from [get_clocks SYS_CLK] -to [get_ports UART0_TXD]

set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports { led_0 } ]
set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports { led_1 } ]
set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports { led_2 } ]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay -1.000 [get_ports { led_0 } ]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay -1.000 [get_ports { led_1 } ]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay -1.000 [get_ports { led_2 } ]

group_path -name LED_DEBUG -to [get_ports led_3]
set_false_path -to [get_ports led_3]
#set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay -1.000 [get_ports { led_3 } ]
#set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 1000000.000 [get_ports { led_3 } ]

##DDR3
set_property IO_BUFFER_TYPE NONE [get_ports {ddr3_ck_n[*]} ]
set_property IO_BUFFER_TYPE NONE [get_ports {ddr3_ck_p[*]} ]

# PadFunction: IO_L5P_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN K5 [get_ports {ddr3_dq[0]}]

# PadFunction: IO_L2N_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN L3 [get_ports {ddr3_dq[1]}]

# PadFunction: IO_L2P_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[2]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN K3 [get_ports {ddr3_dq[2]}]

# PadFunction: IO_L6P_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[3]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN L6 [get_ports {ddr3_dq[3]}]

# PadFunction: IO_L4P_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[4]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN M3 [get_ports {ddr3_dq[4]}]

# PadFunction: IO_L1N_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[5]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN M1 [get_ports {ddr3_dq[5]}]

# PadFunction: IO_L5N_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[6]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN L4 [get_ports {ddr3_dq[6]}]

# PadFunction: IO_L4N_T0_34 
set_property SLEW FAST [get_ports {ddr3_dq[7]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN M2 [get_ports {ddr3_dq[7]}]

# PadFunction: IO_L10N_T1_34 
set_property SLEW FAST [get_ports {ddr3_dq[8]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN V4 [get_ports {ddr3_dq[8]}]

# PadFunction: IO_L12P_T1_MRCC_34 
set_property SLEW FAST [get_ports {ddr3_dq[9]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN T5 [get_ports {ddr3_dq[9]}]

# PadFunction: IO_L8P_T1_34 
set_property SLEW FAST [get_ports {ddr3_dq[10]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN U4 [get_ports {ddr3_dq[10]}]

# PadFunction: IO_L10P_T1_34 
set_property SLEW FAST [get_ports {ddr3_dq[11]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN V5 [get_ports {ddr3_dq[11]}]

# PadFunction: IO_L7N_T1_34 
set_property SLEW FAST [get_ports {ddr3_dq[12]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN V1 [get_ports {ddr3_dq[12]}]

# PadFunction: IO_L11N_T1_SRCC_34 
set_property SLEW FAST [get_ports {ddr3_dq[13]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN T3 [get_ports {ddr3_dq[13]}]

# PadFunction: IO_L8N_T1_34 
set_property SLEW FAST [get_ports {ddr3_dq[14]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN U3 [get_ports {ddr3_dq[14]}]

# PadFunction: IO_L11P_T1_SRCC_34 
set_property SLEW FAST [get_ports {ddr3_dq[15]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dq[15]}]
set_property PACKAGE_PIN R3 [get_ports {ddr3_dq[15]}]

# PadFunction: IO_L24N_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[13]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[13]}]
set_property PACKAGE_PIN T8 [get_ports {ddr3_addr[13]}]

# PadFunction: IO_L23N_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[12]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN T6 [get_ports {ddr3_addr[12]}]

# PadFunction: IO_L22N_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[11]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN U6 [get_ports {ddr3_addr[11]}]

# PadFunction: IO_L19P_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[10]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN R6 [get_ports {ddr3_addr[10]}]

# PadFunction: IO_L20P_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[9]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN V7 [get_ports {ddr3_addr[9]}]

# PadFunction: IO_L24P_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[8]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN R8 [get_ports {ddr3_addr[8]}]

# PadFunction: IO_L22P_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[7]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN U7 [get_ports {ddr3_addr[7]}]

# PadFunction: IO_L20N_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[6]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN V6 [get_ports {ddr3_addr[6]}]

# PadFunction: IO_L23P_T3_34 
set_property SLEW FAST [get_ports {ddr3_addr[5]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN R7 [get_ports {ddr3_addr[5]}]

# PadFunction: IO_L18N_T2_34 
set_property SLEW FAST [get_ports {ddr3_addr[4]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN N6 [get_ports {ddr3_addr[4]}]

# PadFunction: IO_L17N_T2_34 
set_property SLEW FAST [get_ports {ddr3_addr[3]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN T1 [get_ports {ddr3_addr[3]}]

# PadFunction: IO_L16N_T2_34 
set_property SLEW FAST [get_ports {ddr3_addr[2]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN N4 [get_ports {ddr3_addr[2]}]

# PadFunction: IO_L18P_T2_34 
set_property SLEW FAST [get_ports {ddr3_addr[1]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN M6 [get_ports {ddr3_addr[1]}]

# PadFunction: IO_L15N_T2_DQS_34 
set_property SLEW FAST [get_ports {ddr3_addr[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN R2 [get_ports {ddr3_addr[0]}]

# PadFunction: IO_L15P_T2_DQS_34 
set_property SLEW FAST [get_ports {ddr3_ba[2]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_ba[2]}]
set_property PACKAGE_PIN P2 [get_ports {ddr3_ba[2]}]

# PadFunction: IO_L14P_T2_SRCC_34 
set_property SLEW FAST [get_ports {ddr3_ba[1]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN P4 [get_ports {ddr3_ba[1]}]

# PadFunction: IO_L17P_T2_34 
set_property SLEW FAST [get_ports {ddr3_ba[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN R1 [get_ports {ddr3_ba[0]}]

# PadFunction: IO_L14N_T2_SRCC_34 
set_property SLEW FAST [get_ports {ddr3_ras_n}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_ras_n}]
set_property PACKAGE_PIN P3 [get_ports {ddr3_ras_n}]

# PadFunction: IO_L16P_T2_34 
set_property SLEW FAST [get_ports {ddr3_cas_n}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_cas_n}]
set_property PACKAGE_PIN M4 [get_ports {ddr3_cas_n}]

# PadFunction: IO_L13N_T2_MRCC_34 
set_property SLEW FAST [get_ports {ddr3_we_n}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_we_n}]
set_property PACKAGE_PIN P5 [get_ports {ddr3_we_n}]

# PadFunction: IO_0_34 
set_property SLEW FAST [get_ports {ddr3_reset_n}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_reset_n}]
set_property PACKAGE_PIN K6 [get_ports {ddr3_reset_n}]

# PadFunction: IO_L13P_T2_MRCC_34 
set_property SLEW FAST [get_ports {ddr3_cke[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_cke[0]}]
set_property PACKAGE_PIN N5 [get_ports {ddr3_cke[0]}]

# PadFunction: IO_L19N_T3_VREF_34 
set_property SLEW FAST [get_ports {ddr3_odt[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_odt[0]}]
set_property PACKAGE_PIN R5 [get_ports {ddr3_odt[0]}]

# PadFunction: IO_25_34 
set_property SLEW FAST [get_ports {ddr3_cs_n[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_cs_n[0]}]
set_property PACKAGE_PIN U8 [get_ports {ddr3_cs_n[0]}]

# PadFunction: IO_L1P_T0_34 
set_property SLEW FAST [get_ports {ddr3_dm[0]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN L1 [get_ports {ddr3_dm[0]}]

# PadFunction: IO_L7P_T1_34 
set_property SLEW FAST [get_ports {ddr3_dm[1]}]
set_property IOSTANDARD SSTL135 [get_ports {ddr3_dm[1]}]
set_property PACKAGE_PIN U1 [get_ports {ddr3_dm[1]}]

# PadFunction: IO_L3P_T0_DQS_34 
set_property SLEW FAST [get_ports {ddr3_dqs_p[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dqs_p[0]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_dqs_p[0]}]
set_property PACKAGE_PIN N2 [get_ports {ddr3_dqs_p[0]}]

# PadFunction: IO_L3N_T0_DQS_34 
set_property SLEW FAST [get_ports {ddr3_dqs_n[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_dqs_n[0]}]
set_property PACKAGE_PIN N1 [get_ports {ddr3_dqs_n[0]}]

# PadFunction: IO_L9P_T1_DQS_34 
set_property SLEW FAST [get_ports {ddr3_dqs_p[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dqs_p[1]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_dqs_p[1]}]
set_property PACKAGE_PIN U2 [get_ports {ddr3_dqs_p[1]}]

# PadFunction: IO_L9N_T1_DQS_34 
set_property SLEW FAST [get_ports {ddr3_dqs_n[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr3_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_dqs_n[1]}]
set_property PACKAGE_PIN V2 [get_ports {ddr3_dqs_n[1]}]

# PadFunction: IO_L21P_T3_DQS_34 
set_property SLEW FAST [get_ports {ddr3_ck_p[0]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_ck_p[0]}]
set_property PACKAGE_PIN U9 [get_ports {ddr3_ck_p[0]}]

# PadFunction: IO_L21N_T3_DQS_34 
set_property SLEW FAST [get_ports {ddr3_ck_n[0]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {ddr3_ck_n[0]}]
set_property PACKAGE_PIN V9 [get_ports {ddr3_ck_n[0]}]

set_property INTERNAL_VREF  0.675 [get_iobanks 34]
set_property INTERNAL_VREF  0.675 [get_iobanks 35]

##DDR3
