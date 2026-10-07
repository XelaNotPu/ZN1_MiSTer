# Simulation and reference tools (external sound boards)

Nothing here is needed to build the core. No ROM data is stored in the repository;
point the tools at your own MAME ROM set.

| Path | What it is |
|---|---|
| `mame/bbtrace.lua` | MAME 0.289 autoboot script. Logs PSX writes to `0x1FB00000/4`, bank selects, 68000 latch reads and IRQ2 vector fetches, every YMF271 write (and status reads), RAM/ROM/sample address ranges. Env: `BB_OUT` (dir, trailing `/`), `BB_SECS`, `BB_COIN`, `BB_START` (seconds). |
| `mame/regions.lua` | Dumps MAME's logical `audiocpu` and `ymf` regions (to check MRA byte order). |
| `model/ymf_mame.h` | Standalone port of MAME's `ymf271.cpp` (BSD-3-Clause, R. Belmont et al.) — golden reference. |
| `model/ymf_fx.h` | Fixed-point model with the same structure as `rtl/raizing_snd/ymf271.sv`. |
| `model/gen_tables.cpp` | Generates `ymf_tables.h` and the `rtl/raizing_snd/ymf_*.hex` ROM images from MAME's own expressions. |
| `model/replay.cpp` | Replays a `ymf_writes.txt` log through either model and writes a WAV (+ raw 32-bit mix). |
| `ymf271/` | Verilator bench: YMF271 RTL alone, driven by a register log, sample-aligned with `replay`. |
| `raizing_snd/` | Verilator bench: whole sound board (fx68k running the real sound program) with PSX commands injected from `events.txt`. |

## Typical flow (Windows, Git Bash)

```sh
# 1. capture a reference (150 s of attract, coin at 95 s, start at 97 s)
BB_OUT=C:/tmp/run/ BB_SECS=150 BB_COIN=95 BB_START=97 \
  mame brvblade -video none -nothrottle -wavwrite C:/tmp/run/ref.wav \
  -autoboot_script source/sim/mame/bbtrace.lua

# 2. models (g++ from MinGW)
cd source/sim/model && g++ -O2 -std=c++20 gen_tables.cpp -o gen_tables && ./gen_tables ../../rtl/raizing_snd
g++ -O2 -std=c++20 replay.cpp -o replay
./replay mame C:/tmp/run/ymf_writes.txt ra-bbl_rom2.336 mame.wav
./replay fx   C:/tmp/run/ymf_writes.txt ra-bbl_rom2.336 fx.wav

# 3. RTL benches (from source/; OSS = oss-cad-suite, GXX_BIN = MinGW bin)
sh sim/ymf271/build.sh
sim/ymf271/tb_ymf271 C:/tmp/run/ymf_writes.txt ra-bbl_rom2.336 hdl.raw 30 24
sh sim/raizing_snd/build.sh
sim/raizing_snd/tb_raizing_snd C:/tmp/run/events.txt audiocpu.bin ra-bbl_rom2.336 sys 30 16
```

`audiocpu.bin` is the 1 MiB interleave of `spu0u049.bin` (even bytes) and
`spu1u412.bin` (odd bytes), exactly what MRA index 6 sends.

## All board families (zn_ext_audio)

| Path | What it is |
|---|---|
| `mame/fx1atrace.lua` | Taito FX-1A trace: PSX/TC0140SYT traffic, Z80 writes, every YM2610B register write (`ym_writes.txt`). Env `TR_OUT`, `TR_SECS`, `TR_COIN`, `TR_START`. |
| `ext_audio/` | Verilator bench for `rtl/zn_ext_audio.sv` with any family compiled in (`sh sim/ext_audio/build.sh RAIZING` or `FX1A`). Replays the PSX bus events of a trace, serves SDRAM lines with a set latency, logs device register writes and audio. |
| `tools/audio_compare.py` | Per-window lag, waveform correlation and level of a simulation output against a MAME `-wavwrite` file. |

To get MAME audio without the PSX SPU (the board alone), put
`<mixer><device_volume device=":spu" gain="0.0"/></mixer>` in `cfg/<set>.cfg` and run MAME
with `-cfg_directory cfg` (not `-sound none`, which silences `-wavwrite` too).

Toolchain used: Verilator 5.050 and g++ 16 from MSYS2 UCRT64 (`/c/msys64/ucrt64`), Python
with numpy/scipy, MAME 0.289. Run the benches from `source/` (fx68k and the YMF271 tables
are read with relative paths).
