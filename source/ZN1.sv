//============================================================================
//  PSX
//  Copyright (C) 2019 Robert Peip
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign HDMI_FREEZE = 1'b0;
assign HDMI_BOB_DEINT = status[41];

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = bios_download | fixedrom_download | bankedrom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [ 3:0] frameindex;
wire [11:0] DisplayWidth;
wire [11:0] DisplayHeight;
wire [ 9:0] DisplayOffsetX;
wire [ 8:0] DisplayOffsetY;

assign FB_BASE    = status[11] ? 32'h30000000 : {8'h30, frameindex, DisplayOffsetY, DisplayOffsetX, 1'b0};
assign FB_EN      = (status[14] || video_fbmode);
assign FB_FORMAT  = (status[10] || video_fb24) ? 5'b00101 : 5'b01100;
assign FB_WIDTH   = status[11] ? 12'd1024 : DisplayWidth;
assign FB_HEIGHT  = status[11] ? 12'd512  : DisplayHeight;
assign FB_STRIDE  = 14'd2048;
assign FB_FORCE_BLANK = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_1x;
wire clk_2x;
wire clk_3x;
wire clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_2x),
	.outclk_2(clk_3x),
	.locked(pll_locked)
);

pll2 pll2
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
   .reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);


wire FFrequest = joy[17] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoOut = 0; //status[57] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoClock = 0; //status[56] && ~FB_LL && ~DIRECT_VIDEO;

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg pdbg = 0, pdbg2 = 0;
	reg pffw = 0, pffw2 = 0;
	reg [3:0] state = 0;

	pald  <= isPal;
	pald2 <= pald;

	pdbg  <= syncVideoClock;
	pdbg2 <= pdbg;

	pffw  <= fast_forward;
	pffw2 <= pffw;

	cfg_write <= 0;
	if(pald2 != pald || pdbg2 != pdbg || pffw2 != pffw) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
         3: begin
					cfg_address <= 5;
					cfg_data <= pffw2 ? 131842 : pdbg2 ? 771 : 1028;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pffw2 ? 2147483648 : pdbg2 ? 551954751 : pald2 ? 2201376898 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg fast_forward;
reg ff_latch;

always @(posedge clk_1x) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= FFrequest;

	if (FFrequest)
		ff_count <= ff_count + 1;

	if (~last_ffw & FFrequest) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~FFrequest)) begin
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (FFrequest | ff_latch);
end

wire reset_or = RESET | buttons[1] | status[0] | ioctl_download | la_src[11];  // la_src[11]=JTAG reset

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6          7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//  XXXX XXXXXX XXXXXX XXXXX  XX XX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"ZN1;;",
	"P1,Video & Audio;",
	"P1-;",
	"P1O[33:32],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[35:34],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"DEP1O[62],Fixed HBlank,On,Off;",
	"DEP1O[55],Fixed VBlank,Off,On;",
	"d5P1O[4:3],Vertical Crop,Off,On(224/270),On(216/256);",
	"P1O[67],Horizontal Crop,Off,On;",
	"P1O[61],Black Transitions,On,Off;",
	"P1O[41],Deinterlacing,Weave,Bob;",
	"P1O[89],Render 480i as 480p,Off,On;",
	"P1O[60],Sync 480i for HDMI,Off,On;",
	"P1O[24],Rotate,Off,On;",
	"P1O[25],Pause Screen,Horizontal,Vertical;",
	"P1-;",
	"P1O[22],Dithering,On,Off;",
	"P1O[8:7],Stereo Mix,None,25%,50%,100%;",
	"-;",
	"P2,Debug;",
	"P2O[93],Boot Debug Overlay,Off,On;",
	"P2O[94],Test Mode,Off,On;",
	"P2O[95],Service Mode,Off,On;",
	"-;",
	"DIP;",
	"-;",
	// Hidden: PSX_MiSTer leftovers not required by the ZN-1 core. The status bits
	// still exist (default 0 = Off = safe) so the datapath is unchanged; these
	// menu entries are hidden and may be removed entirely later.
	//	"O[79],Turbo,Off,Full;",
	//	"O[80],SDRAM Page-Mode,Off,On;",
	//	"O[81],ROM Prefetch,Off,On;",
	//	"O[82],Fast BIOS,Off,On;",
	//	"O[83],Fast Math,Off,On;",
	//	"O[84],CPU Late-Read Skip,Off,On;",
	//	"O[85],Data Cache,Off,On;",
	"R0,Reset;",
	"J1,Button1,Button2,Button3,Button4,Button5,Button6,Start,Coin,Pause;",
	"jn,A,B,X,Y,L,R,Start,Select,L3;",
	"V,v",`BUILD_DATE
};

reg dbg_enabled = 0;
wire  [1:0] buttons;
wire [127:0] status;
wire [15:0] status_menumask = 16'h0000;
wire        forced_scandoubler;
reg  [31:0] sd_lba0 = 0;
reg  [31:0] sd_lba1;
reg  [ 6:0] sd_lba2;
reg  [ 6:0] sd_lba3;
reg   [3:0] sd_rd;
reg   [3:0] sd_wr;
wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din2;
wire [15:0] sd_buff_din3;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

wire [19:0] joy;
wire [19:0] joy_unmod;
wire [19:0] joy2;
wire [19:0] joy3;
wire [19:0] joy4;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_r0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_r1;
wire [15:0] joystick_analog_l2;
wire [15:0] joystick_analog_r2;
wire [15:0] joystick_analog_l3;
wire [15:0] joystick_analog_r3;

wire [7:0] paddle_0;

wire [24:0] mouse;

wire [15:0] joystick1_rumble;
wire [15:0] joystick2_rumble;
wire [15:0] joystick3_rumble;
wire [15:0] joystick4_rumble;
wire [32:0] RTC_time;

wire filter_on = (status[82:81] == 2'b00) ? 1'b0 : 1'b1;

assign HDMI_BLACKOUT = ~status[61];

wire [127:0] status_in = {status[127:39],ss_slot,status[36:19], 2'b00, status[16:0]};

wire bk_pending = 1'b0;
wire saving_memcard = 1'b0;
wire DIRECT_VIDEO;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(4), .BLKSZ(3)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(EXT_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(statusUpdate),
	.status_menumask(status_menumask),
	.info_req(psx_info_req),
	.info(psx_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba0, sd_lba1, sd_lba2, sd_lba3}),
	.sd_blk_cnt('{0,0, 0, 0}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{0, 0, sd_buff_din2, sd_buff_din3}),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_l_analog_0(joystick_analog_l0),
   .joystick_r_analog_0(joystick_analog_r0),
   .joystick_l_analog_1(joystick_analog_l1),
   .joystick_r_analog_1(joystick_analog_r1),
   .joystick_l_analog_2(joystick_analog_l2),
   .joystick_r_analog_2(joystick_analog_r2),
   .joystick_l_analog_3(joystick_analog_l3),
   .joystick_r_analog_3(joystick_analog_r3),
   .ps2_mouse(mouse),
   .joystick_0_rumble(paused ? 16'h0000 : joystick1_rumble),
   .joystick_1_rumble(paused ? 16'h0000 : joystick2_rumble),

   .paddle_0(paddle_0),

   .direct_video(DIRECT_VIDEO)
);

assign joy = joy_unmod[16] ? 20'b0 : joy_unmod;

assign sd_rd[0] = 0;
assign sd_wr[0] = 0;

assign sd_wr[1] = 0;

wire [35:0] EXT_BUS;
wire        heartbeat;

hps_ext hps_ext
(
	.clk_sys(clk_1x),
	.EXT_BUS(EXT_BUS),
	.heartbeat(heartbeat)
);


//////////////////////////  ROM DETECT  /////////////////////////////////

// SDRAM layout (25-bit byte address, flat):
//   0x0000000-0x03FFFFF: Main RAM   (4MB)
//   0x0400000-0x047FFFF: BIOS       (512KB) — ioctl_index 0, CPU 0x1FC00000
//   0x0480000-0x06FFFFF: Fixed ROM  (2.5MB) — ioctl_index 2, CPU 0x1F000000
//   0x0800000-0x3FFFFFF: Banked ROM (up to 56MB, 7 banks×8MB) — ioctl_index 3, CPU 0x1F000000
localparam BIOS_START      = 27'h0400000;
localparam FIXEDROM_START  = 27'h0480000;
localparam BANKEDROM_START = 27'h0800000;

reg bios_download, fixedrom_download, bankedrom_download, code_download;
reg eeprom_download;
always @(posedge clk_1x) begin
	bios_download       <= ioctl_download & (ioctl_index[5:0] == 0);
	fixedrom_download   <= ioctl_download & (ioctl_index == 2);
	bankedrom_download  <= ioctl_download & (ioctl_index == 3);
	eeprom_download     <= ioctl_download & (ioctl_index == 9);   // AT28C16 EEPROM preload -> zn1_io
	code_download       <= ioctl_download & (ioctl_index == 255);
end

// EEPROM preload writer (MRA index 9). 16-bit ioctl_dout carries 2 bytes (little-endian:
// ioctl_dout[7:0]=even byte, [15:8]=odd byte). Pack into the correct 16-bit lane of the
// 32-bit EEPROM word (word addr = ioctl_addr[10:2], 2KB=512 words) with a matching byte
// enable, and pulse ee_dl_wr. Games with no index-9 part never assert this, keeping the
// eeprom_ff.mif (0xFF) default. Used to preload the Taito FX-1A "TAITO_TG..." NVRAM signature.
reg        zn_ee_dl_wr = 0;
reg [8:0]  zn_ee_dl_addr;
reg [31:0] zn_ee_dl_data;
reg [3:0]  zn_ee_dl_be;
always @(posedge clk_1x) begin
	zn_ee_dl_wr <= 0;
	if (eeprom_download & ioctl_wr) begin
		zn_ee_dl_addr <= ioctl_addr[10:2];
		if (ioctl_addr[1] == 1'b0) begin
			zn_ee_dl_data <= {16'h0000, ioctl_dout};
			zn_ee_dl_be   <= 4'b0011;
		end else begin
			zn_ee_dl_data <= {ioctl_dout, 16'h0000};
			zn_ee_dl_be   <= 4'b1100;
		end
		zn_ee_dl_wr <= 1;
	end
end

// DIAGNOSTIC (temporary): count index-9 ioctl writes the framework delivers, and ee_dl_wr
// pulses my packing fires, so the debug overlay (RED/GREEN bars) reveals where the EEPROM
// preload breaks. RED full-width => framework delivers index 9; GREEN full => packing fires.
reg [8:0] dbg_ee_idx9_cnt = 0;
reg [8:0] dbg_ee_dlwr_cnt = 0;
always @(posedge clk_1x) begin
	if (ioctl_download & (ioctl_index == 9) & ioctl_wr & (dbg_ee_idx9_cnt < 9'd351))
		dbg_ee_idx9_cnt <= dbg_ee_idx9_cnt + 1'd1;
	if (zn_ee_dl_wr & (dbg_ee_dlwr_cnt < 9'd351))
		dbg_ee_dlwr_cnt <= dbg_ee_dlwr_cnt + 1'd1;
end

// Dynamic platform config and CAT702 key loading (from MRA rom index 1/4/5)
reg [7:0]  zn_platform_r  = 8'h00;              // ioctl_index 1: platform id (0=Visco, 1=Raizing, 2=Taito, 3=Atlus, 4=Tecmo)
// Default: COH-1002M mg01 key (80 F2 30 38 F9 FD 1C E0, byte[0] at [7:0]).
// Overwritten by MRA index 4 download when game ROM is loaded.
reg [63:0] zn_cat702_key_a  = 64'hE01CFDF93830F280;
// Default: DoA++ mg05 key (80 C2 38 F9 FD 0C 10 E0, byte[0] at [7:0]).
// Overwritten by MRA index 5 download when game ROM is loaded.
reg [63:0] zn_cat702_key_b_r = 64'hE0100CFDF938C280;

always @(posedge clk_1x) begin
	if (ioctl_wr) begin
		if (ioctl_index[5:0] == 1) begin
			zn_platform_r <= ioctl_dout[7:0];
		end else if (ioctl_index[5:0] == 4) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_a[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_a[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_a[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_a[63:48] <= ioctl_dout;
			endcase
		end else if (ioctl_index[5:0] == 5) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_b_r[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_b_r[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_b_r[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_b_r[63:48] <= ioctl_dout;
			endcase
		end
	end
end

// exe_download stub (unused in ZN, retained for save-state UI compatibility)
wire exe_download = 1'b0;

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (fixedrom_download || bankedrom_download) cart_loaded <= 1;
end

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

// ZN uses no CD
wire hasCD = 1'b0;

// loadExe and EXE header fields unused in ZN (no .EXE loading)
wire loadExe = 1'b0;
wire [31:0] exe_initial_pc    = 32'h0;
wire [31:0] exe_initial_gp    = 32'h0;
wire [31:0] exe_load_address  = 32'h0;
wire [31:0] exe_file_size     = 32'h0;
wire [31:0] exe_stackpointer  = 32'h0;

reg  [1:0] biosregion;
wire [1:0] region_out;
reg        isPal;

// ZN-1 Visco: NTSC-J (region JP)
always @(posedge clk_1x) begin
   isPal     <= 1'b0;
   biosregion <= 2'b01;  // JP BIOS
end

// ===== B-inst6 (raystorm #286): WRITE-SIDE shadow checksum of the banked-ROM download =====
// Sums the 16-bit halves of every 32-bit word committed to the R-3 image window
// 0x600000-0x7FFFFF during the index-3 download (lo = 0x600000-0x6FFFFF only).
// Compare vs the READ-side shadow (B-inst5 rs2_sum_*): matching-but-wrong on both sides
// means the ioctl stream itself is corrupt; write-side correct + read-side wrong means
// SDRAM retention or the CPU read path. Expected: all=0x7F9E lo=0xA1D5 wcnt>>4=0x8000.
reg [15:0] dl_sum_all = 0, dl_sum_lo = 0;
reg [19:0] dl_wcnt = 0;
reg        bankedrom_download_d = 0;
always @(posedge clk_1x) begin
   bankedrom_download_d <= bankedrom_download;
   if (bankedrom_download & ~bankedrom_download_d) begin
      dl_sum_all <= 0; dl_sum_lo <= 0; dl_wcnt <= 0;   // fresh download
   end else if (bankedrom_download & ramdownload_wr_pre & (ioctl_addr[26:21] == 6'd3)) begin
      dl_sum_all <= dl_sum_all + dl_wr_lo16 + dl_wr_hi16;
      dl_wcnt    <= dl_wcnt + 1;
      if (~ioctl_addr[20]) dl_sum_lo <= dl_sum_lo + dl_wr_lo16 + dl_wr_hi16;
   end
end
// the committed word = {ioctl_dout(high half, this cycle), wrdata[15:0](latched low half)}
wire        ramdownload_wr_pre = ioctl_wr & ioctl_addr[1];
wire [15:0] dl_wr_lo16 = ramdownload_wrdata[15:0];
wire [15:0] dl_wr_hi16 = ioctl_dout;

altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (0),
	.instance_id             ("ZND2"),
	.probe_width             (64),
	.source_width            (1),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_jtag_dl (
	.probe      ({dl_sum_all, dl_sum_lo, dl_wcnt[19:4], 16'hB157}),
	.source     (),
	.source_clk (clk_1x),
	.source_ena (1'b1)
);

always @(posedge clk_1x) begin
   ramdownload_wr <= 0;
   if (bios_download | fixedrom_download | bankedrom_download) begin
      if (ioctl_wr) begin
         if (~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)
               // BIOS: SDRAM 0x400000 base (bit22 set, no region overlap)
               ramdownload_wraddr <= BIOS_START[26:0] | {8'b0, ioctl_addr[18:0]};
            else if (fixedrom_download)
               // Fixed ROM: SDRAM 0x480000 base (addition to handle overlapping bits)
               ramdownload_wraddr <= FIXEDROM_START[26:0] + {4'b0000, ioctl_addr[22:0]};
            else
               // Banked ROM: SDRAM 0x800000 base, 24 banks × 1MB = 24MB
               ramdownload_wraddr <= BANKEDROM_START[26:0] + ioctl_addr[26:0];
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait                <= 1;
         end
      end
      if (sdramCh3_done) ioctl_wait <= 0;
   end else begin
      ioctl_wait <= 0;
   end
end

///////////////////////////  SAVESTATE  /////////////////////////////////

wire [1:0] ss_slot;
wire [7:0] ss_info;
wire [3:0] validSStates;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_1x        ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_loaded   ),
	.joySS          (joy_unmod[16] ),
	.joyRight       (joy_unmod[0]  ),
	.joyLeft        (joy_unmod[1]  ),
	.joyDown        (joy_unmod[2]  ),
	.joyUp          (joy_unmod[3]  ),
	.joyRewind      (0             ),
	.rewindEnable   (0             ),
	.status_slot    (status[38:37] ),
	.autoincslot    (status[68]    ),
	.OSD_saveload   (status[18:17] ),
   .validSStates   (validSStates  ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

////////////////////////////  PAD  ///////////////////////////////////

// 0000 -> DualShock
// 0001 -> off
// 0010 -> digital
// 0011 -> analog
// 0100 -> Namco GunCon lightgun
// 0101 -> Namco NeGcon
// 0110 -> Wheel Negcon
// 0111 -> Wheel Analog
// 1000 -> mouse
// 1001 -> Konami Justifier lightgun
// 1010 -> SNAC
// 1011 -> Analog Joystick
// 1100..1111 -> reserved

wire PadPortDS1      = (status[48:45] == 4'b0000);
wire PadPortEnable1  = (status[48:45] != 4'b0001);
wire PadPortDigital1 = (status[48:45] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog1  = (status[48:45] == 4'b0011) || (status[48:45] == 4'b0111);
wire PadPortGunCon1  = (status[48:45] == 4'b0100);
wire PadPortNeGcon1  = (status[48:45] == 4'b0101) || (status[48:45] == 4'b0110);
wire PadPortWheel1   = (status[48:45] == 4'b0110) || (status[48:45] == 4'b0111);
wire PadPortMouse1   = (status[48:45] == 4'b1000);
wire PadPortJustif1  = (status[48:45] == 4'b1001);
wire snacPort1       = (status[48:45] == 4'b1010) && ~multitap;
wire PadPortStick1   = (status[48:45] == 4'b1011);
wire PadPortPopn1    = (status[48:45] == 4'b1100);

wire PadPortDS2      = (status[52:49] == 4'b0000);
wire PadPortEnable2  = (status[52:49] != 4'b0001) && ~multitap;
wire PadPortDigital2 = (status[52:49] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog2  = (status[52:49] == 4'b0011) || (status[52:49] == 4'b0111);
wire PadPortGunCon2  = (status[52:49] == 4'b0100);
wire PadPortNeGcon2  = (status[52:49] == 4'b0101) || (status[52:49] == 4'b0110);
wire PadPortWheel2   = (status[52:49] == 4'b0110) || (status[52:49] == 4'b0111);
wire PadPortMouse2   = (status[52:49] == 4'b1000);
wire PadPortJustif2  = (status[52:49] == 4'b1001);
wire snacPort2       = (status[52:49] == 4'b1010) && ~multitap;
wire PadPortStick2   = (status[52:49] == 4'b1011);
wire PadPortPopn2    = (status[52:49] == 4'b1100);

reg paddleMode = 0;
reg paddleMin = 0;
reg paddleMax = 0;
wire [7:0] joy0_xmuxed = (paddleMode) ? (paddle_0 - 8'd128) : joystick_analog_l0[7:0];

// to activate paddleMode negcon mode must be active and paddle must best moved
always @(posedge clk_1x) begin
   if (PadPortNeGcon1) begin
      if (paddle_0 < 112) paddleMin <= 1'b1;
      if (paddle_0 > 144) paddleMax <= 1'b1;
      if (paddleMin && paddleMax) paddleMode <= 1'b1;
   end else begin
      paddleMode <= 0;
      paddleMin <= 0;
      paddleMax <= 0;
   end
end

// 00 -> multitap off
// 01 -> port1, 4 x digital
// 10 -> port1, 4 x analog
wire multitap        = (status[57:56] != 2'b00);
wire multitapDigital = (status[57:56] == 2'b01);
wire multitapAnalog  = (status[57:56] == 2'b10);

wire [1:0] padMode;
reg  [1:0] padMode_1;

reg [7:0] psx_info;
reg psx_info_req;

wire resetFromCD = 1'b0;

reg [3:0] ToggleDS = 0;
reg [3:0] joy19_1 = 0;

always @(posedge clk_1x) begin

   psx_info_req <= 0;
   padMode_1    <= padMode;

   if (ss_info_req) begin
      psx_info_req <= 1;
      psx_info     <= ss_info;
   end

   if (joy[14] && joy[15] && joy[8]) dbg_enabled <= 1;  // L3+R3+Select

   // DS toggle (unused in arcade but kept for joypad struct compatibility)
   joy19_1 <= {joy4[19] ,joy3[19] ,joy2[19] ,joy[19] };
   ToggleDS[0] <=  joy[19] & ~joy19_1[0];
   ToggleDS[1] <= joy2[19] & ~joy19_1[1];
   ToggleDS[2] <= joy3[19] & ~joy19_1[2];
   ToggleDS[3] <= joy4[19] & ~joy19_1[3];

end

////////////////////////////  PAUSE and RESET  ///////////////////////////
reg paused = 0;
reg [9:0] unpause = 0;
reg status1_1;
wire isPaused;

reg [20:0] aliveCnt = 0;
reg heartbeat_1 = 0;
reg hps_busy = 0;

reg reset = 0;

reg buttonpause_1 = 0;
reg button_paused = 0;

reg TURBO_MEM;
reg TURBO_COMP;
reg TURBO_CACHE;
reg TURBO_CACHE50;
reg SDRAM_PAGEMODE;
reg ROM_PREFETCH;
reg FAST_BIOS;
reg FAST_MATH;
reg CPU_LATE_READ_SKIP;

always @(posedge clk_1x) begin

   paused <= 0;

   // pause from OSD open
   if (~status[64] & OSD_STATUS & (unpause == 0)) begin
      paused <= 1;
   end

   // pause from button — joy[12] = Pause button (J1 list index 8 = 9th entry)
   // J1 mapping: Button1..6 at joy[4..9], Start at joy[10], Coin at joy[11], Pause at joy[12]
   buttonpause_1 <= joy[12];
   if (joy[12] & ~buttonpause_1) begin
      button_paused <= ~button_paused;
   end
   if (button_paused) begin
      paused <= 1;
   end

   // Advance Pause OSD trigger
   status1_1 <= status[1];
   if (status[1] & ~status1_1) begin
      unpause <= 1023;
   end else if (unpause > 0) begin
      unpause <= unpause - 1'd1;
   end

   // pause from heartbeat -> only used for savestate
   hps_busy    <= 0;
   heartbeat_1 <= heartbeat;
   if (heartbeat == heartbeat_1) begin
      if (aliveCnt[20] == 0) begin
         aliveCnt <= aliveCnt + 1'b1;
      end else begin
         hps_busy <= 1;
      end
   end else begin
      aliveCnt <= 0;
   end

   // reset
   reset <= 0;
   if (reset_or) begin
      reset    <= 1;
      aliveCnt <= 0;
   end

   // 1 => low    -> only MEM
   // 2 => medium -> MEM + 50% cache
   // 3 => high   -> everything
   // Default OFF (status[79]=0). DoA++ crashed with TURBO defaulted on; leave as an opt-in
   // for experimentation per title.
   TURBO_MEM      <= status[79];
   TURBO_COMP     <= status[79];
   // status[85] = OSD opt-in for the 16KB data cache in cpu.vhd. Default OFF.
   // Synthesized but unused unless this bit OR the full Turbo bundle is on.
   // Real PSX has a 1KB scratchpad + I-cache; DoA++ math-heavy code thrashes
   // SDRAM data reads constantly without it (60% memoryMuxBusy at boot).
   // Cache is safe since the KSEG1 fix in cpu.vhd (never cache uncached-segment
   // reads); it helps CPU-bound code but not DMA/streaming-bound loads.
   TURBO_CACHE    <= status[79] | status[85];
   TURBO_CACHE50  <= 1'b0;

   // OSD opt-in for the experimental ch1 page-mode SDRAM optimization.
   // Default OFF = baseline FSM proven to work; ON enables HIT/PRECHARGE path.
   // Page-mode follows OSD (default OFF = safe baseline). la_src[10] = JTAG force page-mode ON.
   SDRAM_PAGEMODE <= status[80] | la_src[10];

   // OSD opt-in for ROM prefetch line cache in memorymux. Default OFF =
   // single-word uncached ROM reads (baseline); ON enables a 4-word line
   // buffer fed by burst-of-4 serial SDRAM reads with bank invalidation.
   ROM_PREFETCH   <= status[81];

   // OSD opt-in for zero-wait BIOS reads. The 25-26 cycle waitcnt in
   // memorymux's READBIOS → WAITING path was tuned for original PSX slow
   // ROM-chip pacing; ZN-1 BIOS lives in SDRAM and doesn't need it.
   FAST_BIOS      <= status[82];

   // B20: bypass MIPS R3000 DIV/MULT cycle pacing (37 cycles for DIV, 7-14
   // for MULT). Real hardware enforces these; MAME's interpreter may not.
   // If this toggle dramatically speeds DoA++ post-coin, math pacing IS
   // the dominant slow-window cost.
   FAST_MATH      <= status[83];

   // CPU-only TURBO_COMP: skips lateReadStall in cpu.vhd. Subset of the
   // status[79] Turbo toggle that crashed DoA++ (which also skipped
   // memorymux RAM waits + cache 50% slow-mode). This bit only affects
   // the CPU's TURBO input — DMA, memorymux, CD timing untouched.
   CPU_LATE_READ_SKIP <= status[84];

end

////////////////////////////  SYSTEM  ///////////////////////////////////

psx_mister
psx
(
   .clk1x(clk_1x),
   .clk2x(clk_2x),
   .clk3x(clk_3x),
   .clkvid(clk_vid),
   .reset(reset),
   .isPaused(isPaused),
   // commands
   .pause(paused),
   .hps_busy(hps_busy),
   .loadExe(loadExe),
   .exe_initial_pc(exe_initial_pc),
   .exe_initial_gp(exe_initial_gp),
   .exe_load_address(exe_load_address),
   .exe_file_size(exe_file_size),
   .exe_stackpointer(exe_stackpointer),
   .fastboot(status[16] && hasCD),
   .ram8mb(1'b1),
   .TURBO_MEM(TURBO_MEM),
   .TURBO_COMP(TURBO_COMP),
   .TURBO_CACHE(TURBO_CACHE),
   .TURBO_CACHE50(TURBO_CACHE50),
   .ROM_PREFETCH(ROM_PREFETCH),
   .FAST_BIOS(FAST_BIOS),
   .FAST_MATH(FAST_MATH),
   .CPU_LATE_READ_SKIP(CPU_LATE_READ_SKIP),
   .REPRODUCIBLEGPUTIMING(0),
   .INSTANTSEEK(status[21]),
   .FORCECDSPEED(status[77:75]),
   .LIMITREADSPEED(status[78]),
   .IGNORECDDMATIMING(status[88]),
   .ditherOff(status[22]),
   .interlaced480pHack(status[89]),
   .showGunCrosshairs(status[9]),
   .enableNeGconRumble(status[91]),
   .fpscountOn(status[28]),
   .cdslowOn(status[59]),
   .testSeek(status[70]),
   .pauseOnCDSlow(~status[72]),
   .errorOn(status[74]),
   .LBAOn(status[69]),
   .PATCHSERIAL(0), //.PATCHSERIAL(status[54]),
   .noTexture(status[27]),
   .textureFilter(status[82:81]),
   .textureFilterStrength(status[87:86]),
   .textureFilter2DOff(status[83]),
   .dither24(status[73]),
   .render24(status[84] && ~hack_480p),
   .drawSlow(status[90]),
   .syncVideoOut(syncVideoOut),
   .syncInterlace(status[60]),
   .rotate180(status[24]),
   .fixedVBlank(status[55] && ~hack_480p),
   .vCrop(hack_480p ? 2'b00 : status[4:3]),
   .hCrop(status[67]),
   .SPUon(~status[30]),
   .SPUIRQTrigger(status[2]),
   .SPUSDRAM(status[44] & SDRAM2_EN),
   .REVERBOFF(0),
   .REPRODUCIBLESPUDMA(status[43]),
   .WIDESCREEN(status[54:53]),
   .oldGPU(status[92]),   
   // RAM/BIOS interface
   .biosregion(biosregion),
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead32(sdr_sdram_dout32),
   .ram_Adr(sdram_addr),
   .ram_cntDMA(sdram_cntDMA),
   .ram_be(sdram_be),
   .ram_rnw(sdram_rnw),
   .ram_ena(sdram_req),
   .ram_dma(sdram_dma),
   .ram_cache(sdram_cache),
   .ram_done(sdram_ack),
   .ram_dmafifo_adr  (sdram_dmafifo_adr),
   .ram_dmafifo_data (sdram_dmafifo_data),
   .ram_dmafifo_empty(sdram_dmafifo_empty),
   .ram_dmafifo_read (sdram_dmafifo_read),
   .cache_wr(cache_wr),
   .cache_data(cache_data),
   .cache_addr(cache_addr),
   .dma_wr(dma_wr),
   .dma_reqprocessed(dma_reqprocessed),
   .dma_data(dma_data),
   // vram/ddr3
   .DDRAM_BUSY      (DDRAM_BUSY      ),
   .DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
   .DDRAM_ADDR      (DDRAM_ADDR      ),
   .DDRAM_DOUT      (DDRAM_DOUT      ),
   .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
   .DDRAM_RD        (DDRAM_RD        ),
   .DDRAM_DIN       (DDRAM_DIN       ),
   .DDRAM_BE        (DDRAM_BE        ),
   .DDRAM_WE        (DDRAM_WE        ),
   // cd (unused in ZN)
   .region          (2'b01),    // JP
   .region_out      (region_out),
   .hasCD           (1'b0),
   .LIDopen         (1'b0),
   .fastCD          (1'b0),
   .trackinfo_data  (32'h0),
   .trackinfo_addr  (9'h0),
   .trackinfo_write (1'b0),
   .resetFromCD     (resetFromCD),
   .cd_hps_req      (),
   .cd_hps_lba      (),
   .cd_hps_ack      (1'b0),
   .cd_hps_write    (1'b0),
   .cd_hps_data     (16'h0),
   // spuram
   .spuram_dataWrite(spuram_dataWrite),
   .spuram_Adr      (spuram_Adr      ),
   .spuram_be       (spuram_be       ),
   .spuram_rnw      (spuram_rnw      ),
   .spuram_ena      (spuram_ena      ),
   .spuram_dataRead (spuram_dataRead ),
   .spuram_done     (spuram_done     ),
   // memcard (unused in ZN)
   .memcard_changed (),
   .saving_memcard  (),
   .memcard1_load   (1'b0),
   .memcard2_load   (1'b0),
   .memcard_save    (1'b0),
   .memcard1_mounted   (1'b0),
   .memcard1_available (1'b0),
   .memcard1_rd     (),
   .memcard1_wr     (),
   .memcard1_lba    (),
   .memcard1_ack    (1'b0),
   .memcard1_write  (1'b0),
   .memcard1_addr   (9'h0),
   .memcard1_dataIn (16'h0),
   .memcard1_dataOut(),
   .memcard2_mounted   (1'b0),
   .memcard2_available (1'b0),
   .memcard2_rd     (),
   .memcard2_wr     (),
   .memcard2_lba    (),
   .memcard2_ack    (1'b0),
   .memcard2_write  (1'b0),
   .memcard2_addr   (9'h0),
   .memcard2_dataIn (16'h0),
   .memcard2_dataOut(),
   // video
   .videoout_on     (~status[14]),
   .isPal           (isPal),
   .pal60           (status[15]),
   .hsync           (hs),
   .vsync           (vs),
   .hblank          (hbl),
   .vblank          (vbl),
   .DisplayWidth    (DisplayWidth),
   .DisplayHeight   (DisplayHeight),
   .DisplayOffsetX  (DisplayOffsetX),
   .DisplayOffsetY  (DisplayOffsetY),
   .video_ce        (ce_pix),
   .video_interlace (video_interlace),
   .video_r         (r),
   .video_g         (g),
   .video_b         (b),
   .video_isPal     (video_isPal),
   .video_fbmode    (video_fbmode),
   .video_fb24      (video_fb24),
   .video_hResMode  (video_hResMode),
   .video_frameindex(frameindex),
   //Keys
   .DSAltSwitchMode(status[31]),
   .PadPortEnable1 (PadPortEnable1),
   .PadPortDigital1(PadPortDigital1),
   .PadPortAnalog1 (PadPortAnalog1),
   .PadPortMouse1  (PadPortMouse1 ),
   .PadPortGunCon1 (PadPortGunCon1),
   .PadPortNeGcon1 (PadPortNeGcon1),
   .PadPortWheel1  (PadPortWheel1),
   .PadPortDS1     (PadPortDS1),
   .PadPortJustif1 (PadPortJustif1),
   .PadPortStick1  (PadPortStick1),
   .PadPortPopn1   (PadPortPopn1),
   .PadPortEnable2 (PadPortEnable2),
   .PadPortDigital2(PadPortDigital2),
   .PadPortAnalog2 (PadPortAnalog2),
   .PadPortMouse2  (PadPortMouse2 ),
   .PadPortGunCon2 (PadPortGunCon2),
   .PadPortNeGcon2 (PadPortNeGcon2),
   .PadPortWheel2  (PadPortWheel2),
   .PadPortDS2     (PadPortDS2),
   .PadPortJustif2 (PadPortJustif2),
   .PadPortStick2  (PadPortStick2),
   .PadPortPopn2   (PadPortPopn2),
   .KeyTriangle({joy4[4], joy3[4], joy2[4], joy[4] }),
   .KeyCircle  ({joy4[5] ,joy3[5] ,joy2[5] ,joy[5] }),
   .KeyCross   ({joy4[6] ,joy3[6] ,joy2[6] ,joy[6] }),
   .KeySquare  ({joy4[7] ,joy3[7] ,joy2[7] ,joy[7] }),
   .KeySelect  ({joy4[8] ,joy3[8] ,joy2[8] ,joy[8] }),
   .KeyStart   ({joy4[9] ,joy3[9] ,joy2[9] ,joy[9] }),
   .KeyRight   ({joy4[0] ,joy3[0] ,joy2[0] ,joy[0] }),
   .KeyLeft    ({joy4[1] ,joy3[1] ,joy2[1] ,joy[1] }),
   .KeyUp      ({joy4[3] ,joy3[3] ,joy2[3] ,joy[3] }),
   .KeyDown    ({joy4[2] ,joy3[2] ,joy2[2] ,joy[2] }),
   .KeyR1      ({joy4[11],joy3[11],joy2[11],joy[11]}),
   .KeyR2      ({joy4[13],joy3[13],joy2[13],joy[13]}),
   .KeyR3      ({joy4[15],joy3[15],joy2[15],joy[15]}),
   .KeyL1      ({joy4[10],joy3[10],joy2[10],joy[10]}),
   .KeyL2      ({joy4[12],joy3[12],joy2[12],joy[12]}),
   .KeyL3      ({joy4[14],joy3[14],joy2[14],joy[14]}),
   .ToggleDS   (ToggleDS),
   .Analog1XP1(joy0_xmuxed),
   .Analog1YP1(joystick_analog_l0[15:8]),
   .Analog2XP1(joystick_analog_r0[7:0]),
   .Analog2YP1(joystick_analog_r0[15:8]),
   .Analog1XP2(joystick_analog_l1[7:0]),
   .Analog1YP2(joystick_analog_l1[15:8]),
   .Analog2XP2(joystick_analog_r1[7:0]),
   .Analog2YP2(joystick_analog_r1[15:8]),
   .Analog1XP3(joystick_analog_l2[7:0]),
   .Analog1YP3(joystick_analog_l2[15:8]),
   .Analog2XP3(joystick_analog_r2[7:0]),
   .Analog2YP3(joystick_analog_r2[15:8]),
   .Analog1XP4(joystick_analog_l3[7:0]),
   .Analog1YP4(joystick_analog_l3[15:8]),
   .Analog2XP4(joystick_analog_r3[7:0]),
   .Analog2YP4(joystick_analog_r3[15:8]),
   .RumbleDataP1(joystick1_rumble),
   .RumbleDataP2(joystick2_rumble),
   .RumbleDataP3(joystick3_rumble),
   .RumbleDataP4(joystick4_rumble),
   .padMode(padMode),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
   .multitap(multitap),
   .multitapDigital(multitapDigital),
   .multitapAnalog(multitapAnalog),
   //snac
   .snacPort1(snacPort1),
   .snacPort2(snacPort2),
   .selectedPort1Snac(selectedPort1Snac),
   .selectedPort2Snac(selectedPort2Snac),
   .irq10Snac(irq10Snac),
   .transmitValueSnac(transmitValueSnac),
   .clk9Snac(clk9Snac),
   .receiveBufferSnac(receiveBufferSnac),
   .beginTransferSnac(beginTransferSnac),
   .actionNextSnac(actionNextSnac),
   .receiveValidSnac(receiveValidSnac),
   .ackSnac(~ack),//using real ack not the 1 cycle ack
   .snacMC(status[66]),

   //sound
	.sound_out_left(AUDIO_L),
	.sound_out_right(AUDIO_R),
   //savestates
   .increaseSSHeaderCount (!status[36]),
   .save_state            (ss_save),
   .load_state            (ss_load),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   .validSStates          (validSStates),
   .rewind_on             (0), //(status[27]),
   .rewind_active         (0), //(status[27] & joy[15]),
   //cheats
   .cheat_clear(gg_reset),
   .cheats_enabled(~status[6] && ~TURBO_MEM && ~ioctl_download),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

   .Cheats_BusAddr(cheats_addr),
   .Cheats_BusRnW(cheats_rnw),
   .Cheats_BusByteEnable(cheats_be),
   .Cheats_BusWriteData(cheats_dout),
   .Cheats_Bus_ena(cheats_ena),
   .Cheats_BusReadData(cheats_din),
   .Cheats_BusDone(sdramCh3_done),

   // ZN-1 Arcade I/O
   .zn_p1_right   (joy[0]),
   .zn_p1_left    (joy[1]),
   .zn_p1_down    (joy[2]),
   .zn_p1_up      (joy[3]),
   .zn_p1_btn     (joy[9:4]),    // btn1-6 = joy[4..9]
   .zn_p1_start   (joy[10]),
   .zn_p1_coin    (joy[11]),
   .zn_p2_right   (joy2[0]),
   .zn_p2_left    (joy2[1]),
   .zn_p2_down    (joy2[2]),
   .zn_p2_up      (joy2[3]),
   .zn_p2_btn     (joy2[9:4]),
   .zn_p2_start   (joy2[10]),
   .zn_p2_coin    (joy2[11]),
   .zn_service    (status[95]),
   .zn_test_mode  (status[94]),
   .zn_dsw        (~status[103:96]),  // MRA <switches base="96">; status_bit=0 (default) → DSW bit=1 (Off); status_bit=1 → DSW bit=0 (On)
   // CAT702 keys loaded dynamically via MRA rom index 4 (key_a=KN01/motherboard) and 5 (key_b=KN02/game)
   // CAT702 select is ACTIVE LOW: key_a used for 0x88 path (KN01), key_b used for 0x84 path (KN02)
   .zn_cat702_key  (zn_cat702_key_a),
   .zn_cat702_key_b(zn_cat702_key_b_r),
   .zn_platform    (zn_platform_r[3:0]),
   .zn_ee_dl_wr    (zn_ee_dl_wr),
   .zn_ee_dl_addr  (zn_ee_dl_addr),
   .zn_ee_dl_data  (zn_ee_dl_data),
   .zn_ee_dl_be    (zn_ee_dl_be),
   .zn_debug_out   (zn_debug_out),
   .zn_debug_val   (zn_debug_val),
   .zn_debug_addr  (zn_debug_addr),
   .zn_debug_words (zn_debug_words)
);

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire  [31:0] sdr_sdram_dout32;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [26:0] sdram_addr;
wire   [1:0] sdram_cntDMA;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_dma;
wire         sdram_cache;
wire [ 3:0]  cache_wr;
wire [31:0]  cache_data;
wire [ 7:0]  cache_addr;
wire         dma_wr;
wire         dma_reqprocessed;
wire [31:0]  dma_data;

wire  [22:0] sdram_dmafifo_adr;
wire  [31:0] sdram_dmafifo_data;
wire         sdram_dmafifo_empty;
wire         sdram_dmafifo_read;


wire [20:0] cheats_addr;
wire cheats_rnw;
wire [3:0] cheats_be;
wire [31:0] cheats_dout;
wire cheats_ena;
wire [31:0] cheats_din;
wire sdramCh3_done;

//////////////////  build #54: SENTINEL-READBACK INSTRUMENT  /////////////////
// ===== B-inst7 (2026-07-17): SENTINEL REMOVED =====
// The build #55 "marker ramp" sentinel wrote 8 words 0xA0000000|slot to SDRAM
// 0x0E44800-0x0E4481C after EVERY banked-ROM download - overwriting 32 bytes of
// live banked ROM (image offset 0x644800) on every title. Proven corruption source
// for raystorm's "ROM R-3 ERROR" window (read-shadow sum mismatch) and prime
// suspect for the BR2 loader stall / hvnsgate garbage-bounds freeze.
// dbg_loadwords stays as zeros for the status[93]-gated debug overlay.

assign sdram_ack = sdram_readack | sdram_writeack;

sdram sdram
(
   .SDRAM_DQ   (SDRAM_DQ),
   .SDRAM_A    (SDRAM_A),
   .SDRAM_DQML (SDRAM_DQML),
   .SDRAM_DQMH (SDRAM_DQMH),
   .SDRAM_BA   (SDRAM_BA),
   .SDRAM_nCS  (SDRAM_nCS),
   .SDRAM_nWE  (SDRAM_nWE),
   .SDRAM_nRAS (SDRAM_nRAS),
   .SDRAM_nCAS (SDRAM_nCAS),
   .SDRAM_CKE  (SDRAM_CKE),
   .SDRAM_CLK  (SDRAM_CLK),

   .SDRAM_EN(1),
	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),

	.refreshForce(sdr_refresh),
	.pagemode_en(SDRAM_PAGEMODE),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(sdr_sdram_dout32),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(sdram_dma),
	.ch1_cntDMA(sdram_cntDMA),
	.ch1_cache(sdram_cache),
	.ch1_ready(sdram_readack),
	.cache_wr(cache_wr),
	.cache_data(cache_data),
	.cache_addr(cache_addr),
	.dma_wr(dma_wr),
	.dma_reqprocessed(dma_reqprocessed),
	.dma_data(dma_data),

	.ch2_addr (sdram_addr),
	.ch2_din  (sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  (sdram_req & ~sdram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr ((bios_download | fixedrom_download | bankedrom_download) ? ramdownload_wraddr : {6'b0, cheats_addr}),
	.ch3_din  ((bios_download | fixedrom_download | bankedrom_download) ? ramdownload_wrdata : cheats_dout),
	.ch3_dout (cheats_din),
	.ch3_req  ((bios_download | fixedrom_download | bankedrom_download) ? ramdownload_wr     : cheats_ena),
	.ch3_rnw  ((bios_download | fixedrom_download | bankedrom_download) ? 1'b0 : cheats_rnw),
	.ch3_be   ((bios_download | fixedrom_download | bankedrom_download) ? 4'b1111            : cheats_be),
	.ch3_ready(sdramCh3_done),

	.dmafifo_adr  (sdram_dmafifo_adr),
	.dmafifo_data (sdram_dmafifo_data),
	.dmafifo_empty(sdram_dmafifo_empty),
	.dmafifo_read (sdram_dmafifo_read),
	.dbg_pm_hit   (pm_dbg_hit),
	.dbg_pm_open  (pm_dbg_open),
	.dbg_pm_pre   (pm_dbg_pre),
	.dbg_sdram    (sdram_dbg_state),
	.dbg_drd1     (sdram_dbg_drd1)
);
wire pm_dbg_hit, pm_dbg_open, pm_dbg_pre;   // B-pm-probe: page-mode FSM event latches
wire [8:0] sdram_dbg_state;                 // B-jtag: {lastbank_valid, command[2:0], state[4:0]}
wire [7:0] sdram_dbg_drd1;                  // B-jtag8: data_ready_delay1[7:0] capture window

// ===== B-jtag8: CYCLE-LEVEL SDRAM-bus capture, hardware-triggered on the read of 0x424/0x42C =====
// Per clk_3x cycle, sample the SDRAM bus + FSM. Trigger = ch1 read request to the target addr
// (0x0400424 by default, 0x040042C when la_src[12]=1) so we catch the corrupted vs correct read.
// la_trig fires on the request; the next ~DEPTH cycles capture ACTIVE/HIT -> READ -> DQ -> capture.
wire [26:0] la_trig_addr = la_src[12] ? 27'h040042C : 27'h0400424;
wire        la_trig = sdram_req & sdram_rnw & (sdram_addr == la_trig_addr);

// sample[46:0] = { trig(1), dbg_sdram[8:0]{lastbank,cmd3,state5}, drd1[7:0], SDRAM_A[12:0], SDRAM_DQ[15:0] }
wire [46:0] la_sample = { la_trig, sdram_dbg_state, sdram_dbg_drd1, SDRAM_A, SDRAM_DQ };

wire [12:0] la_src;          // [8:0]=rdaddr, [9]=arm, [10]=pm_force_on, [11]=jtag_reset, [12]=trig 0x42C
wire [46:0] la_rddata;
wire        la_frozen;
wire [8:0]  la_wptr;
jtag_la #(.DW(47), .AW(9)) u_la (
	.clk    (clk_3x),
	.sample (la_sample),
	.trig   (la_trig),
	.arm    (la_src[9]),
	.rdaddr (la_src[8:0]),
	.rddata (la_rddata),
	.frozen (la_frozen),
	.wptr_o (la_wptr)
);
// probe(72,MSB-first): [71:57]=pad(15) [56]=frozen [55:47]=wptr [46:0]=rddata(sample)
wire [71:0] la_probe = { 15'b0, la_frozen, la_wptr, la_rddata };
altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (0),
	.instance_id             ("ZNLA"),
	.probe_width             (72),
	.source_width            (13),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_jtag_issp (
	.probe      (la_probe),
	.source     (la_src),
	.source_clk (clk_3x),
	.source_ena (1'b1)
);

// B-inst4/5 (2026-07-17): instrument probe, now full 256 bits. Layout in psx_top.vhd
// zn_debug_words comments: [255:160] = B-inst5 (raystorm checksum shadow, bank-2/loop-bounds
// shared capture, live bank reg); [159:0] = B-inst4 (live PC, rs first-read, I/O trackers).
wire [255:0] sc_probe = zn_debug_words;
wire sc_src;
altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (1),
	.instance_id             ("ZNSC"),
	.probe_width             (256),
	.source_width            (1),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_jtag_sc (
	.probe      (sc_probe),
	.source     (sc_src),
	.source_clk (clk_3x),
	.source_ena (1'b1)
);
// (probe_width raised 160 -> 256 for B-inst5; readout scripts detect length)
// ================================================================================================

wire [31:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [31:0] spuram_dataRead;
wire        spuram_done;

assign spuram_done     = sdram_readack2 | sdram_writeack2;

`ifdef MISTER_DUAL_SDRAM

sdram sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
   .SDRAM_A    (SDRAM2_A),
   .SDRAM_DQML (),
   .SDRAM_DQMH (),
   .SDRAM_BA   (SDRAM2_BA),
   .SDRAM_nCS  (SDRAM2_nCS),
   .SDRAM_nWE  (SDRAM2_nWE),
   .SDRAM_nRAS (SDRAM2_nRAS),
   .SDRAM_nCAS (SDRAM2_nCAS),
   .SDRAM_CKE  (),
   .SDRAM_CLK  (SDRAM2_CLK),
   .SDRAM_EN   (SDRAM2_EN),

	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),

	.refreshForce(1'b0),
	.pagemode_en(1'b0),    // SPU SDRAM does not opt in to page-mode
	.ram_idle(),

	.ch1_addr(spuram_Adr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(spuram_dataRead),
	.ch1_req(spuram_ena & spuram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(1'b0),
   .ch1_cntDMA(2'b00),
	.ch1_cache(1'b0),
	.ch1_ready(sdram_readack2),

	.ch2_addr (spuram_Adr),
	.ch2_din  (spuram_dataWrite),
	.ch2_dout (),
	.ch2_req  (spuram_ena & ~spuram_rnw),
	.ch2_rnw  (1'b0),
   .ch2_be   (spuram_be),
	.ch2_ready(sdram_writeack2),

	.ch3_addr(0),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready(),

	.dmafifo_adr  (0),
	.dmafifo_data (0),
	.dmafifo_empty(1'b1),
	.dmafifo_read ()
);

`else

wire SDRAM2_EN = 0;

assign spuram_dataRead = '0;
assign sdram_readack2 = '0;
assign sdram_writeack2 = '0;

`endif


assign DDRAM_CLK = clk_2x;

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_vid;

wire hs, vs, hbl, vbl, video_interlace, video_isPal, video_fbmode, video_fb24;

wire [2:0] video_hResMode;

wire ce_pix;
wire [7:0] r,g,b;
wire [6:0] zn_debug_out;  // DIAGNOSTIC build #17: verify Y-wrap fix. See psx_top.vhd.
wire [31:0] zn_debug_val; // build #50: raw 32-bit SDRAM word latched at green anchor 0x1F644810
wire [31:0] zn_debug_addr; // build #51: computed SDRAM byte address latched at green anchor (expect 0x00E44810)
wire [255:0] zn_debug_words; // build #52: 8 contiguous bank0 words [0x1F644800,0x1F644820), word0 in low 32 bits
// build #53: LOAD-TIME capture of the 8 banked-ROM words written to SDRAM [0xE44800,0xE44820)
// during bankedrom_download. Game-independent — frozen after load. word slot s in bits [s*32 +: 32].
// Expected loaded ROM sequence: 0=0x00007FFF 1=0 2=0 3=0 4=0x00200000 5=0x00200020 6=0x00200020 7=0x00400020.
reg  [255:0] dbg_loadwords = 256'd0;
// build #52/#53: overlay bit index — row = dbg_vpix[4:2] (word 0..7), col MSB-left = 31 - dbg_hpix[7:3]
wire [7:0] dbg_word_bitidx = dbg_vpix[4:2]*8'd32 + (8'd31 - {3'b0, dbg_hpix[7:3]});
wire       dbg_word_bit    = dbg_loadwords[dbg_word_bitidx];

wire hack_480p = status[89];

typedef struct {
	logic [7:0] red;
	logic [7:0] green;
	logic [7:0] blue;
	logic       hs;
	logic       vs;
	logic       hb;
	logic       vb;
	logic       interlace;
} vid_info;

vid_info video_aspect;
vid_info video_gamma;

assign CE_PIXEL = ce_pix;
assign VGA_R    = video_gamma.red;
assign VGA_G    = video_gamma.green;
assign VGA_B    = video_gamma.blue;
assign VGA_VS   = video_gamma.vs;
assign VGA_HS   = video_gamma.hs;
assign VGA_DE   = ~(video_gamma.vb | video_gamma.hb);
assign VGA_F1   =  status[14] ? 1'b0 : video_aspect.interlace;
assign VGA_SL = 0;
logic [11:0] aspect_x, aspect_y;

wire [1:0] ar = status[33:32];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? ((status[54:53] == 1) ? 3 : (status[54:53] == 2) ? 5 : (status[54:53] == 3) ? 16 : status[11] ? 12'd2 : aspect_x) : (ar - 1'd1)),
	.ARY((!ar) ? ((status[54:53] == 1) ? 2 : (status[54:53] == 2) ? 3 : (status[54:53] == 3) ?  9 : status[11] ? 12'd1 : aspect_y) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);

// Res  Div Padding
// 256  10  +25
// 320  8   +32
// 368  7   +37
// 512  5   +51
// 640  4   +64

localparam reg [23:0] aspect_ratio_lut_ntsc[128] = '{
    24'h37015B, 24'h2B4113, 24'h1A10A7, 24'hEB45EF, 24'hA00411, 24'hF8365B, 24'hA31435, 24'h6A42C3,
    24'h85D381, 24'hF8F691, 24'h581257, 24'h1860A7, 24'hFD56D4, 24'h6EF303, 24'h497202, 24'hDA1601,
    24'hF8D6E6, 24'h8513B7, 24'hB014F3, 24'h3C51B5, 24'h3971A3, 24'hC02583, 24'hD09606, 24'h4E1245,
    24'hFEF776, 24'hC555D0, 24'hBD559D, 24'hE686E1, 24'hF7C771, 24'hC4F5F4, 24'h655315, 24'hB5158B,
    24'h2C015B, 24'h1750B9, 24'hC74637, 24'hF857CB, 24'h89B459, 24'h800411, 24'hC87668, 24'hA21536,
    24'hFB3820, 24'h443238, 24'hE17761, 24'hFD3856, 24'h207113, 24'h204113, 24'h3941EB, 24'hE6F7C8,
    24'h28015B, 24'hD55745, 24'hD21733, 24'hE9F810, 24'hC0A6AD, 24'h99955A, 24'hA0359D, 24'h7FF482,
    24'hD5B792, 24'hE5C82F, 24'hF558C9, 24'h35D1F0, 24'h6EF404, 24'h93155A, 24'h5BF35D, 24'h9F75DD,
    24'h6E0411, 24'h2DF1B5, 24'h44D292, 24'h1160A7, 24'hB4F6D4, 24'hD49810, 24'hD057F1, 24'h91B595,
    24'hB006C7, 24'hF959A6, 24'hE338D6, 24'hC1378D, 24'hC557C0, 24'hF579B0, 24'h7E1500, 24'hABD6D9,
    24'hFE3A2E, 24'hD3D886, 24'h54736A, 24'hFF3A5E, 24'hE19935, 24'hF42A03, 24'h356233, 24'hFEBA8B,
    24'h957637, 24'hEFAA03, 24'h43F2DA, 24'hA6F70A, 24'h20015B, 24'h24D191, 24'h72E4E9, 24'hC1E853,
    24'hDC097D, 24'hD09909, 24'hFE8B13, 24'hD5E959, 24'hFEFB31, 24'h2B81EB, 24'h8A5620, 24'h2B91F0,
    24'h2AF1EB, 24'hD3F982, 24'hED9AB4, 24'h163101, 24'h724531, 24'hDCBA12, 24'hC50907, 24'hFB7B92,
    24'h580411, 24'hFDDBC7, 24'hAA77F1, 24'hD259D7, 24'h2ED233, 24'h2431B5, 24'hC1992B, 24'h20F191,
    24'h7665A7, 24'h42D334, 24'hD09A0A, 24'hF17BAB, 24'hFFFC6B, 24'h6B653B, 24'h5153FA, 24'hFD9C73
};

localparam reg [23:0] aspect_ratio_lut_pal[160] = '{
    24'hE8F4D9, 24'h41015D, 24'h40815D, 24'h8EB30A, 24'hF8D557, 24'h1C009B, 24'h1CB0A0, 24'h473190,
    24'h711280, 24'hCEF49C, 24'hD734D4, 24'hCAC495, 24'h4791A1, 24'hF695A7, 24'hC7549A, 24'hC31489,
    24'hAEB417, 24'hB8C45B, 24'hA2C3DD, 24'hBCF484, 24'hD2E513, 24'hC2A4B7, 24'hEFF5DA, 24'h85D349,
    24'h18809B, 24'h0C9050, 24'hF59626, 24'hE595C9, 24'h35C15D, 24'hF81655, 24'h0EC061, 24'hEA160D,
    24'h68D2BA, 24'hD735A2, 24'h4731E0, 24'hE9A631, 24'hDC35DF, 24'h6D12ED, 24'h96D412, 24'hB87502,
    24'hCFF5AE, 24'h73732C, 24'hF1D6AF, 24'h7CA377, 24'h30C15D, 24'hA7A4B7, 24'h5C629D, 24'h3941A1,
    24'h4A221F, 24'hF5B712, 24'hD5F631, 24'h8ED428, 24'h8BC417, 24'hE236A8, 24'hA854FB, 24'hEAE6FD,
    24'hD73670, 24'hD5666B, 24'hFD97AB, 24'hA8751F, 24'hCDA649, 24'hCE1655, 24'h5C92DC, 24'h3BC1DB,
    24'hAEB574, 24'hB5A5B3, 24'hFE8807, 24'h2B015D, 24'h13009B, 24'hB6F5DC, 24'hA5E557, 24'hC7D677,
    24'hD1A6D1, 24'h099050, 24'hEF37DB, 24'hB8C619, 24'h25B140, 24'h4FD2A9, 24'hE1978E, 24'hD7373E,
    24'h28515D, 24'hE437C1, 24'hD35737, 24'hF4D866, 24'hF97899, 24'h42724D, 24'h5572F9, 24'h27015D,
    24'hCF0745, 24'h6D83DD, 24'hFFB910, 24'hE35818, 24'hEB2869, 24'hB1565F, 24'hF3F8CE, 24'hE05822,
    24'h10A09B, 24'hEFF8C7, 24'h9E35D0, 24'h87B502, 24'hBAF6EE, 24'hD7D809, 24'hD7380C, 24'hF59939,
    24'h2E31BE, 24'hE0B883, 24'h6B8417, 24'h93F5A7, 24'h09E061, 24'hE3B8C6, 24'hBCE74F, 24'h2FC1DB,
    24'h22F15D, 24'h818513, 24'h5ED3BB, 24'hFF3A15, 24'h5AB399, 24'hB52737, 24'hF0199A, 24'hEE5992,
    24'hBDB7A6, 24'hC74811, 24'h3FD298, 24'h77F4E5, 24'h4552D7, 24'h1390CE, 24'hE4D973, 24'h25B190,
    24'h91960F, 24'hBBD7D9, 24'h20815D, 24'h788513, 24'h20415D, 24'h9BF69E, 24'h8EB614, 24'h8435A7,
    24'hF8DAAE, 24'h9B26AF, 24'h0E009B, 24'h8EA631, 24'h1CB140, 24'h1B112F, 24'hD05925, 24'hD1F940,
    24'h89060F, 24'hD7098B, 24'h88060F, 24'h4172ED, 24'hD739A8, 24'hDBE9E7, 24'h656495, 24'hFF8B97,
    24'hD1A98B, 24'hA6D79F, 24'hB4E84B, 24'hEC7AE1, 24'hFF1BC7, 24'h5C944A, 24'hC31912, 24'hEE8B21
};

logic [11:0] h_pos, v_pos, vb_pos, v_total;
logic [9:0]  dbg_hpix;   // visible-area horizontal pixel counter (10-bit, max 1023 — no wrap for any PSX width)
logic [4:0]  dbg_vpix;   // visible-area line counter
logic        dbg_hbl_prev, dbg_vbl_prev;
logic [11:0] hb_start_lut[8];
logic [11:0] hb_end_lut[8];
logic [11:0] hb_start, hb_end;

// FIXME: this should be adjusted if hsync changes size to maintain center
assign hb_start_lut = '{12'd63,  12'd50,  12'd36,  12'd31,  12'd24,  12'd0, 12'd0, 12'd0};
assign hb_end_lut =   '{12'd767, 12'd613, 12'd441, 12'd383, 12'd305, 12'd0, 12'd0, 12'd0};

always_comb begin
	hb_start = hb_start_lut[video_hResMode];
	hb_end = hb_end_lut[video_hResMode];
end

always_ff @(posedge CLK_VIDEO) if (CE_PIXEL) begin
	logic old_vb;
	old_vb <= vbl;
	video_aspect.hs <= hs;
	video_aspect.vs <= vs;
	video_aspect.vb <= vbl;
	video_aspect.interlace <= video_interlace;
	video_aspect.red <= (vbl || hbl) ? 8'd0 : r;
	video_aspect.green <= (vbl || hbl) ? 8'd0 : g;
	video_aspect.blue <= (vbl || hbl) ? 8'd0 : b;
	{aspect_x, aspect_y} <= video_isPal ? aspect_ratio_lut_pal[v_total] : aspect_ratio_lut_ntsc[v_total];

	VGA_DISABLE <= fast_forward;

	h_pos <= h_pos + 1'd1;
	if (~old_vb && vbl)
		vb_pos <= 0;

	if (video_aspect.hs && ~hs) begin
		h_pos <= 0;
		if (~vbl)
			v_pos <= v_pos + 1'd1;
		else
			vb_pos <= vb_pos + 1'd1;
	end

	if (~video_aspect.vs && vs) begin
		v_pos <= 0;

		if (v_pos < 128)
			v_total <= 6'd0;
		else if (video_isPal && v_pos > 287)
			v_total <= 8'd159;
		else if (~video_isPal && v_pos > 255)
			v_total <= 7'd127;
		else
			v_total <= v_pos - 8'd128;
	end

	if (vb_pos > (video_isPal ? 161 : 135))
		video_aspect.vb <= 0;

	if (h_pos == hb_start)
		video_aspect.hb <= 0;
	if (h_pos == hb_end)
		video_aspect.hb <= 1;
	if (status[62] || hack_480p || (status[54:53] > 0))
		video_aspect.hb <= hbl;

	// Visible-area pixel counters for debug overlay
	dbg_hbl_prev <= hbl;
	dbg_vbl_prev <= vbl;
	if (dbg_vbl_prev && ~vbl)          dbg_vpix <= 0;  // vblank ended: reset line counter
	else if (dbg_hbl_prev && ~hbl && ~vbl) dbg_vpix <= dbg_vpix + 1'd1;  // new visible line
	if (dbg_hbl_prev && ~hbl)          dbg_hpix <= 0;  // start of visible area on line
	else if (~hbl)                      dbg_hpix <= dbg_hpix + 1'd1;

	// build #52: 8 contiguous bank0 SDRAM words [0x1F644800,0x1F644820) captured into
	// zn_debug_words. Render as 8 stacked rows (row r = dbg_vpix[4:2] = word slot r),
	// each 3px tall (drawn when dbg_vpix[1:0] != 3 leaves a 1px gap), MSB (bit31) leftmost,
	// 8px per bit → 256px wide. Lit white = bit set. Per-byte dim tint when bits are 0:
	//   byte3 (31:24)=red, byte2 (23:16)=green, byte1 (15:8)=blue, byte0 (7:0)=gray.
	// Expected ROM-stream slots: 0=0x00007FFF 1=0 2=0 3=0 4=0x00200000 5=0x00200020
	//                            6=0x00200020 7=0x00400020. Mismatch reveals the load defect.
	// build #80: GENERIC triage bars for any title (sticky latches).
	//   bar0 RED   = ram_exec_seen     (CPU executing instructions from game RAM, sticky)
	//   bar1 GREEN = raster_pixel_seen (GPU rasterizer ever produced a VRAM pixel write, sticky)
	//   bar2 BLUE  = gpu_accessed_seen (CPU ever wrote/read GPU registers, sticky)
	// Read: all 3 lit → CPU+GPU alive (hang elsewhere). RED only → no GPU init. All dark → CPU stuck in BIOS.
	// build #155: debug bar overlay gated by OSD status[93]. Default OFF so games render
	// cleanly; toggle on via OSD "Debug" menu (or mister_debug_bars_toggle.sh) when
	// instrument output is needed.
	if (status[93] && ~vbl && ~hbl && dbg_hpix < 10'd352) begin
		if (dbg_vpix >= 5'd1 && dbg_vpix <= 5'd6) begin
			if (dbg_hpix < {1'b0, dbg_ee_idx9_cnt}) begin   // DIAG: RED = index-9 ioctl writes delivered
				video_aspect.red <= 8'hFF; video_aspect.green <= 8'h00; video_aspect.blue <= 8'h00;
			end else begin
				video_aspect.red <= 8'h20; video_aspect.green <= 8'h00; video_aspect.blue <= 8'h00;
			end
		end else if (dbg_vpix >= 5'd9 && dbg_vpix <= 5'd14) begin
			if (dbg_hpix < {1'b0, dbg_ee_dlwr_cnt}) begin   // DIAG: GREEN = ee_dl_wr pulses fired

				video_aspect.red <= 8'h00; video_aspect.green <= 8'hFF; video_aspect.blue <= 8'h00;
			end else begin
				video_aspect.red <= 8'h00; video_aspect.green <= 8'h20; video_aspect.blue <= 8'h00;
			end
		end else if (dbg_vpix >= 5'd17 && dbg_vpix <= 5'd22) begin
			if (dbg_hpix < {1'b0, (SDRAM_PAGEMODE ? (pm_dbg_pre ? 9'd351 : 9'd0) : zn_debug_words[136:128])}) begin
				video_aspect.red <= 8'h00; video_aspect.green <= 8'h00; video_aspect.blue <= 8'hFF;
			end else begin
				video_aspect.red <= 8'h00; video_aspect.green <= 8'h00; video_aspect.blue <= 8'h20;
			end
		end
	end

end

// Pause overlay: when the joystick "pause" button (joy[18]) toggles button_paused on,
// replace video with the XN logo + scrolling Patreon credits. Other pause sources
// (OSD-open, savestate) still display the last game frame.
wire [7:0] pause_overlay_r, pause_overlay_g, pause_overlay_b;
pause_overlay u_pause_overlay (
	.clk         (CLK_VIDEO),
	.ce_pix      (CE_PIXEL),
	.hblank      (video_aspect.hb),
	.vblank      (video_aspect.vb),
	.enable      (button_paused),
	.rotate180   (status[24]),
	.vertical    (status[25]),
	.vid_r_in    (video_aspect.red),
	.vid_g_in    (video_aspect.green),
	.vid_b_in    (video_aspect.blue),
	.vid_r_out   (pause_overlay_r),
	.vid_g_out   (pause_overlay_g),
	.vid_b_out   (pause_overlay_b)
);

assign gamma_bus[21] = 1;
gamma_corr gamma(
	.clk_sys(gamma_bus[20]),
	.clk_vid(CLK_VIDEO),
	.ce_pix(CE_PIXEL),

	.gamma_en(gamma_bus[19]),
	.gamma_wr(gamma_bus[18]),
	.gamma_wr_addr(gamma_bus[17:8]),
	.gamma_value(gamma_bus[7:0]),

	.HSync(video_aspect.hs),
	.VSync(video_aspect.vs),
	.HBlank(video_aspect.hb),
	.VBlank(video_aspect.vb),
	.RGB_in({pause_overlay_r, pause_overlay_g, pause_overlay_b}),

	.HSync_out(video_gamma.hs),
	.VSync_out(video_gamma.vs),
	.HBlank_out(video_gamma.hb),
	.VBlank_out(video_gamma.vb),
	.RGB_out({video_gamma.red,video_gamma.green,video_gamma.blue})
);



////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
reg [127:0] gg_code;
reg gg_valid;
reg gg_reset;
reg code_download_1;
wire gg_active;
always_ff @(posedge clk_1x) begin

   gg_reset <= 0;
   code_download_1 <= code_download;
	if (code_download && ~code_download_1) begin
      gg_reset <= 1;
   end

   gg_valid <= 0;
	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_valid          <= 1;          // Clock it in
			end
		endcase
	end
end

wire clk8Snac;
wire clk9Snac;
wire oldClk8;
wire oldClk9;
wire selectedPort1Snac;
wire selectedPort2Snac;
wire oldselectedPort1;
wire oldselectedPort2;
wire [7:0]transmitValueSnac;
wire [7:0]receiveBufferSnac;
wire receiveValidSnac;
wire beginTransferSnac;
wire actionNextSnac;
wire actionNextPadSnac;
reg [7:0]Send;
reg [7:0]Receive;
wire Cmd;
wire Dat;
wire ack;
wire oldAck;
//wire ackSnac;
wire [15:0]ackTimer;
wire ackNone;
wire oneTime;
wire [3:0]bitCnt;
wire [8:0]byteCnt;
wire [8:0]bytesLeft;
wire [7:0]pad1ID;
wire [7:0]pad2ID;
wire [7:0]targetID;
wire irq10Snac;
wire csync;
wire MCtransfer;
wire PStransfer;
wire [7:0]PSdatalength;

reg USER_IN3_1;
reg USER_IN4_1;
reg USER_IN6_1;

reg USER_IN3_2;
reg USER_IN4_2;
reg USER_IN6_2;

reg USER_IN3_3;
reg USER_IN3_4;
reg ackglitch;

assign clk8Snac = bitCnt < 8 ? clk9Snac : 1'b1;

always @(posedge clk_1x)
begin

   USER_IN3_1 <= USER_IN[3];
   USER_IN4_1 <= USER_IN[4];
   USER_IN6_1 <= USER_IN[6];

   USER_IN3_2 <= USER_IN3_1;
   USER_IN4_2 <= USER_IN4_1;
   USER_IN6_2 <= USER_IN6_1;

   USER_IN3_3 <= USER_IN3_2;//glitch filter for ack
   USER_IN3_4 <= USER_IN3_3;
   ackglitch  <= ~USER_IN3_1 && ~USER_IN3_2 && ~USER_IN3_3 && ~USER_IN3_4 ? 1'b0 : 1'b1;

	if (snacPort1 || snacPort2) begin
		USER_OUT[0] <= ~selectedPort2Snac;
		USER_OUT[1] <= ~selectedPort1Snac;
		USER_OUT[2] <= Cmd;
		USER_OUT[3] <= 1'b1; //ACK
		USER_OUT[4] <= 1'b1; //DAT
		USER_OUT[5] <= oldClk8;
		ack         <= ~ackglitch ? USER_IN3_2 : 1'b1;
		Dat         <= USER_IN4_2;

		if ((pad1ID == 8'h63 || pad2ID == 8'h63) && (pad1ID != 8'h31 || pad2ID != 8'h31)) begin //quirk for guncon, irq is N/C in guncon. so using irq line and outputting csync on snac for g-con. only if justifier isn't connected
			USER_OUT[6] <= ~csync;
			irq10Snac   <= 1'b0;
			csync       <= VGA_HS ^ VGA_VS;//real csync shifts HSync during VSync, should be close enough to work	with guncon
		end
		else begin
			USER_OUT[6] <= 1'b1;
			irq10Snac   <= ~USER_IN6_2;
		end
	end
	else begin
		USER_OUT  <= '1;
		irq10Snac <= 1'b0;
		ack       <= 1'b1;
		Dat       <= 1'b1;
	end

	oldselectedPort1 <= selectedPort1Snac;
	oldselectedPort2 <= selectedPort2Snac;

	if ((~oldselectedPort1 && selectedPort1Snac) || (~oldselectedPort2 && selectedPort2Snac)) begin
		byteCnt   <= 9'd0;
		bytesLeft <= 9'd0;
	end

	if (beginTransferSnac) begin
		bitCnt  <= 4'd0;
		byteCnt <= byteCnt + 9'd1 ;
	end

	oldClk8 <= clk8Snac;
	oldClk9 <= clk9Snac;

	if (oldClk9 && ~clk9Snac) begin	//send on falling edge
		if (bitCnt < 8) begin
			if (bitCnt==0) begin
				Cmd  <= transmitValueSnac[0];
				Send <= {1'b1, transmitValueSnac[7:1]};
			end
			else begin
				Cmd  <= Send[0];
				Send <= {1'b1, Send[7:1]};
			end
		end
		else begin
			Cmd  <= 1'b1;
			Send <= Send;
		end
	end

	if(~oldClk8 && clk8Snac) begin //receive on rising edge
		Receive <= { Dat, Receive[7:1]};
		bitCnt <= bitCnt + 1'b1;
		if(bitCnt == 4'd7) begin//check for ack
			oneTime <= 1'b1;
			if (MCtransfer) ackTimer <= 16'd60000;//very late ack after 7th byte. around 56000 cycles (1.7ms) with a sony MC. 3rd party MCs don't seem to do this
			else begin
				if (byteCnt == bytesLeft + 3) ackTimer <= 16'd400;//only wait around 150 on last byte
				else ackTimer <= 16'd1800;//1st byte of multitap(1375) cycles to ack,digital(460),analog(350-400),ds2(250-400),mouse(120),guncon(270)
			end
		end
	end

	if (ackTimer > 0) begin
		ackTimer <= ackTimer - 16'd1;
	end

	oldAck <= ack;
	if(oldAck && ~ack) begin //ack received
		actionNextPadSnac <= 1'b1;
		ackTimer <= 16'd173;//16'd255;//a delay between ack and next action. too small might cause a hang. was using acktimer 1-255
	end
	else if(ackTimer == 1) begin //wait over
		actionNextPadSnac <= 1'b1;
		oneTime <= 1'b0;
	end
	else if (ackTimer == 16'd258) begin //no ack
		ackNone <= 1'b1;
		actionNextPadSnac <= 1'b1;
	end
	else if (ackTimer == 16'd256) begin //reset if no ack
		oneTime <= 1'b0;
		ackTimer <= 16'd0;
	end
	else begin
		actionNextPadSnac <= 1'b0;
		ackNone <= 1'b0;
	end

	if (actionNextPadSnac && ((snacPort1 && selectedPort1Snac) || (snacPort2 && selectedPort2Snac))) begin //logic for joypad.vhd
		if (oneTime) begin
			if (ackNone) begin
				if (byteCnt < (bytesLeft + 4)) begin // no ack on last byte of transfer
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					actionNextSnac <= 1'b1;
				end
				else
					actionNextSnac <= 1'b1;
				end
			else begin
				if (byteCnt < (bytesLeft + 4)) begin
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					//ackSnac <= 1'b1;
				end
				actionNextSnac <= 1'b1;
			end
		end
		else begin
			actionNextSnac <= 1'b1;
		end
	end
	else begin
		receiveBufferSnac <= 8'd0;
		receiveValidSnac <= 1'b0;
		actionNextSnac <= 1'b0;
		//ackSnac <= 1'b0;
	end

	if (receiveValidSnac) begin
		if (byteCnt == 1) begin
			targetID <= transmitValueSnac;
		end
		if (byteCnt == 2) begin
			if (targetID == 8'h81 || targetID == 8'h82 || targetID == 8'h83 || targetID == 8'h84) begin 	//memcard quirks
				MCtransfer <= 1'b1;
				if (transmitValueSnac == 8'h52) bytesLeft <= 9'd137;//read
				if (transmitValueSnac == 8'h57) bytesLeft <= 9'd135;//write
				if (transmitValueSnac == 8'h53) bytesLeft <= 9'd7;//ID Cmd
				//pocketstation
				if (transmitValueSnac == 8'h50) bytesLeft <= 9'd0;//Change a FUNC 03h related value
				if (transmitValueSnac == 8'h58) bytesLeft <= 9'd2;//Get an ID or Version value
				if (transmitValueSnac == 8'h59) bytesLeft <= 9'd6;//Prepare File Execution with Dir_index, and Parameter
				if (transmitValueSnac == 8'h5A) bytesLeft <= 9'd18;//Get Dir_index, ComFlags, F_SN, Date, and Time
				if (transmitValueSnac == 8'h5D) bytesLeft <= 9'd3;//Execute Custom Download Notification
				if (transmitValueSnac == 8'h5E) bytesLeft <= 9'd3;//Get-and-Send ComFlags.bit1,3,2
				if (transmitValueSnac == 8'h5F) bytesLeft <= 9'd1;//Get-and-Send ComFlags.bit0
				if (transmitValueSnac == 8'h5B) begin//Execute Function and transfer data from Pocketstation to PSX--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
				if (transmitValueSnac == 8'h5C) begin//Execute Function and transfer data from PSX to Pocketstation--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
			end
			else begin //joypad quirks
				MCtransfer <= 1'b0;
				if (selectedPort1Snac) pad1ID <= Receive;
				if (selectedPort2Snac) pad2ID <= Receive;

				if (Receive == 8'h80) bytesLeft <= 9'd32; //for multitap
				else bytesLeft <= {5'd0, (Receive[3:0] + Receive[3:0])};
			end
		end
		if (byteCnt == 4 && PStransfer == 1) begin //for pocketstation
			bytesLeft <= bytesLeft + Receive;
			PSdatalength <=  Receive;
		end
		if ((byteCnt == PSdatalength + 5) && PStransfer == 1) begin
			bytesLeft <= bytesLeft + Receive;
			PStransfer <= 1'b0;
		end
	end
end

endmodule
