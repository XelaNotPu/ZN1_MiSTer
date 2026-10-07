// Yamaha YMF271-F "OPX" - sequential implementation for the Raizing/Eighting
// ZN-1 sound board (Brave Blade).
//
// Behavioural reference: MAME 0.289 src/devices/sound/ymf271.cpp
// (BSD-3-Clause; Olivier Galibert, R. Belmont, hap). Integer arithmetic,
// envelope/LFO/step semantics, slot/group mapping, sync-register broadcast,
// status/end flags and timers follow that model. The ROM tables are generated
// with MAME's own expressions (tools/ymf271 table generator, *.hex here).
//
// Architecture
//   clk is clk_1x (33.8688 MHz) = 2 x the 16.9344 MHz chip clock, so one
//   44.1 kHz output sample is exactly 768 clk. Each sample the engine walks
//   the 12 groups; every group runs a short op program chosen by
//   (sync mode, algorithm): 4-op / 2x2-op / 3-op FM, and PCM. One 18x18
//   multiplier is time-shared (one product per clock).
//   Slot registers live in a byte-enabled RAM written by a CPU write queue;
//   dynamic slot state lives in a second RAM owned by the engine. Key on/off
//   are posted as per-slot flags and applied on the slot's next visit
//   (<= 1 sample later).
//   PCM samples are read from 16-byte lines held in a 2-line (even/odd line)
//   buffer per PCM slot, filled through fetch_req/fetch_ack, with a one-line
//   prefetch so sequential playback does not stall the engine.
//
// Not implemented (also unimplemented/TODO in MAME): PFM, detune, alternate
// loop, Acc On, EXT out, external-memory read-back (reg 2 reads 0xFF), PCM on
// groups whose index is not a multiple of 4 (they have no PCM address regs).
// LFO pitch modulation uses 1 + ln2*cents*p/1200 instead of pow().

module ymf271 #(
	parameter HEXDIR = "rtl/raizing_snd/"
) (
	input  logic        clk,
	input  logic        reset,
	input  logic        pause,          // freeze the sample clock and the timers

	input  logic        cpu_wr,
	input  logic  [3:0] cpu_addr,
	input  logic  [7:0] cpu_din,
	output logic  [7:0] cpu_dout,

	output logic        fetch_req,
	output logic [17:0] fetch_line,     // 16-byte line index within the 4 MiB sample ROM
	input  logic        fetch_ack,      // one-cycle pulse, fetch_data valid
	input  logic [127:0] fetch_data,    // byte k of the line in [8k+7:8k]

	output logic signed [15:0] out_l,
	output logic signed [15:0] out_r,
	output logic        out_strobe,

	input  logic        test_hold,      // testbench only: do not start a new sample (tie 0)
	input  logic        test_fast,      // testbench only: start samples back to back (tie 0)
	output logic        dbg_wbusy,      // register write queue / processor busy

	output logic [15:0] dbg_overruns,
	output logic [15:0] dbg_stalls,
	output logic  [9:0] dbg_cycles      // engine clocks used by the last sample
);

// ---------------------------------------------------------------------------
// ROM tables (synchronous read: address this clock, data next clock)
// ---------------------------------------------------------------------------
logic [15:0] rom_qwave  [0:1023];
logic [19:0] rom_envvol [0:255];
logic [19:0] rom_tl     [0:127];
logic [23:0] rom_envstep[0:2047];
logic [11:0] rom_lfostep[0:255];
logic [11:0] rom_plfosaw[0:255];
initial begin
	$readmemh({HEXDIR, "ymf_qwave.hex"},   rom_qwave);
	$readmemh({HEXDIR, "ymf_envvol.hex"},  rom_envvol);
	$readmemh({HEXDIR, "ymf_tl.hex"},      rom_tl);
	$readmemh({HEXDIR, "ymf_envstep.hex"}, rom_envstep);
	$readmemh({HEXDIR, "ymf_lfostep.hex"}, rom_lfostep);
	$readmemh({HEXDIR, "ymf_plfosaw.hex"}, rom_plfosaw);
end

logic  [9:0] qwave_a;   logic [15:0] qwave_q;
logic  [7:0] envvol_a;  logic [16:0] envvol_q;
logic  [6:0] tl_a;      logic [16:0] tl_q;
logic [10:0] envstep_a; logic [22:0] envstep_q;
logic  [7:0] lfostep_a; logic  [9:0] lfostep_q;
logic  [7:0] saw_a;     logic  [9:0] saw_q;
always_ff @(posedge clk) begin
	qwave_q   <= rom_qwave[qwave_a];
	envvol_q  <= rom_envvol[envvol_a][16:0];
	tl_q      <= rom_tl[tl_a][16:0];
	envstep_q <= rom_envstep[envstep_a][22:0];
	lfostep_q <= rom_lfostep[lfostep_a][9:0];
	saw_q     <= rom_plfosaw[saw_a][9:0];
end

function automatic [16:0] att_lut(input [3:0] l);
	case (l)
		4'd0: att_lut = 17'd65536;  4'd1: att_lut = 17'd49145;  4'd2: att_lut = 17'd32845;  4'd3: att_lut = 17'd24630;
		4'd4: att_lut = 17'd16461;  4'd5: att_lut = 17'd12344;  4'd6: att_lut = 17'd8156;   4'd7: att_lut = 17'd6116;
		4'd8: att_lut = 17'd4087;   4'd9: att_lut = 17'd3065;   4'd10: att_lut = 17'd2048;  4'd11: att_lut = 17'd1536;
		4'd12: att_lut = 17'd1026;  default: att_lut = 17'd1;
	endcase
endfunction

function automatic signed [17:0] u17(input [16:0] v); u17 = {1'b0, v}; endfunction
function automatic signed [15:0] sat16(input signed [31:0] v);
	if (v > 32'sd32767) sat16 = 16'sd32767;
	else if (v < -32'sd32768) sat16 = 16'h8000;
	else sat16 = v[15:0];
endfunction

// slot number j + 12*b without a multiplier
function automatic [5:0] slot_of(input [3:0] j, input [1:0] b);
	slot_of = {2'b00, j} + {1'b0, b, 3'b000} + {2'b00, b, 2'b00};
endfunction

// f * m for the phase-step mantissa (12 x 5 bit, shift-add)
function automatic [16:0] mul12x5(input [11:0] f, input [4:0] m);
	mul12x5 = (m[0] ? {5'd0, f} : 17'd0) + (m[1] ? {4'd0, f, 1'b0} : 17'd0) + (m[2] ? {3'd0, f, 2'b0} : 17'd0) +
	          (m[3] ? {2'd0, f, 3'b0} : 17'd0) + (m[4] ? {1'd0, f, 4'b0} : 17'd0);
endfunction

// signed p (10 bit) * unsigned k (12 bit), shift-add
function automatic signed [22:0] mul_pk(input signed [9:0] p, input [11:0] k);
	logic signed [22:0] acc;
	acc = '0;
	for (int i = 0; i < 12; i++) if (k[i]) acc = acc + ($signed({{13{p[9]}}, p}) <<< i);
	mul_pk = acc;
endfunction

// MAME RKS_Table[keycode][keyscale]
function automatic [4:0] rks_lut(input [4:0] kc, input [2:0] ks);
	case (ks)
		3'd0: rks_lut = 5'd0;
		3'd1: rks_lut = {3'b000, kc[4:3]};
		3'd2: rks_lut = {2'b00, kc[4:2]};
		3'd3: rks_lut = {1'b0, kc[4:1]};
		3'd4: rks_lut = kc;
		3'd5: rks_lut = (kc >= 5'd29) ? 5'd31 : kc + 5'd2;
		3'd6: rks_lut = (kc >= 5'd27) ? 5'd31 : kc + 5'd4;
		default: rks_lut = (kc >= 5'd23) ? 5'd31 : kc + 5'd8;
	endcase
endfunction

function automatic [5:0] ksr(input [6:0] rate, input [4:0] kc, input [2:0] ks);
	logic [7:0] r;
	r = {1'b0, rate} + {3'b000, rks_lut(kc, ks)};
	ksr = (r > 8'd63) ? 6'd63 : r[5:0];
endfunction

// fm_tab: address low nibble -> group (4'hF = invalid)
function automatic [3:0] fm_tab(input [3:0] a);
	case (a)
		4'd0: fm_tab = 4'd0;  4'd1: fm_tab = 4'd1;  4'd2: fm_tab = 4'd2;
		4'd4: fm_tab = 4'd3;  4'd5: fm_tab = 4'd4;  4'd6: fm_tab = 4'd5;
		4'd8: fm_tab = 4'd6;  4'd9: fm_tab = 4'd7;  4'd10: fm_tab = 4'd8;
		4'd12: fm_tab = 4'd9; 4'd13: fm_tab = 4'd10; 4'd14: fm_tab = 4'd11;
		default: fm_tab = 4'hF;
	endcase
endfunction

// modulation_level[fb] = {16,8,4,2,1,32,64,128} as a left shift
function automatic [2:0] modsh(input [2:0] f);
	case (f) 3'd0: modsh = 3'd4; 3'd1: modsh = 3'd3; 3'd2: modsh = 3'd2; 3'd3: modsh = 3'd1;
	         3'd4: modsh = 3'd0; 3'd5: modsh = 3'd5; 3'd6: modsh = 3'd6; default: modsh = 3'd7; endcase
endfunction

// ---------------------------------------------------------------------------
// Op programs. op = {bank[1:0], insel[2:0], dst[1:0], out}
// insel: 0 none, 1 feedback, 2 r1, 3 r2, 4 r3, 5 r1+r3, 6 r1+r2, 7 r3+r2
// dst:   0 none, 1 r1, 2 r2, 3 r3 ; out: op output goes to the mix
// prog = {fbsrc_is_r3, nops[2:0], op3, op2, op1, op0}
// ---------------------------------------------------------------------------
localparam [2:0] IN_NONE = 3'd0, IN_FB = 3'd1, IN_R1 = 3'd2, IN_R2 = 3'd3, IN_R3 = 3'd4,
                 IN_R1R3 = 3'd5, IN_R1R2 = 3'd6, IN_R3R2 = 3'd7;

function automatic [7:0] OPE(input [1:0] b, input [2:0] i, input [1:0] d, input o);
	OPE = {b, i, d, o};
endfunction

function automatic [35:0] prog(input [1:0] mode, input [3:0] alg);
	logic [7:0] s1, s1o;
	s1  = OPE(2'd0, IN_FB, 2'd1, 1'b0);
	s1o = OPE(2'd0, IN_FB, 2'd1, 1'b1);
	prog = 36'd0;
	case (mode)
	2'd0: case (alg) // 4-op: S1 bank0, S2 bank1, S3 bank2, S4 bank3
		4'd0:  prog = {1'b0, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_R3,2,0),   OPE(2,IN_R1,3,0),   s1};
		4'd1:  prog = {1'b1, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_R3,2,0),   OPE(2,IN_R1,3,0),   s1};
		4'd2:  prog = {1'b0, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_R1R3,2,0), OPE(2,IN_NONE,3,0), s1};
		4'd3:  prog = {1'b0, 3'd4, OPE(3,IN_R1R2,0,1), OPE(1,IN_R3,2,0),   OPE(2,IN_NONE,3,0), s1};
		4'd4:  prog = {1'b0, 3'd4, OPE(3,IN_R3R2,0,1), OPE(1,IN_NONE,2,0), OPE(2,IN_R1,3,0),   s1};
		4'd5:  prog = {1'b1, 3'd4, OPE(3,IN_R3R2,0,1), OPE(1,IN_NONE,2,0), OPE(2,IN_R1,3,0),   s1};
		4'd6:  prog = {1'b0, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_NONE,2,0), OPE(2,IN_R1,0,1),   s1};
		4'd7:  prog = {1'b1, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_NONE,2,0), OPE(2,IN_R1,3,1),   s1};
		4'd8:  prog = {1'b0, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_R3,2,0),   OPE(2,IN_NONE,3,0), s1o};
		4'd9:  prog = {1'b0, 3'd4, OPE(3,IN_R3R2,0,1), OPE(1,IN_NONE,2,0), OPE(2,IN_NONE,3,0), s1o};
		4'd10: prog = {1'b0, 3'd4, OPE(3,IN_NONE,0,1), OPE(1,IN_NONE,0,1), OPE(2,IN_R1,0,1),   s1};
		4'd11: prog = {1'b1, 3'd4, OPE(3,IN_NONE,0,1), OPE(1,IN_NONE,0,1), OPE(2,IN_R1,3,1),   s1};
		4'd12: prog = {1'b0, 3'd4, OPE(3,IN_R1,0,1),   OPE(1,IN_R1,0,1),   OPE(2,IN_R1,0,1),   s1};
		4'd13: prog = {1'b0, 3'd4, OPE(3,IN_NONE,0,1), OPE(1,IN_R3,0,1),   OPE(2,IN_NONE,3,0), s1o};
		4'd14: prog = {1'b0, 3'd4, OPE(3,IN_R2,0,1),   OPE(1,IN_NONE,2,0), OPE(2,IN_R1,0,1),   s1o};
		default: prog = {1'b0, 3'd4, OPE(3,IN_NONE,0,1), OPE(1,IN_NONE,0,1), OPE(2,IN_NONE,0,1), s1o};
	endcase
	2'd1: case (alg[1:0]) // 2x 2-op: S1 bank0(+pair), S3 bank2(+pair)
		2'd0: prog = {1'b0, 3'd2, 16'd0, OPE(2,IN_R1,0,1),   s1};
		2'd1: prog = {1'b1, 3'd2, 16'd0, OPE(2,IN_R1,3,1),   s1};
		2'd2: prog = {1'b0, 3'd2, 16'd0, OPE(2,IN_NONE,0,1), s1o};
		default: prog = {1'b0, 3'd2, 16'd0, OPE(2,IN_R1,0,1), s1o};
	endcase
	2'd2: case (alg[2:0]) // 3-op (+ PCM on bank 3)
		3'd0: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_R3,0,1),   OPE(2,IN_R1,3,0),   s1};
		3'd1: prog = {1'b1, 3'd3, 8'd0, OPE(1,IN_R3,0,1),   OPE(2,IN_R1,3,0),   s1};
		3'd2: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_R1R3,0,1), OPE(2,IN_NONE,3,0), s1};
		3'd3: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_R3,0,1),   OPE(2,IN_NONE,3,0), s1o};
		3'd4: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_NONE,0,1), OPE(2,IN_R1,0,1),   s1};
		3'd5: prog = {1'b1, 3'd3, 8'd0, OPE(1,IN_NONE,0,1), OPE(2,IN_R1,3,1),   s1};
		3'd6: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_NONE,0,1), OPE(2,IN_NONE,0,1), s1o};
		default: prog = {1'b0, 3'd3, 8'd0, OPE(1,IN_NONE,0,1), OPE(2,IN_R1,0,1), s1o};
	endcase
	default: prog = 36'd0;
	endcase
endfunction

// ---------------------------------------------------------------------------
// Slot register RAM: 24 byte lanes per slot (byte-enabled writes)
//  0 lfofreq  1 lfo(wave/pms/ams)  2 mult  3 tl  4 ar/ks  5 d1r  6 d2r  7 rr/d1l
//  8 fns low  9 block/fns high (captured at fns-low write)  10 wave/fb  11 alg
// 12 lvl0/lvl1  13 lvl2/lvl3  14-16 start  17-19 end  20-22 loop  23 pcm fs/bits
// ---------------------------------------------------------------------------
logic  [5:0] rr_raddr;
logic [23:0][7:0] rr_q;
logic        rw_we;
logic  [5:0] rw_addr;
logic [23:0] rw_be;
logic [23:0][7:0] rw_data;
genvar gi;
generate
	for (gi = 0; gi < 6; gi = gi + 1) begin : g_regram
		ymf_regram ram (
			.clk(clk), .we(rw_we), .waddr(rw_addr), .be(rw_be[gi*4 +: 4]),
			.wdata({rw_data[gi*4+3], rw_data[gi*4+2], rw_data[gi*4+1], rw_data[gi*4]}),
			.raddr(rr_raddr),
			.q({rr_q[gi*4+3], rr_q[gi*4+2], rr_q[gi*4+1], rr_q[gi*4]})
		);
	end
endgenerate

// ---------------------------------------------------------------------------
// Slot state RAM (engine private)
// ---------------------------------------------------------------------------
typedef struct packed {
	logic  [1:0] env;       // 0 attack 1 decay1 2 decay2 3 release
	logic [23:0] vol;       // 8.16, 0 .. 255<<16
	logic  [5:0] r_ar, r_d1, r_d2, r_rr;
	logic  [3:0] d1l_k;
	logic [39:0] ptr;       // PCM 24.16 ; FM phase in [25:0]
	logic [15:0] lfo;
} sstate_t;
localparam SW = $bits(sstate_t);
logic [SW-1:0] stram [0:63];
logic  [5:0] st_raddr, st_waddr;
logic        st_we;
sstate_t     st_q, st_wdata;
always_ff @(posedge clk) begin
	if (st_we) stram[st_waddr] <= st_wdata;
	st_q <= stram[st_raddr];
end

// feedback RAM: {fb0, fb1} (27-bit signed each; used by group leaders)
logic [53:0] fbram [0:63];
logic  [5:0] fb_waddr;
logic        fb_we;
logic [53:0] fb_q, fb_wdata;
always_ff @(posedge clk) begin
	if (fb_we) fbram[fb_waddr] <= fb_wdata;
	fb_q <= fbram[st_raddr];
end

// ---------------------------------------------------------------------------
// PCM line buffers: index pslot = {bank[1:0], group[3:2]}, parity = line[0]
// ---------------------------------------------------------------------------
logic [127:0] lb0 [0:15];
logic [127:0] lb1 [0:15];
logic   [3:0] lb_raddr;
logic [127:0] lb0_q, lb1_q;
logic  [17:0] lb_tag0 [0:15];
logic  [17:0] lb_tag1 [0:15];
logic  [15:0] lb_valid0, lb_valid1, lb_pend0, lb_pend1;

localparam FQ = 16;
logic [22:0] fq [0:FQ-1];          // {pslot, par, line}
logic  [3:0] fq_wp, fq_rp;
logic  [4:0] fq_cnt;
wire         fq_full = fq_cnt == FQ;
wire  [22:0] fq_head = fq[fq_rp];
assign fetch_req  = fq_cnt != 0;
assign fetch_line = fq_head[17:0];
wire   [3:0] fill_pslot = fq_head[22:19];
wire         fill_par   = fq_head[18];

always_ff @(posedge clk) begin
	if (fetch_ack) begin
		if (fill_par) lb1[fill_pslot] <= fetch_data;
		else          lb0[fill_pslot] <= fetch_data;
	end
	lb0_q <= lb0[lb_raddr];
	lb1_q <= lb1[lb_raddr];
end

// ---------------------------------------------------------------------------
// CPU interface state
// ---------------------------------------------------------------------------
logic [7:0] areg [0:7];
localparam WQ = 16;
logic [18:0] wq [0:WQ-1];          // {offset[3:1], address, data}
logic  [3:0] wq_wp, wq_rp;
logic  [4:0] wq_cnt;

logic  [9:0] timer_a;
logic  [7:0] timer_b;
logic  [7:0] tctl;
logic  [1:0] tflag;
logic        ta_run, tb_run;
logic [19:0] ta_cnt;
logic [21:0] tb_cnt;

logic [47:0] active, kon, koff;
logic  [3:0] alg_r    [0:47];
logic  [1:0] gsync    [0:11];
logic [11:0] end_status;

logic        wf_busy;
logic  [7:0] wf_a, wf_d;
logic  [3:0] wf_banks, wf_grp, wf_reg;
logic  [1:0] wf_b;
wire busy = wq_cnt != 0;
// timer periods in clk: A = 768*(1024-TA), B = 12288*(256-TB)
wire [10:0] ta_n = 11'd1024 - {1'b0, timer_a};
wire  [8:0] tb_n = 9'd256 - {1'b0, timer_b};
wire [19:0] ta_period = {ta_n[9:0], 9'd0} + {1'b0, ta_n[9:0], 8'd0} + (ta_n[10] ? 20'd786432 : 20'd0);
wire [21:0] tb_period = {tb_n, 13'd0} + {1'b0, tb_n, 12'd0};
assign dbg_wbusy = busy | wf_busy;

// FNS-high/block register (reg A) per slot, only read when reg 9 is written.
// Small RAM; its read address runs one bank ahead of the write-processor loop.
logic [7:0] fnshi_ram [0:63];
logic [5:0] fnshi_ra;
logic [7:0] fnshi_q;
wire        fnshi_we = wf_busy && wf_banks[wf_b] && wf_reg == 4'd10;
always_comb fnshi_ra = wf_busy ? slot_of(wf_grp, wf_b + 2'd1) : slot_of(fm_tab(wq[wq_rp][11:8]), 2'd0);
always_ff @(posedge clk) begin
	if (fnshi_we) fnshi_ram[slot_of(wf_grp, wf_b)] <= wf_d;
	fnshi_q <= fnshi_ram[fnshi_ra];
end
always_comb begin
	case (cpu_addr)
		// busy (bit 7) reads 0 like MAME: the write queue drains faster than the 68000 can write
		4'd0:    cpu_dout = {1'b0, end_status[3:0], 1'b0, tflag};
		4'd1:    cpu_dout = end_status[11:4];
		default: cpu_dout = 8'hFF;
	endcase
end

// ---------------------------------------------------------------------------
// Engine state
// ---------------------------------------------------------------------------
typedef enum logic [4:0] {
	E_IDLE, E_GROUP, E_RD, E_A, E_B, E_C, E_D, E_E, E_F, E_G, E_H, E_I, E_J, E_K, E_L, E_UEND, E_DONE
} estate_t;
estate_t es;

logic  [9:0] tick_cnt;
logic        tick_pend;
logic  [9:0] cyc;
logic  [3:0] g_j;
logic  [3:0] u_j;          // group of the unit being processed
logic  [2:0] g_step;
logic        u_pcm;
logic  [1:0] u_bank;       // bank of the current PCM slot / pair offset of an FM unit
logic  [2:0] u_op;
logic [35:0] u_prog;
logic  [5:0] s_idx;        // slot whose RAM words are being read
logic  [5:0] s_cur;        // slot being processed / written back
logic  [2:0] u_fbsh;       // leader's feedback shift (+1; 0 = feedback level 0)
logic signed [26:0] u_fb1_old;
logic signed [31:0] mix0, mix1;
logic signed [35:0] acc0, acc1;
logic signed [16:0] r1, r2, r3;

// working registers of the current slot step
logic [23:0][7:0] R;
sstate_t     W;
logic signed [26:0] w_fb0, w_fb1;
logic [23:0] vol_n;
logic  [1:0] env_n;
logic        act_n;
logic [15:0] lfo_n;
logic [22:0] a0;
logic  [9:0] widx;
logic        wv_neg, wv_zero, wv_max;
logic signed [16:0] wv;
logic signed [15:0] smp;
logic [16:0] amp, env_vol_r, tl_r, am, ev, vol, cv0, cv1;
logic [15:0] amk;
logic [16:0] pm;
logic [16:0] mant;
logic signed [5:0] sh;
logic [29:0] step;
logic signed [16:0] opout;
logic signed [35:0] P;
logic signed [17:0] ma, mb;

always_ff @(posedge clk) P <= ma * mb;

// decoded register fields of the current slot (from R)
wire  [7:0] f_lfofreq = R[0];
wire  [1:0] f_lfowave = R[1][1:0];
wire  [2:0] f_pms     = R[1][5:3];
wire  [1:0] f_ams     = R[1][7:6];
wire  [3:0] f_mult    = R[2][3:0];
wire  [6:0] f_tl      = R[3][6:0];
wire  [3:0] f_d1l     = R[7][7:4];
wire [11:0] f_fns     = {R[9][3:0], R[8]};
wire  [3:0] f_block   = R[9][7:4];
wire  [2:0] f_wave    = R[10][2:0];
wire  [2:0] f_fb      = R[10][6:4];
wire  [3:0] f_lvl0    = R[12][7:4];
wire  [3:0] f_lvl1    = R[12][3:0];
wire [22:0] f_start   = {R[16][6:0], R[15], R[14]};
wire [22:0] f_end     = {R[19][6:0], R[18], R[17]};
wire [22:0] f_loop    = {R[22][6:0], R[21], R[20]};
wire  [1:0] f_fs      = R[23][1:0];
wire        f_bits12  = R[23][2];

wire  [7:0] cur_op  = u_prog[u_op*8 +: 8];
wire  [1:0] op_bank = cur_op[7:6];
wire  [2:0] op_in   = cur_op[5:3];
wire  [1:0] op_dst  = cur_op[2:1];
wire        op_out  = cur_op[0];
wire  [2:0] u_nops  = u_prog[34:32];
wire        u_fbr3  = u_prog[35];

wire  [3:0] pslot = {u_bank, u_j[3:2]};

// key-on rate latch, decoded straight from the register RAM output
function automatic [27:0] kon_rates(input [23:0][7:0] q);
	logic [11:0] fns;
	logic [10:0] f11;
	logic [4:0]  kc;
	fns = {q[9][3:0], q[8]};
	f11 = fns[10:0];
	if (q[10][2:0] == 3'd7)
		kc = {q[9][6:4], (f11 < 11'h100) ? 2'd0 : (f11 < 11'h300) ? 2'd1 : (f11 < 11'h500) ? 2'd2 : 2'd3};
	else
		kc = {q[9][6:4], (fns < 12'h780) ? 2'd0 : (fns < 12'h900) ? 2'd1 : (fns < 12'hA80) ? 2'd2 : 2'd3};
	kon_rates = { ksr({1'b0, q[4][4:0], 1'b0}, kc, q[4][7:5]),
	              ksr({1'b0, q[5][4:0], 1'b0}, kc, q[4][7:5]),
	              ksr({1'b0, q[6][4:0], 1'b0}, kc, q[4][7:5]),
	              ksr({1'b0, q[7][3:0], 2'b00}, kc, q[4][7:5]),
	              q[7][7:4] };
endfunction

// op input (unscaled) from unit registers
logic signed [17:0] in_sum;
always_comb begin
	case (op_in)
		IN_R1:   in_sum = r1;
		IN_R2:   in_sum = r2;
		IN_R3:   in_sum = r3;
		IN_R1R3: in_sum = r1 + r3;
		IN_R1R2: in_sum = r1 + r2;
		IN_R3R2: in_sum = r3 + r2;
		default: in_sum = '0;
	endcase
end
logic signed [27:0] fb_sum;
assign fb_sum = w_fb0 + w_fb1;
logic signed [40:0] in_sh;
assign in_sh = $signed(in_sum) <<< (5'd8 + {2'b00, modsh(f_fb)});
wire [25:0] in26 = (op_in == IN_FB) ? fb_sum[26:1] : in_sh[25:0];

// line checks for the current PCM slot
wire [21:0] a0m = a0[21:0];
wire [21:0] a1m = a0[21:0] + 22'd1;
wire [17:0] ln0 = a0m[21:4];
wire [17:0] ln1 = f_bits12 ? a1m[21:4] : a0m[21:4];
wire [17:0] tagA0 = ln0[0] ? lb_tag1[pslot] : lb_tag0[pslot];
wire [17:0] tagA1 = ln1[0] ? lb_tag1[pslot] : lb_tag0[pslot];
wire        vA0   = ln0[0] ? lb_valid1[pslot] : lb_valid0[pslot];
wire        vA1   = ln1[0] ? lb_valid1[pslot] : lb_valid0[pslot];
wire        pA0   = ln0[0] ? lb_pend1[pslot]  : lb_pend0[pslot];
wire        pA1   = ln1[0] ? lb_pend1[pslot]  : lb_pend0[pslot];
wire        hit0  = vA0 && tagA0 == ln0;
wire        hit1  = vA1 && tagA1 == ln1;
wire [17:0] pf_line = ln0 + 18'd1;
wire [17:0] tagPF = pf_line[0] ? lb_tag1[pslot] : lb_tag0[pslot];
wire        vPF   = pf_line[0] ? lb_valid1[pslot] : lb_valid0[pslot];
wire        pPF   = pf_line[0] ? lb_pend1[pslot]  : lb_pend0[pslot];

function automatic [7:0] lbyte(input [127:0] q0, input [127:0] q1, input [21:0] a);
	logic [127:0] q;
	q = a[4] ? q1 : q0;
	lbyte = q[a[3:0]*8 +: 8];
endfunction
wire  [7:0] sbyte0 = lbyte(lb0_q, lb1_q, a0m);
wire  [7:0] sbyte1 = lbyte(lb0_q, lb1_q, a1m);

// next-state of the slot being latched in E_A (key on/off applied)
sstate_t st_n;
always_comb begin
	st_n = st_q;
	if (kon[s_idx]) begin
		st_n.env = 2'd0; st_n.vol = 24'd95 << 16; st_n.ptr = '0; st_n.lfo = '0;
		{st_n.r_ar, st_n.r_d1, st_n.r_d2, st_n.r_rr, st_n.d1l_k} = kon_rates(rr_q);
	end
	if (koff[s_idx] && (active[s_idx] || kon[s_idx])) st_n.env = 2'd3;
end

// ---------------------------------------------------------------------------
// Combinational addresses / multiplier operands per engine state
// ---------------------------------------------------------------------------
always_comb begin
	rr_raddr  = s_idx;
	st_raddr  = s_idx;
	lb_raddr  = pslot;
	envstep_a = st_n.env == 2'd0 ? {5'b10000, st_n.r_ar} :
	            st_n.env == 2'd1 ? {1'b0, st_n.d1l_k, st_n.r_d1} :
	            st_n.env == 2'd2 ? {5'b10001, st_n.r_d2} : {5'b10001, st_n.r_rr};
	lfostep_a = rr_q[0];
	envvol_a  = 8'd255 - vol_n[23:16];
	tl_a      = f_tl;
	saw_a     = lfo_n[15:8];
	// quarter-wave address for the current op
	begin
		logic [9:0] i2;
		logic [9:0] ii;
		logic [1:0] tsel;
		i2 = {widx[8:0], 1'b0};
		ii = (f_wave == 3'd4 || f_wave == 3'd5) ? i2 : widx;
		tsel = (f_wave == 3'd1) ? (widx[9] ? 2'd2 : 2'd1) : 2'd0;
		qwave_a = {tsel, ii[8] ? ~ii[7:0] : ii[7:0]};
	end

	ma = '0; mb = '0;
	case (es)
		E_D: begin ma = u17(amp); mb = {2'b00, amk}; end                         // amp * K
		E_E: begin                                                                 // env_vol * am  | env_vol * tl
			if (f_ams != 0) begin ma = u17(env_vol_r); mb = u17(17'd65536 - {1'b0, P[31:16]}); end
			else            begin ma = u17(env_vol_r); mb = u17(tl_r); end
		end
		E_F: begin ma = u17(P[32:16]); mb = u17(tl_r); end                         // ev * tl (AM path)
		E_G: begin ma = u17(mant); mb = u17(pm); end                               // mant * pm
		E_H: begin
			if (u_pcm) begin ma = u17(vol); mb = u17(att_lut(f_lvl0)); end         // vol * att0
			else       begin ma = {wv[16], wv}; mb = u17(vol); end                 // wave * vol
		end
		E_I: begin
			if (u_pcm) begin ma = u17(vol); mb = u17(att_lut(f_lvl1)); end         // vol * att1
			else       begin ma = {P[32], P[32:16]}; mb = u17(att_lut(f_lvl0)); end // out * att0
		end
		E_J: begin
			if (u_pcm) begin ma = {smp[15], smp[15], smp}; mb = u17(cv0); end      // smp * cv0
			else       begin ma = {opout[16], opout}; mb = u17(att_lut(f_lvl1)); end // out * att1
		end
		E_K: begin
			if (u_pcm) begin ma = {smp[15], smp[15], smp}; mb = u17(cv1); end      // smp * cv1
		end
		default: ;
	endcase
end


// ---------------------------------------------------------------------------
// Main sequential block. Order matters: the CPU write processor comes after
// the engine so that a key-on/off posted in the same clock wins.
// ---------------------------------------------------------------------------
logic        fq_push;
logic [22:0] fq_din;

always_ff @(posedge clk) begin
	rw_we      <= 1'b0;
	st_we      <= 1'b0;
	fb_we      <= 1'b0;
	out_strobe <= 1'b0;

	if (reset) begin
		active <= '0; kon <= '0; koff <= '0;
		end_status <= '0;
		for (int i = 0; i < 12; i++) gsync[i] <= 2'd0;
		for (int i = 0; i < 48; i++) alg_r[i] <= 4'd0;
		for (int i = 0; i < 8; i++) areg[i] <= 8'd0;
		wq_wp <= '0; wq_rp <= '0; wq_cnt <= '0;
		fq_wp <= '0; fq_rp <= '0; fq_cnt <= '0;
		lb_valid0 <= '0; lb_valid1 <= '0; lb_pend0 <= '0; lb_pend1 <= '0;
		timer_a <= '0; timer_b <= '0; tctl <= '0; tflag <= '0;
		ta_run <= 1'b0; tb_run <= 1'b0; ta_cnt <= '0; tb_cnt <= '0;
		wf_busy <= 1'b0;
		es <= E_IDLE;
		tick_cnt <= '0; tick_pend <= 1'b0; cyc <= '0;
		out_l <= '0; out_r <= '0;
		dbg_overruns <= '0; dbg_stalls <= '0; dbg_cycles <= '0;
	end else begin
		logic wq_pop, wq_push;
		fq_push = 1'b0;
		fq_din  = '0;
		wq_pop  = 1'b0;
		wq_push = 1'b0;

		// ---------------- sample clock ----------------
		if (pause) ;
		else if (tick_cnt == 10'd767) begin
			tick_cnt <= '0;
			if (tick_pend) dbg_overruns <= dbg_overruns + 1'd1;
			tick_pend <= 1'b1;
		end else tick_cnt <= tick_cnt + 1'd1;
		if (es != E_IDLE) cyc <= cyc + 1'd1;

		// ---------------- engine ----------------
		case (es)
		E_IDLE: if ((tick_pend || test_fast) && !test_hold) begin
			tick_pend <= 1'b0;
			mix0 <= '0; mix1 <= '0;
			g_j <= '0; g_step <= '0;
			cyc <= '0;
			es <= E_GROUP;
		end

		E_GROUP: begin
			if (g_j == 4'd12) es <= E_DONE;
			else begin
				logic go, pcm, last;
				logic [1:0] bank;
				logic [5:0] s;
				go = 1'b0; pcm = 1'b0; last = 1'b1; bank = 2'd0;
				case (gsync[g_j])
				2'd0: begin
					go = active[g_j];
					u_prog <= prog(2'd0, alg_r[g_j]);
				end
				2'd1: begin
					bank = g_step[0] ? 2'd1 : 2'd0;
					last = g_step[0];
					go = g_step[0] ? active[slot_of(g_j, 2'd1)] : active[g_j];
					u_prog <= prog(2'd1, g_step[0] ? alg_r[slot_of(g_j, 2'd1)] : alg_r[g_j]);
				end
				2'd2: begin
					last = g_step[0];
					if (!g_step[0]) begin go = active[g_j]; u_prog <= prog(2'd2, alg_r[g_j]); end
					else begin pcm = 1'b1; bank = 2'd3; go = g_j[1:0] == 2'b00 && active[slot_of(g_j, 2'd3)]; end
				end
				default: begin
					pcm = 1'b1; bank = g_step[1:0]; last = g_step[1:0] == 2'd3;
					go = g_j[1:0] == 2'b00 && active[slot_of(g_j, g_step[1:0])];
				end
				endcase
				s = slot_of(g_j, bank);
				if (last) begin g_j <= g_j + 1'd1; g_step <= '0; end
				else g_step <= g_step + 1'd1;
				if (go) begin
					u_pcm  <= pcm;
					u_bank <= bank;
					u_op   <= '0;
					acc0   <= '0; acc1 <= '0;
					r1 <= '0; r2 <= '0; r3 <= '0;
					s_idx  <= s;
					u_j    <= g_j;
					es     <= E_RD;
				end
			end
		end

		// ---- one slot step. RAM addresses come from s_idx. ----
		E_RD: es <= E_A;

		E_A: begin                           // latch registers + state; envstep/lfostep addressed from st_n
			R <= rr_q;
			W <= st_n;
			s_cur <= s_idx;
			if (kon[s_idx]) kon[s_idx] <= 1'b0;
			if (koff[s_idx]) koff[s_idx] <= 1'b0;
			w_fb0 <= kon[s_idx] ? 27'sd0 : $signed(fb_q[53:27]);
			w_fb1 <= kon[s_idx] ? 27'sd0 : $signed(fb_q[26:0]);
			if (u_op == 3'd0 && !u_pcm) u_fbsh <= rr_q[10][6:4];
			es <= E_B;
		end

		E_B: begin                           // envelope, LFO, step mantissa, PCM loop
			logic [24:0] v;
			logic [1:0]  e;
			logic        act;
			logic [15:0] lf;
			logic [7:0]  li;
			logic signed [5:0] ex;
			e = W.env; act = 1'b1;
			if (W.env == 2'd0) begin
				v = {1'b0, W.vol} + {2'b00, envstep_q};
				if (v >= (25'd255 << 16)) begin v = 25'd255 << 16; e = 2'd1; end
			end else begin
				v = {1'b0, W.vol} - {2'b00, envstep_q};
				if (v[24] || v == 25'd0) begin v = '0; act = 1'b0; end
				else if (W.env == 2'd1 && v[23:16] <= 8'd255 - {f_d1l, 4'd0}) e = 2'd2;
			end
			vol_n <= v[23:0];
			env_n <= e;
			act_n <= act;
			lf = W.lfo + {6'd0, lfostep_q};
			lfo_n <= lf;
			li = lf[15:8];
			case (f_lfowave)
				2'd0: amp <= 17'd0;
				2'd1: amp <= 17'd65536 - {1'b0, li, 8'd0};
				2'd2: amp <= li[7] ? 17'd0 : 17'd65536;
				default: amp <= li[7] ? {1'b0, li[6:0], 9'd0} : 17'd65536 - {1'b0, li[6:0], 9'd0};
			endcase
			case (f_ams)
				2'd1: amk <= 16'd33124;
				2'd2: amk <= 16'd16742;
				2'd3: amk <= 16'd4277;
				default: amk <= 16'd0;
			endcase
			ex = f_block[3] ? $signed({2'b00, f_block}) - 6'sd9 : $signed({2'b00, f_block}) + 6'sd7;
			if (f_wave == 3'd7) begin
				mant <= mul12x5(f_fns | 12'h800, f_mult == 4'd0 ? 5'd1 : {f_mult, 1'b0});
				sh   <= ex - $signed({4'd0, f_fs}) - 6'sd3;
			end else begin
				mant <= mul12x5(f_fns, f_mult == 4'd0 ? 5'd1 : {f_mult, 1'b0});
				sh   <= ex - 6'sd3;
			end
			if (u_pcm) begin                 // MAME update_pcm: loop check before the sample read
				logic [40:0] p;
				p = {1'b0, W.ptr};
				if (p[40:16] > {2'b00, f_end}) begin
					p = p - {2'b00, f_end, 16'd0} + {2'b00, f_loop, 16'd0};
					end_status[{u_j[3:2], u_bank}] <= 1'b1;
					if (p[40:16] > {2'b00, f_end}) begin
						p = {2'b00, f_loop, p[15:0]};
						if (p[40:16] > {2'b00, f_end}) p = {2'b00, f_end, p[15:0]};
					end
				end
				W.ptr <= p[39:0];
			end
			es <= E_C;
		end

		E_C: begin                           // envvol/tl/saw addressed; sample address / wave index
			if (f_bits12) a0 <= f_start + {W.ptr[38:17], 1'b0} + {1'b0, W.ptr[38:17]} + {22'd0, W.ptr[16]};
			else          a0 <= f_start + W.ptr[38:16];
			widx <= 10'((W.ptr[25:0] + in26) >> 16);
			es <= E_D;
		end

		E_D: begin                           // tables valid; LFO pitch factor; PCM line check; P <= amp*K
			logic signed [9:0]  p;
			logic [11:0] k;
			logic signed [22:0] pk;
			logic [7:0] li;
			env_vol_r <= envvol_q;
			tl_r      <= tl_q;
			li = lfo_n[15:8];
			case (f_lfowave)
				2'd0: p = 10'sd0;
				2'd1: p = $signed(saw_q);
				2'd2: p = li[7] ? -10'sd256 : 10'sd256;
				default: p = (li < 8'd64)  ? $signed({2'b00, li[5:0], 2'b00}) :
				             (li < 8'd128) ? 10'sd256 - $signed({2'b00, li[5:0], 2'b00}) :
				             (li < 8'd192) ? -$signed({2'b00, li[5:0], 2'b00}) :
				                             -(10'sd256 - $signed({2'b00, li[5:0], 2'b00}));
			endcase
			case (f_pms)
				3'd0: k = 12'd0;    3'd1: k = 12'd128;  3'd2: k = 12'd192;  3'd3: k = 12'd256;
				3'd4: k = 12'd383;  3'd5: k = 12'd764;  3'd6: k = 12'd1518; default: k = 12'd3002;
			endcase
			pk = mul_pk(p, k);
			pm <= 17'(18'sd65536 + 18'(pk >>> 8));
			wv_neg  <= (f_wave == 3'd0 || f_wave == 3'd1) ? widx[9] : (f_wave == 3'd4) ? widx[8] : 1'b0;
			wv_zero <= (f_wave == 3'd7) || ((f_wave == 3'd3 || f_wave == 3'd4 || f_wave == 3'd5) && widx[9]);
			wv_max  <= f_wave == 3'd6;
			if (u_pcm) begin
				if (hit0 && hit1) begin
					// one-line prefetch while both sample bytes sit in one line
					if (ln0 == ln1 && !(tagPF == pf_line && vPF) && !pPF && !fq_full) begin
						fq_push = 1'b1;
						fq_din  = {pslot, pf_line[0], pf_line};
					end
					es <= E_E;
				end else begin
					dbg_stalls <= dbg_stalls + 1'd1;
					if (!fq_full) begin
						if (!hit0 && !pA0) begin fq_push = 1'b1; fq_din = {pslot, ln0[0], ln0}; end
						else if (!hit1 && !pA1) begin fq_push = 1'b1; fq_din = {pslot, ln1[0], ln1}; end
					end
				end
			end else es <= E_E;
		end

		E_E: begin                           // wave / sample data valid ; P <= env_vol*(am|tl)
			wv <= wv_zero ? 17'sd0 : wv_max ? 17'sd32767 : wv_neg ? -$signed({1'b0, qwave_q}) : $signed({1'b0, qwave_q});
			if (!f_bits12) smp <= {sbyte0, 8'h00};
			else if (!W.ptr[16]) smp <= {sbyte0, sbyte1[7:4], 4'h0};
			else                 smp <= {sbyte1, sbyte0[3:0], 4'h0};
			es <= (f_ams != 0) ? E_F : E_G;
		end

		E_F: es <= E_G;                      // P <= ev*tl (AM path)

		E_G: begin                           // vol ; P <= mant*pm
			vol <= 17'(P[32:16]);
			es <= E_H;
		end

		E_H: begin                           // step ; P <= wave*vol | vol*att0
			step <= 30'(P[35:0] >> (6'd16 - sh));
			es <= E_I;
		end

		E_I: begin                           // FM: out ; PCM: cv0
			if (u_pcm) cv0 <= 17'(P[32:16]);
			else begin
				opout <= 17'(P >>> 16);
				case (op_dst)
					2'd1: r1 <= 17'(P >>> 16);
					2'd2: r2 <= 17'(P >>> 16);
					2'd3: r3 <= 17'(P >>> 16);
					default: ;
				endcase
			end
			es <= E_J;
		end

		E_J: begin                           // FM: acc0 ; PCM: cv1. Next FM op's RAM read starts here.
			if (u_pcm) cv1 <= 17'(P[32:16]);
			else begin
				if (op_out) acc0 <= acc0 + P;
				if (u_op + 3'd1 != u_nops)
					s_idx <= slot_of(u_j, u_prog[(u_op + 3'd1)*8 + 6 +: 2] + u_bank);
			end
			es <= E_K;
		end

		E_K: begin
			if (u_pcm) begin                 // mix0
				mix0 <= mix0 + 32'(P >>> 16);
				es <= E_L;
			end else begin                   // acc1, write back, next op
				sstate_t n;
				if (op_out) acc1 <= acc1 + P;
				n = W; n.env = env_n; n.vol = vol_n; n.lfo = lfo_n;
				n.ptr = {14'd0, 26'(W.ptr[25:0] + step[25:0])};
				st_we <= 1'b1; st_waddr <= s_cur; st_wdata <= n;
				active[s_cur] <= act_n | kon[s_cur];
				if (u_op == 3'd0) u_fb1_old <= w_fb1;
				if (u_op + 3'd1 == u_nops) es <= E_UEND;
				else begin
					u_op <= u_op + 1'd1;
					es   <= E_A;
				end
			end
		end

		E_L: begin                           // PCM: mix1, write back
			sstate_t n;
			mix1 <= mix1 + 32'(P >>> 16);
			n = W; n.env = env_n; n.vol = vol_n; n.lfo = lfo_n;
			n.ptr = W.ptr + {10'd0, step};
			st_we <= 1'b1; st_waddr <= s_cur; st_wdata <= n;
			active[s_cur] <= act_n | kon[s_cur];
			es <= E_GROUP;
		end

		E_UEND: begin
			logic signed [26:0] src, fbv;
			src = u_fbr3 ? {{10{r3[16]}}, r3} : {{10{r1[16]}}, r1};
			fbv = (u_fbsh == 3'd0) ? 27'sd0 : (src <<< (4'd3 + {1'b0, u_fbsh}));
			mix0 <= mix0 + 32'(acc0 >>> 16);
			mix1 <= mix1 + 32'(acc1 >>> 16);
			fb_we <= 1'b1;
			fb_waddr <= slot_of(u_j, u_bank);
			fb_wdata <= {u_fb1_old, fbv};
			es <= E_GROUP;
		end
		E_DONE: begin
			out_l <= sat16(mix0 >>> 2);
			out_r <= sat16(mix1 >>> 2);
			out_strobe <= 1'b1;
			dbg_cycles <= cyc;
			es <= E_IDLE;
		end

		default: es <= E_IDLE;
		endcase

		// ---------------- timers (768 clk = 384 chip clocks) ----------------
		if (ta_run && !pause) begin
			if (ta_cnt <= 20'd1) begin
				tflag[0] <= 1'b1;
				ta_cnt   <= ta_period;
			end else ta_cnt <= ta_cnt - 1'd1;
		end
		if (tb_run && !pause) begin
			if (tb_cnt <= 22'd1) begin
				tflag[1] <= 1'b1;
				tb_cnt   <= tb_period;
			end else tb_cnt <= tb_cnt - 1'd1;
		end

		// ---------------- CPU writes ----------------
		if (cpu_wr) begin
			if (!cpu_addr[0]) areg[cpu_addr[3:1]] <= cpu_din;
			else if (wq_cnt != WQ) begin
				wq[wq_wp] <= {cpu_addr[3:1], areg[cpu_addr[3:1]], cpu_din};
				wq_wp <= wq_wp + 1'd1;
				wq_push = 1'b1;
			end
		end

		// ---------------- register write processor ----------------
		if (!wf_busy) begin
			if (wq_cnt != 0) begin
				logic [18:0] e;
				logic [3:0]  g, rg;
				logic [1:0]  bank;
				logic [3:0]  m;
				logic        sreg;
				e = wq[wq_rp];
				wq_pop = 1'b1;
				g  = fm_tab(e[11:8]);
				rg = e[15:12];
				case (e[18:16])
				3'd0, 3'd1, 3'd2, 3'd3: begin   // FM bank data
					bank = e[17:16];
					sreg = (rg == 4'd0) || (rg == 4'd9) || (rg == 4'd10) || (rg == 4'd12) || (rg == 4'd13) || (rg == 4'd14);
					m = 4'b0001 << bank;
					if (sreg) begin
						case (gsync[g])
							2'd0: if (bank == 2'd0) m = 4'b1111;
							2'd1: if (bank == 2'd0) m = 4'b0101; else if (bank == 2'd1) m = 4'b1010;
							2'd2: if (bank == 2'd0) m = 4'b0111;
							default: ;
						endcase
					end
					if (g != 4'hF) begin
						wf_busy  <= 1'b1;
						wf_banks <= m;
						wf_grp   <= g;
						wf_reg   <= rg;
						wf_d     <= e[7:0];
						wf_b     <= 2'd0;
					end
				end
				3'd4: begin                      // PCM data: slot = 4 * fm_tab(addr)
					if (g != 4'hF && rg <= 4'd9) begin
						rw_we   <= 1'b1;
						rw_addr <= {g, 2'b00};
						rw_be   <= 24'd1 << (5'd14 + {1'b0, rg});
						for (int i = 0; i < 24; i++) rw_data[i] <= e[7:0];
					end
				end
				3'd6: begin                      // timer / group
					if (rg == 4'd0) begin
						if (g != 4'hF) gsync[g] <= e[1:0];
					end else begin
						case (e[15:8])
							8'h10: timer_a <= {e[7:0], timer_a[1:0]};
							8'h11: timer_a <= {timer_a[9:2], e[1:0]};
							8'h12: timer_b <= e[7:0];
							8'h13: begin
								if (!tctl[0] && e[0]) begin ta_run <= 1'b1; ta_cnt <= ta_period; end
								if (!tctl[1] && e[1]) begin tb_run <= 1'b1; tb_cnt <= tb_period; end
								if (e[4]) tflag[0] <= 1'b0;
								if (e[5]) tflag[1] <= 1'b0;
								tctl <= e[7:0];
							end
							default: ;
						endcase
					end
				end
				default: ;
				endcase
			end
		end else begin
			// one bank per clock
			if (wf_banks[wf_b]) begin
				logic [5:0] s;
				s = slot_of(wf_grp, wf_b);
				case (wf_reg)
				4'd0: begin
					if (wf_d[0]) begin
						kon[s]    <= 1'b1;
						koff[s]   <= 1'b0;
						active[s] <= 1'b1;
						if (wf_grp[1:0] == 2'b00) end_status[{wf_grp[3:2], wf_b}] <= 1'b0;
					end else koff[s] <= 1'b1;
				end
				4'd10: ;                      // fnshi_ram write (see above)
				4'd15: ;
				default: begin
					rw_we   <= 1'b1;
					rw_addr <= s;
					for (int i = 0; i < 24; i++) rw_data[i] <= wf_d;
					case (wf_reg)
						4'd9:  begin rw_be <= 24'b11 << 8; rw_data[9] <= fnshi_q; end
						4'd11: rw_be <= 24'd1 << 10;
						4'd12: begin rw_be <= 24'd1 << 11; alg_r[s] <= wf_d[3:0]; end
						4'd13: rw_be <= 24'd1 << 12;
						4'd14: rw_be <= 24'd1 << 13;
						default: rw_be <= 24'd1 << (wf_reg - 4'd1);
					endcase
				end
				endcase
			end
			wf_b <= wf_b + 1'd1;
			if (wf_b == 2'd3) wf_busy <= 1'b0;
		end

		if (wq_pop) wq_rp <= wq_rp + 1'd1;
		wq_cnt <= wq_cnt + (wq_push ? 5'd1 : 5'd0) - (wq_pop ? 5'd1 : 5'd0);

		// ---------------- fetch queue bookkeeping ----------------
		if (fq_push) begin
			fq[fq_wp] <= fq_din;
			fq_wp <= fq_wp + 1'd1;
			if (fq_din[18]) begin
				lb_tag1[fq_din[22:19]] <= fq_din[17:0];
				lb_valid1[fq_din[22:19]] <= 1'b0;
				lb_pend1[fq_din[22:19]]  <= 1'b1;
			end else begin
				lb_tag0[fq_din[22:19]] <= fq_din[17:0];
				lb_valid0[fq_din[22:19]] <= 1'b0;
				lb_pend0[fq_din[22:19]]  <= 1'b1;
			end
		end
		if (fetch_ack) begin
			fq_rp <= fq_rp + 1'd1;
			if (fill_par) begin lb_valid1[fill_pslot] <= 1'b1; lb_pend1[fill_pslot] <= 1'b0; end
			else          begin lb_valid0[fill_pslot] <= 1'b1; lb_pend0[fill_pslot] <= 1'b0; end
		end
		fq_cnt <= fq_cnt + (fq_push ? 5'd1 : 5'd0) - (fetch_ack ? 5'd1 : 5'd0);
	end
end

`ifdef YMF_TRACE
// simulation-only per-slot trace: +ymf_from=<sample> +ymf_to=<sample>
integer tr_from, tr_to;
integer tr_sn;
initial begin
	if (!$value$plusargs("ymf_from=%d", tr_from)) tr_from = -1;
	if (!$value$plusargs("ymf_to=%d", tr_to)) tr_to = -1;
	tr_sn = 0;
end
always @(posedge clk) begin
	if (out_strobe) tr_sn <= tr_sn + 1;
	if (tr_sn >= tr_from && tr_sn <= tr_to) begin
		if (es == E_K && u_pcm)
			$display("H s=%0d PCM slot %0d ch0 smp=%0d vol=%0d cv0=%0d add=%0d ptr=%h env_vol=%h step=%0d", tr_sn, s_cur, smp, vol, cv0, P >>> 16, W.ptr, vol_n, step);
		if (es == E_L)
			$display("H s=%0d PCM slot %0d ch1 cv1=%0d add=%0d", tr_sn, s_cur, cv1, P >>> 16);
		if (es == E_UEND)
			$display("H s=%0d FM j=%0d ofs=%0d add0=%0d add1=%0d", tr_sn, u_j, u_bank, acc0 >>> 16, acc1 >>> 16);
	end
end
`endif

endmodule
