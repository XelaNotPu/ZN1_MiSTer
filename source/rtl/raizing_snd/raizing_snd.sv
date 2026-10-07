// Raizing / Eighting ZN-1 sound board (PS9805 / RA9701 SUB): MC68000 @ 12 MHz,
// YMF271-F @ 16.9344 MHz, one 8-bit command latch from the PSX, and a level-2
// interrupt raised by the PSX.
//
// Reference: MAME 0.289 src/mame/sony/zn.cpp raizing_zn_state:
//   PSX  0x1FB00000  write -> sound latch (8 bit)
//   PSX  0x1FB00004  write -> 68000 IRQ2, HOLD_LINE (cleared by the acknowledge)
//   68K  0x000000-0x07FFFF program ROM   (SDRAM, through a 4 KiB line cache)
//        0x080000-0x0FFFFF RAM           (16 KiB here, mirrored; Brave Blade
//                                         uses 0x080000-0x083FFF only)
//        0x100000-0x10001F YMF271 on the low byte lane (reg = A[4:1])
//        0x180009          sound latch read
//        everything else   reads 0, writes ignored (the driver pokes
//                          0x180000-0x18000E, which MAME leaves unmapped)
//
// All logic runs on clk = clk_1x (33.8688 MHz). The 68000 runs at an average
// 12.000 MHz (phi enables from a 1875/2646 fractional divider). Program ROM
// and YMF sample ROM live in SDRAM and are read as 16-byte lines through one
// request port (mem_*), shared by the YMF line fetcher (priority) and the
// 68000 cache.

module raizing_snd #(
	parameter HEXDIR = "rtl/raizing_snd/",
	parameter [26:0] PROG_BASE   = 27'h1800000,   // 68000 program (1 MiB region, 512 KiB used)
	parameter [26:0] SAMPLE_BASE = 27'h1C00000    // YMF271 sample ROM (4 MiB)
) (
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,          // sound ROMs are loaded
	input  logic        pause,           // core paused: freeze the 68000 and the YMF271 sample clock

	input  logic        latch_wr,        // PSX write to 0x1FB00000
	input  logic  [7:0] latch_din,
	input  logic        irq_wr,          // PSX write to 0x1FB00004

	output logic        mem_req,         // one-clock request pulse; mem_addr held until mem_ack
	output logic [26:0] mem_addr,        // byte address, 16-byte aligned
	input  logic        mem_ack,         // one-clock pulse, mem_data valid
	input  logic [127:0] mem_data,       // byte k of the line in [8k+7:8k]

	output logic signed [15:0] out_l,
	output logic signed [15:0] out_r,

	output logic [63:0] dbg,
	output logic        dbg_ymf_wr,      // simulation visibility of the YMF271 write stream
	output logic  [3:0] dbg_ymf_addr,
	output logic  [7:0] dbg_ymf_data,
	output logic        dbg_sample,      // YMF271 produced a sample (out_l/out_r updated)
	output logic [63:0] dbg_bus,         // 68000 bus snapshot (simulation)
	output logic  [2:0] dbg_bstate
);

wire rst = reset | ~enable;

// ---------------------------------------------------------------------------
// 68000 clock enables: 24 MHz of phi edges from 33.8688 MHz (ratio 1875/2646)
// ---------------------------------------------------------------------------
logic [11:0] ce_acc;
logic        ce_phase;
logic        en_phi1, en_phi2;
wire  [12:0] ce_next = {1'b0, ce_acc} + 13'd1875;
wire         ce_tick = ce_next >= 13'd2646;
always_ff @(posedge clk) begin
	if (rst) begin
		ce_acc <= '0; ce_phase <= 1'b0;
	end else if (!pause) begin
		ce_acc <= ce_tick ? 12'(ce_next - 13'd2646) : ce_next[11:0];
		if (ce_tick) ce_phase <= ~ce_phase;
	end
end
assign en_phi1 = !rst && !pause && ce_tick && !ce_phase;
assign en_phi2 = !rst && !pause && ce_tick &&  ce_phase;

// ---------------------------------------------------------------------------
// 68000
// ---------------------------------------------------------------------------
logic [23:1] eab;
logic [15:0] cpu_dout, cpu_din;   // cpu_din driven combinationally by the bus handler
logic        as_n, uds_n, lds_n, rw_n;
logic        dtack_n, vpa_n;
logic  [2:0] fc;
logic  [2:0] ipl_n;

fx68k cpu (
	.clk(clk), .HALTn(1'b1), .extReset(rst), .pwrUp(rst),
	.enPhi1(en_phi1), .enPhi2(en_phi2),
	.eRWn(rw_n), .ASn(as_n), .LDSn(lds_n), .UDSn(uds_n),
	.E(), .VMAn(), .FC0(fc[0]), .FC1(fc[1]), .FC2(fc[2]),
	.BGn(), .oRESETn(), .oHALTEDn(),
	.DTACKn(dtack_n), .VPAn(vpa_n), .BERRn(1'b1),
	.BRn(1'b1), .BGACKn(1'b1),
	.IPL0n(ipl_n[0]), .IPL1n(ipl_n[1]), .IPL2n(ipl_n[2]),
	.iEdb(cpu_din), .oEdb(cpu_dout), .eab(eab)
);

wire [23:0] a        = {eab, 1'b0};
wire        iack     = !as_n && fc == 3'b111;
wire        transfer = !as_n && (!uds_n || !lds_n) && !iack;

// ---------------------------------------------------------------------------
// Sound latch and IRQ2 (MAME HOLD_LINE: stays asserted until acknowledged)
// ---------------------------------------------------------------------------
logic [7:0] latch;
logic       irq2;
logic       iack_seen;
always_ff @(posedge clk) begin
	if (latch_wr) latch <= latch_din;
	if (rst) begin
		irq2 <= 1'b0; iack_seen <= 1'b0;
	end else begin
		iack_seen <= iack;
		if (irq_wr) irq2 <= 1'b1;
		else if (iack && !iack_seen && eab[3:1] == 3'd2) irq2 <= 1'b0;
	end
end
assign ipl_n = irq2 ? 3'b101 : 3'b111;
assign vpa_n = !iack;          // autovector for every interrupt acknowledge

// ---------------------------------------------------------------------------
// Work RAM: 16 KiB, mirrored over 0x080000-0x0FFFFF
// ---------------------------------------------------------------------------
logic [1:0][7:0] wram [0:8191];
logic [12:0] wram_wa;
logic  [1:0] wram_be;
logic        wram_we;
logic [15:0] wram_d, wram_q;
always_ff @(posedge clk) begin
	if (wram_we) begin
		if (wram_be[1]) wram[wram_wa][1] <= wram_d[15:8];
		if (wram_be[0]) wram[wram_wa][0] <= wram_d[7:0];
	end
	wram_q <= wram[eab[13:1]];      // bus address is stable for the whole cycle
end

// ---------------------------------------------------------------------------
// Program ROM cache: 4 KiB direct mapped, 16-byte lines. ROM bytes are stored
// in SDRAM in file order (even address in the low byte of each 16-bit word).
// ---------------------------------------------------------------------------
logic [127:0] cdata [0:255];
logic   [7:0] ctag  [0:255];    // {valid, A[18:12]}
logic   [7:0] c_widx;
logic [127:0] cdata_q;
logic   [7:0] ctag_q;
logic         c_fill;
logic [127:0] c_fill_data;
logic   [7:0] c_fill_tag;
always_ff @(posedge clk) begin
	if (c_fill) begin
		cdata[c_widx] <= c_fill_data;
		ctag[c_widx]  <= c_fill_tag;
	end
	cdata_q <= cdata[eab[11:4]];
	ctag_q  <= ctag[eab[11:4]];
end
// cache invalidation after reset: walk all 256 tags
logic       c_clr;
logic [7:0] c_clr_idx;

// ---------------------------------------------------------------------------
// YMF271
// ---------------------------------------------------------------------------
logic        ymf_wr;
logic  [7:0] ymf_dout;
logic        ymf_fetch_req, ymf_fetch_ack;
logic [17:0] ymf_fetch_line;
logic [15:0] ymf_ovr, ymf_stalls;
logic  [9:0] ymf_cycles;
logic        ymf_wbusy;
logic        ymf_strobe;

ymf271 #(.HEXDIR(HEXDIR)) ymf (
	.clk(clk), .reset(rst), .pause(pause),
	.cpu_wr(ymf_wr), .cpu_addr(a[4:1]), .cpu_din(cpu_dout[7:0]), .cpu_dout(ymf_dout),
	.fetch_req(ymf_fetch_req), .fetch_line(ymf_fetch_line), .fetch_ack(ymf_fetch_ack), .fetch_data(mem_data),
	.out_l(out_l), .out_r(out_r), .out_strobe(ymf_strobe),
	.test_hold(1'b0), .test_fast(1'b0), .dbg_wbusy(ymf_wbusy),
	.dbg_overruns(ymf_ovr), .dbg_stalls(ymf_stalls), .dbg_cycles(ymf_cycles)
);

// ---------------------------------------------------------------------------
// Memory port arbiter: one outstanding line read; YMF first.
// ---------------------------------------------------------------------------
logic mem_busy, mem_owner_cpu;
logic cpu_miss;                 // CPU waits for a program line (held until the fill)
logic cpu_issued;               // the request for the current miss has been issued
logic cpu_fill_done;
always_ff @(posedge clk) begin
	mem_req       <= 1'b0;
	ymf_fetch_ack <= 1'b0;
	cpu_fill_done <= 1'b0;
	if (!cpu_miss) cpu_issued <= 1'b0;
	if (rst) begin
		mem_busy <= 1'b0; cpu_issued <= 1'b0;
	end else if (!mem_busy) begin
		// not while an acknowledge is being delivered: the YMF pops its queue in that
		// clock and fetch_req still reflects the entry being answered
		if (ymf_fetch_req && !ymf_fetch_ack) begin
			mem_req <= 1'b1; mem_busy <= 1'b1; mem_owner_cpu <= 1'b0;
			mem_addr <= SAMPLE_BASE + {5'd0, ymf_fetch_line, 4'd0};
		end else if (cpu_miss && !cpu_issued) begin
			mem_req <= 1'b1; mem_busy <= 1'b1; mem_owner_cpu <= 1'b1; cpu_issued <= 1'b1;
			mem_addr <= PROG_BASE + {8'd0, a[18:4], 4'd0};
		end
	end else if (mem_ack) begin
		mem_busy <= 1'b0;
		if (mem_owner_cpu) cpu_fill_done <= 1'b1;
		else               ymf_fetch_ack <= 1'b1;
	end
end

// ---------------------------------------------------------------------------
// 68000 bus cycle handler. Zero wait states like the real board: DTACK is
// asserted as soon as the bus address has been stable for one clock (so the
// synchronous RAM / cache outputs belong to it). fx68k samples DTACK on every
// PHI2, and for writes UDS/LDS assert only one phase before that sample, so the
// write side effects are triggered by the data strobes independently of DTACK.
// A program-cache miss holds DTACK until the line arrives from SDRAM.
// ---------------------------------------------------------------------------
wire sel_rom   = a[23:19] == 5'b00000;
wire sel_ram   = a[23:19] == 5'b00001;
wire sel_ymf   = a[23:5]  == 19'h08000;          // 0x100000-0x10001F
wire sel_latch = a[23:1]  == 23'h0C0004;         // 0x180008-0x180009

logic [23:1] eab_d;
logic        wr_done;        // write side effect done for this bus cycle
logic        fill_ack;       // miss answered, hold DTACK until AS rises
logic [15:0] fill_word;
wire         cyc        = !as_n && !iack;
wire         addr_ok    = eab == eab_d && !c_clr;
wire         rom_hit    = ctag_q == {1'b1, a[18:12]};
wire  [15:0] cache_word = cdata_q[a[3:1]*16 +: 16];
wire  [15:0] fill_sel   = mem_data[a[3:1]*16 +: 16];

assign dtack_n = !(fill_ack || (cyc && addr_ok && (!sel_rom || !rw_n || rom_hit)));

always_comb begin
	if (fill_ack)       cpu_din = fill_word;
	else if (sel_rom)   cpu_din = {cache_word[7:0], cache_word[15:8]};   // SDRAM holds even byte low
	else if (sel_ram)   cpu_din = wram_q;
	else if (sel_ymf)   cpu_din = {8'h00, ymf_dout};
	else if (sel_latch) cpu_din = {8'h00, latch};
	else                cpu_din = 16'h0000;
end

always_ff @(posedge clk) begin
	ymf_wr  <= 1'b0;
	wram_we <= 1'b0;
	c_fill  <= 1'b0;
	eab_d   <= eab;
	if (rst) begin
		wr_done <= 1'b0; fill_ack <= 1'b0; cpu_miss <= 1'b0;
		c_clr <= 1'b1; c_clr_idx <= '0;
	end else begin
		if (as_n) begin wr_done <= 1'b0; fill_ack <= 1'b0; end

		if (c_clr) begin
			// invalidate the cache after reset (the ROM may have been reloaded)
			c_widx <= c_clr_idx; c_fill <= 1'b1; c_fill_tag <= '0;
			c_clr_idx <= c_clr_idx + 1'd1;
			if (c_clr_idx == 8'hFF) c_clr <= 1'b0;
		end

		// writes: act once per bus cycle when the data strobes are valid
		if (cyc && !rw_n && (!uds_n || !lds_n) && !wr_done) begin
			wr_done <= 1'b1;
			if (sel_ram) begin
				wram_we <= 1'b1;
				wram_wa <= a[13:1];
				wram_be <= {!uds_n, !lds_n};
				wram_d  <= cpu_dout;
			end
			if (sel_ymf) ymf_wr <= !lds_n;            // YMF271 sits on the low byte lane
		end

		// program-cache miss
		if (cyc && rw_n && sel_rom && addr_ok && !rom_hit && !cpu_miss && !fill_ack)
			cpu_miss <= 1'b1;
		if (cpu_fill_done) begin
			cpu_miss    <= 1'b0;
			fill_ack    <= 1'b1;
			fill_word   <= {fill_sel[7:0], fill_sel[15:8]};
			c_fill      <= 1'b1;
			c_widx      <= a[11:4];
			c_fill_data <= mem_data;
			c_fill_tag  <= {1'b1, a[18:12]};
		end
	end
end

// ---------------------------------------------------------------------------
// Debug / instrumentation
// ---------------------------------------------------------------------------
logic [15:0] dbg_irqs, dbg_latch_reads, dbg_ymf_writes;
logic        as_d;
always_ff @(posedge clk) begin
	as_d <= as_n;
	if (rst) begin
		dbg_irqs <= '0; dbg_latch_reads <= '0; dbg_ymf_writes <= '0;
	end else begin
		if (iack && !iack_seen) dbg_irqs <= dbg_irqs + 1'd1;
		if (as_d && !as_n && rw_n && sel_latch) dbg_latch_reads <= dbg_latch_reads + 1'd1;
		if (ymf_wr) dbg_ymf_writes <= dbg_ymf_writes + 1'd1;
	end
end
assign dbg = {dbg_irqs, dbg_latch_reads, dbg_ymf_writes, ymf_ovr};
assign dbg_ymf_wr   = ymf_wr;
assign dbg_ymf_addr = a[4:1];
assign dbg_ymf_data = cpu_dout[7:0];
assign dbg_sample   = ymf_strobe;
assign dbg_bus      = {as_n, uds_n, lds_n, rw_n, dtack_n, fc, a, cpu_din, cpu_dout};
assign dbg_bstate   = {cpu_miss, fill_ack, wr_done};

endmodule
