# Raizing / Eighting sound board (68000 + YMF271) — Brave Blade, Bloody Roar

RBF: `XNZN1RZ` (built with `ZN_EXT_AUDIO_RAIZING`). Board ID in the MRA: `10`.

## Origin of the implementation

The board was ported from the user's hardware-proven Brave Blade fork
(`../ZN1_MiSTer`, commit `e73fa72`, release `BraveBlade_20261002.rbf`). Taken unchanged:

| File | From the fork | Notes |
|---|---|---|
| `rtl/raizing_snd/raizing_snd.sv` | unchanged | board: fx68k, clock enables, 16 KiB RAM, 4 KiB program cache, latch + IRQ2, YMF271, SDRAM line port |
| `rtl/raizing_snd/ymf271.sv`, `ymf_regram.sv`, `ymf_*.hex` | unchanged | YMF271 engine (bit-exact vs a MAME port over 150 s) |
| `rtl/fx68k/*`, `microrom.mem`, `nanorom.mem` | unchanged | FX68K by Jorge Cwik, GPL-3.0 (see `rtl/fx68k/ORIGIN.md`) |
| `rtl/sdram.sv` | 128-bit channel-3 line read + channel-3 anti-starvation | |
| `sim/model/*`, `sim/ymf271/*`, `sim/raizing_snd/*`, `sim/mame/bbtrace.lua` | unchanged | reference models and benches |
| `sys/ascal.vhd`, `rtl/pause_overlay.v`, `ZN1.sdc`, CRT loading-screen sync in `ZN1.sv` | unchanged | timing-closure work and the CRT loading-screen fix from the fork (hardware-tested there) |

Generalized (new in this repository):

* The board sits behind `rtl/zn_ext_audio.sv`, which is shared by all board families: it
  selects the board compiled into the RBF, gates it with the MRA's board ID and the
  presence of both sound ROMs, owns the SDRAM line port and does the final mix.
* `memorymux.vhd` no longer has Raizing-specific latch/IRQ strobes; it forwards the active
  board's PSX window over a generic bus (`ext_snd_*`, reads and writes). For Raizing the
  window is writes to `0x1FB00000-0x1FB00007`, at the same place in the decode chain as
  the fork's hardware-proven decode.
* Board selection comes from the MRA (index 1 byte 1 = `10`), not from the platform byte
  or ROM names.
* Brave-Blade-specific items: none remained in RTL. The fork's only game-specific facts
  were the ROM file names and the bank-2 SDRAM placement, both now in the MRA generator.
* Debug/hack behaviour not generalized: the fork's JTAG probes stay behind
  `ZN_JTAG_DEBUG` (off), its `snd_dbg` wiring became the generic overlay words.

## Board facts (MAME 0.289 `raizing_zn_state`, verified by bus traces)

* 68000 @ 12.000 MHz (phi enables 1875/2646 of clk_1x, exact); YMF271 @ 16.9344 MHz
  (clk_1x / 2, exact, 44.1 kHz output).
* PSX `SH 0x1FB00000` → 8-bit latch; `SH 0x1FB00004` → 68000 IRQ2 (HOLD_LINE, cleared by
  the acknowledge). 68000 reads the latch at `0x180009`.
* 68000 map: ROM `0x000000-0x07FFFF`, RAM `0x080000-0x0FFFFF` (16 KiB implemented,
  mirrored), YMF271 `0x100000-0x10001F` (low byte lane).
* Measured RAM use: Brave Blade and Bloody Roar both `0x080000-0x083FEE`.
* Sample ROM: 4 MiB in both games; both touch the whole ROM.

| | Brave Blade (`brvblade` + u/j/a) | Bloody Roar (`beastrzr`, `beastrzra`, `bldyroar`) |
|---|---|---|
| Program | `spu0u049.bin` even + `spu1u412.bin` odd, 2 × 512 KiB (only the lower 512 KiB is mapped) | `b.roar_u042.u042` even + `b.roar_u046.u046` odd, 2 × 256 KiB |
| Samples | `ra-bbl_rom2.336` 4 MiB | `8ing_ra-b.roar_rom-3.u0326` 4 MiB |
| Banked ROM in use | banks 0-1 | banks 0-1 (bank writes seen: 0, 1 only) |
| Status registers polled | 0 | 0 and 1 (end flags of PCB groups 4-11; implemented in the fork) |
| Board revision | PS9805 | RA9701 SUB — same CPU/clock/map in MAME |

No register constants of Brave Blade are assumed for Bloody Roar: the RTL has none; the
differences are entirely in the ROM layout, which the MRA expresses.

## SDRAM and bandwidth

`0x1800000` program (MRA index 6), `0x1C00000` samples (index 7): banked-ROM bank 2,
which neither game selects (MRA index 3 was shortened to 16 MiB so the downloads do not
overlap). The board reads 16-byte lines over SDRAM channel 3 (one outstanding request,
YMF first, 68000 cache second); a channel-3 request waiting ≥ 64 SDRAM clocks is served
next. Measured in the Bloody Roar simulation: 2.66 M line reads in 150 s = 17.8 k/s
average (~285 KB/s, 0.4 % of the SDRAM's peak), bursts during song starts.

## Mix

`out = sat(SPU × 45/128 + YMF × 2)` → MAME's 0.35 : 1.0 balance with +6 dB overall
(the fork's hardware-tested level; Brave Blade's loudest passages ≈ −3 dBFS).

## Results (details in AUDIO_VALIDATION.md)

* Bloody Roar, 150 s attract + coin + start, real sound program on the FPGA 68000 through
  `zn_ext_audio`: **161,128 YMF271 writes, identical count to MAME**; per PSX command the
  write counts match (one ±9 boundary shift); first 33,247 writes identical in order.
* Brave Blade: the fork's verification (bit-exact YMF271 over 150 s, write stream vs MAME)
  applies unchanged; re-run through the generic wrapper in AUDIO_VALIDATION.md.
* Quartus (seed 1): 41,051 ALMs (98 %), 517 M10K, 111/112 DSP; all core clocks meet
  timing, HDMI scaler clock −0.076 ns (the shipped fork release: −0.145 ns).

## Limitations

* Save states do not include the sound board.
* Bloody Roar 2 is not enabled: its banked ROM fills all of banks 0-2, leaving no SDRAM
  for the sound ROMs on a 32 MiB module.
