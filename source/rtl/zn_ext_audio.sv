// ZN-1 external (game-board) sound system: board selection, PSX bus adapter,
// SDRAM line port and the output mix with the PSX SPU.
//
// Exactly one board is compiled in, chosen by a Verilog macro (one RBF per family,
// see docs/AUDIO_ARCHITECTURE.md):
//   ZN_EXT_AUDIO_RAIZING  board ID 0x10  68000 + YMF271          (rtl/raizing_snd)
//   ZN_EXT_AUDIO_FX1A     board ID 0x1A  Z80 + YM2610B + TC0140SYT (rtl/taito_fx1a)
//   none                  board ID 0x00  PSX SPU only
//
// The board runs only when the MRA selected this board (index 1, byte 1) and
// supplied its program (index 6) and sample (index 7) ROMs; otherwise it is held in
// reset, the PSX window is not forwarded and the SPU passes through unchanged.

module zn_ext_audio (
	input  logic        clk,             // clk_1x, 33.8688 MHz
	input  logic        reset,
	input  logic        pause,
	input  logic  [7:0] mra_board,       // MRA index 1 byte 1
	input  logic        prog_loaded,     // MRA index 6 downloaded
	input  logic        smp_loaded,      // MRA index 7 downloaded

	output logic  [7:0] active_board,    // to memorymux: board ID whose PSX window is forwarded
	output logic        enable,          // board running (owns SDRAM channel 3)

	// PSX bus window (memorymux.vhd)
	input  logic        bus_wr,
	input  logic        bus_rd,
	input  logic [23:0] bus_addr,
	input  logic [31:0] bus_din,
	input  logic  [3:0] bus_be,
	output logic [31:0] bus_dout,
	output logic        bus_ack,

	// SDRAM 16-byte line reads (channel 3)
	output logic        mem_req,
	output logic [26:0] mem_addr,
	input  logic        mem_ack,
	input  logic [127:0] mem_data,

	input  logic [15:0] spu_l,
	input  logic [15:0] spu_r,
	output logic [15:0] out_l,
	output logic [15:0] out_r,

	output logic [127:0] diag,           // 4 x 32-bit words for the debug overlay

	// Simulation: sound-device register write stream and board sample strobe
	// (left unconnected in the core; compared against MAME logs in source/sim)
	output logic        dbg_dev_wr,
	output logic [15:0] dbg_dev_addr,
	output logic [15:0] dbg_dev_data,
	output logic        dbg_sample,
	output logic signed [15:0] dbg_brd_l,
	output logic signed [15:0] dbg_brd_r
);

`ifdef ZN_EXT_AUDIO_RAIZING
localparam [7:0] BOARD = 8'h10;
`elsif ZN_EXT_AUDIO_FX1A
localparam [7:0] BOARD = 8'h1A;
`else
localparam [7:0] BOARD = 8'h00;
`endif

assign enable       = (BOARD != 8'h00) && mra_board == BOARD && prog_loaded && smp_loaded;
assign active_board = enable ? BOARD : 8'h00;

wire rst = reset | ~enable;

// The PSX CPU issues every store word-aligned (cpu.vhd: EXEMemAddr(31:2) & "00"); the
// byte offset of a byte/halfword store is only in the write mask, data stays on its lane.
// Rebuild the byte address of writes from the lowest enabled lane, so the boards see the
// address the game used (FX-1A: an SH to 0x1FB80002 arrives as 0x1FB80000 + mask 1100).
// Reads already carry their byte address.
wire  [1:0] wr_lo  = bus_be[0] ? 2'd0 : bus_be[1] ? 2'd1 : bus_be[2] ? 2'd2 : 2'd3;
wire [23:0] bus_a  = bus_wr ? {bus_addr[23:2], wr_lo} : bus_addr;

logic signed [15:0] brd_l, brd_r;     // board output, full scale = MAME gain 1.0
logic               brd_strobe;       // a new board sample
logic [127:0]       brd_diag;

`ifdef ZN_EXT_AUDIO_RAIZING
// ---------------------------------------------------------------------------
// Raizing / Eighting: PSX 0x1FB00000 = 8-bit latch, 0x1FB00004 = 68000 IRQ2.
// Writes only (memorymux forwards nothing else); reads would answer 0.
// ---------------------------------------------------------------------------
logic [63:0] rz_dbg;
logic        rz_ymf_wr;
logic  [3:0] rz_ymf_addr;
logic  [7:0] rz_ymf_data;
raizing_snd raizing_snd (
	.clk(clk), .reset(reset), .enable(enable), .pause(pause),
	.latch_wr(bus_wr && !bus_a[2]), .latch_din(bus_din[7:0]),
	.irq_wr(bus_wr && bus_a[2]),
	.mem_req(mem_req), .mem_addr(mem_addr), .mem_ack(mem_ack && enable), .mem_data(mem_data),
	.out_l(brd_l), .out_r(brd_r),
	.dbg(rz_dbg),
	.dbg_ymf_wr(rz_ymf_wr), .dbg_ymf_addr(rz_ymf_addr), .dbg_ymf_data(rz_ymf_data), .dbg_sample(brd_strobe),
	.dbg_bus(), .dbg_bstate()
);
assign bus_dout = 32'h0;
always_ff @(posedge clk) bus_ack <= bus_rd;
assign dbg_dev_wr   = rz_ymf_wr;
assign dbg_dev_addr = {12'd0, rz_ymf_addr};
assign dbg_dev_data = {8'd0, rz_ymf_data};
// dbg = {IRQs taken, latch reads, YMF writes, YMF sample overruns}
assign brd_diag = {rz_dbg[63:48], rz_dbg[47:32],      // IRQ2s taken / latch reads
                   rz_dbg[31:16], 16'd0,              // YMF271 register writes
                   rz_dbg[15:0],  16'd0,              // YMF271 sample-slot overruns
                   32'd0};
`elsif ZN_EXT_AUDIO_FX1A
// ---------------------------------------------------------------------------
// Taito FX-1A: PSX 0x1FB80000 = TC0140SYT master port, 0x1FB80002 = master comm.
// ---------------------------------------------------------------------------
logic [127:0] fa_dbg;
logic         fa_ym_wr;
logic   [8:0] fa_ym_addr;
logic   [7:0] fa_ym_data;
taito_fx1a taito_fx1a (
	.clk(clk), .reset(reset), .enable(enable), .pause(pause),
	.bus_wr(bus_wr), .bus_rd(bus_rd), .bus_addr(bus_a[1:0]), .bus_din(bus_din), .bus_dout(bus_dout),
	.mem_req(mem_req), .mem_addr(mem_addr), .mem_ack(mem_ack && enable), .mem_data(mem_data),
	.out_l(brd_l), .out_r(brd_r), .out_strobe(brd_strobe),
	.dbg(fa_dbg), .dbg_ym_wr(fa_ym_wr), .dbg_ym_addr(fa_ym_addr), .dbg_ym_data(fa_ym_data)
);
always_ff @(posedge clk) bus_ack <= bus_rd;
assign dbg_dev_wr   = fa_ym_wr;
assign dbg_dev_addr = {7'd0, fa_ym_addr};
assign dbg_dev_data = {8'd0, fa_ym_data};
// fa_dbg = {PSX comm writes, Z80 comm reads, YM writes, Z80 line fetches, ADPCM line fetches, 0, Z80 A, bank}
assign brd_diag = {fa_dbg[127:112], fa_dbg[111:96],    // commands sent / commands read
                   fa_dbg[95:80], 16'd0,               // YM2610B register writes
                   32'd0,
                   32'd0};
`else
assign brd_l = '0; assign brd_r = '0; assign brd_strobe = 1'b0;
assign mem_req = 1'b0; assign mem_addr = '0;
assign bus_dout = 32'h0;
always_ff @(posedge clk) bus_ack <= bus_rd;
assign brd_diag = '0;
assign dbg_dev_wr = 1'b0; assign dbg_dev_addr = '0; assign dbg_dev_data = '0;
`endif
assign dbg_sample = brd_strobe;
assign dbg_brd_l  = brd_l;
assign dbg_brd_r  = brd_r;

// ---------------------------------------------------------------------------
// Output mix. MAME speaker routes (zn.cpp):
//   Raizing : SPU 0.35, YMF271 1.0        -> SPU*45/64 + EXT*2   (+6 dB overall,
//             the hardware-proven Brave Blade balance; loudest passages ~-3 dBFS)
//   FX-1A   : SPU 0.35, YM2610B 1.0 (SSG 0.75, mixed inside the board)
// The sum saturates. Without an active board the SPU passes through bit-exactly.
// ---------------------------------------------------------------------------
// Shift-add only: the PSX core already uses 108 of the 112 DSP blocks.
function automatic logic signed [24:0] spu_gain(input logic [15:0] spu);
	logic signed [24:0] x;
	x = $signed({{9{spu[15]}}, spu});
	spu_gain = (x <<< 5) + (x <<< 3) + (x <<< 2) + x;      // * 45  (45/128 = 0.352 ~ 0.35)
endfunction

function automatic logic [15:0] sat16(input logic signed [24:0] v);
	sat16 = (v > 25'sd32767) ? 16'h7FFF : (v < -25'sd32768) ? 16'h8000 : v[15:0];
endfunction

// (SPU*gain + EXT*128) / 64
wire signed [24:0] sum_l  = (spu_gain(spu_l) + ($signed({{9{brd_l[15]}}, brd_l}) <<< 7)) >>> 6;
wire signed [24:0] sum_r  = (spu_gain(spu_r) + ($signed({{9{brd_r[15]}}, brd_r}) <<< 7)) >>> 6;
wire        [15:0] mix_l  = sat16(sum_l);
wire        [15:0] mix_r  = sat16(sum_r);
wire               clip_l = sum_l > 25'sd32767 || sum_l < -25'sd32768;
wire               clip_r = sum_r > 25'sd32767 || sum_r < -25'sd32768;

always_ff @(posedge clk) begin
	out_l <= enable ? mix_l : spu_l;
	out_r <= enable ? mix_r : spu_r;
end

// ---------------------------------------------------------------------------
// Passive diagnostics (debug overlay rows). Sticky/saturating counters.
//   word 0: [31:16] PSX commands to the board, [15:0] board-side command reads
//   word 1: [31:16] sound-device register writes, [15:0] SDRAM line fetches
//   word 2: [31:16] sample FIFO underruns/overruns, [15:0] mixer clip events
//   word 3: [31:24] board ID, [23] enabled, [22] prog, [21] samples, [20:16] 0,
//           [15:8] heartbeat (board sample counter / 2^10), [7:0] 0
// ---------------------------------------------------------------------------
logic [15:0] d_fetch, d_clip;
logic [25:0] d_samples;
always_ff @(posedge clk) begin
	if (rst) begin
		d_fetch <= '0; d_clip <= '0; d_samples <= '0;
	end else begin
		if (mem_ack && d_fetch != 16'hFFFF) d_fetch <= d_fetch + 1'd1;
		if ((clip_l || clip_r) && brd_strobe && d_clip != 16'hFFFF) d_clip <= d_clip + 1'd1;
		if (brd_strobe) d_samples <= d_samples + 1'd1;
	end
end
assign diag = {brd_diag[127:96],
               brd_diag[95:80], d_fetch,
               brd_diag[63:48], d_clip,
               BOARD, enable, prog_loaded, smp_loaded, 5'd0, d_samples[17:10], 8'd0};

endmodule
