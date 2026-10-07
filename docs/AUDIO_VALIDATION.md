# External audio — validation record

All references are MAME 0.289 runs of the real ROM sets, captured with the trace scripts in
`source/sim/mame/` (see `source/sim/README.md`). Large captures, WAVs and ROM streams are not
part of the repository.

## Raizing (`XNZN1RZ`)

| Check | Result |
|---|---|
| Bloody Roar (`beastrzr`), 150 s (boot, attract, coin 95 s, start 97 s): real sound program on fx68k through `zn_ext_audio`, PSX commands at MAME's times, 24-clock SDRAM latency | **161,128 YMF271 writes = MAME 161,128**; writes after each of the 14 PSX commands equal per command (commands 10/11: 2,422/2,608 vs 2,431/2,599, a 9-write boundary shift); first 33,247 writes identical in content and order, ≤ 0.52 ms offset |
| Bloody Roar sound RAM / program / sample use | RAM `0x080000-0x083FEE` (= Brave Blade's), program to `0x02979A`, samples `0x001353-0x3FEA41` |
| Brave Blade through the generic wrapper (15 s, attract music command `08` at 11.1 s) | 13,972 YMF271 writes vs MAME 13,974; per command 1,402/964/10,430 vs 1,402/964/10,432; first 4,123 writes identical in order; the song starts one timer tick (7.98 ms) after MAME, exactly as in the hardware-tested Brave Blade fork |
| Brave Blade YMF271 engine | bit-exact vs the MAME-port model over 150 s (fork verification, RTL unchanged) |
| MRAs (7: Brave Blade World/USA/Japan/Asia, Bloody Roar Japan, Beastorizer USA ×2) | all ROM streams built and CRC-checked; index 6/7 streams identical to the fork's hardware-proven Brave Blade MRA |

## Taito FX-1A (`XNZN1FXA`)

| Check | Result |
|---|---|
| Psychic Force, 25 s (boot, SYT reset at 18.4 s, attract music from ~24 s) | 998 music register writes **identical to MAME in order** (median 0.6 µs, max 70 µs offset); 4,348 timer-ack writes vs MAME 4,347 |
| Audio vs MAME with the SPU muted, 60 s | lag ≤ 0.04 ms; level ≈ 0 dB after a +1.0 dB output correction; spectral peaks identical; log-spectrum correlation 0.92-0.95; per-band levels within 2 dB; waveform correlation 0.64-0.87 (jt10 vs MAME's ymfm synthesis detail) |
| SDRAM traffic | 175.9 k line reads in 60 s (Z80 program cache + ADPCM cache) |
| MRAs (3: 2.4O, 2.4J, EX 2.0J) | CRC-checked |

### Hardware finding (fixed): PSX stores

The first hardware test of Psychic Force had sound effects but no music; the debug overlay
showed the board running but **0 PSX comm writes**. The PSX CPU core issues every store
word-aligned (`cpu.vhd`: `EXEMemAddr(31:2) & "00"`) with the byte offset only in the write
mask, so the game's `sh` to `0x1FB80002` (TC0140SYT master comm) reached the board as a write
to `0x1FB80000` (master port). Fix: `zn_ext_audio` rebuilds the byte address of writes from
the lowest enabled lane, for every board; the benches now drive stores word-aligned like the
CPU (previous wrapper: 0 comm writes, as on hardware; fixed: 16 comm writes and the
MAME-matched register stream; Brave Blade's device log unchanged).

## Hardware results

| Game (MRA) | Result |
|---|---|
| Brave Blade (World) | music and SFX ✔ |
| Bloody Roar (Japan, Jun 21 1997) | music and SFX ✔ |
| Psychic Force (Ver 2.4O) | music and SFX ✔ |
| Dead or Alive ++ (`XNZN1`, regression) | unchanged ✔ |

## Fits (Quartus 17.0 Lite, 5CSEBA6)

| RBF | ALMs | M10K | DSP | Timing |
|---|---|---|---|---|
| `XNZN1RZ_20261006` (seed 1) | 41,051 (98 %) | 517 | 111 | core clocks met; HDMI scaler clock −0.076 ns (the shipped Brave Blade fork: −0.145 ns) |
| `XNZN1FXA_20261006` (seed 1) | 39,598 (94 %) | 487 | 110 | core clocks met; HDMI scaler clock −0.085 ns |

Build: `sh tools/build_family.sh RAIZING 1` / `sh tools/build_family.sh FX1A 1` (stages
`source/` with the `ZN_EXT_AUDIO_*` macro set and runs the Quartus flow).

## Debug overlay

OSD → Debug → **Boot Debug Overlay = On** shows four rows of 32 yellow/grey bit cells (MSB
left) under the existing bars:

| Row | Raizing | FX-1A |
|---|---|---|
| 1 | [31:16] IRQ2s taken, [15:0] latch reads by the 68000 | [31:16] PSX comm writes, [15:0] Z80 comm reads |
| 2 | [31:16] YMF271 writes, [15:0] SDRAM line fetches | [31:16] YM2610B writes, [15:0] SDRAM line fetches |
| 3 | [31:16] YMF271 sample overruns (should stay 0), [15:0] mixer clip events | [15:0] mixer clip events |
| 4 | [31:24] board ID `0x10`, [23] enabled, [22] program, [21] samples loaded, [15:8] heartbeat (changes every ~23 ms) | same with `0x1A` |
