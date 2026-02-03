#!/bin/csh -f
echo Simulation Tool: Viavdo Simulator
xelab work.zap_test work.glbl -debug drivers -d XILINX -d DDR3_CONTROLLER -prj file_list_ddr3.prj -L unisims_ver -L secureip -s zap_test
#xelab work.zap_test -debug drivers -d XILINX -d DDR3_CONTROLLER -prj file_list_ddr3.prj -L unisims_ver -L secureip -s zap_test
#xsim -R zap_test
echo done

