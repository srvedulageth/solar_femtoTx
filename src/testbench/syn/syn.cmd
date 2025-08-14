\rm -rf project_1.* .Xil syn.log zap.dcp vivado* syn_timing.rpt; clear 
vivado -mode batch -source ./syn.tcl | tee syn.log
