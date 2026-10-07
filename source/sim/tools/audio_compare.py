#!/usr/bin/env python3
"""Compare a simulation's board output (int16 stereo raw at a given rate) with a MAME
-wavwrite reference: per window, best lag, waveform correlation and level ratio.

  audio_compare.py <mame.wav> <sim.raw> <sim_rate_hz> <t0> <t1> [<t0> <t1> ...]
"""
import sys, wave
from fractions import Fraction
import numpy as np
from scipy.signal import resample_poly, correlate


def main():
    wav, raw, rate = sys.argv[1], sys.argv[2], float(sys.argv[3])
    w = wave.open(wav)
    fr = w.getframerate()
    m = np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(float)
    s = np.fromfile(raw, np.int16).reshape(-1, 2).astype(float)
    ratio = (Fraction(fr) / Fraction(rate).limit_denominator(100000)).limit_denominator(4000)
    s = resample_poly(s, ratio.numerator, ratio.denominator, axis=0)
    print(f'MAME {len(m)/fr:.2f} s @ {fr} Hz, sim {len(s)/fr:.2f} s (resampled {ratio})')
    ws = sys.argv[4:]
    for a, b in zip(ws[0::2], ws[1::2]):
        a, b = float(a), float(b)
        M = m[int(a * fr):int(b * fr)]
        S = s[int(a * fr):int(b * fr)]
        n = min(len(M), len(S))
        M, S = M[:n], S[:n]
        for ch in (0, 1):
            x, y = S[:, ch] - S[:, ch].mean(), M[:, ch] - M[:, ch].mean()
            if not y.any():
                print(f'{a:.1f}-{b:.1f} s ch{ch}: MAME silent'); continue
            c = correlate(x, y, mode='full', method='fft')
            lag = int(c.argmax() - (n - 1))
            xs = np.roll(x, -lag)[2000:-2000]
            ys = y[2000:-2000]
            r = np.corrcoef(xs, ys)[0, 1]
            g = np.sqrt((xs ** 2).mean() / (ys ** 2).mean())
            print(f'{a:.1f}-{b:.1f} s ch{ch}: lag {lag / fr * 1000:+.2f} ms  corr {r:.3f}  '
                  f'level sim/MAME {g:.3f} ({20 * np.log10(g):+.2f} dB)  MAME rms {np.sqrt((ys ** 2).mean()):.0f}')


if __name__ == '__main__':
    main()
