// stand-ins for tv80s / jt10 (this bench checks the PSX bus path and the TC0140SYT only)
module tv80s(output m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n, output [15:0] A, output [7:0] dout,
  input reset_n, clk, cen, wait_n, int_n, nmi_n, busrq_n, input [7:0] di,
  input auto_ss_rd, auto_ss_wr, input [31:0] auto_ss_data_in, input [7:0] auto_ss_device_idx,
  input [15:0] auto_ss_state_idx, input [7:0] auto_ss_base_device_idx, output [31:0] auto_ss_data_out, output auto_ss_ack);
  assign {m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n} = 8'hFF; assign A = 0; assign dout = 0;
  assign auto_ss_data_out = 0; assign auto_ss_ack = 0;
endmodule
module jt10(input rst, clk, cen, input [7:0] din, input [1:0] addr, input cs_n, wr_n, output [7:0] dout, output irq_n,
  output [19:0] adpcma_addr, output [3:0] adpcma_bank, output adpcma_roe_n, input [7:0] adpcma_data,
  output [23:0] adpcmb_addr, output adpcmb_roe_n, input [7:0] adpcmb_data,
  output [7:0] psg_A, psg_B, psg_C, output signed [15:0] fm_snd, output [9:0] psg_snd,
  output signed [15:0] snd_right, snd_left, output snd_sample, input [5:0] ch_enable, input ym2610b,
  input auto_ss_rd, auto_ss_wr, input [31:0] auto_ss_data_in, input [7:0] auto_ss_device_idx,
  input [15:0] auto_ss_state_idx, input [7:0] auto_ss_base_device_idx, output [31:0] auto_ss_data_out, output auto_ss_ack);
  assign dout = 0; assign irq_n = 1; assign adpcma_addr = 0; assign adpcma_bank = 0; assign adpcma_roe_n = 1;
  assign adpcmb_addr = 0; assign adpcmb_roe_n = 1; assign {psg_A, psg_B, psg_C} = 0; assign fm_snd = 0; assign psg_snd = 0;
  assign snd_right = 0; assign snd_left = 0; assign snd_sample = 0; assign auto_ss_data_out = 0; assign auto_ss_ack = 0;
endmodule
