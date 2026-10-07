// Taito FX-1A sound board (Psychic Force, Super Football Champ, Magical Date):
// Z80 @ 4 MHz, YM2610B @ 8 MHz, TC0140SYT between the PSX and the Z80.
//
// Reference: MAME 0.289 src/mame/sony/zn.cpp taito_fx1s_state, src/mame/shared/taitosnd.cpp
//   PSX  0x1FB80000 (byte) write -> TC0140SYT master port (mode)
//   PSX  0x1FB80002 (byte) r/w   -> TC0140SYT master comm
//   Z80  0000-3FFF  ROM (program offset 0)
//        4000-7FFF  ROM bank (0xF200 & 7) * 0x4000
//        C000-DFFF  RAM 8 KiB
//        E000-E003  YM2610B
//        E200       TC0140SYT slave port (write)     E201  slave comm (r/w)
//        E400-E403, EE00, F000  unused (MAME: no-ops)  F200  ROM bank
//   YM2610B IRQ -> Z80 INT; TC0140SYT -> Z80 NMI and RESET
//   ADPCM-A and ADPCM-B both read the 'ym2610b:adpcma' region (MAME maps space 1 to
//   it when there is no adpcmb region)
//
// The Z80 program (MRA index 6) and the ADPCM ROM (index 7) live in SDRAM. The Z80
// reads through an 8 KiB direct-mapped line cache, the YM2610B through an 8-line fully
// associative cache. On a miss the chip's clock enable is held; the fractional clock
// generators keep counting, and the owed enables are issued afterwards (at most one
// every two clocks), so long-term timing stays exact.
//
// All logic runs on clk = clk_1x (33.8688 MHz).

module taito_fx1a #(
	parameter [26:0] PROG_BASE   = 27'h1800000,
	parameter [26:0] SAMPLE_BASE = 27'h1C00000
) (
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,
	input  logic        pause,

	input  logic        bus_wr,          // PSX window 0x1FB80000-0x1FB80003
	input  logic        bus_rd,
	input  logic  [1:0] bus_addr,
	input  logic [31:0] bus_din,
	output logic [31:0] bus_dout,

	output logic        mem_req,
	output logic [26:0] mem_addr,
	input  logic        mem_ack,
	input  logic [127:0] mem_data,

	output logic signed [15:0] out_l,
	output logic signed [15:0] out_r,
	output logic        out_strobe,

	output logic [127:0] dbg,
	output logic        dbg_ym_wr,
	output logic  [8:0] dbg_ym_addr,     // {port, register}
	output logic  [7:0] dbg_ym_data
);

wire rst = reset | ~enable;

// ---------------------------------------------------------------------------
// Clock enables: Z80 4 MHz = 625/5292 of clk, YM2610B 8 MHz = 625/2646 of clk.
// 'owed' counts generated-but-not-issued enables; an enable is issued when the
// consumer is not stalled and the previous one is at least two clocks old.
// ---------------------------------------------------------------------------
logic [12:0] z_acc, y_acc;
logic  [3:0] z_owed, y_owed;
logic        z_gap, y_gap;
logic        z_stall, y_stall;
logic        ce_z80, ce_ym;
wire  [13:0] z_next = {1'b0, z_acc} + 14'd625;
wire  [13:0] y_next = {1'b0, y_acc} + 14'd625;
wire         z_tick = z_next >= 14'd5292;
wire         y_tick = y_next >= 14'd2646;
assign ce_z80 = !rst && !pause && z_owed != 0 && !z_gap && !z_stall;
assign ce_ym  = !rst && !pause && y_owed != 0 && !y_gap && !y_stall;
always_ff @(posedge clk) begin
	if (rst) begin
		z_acc <= '0; y_acc <= '0; z_owed <= '0; y_owed <= '0; z_gap <= 1'b0; y_gap <= 1'b0;
	end else if (!pause) begin
		z_acc <= z_tick ? 13'(z_next - 14'd5292) : z_next[12:0];
		y_acc <= y_tick ? 13'(y_next - 14'd2646) : y_next[12:0];
		z_owed <= z_owed + (z_tick && z_owed != 4'hF) - ce_z80;
		y_owed <= y_owed + (y_tick && y_owed != 4'hF) - ce_ym;
		z_gap <= ce_z80;
		y_gap <= ce_ym;
	end
end

// ---------------------------------------------------------------------------
// TC0140SYT (MAME taitosnd.cpp)
// ---------------------------------------------------------------------------
logic [3:0] syt_mainmode, syt_submode;
logic [3:0] syt_status;              // [0] p01 full, [1] p23 full, [2] p01 full (master), [3] p23 full (master)
logic       syt_nmi_en;
logic [3:0] syt_slave [0:3];         // PSX -> Z80
logic [3:0] syt_master[0:3];         // Z80 -> PSX
logic       syt_z80_reset;           // master mode 4: Z80 RESET while data != 0
wire        z80_nmi_n = !(syt_nmi_en && (syt_status[0] || syt_status[1]));

// Z80 bus
logic [15:0] za;
logic  [7:0] zdo, zdi;
logic        z_mreq_n, z_iorq_n, z_rd_n, z_wr_n, z_m1_n;
logic        ym_irq_n;
wire         z_rst_n = !rst && !syt_z80_reset;

wire sel_rom  = za[15] == 1'b0;                    // 0000-7FFF
wire sel_ram  = za[15:13] == 3'b110;               // C000-DFFF
wire sel_ym   = za[15:8] == 8'hE0;                 // E000-E0FF (E000-E003 mirrored)
wire sel_sytp = za == 16'hE200;
wire sel_sytc = za == 16'hE201;
wire sel_bank = za[15:8] == 8'hF2;

logic [2:0] rom_bank;
logic       z_wr_q, z_rd_q;                        // previous strobes (edge detection)
wire        z_wr_edge = !z_mreq_n && !z_wr_n && !z_wr_q;
wire        z_rd_edge = !z_mreq_n && !z_rd_n && !z_rd_q;
logic [3:0] syt_slave_rd;

always_ff @(posedge clk) begin
	z_wr_q <= !z_mreq_n && !z_wr_n;
	z_rd_q <= !z_mreq_n && !z_rd_n;
	if (rst) begin
		syt_mainmode <= '0; syt_submode <= '0; syt_status <= '0; syt_nmi_en <= 1'b0;
		syt_z80_reset <= 1'b0; rom_bank <= 3'd1;   // MAME driver_reset: soundbank entry 1
		for (int i = 0; i < 4; i++) begin syt_slave[i] <= '0; syt_master[i] <= '0; end
	end else begin
		// ---- PSX (master) side ----
		if (bus_wr && !bus_addr[1]) syt_mainmode <= bus_din[3:0];
		if (bus_wr && bus_addr[1]) begin
			case (syt_mainmode)
				4'd0, 4'd2: begin syt_slave[syt_mainmode[1:0]] <= bus_din[19:16]; syt_mainmode <= syt_mainmode + 1'd1; end
				4'd1: begin syt_slave[1] <= bus_din[19:16]; syt_mainmode <= 4'd2; syt_status[0] <= 1'b1; end
				4'd3: begin syt_slave[3] <= bus_din[19:16]; syt_mainmode <= 4'd4; syt_status[1] <= 1'b1; end
				4'd4: syt_z80_reset <= bus_din[19:16] != 4'd0;
				default: ;
			endcase
		end
		if (bus_rd && bus_addr[1]) begin
			case (syt_mainmode)
				4'd0, 4'd2: syt_mainmode <= syt_mainmode + 1'd1;
				4'd1: begin syt_status[2] <= 1'b0; syt_mainmode <= 4'd2; end
				4'd3: begin syt_status[3] <= 1'b0; syt_mainmode <= 4'd4; end
				default: ;
			endcase
		end
		// ---- Z80 (slave) side ----
		if (z_wr_edge && sel_sytp) syt_submode <= zdo[3:0];
		if (z_wr_edge && sel_sytc) begin
			case (syt_submode)
				4'd0, 4'd2: begin syt_master[syt_submode[1:0]] <= zdo[3:0]; syt_submode <= syt_submode + 1'd1; end
				4'd1: begin syt_master[1] <= zdo[3:0]; syt_submode <= 4'd2; syt_status[2] <= 1'b1; end
				4'd3: begin syt_master[3] <= zdo[3:0]; syt_submode <= 4'd4; syt_status[3] <= 1'b1; end
				4'd5: syt_nmi_en <= 1'b0;
				4'd6: syt_nmi_en <= 1'b1;
				default: ;
			endcase
		end
		if (z_rd_edge && sel_sytc) begin
			case (syt_submode)
				4'd0, 4'd2: syt_submode <= syt_submode + 1'd1;
				4'd1: begin syt_status[0] <= 1'b0; syt_submode <= 4'd2; end
				4'd3: begin syt_status[1] <= 1'b0; syt_submode <= 4'd4; end
				default: ;
			endcase
		end
		if (z_wr_edge && sel_bank) rom_bank <= zdo[2:0];
	end
end

// value returned by a slave comm read (captured at the start of the read, before the
// mode advances)
always_ff @(posedge clk)
	if (z_rd_edge && sel_sytc)
		syt_slave_rd <= (syt_submode < 4'd4) ? syt_slave[syt_submode[1:0]] :
		                (syt_submode == 4'd4) ? syt_status : 4'd0;

// PSX read of the master comm (bus-lane 2), MAME master_comm_r
always_ff @(posedge clk)
	if (bus_rd)
		bus_dout <= {8'h00, 4'h0, (syt_mainmode < 4'd4) ? syt_master[syt_mainmode[1:0]] :
		                          (syt_mainmode == 4'd4) ? syt_status : 4'd0, 16'h0000};

// ---------------------------------------------------------------------------
// Work RAM 8 KiB
// ---------------------------------------------------------------------------
logic [7:0] wram [0:8191];
logic [7:0] wram_q;
always_ff @(posedge clk) begin
	if (z_wr_edge && sel_ram) wram[za[12:0]] <= zdo;
	wram_q <= wram[za[12:0]];
end

// ---------------------------------------------------------------------------
// Program ROM cache: 8 KiB direct mapped, 16-byte lines, over the 128 KiB image
// ---------------------------------------------------------------------------
wire [16:0] rom_a = za[14] ? {rom_bank, za[13:0]} : {3'd0, za[13:0]};
logic [127:0] pc_data [0:511];
logic   [4:0] pc_tag  [0:511];           // {valid, A[16:13]}
logic [127:0] pc_q;
logic   [4:0] pc_tag_q;
logic  [16:0] pc_qa;                     // address the cache outputs belong to
logic         pc_qv;                     // ... and they were read outside a fill
logic         pc_fill;
logic   [8:0] pc_widx;
logic   [4:0] pc_wtag;
logic         pc_clr;
logic   [8:0] pc_clr_idx;
always_ff @(posedge clk) begin
	if (pc_fill) begin
		pc_data[pc_widx] <= mem_data;
		pc_tag[pc_widx]  <= pc_wtag;
	end
	pc_q     <= pc_data[rom_a[12:4]];
	pc_tag_q <= pc_tag[rom_a[12:4]];
	pc_qa    <= rom_a;
	pc_qv    <= !pc_fill;                // a read in the fill clock returns the old line
end
wire       pc_valid = pc_qa == rom_a && pc_qv && !pc_fill;
wire       pc_hit   = pc_valid && pc_tag_q == {1'b1, rom_a[16:13]};
wire [7:0] pc_byte  = pc_q[rom_a[3:0]*8 +: 8];

logic [15:0] za_q;
always_ff @(posedge clk) za_q <= za;

// Z80 read data and stall: any memory read waits until its source is valid for the
// current address (synchronous RAMs answer one clock after an address change).
logic [7:0] ym_dout;
always_comb begin
	if (sel_rom)       zdi = pc_byte;
	else if (sel_ram)  zdi = wram_q;
	else if (sel_ym)   zdi = ym_dout;
	else if (sel_sytc) zdi = {4'h0, syt_slave_rd};
	else               zdi = 8'hFF;
end
wire z_reading = !z_mreq_n && !z_rd_n;
wire z_rom_wait = z_reading && sel_rom && !pc_hit;
assign z_stall  = z_rom_wait || (z_reading && za != za_q) || pc_clr;

// ---------------------------------------------------------------------------
// Z80
// ---------------------------------------------------------------------------
tv80s z80 (
	.clk(clk), .cen(ce_z80), .reset_n(z_rst_n), .wait_n(1'b1),
	.int_n(ym_irq_n), .nmi_n(z80_nmi_n), .busrq_n(1'b1),
	.m1_n(z_m1_n), .mreq_n(z_mreq_n), .iorq_n(z_iorq_n), .rd_n(z_rd_n), .wr_n(z_wr_n),
	.rfsh_n(), .halt_n(), .busak_n(),
	.A(za), .di(zdi), .dout(zdo),
	.auto_ss_rd(1'b0), .auto_ss_wr(1'b0), .auto_ss_data_in(32'd0),
	.auto_ss_device_idx(8'd0), .auto_ss_state_idx(16'd0), .auto_ss_base_device_idx(8'd0),
	.auto_ss_data_out(), .auto_ss_ack()
);

// ---------------------------------------------------------------------------
// YM2610B (jt10). Writes are passed as the Z80 drives them (jt10 samples the bus on clk).
// ---------------------------------------------------------------------------
logic [19:0] yaa;
logic  [3:0] yab;
logic        ya_roe_n, yb_roe_n;
logic [23:0] yba;
logic  [7:0] ya_d, yb_d;
logic signed [15:0] ym_l, ym_r;
logic  [9:0] ym_psg;
logic        ym_sample;

jt10 ym (
	.rst(rst), .clk(clk), .cen(ce_ym),
	.din(zdo), .addr(za[1:0]), .cs_n(!(sel_ym && !z_mreq_n)), .wr_n(z_wr_n),
	.dout(ym_dout), .irq_n(ym_irq_n),
	.adpcma_addr(yaa), .adpcma_bank(yab), .adpcma_roe_n(ya_roe_n), .adpcma_data(ya_d),
	.adpcmb_addr(yba), .adpcmb_roe_n(yb_roe_n), .adpcmb_data(yb_d),
	.psg_A(), .psg_B(), .psg_C(), .fm_snd(),
	.psg_snd(ym_psg), .snd_right(ym_r), .snd_left(ym_l), .snd_sample(ym_sample),
	.ch_enable(6'b111111), .ym2610b(1'b1),
	.auto_ss_rd(1'b0), .auto_ss_wr(1'b0), .auto_ss_data_in(32'd0),
	.auto_ss_device_idx(8'd0), .auto_ss_state_idx(16'd0), .auto_ss_base_device_idx(8'd0),
	.auto_ss_data_out(), .auto_ss_ack()
);

// ---------------------------------------------------------------------------
// ADPCM cache: 8 lines of 16 bytes, fully associative, round-robin replacement.
// The YM is stalled while an enabled ROM read (A or B) does not hit.
// ---------------------------------------------------------------------------
wire [23:0] ya_addr = {yab, yaa};
logic [19:0] ac_tag [0:7];               // byte address [23:4]
logic  [7:0] ac_valid;
logic  [7:0] ac_data [0:127];            // {line, byte}
logic  [2:0] ac_rr;
logic  [2:0] ac_hit_a, ac_hit_b;
logic        ac_has_a, ac_has_b;
always_comb begin
	ac_has_a = 1'b0; ac_hit_a = '0; ac_has_b = 1'b0; ac_hit_b = '0;
	for (int i = 0; i < 8; i++) begin
		if (ac_valid[i] && ac_tag[i] == ya_addr[23:4]) begin ac_has_a = 1'b1; ac_hit_a = 3'(i); end
		if (ac_valid[i] && ac_tag[i] == yba[23:4])     begin ac_has_b = 1'b1; ac_hit_b = 3'(i); end
	end
end
// two read ports (A and B) on a 128-byte array: registered, so valid one clock after
// the address settles
logic [23:0] ya_qa, yb_qa;
logic        ya_qv, yb_qv;
logic        ac_fill;
always_ff @(posedge clk) begin
	ya_d  <= ac_data[{ac_hit_a, ya_addr[3:0]}];
	yb_d  <= ac_data[{ac_hit_b, yba[3:0]}];
	// a read in the fill clock (or before the tag matched) returns stale data
	ya_qv <= ac_has_a && !ac_fill;
	yb_qv <= ac_has_b && !ac_fill;
	ya_qa <= ya_addr;
	yb_qa <= yba;
end
wire ya_ok = ya_roe_n || (ya_qv && ya_qa == ya_addr && !ac_fill);
wire yb_ok = yb_roe_n || (yb_qv && yb_qa == yba     && !ac_fill);
assign y_stall = !ya_ok || !yb_ok;

// ---------------------------------------------------------------------------
// SDRAM line port: one outstanding read; ADPCM first, then the Z80 cache
// ---------------------------------------------------------------------------
logic        mem_busy, mem_owner_z80;
logic [19:0] ac_ftag;
logic        pc_req_done;
logic [15:0] d_fetch_a, d_fetch_z;
always_ff @(posedge clk) begin
	mem_req <= 1'b0;
	pc_fill <= 1'b0;
	ac_fill <= 1'b0;
	if (rst) begin
		mem_busy <= 1'b0; ac_valid <= '0; ac_rr <= '0;
		pc_clr <= 1'b1; pc_clr_idx <= '0;
		d_fetch_a <= '0; d_fetch_z <= '0;
	end else begin
		if (pc_clr) begin
			pc_fill <= 1'b1; pc_widx <= pc_clr_idx; pc_wtag <= '0;
			pc_clr_idx <= pc_clr_idx + 1'd1;
			if (pc_clr_idx == 9'h1FF) pc_clr <= 1'b0;
		end else if (!mem_busy) begin
			if (!ya_roe_n && !ac_has_a) begin
				mem_req <= 1'b1; mem_busy <= 1'b1; mem_owner_z80 <= 1'b0; ac_ftag <= ya_addr[23:4];
				mem_addr <= SAMPLE_BASE + {3'd0, ya_addr[23:4], 4'd0};
			end else if (!yb_roe_n && !ac_has_b) begin
				mem_req <= 1'b1; mem_busy <= 1'b1; mem_owner_z80 <= 1'b0; ac_ftag <= yba[23:4];
				mem_addr <= SAMPLE_BASE + {3'd0, yba[23:4], 4'd0};
			end else if (z_rom_wait && pc_valid) begin
				mem_req <= 1'b1; mem_busy <= 1'b1; mem_owner_z80 <= 1'b1;
				mem_addr <= PROG_BASE + {10'd0, rom_a[16:4], 4'd0};
			end
		end else if (mem_ack) begin
			mem_busy <= 1'b0;
			if (mem_owner_z80) begin
				pc_fill <= 1'b1; pc_widx <= rom_a[12:4]; pc_wtag <= {1'b1, rom_a[16:13]};
				if (d_fetch_z != 16'hFFFF) d_fetch_z <= d_fetch_z + 1'd1;
			end else begin
				ac_fill <= 1'b1;
				ac_tag[ac_rr] <= ac_ftag; ac_valid[ac_rr] <= 1'b1; ac_rr <= ac_rr + 1'd1;
				if (d_fetch_a != 16'hFFFF) d_fetch_a <= d_fetch_a + 1'd1;
			end
		end
	end
end
always_ff @(posedge clk)
	if (ac_fill)
		for (int b = 0; b < 16; b++) ac_data[{ac_rr - 3'd1, 4'(b)}] <= mem_data[b*8 +: 8];

// ---------------------------------------------------------------------------
// Output: MAME routes SSG x0.75 to both sides, FM+ADPCM x1.0 (zn.cpp coh1000ta).
// jt10 snd_left/right carry FM + ADPCM; psg_snd is the unsigned 10-bit SSG sum.
// Levels are matched to MAME in source/sim (docs/AUDIO_TAITO_FX1A.md).
// ---------------------------------------------------------------------------
// SSG is unipolar (as in MAME's ymfm); PSG_GAIN is calibrated against MAME.
localparam int PSG_SHIFT = 4;
wire signed [17:0] psg_s  = $signed({2'b00, ym_psg, 6'd0});            // 0..65472
wire signed [17:0] psg_75 = (psg_s >>> 1) + (psg_s >>> 2);
function automatic logic signed [18:0] g98(input logic signed [18:0] v);
	g98 = v + (v >>> 3);
endfunction
function automatic logic signed [15:0] sat(input logic signed [18:0] v);
	sat = (v > 19'sd32767) ? 16'sh7FFF : (v < -19'sd32768) ? -16'sh8000 : 16'(v);
endfunction
logic ym_sample_q;
always_ff @(posedge clk) ym_sample_q <= ym_sample;
always_ff @(posedge clk) begin
	out_strobe <= 1'b0;
	if (rst) begin
		out_l <= '0; out_r <= '0;
	end else if (ym_sample && !ym_sample_q) begin
		// x 9/8 (+1.0 dB): measured against MAME's ymfm output (SPU muted), 24-59 s of the
		// Psychic Force attract: jt10 was a steady 0.9 dB below (docs/AUDIO_TAITO_FX1A.md)
		out_l <= sat(g98(19'(ym_l) + 19'(psg_75 >>> PSG_SHIFT)));
		out_r <= sat(g98(19'(ym_r) + 19'(psg_75 >>> PSG_SHIFT)));
		out_strobe <= 1'b1;
	end
end

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------
logic [15:0] d_cmd, d_cmdrd, d_ymw;
logic [7:0]  d_ymreg [0:1];
always_ff @(posedge clk) begin
	dbg_ym_wr <= 1'b0;
	if (rst) begin
		d_cmd <= '0; d_cmdrd <= '0; d_ymw <= '0; d_ymreg[0] <= '0; d_ymreg[1] <= '0;
	end else begin
		if (bus_wr && bus_addr[1] && d_cmd != 16'hFFFF) d_cmd <= d_cmd + 1'd1;
		if (z_rd_edge && sel_sytc && d_cmdrd != 16'hFFFF) d_cmdrd <= d_cmdrd + 1'd1;
		if (z_wr_edge && sel_ym) begin
			if (!za[0]) d_ymreg[za[1]] <= zdo;       // register select per port
			else begin
				dbg_ym_wr   <= 1'b1;
				dbg_ym_addr <= {za[1], d_ymreg[za[1]]};
				dbg_ym_data <= zdo;
				if (d_ymw != 16'hFFFF) d_ymw <= d_ymw + 1'd1;
			end
		end
	end
end
assign dbg = {d_cmd, d_cmdrd, d_ymw, d_fetch_z, d_fetch_a, 16'd0, za, 8'd0, 5'd0, rom_bank};

endmodule
