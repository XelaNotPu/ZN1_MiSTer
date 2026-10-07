// Fixed-point YMF271 model mirroring the planned HDL (ymf271.sv).
// Integer semantics follow MAME's ymf271.cpp; structure follows the hardware:
//  - one sample = 12 groups processed in order, each group runs a short
//    op-program selected by (sync, algorithm)
//  - envelope rates are latched at key-on and turned into steps via ROM tables
//  - phase step computed each sample from registers with shifts (no doubles)
//  - LFO pitch modulation uses a linearised factor (MAME uses pow())
#pragma once
#include <cstdint>
#include <cstdio>
#include <cmath>
#include <cstring>
#include <cassert>
#include <functional>
#include "ymf_tables.h"

namespace ymf_fx {

enum { IN_NONE = 0, IN_FB, IN_R1, IN_R2, IN_R3, IN_R1R3, IN_R1R2, IN_R3R2 };
enum { D_NONE = 0, D_R1, D_R2, D_R3 };
struct Op { uint8_t bank, insel, dst, out; };
struct Prog { uint8_t nops; Op op[4]; uint8_t fbsrc; /* D_R1 / D_R3 */ };

// 4-op FM programs (sync 0), index = algorithm 0..15
static const Prog prog4[16] = {
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_R3,D_R2,0},{3,IN_R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_R3,D_R2,0},{3,IN_R2,D_NONE,1}},D_R3},
	{4,{{0,IN_FB,D_R1,0},{2,IN_NONE,D_R3,0},{1,IN_R1R3,D_R2,0},{3,IN_R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_NONE,D_R3,0},{1,IN_R3,D_R2,0},{3,IN_R1R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_NONE,D_R2,0},{3,IN_R3R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_NONE,D_R2,0},{3,IN_R3R2,D_NONE,1}},D_R3},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_NONE,1},{1,IN_NONE,D_R2,0},{3,IN_R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,1},{1,IN_NONE,D_R2,0},{3,IN_R2,D_NONE,1}},D_R3},
	{4,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_R3,0},{1,IN_R3,D_R2,0},{3,IN_R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_R3,0},{1,IN_NONE,D_R2,0},{3,IN_R3R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_NONE,1},{1,IN_NONE,D_NONE,1},{3,IN_NONE,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,1},{1,IN_NONE,D_NONE,1},{3,IN_NONE,D_NONE,1}},D_R3},
	{4,{{0,IN_FB,D_R1,0},{2,IN_R1,D_NONE,1},{1,IN_R1,D_NONE,1},{3,IN_R1,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_R3,0},{1,IN_R3,D_NONE,1},{3,IN_NONE,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,1},{2,IN_R1,D_NONE,1},{1,IN_NONE,D_R2,0},{3,IN_R2,D_NONE,1}},D_R1},
	{4,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_NONE,1},{1,IN_NONE,D_NONE,1},{3,IN_NONE,D_NONE,1}},D_R1},
};
// 2-op FM programs (sync 1), index = algorithm & 3; banks are relative (0 = slot1, 2 = slot3)
static const Prog prog2[4] = {
	{2,{{0,IN_FB,D_R1,0},{2,IN_R1,D_NONE,1}},D_R1},
	{2,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,1}},D_R3},
	{2,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_NONE,1}},D_R1},
	{2,{{0,IN_FB,D_R1,1},{2,IN_R1,D_NONE,1}},D_R1},
};
// 3-op FM programs (sync 2), index = algorithm & 7
static const Prog prog3[8] = {
	{3,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_R3,D_NONE,1}},D_R1},
	{3,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,0},{1,IN_R3,D_NONE,1}},D_R3},
	{3,{{0,IN_FB,D_R1,0},{2,IN_NONE,D_R3,0},{1,IN_R1R3,D_NONE,1}},D_R1},
	{3,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_R3,0},{1,IN_R3,D_NONE,1}},D_R1},
	{3,{{0,IN_FB,D_R1,0},{2,IN_R1,D_NONE,1},{1,IN_NONE,D_NONE,1}},D_R1},
	{3,{{0,IN_FB,D_R1,0},{2,IN_R1,D_R3,1},{1,IN_NONE,D_NONE,1}},D_R3},
	{3,{{0,IN_FB,D_R1,1},{2,IN_NONE,D_NONE,1},{1,IN_NONE,D_NONE,1}},D_R1},
	{3,{{0,IN_FB,D_R1,1},{2,IN_R1,D_NONE,1},{1,IN_NONE,D_NONE,1}},D_R1},
};

struct Slot {
	// registers
	uint8_t lfofreq, lfowave, pms, ams, mult, tl, ks, ar, d1r, d2r, rr, d1l, block, fns_hi, fb, wave, alg;
	uint16_t fns;
	uint8_t lvl[4];
	uint32_t start, loop, end;
	uint8_t fs, bits12;
	// latched at key-on
	uint8_t r_ar, r_d1, r_d2, r_rr, d1l_k;
	// dynamic
	uint8_t active, env_state;
	int32_t volume;       // 8.16
	uint64_t ptr;         // PCM: 24.16 ; FM: phase (26 bits used)
	uint16_t lfo_phase;
	int32_t fb0, fb1;
};

struct ymf271 {
	std::function<uint8_t(uint32_t)> read_byte;
	int64_t dbg_sample = -1, cur_sample = 0; int64_t dbg_from=-1, dbg_to=-1;
	Slot s[48];
	uint8_t gsync[12];
	uint8_t regs[16];
	uint16_t end_status = 0;

	ymf271() { memset(s, 0, sizeof s); memset(gsync, 0, sizeof gsync); memset(regs, 0, sizeof regs); }

	// ---------------- per-slot arithmetic ----------------
	static int keycode(const Slot &x) {
		int n43;
		if (x.wave != 7) { int f = x.fns; n43 = f < 0x780 ? 0 : f < 0x900 ? 1 : f < 0xa80 ? 2 : 3; }
		else { int f = x.fns & 0x7ff; n43 = f < 0x100 ? 0 : f < 0x300 ? 1 : f < 0x500 ? 2 : 3; }
		return ((x.block & 7) << 2) | n43;
	}
	static int ksr(int rate, int kc, int ks) { int r = rate + tbl::rks[kc][ks]; return r > 63 ? 63 : r; }

	void keyon(Slot &x, int slotnum) {
		x.active = 1; x.ptr = 0;
		if (!(slotnum & 3)) end_status &= ~(1 << (slotnum / 12 + ((slotnum % 12) >> 2) * 4));
		int kc = keycode(x);
		x.r_ar = ksr(x.ar * 2, kc, x.ks);
		x.r_d1 = ksr(x.d1r * 2, kc, x.ks);
		x.r_d2 = ksr(x.d2r * 2, kc, x.ks);
		x.r_rr = ksr(x.rr * 4, kc, x.ks);
		x.d1l_k = x.d1l;
		x.volume = 95 << 16;
		x.env_state = 0;
		x.lfo_phase = 0;
		x.fb0 = x.fb1 = 0;
	}
	void env_update(Slot &x) {
		switch (x.env_state) {
		case 0:
			x.volume += x.r_ar < 4 ? 0 : tbl::ar_step[x.r_ar];
			if (x.volume >= (255 << 16)) { x.volume = 255 << 16; x.env_state = 1; }
			break;
		case 1:
			x.volume -= x.r_d1 < 4 ? 0 : tbl::d1_step[x.d1l_k][x.r_d1];
			if (x.volume <= 0) { x.volume = 0; x.active = 0; }
			else if ((x.volume >> 16) <= 255 - (x.d1l << 4)) x.env_state = 2;
			break;
		case 2:
			x.volume -= x.r_d2 < 4 ? 0 : tbl::dc_step[x.r_d2];
			if (x.volume <= 0) { x.volume = 0; x.active = 0; }
			break;
		case 3:
			x.volume -= x.r_rr < 4 ? 0 : tbl::dc_step[x.r_rr];
			if (x.volume <= 0) { x.volume = 0; x.active = 0; }
			break;
		}
	}
	// LFO: returns pitch factor (1.16) and amplitude-mod factor (0..65536)
	void lfo_update(Slot &x, uint32_t &pm, uint32_t &am) {
		x.lfo_phase += tbl::lfo_step[x.lfofreq];
		int i = (x.lfo_phase >> 8) & 255;
		// amplitude (exact MAME tables)
		int amp;
		switch (x.lfowave) {
		case 0: amp = 0; break;
		case 1: amp = 65536 - 256 * i; break;
		case 2: amp = i < 128 ? 65536 : 0; break;
		default: { int tri = (i & 127) * 512; amp = i < 128 ? 65536 - tri : tri; } break;
		}
		static const int amk[4] = { 0, 33124, 16742, 4277 };
		am = x.ams ? 65536 - (uint32_t)(((int64_t)amp * amk[x.ams]) >> 16) : 65536;
		// pitch: p in Q8 (-256..256)
		int p;
		switch (x.lfowave) {
		case 0: p = 0; break;
		case 1: p = tbl::plfo_saw[i]; break;
		case 2: p = i < 128 ? 256 : -256; break;
		default: { int q = i & 63; int t = q * 4; p = (i < 64) ? t : (i < 128) ? 256 - t : (i < 192) ? -t : -(256 - t); } break;
		}
		pm = 65536 + ((p * tbl::pm_k[x.pms]) >> 8);   // pm_k = round(65536*ln2*cents/1200)
	}
	uint32_t step_of(const Slot &x, uint32_t pm) {
		int e = x.block < 8 ? x.block + 7 : x.block - 9;
		uint32_t mulx2 = x.mult ? 2 * x.mult : 1;
		uint64_t f; int sh;
		if (x.wave == 7) { f = (uint64_t)(x.fns | 2048) * mulx2; sh = e - x.fs - 3; }
		else { f = (uint64_t)x.fns * mulx2; sh = e - 3; }
		// base with 8 extra fractional bits so that PM multiply stays accurate
		uint64_t b8 = sh >= 0 ? (f << sh) << 8 : (f << 8) >> (-sh);
		if (pm == 65536) return (uint32_t)(b8 >> 8);
		return (uint32_t)((b8 * pm) >> 24);
	}
	// envelope * TL (* AM) -> 0..65536
	int64_t slot_volume(const Slot &x, uint32_t am) {
		int64_t ev = tbl::env_vol[255 - (x.volume >> 16)];
		if (am != 65536) ev = (ev * am) >> 16;
		return (ev * tbl::tl[x.tl]) >> 16;
	}
	int16_t wave(int w, int idx) { return tbl::wave(w, idx); }

	int64_t fm_op(int slotnum, int insel, int64_t r1, int64_t r2, int64_t r3) {
		Slot &x = s[slotnum];
		env_update(x);
		uint32_t pm, am; lfo_update(x, pm, am);
		uint32_t step = step_of(x, pm);
		int64_t env = slot_volume(x, am);
		int64_t in = 0;
		switch (insel) {
		case IN_FB: in = (int64_t)(x.fb0 + x.fb1) / 2; x.fb0 = x.fb1; break;
		case IN_NONE: in = 0; break;
		default: {
			int64_t v = insel == IN_R1 ? r1 : insel == IN_R2 ? r2 : insel == IN_R3 ? r3 : insel == IN_R1R3 ? r1 + r3 : insel == IN_R1R2 ? r1 + r2 : r3 + r2;
			in = v * 256 * tbl::modlvl[x.fb];
		} break;
		}
		int idx = (int)(((x.ptr + (uint64_t)in) >> 16) & 1023);
		int64_t out = ((int64_t)wave(x.wave, idx) * env) >> 16;
		x.ptr = (x.ptr + step) & 0x3ffffff;
		return out;
	}

	void run_prog(int j, const Prog &p, int bank_ofs, int32_t *mix) {
		int64_t r1 = 0, r2 = 0, r3 = 0;
		int64_t acc[2] = { 0, 0 };
		for (int k = 0; k < p.nops; k++) {
			const Op &o = p.op[k];
			int sn = j + 12 * (o.bank + bank_ofs);
			int64_t v = fm_op(sn, o.insel, r1, r2, r3);
			if (o.dst == D_R1) r1 = v; else if (o.dst == D_R2) r2 = v; else if (o.dst == D_R3) r3 = v;
			if (o.out) { acc[0] += v * tbl::att[s[sn].lvl[0]]; acc[1] += v * tbl::att[s[sn].lvl[1]]; }
		}
		Slot &l = s[j + 12 * bank_ofs];
		l.fb1 = (int32_t)((p.fbsrc == D_R3 ? r3 : r1) * 16 * tbl::fblvl[l.fb]);
		mix[0] += (int32_t)(acc[0] >> 16);
		mix[1] += (int32_t)(acc[1] >> 16);
		if (cur_sample>=dbg_from && cur_sample<=dbg_to) fprintf(stderr,"M s=%lld FM j=%d ofs=%d add0=%lld add1=%lld\n",(long long)cur_sample,j,bank_ofs,(long long)(acc[0]>>16),(long long)(acc[1]>>16));
	}

	void pcm(int slotnum, int32_t *mix) {
		Slot &x = s[slotnum];
		if (!x.active) return;
		if (x.wave != 7) return;
		if ((x.ptr >> 16) > x.end) {
			x.ptr = x.ptr - ((uint64_t)x.end << 16) + ((uint64_t)x.loop << 16);
			end_status |= (1 << (slotnum / 12 + ((slotnum % 12) >> 2) * 4));
			if ((x.ptr >> 16) > x.end) {
				x.ptr = (x.ptr & 0xffff) | ((uint64_t)x.loop << 16);
				if ((x.ptr >> 16) > x.end) x.ptr = (x.ptr & 0xffff) | ((uint64_t)x.end << 16);
			}
		}
		int16_t smp;
		if (!x.bits12) smp = (int16_t)(read_byte(x.start + (uint32_t)(x.ptr >> 16)) << 8);
		else {
			uint32_t a = x.start + (uint32_t)(x.ptr >> 17) * 3;
			if (x.ptr & 0x10000) smp = (int16_t)(read_byte(a + 2) << 8 | ((read_byte(a + 1) << 4) & 0xf0));
			else smp = (int16_t)(read_byte(a) << 8 | (read_byte(a + 1) & 0xf0));
		}
		env_update(x);
		uint32_t pm, am; lfo_update(x, pm, am);
		uint32_t step = step_of(x, pm);
		int64_t fv = slot_volume(x, am);
		for (int c = 0; c < 2; c++) {
			int64_t cv = (fv * tbl::att[x.lvl[c]]) >> 16;
			if (cv > 65536) cv = 65536;
			mix[c] += (int32_t)((smp * cv) >> 16);
			if (cur_sample>=dbg_from && cur_sample<=dbg_to) fprintf(stderr,"M s=%lld PCM slot %d ch%d smp=%d fv=%lld cv=%lld add=%lld ptr=%llx vol=%x env=%d step=%u\n",(long long)cur_sample,slotnum,c,smp,(long long)fv,(long long)cv,(long long)((smp*cv)>>16),(unsigned long long)x.ptr,x.volume,x.env_state,step);
		}
		x.ptr += step;
		x.ptr &= 0xffffffffffULL;
	}

	void update(int n, int32_t *mixbuf) {
		for (int i = 0; i < n; i++) {
			int32_t mix[2] = { 0, 0 };
			for (int j = 0; j < 12; j++) {
				switch (gsync[j]) {
				case 0: if (s[j].active) run_prog(j, prog4[s[j].alg & 15], 0, mix); break;
				case 1:
					for (int p = 0; p < 2; p++) if (s[j + 12 * p].active) run_prog(j, prog2[s[j + 12 * p].alg & 3], p, mix);
					break;
				case 2: if (s[j].active) run_prog(j, prog3[s[j].alg & 7], 0, mix); pcm(j + 36, mix); break;
				case 3: for (int b = 0; b < 4; b++) pcm(j + 12 * b, mix); break;
				}
			}
			cur_sample++;
			mixbuf[i * 4 + 0] = mix[0]; mixbuf[i * 4 + 1] = mix[1]; mixbuf[i * 4 + 2] = 0; mixbuf[i * 4 + 3] = 0;
		}
	}

	// ---------------- register interface ----------------
	void write_register(int sn, int reg, uint8_t d) {
		Slot &x = s[sn];
		switch (reg) {
		case 0x0: if (d & 1) keyon(x, sn); else if (x.active) x.env_state = 3; break;
		case 0x1: x.lfofreq = d; break;
		case 0x2: x.lfowave = d & 3; x.pms = (d >> 3) & 7; x.ams = (d >> 6) & 3; break;
		case 0x3: x.mult = d & 0xf; break;
		case 0x4: x.tl = d & 0x7f; break;
		case 0x5: x.ar = d & 0x1f; x.ks = (d >> 5) & 7; break;
		case 0x6: x.d1r = d & 0x1f; break;
		case 0x7: x.d2r = d & 0x1f; break;
		case 0x8: x.rr = d & 0xf; x.d1l = (d >> 4) & 0xf; break;
		case 0x9: x.fns = ((x.fns_hi << 8) & 0xf00) | d; x.block = (x.fns_hi >> 4) & 0xf; break;
		case 0xa: x.fns_hi = d; break;
		case 0xb: x.wave = d & 7; x.fb = (d >> 4) & 7; break;
		case 0xc: x.alg = d & 0xf; break;
		case 0xd: x.lvl[0] = d >> 4; x.lvl[1] = d & 0xf; break;
		case 0xe: x.lvl[2] = d >> 4; x.lvl[3] = d & 0xf; break;
		}
	}
	void write_fm(int bank, uint8_t a, uint8_t d) {
		static const int fm_tab[16] = { 0, 1, 2, -1, 3, 4, 5, -1, 6, 7, 8, -1, 9, 10, 11, -1 };
		int g = fm_tab[a & 0xf]; if (g < 0) return;
		int reg = a >> 4;
		bool sreg = reg == 0 || reg == 9 || reg == 10 || reg == 12 || reg == 13 || reg == 14;
		int sy = gsync[g];
		if (sreg && sy == 0 && bank == 0) { for (int b = 0; b < 4; b++) write_register(12 * b + g, reg, d); }
		else if (sreg && sy == 1 && bank <= 1) { write_register(12 * bank + g, reg, d); write_register(12 * (bank + 2) + g, reg, d); }
		else if (sreg && sy == 2 && bank == 0) { for (int b = 0; b < 3; b++) write_register(12 * b + g, reg, d); }
		else write_register(12 * bank + g, reg, d);
	}
	void write_pcm(uint8_t a, uint8_t d) {
		static const int pcm_tab[16] = { 0, 4, 8, -1, 12, 16, 20, -1, 24, 28, 32, -1, 36, 40, 44, -1 };
		int sn = pcm_tab[a & 0xf]; if (sn < 0) return;
		Slot &x = s[sn];
		switch (a >> 4) {
		case 0: x.start = (x.start & ~0xffu) | d; break;
		case 1: x.start = (x.start & ~0xff00u) | (d << 8); break;
		case 2: x.start = (x.start & ~0xff0000u) | ((d & 0x7f) << 16); break;
		case 3: x.end = (x.end & ~0xffu) | d; break;
		case 4: x.end = (x.end & ~0xff00u) | (d << 8); break;
		case 5: x.end = (x.end & ~0xff0000u) | ((d & 0x7f) << 16); break;
		case 6: x.loop = (x.loop & ~0xffu) | d; break;
		case 7: x.loop = (x.loop & ~0xff00u) | (d << 8); break;
		case 8: x.loop = (x.loop & ~0xff0000u) | ((d & 0x7f) << 16); break;
		case 9: x.fs = d & 3; x.bits12 = (d >> 2) & 1; break;
		}
	}
	void write(uint32_t off, uint8_t d) {
		off &= 0xf; regs[off] = d;
		switch (off) {
		case 1: write_fm(0, regs[0], d); break;
		case 3: write_fm(1, regs[2], d); break;
		case 5: write_fm(2, regs[4], d); break;
		case 7: write_fm(3, regs[6], d); break;
		case 9: write_pcm(regs[8], d); break;
		case 0xd: if (regs[0xc] < 0x10) { static const int fm_tab[16] = { 0, 1, 2, -1, 3, 4, 5, -1, 6, 7, 8, -1, 9, 10, 11, -1 }; int g = fm_tab[regs[0xc] & 0xf]; if (g >= 0) gsync[g] = d & 3; } break;
		}
	}
};

} // namespace ymf_fx
