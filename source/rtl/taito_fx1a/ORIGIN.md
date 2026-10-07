# Imported sound cores (Taito FX-1A board)

| File | Origin | Licence |
|---|---|---|
| `jt10_auto_ss.sv` | JT12/JT10 by Jose Tejada (jotego), flattened auto-save-state variant as used by Arcade-TaitoF2_MiSTer and Arcade-TaitoB_MiSTer (`../Arcade-TaitoB_MiSTer/rtl/jt10_auto_ss.sv`, commit `f1c08b7`, which adds the `ym2610b` six-FM-channel input) | GPL-3.0-or-later, `LICENSE.jt12` |
| `tv80_auto_ss.sv` | TV80 by Guy Hutchison (based on T80 by Daniel Wallner), same flattened variant and commit | MIT-style, `LICENSE.tv80` |

Both files are unchanged; the save-state ports are tied off in `taito_fx1a.sv`.
`taito_fx1a.sv` (board, TC0140SYT, caches) is new, written from MAME 0.289
`src/mame/sony/zn.cpp` and `src/mame/shared/taitosnd.cpp` (BSD-3-Clause).
