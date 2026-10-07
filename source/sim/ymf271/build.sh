#!/bin/sh
# Build the ymf271 Verilator testbench (Windows: oss-cad-suite + MinGW g++).
# Env: OSS (oss-cad-suite dir), GXX_BIN (dir containing g++). Run from source/.
set -e
: "${OSS:?set OSS to the oss-cad-suite directory}"
: "${GXX_BIN:?set GXX_BIN to the directory containing g++}"
export VERILATOR_ROOT="$OSS/share/verilator"
export PATH="$GXX_BIN:$OSS/bin:$OSS/lib:$PATH"
OBJ=sim/ymf271/obj
rm -rf "$OBJ"
verilator_bin --cc --top-module ymf271 $VFLAGS -Wno-fatal -Wno-WIDTH -O3 --x-initial 0 --x-assign 0 \
	-GHEXDIR='"rtl/raizing_snd/"' --Mdir "$OBJ" rtl/raizing_snd/ymf_regram.sv rtl/raizing_snd/ymf271.sv
INC="$VERILATOR_ROOT/include"
g++ -O2 -std=c++20 -I"$OBJ" -I"$INC" -I"$INC/vltstd" -DVL_TIME_CONTEXT \
	sim/ymf271/tb_ymf271.cpp "$OBJ"/*.cpp "$INC/verilated.cpp" "$INC/verilated_threads.cpp" \
	-o sim/ymf271/tb_ymf271.exe -pthread -static-libstdc++ -static-libgcc
echo built sim/ymf271/tb_ymf271.exe
