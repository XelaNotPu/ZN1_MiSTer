#!/bin/sh
# Full Quartus build of one ZN-1 bitstream family from a staged copy of source/.
#   sh tools/build_family.sh NONE|RAIZING|FX1A [seed] [builddir]
# The family selects the external sound board compiled in (ZN_EXT_AUDIO_<FAM> macro,
# see docs/AUDIO_ARCHITECTURE.md). Output: <builddir>/output_files/ZN1.rbf + reports,
# and a summary line in <builddir>/build_summary.txt. Default builddir:
# local/build/<FAM>_s<seed> (git-ignored).
set -e
FAM=${1:?family: NONE, RAIZING or FX1A}
SEED=${2:-1}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BD=${3:-$ROOT/local/build/${FAM}_s$SEED}
QBIN=${QBIN:-/c/intelFPGA_lite/17.0/quartus/bin64}

mkdir -p "$BD"
# stage sources (keep the Quartus db for smart recompiles of the same dir)
(cd "$ROOT/source" && tar cf - --exclude=./sim --exclude=./output_files --exclude=./db \
	--exclude=./incremental_db .) | (cd "$BD" && tar xf -)
sed -i '/^set_global_assignment -name VERILOG_MACRO "ZN_EXT_AUDIO_/d; s/^set_global_assignment -name SEED .*/set_global_assignment -name SEED '"$SEED"'/' "$BD/ZN1.qsf"
if [ "$FAM" != NONE ]; then
	sed -i 's/^\(set_global_assignment -name VERILOG_MACRO "MISTER_FB=1"\)/\1\nset_global_assignment -name VERILOG_MACRO "ZN_EXT_AUDIO_'"$FAM"'=1"/' "$BD/ZN1.qsf"
fi
grep -n 'ZN_EXT_AUDIO_\|name SEED' "$BD/ZN1.qsf" || true

cd "$BD"
start=$(date +%s)
"$QBIN/quartus_sh" --flow compile ZN1 > build.log 2>&1 || { echo "BUILD FAILED ($FAM seed $SEED), see $BD/build.log"; tail -30 build.log; exit 1; }
end=$(date +%s)
{
	echo "family=$FAM seed=$SEED minutes=$(( (end - start) / 60 ))"
	grep -E "Logic utilization|Total registers|Total block memory bits|Total RAM Blocks|Total DSP Blocks" output_files/ZN1.fit.summary
} > build_summary.txt
cat build_summary.txt
