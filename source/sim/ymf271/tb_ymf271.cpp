// Verilator testbench for rtl/raizing_snd/ymf271.sv
// Replays a YMF271 register-write log (captured from MAME with the Lua trace
// script) with the same sample alignment as the C++ reference replay tool:
// writes whose timestamp falls in sample k are applied before sample k is
// computed. Sample-ROM line fetches are answered after a configurable latency.
//
// usage: tb_ymf271 <ymf_writes.txt> <samplerom.bin> <out.raw> [t_end] [latency]
// out.raw: interleaved int16 L/R
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include <deque>
#include "Vymf271.h"
#include "verilated.h"

struct Wr { int64_t sample; uint8_t reg, data; };

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	if (argc < 4) { fprintf(stderr, "usage: tb_ymf271 log rom out.raw [t_end] [latency]\n"); return 1; }
	double t_end = argc > 4 ? atof(argv[4]) : 1e9;
	int latency = argc > 5 ? atoi(argv[5]) : 24;

	std::vector<uint8_t> rom;
	{ FILE *f = fopen(argv[2], "rb"); fseek(f, 0, SEEK_END); rom.resize(ftell(f)); fseek(f, 0, SEEK_SET); fread(rom.data(), 1, rom.size(), f); fclose(f); }
	std::vector<Wr> wr;
	{
		FILE *f = fopen(argv[1], "r"); char line[256]; double last = 0;
		while (fgets(line, sizeof line, f)) {
			double t; char rw; unsigned r, d;
			if (sscanf(line, "%lf %c %x %x", &t, &rw, &r, &d) != 4) continue;
			if (t > t_end) break;
			last = t;
			if (rw == 'W') wr.push_back({(int64_t)(t * 44100.0), (uint8_t)r, (uint8_t)d});
		}
		wr.push_back({(int64_t)(std::min(last, t_end) * 44100.0), 0xff, 0});   // end marker
	}
	int64_t nsamples = wr.back().sample;

	Vymf271 *top = new Vymf271;
	uint64_t cyc = 0;
	auto tick = [&]() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); cyc++; };

	top->pause = 0; top->reset = 1; top->cpu_wr = 0; top->fetch_ack = 0; top->test_hold = 1; top->test_fast = 1;
	for (int i = 0; i < 8; i++) tick();
	top->reset = 0;

	FILE *out = fopen(argv[3], "wb");
	std::deque<std::pair<uint64_t, uint32_t>> pend;   // (ready cycle, line)
	bool req_seen = false;
	size_t wi = 0;
	uint64_t fetches = 0;
	int64_t k = 0;
	uint64_t maxcyc = 0; int64_t maxk = 0; uint64_t hist[16] = {0};
	auto serve = [&]() {
		// memory model: one outstanding request at a time (like the arbiter)
		top->fetch_ack = 0;
		if (top->fetch_req && !req_seen) { pend.push_back({cyc + latency, top->fetch_line}); req_seen = true; }
		if (!pend.empty() && cyc >= pend.front().first) {
			uint32_t line = pend.front().second; pend.pop_front();
			for (int w = 0; w < 4; w++) {
				uint32_t v = 0;
				for (int b = 0; b < 4; b++) v |= (uint32_t)rom[((line << 4) + w * 4 + b) & (rom.size() - 1)] << (8 * b);
				top->fetch_data[w] = v;
			}
			top->fetch_ack = 1; req_seen = false; fetches++;
		}
	};
	auto step = [&]() { serve(); tick(); };

	while (k < nsamples) {
		// apply writes belonging to sample k while the engine is held
		top->test_hold = 1;
		while (wi < wr.size() && wr[wi].sample <= k && wr[wi].reg != 0xff) {
			top->cpu_wr = 1; top->cpu_addr = wr[wi].reg & 0xf; top->cpu_din = wr[wi].data;
			step();
			top->cpu_wr = 0;
			step();
			while (top->dbg_wbusy) step();
			wi++;
		}
		top->test_hold = 0;
		// run until the sample is produced
		uint64_t c0 = cyc;
		for (;;) {
			step();
			top->test_hold = 1;
			if (top->out_strobe) break;
		}
		uint64_t used = cyc - c0;
		if (used > maxcyc) { maxcyc = used; maxk = k; }
		hist[used >= 1024 ? 15 : used / 64]++;
		int16_t lr[2] = { (int16_t)top->out_l, (int16_t)top->out_r };
		fwrite(lr, 2, 2, out);
		k++;
		if ((k % 441000) == 0) fprintf(stderr, "t=%.1fs cycles=%llu stalls=%u lastcyc=%u fetches=%llu\n", k / 44100.0,
			(unsigned long long)cyc, top->dbg_stalls, top->dbg_cycles, (unsigned long long)fetches);
	}
	fclose(out);
	fprintf(stderr, "max engine cycles/sample = %llu at sample %lld (budget 768)\nhistogram (64-cycle bins):", (unsigned long long)maxcyc, (long long)maxk);
	for (int i = 0; i < 16; i++) fprintf(stderr, " %llu", (unsigned long long)hist[i]);
	fprintf(stderr, "\n");
	fprintf(stderr, "done: %lld samples, %llu cycles, stalls=%u fetches=%llu\n", (long long)k, (unsigned long long)cyc, top->dbg_stalls, (unsigned long long)fetches);
	delete top;
	return 0;
}
