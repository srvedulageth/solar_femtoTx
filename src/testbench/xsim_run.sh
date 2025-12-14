#!/bin/csh -f
echo Simulation Tool: Viavdo Simulator
xelab work.zap_test -d XILINX -prj file_list_xilinx.prj -s zap_test
xsim -R zap_test
echo done

