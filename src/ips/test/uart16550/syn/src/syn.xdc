#
# (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.
#

# Target 170MHz clock speed.
#set_property HD.CLK_SRC [get_ports wb_clk_i] [get_cells uart_top]
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { wb_clk_i }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -period 5.88 -name SYS_CLK -waveform {0.0 2.94} [get_ports wb_clk_i]

# Inputs are directly driven from FF.
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_rst_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_adr_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports {wb_dat_i[*]}]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_we_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_stb_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_cyc_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports wb_sel_i]
set_input_delay -clock [get_clocks SYS_CLK] -add_delay 1.000 [get_ports srx_pad_i]

# Design has double flop synchronizer.
#set_false_path -from [get_ports i_fiq]

# Output pin configuration.
set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports wb_ack_o]
set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports {wb_dat_o[*]}]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay 2.000 [get_ports wb_ack_o]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay -1.000 [get_ports {wb_dat_o[*]}]

set_output_delay -clock [get_clocks SYS_CLK] -max -add_delay 2.000 [get_ports stx_pad_o]
set_output_delay -clock [get_clocks SYS_CLK] -min -add_delay 2.000 [get_ports stx_pad_o]
