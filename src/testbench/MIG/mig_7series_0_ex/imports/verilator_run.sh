!#/bin/sh -f
verilator --trace-fst --binary --timing --exe --build -Wno-PINMISSING -Wno-CMPCONST -Wno-WIDTHEXPAND -j $(nproc) -f file_list --top-module zap_test
