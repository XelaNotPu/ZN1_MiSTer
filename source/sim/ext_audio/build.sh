#!/bin/sh
# Build the zn_ext_audio Verilator bench for one board family. Run from source/.
#   sh sim/ext_audio/build.sh RAIZING|FX1A
# Env: VROOT (Verilator share dir, default msys64 ucrt64), GXX_BIN (dir with g++/verilator_bin)
set -e
FAM=${1:?family: RAIZING or FX1A}
GXX_BIN=${GXX_BIN:-/c/msys64/ucrt64/bin}
export VERILATOR_ROOT=${VROOT:-/c/msys64/ucrt64/share/verilator}
export PATH="$GXX_BIN:$PATH"
OBJ=sim/ext_audio/obj_$FAM
rm -rf "$OBJ"
case $FAM in
RAIZING) SRC="rtl/fx68k/fx68k.sv rtl/fx68k/fx68kAlu.sv rtl/fx68k/uaddrPla.sv
              rtl/raizing_snd/ymf_regram.sv rtl/raizing_snd/ymf271.sv rtl/raizing_snd/raizing_snd.sv" ;;
FX1A)    SRC=$(cat sim/ext_audio/fx1a_files.txt) ;;
esac
verilator_bin --cc --top-module zn_ext_audio -DZN_EXT_AUDIO_$FAM $VFLAGS -Wno-fatal -Wno-WIDTH -Wno-lint \
	-Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN --no-assert -O3 --x-initial 0 --x-assign 0 --Mdir "$OBJ" \
	-Irtl $SRC rtl/zn_ext_audio.sv
INC="$VERILATOR_ROOT/include"
g++ -O2 -std=c++20 -I"$OBJ" -I"$INC" -I"$INC/vltstd" -DVL_TIME_CONTEXT \
	sim/ext_audio/tb_ext_audio.cpp "$OBJ"/*.cpp "$INC/verilated.cpp" "$INC/verilated_threads.cpp" \
	-o sim/ext_audio/tb_$FAM.exe -pthread -static-libstdc++ -static-libgcc
echo built sim/ext_audio/tb_$FAM.exe
