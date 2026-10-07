# Taito FX-1A sound (Z80 + YM2610B + TC0140SYT) — Psychic Force

RBF: `XNZN1FXA` (built with `ZN_EXT_AUDIO_FX1A`). Board ID in the MRA: `1A`.
Module: `rtl/taito_fx1a/taito_fx1a.sv`.

## Board facts (MAME 0.289 `taito_fx1s_state`, verified by bus traces)

| | |
|---|---|
| Sound CPU | Z80 @ 16 MHz / 4 = 4 MHz (cen 625/5292 of clk_1x, exact) |
| Music chip | YM2610B @ 8 MHz (cen 625/2646, exact): 6 FM channels, ADPCM-A ×6, ADPCM-B, SSG — Psychic Force writes all of them |
| Comms | TC0140SYT: PSX `0x1FB80000` master port (mode), `0x1FB80002` master comm; Z80 `0xE200` slave port, `0xE201` slave comm; SYT → Z80 NMI (when a PSX→Z80 pair is full and NMI enabled), master mode 4 drives Z80 RESET |
| Z80 map | `0000-3FFF` ROM, `4000-7FFF` ROM bank (`0xF200` & 7) × 16 KiB, `C000-DFFF` RAM 8 KiB, `E000-E003` YM2610B, `E400`/`EE00`/`F000` ignored (MAME no-ops) |
| Interrupt | YM2610B IRQ → Z80 INT |
| ROMs | `e22-07.22` Z80 program 128 KiB (MRA index 6); `e22-01.15` ADPCM 2 MiB (index 7) — ADPCM-A and ADPCM-B both read it (MAME maps space 1 to the adpcma region) |
| Output | MAME: SSG ×0.75 to both sides, FM+ADPCM L/R ×1.0; SPU ×0.35 |

The PSX holds the Z80 in reset from 18.4 s (mode 4 = 1) to 19.4 s and then streams commands;
attract music starts at about 24 s after power-on.

## Implementation

* Z80: `tv80s` (Guy Hutchison, MIT-style licence) and YM2610B: `jt10` (Jose Tejada,
  GPL-3.0) — the flattened `tv80_auto_ss.sv` / `jt10_auto_ss.sv` from the hardware-proven
  Arcade-TaitoB core (commit `f1c08b7`), unchanged; save-state ports tied off. The jt10 copy
  carries Taito B's YM2610B six-FM-channel extension (`ym2610b` input).
* TC0140SYT: new, written from MAME `taitosnd.cpp` (BSD-3-Clause).
* Z80 program and ADPCM data come from SDRAM (the 128 KiB program would cost ~105 M10K
  in block RAM): an 8 KiB direct-mapped program cache and an 8-line × 16-byte fully
  associative ADPCM cache. On a miss the chip's clock enable is held; the fractional clock
  generators keep counting and the owed enables are issued afterwards (at most one per two
  clocks), so long-term timing is exact. Measured: 175.9 k line reads in 60 s.
* jt10's five multipliers are built from logic (`DSP_BLOCK_BALANCING` instance assignment in
  `ZN1.qsf`): the PSX core and MiSTer framework already use 110 of the 112 DSP blocks.
* Output: `(jt10 L/R + SSG × 0.75) × 9/8`, saturated. The ×9/8 (+1.0 dB) was measured: with
  MAME's SPU muted, jt10 was a steady 0.9 dB below MAME's ymfm output over 24-59 s.

## Results (details in AUDIO_VALIDATION.md)

* All **998 music register writes in 25 s are identical to MAME in order** (median offset
  0.6 µs, max 70 µs); the 4,348 timer-acknowledge writes match MAME's 4,347 per value ±1.
* Audio vs MAME (SPU muted), 24-59 s: timing aligned (lag ≤ 0.04 ms); dominant spectral
  peaks identical (pitch); log-spectrum correlation 0.92-0.95; band levels within 2 dB;
  waveform correlation 0.64-0.87 — the residual is jt10 vs ymfm synthesis detail (FM phase
  accumulation and rounding), not timing or note data.
* Quartus (seed 1): 39,628 ALMs (95 %), 487 M10K, 110/112 DSP, **all timing met**
  (worst setup slack +0.092 ns). Board: 3,691 ALMs, 29 M10K, 0 DSP.

## Not enabled yet

Super Football Champ and Magical Date are FX-1A boards too. Their MRAs still use `XNZN1`;
adding them is a table entry in `tools/gen_audio_mra.py` once they have been checked
against MAME the same way (different program/ADPCM ROMs, Magical Date has 4 MiB ADPCM).
