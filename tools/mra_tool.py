#!/usr/bin/env python3
"""MRA checker / ROM-stream builder for the ZN-1 core.

Builds, for every <rom index=N>, the byte stream the MiSTer loader sends to the core
(parts from the listed zips with CRC check, inline hex parts, repeat fills, and
<interleave output="16|32"> with map strings), so MRAs can be validated against a
MAME ROM directory and the streams fed to the simulation benches.

  mra_tool.py check  <romdir> <mra>...           validate (exit 1 on any error)
                                                 (<romdir> may be 'dirA;dirB', searched in order)
  mra_tool.py stream <romdir> <mra> <index> <out.bin>
"""
import sys, zipfile, zlib, os, re
import xml.etree.ElementTree as ET


class MraError(Exception):
    pass


def _int(s, default=None):
    if s is None:
        return default
    s = s.strip()
    return int(s, 16) if s.lower().startswith('0x') else int(s)


class Zips:
    def __init__(self, romdir, ziplist):
        self.files = []
        for z in ziplist:                    # romdir may list several folders, ';'-separated
            for d in romdir.split(';'):
                p = os.path.join(d, z)
                if os.path.exists(p):
                    self.files.append(zipfile.ZipFile(p))
                    break

    def get(self, name, crc):
        crc = int(crc, 16) if crc else None
        for zf in self.files:            # by CRC first (MiSTer behaviour), then by name
            for i in zf.infolist():
                if crc is not None and i.CRC == crc:
                    return zf.read(i)
        for zf in self.files:
            for i in zf.infolist():
                if os.path.basename(i.filename) == name:
                    d = zf.read(i)
                    if crc is not None and zlib.crc32(d) != crc:
                        raise MraError(f'{name}: CRC {zlib.crc32(d):08x} != {crc:08x}')
                    return d
        raise MraError(f'{name} (crc {crc and format(crc, "08x")}) not found in {[os.path.basename(f.filename) for f in self.files]}')


def part_bytes(part, zips):
    if part.get('name') is not None:
        d = zips.get(part.get('name'), part.get('crc'))
        off = _int(part.get('offset'), 0)
        ln = _int(part.get('length'), len(d) - off)
        d = d[off:off + ln]
    else:
        txt = re.sub(r'\s+', '', part.text or '')
        d = bytes.fromhex(txt)
    rep = _int(part.get('repeat'), None)
    if rep is not None:
        d = (d * (rep // max(len(d), 1) + 1))[:rep] if d else b''
    return d


def interleave(node, zips):
    width = _int(node.get('output')) // 8
    parts = []
    for p in node.findall('part'):
        m = p.get('map')
        parts.append((part_bytes(p, zips), m))
    # map: rightmost char = output byte 0; char k>0 = take byte k-1 of the part's group
    steps = None
    for d, m in parts:
        n = sum(1 for c in m if c != '0')
        s = len(d) // n
        steps = s if steps is None else min(steps, s)
    out = bytearray(steps * width)
    for d, m in parts:
        n = sum(1 for c in m if c != '0')
        for ob, c in enumerate(reversed(m)):
            if c == '0':
                continue
            k = int(c) - 1
            out[ob::width] = d[k::n][:steps]
    return bytes(out)


def rom_streams(romdir, mra):
    root = ET.parse(mra).getroot()
    res = {}
    for rom in root.findall('rom'):
        idx = _int(rom.get('index'), 0)
        zips = Zips(romdir, (rom.get('zip') or '').split('|') if rom.get('zip') else [])
        buf = bytearray()
        for child in rom:
            if child.tag == 'part':
                buf += part_bytes(child, zips)
            elif child.tag == 'interleave':
                buf += interleave(child, zips)
        res[idx] = bytes(buf)
    return root, res


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    cmd, romdir = sys.argv[1], sys.argv[2]
    if cmd == 'check':
        bad = 0
        for mra in sys.argv[3:]:
            try:
                root, st = rom_streams(romdir, mra)
                desc = ' '.join(f'{i}:{len(b):#x}' for i, b in sorted(st.items()))
                print(f'OK   {os.path.basename(mra)}  rbf={root.findtext("rbf")}  {desc}')
            except Exception as e:
                bad += 1
                print(f'FAIL {os.path.basename(mra)}: {e}')
        sys.exit(1 if bad else 0)
    elif cmd == 'stream':
        _, st = rom_streams(romdir, sys.argv[3])
        open(sys.argv[5], 'wb').write(st[_int(sys.argv[4])])
    else:
        print(__doc__); sys.exit(2)


if __name__ == '__main__':
    main()
