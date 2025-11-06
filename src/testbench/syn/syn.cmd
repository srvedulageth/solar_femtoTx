\rm -rf project_1.* .Xil syn.log *.dcp vivado* syn_timing.rpt; clear
vivado -mode batch -source ./syn.tcl
