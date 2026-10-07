// Replay a captured YMF271 register log through a model and write stereo output.
// usage: replay <model: mame|fx> <ymf_writes.txt> <samplerom.bin> <out.wav> [t_start t_end]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include "ymf_mame.h"
#include "ymf_fx.h"

static std::vector<uint8_t> rom;
static uint8_t rd(uint32_t a) { return rom[a & (rom.size() - 1)]; }

static void wr16(FILE *f, uint16_t v) { fwrite(&v, 2, 1, f); }
static void wr32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }
static void write_wav(const char *fn, const std::vector<int16_t> &s) {
	FILE *f = fopen(fn, "wb");
	uint32_t n = s.size() * 2;
	fwrite("RIFF", 1, 4, f); wr32(f, 36 + n); fwrite("WAVEfmt ", 1, 8, f);
	wr32(f, 16); wr16(f, 1); wr16(f, 2); wr32(f, 44100); wr32(f, 44100 * 4); wr16(f, 4); wr16(f, 16);
	fwrite("data", 1, 4, f); wr32(f, n); fwrite(s.data(), 2, s.size(), f); fclose(f);
}
static int16_t clamp16(int64_t v) { return v > 32767 ? 32767 : v < -32768 ? -32768 : (int16_t)v; }

int main(int argc, char **argv) {
	if (argc < 5) { fprintf(stderr, "usage\n"); return 1; }
	std::string model = argv[1];
	FILE *rf = fopen(argv[3], "rb"); fseek(rf, 0, SEEK_END); rom.resize(ftell(rf)); fseek(rf, 0, SEEK_SET);
	fread(rom.data(), 1, rom.size(), rf); fclose(rf);
	double t_end = argc > 6 ? atof(argv[6]) : 1e9;

	mame_ymf::ymf271 mame; mame.read_byte = rd;
	ymf_fx::ymf271 fx; fx.read_byte = rd;
	if (getenv("DBG_FROM")) { fx.dbg_from = atoll(getenv("DBG_FROM")); fx.dbg_to = atoll(getenv("DBG_TO")); }

	std::vector<int16_t> out; std::vector<int32_t> raw;
	int64_t produced = 0;
	int32_t mix[4 * 4096];
	auto gen = [&](int64_t upto) {
		while (produced < upto) {
			int n = (int)std::min<int64_t>(upto - produced, 4096);
			if (model == "mame") mame.update(n, mix); else fx.update(n, mix);
			for (int i = 0; i < n; i++) {
				raw.push_back(mix[i * 4 + 0]); raw.push_back(mix[i * 4 + 1]);
				out.push_back(clamp16(mix[i * 4 + 0] >> 2)); out.push_back(clamp16(mix[i * 4 + 1] >> 2));
			}
			produced += n;
		}
	};
	FILE *lf = fopen(argv[2], "r");
	char line[256];
	double last_t = 0;
	while (fgets(line, sizeof line, lf)) {
		double t; char rw; unsigned reg, data;
		if (sscanf(line, "%lf %c %x %x", &t, &rw, &reg, &data) != 4) continue;
		if (t > t_end) break;
		last_t = t;
		if (rw != 'W') continue;
		gen((int64_t)(t * 44100.0));
		if (model == "mame") mame.write(reg, data); else fx.write(reg, data);
	}
	gen((int64_t)(std::min(last_t, t_end) * 44100.0));
	write_wav(argv[4], out);
	std::string rawfn = std::string(argv[4]) + ".raw";
	FILE *o = fopen(rawfn.c_str(), "wb"); fwrite(raw.data(), 4, raw.size(), o); fclose(o);
	fprintf(stderr, "%s: %lld samples\n", model.c_str(), (long long)produced);
	return 0;
}
