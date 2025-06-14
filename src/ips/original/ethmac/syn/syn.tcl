#
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

# We targeting an Artix-7 speed grade -3 FPGA for synthesis.
#create_project project_1 -part xc7a75tcsg324-3
create_project project_1 -part xc7a100tcsg324-1

# Add RTL files and includes for synthesis.
add_files -scan_for_includes {
../rtl/verilog/ethmac_defines.v \
../rtl/verilog/timescale.v \
../rtl/verilog/ethmac.v \
../rtl/verilog/eth_clockgen.v \
../rtl/verilog/eth_cop.v \
../rtl/verilog/eth_crc.v \
../rtl/verilog/xilinx_dist_ram_16x32.v \
../rtl/verilog/eth_fifo.v \
../rtl/verilog/eth_maccontrol.v \
../rtl/verilog/eth_macstatus.v \
../rtl/verilog/eth_miim.v \
../rtl/verilog/eth_outputcontrol.v \
../rtl/verilog/eth_random.v \
../rtl/verilog/eth_receivecontrol.v \
../rtl/verilog/eth_registers.v \
../rtl/verilog/eth_rxaddrcheck.v \
../rtl/verilog/eth_rxcounters.v \
../rtl/verilog/eth_register.v \
../rtl/verilog/eth_rxethmac.v \
../rtl/verilog/eth_rxstatem.v \
../rtl/verilog/eth_spram_256x32.v \
../rtl/verilog/eth_shiftreg.v \
../rtl/verilog/eth_transmitcontrol.v \
../rtl/verilog/eth_txcounters.v \
../rtl/verilog/eth_txethmac.v \
../rtl/verilog/eth_txstatem.v \
../rtl/verilog/eth_wishbone.v \
}

# Create a sources_1 fileset.
update_compile_order \
-fileset sources_1

# Add XDC file into the mix, into constrs_1.
#add_files -fileset constrs_1 -norecurse ../../src/syn/syn.xdc

#
# Synthesize the design with Vivado high performance defaults, as seen in
# the GUI.
#
synth_design \
-top ethmac \
-part xc7a100tcsg324-1 \
-gated_clock_conversion auto \
-directive PerformanceOptimized \
-retiming \
-keep_equivalent_registers \
-resource_sharing off \
-no_lc \
-shreg_min_size 5 \
-mode out_of_context

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
-file syn_timing.rpt

#
# Generate a DCP file that can be loaded for further runs to integrate
# the design into an SOC.
#
write_checkpoint ethmac.dcp

###############################################################################
# EOF
###############################################################################
