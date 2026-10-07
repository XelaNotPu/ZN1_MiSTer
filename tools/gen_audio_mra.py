#!/usr/bin/env python3
"""Add / refresh the external sound board in the ZN-1 MRAs (idempotent).

For every MRA whose <setname> is in SETS below, this rewrites (text-level, keeping the
hand-written comments of the rest of the file):
  * <rbf>                 -> the family bitstream (XNZN1RZ / XNZN1FXA)
  * index 1               -> "<platform> <board>" (byte 1 = audio board ID)
  * index 3               -> drops a trailing zero fill that would cover the sound-ROM
                             window (SDRAM 0x1800000+) - bank 2 is never selected
  * index 6 / index 7     -> sound CPU program / sample ROM (from MAME 0.289 zn.cpp)
Both source/mra/ and release/_Arcade/ (primaries and _alternatives/_<Game>/) are updated
wherever a file with the same name exists. Run from the repository root:
  python tools/gen_audio_mra.py            (rewrite)
  python tools/gen_audio_mra.py --check    (exit 1 if anything would change)
"""
import os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LF, CRLF = '\n', '\r\n'

FAMILY = {
    'RZ':  dict(rbf='XNZN1RZ',  board='10', title='Raizing/Eighting sound board (68000 + YMF271)'),
    'FXA': dict(rbf='XNZN1FXA', board='1A', title='Taito FX-1A sound (Z80 + YM2610B + TC0140SYT)'),
}

# Sound ROMs per MAME set (MAME 0.289 src/mame/sony/zn.cpp). prog = list of
# (name, crc, lane) where lane is 'even'/'odd' for ROM_LOAD16_BYTE pairs or 'all'.
_BRVBLADE = dict(fam='RZ', zip='brvblade.zip',
                 prog=[('spu0u049.bin', 'c9df8ed9', 'even'), ('spu1u412.bin', '6408b5b2', 'odd')],
                 prog_note='MAME ROM_LOAD16_BYTE: spu0u049 = even bytes, spu1u412 = odd bytes.\n\t     (spu* are sound-CPU program ROMs, not PlayStation SPU data.)',
                 smp=[('ra-bbl_rom2.336', 'cd052c02')])
_BROAR = dict(fam='RZ', zip='beastrzr.zip',
              prog=[('b.roar_u042.u042', '4d537f88', 'even'), ('b.roar_u046.u046', 'd4bb261a', 'odd')],
              prog_note='MAME ROM_LOAD16_BYTE: u042 = even bytes, u046 = odd bytes (512 KiB).',
              smp=[('8ing_ra-b.roar_rom-3.u0326', 'b74cc4d1')])
_PSYFORCE = dict(fam='FXA', zip='psyforce.zip',
                 prog=[('e22-07.22', '739af589', 'all')],
                 prog_note='Z80 program 128 KiB: 0000-3FFF fixed, 4000-7FFF = bank (0xF200 & 7) x 16 KiB.',
                 smp=[('e22-01.15', '808b8340')])
SETS = {
    'brvblade': _BRVBLADE, 'brvbladeu': _BRVBLADE, 'brvbladej': _BRVBLADE, 'brvbladea': _BRVBLADE,
    'beastrzr': _BROAR, 'beastrzra': _BROAR, 'bldyroar': _BROAR,
    'psyforce': _PSYFORCE, 'psyforcej': _PSYFORCE, 'psyforcex': _PSYFORCE,
}


def rom_block(idx, cfg, zips, what):
    fam = FAMILY[cfg['fam']]
    if what == 'prog':
        sdram = '0x1800000'
        head = f'\t<!-- {fam["title"]}: sound CPU program, ioctl_index 6 (SDRAM {sdram}).'
        if cfg.get('prog_note'):
            head += f'\n\t     {cfg["prog_note"]}'
        head += ' -->\n'
        parts = cfg['prog']
        body = ''
        if len(parts) == 2 and {p[2] for p in parts} == {'even', 'odd'}:
            body += '\t\t<interleave output="16">\n'
            for n, c, lane in parts:
                body += f'\t\t\t<part name="{n}" crc="{c}" map="{"01" if lane == "even" else "10"}"/>\n'
            body += '\t\t</interleave>\n'
        else:
            for n, c, _ in parts:
                body += f'\t\t<part name="{n}" crc="{c}"/>\n'
    else:
        head = f'\t<!-- {fam["title"]}: sample ROM, ioctl_index 7 (SDRAM 0x1C00000) -->\n'
        body = ''.join(f'\t\t<part name="{n}" crc="{c}"/>\n' for n, c in cfg['smp'])
    return f'{head}\t<rom index="{idx}" zip="{zips}" md5="none">\n{body}\t</rom>\n'


def transform(text, cfg):
    fam = FAMILY[cfg['fam']]
    # rbf
    text = re.sub(r'<rbf>[^<]*</rbf>', f'<rbf>{fam["rbf"]}</rbf>', text, count=1)
    # index 1: platform byte + board byte
    m = re.search(r'(<rom index="1">\s*<part>)([0-9A-Fa-f]{2})(?:\s+[0-9A-Fa-f]{2})?(</part>)', text)
    assert m, 'no index 1'
    text = text[:m.start()] + f'{m.group(1)}{m.group(2)} {fam["board"]}{m.group(3)}' + text[m.end():]
    text = re.sub(r'(<!-- Platform: [^>]*?), ioctl_index 1(?:, byte 1 = audio board [0-9A-F]{2})? -->',
                  lambda mm: f'{mm.group(1)}, ioctl_index 1, byte 1 = audio board {fam["board"]} -->', text, count=1)
    # index 3: drop the bank-2 zero fill (sound ROMs live there) and fix the comments
    m = re.search(r'<rom index="3".*?</rom>', text, re.S)
    blk = m.group(0)
    nblk = blk
    if '3 banks x 8MB = 24MB' in text:
        # the stream ends with bank 2's 8 MiB of zeros (possibly merged into a longer fill)
        f = re.search(r'\n\t\t<part repeat="(0x[0-9A-Fa-f]+)">00</part>(\n\t</rom>)$', blk)
        assert f and int(f.group(1), 16) >= 0x800000, 'index 3 does not end with the bank-2 fill'
        rest = int(f.group(1), 16) - 0x800000
        keep = f'\n\t\t<part repeat="0x{rest:X}">00</part>' if rest else ''
        nblk = blk[:f.start()] + keep + f.group(2)
    if nblk != blk:
        text = text[:m.start()] + nblk + text[m.end():]
        text = text.replace('3 banks x 8MB = 24MB', '2 banks x 8MB = 16MB')
        text = re.sub(r'<!-- Bank 2: 8MB empty\s*-->',
                      '<!-- Bank 2 (never selected by the game) holds the sound ROMs below         -->', text)
    # remove existing index 6/7 blocks (with their leading comment) and insert fresh ones after index 3
    text = re.sub(r'\n\t<!-- [^\n]*ioctl_index [67][^>]*?-->\n\t<rom index="[67]".*?</rom>\n', '\n', text, flags=re.S)
    text = re.sub(r'\n\t<rom index="[67]".*?</rom>\n', '\n', text, flags=re.S)
    text = re.sub(r'\n{3,}', '\n\n', text)
    m = re.search(r'<rom index="3".*?</rom>\n', text, re.S)
    ins = '\n' + rom_block(6, cfg, cfg['zip'], 'prog') + '\n' + rom_block(7, cfg, cfg['zip'], 'smp')
    text = text[:m.end()] + ins + text[m.end():]
    return text


def all_mras():
    files = glob.glob(os.path.join(ROOT, 'source', 'mra', '*.mra'))
    files += glob.glob(os.path.join(ROOT, 'release', '_Arcade', '*.mra'))
    files += glob.glob(os.path.join(ROOT, 'release', '_Arcade', '_alternatives', '*', '*.mra'))
    return files


def main():
    check = '--check' in sys.argv
    changed = 0
    for f in sorted(all_mras()):
        raw = open(f, encoding='utf-8', newline='').read()
        crlf = CRLF in raw
        text = raw.replace(CRLF, LF)
        sm = re.search(r'<setname>([^<]+)</setname>', text)
        if not sm or sm.group(1) not in SETS:
            continue
        new = transform(text, SETS[sm.group(1)])
        if crlf:
            new = new.replace(LF, CRLF)
        if new != raw:
            changed += 1
            print(('WOULD UPDATE ' if check else 'updated ') + os.path.relpath(f, ROOT))
            if not check:
                open(f, 'w', encoding='utf-8', newline='').write(new)
    print(f'{changed} file(s) {"need updating" if check else "updated"}')
    sys.exit(1 if check and changed else 0)


if __name__ == '__main__':
    main()
