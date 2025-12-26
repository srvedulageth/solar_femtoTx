#!/bin/csh -f
echo Simulation Tool: Viavdo Simulator
xelab work.zap_test work.glbl -debug drivers -d XILINX -prj file_list_xilinx.prj -L unisims_ver -L secureip -s zap_test
#xsim -R zap_test
echo done

