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

# We targeting an Artix-7 speed grade -3 FPGA for synthesis.
#create_project project_1 -part xc7a75tcsg324-3
create_project project_1 -part xc7a100tcsg324-1

# Add RTL files and includes for synthesis.
add_files -scan_for_includes {
  ../../rtl/verilog/timescale.v \
  ../../rtl/verilog/uart_debug_if.v \
  ../../rtl/verilog/uart_defines.v \
  ../../rtl/verilog/uart_receiver.v \
  ../../rtl/verilog/uart_regs.v \
  ../../rtl/verilog/raminfr.v \
  ../../rtl/verilog/uart_rfifo.v \
  ../../rtl/verilog/uart_sync_flops.v \
  ../../rtl/verilog/uart_tfifo.v \
  ../../rtl/verilog/uart_transmitter.v \
  ../../rtl/verilog/uart_wb.v \
  ../../rtl/verilog/uart_top.v \
}

# Create a sources_1 fileset.
update_compile_order -fileset sources_1

# Add XDC file into the mix, into constrs_1.
add_files -fileset constrs_1 -norecurse ./syn.xdc

#
# Synthesize the design with Vivado high performance defaults, as seen in
# the GUI.
#
synth_design \
-top uart_top \
-part xc7a100tcsg324-1 \
-gated_clock_conversion auto \
-directive PerformanceOptimized \
-retiming \
-keep_equivalent_registers \
-resource_sharing off \
-no_lc \
-shreg_min_size 5 \
-verilog_define SYNTHESIS=1 \
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
write_checkpoint uart.dcp

###############################################################################
# EOF
###############################################################################
