// Verilator system testbench for rtl/raizing_snd/raizing_snd.sv
// Runs the real 68000 sound program. PSX-side latch/IRQ writes are injected at
// the times recorded by the MAME trace (events.txt "PSXW" lines). SDRAM line
// reads are served from a memory image after a configurable latency.
//
// usage: tb_raizing_snd <events.txt> <audiocpu_interleaved.bin> <samplerom.bin>
//                        <out_prefix> <seconds> [latency_clk]
// writes <out_prefix>.raw (int16 L/R at 44.1 kHz, one pair per YMF sample)
//        <out_prefix>_ymf.txt (68000 YMF271 writes: time reg data)
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>
#include "Vraizing_snd.h"
#include "verilated.h"

static const double CLK_HZ = 33868800.0;

struct Ev { uint64_t cyc; bool irq; uint8_t data; };

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	if (argc < 6) { fprintf(stderr, "usage\n"); return 1; }
	double secs = atof(argv[5]);
	int latency = argc > 6 ? atoi(argv[6]) : 16;
	uint64_t bustrace = getenv("BUSTRACE") ? strtoull(getenv("BUSTRACE"), 0, 10) : 0;
	uint64_t busfrom = getenv("BUSFROM") ? strtoull(getenv("BUSFROM"), 0, 10) : 0;

	auto load = [](const char *fn) {
		std::vector<uint8_t> v; FILE *f = fopen(fn, "rb");
		if (!f) { fprintf(stderr, "cannot open %s\n", fn); exit(1); }
		fseek(f, 0, SEEK_END); v.resize(ftell(f)); fseek(f, 0, SEEK_SET); fread(v.data(), 1, v.size(), f); fclose(f); return v;
	};
	std::vector<uint8_t> prog = load(argv[2]), smp = load(argv[3]);
	const uint32_t PROG_BASE = 0x1800000, SAMPLE_BASE = 0x1C00000;

	std::vector<Ev> ev;
	{
		FILE *f = fopen(argv[1], "r"); char line[512];
		while (fgets(line, sizeof line, f)) {
			double t; unsigned addr, data;
			if (sscanf(line, "%lf PSXW %x data=%x", &t, &addr, &data) == 3) {
				if (addr == 0x1FB00000) ev.push_back({(uint64_t)(t * CLK_HZ), false, (uint8_t)data});
				else if (addr == 0x1FB00004) ev.push_back({(uint64_t)(t * CLK_HZ), true, 0});
			}
		}
		fclose(f);
		fprintf(stderr, "%zu PSX sound events\n", ev.size());
	}

	Vraizing_snd *top = new Vraizing_snd;
	uint64_t cyc = 0;
	top->pause = 0; top->reset = 1; top->enable = 1; top->latch_wr = 0; top->irq_wr = 0; top->mem_ack = 0;
	auto tick = [&]() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); cyc++; };
	for (int i = 0; i < 16; i++) tick();
	top->reset = 0;
	uint64_t t0 = cyc;

	std::string pre = argv[4];
	FILE *fo = fopen((pre + ".raw").c_str(), "wb");
	FILE *fy = fopen((pre + "_ymf.txt").c_str(), "w");
	size_t ei = 0;
	bool pending = false; uint64_t ready = 0; uint32_t paddr = 0;
	uint64_t end = (uint64_t)(secs * CLK_HZ);
	uint64_t nreq = 0, nsamp = 0;
	while (cyc - t0 < end) {
		uint64_t now = cyc - t0;
		top->latch_wr = 0; top->irq_wr = 0; top->mem_ack = 0;
		while (ei < ev.size() && ev[ei].cyc <= now) {
			if (ev[ei].irq) top->irq_wr = 1; else { top->latch_wr = 1; top->latch_din = ev[ei].data; }
			ei++;
			if (top->irq_wr && top->latch_wr) break;
		}
		if (top->mem_req) { pending = true; ready = cyc + latency; paddr = top->mem_addr; nreq++; }
		if (pending && cyc >= ready) {
			pending = false;
			for (int w = 0; w < 4; w++) {
				uint32_t v = 0;
				for (int b = 0; b < 4; b++) {
					uint32_t a = paddr + w * 4 + b;
					uint8_t byte = 0xff;
					if (a >= SAMPLE_BASE && a < SAMPLE_BASE + 0x400000) byte = smp[(a - SAMPLE_BASE) % smp.size()];
					else if (a >= PROG_BASE && a < PROG_BASE + 0x100000) byte = (a - PROG_BASE) < prog.size() ? prog[a - PROG_BASE] : 0xff;
					v |= (uint32_t)byte << (8 * b);
				}
				top->mem_data[w] = v;
			}
			top->mem_ack = 1;
		}
		// log YMF writes as they enter the chip
		if (top->dbg_ymf_wr)
			fprintf(fy, "%.7f W %02X %02X\n", now / CLK_HZ, top->dbg_ymf_addr, top->dbg_ymf_data);
		{
			// ring buffer of bus cycles; dump when the CPU first reaches the default trap handlers
			static uint64_t ring[64]; static int rp = 0; static bool lastas = true; static bool dumped = false;
			uint64_t b = top->dbg_bus;
			bool as = (b >> 63) & 1;
			if (lastas && !as) { ring[rp++ & 63] = b; }
			if (!as && !dumped) {
				uint32_t a = (b >> 32) & 0xffffff;
				if (a >= 0x08 && a < 0x100 && a != 0x68 && a != 0x6A && ((b >> 56) & 7) == 5 && ((b >> 60) & 1)) {
					dumped = true;
					fprintf(stderr, "EXCEPTION PATH at cycle %llu (t=%.6f):\n", (unsigned long long)now, now / CLK_HZ);
					for (int i = 0; i < 64; i++) {
						uint64_t x = ring[(rp + i) & 63];
						fprintf(stderr, "  FC=%d RW=%d UDS=%d LDS=%d A=%06X din=%04X dout=%04X\n", (int)(x >> 56 & 7), (int)(x >> 60 & 1),
							(int)(x >> 62 & 1), (int)(x >> 61 & 1), (unsigned)(x >> 32 & 0xffffff), (unsigned)(x >> 16 & 0xffff), (unsigned)(x & 0xffff));
					}
				}
			}
			lastas = as;
		}
		if (bustrace && now >= busfrom && now < busfrom + bustrace) {
			uint64_t b = top->dbg_bus;
			static uint64_t lastb = ~0ull;
			if (b != lastb) { fprintf(stderr, "%llu bus AS=%d UDS=%d LDS=%d RW=%d DTACK=%d FC=%d A=%06X din=%04X dout=%04X st=%d\n", (unsigned long long)now, (int)(b>>63&1),(int)(b>>62&1),(int)(b>>61&1),(int)(b>>60&1),(int)(b>>59&1),(int)(b>>56&7),(unsigned)((b>>32&0xffffff)),(unsigned)(b>>16&0xffff),(unsigned)(b&0xffff),(int)top->dbg_bstate); lastb = b; }
		}
		tick();
		if (top->dbg_sample) {
			int16_t lr[2] = { (int16_t)top->out_l, (int16_t)top->out_r };
			fwrite(lr, 2, 2, fo);
			nsamp++;
		}
		if ((now % (uint64_t)(CLK_HZ * 5)) == 0 && now)
			fprintf(stderr, "t=%.0fs samples=%llu memreq=%llu dbg=%016llx\n", now / CLK_HZ, (unsigned long long)nsamp,
				(unsigned long long)nreq, (unsigned long long)top->dbg);
	}
	fclose(fo); fclose(fy);
	fprintf(stderr, "done: %llu samples, %llu mem requests, dbg=%016llx\n", (unsigned long long)nsamp, (unsigned long long)nreq, (unsigned long long)top->dbg);
	delete top;
	return 0;
}
