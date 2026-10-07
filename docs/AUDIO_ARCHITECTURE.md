# ZN-1 external audio boards — architecture

All facts below were checked against MAME 0.289 source (`src/mame/sony/zn.cpp`,
`src/mame/shared/taitosnd.cpp`, `src/devices/sound/{ymf271,ymopn}.cpp`) **and** against bus
traces captured from MAME 0.289 running the real ROM sets (`source/sim/mame/*trace.lua`, see
`AUDIO_VALIDATION.md`).

The ZN-1 motherboard's PSX SPU produces the sound effects in every game; the music of some
games comes from a separate sound system on the game ROM board. This release adds two of
those board families:

| Family | MAME class / machine | Sound CPU | Music device(s) | Games |
|---|---|---|---|---|
| Raizing / Eighting | `raizing_zn_state` / `coh1002e` | MC68000 @ 12 MHz | YMF271-F "OPX" @ 16.9344 MHz | Brave Blade (World/USA/Japan/Asia), Bloody Roar / Beastorizer |
| Taito FX-1A | `taito_fx1s_state` / `coh1000ta` | Z80 @ 4 MHz | YM2610B @ 8 MHz, TC0140SYT comms | Psychic Force (2.4O, 2.4J, EX 2.0J) |

The Taito FX-1B games (Ray Storm, G-Darius: MN10200 + ZOOM ZSG-2 + TMS57002) are not part of
this release.

## Per-game table

| Game | MAME set | Sound ROMs (MAME region: file) | Main-CPU ↔ sound |
|---|---|---|---|
| Brave Blade | `brvblade` (+`u`, `j`, `a`) | `audiocpu` 1 MiB: `spu0u049.bin` (even), `spu1u412.bin` (odd); `ymf` 4 MiB: `ra-bbl_rom2.336` | PSX `0x1FB00000` 8-bit latch, `0x1FB00004` → 68000 IRQ2 |
| Bloody Roar / Beastorizer | `beastrzr` (+`beastrzra`, `bldyroar`) | `audiocpu` 512 KiB: `b.roar_u042.u042` (even), `b.roar_u046.u046` (odd); `ymf` 4 MiB: `8ing_ra-b.roar_rom-3.u0326` | identical to Brave Blade |
| Psychic Force | `psyforce` (+`psyforcej`, `psyforcex`) | `audiocpu` 128 KiB: `e22-07.22` (bank 0x4000-0x7FFF = 16 KiB × 8); `ym2610b:adpcma` 2 MiB: `e22-01.15` (also ADPCM-B) | TC0140SYT: PSX `0x1FB80000` port / `0x1FB80002` comm; Z80 `0xE200/0xE201`; the SYT drives the Z80 NMI and reset |

Measured in MAME (bus traces):

| | Raizing (beastrzr, 150 s) | FX-1A (psyforce, 120 s) |
|---|---|---|
| Sound RAM used | `0x080000-0x083FEE` (16 KiB) | `0xC000-0xDFFF` (8 KiB) |
| Program fetched up to | `0x02979A` | `0x3A19` fixed + bank data to `0x1A589` |
| Sample ROM touched | whole 4 MiB | ADPCM via registers |
| PSX → board traffic | 14 commands | 36 port/comm writes (the PSX never reads) |
| Device register traffic | 161 k YMF271 writes | 118 k YM2610B writes |

## Clocks

`clk_1x` = 33.8688 MHz (PSX, 768 × 44.1 kHz). Every sound clock is an exact rational of it,
so all clock enables are exact fractional accumulators (0 ppm).

| Device | Clock | FPGA clock / CE | Ratio (CE per clk_1x) |
|---|---|---|---|
| 68000 (Raizing) | 12 MHz | phi1/phi2 enables | 1875 / 2646 |
| YMF271 | 16.9344 MHz (44.1 kHz out) | clk_1x / 2 | 1 / 2 |
| Z80 (FX-1A) | 4 MHz | cen | 625 / 5292 |
| YM2610B | 8 MHz | cen | 625 / 2646 |

## SDRAM layout

The sound ROMs go to two windows in banked-ROM space that these games never map (their bank
registers never select bank 2):

| SDRAM | Content | MRA index |
|---|---|---|
| `0x1800000-0x18FFFFF` | sound CPU program (68000: 1 MiB interleave; Z80: 128 KiB) | 6 |
| `0x1C00000-0x1FFFFFF` | sample ROM (YMF271 4 MiB / YM2610B ADPCM 2 MiB) | 7 |

The board reads them through SDRAM channel 3 with 128-bit line reads (`rtl/sdram.sv`, from
the Brave Blade fork) and small line caches.

## Board selection (MRA, not RTL game checks)

MRA index 1 is a 16-bit download. Byte 0 stays the existing **platform** ID; the new byte 1
is the **audio board** ID:

| Byte 1 | Audio board |
|---|---|
| `00` / absent | none (PSX SPU only — every other game, unchanged MRAs) |
| `10` | Raizing 68000 + YMF271 |
| `1A` | Taito FX-1A Z80 + YM2610B + TC0140SYT |

The board runs only when the ID matches the board compiled into the RBF **and** MRA indices 6
and 7 were downloaded, so an MRA can never start a sound CPU on an empty program.

## PSX bus window

`memorymux.vhd` forwards the board's address window as a generic `ext_snd_*` bus (strobe,
24-bit address, 32-bit data on CPU lanes, byte mask). The PSX CPU core issues **stores
word-aligned** and gives the byte offset only in the mask, so `zn_ext_audio.sv` rebuilds the
byte address of writes from the lowest enabled lane before a board decodes it (an `sh` to
`0x1FB80002` arrives as `0x1FB80000` + mask `1100`).

## Mix

MAME speaker routes: SPU 0.35 + music board 1.0. `zn_ext_audio.sv` mixes
`SPU × 45/128 + board × 2` with saturation (shift-adds only: the PSX core and the framework
use 110 of the 112 DSP blocks). Without an active board the SPU passes through bit-exactly.

## One bitstream per board family

Base core ~35.8 k ALMs; Raizing board 4.4 k, FX-1A board 3.8 k (of 41.9 k on the
DE10-Nano). Both boards together do not fit, so one source tree builds one bitstream per
family, selected by a Verilog macro (`ZN_EXT_AUDIO_RAIZING` / `ZN_EXT_AUDIO_FX1A`;
`tools/build_family.sh`):

| RBF (`<rbf>` name) | External audio | Used by |
|---|---|---|
| `XNZN1` | none | every game without a music board (unchanged) |
| `XNZN1RZ` | Raizing | Brave Blade, Bloody Roar / Beastorizer |
| `XNZN1FXA` | Taito FX-1A | Psychic Force |

No family name starts with `XNZN1_`, so MiSTer's `<rbf>_*.rbf` lookup for `XNZN1` cannot pick
a family bitstream by accident.

## Detailed documents

* `AUDIO_RAIZING_YMF271.md` — Brave Blade reuse, generalization, Bloody Roar.
* `AUDIO_TAITO_FX1A.md` — Z80 / YM2610B / TC0140SYT.
* `AUDIO_VALIDATION.md` — MAME traces, simulation comparisons, hardware results.
* `MRA_GENERATION.md` — how the MRAs are generated and checked.
