// Verilator bench for rtl/zn_ext_audio.sv (any board family, chosen at build time).
// PSX bus writes (and reads) are injected at the times recorded by the MAME trace
// scripts (events.txt "PSXW"/"PSXR" lines, both the bbtrace and fx1*trace formats).
// SDRAM 16-byte line reads are served from the MRA index-6/7 byte streams after a
// configurable latency.
//
// usage: tb_ext_audio <events.txt> <index6.bin> <index7.bin> <out_prefix> <seconds>
//                     [latency_clk] [board_id_hex]
// writes <out_prefix>.raw   int16 L/R board output, one pair per board sample
//        <out_prefix>_mix.raw int16 L/R mixer output (SPU silent) at the same strobes
//        <out_prefix>_dev.txt device register writes: "time W addr data"
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>
#include "Vzn_ext_audio.h"
#include "verilated.h"

static const double CLK_HZ = 33868800.0;

struct Ev { uint64_t cyc; bool rd; uint32_t addr, data; uint8_t be; };

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	if (argc < 6) { fprintf(stderr, "usage: tb_ext_audio events idx6 idx7 out secs [latency] [board]\n"); return 1; }
	double secs = atof(argv[5]);
	int latency = argc > 6 ? atoi(argv[6]) : 16;
	unsigned board = argc > 7 ? strtoul(argv[7], 0, 16) : 0x10;

	auto load = [](const char *fn) {
		std::vector<uint8_t> v; FILE *f = fopen(fn, "rb");
		if (!f) { fprintf(stderr, "cannot open %s\n", fn); exit(1); }
		fseek(f, 0, SEEK_END); v.resize(ftell(f)); fseek(f, 0, SEEK_SET);
		if (fread(v.data(), 1, v.size(), f) != v.size()) exit(1);
		fclose(f); return v;
	};
	std::vector<uint8_t> prog = load(argv[2]), smp = load(argv[3]);
	const uint32_t PROG_BASE = 0x1800000, SAMPLE_BASE = 0x1C00000;

	std::vector<Ev> ev;
	{
		FILE *f = fopen(argv[1], "r"); char line[512];
		if (!f) { fprintf(stderr, "cannot open %s\n", argv[1]); return 1; }
		while (fgets(line, sizeof line, f)) {
			double t; unsigned addr, data, mask; char kind[8];
			if (sscanf(line, "%lf %7s %x data=%x mask=%x", &t, kind, &addr, &data, &mask) == 5 ||
			    sscanf(line, "%lf %7s %x d=%x m=%x", &t, kind, &addr, &data, &mask) == 5) {
				bool rd = !strcmp(kind, "PSXR");
				if (!rd && strcmp(kind, "PSXW")) continue;
				uint8_t be = 0;
				for (int b = 0; b < 4; b++) if ((mask >> (8 * b)) & 0xff) be |= 1 << b;
				// the trace logs the 32-bit-aligned word. Writes are driven word-aligned with the
				// lane in the mask, exactly as the PSX CPU core issues stores (cpu.vhd); reads
				// carry the byte address of the lowest lane.
				uint32_t a = addr & ~3u;
				if (rd) for (int b = 0; b < 4; b++) if (be >> b & 1) { a |= b; break; }
				ev.push_back({(uint64_t)(t * CLK_HZ), rd, a & 0xFFFFFF, data, be});
			}
		}
		fclose(f);
		fprintf(stderr, "%zu PSX bus events\n", ev.size());
	}

	Vzn_ext_audio *top = new Vzn_ext_audio;
	uint64_t cyc = 0;
	top->pause = 0; top->reset = 1; top->mra_board = board; top->prog_loaded = 1; top->smp_loaded = 1;
	top->bus_wr = 0; top->bus_rd = 0; top->mem_ack = 0; top->spu_l = 0; top->spu_r = 0;
	auto tick = [&]() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); cyc++; };
	for (int i = 0; i < 16; i++) tick();
	top->reset = 0;
	uint64_t t0 = cyc;

	std::string pre = argv[4];
	FILE *fo = fopen((pre + ".raw").c_str(), "wb");
	FILE *fm = fopen((pre + "_mix.raw").c_str(), "wb");
	FILE *fd = fopen((pre + "_dev.txt").c_str(), "w");
	size_t ei = 0;
	bool pending = false; uint64_t ready = 0; uint32_t paddr = 0;
	uint64_t end = (uint64_t)(secs * CLK_HZ);
	uint64_t nreq = 0, nsamp = 0, ndev = 0;
	int gap = 0;
	while (cyc - t0 < end) {
		uint64_t now = cyc - t0;
		top->bus_wr = 0; top->bus_rd = 0; top->mem_ack = 0;
		// one bus access every 4 clocks at most (memorymux needs a few clocks per access)
		if (gap) gap--;
		else if (ei < ev.size() && ev[ei].cyc <= now) {
			const Ev &e = ev[ei++];
			top->bus_addr = e.addr; top->bus_din = e.data; top->bus_be = e.be;
			if (e.rd) top->bus_rd = 1; else top->bus_wr = 1;
			gap = 4;
		}
		if (top->mem_req) { pending = true; ready = cyc + latency; paddr = top->mem_addr; nreq++; }
		if (pending && cyc >= ready) {
			pending = false;
			for (int w = 0; w < 4; w++) {
				uint32_t v = 0;
				for (int b = 0; b < 4; b++) {
					uint32_t a = paddr + w * 4 + b;
					uint8_t byte = 0xff;
					if (a >= SAMPLE_BASE && a < SAMPLE_BASE + 0x400000) byte = (a - SAMPLE_BASE) < smp.size() ? smp[a - SAMPLE_BASE] : 0xff;
					else if (a >= PROG_BASE && a < PROG_BASE + 0x100000) byte = (a - PROG_BASE) < prog.size() ? prog[a - PROG_BASE] : 0xff;
					v |= (uint32_t)byte << (8 * b);
				}
				top->mem_data[w] = v;
			}
			top->mem_ack = 1;
		}
		if (top->dbg_dev_wr) {
			fprintf(fd, "%.7f W %03X %04X\n", now / CLK_HZ, top->dbg_dev_addr, top->dbg_dev_data);
			ndev++;
		}
		tick();
		if (top->dbg_sample) {
			int16_t lr[2] = { (int16_t)top->dbg_brd_l, (int16_t)top->dbg_brd_r };
			fwrite(lr, 2, 2, fo);
			int16_t mx[2] = { (int16_t)top->out_l, (int16_t)top->out_r };
			fwrite(mx, 2, 2, fm);
			nsamp++;
		}
		if ((now % (uint64_t)(CLK_HZ * 5)) == 0 && now)
			fprintf(stderr, "t=%.0fs samples=%llu memreq=%llu devw=%llu diag=%08x %08x %08x %08x\n", now / CLK_HZ,
				(unsigned long long)nsamp, (unsigned long long)nreq, (unsigned long long)ndev,
				top->diag[3], top->diag[2], top->diag[1], top->diag[0]);
	}
	fclose(fo); fclose(fm); fclose(fd);
	fprintf(stderr, "done: %llu samples, %llu mem requests, %llu device writes\n",
		(unsigned long long)nsamp, (unsigned long long)nreq, (unsigned long long)ndev);
	delete top;
	return 0;
}
