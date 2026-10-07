# MRA generation and validation

The MRAs in `source/mra/` (and their copies in `release/_Arcade/` and
`release/_Arcade/_alternatives/_<Game>/`) are hand-written per set. The external sound
boards are added by a generator so that every primary and every alternate of a game gets
the same layout:

```sh
python tools/gen_audio_mra.py            # rewrite (idempotent)
python tools/gen_audio_mra.py --check    # exit 1 if anything is out of date
```

For each MRA whose `<setname>` is in its `SETS` table (from MAME 0.289 zn.cpp) it sets:

* `<rbf>` → the family bitstream: `XNZN1RZ`, `XNZN1FXA`;
* index 1 → `<platform> <board>`: byte 1 is the audio board ID (`10`, `1A`, `1B`);
* index 3 → drops the trailing 8 MiB zero fill of banked-ROM bank 2 where present
  (the sound ROMs live there; the games never select it);
* index 6 → sound CPU program (SDRAM `0x1800000`), index 7 → sample ROM (`0x1C00000`).

It keeps the rest of each file (comments, DIP switches, EEPROM preloads) and its CRLF line
endings. To add a game: add its sets to `SETS` and run the generator.

Sets covered now:

| Family | Sets (primary in **bold**) |
|---|---|
| Raizing `XNZN1RZ` | **brvblade**, brvbladeu, brvbladej, brvbladea, **bldyroar**, beastrzr, beastrzra |
| FX-1A `XNZN1FXA` | **psyforce**, psyforcej, psyforcex |

## Validation against a ROM folder

```sh
python tools/mra_tool.py check "C:/roms/mame;C:/roms/extra" source/mra/*.mra
python tools/mra_tool.py stream "C:/roms/mame" "source/mra/<game>.mra" 7 out.bin
```

`check` builds every `<rom index>` stream exactly as the MiSTer loader would (parts by CRC
then name, inline hex, `repeat`, `<interleave>` with `map`), verifies CRCs and prints the
stream sizes. `stream` writes one index's bytes (used to feed the simulation benches).
Several folders can be given separated by `;` (Windows paths).
