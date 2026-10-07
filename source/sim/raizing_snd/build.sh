#!/bin/sh
# Build the Raizing sound-board Verilator testbench (fx68k + ymf271).
# Env: OSS (oss-cad-suite dir), GXX_BIN (dir containing g++). Run from source/.
set -e
: "${OSS:?set OSS to the oss-cad-suite directory}"
: "${GXX_BIN:?set GXX_BIN to the directory containing g++}"
export VERILATOR_ROOT="$OSS/share/verilator"
export PATH="$GXX_BIN:$OSS/bin:$OSS/lib:$PATH"
OBJ=sim/raizing_snd/obj
rm -rf "$OBJ"
verilator_bin --cc --top-module raizing_snd $VFLAGS -Wno-fatal -Wno-WIDTH -Wno-lint -Wno-style -Wno-BLKANDNBLK --no-assert -O3 \
	--x-initial 0 --x-assign 0 --Mdir "$OBJ" \
	rtl/fx68k/fx68k.sv rtl/fx68k/fx68kAlu.sv rtl/fx68k/uaddrPla.sv \
	rtl/raizing_snd/ymf_regram.sv rtl/raizing_snd/ymf271.sv rtl/raizing_snd/raizing_snd.sv
INC="$VERILATOR_ROOT/include"
g++ -O2 -std=c++20 -I"$OBJ" -I"$INC" -I"$INC/vltstd" -DVL_TIME_CONTEXT \
	sim/raizing_snd/tb_raizing_snd.cpp "$OBJ"/*.cpp "$INC/verilated.cpp" "$INC/verilated_threads.cpp" \
	-o sim/raizing_snd/tb_raizing_snd.exe -pthread -static-libstdc++ -static-libgcc
echo built sim/raizing_snd/tb_raizing_snd.exe
