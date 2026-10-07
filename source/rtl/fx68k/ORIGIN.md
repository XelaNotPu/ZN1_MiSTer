# Imported FX68K

Source: https://github.com/ijor/fx68k
Revision: `0602ee4627b10f301298f2673d826cdd6baa9327`

Imported files are unchanged. Copyright Jorge Cwik; GPL-3.0-or-later as
stated in `fx68k.txt`; full GPLv3 text in `LICENSE`.

Used as the 68000 of the Raizing/Eighting ZN-1 sound board
(`rtl/raizing_snd/raizing_snd.sv`). `microrom.mem` and `nanorom.mem` from the
same revision live in the project root (`source/`) because the unchanged CPU
reads those file names with `$readmemb`; they are the CPU's microcode, not
game ROM data. Simulate from `source/` so `$readmemb` finds them.
