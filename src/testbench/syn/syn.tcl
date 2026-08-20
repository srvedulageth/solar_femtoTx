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
set board "A7-100"
set a7part "xc7a100tcsg324-1"
set a7prj ${board}-solar_femtoTX

# Create and clear output directory
set outputdir work
file mkdir $outputdir

set files [glob -nocomplain "$outputdir/*"]
if {[llength $files] != 0} {
    puts "deleting contents of $outputdir"
    file delete -force {*}[glob -directory $outputdir *]; # clear folder contents
} else {
    puts "$outputdir is empty"
}

# We targeting an Artix-7 speed grade -1 FPGA for synthesis.
#create_project project_1 -part xc7a100tcsg324-1
create_project -part $a7part $a7prj $outputdir

# Add RTL files and includes for synthesis.
add_files -scan_for_includes {
../../zap_rtl/zap_alu_main.sv \
../../zap_rtl/zap_btb.sv \
../../zap_rtl/zap_cache_fsm.sv \
../../zap_rtl/zap_cache.sv \
../../zap_rtl/zap_cache_tag_ram.sv \
../../zap_rtl/zap_core.sv \
../../zap_rtl/zap_cp15_cb.sv \
../../zap_rtl/zap_dcache_fsm.sv \
../../zap_rtl/zap_dcache.sv \
../../zap_rtl/zap_decode_main.sv \
../../zap_rtl/zap_decode.sv \
../../zap_rtl/zap_decompile.sv \
../../zap_rtl/zap_dual_rank_synchronizer.sv \
../../zap_rtl/zap_fetch_main.sv \
../../zap_rtl/zap_fifo.sv \
../../zap_rtl/zap_issue_main.sv \
../../zap_rtl/zap_mem_inv_block.sv \
../../zap_rtl/zap_memory_main.sv \
../../zap_rtl/zap_mode16_decoder_main.sv \
../../zap_rtl/zap_mode16_decoder.sv \
../../zap_rtl/zap_ones_counter.sv \
../../zap_rtl/zap_postalu_main.sv \
../../zap_rtl/zap_predecode_coproc.sv \
../../zap_rtl/zap_predecode_main.sv \
../../zap_rtl/zap_predecode_uop_sequencer.sv \
../../zap_rtl/zap_ram_simple_ben.sv \
../../zap_rtl/zap_ram_simple_nopipe.sv \
../../zap_rtl/zap_ram_simple.sv \
../../zap_rtl/zap_register_file.sv \
../../zap_rtl/zap_shifter_main.sv \
../../zap_rtl/zap_shifter_multiply.sv \
../../zap_rtl/zap_shifter_shift.sv \
../../zap_rtl/zap_sync_fifo.sv \
../../zap_rtl/zap_tlb_check.sv \
../../zap_rtl/zap_tlb_fsm.sv \
../../zap_rtl/zap_tlb.sv \
../../zap_rtl/zap_wb_merger_gpt.sv \
../../zap_rtl/zap_writeback.sv \
../../zap_rtl/zap_top.sv \
../../ips/misc/wb_arb2.v \
../../ips/ram_wb/verilog/ram_wb.v \
../../ips/ram_wb/verilog/ram_wb_sc_sw.v \
../../ips/uart16550/rtl/verilog/raminfr.v \
../../ips/uart16550/rtl/verilog/uart_debug_if.v \
../../ips/uart16550/rtl/verilog/uart_receiver.v \
../../ips/uart16550/rtl/verilog/uart_regs.v \
../../ips/uart16550/rtl/verilog/uart_rfifo.v \
../../ips/uart16550/rtl/verilog/uart_sync_flops.v \
../../ips/uart16550/rtl/verilog/uart_tfifo.v \
../../ips/uart16550/rtl/verilog/uart_transmitter.v \
../../ips/uart16550/rtl/verilog/uart_wb.v \
../../ips/uart16550/rtl/verilog/uart_top.v \
../../ips/ethmac/rtl/verilog/eth_clockgen.v \
../../ips/ethmac/rtl/verilog/eth_cop.v \
../../ips/ethmac/rtl/verilog/eth_crc.v \
../../ips/ethmac/rtl/verilog/eth_fifo.v \
../../ips/ethmac/rtl/verilog/eth_maccontrol.v \
../../ips/ethmac/rtl/verilog/eth_macstatus.v \
../../ips/ethmac/rtl/verilog/eth_miim.v \
../../ips/ethmac/rtl/verilog/eth_outputcontrol.v \
../../ips/ethmac/rtl/verilog/eth_random.v \
../../ips/ethmac/rtl/verilog/eth_receivecontrol.v \
../../ips/ethmac/rtl/verilog/eth_registers.v \
../../ips/ethmac/rtl/verilog/eth_rxaddrcheck.v \
../../ips/ethmac/rtl/verilog/eth_rxcounters.v \
../../ips/ethmac/rtl/verilog/eth_register.v \
../../ips/ethmac/rtl/verilog/eth_rxethmac.v \
../../ips/ethmac/rtl/verilog/eth_rxstatem.v \
../../ips/ethmac/rtl/verilog/eth_spram_256x32.v \
../../ips/ethmac/rtl/verilog/eth_shiftreg.v \
../../ips/ethmac/rtl/verilog/eth_transmitcontrol.v \
../../ips/ethmac/rtl/verilog/eth_txcounters.v \
../../ips/ethmac/rtl/verilog/eth_txethmac.v \
../../ips/ethmac/rtl/verilog/eth_txstatem.v \
../../ips/ethmac/rtl/verilog/eth_wishbone.v \
../../ips/ethmac/rtl/verilog/xilinx_dist_ram_16x32.v \
../../ips/ethmac/rtl/verilog/ethmac.v \
../../ips/misc/reset_sync_debounce.v \
../../ips/timer/timer.v \
../../ips/vic/vic.v \
../../ips/ram_wb/verilog/wb_ddr3_bridge.v \
../../ips/ddr3/core_ddr3_controller/examples/arty_a7/artix7_pll.v \
../../ips/ddr3/core_ddr3_controller/src_v/ddr3_dfi_seq.v \
../../ips/ddr3/core_ddr3_controller/src_v/ddr3_core.v \
../../ips/ddr3/core_ddr3_controller/src_v/ddr3_calib_dqs_window.v \
../../ips/ddr3/core_ddr3_controller/src_v/phy/xc7/ddr3_dfi_phy.v \
./zap_soc.v \
}

# Add XDC file into the mix, into constrs_1.
add_files -fileset constrs_1 -norecurse ./arty_a7_test_setup.xdc

set_property incremental_checkpoint {} [get_runs synth_1]

synth_design \
-top zap_soc \
-verilog_define SYNTHESIS=1 \
-verilog_define DDR3_CONTROLLER=1 \
-part xc7a100tcsg324-1 \
-gated_clock_conversion auto \
-directive PerformanceOptimized \
-retiming \
-resource_sharing off \
-no_lc \
-shreg_min_size 5

#
# Generate a timing report for the worst 1000 paths. We expect the timing
# report to be clean.
#
report_timing_summary \
-delay_type max \
-report_unconstrained \
-check_timing_verbose \
-max_paths 1000 \
-input_pins \
-file zap_soc_syn_timing.rpt

#
# Generate a DCP file that can be loaded for further runs to integrate
# the design into an SOC.
#
write_checkpoint -force zap_synth.dcp

open_checkpoint zap_synth.dcp

create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 16384 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
startgroup
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0 ]
endgroup

#connect_debug_port u_ila_0/clk [get_nets [list SYS_CLK_IBUF_BUFG ]]
connect_debug_port u_ila_0/clk [get_nets [list clk_ddr ]]

set_property port_width 1 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list clk2ddr3 ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list calib_done_dbg ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list calib_pass_dbg ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list mmu_en_dbg ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list dc_en_dbg ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list ic_en_dbg ]]



#Debug
#link_design -debug

#Implementation and bit stream generation
##Optimization and Placement ...
set_property IO_BUFFER_TYPE OBUF [get_ports {SYS_CLK}]

opt_design

place_design
write_checkpoint -force post_place.dcp
report_timing -file zap_soc_place_timing.rpt
report_drc -file drc_report_place.txt

##Physical Synthesis and Routing ...
phys_opt_design
route_design
write_checkpoint -force post_route.dcp
#report_debug_cores -file debug_cores.rpt
#report_debug_probes -file debug_probes.rpt
report_timing_summary -file zap_soc_timing_summary.rpt
report_drc -file drc_report_place_route.txt

# Generate the probes file (.ltx)
write_debug_probes -force debug_nets.ltx

##Bit Stream Generation
write_bitstream -force zap_soc_top.bit

#launch_runs impl_1 -to_step write_bitstream -jobs 4
#wait_on_run impl_1


###############################################################################
# EOF
###############################################################################
