// ModelSim bench: the real memorymux.vhd decoding PSX stores into the external sound
// bus, feeding zn_ext_audio with the board selected by +define (FX1A or RAIZING).
// Drives the exact store sequence a game issues, as the CPU core does: word-aligned address,
// halfword at offset 2 = data in [31:16] with mask 1100 (zn_ext_audio rebuilds the offset).
// Prints what reaches the board.
`timescale 1ns/1ps
module tb_mm;
logic clk1x = 0, clk2x = 0;
always #14.76 clk1x = ~clk1x;          // 33.8688 MHz
always #7.38  clk2x = ~clk2x;
logic reset = 1;

logic        req = 0, rnw = 1;
logic [31:0] addr = 0, wdata = 0;
logic [3:0]  wmask = 0;
logic [1:0]  rsize = 2'b10;
logic        done;
logic [31:0] rdata;

logic        e_wr, e_rd, e_ack;
logic [23:0] e_addr;
logic [31:0] e_din, e_dout;
logic [3:0]  e_be;
logic [7:0]  board;

memorymux mm (
	.clk1x(clk1x), .clk2x(clk2x), .ce(1'b1), .reset(reset), .pauseNext(1'b0), .isIdle(),
	.loadExe(1'b0), .exe_initial_pc(32'd0), .exe_initial_gp(32'd0), .exe_load_address(32'd0),
	.exe_file_size(32'd0), .exe_stackpointer(32'd0), .reset_exe(), .fastboot(1'b0), .PATCHSERIAL(1'b0),
	.TURBO(1'b0), .ROM_PREFETCH(1'b0), .FAST_BIOS(1'b0), .region_in(2'b00),
	.ram_dataWrite(), .ram_dataRead(32'd0), .ram_Adr(), .ram_be(), .ram_rnw(), .ram_ena(), .ram_cache(), .ram_done(1'b1),
	.mem_in_request(req), .mem_in_rnw(rnw), .mem_in_isData(1'b1), .mem_in_isCache(1'b0), .mem_in_oldtagvalids(4'd0),
	.mem_in_addressInstr(32'd0), .mem_in_addressData(addr), .mem_in_reqsize(rsize), .mem_in_writeMask(wmask),
	.mem_in_dataWrite(wdata), .mem_dataRead(rdata), .mem_done(done), .mem_fifofull(), .mem_tagvalids(),
	.bios_memctrl(14'd0), .ex1_memctrl(14'd0), .bus_exp1_read(), .bus_exp1_dataRead(8'd0),
	.bus_memc_addr(), .bus_memc_dataWrite(), .bus_memc_read(), .bus_memc_write(), .bus_memc_dataRead(32'd0),
	.bus_pad_addr(), .bus_pad_dataWrite(), .bus_pad_read(), .bus_pad_write(), .bus_pad_writeMask(), .bus_pad_dataRead(32'd0),
	.bus_sio_addr(), .bus_sio_dataWrite(), .bus_sio_read(), .bus_sio_write(), .bus_sio_writeMask(), .bus_sio_dataRead(32'd0),
	.bus_memc2_addr(), .bus_memc2_dataWrite(), .bus_memc2_read(), .bus_memc2_write(), .bus_memc2_dataRead(32'd0),
	.bus_irq_addr(), .bus_irq_dataWrite(), .bus_irq_read(), .bus_irq_write(), .bus_irq_dataRead(32'd0),
	.bus_dma_addr(), .bus_dma_dataWrite(), .bus_dma_read(), .bus_dma_write(), .bus_dma_dataRead(32'd0),
	.bus_tmr_addr(), .bus_tmr_dataWrite(), .bus_tmr_read(), .bus_tmr_write(), .bus_tmr_dataRead(32'd0),
	.cd_memctrl(14'd0), .bus_cd_addr(), .bus_cd_dataWrite(), .bus_cd_read(), .bus_cd_write(), .bus_cd_dataRead(8'd0),
	.bus_gpu_addr(), .bus_gpu_dataWrite(), .bus_gpu_read(), .bus_gpu_write(), .bus_gpu_dataRead(32'd0), .bus_gpu_stall(1'b0),
	.bus_mdec_addr(), .bus_mdec_dataWrite(), .bus_mdec_read(), .bus_mdec_write(), .bus_mdec_dataRead(32'd0),
	.bus_znio_addr(), .bus_znio_dataWrite(), .bus_znio_read(), .bus_znio_write(), .bus_znio_writeMask(), .bus_znio_dataRead(32'd0),
	.zn_platform(`PLATFORM), .dbg_zn_bank(),
	.zn_ext_audio(board), .ext_snd_wr(e_wr), .ext_snd_rd(e_rd), .ext_snd_addr(e_addr), .ext_snd_din(e_din),
	.ext_snd_be(e_be), .ext_snd_dout(e_dout), .ext_snd_ack(e_ack),
	.spu_memctrl(14'd0), .bus_spu_addr(), .bus_spu_dataWrite(), .bus_spu_read(), .bus_spu_write(), .bus_spu_dataRead(16'd0),
	.ex2_memctrl(14'd0), .bus_exp2_addr(), .bus_exp2_dataWrite(), .bus_exp2_read(), .bus_exp2_write(), .bus_exp2_dataRead(8'd0),
	.ex3_memctrl(14'd0), .bus_exp3_read(), .bus_exp3_dataRead(16'd0),
	.com0_delay(4'd0), .com1_delay(4'd0), .com2_delay(4'd0), .com3_delay(4'd0),
	.loading_savestate(1'b0), .SS_reset(1'b0), .SS_DataWrite(32'd0), .SS_Adr(19'd0), .SS_wren_SDRam(1'b0), .SS_rden_SDRam(1'b0),
	.zn_bank_8mb_out()
);

// the board under test (memory port answered by a trivial model)
logic        m_req, m_ack = 0;
logic [26:0] m_addr;
logic [15:0] o_l, o_r;
logic [127:0] diag;
logic        en;
zn_ext_audio ext (
	.clk(clk1x), .reset(reset), .pause(1'b0), .mra_board(`BOARD), .prog_loaded(1'b1), .smp_loaded(1'b1),
	.active_board(board), .enable(en),
	.bus_wr(e_wr), .bus_rd(e_rd), .bus_addr(e_addr), .bus_din(e_din), .bus_be(e_be), .bus_dout(e_dout), .bus_ack(e_ack),
	.mem_req(m_req), .mem_addr(m_addr), .mem_ack(m_ack), .mem_data(128'd0),
	.spu_l(16'd0), .spu_r(16'd0), .out_l(o_l), .out_r(o_r), .diag(diag),
	.dbg_dev_wr(), .dbg_dev_addr(), .dbg_dev_data(), .dbg_sample(), .dbg_brd_l(), .dbg_brd_r()
);
always @(posedge clk1x) m_ack <= m_req;

always @(posedge clk1x) if (e_wr) $display("%t ext_snd_wr addr=%06h din=%08h be=%b", $time, e_addr, e_din, e_be);

task automatic store(input [31:0] a, input [31:0] d, input [3:0] m, input [1:0] sz);
	@(posedge clk1x); addr <= a; wdata <= d; wmask <= m; rsize <= sz; rnw <= 0; req <= 1;
	@(posedge clk1x); req <= 0;
	repeat (20) @(posedge clk1x);
endtask

initial begin
	repeat (20) @(posedge clk1x);
	reset <= 0;
	repeat (20) @(posedge clk1x);
	$display("board active = %h, enable = %b", board, en);
`ifdef FX1A
	// Psychic Force at 18.36 s: mode 4 (sh 0x1FB80000 = 0x0404), comm 1 (sh 0x1FB80002 = 0x0101)
	store(32'h1FB80000, 32'h00000404, 4'b0011, 2'b01);
	store(32'h1FB80000, 32'h01010000, 4'b1100, 2'b01);
	$display("SYT: mainmode=%0d z80_reset=%b", ext.taito_fx1a.syt_mainmode, ext.taito_fx1a.syt_z80_reset);
	store(32'h1FB80000, 32'h00000404, 4'b0011, 2'b01);
	store(32'h1FB80000, 32'h00000000, 4'b1100, 2'b01);
	$display("SYT: mainmode=%0d z80_reset=%b", ext.taito_fx1a.syt_mainmode, ext.taito_fx1a.syt_z80_reset);
	// command: mode 2, comm 0x03 (nibble 3) ... as at 20.36 s
	store(32'h1FB80000, 32'h00000202, 4'b0011, 2'b01);
	store(32'h1FB80000, 32'h00000000, 4'b1100, 2'b01);
	store(32'h1FB80000, 32'h00000303, 4'b0011, 2'b01);
	store(32'h1FB80000, 32'h03030000, 4'b1100, 2'b01);
	$display("SYT: slave2=%h slave3=%h status=%b", ext.taito_fx1a.syt_slave[2], ext.taito_fx1a.syt_slave[3], ext.taito_fx1a.syt_status);
`else
	store(32'h1FB00000, 32'h00000008, 4'b0011, 2'b01);
	store(32'h1FB00004, 32'h00000000, 4'b0011, 2'b01);
`endif
	$finish;
end
endmodule
