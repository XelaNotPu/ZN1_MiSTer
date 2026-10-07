///////////////////////////////////////////
// MODULE jt12_dout
module jt12_dout (
    // input             rst_n,
    input               clk,                      // CPU clock
    input               flag_A,
    input               flag_B,
    input               busy,
    input        [ 5:0] adpcma_flags,
    input               adpcmb_flag,
    input        [ 7:0] psg_dout,
    input        [ 1:0] addr,
    output reg   [ 7:0] dout,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter use_ssg = 0, use_adpcm = 0;

  always @(posedge clk) begin
    begin
      casez (addr)
        2'b00: dout <= {busy, 5'd0, flag_B, flag_A};  // YM2203
        2'b01: dout <= (use_ssg == 1) ? psg_dout : {busy, 5'd0, flag_B, flag_A};
        2'b1?:
        dout <= (use_adpcm == 1) ? {adpcmb_flag, 1'b0, adpcma_flags} : {busy, 5'd0, flag_B, flag_A};
      endcase
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          dout <= auto_ss_data_in[7:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[8-1:0] = dout;
          auto_ss_ack             = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_div
module jt12_div (
    input               rst,
    input               clk,
    input               cen  /* synthesis direct_enable */,
    input        [ 1:0] div_setting,
    output reg          clk_en,                              // after prescaler
    output reg          clk_en_2,                            // cen divided by 2
    output reg          clk_en_ssg,
    output reg          clk_en_666,                          // 666 kHz
    output reg          clk_en_111,                          // 111 kHz
    output reg          clk_en_55,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack
    //  55 kHz
);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter use_ssg = 0;

  reg [3:0] opn_pres, opn_cnt = 4'd0;
  reg [2:0] ssg_pres, ssg_cnt = 3'd0;
  reg [4:0] adpcm_cnt666 = 5'd0;
  reg [2:0] adpcm_cnt111 = 3'd0, adpcm_cnt55 = 3'd0;
  reg cen_int, cen_ssg_int, cen_adpcm_int, cen_adpcm3_int;

  // prescaler values for FM
  // reset: 1/3
  // sel1/sel2
  //    0 0    1/3
  //    0 1    1/2
  //    1 0    1/6  
  //    1 1    1/2
  //
  // According to YM2608 document
  //                  FM      SSG   div[1:0]
  // reset value     1/6      1/4    10
  // 2D              1/6      1/4    10   | 10
  // 2D,2E           1/3      1/2    11   | 01
  // 2F              1/2      1/1    00   & 00
  //  

  always @(*) begin
    casez (div_setting)
      2'b0?: begin  // FM 1/2 - SSG 1/1
        opn_pres = 4'd2 - 4'd1;
        ssg_pres = 3'd0;
      end
      2'b10: begin  // FM 1/6 - SSG 1/4 (reset value. Fixed for YM2610)
        opn_pres = 4'd6 - 4'd1;
        ssg_pres = 3'd3;
      end
      2'b11: begin  // FM 1/3 - SSG 1/2
        opn_pres = 4'd3 - 4'd1;
        ssg_pres = 3'd1;
      end
    endcase  // div_setting
  end



  reg       cen_55_int;
  reg [1:0] div2 = 2'b0;

  always @(negedge clk) begin
    begin
      cen_int        <= opn_cnt == 4'd0;
      cen_ssg_int    <= ssg_cnt == 3'd0;
      cen_adpcm_int  <= adpcm_cnt666 == 5'd0;
      cen_adpcm3_int <= adpcm_cnt111 == 3'd0;
      cen_55_int     <= adpcm_cnt55 == 3'd0;

      clk_en         <= cen & cen_int;
      clk_en_2       <= cen && (div2 == 2'b00);
      clk_en_ssg     <= use_ssg ? (cen & cen_ssg_int) : 1'b0;
      clk_en_666     <= cen & cen_adpcm_int;
      clk_en_111     <= cen & cen_adpcm_int & cen_adpcm3_int;
      clk_en_55      <= cen & cen_adpcm_int & cen_adpcm3_int & cen_55_int;

    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cen_55_int     <= auto_ss_data_in[20];
          cen_adpcm3_int <= auto_ss_data_in[21];
          cen_adpcm_int  <= auto_ss_data_in[22];
          cen_int        <= auto_ss_data_in[23];
          cen_ssg_int    <= auto_ss_data_in[24];
          clk_en         <= auto_ss_data_in[25];
          clk_en_111     <= auto_ss_data_in[26];
          clk_en_2       <= auto_ss_data_in[27];
          clk_en_55      <= auto_ss_data_in[28];
          clk_en_666     <= auto_ss_data_in[29];
          clk_en_ssg     <= auto_ss_data_in[30];
        end
        default: begin
        end
      endcase
    end
  end



  // Div/2
  always @(posedge clk) begin

    if (cen) begin
      div2 <= div2 == 2'b10 ? 2'b00 : (div2 + 2'b01);
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          div2 <= auto_ss_data_in[19:18];
        end
        default: begin
        end
      endcase
    end
  end



  // OPN
  always @(posedge clk) begin

    if (cen) begin
      if (opn_cnt == opn_pres) begin
        opn_cnt <= 4'd0;
      end else opn_cnt <= opn_cnt + 4'd1;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          opn_cnt <= auto_ss_data_in[8:5];
        end
        default: begin
        end
      endcase
    end
  end



  // SSG
  always @(posedge clk) begin

    if (cen) begin
      if (ssg_cnt == ssg_pres) begin
        ssg_cnt <= 3'd0;
      end else ssg_cnt <= ssg_cnt + 3'd1;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          ssg_cnt <= auto_ss_data_in[11:9];
        end
        default: begin
        end
      endcase
    end
  end



  // ADPCM-A
  always @(posedge clk) begin

    if (cen) begin
      adpcm_cnt666 <= adpcm_cnt666 == 5'd11 ? 5'd0 : adpcm_cnt666 + 5'd1;
      if (adpcm_cnt666 == 5'd0) begin
        adpcm_cnt111 <= adpcm_cnt111 == 3'd5 ? 3'd0 : adpcm_cnt111 + 3'd1;
        if (adpcm_cnt111 == 3'd0) adpcm_cnt55 <= adpcm_cnt55 == 3'd1 ? 3'd0 : adpcm_cnt55 + 3'd1;
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          adpcm_cnt666 <= auto_ss_data_in[4:0];
          adpcm_cnt111 <= auto_ss_data_in[14:12];
          adpcm_cnt55  <= auto_ss_data_in[17:15];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[30:0] = {
            clk_en_ssg,
            clk_en_666,
            clk_en_55,
            clk_en_2,
            clk_en_111,
            clk_en,
            cen_ssg_int,
            cen_int,
            cen_adpcm_int,
            cen_adpcm3_int,
            cen_55_int,
            div2,
            adpcm_cnt55,
            adpcm_cnt111,
            ssg_cnt,
            opn_cnt,
            adpcm_cnt666
          };
          auto_ss_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_sumch
module jt12_sumch (
    input      [4:0] chin,
    output reg [4:0] chout
);

  parameter num_ch = 6;

  reg [2:0] aux;

  always @(*) begin
    aux = chin[2:0] + 3'd1;
    if (num_ch == 6) begin
      chout[2:0] = aux[1:0] == 2'b11 ? aux + 3'd1 : aux;
      chout[4:3] = chin[2:0] == 3'd6 ? chin[4:3] + 2'd1 : chin[4:3];  // next operator
    end else begin  // 3 channels
      chout[2:0] = aux[1:0] == 2'b11 ? 3'd0 : aux;
      chout[4:3] = chin[2:0] == 3'd2 ? chin[4:3] + 2'd1 : chin[4:3];  // next operator
    end
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_sh_rst
module jt12_sh_rst #(
    parameter width  = 5,
              stages = 32,
              rstval = 1'b0
) (
    input                    rst,
    input                    clk,
    input                    clk_en  /* synthesis direct_enable */,
    input        [width-1:0] din,
    output       [width-1:0] drop,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input        [     31:0] auto_ss_data_in,
    input        [      7:0] auto_ss_device_idx,
    input        [     15:0] auto_ss_state_idx,
    input        [      7:0] auto_ss_base_device_idx,
    output logic [     31:0] auto_ss_data_out,
    output logic             auto_ss_ack


);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg  [stages-1:0] bits                                    [width-1:0];
  wire [ width-1:0] din_mx = rst ? {width{rstval[0]}} : din;

  always @(posedge clk) begin
    begin
      if (clk_en) begin
        for (int i = 0; i < width; i = i + 1) begin
          bits[i] <= {bits[i][stages-2:0], din_mx[i]};
        end
      end
    end
    if (auto_ss_wr && device_match) begin
      if (auto_ss_state_idx < (width)) begin
        bits[auto_ss_state_idx] <= auto_ss_data_in[stages-1:0];
      end
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      if (auto_ss_state_idx < (width)) begin
        auto_ss_data_out[stages-1:0] = bits[auto_ss_state_idx];
        auto_ss_ack                  = 1'b1;
      end
    end
  end



  genvar i;
  generate
    for (i = 0; i < width; i = i + 1) begin : bit_shifter
      assign drop[i] = bits[i][stages-1];
    end
  endgenerate

endmodule


///////////////////////////////////////////
// MODULE jt12_kon
module jt12_kon (
    input       rst,
    input       clk,
    input       clk_en  /* synthesis direct_enable */,
    input [3:0] keyon_op,
    input [2:0] keyon_ch,
    input [1:0] next_op,
    input [2:0] next_ch,
    input       up_keyon,
    input       csm,
    // input            flag_A,
    input       overflow_A,

    output reg          keyon_I,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_konch0_ack | auto_ss_u_konch1_ack | auto_ss_u_konch2_ack | auto_ss_u_konch3_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_konch0_data_out | auto_ss_u_konch1_data_out | auto_ss_u_konch2_data_out | auto_ss_u_konch3_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_konch3_ack;

  wire  [31:0] auto_ss_u_konch3_data_out;

  wire         auto_ss_u_konch2_ack;

  wire  [31:0] auto_ss_u_konch2_data_out;

  wire         auto_ss_u_konch1_ack;

  wire  [31:0] auto_ss_u_konch1_data_out;

  wire         auto_ss_u_konch0_ack;

  wire  [31:0] auto_ss_u_konch0_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;

  wire       csr_out;

  reg        overflow2;
  reg  [4:0] overflow_cycle;
  reg        up_keyon_reg;
  reg  [3:0] tkeyon_op;
  reg  [2:0] tkeyon_ch;


  generate
    if (num_ch == 6) begin
      // capture overflow signal so it lasts long enough
      always @(posedge clk) begin
        if (clk_en) begin
          if (overflow_A) begin
            overflow2      <= 1'b1;
            overflow_cycle <= {next_op, next_ch};
          end else begin
            if (overflow_cycle == {next_op, next_ch}) overflow2 <= 1'b0;
          end
        end
        if (auto_ss_wr && device_match) begin
          case (auto_ss_state_idx)
            0: begin
              overflow_cycle <= auto_ss_data_in[4:0];
              overflow2      <= auto_ss_data_in[12];
            end
            default: begin
            end
          endcase
        end
      end



      always @(posedge clk) begin
        if (clk_en) keyon_I <= (csm && next_ch == 3'd2 && overflow2) || csr_out;
        if (auto_ss_wr && device_match) begin
          case (auto_ss_state_idx)
            0: begin
              keyon_I <= auto_ss_data_in[15];
              keyon_I <= auto_ss_data_in[15];
            end
            default: begin
            end
          endcase
        end
      end



      wire key_upnow;

      assign key_upnow = up_keyon_reg && (tkeyon_ch == next_ch) && (next_op == 2'd3);

      always @(posedge clk) begin
        if (clk_en) begin
          if (rst) up_keyon_reg <= 1'b0;
          if (up_keyon) begin
            up_keyon_reg <= 1'b1;
            tkeyon_op    <= keyon_op;
            tkeyon_ch    <= keyon_ch;
          end else if (key_upnow) up_keyon_reg <= 1'b0;
        end
        if (auto_ss_wr && device_match) begin
          case (auto_ss_state_idx)
            0: begin
              tkeyon_op    <= auto_ss_data_in[8:5];
              tkeyon_ch    <= auto_ss_data_in[11:9];
              up_keyon_reg <= auto_ss_data_in[14];
            end
            default: begin
            end
          endcase
        end
      end




      wire middle1;
      wire middle2;
      wire middle3;
      wire din = key_upnow ? tkeyon_op[3] : csr_out;
      wire mid_din2 = key_upnow ? tkeyon_op[1] : middle1;
      wire mid_din3 = key_upnow ? tkeyon_op[2] : middle2;
      wire mid_din4 = key_upnow ? tkeyon_op[0] : middle3;

      jt12_sh_rst #(
          .width (1),
          .stages(6),
          .rstval(1'b0)
      ) u_konch0 (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .rst                    (rst),
          .din                    (din),
          .drop                   (middle1),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
          .auto_ss_data_out       (auto_ss_u_konch0_data_out),
          .auto_ss_ack            (auto_ss_u_konch0_ack)

      );

      jt12_sh_rst #(
          .width (1),
          .stages(6),
          .rstval(1'b0)
      ) u_konch1 (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .rst                    (rst),
          .din                    (mid_din2),
          .drop                   (middle2),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
          .auto_ss_data_out       (auto_ss_u_konch1_data_out),
          .auto_ss_ack            (auto_ss_u_konch1_ack)

      );

      jt12_sh_rst #(
          .width (1),
          .stages(6),
          .rstval(1'b0)
      ) u_konch2 (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .rst                    (rst),
          .din                    (mid_din3),
          .drop                   (middle3),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 3),
          .auto_ss_data_out       (auto_ss_u_konch2_data_out),
          .auto_ss_ack            (auto_ss_u_konch2_ack)

      );

      jt12_sh_rst #(
          .width (1),
          .stages(6),
          .rstval(1'b0)
      ) u_konch3 (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .rst                    (rst),
          .din                    (mid_din4),
          .drop                   (csr_out),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 4),
          .auto_ss_data_out       (auto_ss_u_konch3_data_out),
          .auto_ss_ack            (auto_ss_u_konch3_ack)

      );
    end else begin  // 3 channels
      reg       din;
      reg [3:0] next_op_hot;

      always @(*) begin
        case (next_op)
          2'd0: next_op_hot = 4'b0001;  // S1
          2'd1: next_op_hot = 4'b0100;  // S3
          2'd2: next_op_hot = 4'b0010;  // S2
          2'd3: next_op_hot = 4'b1000;  // S4
        endcase
        din = keyon_ch[1:0] == next_ch[1:0] && up_keyon ? |(keyon_op & next_op_hot) : csr_out;
      end

      always @(posedge clk) begin
        if (clk_en) keyon_I <= csr_out;
        if (auto_ss_wr && device_match) begin
          case (auto_ss_state_idx)
            0: begin
              keyon_I <= auto_ss_data_in[15];
              keyon_I <= auto_ss_data_in[15];
            end
            default: begin
            end
          endcase
        end
      end


      always_comb begin
        auto_ss_local_data_out = 32'h0;
        auto_ss_local_ack      = 1'b0;
        if (auto_ss_rd && device_match) begin
          case (auto_ss_state_idx)
            0: begin
              auto_ss_local_data_out[15:0] = {
                keyon_I, keyon_I, up_keyon_reg, overflow2, tkeyon_ch, tkeyon_op, overflow_cycle
              };
              auto_ss_local_ack = 1'b1;
            end
            default: begin
            end
          endcase
        end
      end

      // No CSM for YM2203

      jt12_sh_rst #(
          .width (1),
          .stages(12),
          .rstval(1'b0)
      ) u_konch1 (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .rst                    (rst),
          .din                    (din),
          .drop                   (csr_out),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
          .auto_ss_data_out       (auto_ss_u_konch1_data_out),
          .auto_ss_ack            (auto_ss_u_konch1_ack)

      );
    end
  endgenerate


endmodule


///////////////////////////////////////////
// MODULE jt12_mod
module jt12_mod (
    input s1_enters,
    input s2_enters,
    input s3_enters,
    input s4_enters,

    input [2:0] alg_I,

    output reg xuse_prevprev1,
    output reg xuse_internal,
    output reg yuse_internal,
    output reg xuse_prev2,
    output reg yuse_prev1,
    output reg yuse_prev2
);

  parameter num_ch = 6;

  reg [7:0] alg_hot;

  always @(*) begin
    case (alg_I)
      3'd0: alg_hot = 8'h1;  // D0
      3'd1: alg_hot = 8'h2;  // D1
      3'd2: alg_hot = 8'h4;  // D2
      3'd3: alg_hot = 8'h8;  // D3
      3'd4: alg_hot = 8'h10;  // D4
      3'd5: alg_hot = 8'h20;  // D5
      3'd6: alg_hot = 8'h40;  // D6
      3'd7: alg_hot = 8'h80;  // D7
    endcase
  end

  // prev2 cannot modulate with prevprev1 at the same time
  // x = prev2, prevprev1, internal_x
  // y = prev1, internal_y

  generate
    if (num_ch == 6) begin
      always @(*) begin
        xuse_prevprev1 = s1_enters | (s3_enters & alg_hot[5]);
        xuse_prev2 = (s3_enters & (|alg_hot[2:0])) | (s4_enters & alg_hot[3]);
        xuse_internal = s4_enters & alg_hot[2];
        yuse_internal = s4_enters & (|{alg_hot[4:3], alg_hot[1:0]});
        yuse_prev1 = s1_enters | (s3_enters&alg_hot[1]) |
                (s2_enters&(|{alg_hot[6:3],alg_hot[0]}) )|
                (s4_enters&(|{alg_hot[5],alg_hot[2]}));
        yuse_prev2 = 1'b0;  // unused for 6 channels
      end
    end else begin
      reg [2:0] xuse_s4, xuse_s3, xuse_s2, xuse_s1;
      reg [2:0] yuse_s4, yuse_s3, yuse_s2, yuse_s1;
      always @(*) begin  // 3 ch
        // S1
        {xuse_s1, yuse_s1} = {3'b001, 3'b100};
        // S2
        casez (1'b1)
          // S2 modulated by S1
          alg_hot[6], alg_hot[5], alg_hot[4], alg_hot[3], alg_hot[0]:
          {xuse_s2, yuse_s2} = {3'b000, 3'b100};  // prev1
          default: {xuse_s2, yuse_s2} = 6'd0;
        endcase
        // S3
        casez (1'b1)
          // S3 modulated by S1
          alg_hot[5]: {xuse_s3, yuse_s3} = {3'b000, 3'b100};  // prev1
          // S3 modulated by S2
          alg_hot[2], alg_hot[0]: {xuse_s3, yuse_s3} = {3'b000, 3'b010};  // prev2
          // S3 modulated by S2+S1
          alg_hot[1]: {xuse_s3, yuse_s3} = {3'b010, 3'b100};  // prev2 + prev1                   
          default: {xuse_s3, yuse_s3} = 6'd0;
        endcase
        // S4
        casez (1'b1)
          // S4 modulated by S1
          alg_hot[5]: {xuse_s4, yuse_s4} = {3'b000, 3'b100};  // prev1
          // S4 modulated by S3
          alg_hot[4], alg_hot[1], alg_hot[0]: {xuse_s4, yuse_s4} = {3'b100, 3'b000};  // prevprev1
          // S4 modulated by S3+S2
          alg_hot[3]: {xuse_s4, yuse_s4} = {3'b100, 3'b010};  // prevprev1+prev2                    
          // S4 modulated by S3+S1
          alg_hot[2]: {xuse_s4, yuse_s4} = {3'b100, 3'b100};  // prevprev1+prev1
          default: {xuse_s4, yuse_s4} = 6'd0;
        endcase
        case ({
          s4_enters, s3_enters, s2_enters, s1_enters
        })
          4'b1000: begin
            {xuse_prevprev1, xuse_prev2, xuse_internal} = xuse_s4;
            {yuse_prev1, yuse_prev2, yuse_internal}     = yuse_s4;
          end
          4'b0100: begin
            {xuse_prevprev1, xuse_prev2, xuse_internal} = xuse_s3;
            {yuse_prev1, yuse_prev2, yuse_internal}     = yuse_s3;
          end
          4'b0010: begin
            {xuse_prevprev1, xuse_prev2, xuse_internal} = xuse_s2;
            {yuse_prev1, yuse_prev2, yuse_internal}     = yuse_s2;
          end
          4'b0001: begin
            {xuse_prevprev1, xuse_prev2, xuse_internal} = xuse_s1;
            {yuse_prev1, yuse_prev2, yuse_internal}     = yuse_s1;
          end
          default: begin
            {xuse_prevprev1, xuse_prev2, xuse_internal} = 3'b0;
            {yuse_prev1, yuse_prev2, yuse_internal}     = 3'b0;
          end
        endcase
      end
    end
  endgenerate

  // Control signals for simulation: should be 2'b0 or 2'b1
  // wire [1:0] xusage = xuse_prevprev1+xuse_prev2+xuse_internal;
  // wire [1:0] yusage = yuse_prev1+yuse_internal;
  // 
  // always @(xusage,yusage)
  //     if( xusage>2'b1 || yusage>2'b1 ) begin
  //         $display("ERROR: x/y over use in jt12_mod");
  //         $finish;
  //     end

endmodule


///////////////////////////////////////////
// MODULE jt12_reg_ch
module jt12_reg_ch (
    input       rst,
    input       clk,
    input       cen,
    input [7:0] din,

    input [2:0] up_ch,
    input [5:0] latch_fnum,
    input       up_fnumlo,
    input       up_alg,
    input       up_pms,

    input        [ 2:0] ch,                       // next active channel
    output reg   [ 2:0] block,
    output reg   [10:0] fnum,
    output reg   [ 2:0] fb,
    output reg   [ 2:0] alg,
    output reg   [ 1:0] rl,
    output reg   [ 1:0] ams_IV,
    output reg   [ 2:0] pms,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter NUM_CH = 6;
  localparam M = NUM_CH == 3 ? 2 : 3;

  reg [ 2:0] reg_block[0:NUM_CH-1];
  reg [10:0] reg_fnum [0:NUM_CH-1];
  reg [ 2:0] reg_fb   [0:NUM_CH-1];
  reg [ 2:0] reg_alg  [0:NUM_CH-1];
  reg [ 1:0] reg_rl   [0:NUM_CH-1];
  reg [ 1:0] reg_ams  [0:NUM_CH-1];
  reg [ 2:0] reg_pms  [0:NUM_CH-1];
  reg [ 2:0] ch_IV;

  wire [M-1:0] ch_sel, out_sel;

  function [M-1:0] chtr(input [2:0] chin);
    reg [2:0] aux;
    begin
      aux  = chin[M-1] ? {1'b0, chin[1:0]} + 3'd3 :  // upper channels
{1'b0, chin[1:0]};  // lower
      chtr = NUM_CH == 3 ? chin[M-1:0] : aux[M-1:0];

    end
  endfunction

  assign ch_sel  = chtr(up_ch);
  assign out_sel = chtr(ch);

  integer i;
  /* verilator lint_off WIDTHEXPAND */
  always @* begin
    ch_IV = ch;
    if (NUM_CH == 6)
      case (out_sel)
        0: ch_IV = 3;
        1: ch_IV = 4;
        2: ch_IV = 5;
        3: ch_IV = 0;
        4: ch_IV = 1;
        5: ch_IV = 2;
        default: ch_IV = 0;
      endcase
  end
  /* verilator lint_on WIDTHEXPAND */

  always @(posedge clk) begin
    if (cen) begin
      block  <= reg_block[out_sel];
      fnum   <= reg_fnum[out_sel];
      fb     <= reg_fb[out_sel];
      alg    <= reg_alg[out_sel];
      rl     <= reg_rl[out_sel];
      ams_IV <= reg_ams[ch_IV[M-1:0]];
      pms    <= reg_pms[out_sel];
      if (NUM_CH == 3) rl <= 3;  // YM2203 has no stereo output
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          fnum   <= auto_ss_data_in[10:0];
          alg    <= auto_ss_data_in[13:11];
          block  <= auto_ss_data_in[16:14];
          fb     <= auto_ss_data_in[19:17];
          pms    <= auto_ss_data_in[22:20];
          ams_IV <= auto_ss_data_in[24:23];
          rl     <= auto_ss_data_in[26:25];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk, posedge rst) begin
    if (rst)
      for (i = 0; i < NUM_CH; i = i + 1) begin
        reg_block[i] <= 0;
        reg_fnum[i]  <= 0;
        reg_fb[i]    <= 0;
        reg_alg[i]   <= 0;
        reg_rl[i]    <= 3;
        reg_ams[i]   <= 0;
        reg_pms[i]   <= 0;
      end
    else if (auto_ss_wr && device_match) begin
      if (auto_ss_state_idx >= (1) && auto_ss_state_idx < (NUM_CH + 1)) begin
        reg_alg[auto_ss_state_idx-1] <= auto_ss_data_in[2:0];
      end
      if (auto_ss_state_idx >= (NUM_CH + 1) && auto_ss_state_idx < (2 * NUM_CH + 1)) begin
        reg_ams[-NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[1:0];
      end
      if (auto_ss_state_idx >= (2 * NUM_CH + 1) && auto_ss_state_idx < (3 * NUM_CH + 1)) begin
        reg_block[-2*NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[2:0];
      end
      if (auto_ss_state_idx >= (3 * NUM_CH + 1) && auto_ss_state_idx < (4 * NUM_CH + 1)) begin
        reg_fb[-3*NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[2:0];
      end
      if (auto_ss_state_idx >= (4 * NUM_CH + 1) && auto_ss_state_idx < (5 * NUM_CH + 1)) begin
        reg_fnum[-4*NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[10:0];
      end
      if (auto_ss_state_idx >= (5 * NUM_CH + 1) && auto_ss_state_idx < (6 * NUM_CH + 1)) begin
        reg_pms[-5*NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[2:0];
      end
      if (auto_ss_state_idx >= (6 * NUM_CH + 1) && auto_ss_state_idx < (7 * NUM_CH + 1)) begin
        reg_rl[-6*NUM_CH+auto_ss_state_idx-1] <= auto_ss_data_in[1:0];
      end
    end else begin
      i = 0;  // prevents latch warning in Quartus
      if (up_fnumlo) {reg_block[ch_sel], reg_fnum[ch_sel]} <= {latch_fnum, din};
      if (up_alg) begin
        reg_fb[ch_sel]  <= din[5:3];
        reg_alg[ch_sel] <= din[2:0];
      end
      if (up_pms) begin
        reg_rl[ch_sel]  <= din[7:6];
        reg_ams[ch_sel] <= din[5:4];
        reg_pms[ch_sel] <= din[2:0];
      end
    end
  end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[26:0] = {rl, ams_IV, pms, fb, block, alg, fnum};
          auto_ss_ack            = 1'b1;
        end
        default: begin
          if (auto_ss_state_idx >= (1) && auto_ss_state_idx < (NUM_CH + 1)) begin
            auto_ss_data_out[3-1:0] = reg_alg[auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
          if (auto_ss_state_idx >= (NUM_CH + 1) && auto_ss_state_idx < (2 * NUM_CH + 1)) begin
            auto_ss_data_out[2-1:0] = reg_ams[-NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
          if (auto_ss_state_idx >= (2 * NUM_CH + 1) && auto_ss_state_idx < (3 * NUM_CH + 1)) begin
            auto_ss_data_out[3-1:0] = reg_block[-2*NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
          if (auto_ss_state_idx >= (3 * NUM_CH + 1) && auto_ss_state_idx < (4 * NUM_CH + 1)) begin
            auto_ss_data_out[3-1:0] = reg_fb[-3*NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
          if (auto_ss_state_idx >= (4 * NUM_CH + 1) && auto_ss_state_idx < (5 * NUM_CH + 1)) begin
            auto_ss_data_out[11-1:0] = reg_fnum[-4*NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack              = 1'b1;
          end
          if (auto_ss_state_idx >= (5 * NUM_CH + 1) && auto_ss_state_idx < (6 * NUM_CH + 1)) begin
            auto_ss_data_out[3-1:0] = reg_pms[-5*NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
          if (auto_ss_state_idx >= (6 * NUM_CH + 1) && auto_ss_state_idx < (7 * NUM_CH + 1)) begin
            auto_ss_data_out[2-1:0] = reg_rl[-6*NUM_CH+auto_ss_state_idx-1];
            auto_ss_ack             = 1'b1;
          end
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_csr
module jt12_csr (  // Circular Shift Register + input mux
    input         rst,
    input         clk,
    input         clk_en  /* synthesis direct_enable */,
    input  [ 7:0] din,
    input  [43:0] shift_in,
    output [43:0] shift_out,

    input               up_tl,
    input               up_dt1,
    input               up_ks_ar,
    input               up_amen_dr,
    input               up_sr,
    input               up_sl_rr,
    input               up_ssgeg,
    input               update_op_I,
    input               update_op_II,
    input               update_op_IV,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_u_regch_ack;

  assign auto_ss_data_out = auto_ss_u_regch_data_out;

  wire        auto_ss_u_regch_ack;

  wire [31:0] auto_ss_u_regch_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  localparam regop_width = 44;

  reg [regop_width-1:0] regop_in;

  jt12_sh_rst #(
      .width (regop_width),
      .stages(12)
  ) u_regch (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (regop_in),
      .drop                   (shift_out),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_regch_data_out),
      .auto_ss_ack            (auto_ss_u_regch_ack)

  );

  wire up_tl_op = up_tl & update_op_IV;
  wire up_dt1_op = up_dt1 & update_op_I;
  wire up_mul_op = up_dt1 & update_op_II;
  wire up_ks_op = up_ks_ar & update_op_II;
  wire up_ar_op = up_ks_ar & update_op_I;
  wire up_amen_op = up_amen_dr & update_op_IV;
  wire up_dr_op = up_amen_dr & update_op_I;
  wire up_sr_op = up_sr & update_op_I;
  wire up_sl_op = up_sl_rr & update_op_I;
  wire up_rr_op = up_sl_rr & update_op_I;
  wire up_ssg_op = up_ssgeg & update_op_I;

  always @(*)
    regop_in = {
      up_tl_op ? din[6:0] : shift_in[43:37],  // 7 
      up_dt1_op ? din[6:4] : shift_in[36:34],  // 3 
      up_mul_op ? din[3:0] : shift_in[33:30],  // 4 
      up_ks_op ? din[7:6] : shift_in[29:28],  // 2 
      up_ar_op ? din[4:0] : shift_in[27:23],  // 5 
      up_amen_op ? din[7] : shift_in[22],  // 1 
      up_dr_op ? din[4:0] : shift_in[21:17],  // 5 
      up_sr_op ? din[4:0] : shift_in[16:12],  // 5 
      up_sl_op ? din[7:4] : shift_in[11:8],  // 4 
      up_rr_op ? din[3:0] : shift_in[7:4],  // 4 
      up_ssg_op ? din[3:0] : shift_in[3:0]  // 4 
    };

endmodule


///////////////////////////////////////////
// MODULE jt12_reg
module jt12_reg (
    input rst,
    input clk,
    input clk_en  /* synthesis direct_enable */,

    input [2:0] ch,  // channel to update
    input [1:0] op,

    input csm,
    input flag_A,
    input overflow_A,

    // channel udpates
    input [2:0] ch_sel,
    input [7:0] ch_din,
    input       up_alg,
    input       up_fnumlo,
    // operator updates
    input [7:0] din,
    input       up_keyon,
    input       up_pms,
    input       up_dt1,
    input       up_tl,
    input       up_ks_ar,
    input       up_amen_dr,
    input       up_sr,
    input       up_sl_rr,
    input       up_ssgeg,

    output reg       ch6op,   // 1 when the operator belongs to CH6
    output reg [2:0] cur_ch,
    output reg [1:0] cur_op,

    // CH3 Effect-mode operation
    input             effect,
    input      [10:0] fnum_ch3op2,
    input      [10:0] fnum_ch3op3,
    input      [10:0] fnum_ch3op1,
    input      [ 2:0] block_ch3op2,
    input      [ 2:0] block_ch3op3,
    input      [ 2:0] block_ch3op1,
    input      [ 5:0] latch_fnum,
    // Pipeline order
    output reg        zero,
    output            s1_enters,
    output            s2_enters,
    output            s3_enters,
    output            s4_enters,

    // Operator
    output xuse_prevprev1,
    output xuse_internal,
    output yuse_internal,
    output xuse_prev2,
    output yuse_prev1,
    output yuse_prev2,

    // PG
    output     [10:0] fnum_I,
    output     [ 2:0] block_I,
    // channel configuration
    output     [ 1:0] rl,
    output reg [ 2:0] fb_II,
    output     [ 2:0] alg_I,
    // Operator multiplying
    output     [ 3:0] mul_II,
    // Operator detuning
    output     [ 2:0] dt1_I,

    // EG
    output [4:0] ar_I,      // attack  rate
    output [4:0] d1r_I,     // decay   rate
    output [4:0] d2r_I,     // sustain rate
    output [3:0] rr_I,      // release rate
    output [3:0] sl_I,      // sustain level
    output [1:0] ks_II,     // key scale
    output       ssg_en_I,
    output [2:0] ssg_eg_I,
    output [6:0] tl_IV,
    output [2:0] pms_I,
    output [1:0] ams_IV,
    output       amsen_IV,

    // envelope operation
    output              keyon_I,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_kon_ack | auto_ss_u_regch_ack | auto_ss_u_csr0_ack | auto_ss_u_csr1_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_kon_data_out | auto_ss_u_regch_data_out | auto_ss_u_csr0_data_out | auto_ss_u_csr1_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_csr1_ack;

  wire  [31:0] auto_ss_u_csr1_data_out;

  wire         auto_ss_u_csr0_ack;

  wire  [31:0] auto_ss_u_csr0_data_out;

  wire         auto_ss_u_regch_ack;

  wire  [31:0] auto_ss_u_regch_data_out;

  wire         auto_ss_u_kon_ack;

  wire  [31:0] auto_ss_u_kon_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;  // Use only 3 (YM2203/YM2610) or 6 (YM2612/YM2608)


  reg [1:0] next_op;
  reg [2:0] next_ch;
  reg       last;



  assign s1_enters = cur_op == 2'b00;
  assign s3_enters = cur_op == 2'b01;
  assign s2_enters = cur_op == 2'b10;
  assign s4_enters = cur_op == 2'b11;

  wire [4:0] next = {next_op, next_ch};
  wire [4:0] cur = {cur_op, cur_ch};

  wire [2:0] fb_I;

  always @(posedge clk) begin
    if (clk_en) begin
      fb_II <= fb_I;
      ch6op <= next_ch == 3'd6;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          fb_II <= auto_ss_data_in[2:0];
          ch6op <= auto_ss_data_in[5];
        end
        default: begin
        end
      endcase
    end
  end



  // FNUM and BLOCK
  wire [10:0] fnum_I_raw;
  wire [ 2:0] block_I_raw;
  wire        effect_on = effect && (cur_ch == 3'd2);
  wire        effect_on_s1 = effect_on && (cur_op == 2'd0);
  wire        effect_on_s3 = effect_on && (cur_op == 2'd1);
  wire        effect_on_s2 = effect_on && (cur_op == 2'd2);
  wire        noeffect = ~|{effect_on_s1, effect_on_s3, effect_on_s2};
  assign fnum_I = ( {11{effect_on_s1}} & fnum_ch3op1 ) |
                ( {11{effect_on_s2}} & fnum_ch3op2 ) |
                ( {11{effect_on_s3}} & fnum_ch3op3 ) |
                ( {11{noeffect}}     & fnum_I_raw  );

  assign block_I =( {3{effect_on_s1}} & block_ch3op1 ) |
                ( {3{effect_on_s2}} & block_ch3op2 ) |
                ( {3{effect_on_s3}} & block_ch3op3 ) |
                ( {3{noeffect}}  & block_I_raw  );

  wire [4:0] req_opch_I = {op, ch};
  wire [4:0] req_opch_II, req_opch_III, req_opch_IV, req_opch_V;  //, req_opch_VI;

  jt12_sumch #(
      .num_ch(num_ch)
  ) u_opch_II (
      .chin (req_opch_I),
      .chout(req_opch_II)
  );
  jt12_sumch #(
      .num_ch(num_ch)
  ) u_opch_III (
      .chin (req_opch_II),
      .chout(req_opch_III)
  );
  jt12_sumch #(
      .num_ch(num_ch)
  ) u_opch_IV (
      .chin (req_opch_III),
      .chout(req_opch_IV)
  );
  jt12_sumch #(
      .num_ch(num_ch)
  ) u_opch_V (
      .chin (req_opch_IV),
      .chout(req_opch_V)
  );
  // jt12_sumch #(.num_ch(num_ch)) u_opch_VI ( .chin(req_opch_V  ), .chout(req_opch_VI)  );

  wire       update_op_I = cur == req_opch_I;
  wire       update_op_II = cur == req_opch_II;
  // wire update_op_III= cur == req_opch_III;
  wire       update_op_IV = cur == req_opch_IV;
  // wire update_op_V  = cur == req_opch_V;
  // wire update_op_VI = cur == opch_VI;
  // wire [2:0] op_plus1 = op+2'd1;
  // wire update_op_VII= cur == { op_plus1[1:0], ch };

  // key on/off
  wire [3:0] keyon_op = din[7:4];
  wire [2:0] keyon_ch = din[2:0];

  always @(*) begin
    // next = cur==5'd23 ? 5'd0 : cur +1'b1;
    if (num_ch == 6) begin
      next_op = cur_ch == 3'd6 ? cur_op + 1'b1 : cur_op;
      next_ch = cur_ch[1:0] == 2'b10 ? cur_ch + 2'd2 : cur_ch + 1'd1;
    end else begin  // 3 channels
      next_op = cur_ch == 3'd2 ? cur_op + 1'b1 : cur_op;
      next_ch = cur_ch[1:0] == 2'b10 ? 3'd0 : cur_ch + 1'd1;
    end
  end

  always @(posedge clk) begin
    begin : up_counter
      if (clk_en) begin
        {cur_op, cur_ch} <= {next_op, next_ch};
        zero             <= next == 5'd0;
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cur_op <= auto_ss_data_in[4:3];
          zero   <= auto_ss_data_in[6];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[6:0] = {zero, ch6op, cur_op, fb_II};
          auto_ss_local_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end




  jt12_kon #(
      .num_ch(num_ch)
  ) u_kon (
      .rst       (rst),
      .clk       (clk),
      .clk_en    (clk_en),
      .keyon_op  (keyon_op),
      .keyon_ch  (keyon_ch),
      .next_op   (next_op),
      .next_ch   (next_ch),
      .up_keyon  (up_keyon),
      .csm       (csm),
      // .flag_A      ( flag_A    ),
      .overflow_A(overflow_A),

      .keyon_I                (keyon_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_kon_data_out),
      .auto_ss_ack            (auto_ss_u_kon_ack)

  );

  jt12_mod #(
      .num_ch(num_ch)
  ) u_mod (
      .alg_I    (alg_I),
      .s1_enters(s1_enters),
      .s3_enters(s3_enters),
      .s2_enters(s2_enters),
      .s4_enters(s4_enters),

      .xuse_prevprev1(xuse_prevprev1),
      .xuse_internal (xuse_internal),
      .yuse_internal (yuse_internal),
      .xuse_prev2    (xuse_prev2),
      .yuse_prev1    (yuse_prev1),
      .yuse_prev2    (yuse_prev2)
  );

  wire [43:0] shift_out;

  generate
    if (num_ch == 6) begin
      // YM2612 / YM3438: Two CSR.
      wire [43:0] shift_middle;

      jt12_csr u_csr0 (
          .rst                    (rst),
          .clk                    (clk),
          .clk_en                 (clk_en),
          .din                    (din),
          .shift_in               (shift_out),
          .shift_out              (shift_middle),
          .up_tl                  (up_tl),
          .up_dt1                 (up_dt1),
          .up_ks_ar               (up_ks_ar),
          .up_amen_dr             (up_amen_dr),
          .up_sr                  (up_sr),
          .up_sl_rr               (up_sl_rr),
          .up_ssgeg               (up_ssgeg),
          .update_op_I            (update_op_I),
          .update_op_II           (update_op_II),
          .update_op_IV           (update_op_IV),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 8),
          .auto_ss_data_out       (auto_ss_u_csr0_data_out),
          .auto_ss_ack            (auto_ss_u_csr0_ack)

      );

      wire up_midop_I = {~cur[4], cur[3:0]} == req_opch_I;
      wire up_midop_II = {~cur[4], cur[3:0]} == req_opch_II;
      wire up_midop_IV = {~cur[4], cur[3:0]} == req_opch_IV;

      jt12_csr u_csr1 (
          .rst                    (rst),
          .clk                    (clk),
          .clk_en                 (clk_en),
          .din                    (din),
          .shift_in               (shift_middle),
          .shift_out              (shift_out),
          .up_tl                  (up_tl),
          .up_dt1                 (up_dt1),
          .up_ks_ar               (up_ks_ar),
          .up_amen_dr             (up_amen_dr),
          .up_sr                  (up_sr),
          .up_sl_rr               (up_sl_rr),
          .up_ssgeg               (up_ssgeg),
          // update in the middle:
          .update_op_I            (up_midop_I),
          .update_op_II           (up_midop_II),
          .update_op_IV           (up_midop_IV),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 10),
          .auto_ss_data_out       (auto_ss_u_csr1_data_out),
          .auto_ss_ack            (auto_ss_u_csr1_ack)

      );
    end else begin  // YM2203 only has one CSR
      jt12_csr u_csr0 (
          .rst                    (rst),
          .clk                    (clk),
          .clk_en                 (clk_en),
          .din                    (din),
          .shift_in               (shift_out),
          .shift_out              (shift_out),
          .up_tl                  (up_tl),
          .up_dt1                 (up_dt1),
          .up_ks_ar               (up_ks_ar),
          .up_amen_dr             (up_amen_dr),
          .up_sr                  (up_sr),
          .up_sl_rr               (up_sl_rr),
          .up_ssgeg               (up_ssgeg),
          .update_op_I            (update_op_I),
          .update_op_II           (update_op_II),
          .update_op_IV           (update_op_IV),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 12),
          .auto_ss_data_out       (auto_ss_u_csr0_data_out),
          .auto_ss_ack            (auto_ss_u_csr0_ack)

      );
    end  // else
  endgenerate

  assign { tl_IV,   dt1_I,    mul_II,    ks_II, 
         ar_I,    amsen_IV, d1r_I,     d2r_I, 
         sl_I,    rr_I,     ssg_en_I,  ssg_eg_I } = shift_out;


  // memory for CH registers
  jt12_reg_ch #(
      .NUM_CH(num_ch)
  ) u_regch (
      .rst(rst),
      .clk(clk),
      .cen(clk_en),
      .din(ch_din),

      .up_ch     (ch_sel),
      .latch_fnum(latch_fnum),
      .up_fnumlo (up_fnumlo),
      .up_alg    (up_alg),
      .up_pms    (up_pms),

      .ch                     (next_ch),                      // next active channel
      .block                  (block_I_raw),
      .fnum                   (fnum_I_raw),
      .fb                     (fb_I),
      .alg                    (alg_I),
      .rl                     (rl),
      .ams_IV                 (ams_IV),
      .pms                    (pms_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 7),
      .auto_ss_data_out       (auto_ss_u_regch_data_out),
      .auto_ss_ack            (auto_ss_u_regch_ack)

  );


endmodule


///////////////////////////////////////////
// MODULE jt12_mmr
module jt12_mmr (
    input rst,
    input clk,
    input cen  /* synthesis direct_enable */,
    output clk_en,
    output clk_en_2,
    output clk_en_ssg,
    output clk_en_666,
    output clk_en_111,
    output clk_en_55,
    input [7:0] din,
    input write,
    input [1:0] addr,
    output reg busy,
    output ch6op,
    output [2:0] cur_ch,
    output [1:0] cur_op,
    // LFO
    output reg [2:0] lfo_freq,
    output reg lfo_en,
    // Timers
    output reg [9:0] value_A,
    output reg [7:0] value_B,
    output reg load_A,
    output reg load_B,
    output reg enable_irq_A,
    output reg enable_irq_B,
    output reg clr_flag_A,
    output reg clr_flag_B,
    output reg fast_timers,
    input flag_A,
    input overflow_A,
    output reg [1:0] div_setting,
    // PCM
    output reg [8:0] pcm,
    output reg pcm_en,
    output reg pcm_wr,  // high for one clock cycle when PCM is written
    // ADPCM-A
    output reg [7:0] aon_a,  // ON
    output reg [5:0] atl_a,  // TL
    output reg [15:0] addr_a,  // address latch
    output reg [7:0] lracl,  // L/R ADPCM Channel Level
    output reg up_start,  // write enable start address latch
    output reg up_end,  // write enable end address latch
    output reg [2:0] up_addr,  // write enable end address latch
    output reg [2:0] up_lracl,
    output reg up_aon,  // There was a write AON register
    // ADPCM-B
    output reg acmd_on_b,  // Control - Process start, Key On
    output reg acmd_rep_b,  // Control - Repeat
    output reg acmd_rst_b,  // Control - Reset
    output reg acmd_up_b,  // Control - New cmd received
    output reg [1:0] alr_b,  // Left / Right
    output reg [15:0] astart_b,  // Start address
    output reg [15:0] aend_b,  // End   address
    output reg [15:0] adeltan_b,  // Delta-N
    output reg [7:0] aeg_b,  // Envelope Generator Control
    output reg [6:0] flag_ctl,
    output reg [6:0] flag_mask,
    // Operator
    output xuse_prevprev1,
    output xuse_internal,
    output yuse_internal,
    output xuse_prev2,
    output yuse_prev1,
    output yuse_prev2,
    // PG
    output [10:0] fnum_I,
    output [2:0] block_I,
    output reg pg_stop,
    // REG
    output [1:0] rl,
    output [2:0] fb_II,
    output [2:0] alg_I,
    output [2:0] pms_I,
    output [1:0] ams_IV,
    output amsen_IV,
    output [2:0] dt1_I,
    output [3:0] mul_II,
    output [6:0] tl_IV,
    output reg eg_stop,

    output [4:0] ar_I,
    output [4:0] d1r_I,
    output [4:0] d2r_I,
    output [3:0] rr_I,
    output [3:0] sl_I,
    output [1:0] ks_II,
    // SSG operation
    output       ssg_en_I,
    output [2:0] ssg_eg_I,

    output keyon_I,

    // Operator
    output zero,
    output s1_enters,
    output s2_enters,
    output s3_enters,
    output s4_enters,

    // PSG interace
    output       [ 3:0] psg_addr,
    output       [ 7:0] psg_data,
    output reg          psg_wr_n,
    input        [ 7:0] debug_bus,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_div_ack | auto_ss_u_reg_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_div_data_out | auto_ss_u_reg_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_reg_ack;

  wire  [31:0] auto_ss_u_reg_data_out;

  wire         auto_ss_u_div_ack;

  wire  [31:0] auto_ss_u_div_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter use_ssg = 0, num_ch = 6, use_pcm = 1, use_adpcm = 0, mask_div = 1;

  jt12_div #(
      .use_ssg(use_ssg)
  ) u_div (
      .rst                    (rst),
      .clk                    (clk),
      .cen                    (cen),
      .div_setting            (div_setting),
      .clk_en                 (clk_en),
      .clk_en_2               (clk_en_2),
      .clk_en_ssg             (clk_en_ssg),
      .clk_en_666             (clk_en_666),
      .clk_en_111             (clk_en_111),
      .clk_en_55              (clk_en_55),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_div_data_out),
      .auto_ss_ack            (auto_ss_u_div_ack)

  );

  reg [7:0] selected_register;

  /*
reg     irq_zero_en, irq_brdy_en, irq_eos_en,
        irq_tb_en, irq_ta_en;
        */
  reg [6:0] up_opreg;  // hot-one encoding. tells which operator register gets updated next
  reg [2:0] up_chreg;  // hot-one encoding. tells which channel register gets updated next
  reg       up_keyon;

  localparam  REG_TESTYM  =   8'h21,
            REG_LFO     =   8'h22,
            REG_CLKA1   =   8'h24,
            REG_CLKA2   =   8'h25,
            REG_CLKB    =   8'h26,
            REG_TIMER   =   8'h27,
            REG_KON     =   8'h28,
            REG_IRQMASK =   8'h29,
            REG_PCM     =   8'h2A,
            REG_PCM_EN  =   8'h2B,
            REG_DACTEST =   8'h2C,
            REG_CLK_N6  =   8'h2D,
            REG_CLK_N3  =   8'h2E,
            REG_CLK_N2  =   8'h2F,
  // ADPCM (YM2610)
  REG_ADPCMA_ON = 8'h00, REG_ADPCMA_TL = 8'h01, REG_ADPCMA_TEST = 8'h02;

  reg csm, effect;

  reg [2:0] block_ch3op2, block_ch3op3, block_ch3op1;
  reg [10:0] fnum_ch3op2, fnum_ch3op3, fnum_ch3op1;
  reg [5:0] latch_fnum;


  reg [2:0] up_ch;
  reg [1:0] up_op;

  reg [7:0] op_din, ch_din;

  generate
    if (use_ssg) begin
      assign psg_addr = selected_register[3:0];
      assign psg_data = ch_din;
    end else begin
      assign psg_addr = 4'd0;
      assign psg_data = 8'd0;
    end
  endgenerate

  reg        part;



  wire [2:0] ch_sel = {part, selected_register[1:0]};

  // this runs at clk speed, no clock gating here
  // if I try to make this an async rst it fails to map it
  // as flip flops but uses latches instead. So I keep it as sync. reset
  always @(posedge clk) begin
    begin : memory_mapped_registers
      if (rst) begin
        selected_register <= 0;
        div_setting <= 2'b10;  // FM=1/6, SSG=1/4
        up_ch <= 0;
        up_op <= 0;
        up_keyon <= 0;
        up_opreg <= 0;
        up_chreg <= 0;
        // IRQ Mask
        /*{ irq_zero_en, irq_brdy_en, irq_eos_en,
            irq_tb_en, irq_ta_en } = 5'h1f; */
        // timers
        {value_A, value_B} <= 0;
        {clr_flag_B, clr_flag_A, enable_irq_B, enable_irq_A, load_B, load_A} <= 0;
        fast_timers <= 0;
        // LFO
        lfo_freq <= 0;
        lfo_en <= 0;
        csm <= 0;
        effect <= 0;
        // PCM
        pcm <= 0;
        pcm_en <= 0;
        pcm_wr <= 0;
        // ADPCM-A
        aon_a <= 0;
        atl_a <= 0;
        up_start <= 0;
        up_end <= 0;
        up_addr <= 7;
        up_lracl <= 7;
        up_aon <= 0;
        lracl <= 0;
        addr_a <= 0;
        // ADPCM-B
        acmd_on_b <= 0;
        acmd_rep_b <= 0;
        acmd_rst_b <= 0;
        alr_b <= 0;
        flag_ctl <= 0;
        astart_b <= 0;
        aend_b <= 0;
        adeltan_b <= 0;
        flag_mask <= 0;
        aeg_b <= 8'hff;
        // Original test features
        eg_stop <= 0;
        pg_stop <= 0;
        psg_wr_n <= 1;
        // 
        {block_ch3op1, fnum_ch3op1} <= {3'd0, 11'd0};
        {block_ch3op3, fnum_ch3op3} <= {3'd0, 11'd0};
        {block_ch3op2, fnum_ch3op2} <= {3'd0, 11'd0};
        latch_fnum <= 0;
        op_din <= 0;
        part <= 0;
      end else begin
        up_chreg <= 0;
        // WRITE IN REGISTERS
        if (write) begin
          if (!addr[0]) begin
            selected_register <= din;
            part              <= addr[1];
            if (!mask_div)
              case (din)
                // clock divider: should work only for ym2203
                // and ym2608.
                // clock divider works just by selecting the register
                REG_CLK_N6: div_setting[1] <= 1'b1; // 2D
                REG_CLK_N3: div_setting[0] <= 1'b1; // 2E
                REG_CLK_N2: div_setting    <= 2'b0; // 2F
                default:;
              endcase
          end else begin
            // Global registers
            ch_din <= din;
            if (selected_register == REG_KON && !part) begin
              up_keyon <= 1;
              op_din   <= din;
            end else begin
              up_keyon <= 0;
            end
            // General control (<0x20 registers and A0==0)
            if (!part) begin
              casez (selected_register)
                //REG_TEST: lfo_rst <= 1'b1; // regardless of din
                8'h0?:     psg_wr_n <= 1'b0;
                REG_TESTYM: begin
                  eg_stop     <= din[5];
                  pg_stop     <= din[3];
                  fast_timers <= din[2];
                end
                REG_CLKA1: value_A[9:2] <= din;
                REG_CLKA2: value_A[1:0] <= din[1:0];
                REG_CLKB:  value_B <= din;
                REG_TIMER: begin
                  effect <= |din[7:6];
                  csm <= din[7:6] == 2'b10;
                  {clr_flag_B, clr_flag_A, enable_irq_B, enable_irq_A, load_B, load_A} <= din[5:0];
                end

                REG_LFO: {lfo_en, lfo_freq} <= din[3:0];

                default: ;
              endcase
            end

            // CH3 special registers
            casez (selected_register)
              8'hA9: {block_ch3op1, fnum_ch3op1} <= {latch_fnum, din};
              8'hA8: {block_ch3op3, fnum_ch3op3} <= {latch_fnum, din};
              8'hAA: {block_ch3op2, fnum_ch3op2} <= {latch_fnum, din};
              // According to http://www.mjsstuf.x10host.com/pages/vgmPlay/vgmPlay.htm
              // There is a single fnum latch for all channels
              8'hA4, 8'hA5, 8'hA6, 8'hAD, 8'hAC, 8'hAE: latch_fnum <= din[5:0];
              default: ;  // avoid incomplete-case warning
            endcase

            // YM2612 PCM support
            if (use_pcm == 1) begin
              casez (selected_register)
                REG_DACTEST: pcm[0] <= din[3];
                REG_PCM: pcm <= {~din[7], din[6:0], 1'b1};
                REG_PCM_EN: pcm_en <= din[7];
                default: ;
              endcase
              pcm_wr <= selected_register == REG_PCM;
            end
            if (use_adpcm == 1) begin
              // YM2610 ADPCM-A support, A1=1, regs 0-2D
              if (part && selected_register[7:6] == 2'b0) begin
                casez (selected_register[5:0])
                  6'h0: begin
                    aon_a  <= din;
                    up_aon <= 1'b1;
                  end
                  6'h1: atl_a <= din[5:0];
                  // LRACL
                  6'h8, 6'h9, 6'hA, 6'hB, 6'hC, 6'hD: begin
                    lracl    <= din;
                    up_lracl <= selected_register[2:0];
                  end
                  6'b01_????, 6'b10_????: begin
                    if (!selected_register[3]) addr_a[7:0] <= din;
                    if (selected_register[3]) addr_a[15:8] <= din;
                    case (selected_register[5:4])
                      2'b01, 2'b10: begin
                        {up_end, up_start} <= selected_register[5:4];
                        up_addr            <= selected_register[2:0];
                      end
                      default: begin
                        up_start <= 1'b0;
                        up_end   <= 1'b0;
                      end
                    endcase
                  end
                  default: ;
                endcase
              end
              if (!part && selected_register[7:4] == 4'h1) begin
                // YM2610 ADPCM-B support, A1=0, regs 1x
                case (selected_register[3:0])
                  4'd0:
                  {acmd_up_b, acmd_on_b, acmd_rep_b, acmd_rst_b} <= {1'd1, din[7], din[4], din[0]};
                  4'd1: alr_b <= din[7:6];
                  4'd2: astart_b[7:0] <= din;
                  4'd3: astart_b[15:8] <= din;
                  4'd4: aend_b[7:0] <= din;
                  4'd5: aend_b[15:8] <= din;
                  4'h9: adeltan_b[7:0] <= din;
                  4'ha: adeltan_b[15:8] <= din;
                  4'hb: aeg_b <= din;
                  4'hc: begin
                    flag_mask <= ~{din[7], din[5:0]};
                    flag_ctl  <= {din[7], din[5:0]};  // this lasts a single clock cycle
                  end
                  default: ;
                endcase
              end
            end
            if (selected_register[1:0] == 2'b11) {up_chreg, up_opreg} <= {3'h0, 7'h0};
            else begin
              casez (selected_register)
                // channel registers
                8'hA0, 8'hA1, 8'hA2:    { up_chreg, up_opreg } <= { 3'h1, 7'd0 }; // up_fnumlo
                // FB + Algorithm
                8'hB0, 8'hB1, 8'hB2: { up_chreg, up_opreg } <= { 3'h2, 7'd0 }; // up_alg
                8'hB4, 8'hB5, 8'hB6: { up_chreg, up_opreg } <= { 3'h4, 7'd0 }; // up_pms
                // operator registers
                8'h3?: { up_chreg, up_opreg } <= { 3'h0, 7'h01 }; // up_dt1
                8'h4?: { up_chreg, up_opreg } <= { 3'h0, 7'h02 }; // up_tl
                8'h5?: { up_chreg, up_opreg } <= { 3'h0, 7'h04 }; // up_ks_ar
                8'h6?: { up_chreg, up_opreg } <= { 3'h0, 7'h08 }; // up_amen_dr
                8'h7?: { up_chreg, up_opreg } <= { 3'h0, 7'h10 }; // up_sr
                8'h8?: { up_chreg, up_opreg } <= { 3'h0, 7'h20 }; // up_sl
                8'h9?: { up_chreg, up_opreg } <= { 3'h0, 7'h40 }; // up_ssgeg
                default: { up_chreg, up_opreg } <= { 3'h0, 7'h0 };
              endcase  // selected_register
              if (selected_register[7:4] >= 3 && selected_register[7:4] <= 9) begin
                op_din <= din;
                up_ch  <= {part, selected_register[1:0]};
                up_op  <= selected_register[3:2];  // 0=S1,1=S3,2=S2,3=S4
              end
            end
          end
        end else if (clk_en) begin  /* clear once-only bits */
          // lfo_rst <= 1'b0;
          {clr_flag_B, clr_flag_A} <= 2'd0;
          psg_wr_n                 <= 1'b1;
          pcm_wr                   <= 1'b0;
          flag_ctl                 <= 'd0;
          up_aon                   <= 1'b0;
          acmd_up_b                <= 1'b0;
        end
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          addr_a    <= auto_ss_data_in[15:0];
          adeltan_b <= auto_ss_data_in[31:16];
        end
        1: begin
          aend_b   <= auto_ss_data_in[15:0];
          astart_b <= auto_ss_data_in[31:16];
        end
        2: begin
          value_A <= auto_ss_data_in[9:0];
          pcm     <= auto_ss_data_in[18:10];
          aeg_b   <= auto_ss_data_in[26:19];
        end
        3: begin
          aon_a  <= auto_ss_data_in[7:0];
          ch_din <= auto_ss_data_in[15:8];
          lracl  <= auto_ss_data_in[23:16];
          op_din <= auto_ss_data_in[31:24];
        end
        4: begin
          selected_register <= auto_ss_data_in[7:0];
          value_B           <= auto_ss_data_in[15:8];
          flag_ctl          <= auto_ss_data_in[22:16];
          flag_mask         <= auto_ss_data_in[29:23];
        end
        5: begin
          up_opreg     <= auto_ss_data_in[6:0];
          atl_a        <= auto_ss_data_in[12:7];
          latch_fnum   <= auto_ss_data_in[18:13];
          block_ch3op1 <= auto_ss_data_in[26:24];
          block_ch3op2 <= auto_ss_data_in[29:27];
        end
        6: begin
          block_ch3op3 <= auto_ss_data_in[2:0];
          lfo_freq     <= auto_ss_data_in[5:3];
          up_addr      <= auto_ss_data_in[8:6];
          up_ch        <= auto_ss_data_in[11:9];
          up_chreg     <= auto_ss_data_in[14:12];
          up_lracl     <= auto_ss_data_in[17:15];
          alr_b        <= auto_ss_data_in[19:18];
          div_setting  <= auto_ss_data_in[21:20];
          up_op        <= auto_ss_data_in[23:22];
          acmd_on_b    <= auto_ss_data_in[24];
          acmd_rep_b   <= auto_ss_data_in[25];
          acmd_rst_b   <= auto_ss_data_in[26];
          acmd_up_b    <= auto_ss_data_in[27];
          clr_flag_B   <= auto_ss_data_in[28];
          csm          <= auto_ss_data_in[29];
          effect       <= auto_ss_data_in[30];
          eg_stop      <= auto_ss_data_in[31];
        end
        7: begin
          fast_timers <= auto_ss_data_in[0];
          lfo_en      <= auto_ss_data_in[1];
          part        <= auto_ss_data_in[2];
          pcm_en      <= auto_ss_data_in[3];
          pcm_wr      <= auto_ss_data_in[4];
          pg_stop     <= auto_ss_data_in[5];
          psg_wr_n    <= auto_ss_data_in[6];
          up_aon      <= auto_ss_data_in[7];
          up_end      <= auto_ss_data_in[8];
          up_keyon    <= auto_ss_data_in[9];
          up_start    <= auto_ss_data_in[10];
        end
        default: begin
        end
      endcase
    end
  end



  reg  [4:0] busy_cnt;  // busy lasts for 32 synthesizer clock cycles
  wire [5:0] nx_busy = {1'd0, busy_cnt} + {5'd0, busy};

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      busy     <= 0;
      busy_cnt <= 0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        5: begin
          busy_cnt <= auto_ss_data_in[23:19];
        end
        7: begin
          busy <= auto_ss_data_in[11];
        end
        default: begin
        end
      endcase
    end else begin
      if (write & addr[0]) begin
        busy     <= 1;
        busy_cnt <= 0;
      end else if (clk_en) begin
        busy     <= ~nx_busy[5] & busy;
        busy_cnt <= nx_busy[4:0];
      end
    end
  end
  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[31:0] = {adeltan_b, addr_a};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[31:0] = {astart_b, aend_b};
          auto_ss_local_ack            = 1'b1;
        end
        2: begin
          auto_ss_local_data_out[26:0] = {aeg_b, pcm, value_A};
          auto_ss_local_ack            = 1'b1;
        end
        3: begin
          auto_ss_local_data_out[31:0] = {op_din, lracl, ch_din, aon_a};
          auto_ss_local_ack            = 1'b1;
        end
        4: begin
          auto_ss_local_data_out[29:0] = {flag_mask, flag_ctl, value_B, selected_register};
          auto_ss_local_ack            = 1'b1;
        end
        5: begin
          auto_ss_local_data_out[29:0] = {
            block_ch3op2, block_ch3op1, busy_cnt, latch_fnum, atl_a, up_opreg
          };
          auto_ss_local_ack = 1'b1;
        end
        6: begin
          auto_ss_local_data_out[31:0] = {
            eg_stop,
            effect,
            csm,
            clr_flag_B,
            acmd_up_b,
            acmd_rst_b,
            acmd_rep_b,
            acmd_on_b,
            up_op,
            div_setting,
            alr_b,
            up_lracl,
            up_chreg,
            up_ch,
            up_addr,
            lfo_freq,
            block_ch3op3
          };
          auto_ss_local_ack = 1'b1;
        end
        7: begin
          auto_ss_local_data_out[11:0] = {
            busy,
            up_start,
            up_keyon,
            up_end,
            up_aon,
            psg_wr_n,
            pg_stop,
            pcm_wr,
            pcm_en,
            part,
            lfo_en,
            fast_timers
          };
          auto_ss_local_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt12_reg #(
      .num_ch(num_ch)
  ) u_reg (
      .rst   (rst),
      .clk   (clk),    // P1
      .clk_en(clk_en),

      // channel udpates
      .ch_sel   (ch_sel),
      .ch_din   (ch_din),
      .up_fnumlo(up_chreg[0]),
      .up_alg   (up_chreg[1]),
      .up_pms   (up_chreg[2]),

      // operator updates
      .din       (op_din),
      .up_keyon  (up_keyon),
      .up_dt1    (up_opreg[0]),
      .up_tl     (up_opreg[1]),
      .up_ks_ar  (up_opreg[2]),
      .up_amen_dr(up_opreg[3]),
      .up_sr     (up_opreg[4]),
      .up_sl_rr  (up_opreg[5]),
      .up_ssgeg  (up_opreg[6]),

      .op(up_op),  // operator to update
      .ch(up_ch),  // channel to update

      .csm       (csm),
      .flag_A    (flag_A),
      .overflow_A(overflow_A),

      .ch6op         (ch6op),
      .cur_ch        (cur_ch),
      .cur_op        (cur_op),
      // CH3 Effect-mode operation
      .effect        (effect),          // allows independent freq. for CH 3
      .fnum_ch3op2   (fnum_ch3op2),
      .fnum_ch3op3   (fnum_ch3op3),
      .fnum_ch3op1   (fnum_ch3op1),
      .block_ch3op2  (block_ch3op2),
      .block_ch3op3  (block_ch3op3),
      .block_ch3op1  (block_ch3op1),
      .latch_fnum    (latch_fnum),
      // Operator
      .xuse_prevprev1(xuse_prevprev1),
      .xuse_internal (xuse_internal),
      .yuse_internal (yuse_internal),
      .xuse_prev2    (xuse_prev2),
      .yuse_prev1    (yuse_prev1),
      .yuse_prev2    (yuse_prev2),
      // PG
      .fnum_I        (fnum_I),
      .block_I       (block_I),
      .mul_II        (mul_II),
      .dt1_I         (dt1_I),

      // EG
      .ar_I    (ar_I),      // attack  rate
      .d1r_I   (d1r_I),     // decay   rate
      .d2r_I   (d2r_I),     // sustain rate
      .rr_I    (rr_I),      // release rate
      .sl_I    (sl_I),      // sustain level
      .ks_II   (ks_II),     // key scale
      // SSG operation
      .ssg_en_I(ssg_en_I),
      .ssg_eg_I(ssg_eg_I),
      // envelope number
      .tl_IV   (tl_IV),
      .pms_I   (pms_I),
      .ams_IV  (ams_IV),
      .amsen_IV(amsen_IV),
      // channel configuration
      .rl      (rl),
      .fb_II   (fb_II),
      .alg_I   (alg_I),
      .keyon_I (keyon_I),

      .zero                   (zero),
      .s1_enters              (s1_enters),
      .s2_enters              (s2_enters),
      .s3_enters              (s3_enters),
      .s4_enters              (s4_enters),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_reg_data_out),
      .auto_ss_ack            (auto_ss_u_reg_ack)

  );

endmodule


///////////////////////////////////////////
// MODULE jt12_timer
module jt12_timer #(
    parameter CW      = 8,  // counter bit width. This is the counter that can be loaded
              FW      = 4,  // number of bits for the free-running counter
              FREE_EN = 0   // enables a 4-bit free enable count
) (
    input                 rst,
    input                 clk,
    input                 cen,
    input                 zero,
    input        [CW-1:0] start_value,
    input                 load,
    input                 clr_flag,
    output reg            flag,
    output reg            overflow,
    input                 auto_ss_rd,
    input                 auto_ss_wr,
    input        [  31:0] auto_ss_data_in,
    input        [   7:0] auto_ss_device_idx,
    input        [  15:0] auto_ss_state_idx,
    input        [   7:0] auto_ss_base_device_idx,
    output logic [  31:0] auto_ss_data_out,
    output logic          auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;

  /* verilator lint_off WIDTH */
  reg load_l;
  reg [CW-1:0] cnt, next;
  reg [FW-1:0] free_cnt, free_next;
  reg free_ov;

  always @(posedge clk, posedge rst)
    if (rst) flag <= 1'b0;
    else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          flag <= auto_ss_data_in[0];
        end
        default: begin
        end
      endcase
    end else  /*if(cen)*/ begin
      if (clr_flag) flag <= 1'b0;
      else if (cen && zero && load && overflow) flag <= 1'b1;
    end

  always @(*) begin
    {free_ov, free_next} = {1'b0, free_cnt} + 1'b1;
    {overflow, next}     = {1'b0, cnt} + (FREE_EN ? free_ov : 1'b1);
  end

  always @(posedge clk) begin
    begin
      load_l <= load;
      if (!load_l && load) begin
        cnt <= start_value;
      end else if (cen && zero && load) cnt <= overflow ? start_value : next;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          load_l <= auto_ss_data_in[1];
        end
        default: begin
        end
      endcase
    end
  end



  // Free running counter
  always @(posedge clk) begin
    begin
      if (rst) begin
        free_cnt <= 0;
      end else if (cen && zero) begin
        free_cnt <= free_next;
      end
    end
    if (auto_ss_wr && device_match) begin
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[1:0] = {load_l, flag};
          auto_ss_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end


  /* verilator lint_on WIDTH */
endmodule


///////////////////////////////////////////
// MODULE jt12_timers
module jt12_timers (
    input               clk,
    input               rst,
    input               clk_en  /* synthesis direct_enable */,
    input               zero,
    input        [ 9:0] value_A,
    input        [ 7:0] value_B,
    input               load_A,
    input               load_B,
    input               clr_flag_A,
    input               clr_flag_B,
    input               enable_irq_A,
    input               enable_irq_B,
    output              flag_A,
    output              flag_B,
    output              overflow_A,
    output              irq_n,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_timer_A_ack | auto_ss_timer_B_ack;

  assign auto_ss_data_out = auto_ss_timer_A_data_out | auto_ss_timer_B_data_out;

  wire        auto_ss_timer_B_ack;

  wire [31:0] auto_ss_timer_B_data_out;

  wire        auto_ss_timer_A_ack;

  wire [31:0] auto_ss_timer_A_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;

  assign irq_n = ~((flag_A & enable_irq_A) | (flag_B & enable_irq_B));

  /*
reg zero2;

always @(posedge clk, posedge rst) begin
    if( rst )
        zero2 <= 0;
    else if(clk_en) begin
        if( zero ) zero2 <= ~zero;
    end
end

wire zero       = num_ch == 6 ? zero : (zero2&zero);
*/
  jt12_timer #(
      .CW(10)
  ) timer_A (
      .clk                    (clk),
      .rst                    (rst),
      .cen                    (clk_en),
      .zero                   (zero),
      .start_value            (value_A),
      .load                   (load_A),
      .clr_flag               (clr_flag_A),
      .flag                   (flag_A),
      .overflow               (overflow_A),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_timer_A_data_out),
      .auto_ss_ack            (auto_ss_timer_A_ack)

  );

  jt12_timer #(
      .CW     (8),
      .FREE_EN(1)
  ) timer_B (
      .clk                    (clk),
      .rst                    (rst),
      .cen                    (clk_en),
      .zero                   (zero),
      .start_value            (value_B),
      .load                   (load_B),
      .clr_flag               (clr_flag_B),
      .flag                   (flag_B),
      .overflow               (),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_timer_B_data_out),
      .auto_ss_ack            (auto_ss_timer_B_ack)

  );

endmodule


///////////////////////////////////////////
// MODULE jt12_pm
module jt12_pm (
    input             [ 4:0] lfo_mod,
    input             [10:0] fnum,
    input             [ 2:0] pms,
    output reg signed [ 8:0] pm_offset
);


  reg  [7:0] pm_unsigned;
  reg  [7:0] pm_base;
  reg  [9:0] pm_shifted;

  wire [2:0] index = lfo_mod[3] ? (~lfo_mod[2:0]) : lfo_mod[2:0];

  reg  [2:0] lfo_sh1_lut                                         [0:63];
  reg  [2:0] lfo_sh2_lut                                         [0:63];
  reg [2:0] lfo_sh1, lfo_sh2;

  initial begin
    lfo_sh1_lut[6'h00] = 3'd7;
    lfo_sh1_lut[6'h01] = 3'd7;
    lfo_sh1_lut[6'h02] = 3'd7;
    lfo_sh1_lut[6'h03] = 3'd7;
    lfo_sh1_lut[6'h04] = 3'd7;
    lfo_sh1_lut[6'h05] = 3'd7;
    lfo_sh1_lut[6'h06] = 3'd7;
    lfo_sh1_lut[6'h07] = 3'd7;
    lfo_sh1_lut[6'h08] = 3'd7;
    lfo_sh1_lut[6'h09] = 3'd7;
    lfo_sh1_lut[6'h0A] = 3'd7;
    lfo_sh1_lut[6'h0B] = 3'd7;
    lfo_sh1_lut[6'h0C] = 3'd7;
    lfo_sh1_lut[6'h0D] = 3'd7;
    lfo_sh1_lut[6'h0E] = 3'd7;
    lfo_sh1_lut[6'h0F] = 3'd7;
    lfo_sh1_lut[6'h10] = 3'd7;
    lfo_sh1_lut[6'h11] = 3'd7;
    lfo_sh1_lut[6'h12] = 3'd7;
    lfo_sh1_lut[6'h13] = 3'd7;
    lfo_sh1_lut[6'h14] = 3'd7;
    lfo_sh1_lut[6'h15] = 3'd7;
    lfo_sh1_lut[6'h16] = 3'd1;
    lfo_sh1_lut[6'h17] = 3'd1;
    lfo_sh1_lut[6'h18] = 3'd7;
    lfo_sh1_lut[6'h19] = 3'd7;
    lfo_sh1_lut[6'h1A] = 3'd7;
    lfo_sh1_lut[6'h1B] = 3'd7;
    lfo_sh1_lut[6'h1C] = 3'd1;
    lfo_sh1_lut[6'h1D] = 3'd1;
    lfo_sh1_lut[6'h1E] = 3'd1;
    lfo_sh1_lut[6'h1F] = 3'd1;
    lfo_sh1_lut[6'h20] = 3'd7;
    lfo_sh1_lut[6'h21] = 3'd7;
    lfo_sh1_lut[6'h22] = 3'd7;
    lfo_sh1_lut[6'h23] = 3'd1;
    lfo_sh1_lut[6'h24] = 3'd1;
    lfo_sh1_lut[6'h25] = 3'd1;
    lfo_sh1_lut[6'h26] = 3'd1;
    lfo_sh1_lut[6'h27] = 3'd0;
    lfo_sh1_lut[6'h28] = 3'd7;
    lfo_sh1_lut[6'h29] = 3'd7;
    lfo_sh1_lut[6'h2A] = 3'd1;
    lfo_sh1_lut[6'h2B] = 3'd1;
    lfo_sh1_lut[6'h2C] = 3'd0;
    lfo_sh1_lut[6'h2D] = 3'd0;
    lfo_sh1_lut[6'h2E] = 3'd0;
    lfo_sh1_lut[6'h2F] = 3'd0;
    lfo_sh1_lut[6'h30] = 3'd7;
    lfo_sh1_lut[6'h31] = 3'd7;
    lfo_sh1_lut[6'h32] = 3'd1;
    lfo_sh1_lut[6'h33] = 3'd1;
    lfo_sh1_lut[6'h34] = 3'd0;
    lfo_sh1_lut[6'h35] = 3'd0;
    lfo_sh1_lut[6'h36] = 3'd0;
    lfo_sh1_lut[6'h37] = 3'd0;
    lfo_sh1_lut[6'h38] = 3'd7;
    lfo_sh1_lut[6'h39] = 3'd7;
    lfo_sh1_lut[6'h3A] = 3'd1;
    lfo_sh1_lut[6'h3B] = 3'd1;
    lfo_sh1_lut[6'h3C] = 3'd0;
    lfo_sh1_lut[6'h3D] = 3'd0;
    lfo_sh1_lut[6'h3E] = 3'd0;
    lfo_sh1_lut[6'h3F] = 3'd0;
    lfo_sh2_lut[6'h00] = 3'd7;
    lfo_sh2_lut[6'h01] = 3'd7;
    lfo_sh2_lut[6'h02] = 3'd7;
    lfo_sh2_lut[6'h03] = 3'd7;
    lfo_sh2_lut[6'h04] = 3'd7;
    lfo_sh2_lut[6'h05] = 3'd7;
    lfo_sh2_lut[6'h06] = 3'd7;
    lfo_sh2_lut[6'h07] = 3'd7;
    lfo_sh2_lut[6'h08] = 3'd7;
    lfo_sh2_lut[6'h09] = 3'd7;
    lfo_sh2_lut[6'h0A] = 3'd7;
    lfo_sh2_lut[6'h0B] = 3'd7;
    lfo_sh2_lut[6'h0C] = 3'd2;
    lfo_sh2_lut[6'h0D] = 3'd2;
    lfo_sh2_lut[6'h0E] = 3'd2;
    lfo_sh2_lut[6'h0F] = 3'd2;
    lfo_sh2_lut[6'h10] = 3'd7;
    lfo_sh2_lut[6'h11] = 3'd7;
    lfo_sh2_lut[6'h12] = 3'd7;
    lfo_sh2_lut[6'h13] = 3'd2;
    lfo_sh2_lut[6'h14] = 3'd2;
    lfo_sh2_lut[6'h15] = 3'd2;
    lfo_sh2_lut[6'h16] = 3'd7;
    lfo_sh2_lut[6'h17] = 3'd7;
    lfo_sh2_lut[6'h18] = 3'd7;
    lfo_sh2_lut[6'h19] = 3'd7;
    lfo_sh2_lut[6'h1A] = 3'd2;
    lfo_sh2_lut[6'h1B] = 3'd2;
    lfo_sh2_lut[6'h1C] = 3'd7;
    lfo_sh2_lut[6'h1D] = 3'd7;
    lfo_sh2_lut[6'h1E] = 3'd2;
    lfo_sh2_lut[6'h1F] = 3'd2;
    lfo_sh2_lut[6'h20] = 3'd7;
    lfo_sh2_lut[6'h21] = 3'd7;
    lfo_sh2_lut[6'h22] = 3'd2;
    lfo_sh2_lut[6'h23] = 3'd7;
    lfo_sh2_lut[6'h24] = 3'd7;
    lfo_sh2_lut[6'h25] = 3'd7;
    lfo_sh2_lut[6'h26] = 3'd2;
    lfo_sh2_lut[6'h27] = 3'd7;
    lfo_sh2_lut[6'h28] = 3'd7;
    lfo_sh2_lut[6'h29] = 3'd7;
    lfo_sh2_lut[6'h2A] = 3'd7;
    lfo_sh2_lut[6'h2B] = 3'd2;
    lfo_sh2_lut[6'h2C] = 3'd7;
    lfo_sh2_lut[6'h2D] = 3'd7;
    lfo_sh2_lut[6'h2E] = 3'd2;
    lfo_sh2_lut[6'h2F] = 3'd1;
    lfo_sh2_lut[6'h30] = 3'd7;
    lfo_sh2_lut[6'h31] = 3'd7;
    lfo_sh2_lut[6'h32] = 3'd7;
    lfo_sh2_lut[6'h33] = 3'd2;
    lfo_sh2_lut[6'h34] = 3'd7;
    lfo_sh2_lut[6'h35] = 3'd7;
    lfo_sh2_lut[6'h36] = 3'd2;
    lfo_sh2_lut[6'h37] = 3'd1;
    lfo_sh2_lut[6'h38] = 3'd7;
    lfo_sh2_lut[6'h39] = 3'd7;
    lfo_sh2_lut[6'h3A] = 3'd7;
    lfo_sh2_lut[6'h3B] = 3'd2;
    lfo_sh2_lut[6'h3C] = 3'd7;
    lfo_sh2_lut[6'h3D] = 3'd7;
    lfo_sh2_lut[6'h3E] = 3'd2;
    lfo_sh2_lut[6'h3F] = 3'd1;
  end

  always @(*) begin
    lfo_sh1 = lfo_sh1_lut[{pms, index}];
    lfo_sh2 = lfo_sh2_lut[{pms, index}];
    pm_base = ({1'b0, fnum[10:4]} >> lfo_sh1) + ({1'b0, fnum[10:4]} >> lfo_sh2);
    case (pms)
      default: pm_shifted = {2'b0, pm_base};
      3'd6:    pm_shifted = {1'b0, pm_base, 1'b0};
      3'd7:    pm_shifted = {pm_base, 2'b0};
    endcase  // pms
    pm_offset = lfo_mod[4] ? (-{1'b0, pm_shifted[9:2]}) : {1'b0, pm_shifted[9:2]};
  end  // always @(*)

endmodule


///////////////////////////////////////////
// MODULE jt12_pg_dt
module jt12_pg_dt (
    input [ 2:0] block,
    input [10:0] fnum,
    input [ 2:0] detune,

    output reg        [4:0] keycode,
    output reg signed [5:0] detune_signed
);

  reg [5:0] detune_kf;
  reg [4:0] pow2;
  reg [5:0] detune_unlimited;
  reg [4:0] detune_limit, detune_limited;


  always @(*) begin
    keycode = {block, fnum[10], fnum[10] ? (|fnum[9:7]) : (&fnum[9:7])};
    case (detune[1:0])
      2'd1: detune_kf = {1'b0, keycode} - 6'd4;
      2'd2: detune_kf = {1'b0, keycode} + 6'd4;
      2'd3: detune_kf = {1'b0, keycode} + 6'd8;
      default: detune_kf = {1'b0, keycode};
    endcase
    case (detune_kf[2:0])
      3'd0: pow2 = 5'd16;
      3'd1: pow2 = 5'd17;
      3'd2: pow2 = 5'd19;
      3'd3: pow2 = 5'd20;
      3'd4: pow2 = 5'd22;
      3'd5: pow2 = 5'd24;
      3'd6: pow2 = 5'd26;
      3'd7: pow2 = 5'd29;
    endcase
    case (detune[1:0])
      2'd0: detune_limit = 5'd0;
      2'd1: detune_limit = 5'd8;
      2'd2: detune_limit = 5'd16;
      2'd3: detune_limit = 5'd22;
    endcase
    case (detune_kf[5:3])
      3'd0:   detune_unlimited = { 5'd0, pow2[4]   }; // <2
      3'd1:   detune_unlimited = { 4'd0, pow2[4:3] }; // <4
      3'd2:   detune_unlimited = { 3'd0, pow2[4:2] }; // <8
      3'd3:   detune_unlimited = { 2'd0, pow2[4:1] };
      3'd4:   detune_unlimited = { 1'd0, pow2[4:0] };
      3'd5:   detune_unlimited = { pow2[4:0], 1'd0 };
      default:detune_unlimited = 6'd0;
    endcase
    detune_limited = detune_unlimited > {1'b0, detune_limit} ? detune_limit : detune_unlimited[4:0];
    detune_signed = !detune[2] ? {1'b0, detune_limited} : (~{1'b0, detune_limited} + 6'd1);
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_pg_inc
module jt12_pg_inc (
    input         [ 2:0] block,
    input         [10:0] fnum,
    input  signed [ 8:0] pm_offset,
    output reg    [16:0] phinc_pure
);

  reg [11:0] fnum_mod;

  always @(*) begin
    fnum_mod = {fnum, 1'b0} + {{3{pm_offset[8]}}, pm_offset};
    case (block)
      3'd0: phinc_pure = {7'd0, fnum_mod[11:2]};
      3'd1: phinc_pure = {6'd0, fnum_mod[11:1]};
      3'd2: phinc_pure = {5'd0, fnum_mod[11:0]};
      3'd3: phinc_pure = {4'd0, fnum_mod, 1'd0};
      3'd4: phinc_pure = {3'd0, fnum_mod, 2'd0};
      3'd5: phinc_pure = {2'd0, fnum_mod, 3'd0};
      3'd6: phinc_pure = {1'd0, fnum_mod, 4'd0};
      3'd7: phinc_pure = {fnum_mod, 5'd0};
    endcase
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_pg_sum
module jt12_pg_sum (
    input        [ 3:0] mul,
    input        [19:0] phase_in,
    input               pg_rst,
    input signed [ 5:0] detune_signed,
    input        [16:0] phinc_pure,

    output reg [19:0] phase_out,
    output reg [ 9:0] phase_op
);

  reg [16:0] phinc_premul;
  reg [19:0] phinc_mul;

  always @(*) begin
    phinc_premul = phinc_pure + {{11{detune_signed[5]}}, detune_signed};
    phinc_mul    = (mul == 4'd0) ? {4'b0, phinc_premul[16:1]} : ({3'd0, phinc_premul} * mul);

    phase_out    = pg_rst ? 20'd0 : (phase_in + {phinc_mul});
    phase_op     = phase_out[19:10];
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_pg_comb
module jt12_pg_comb (
    input [ 2:0] block,
    input [10:0] fnum,
    // Phase Modulation
    input [ 4:0] lfo_mod,
    input [ 2:0] pms,
    // output       [ 7:0]  pm_out,

    // Detune
    input [2:0] detune,

    output        [ 4:0] keycode,
    output signed [ 5:0] detune_out,
    // Phase increment  
    output        [16:0] phinc_out,
    // Phase add
    input         [ 3:0] mul,
    input         [19:0] phase_in,
    input                pg_rst,
    // input signed [7:0]   pm_in,
    input  signed [ 5:0] detune_in,
    input         [16:0] phinc_in,

    output [19:0] phase_out,
    output [ 9:0] phase_op
);

  wire signed [8:0] pm_offset;

  /*  pm, pg_dt and pg_inc operate in parallel */
  jt12_pm u_pm (
      .lfo_mod  (lfo_mod),
      .fnum     (fnum),
      .pms      (pms),
      .pm_offset(pm_offset)
  );

  jt12_pg_dt u_dt (
      .block        (block),
      .fnum         (fnum),
      .detune       (detune),
      .keycode      (keycode),
      .detune_signed(detune_out)
  );

  jt12_pg_inc u_inc (
      .block     (block),
      .fnum      (fnum),
      .pm_offset (pm_offset),
      .phinc_pure(phinc_out)
  );

  // pg_sum uses the output from the previous blocks

  jt12_pg_sum u_sum (
      .mul          (mul),
      .phase_in     (phase_in),
      .pg_rst       (pg_rst),
      .detune_signed(detune_in),
      .phinc_pure   (phinc_in),
      .phase_out    (phase_out),
      .phase_op     (phase_op)
  );

endmodule


///////////////////////////////////////////
// MODULE jt12_pg
module jt12_pg (
    input        clk,
    input        clk_en  /* synthesis direct_enable */,
    input        rst,
    // Channel frequency
    input [10:0] fnum_I,
    input [ 2:0] block_I,
    // Operator multiplying
    input [ 3:0] mul_II,
    // Operator detuning
    input [ 2:0] dt1_I,                                  // same as JT51's DT1
    // phase modulation from LFO
    input [ 6:0] lfo_mod,
    input [ 2:0] pms_I,
    // phase operation
    input        pg_rst_II,
    input        pg_stop,                                // not implemented

    output reg   [ 4:0] keycode_II,
    output       [ 9:0] phase_VIII,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_phsh_ack | auto_ss_u_pad_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_phsh_data_out | auto_ss_u_pad_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_pad_ack;

  wire  [31:0] auto_ss_u_pad_data_out;

  wire         auto_ss_u_phsh_ack;

  wire  [31:0] auto_ss_u_phsh_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;

  wire        [ 4:0] keycode_I;
  wire signed [ 5:0] detune_mod_I;
  reg signed  [ 5:0] detune_mod_II;
  wire        [16:0] phinc_I;
  reg         [16:0] phinc_II;
  wire [19:0] phase_drop, phase_in;
  wire [9:0] phase_II;

  always @(posedge clk) begin
    if (clk_en) begin
      keycode_II    <= keycode_I;
      detune_mod_II <= detune_mod_I;
      phinc_II      <= phinc_I;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          phinc_II      <= auto_ss_data_in[16:0];
          detune_mod_II <= auto_ss_data_in[22:17];
          keycode_II    <= auto_ss_data_in[27:23];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[27:0] = {keycode_II, detune_mod_II, phinc_II};
          auto_ss_local_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt12_pg_comb u_comb (
      .block  (block_I),
      .fnum   (fnum_I),
      // Phase Modulation
      .lfo_mod(lfo_mod[6:2]),
      .pms    (pms_I),

      // Detune
      .detune    (dt1_I),
      .keycode   (keycode_I),
      .detune_out(detune_mod_I),
      // Phase increment  
      .phinc_out (phinc_I),
      // Phase add
      .mul       (mul_II),
      .phase_in  (phase_drop),
      .pg_rst    (pg_rst_II),
      .detune_in (detune_mod_II),
      .phinc_in  (phinc_II),

      .phase_out(phase_in),
      .phase_op (phase_II)
  );

  jt12_sh_rst #(
      .width (20),
      .stages(4 * num_ch)
  ) u_phsh (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (phase_in),
      .drop                   (phase_drop),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_phsh_data_out),
      .auto_ss_ack            (auto_ss_u_phsh_ack)

  );

  jt12_sh_rst #(
      .width (10),
      .stages(6)
  ) u_pad (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (phase_II),
      .drop                   (phase_VIII),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_pad_data_out),
      .auto_ss_ack            (auto_ss_u_pad_ack)

  );

endmodule


///////////////////////////////////////////
// MODULE jt12_eg_cnt
module jt12_eg_cnt (
    input               rst,
    input               clk,
    input               clk_en  /* synthesis direct_enable */,
    input               zero,
    output reg   [14:0] eg_cnt,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [1:0] eg_cnt_base;

  always @(posedge clk, posedge rst) begin : envelope_counter
    if (rst) begin
      eg_cnt_base <= 2'd0;
      eg_cnt      <= 15'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          eg_cnt      <= auto_ss_data_in[14:0];
          eg_cnt_base <= auto_ss_data_in[16:15];
        end
        default: begin
        end
      endcase
    end else begin
      if (zero && clk_en) begin
        // envelope counter increases every 3 output samples,
        // there is one sample every 24 clock ticks
        if (eg_cnt_base == 2'd2) begin
          eg_cnt      <= eg_cnt + 1'b1;
          eg_cnt_base <= 2'd0;
        end else eg_cnt_base <= eg_cnt_base + 1'b1;
      end
    end
  end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[16:0] = {eg_cnt_base, eg_cnt};
          auto_ss_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_eg_ctrl
module jt12_eg_ctrl (
    input            keyon_now,
    input            keyoff_now,
    input      [2:0] state_in,
    input      [9:0] eg,
    // envelope configuration
    input      [4:0] arate,       // attack  rate
    input      [4:0] rate1,       // decay   rate
    input      [4:0] rate2,       // sustain rate
    input      [3:0] rrate,
    input      [3:0] sl,          // sustain level
    // SSG operation
    input            ssg_en,
    input      [2:0] ssg_eg,
    // SSG output inversion
    input            ssg_inv_in,
    output reg       ssg_inv_out,

    output reg [4:0] base_rate,
    output reg [2:0] state_next,
    output reg       pg_rst
);

  localparam 	ATTACK = 3'b001,
			DECAY  = 3'b010,
			HOLD   = 3'b100,
			RELEASE= 3'b000; // default state is release

  // wire is_decaying = state_in[1] | state_in[2];

  reg [4:0] sustain;

  always @(*)
    if (sl == 4'd15) sustain = 5'h1f;  // 93dB
    else sustain = {1'b0, sl};

  wire ssg_en_out;
  reg ssg_en_in, ssg_pg_rst;

  // aliases
  wire ssg_att = ssg_eg[2];
  wire ssg_alt = ssg_eg[1];
  wire ssg_hold = ssg_eg[0] & ssg_en;

  reg  ssg_over;


  always @(*) begin
    ssg_over   = ssg_en && eg[9];  // eg >=10'h200
    ssg_pg_rst = ssg_over && !(ssg_alt || ssg_hold);
    pg_rst     = keyon_now | ssg_pg_rst;
  end

  always @(*)
    casez ({
      keyoff_now, keyon_now, state_in
    })
      5'b01_???: begin  // key on
        base_rate   = arate;
        state_next  = ATTACK;
        ssg_inv_out = ssg_att & ssg_en;
      end
      {
        2'b00, ATTACK
      } :
      if (eg == 10'd0) begin
        base_rate   = rate1;
        state_next  = DECAY;
        ssg_inv_out = ssg_inv_in;
      end else begin
        base_rate   = arate;
        state_next  = ATTACK;
        ssg_inv_out = ssg_inv_in;
      end
      {
        2'b00, DECAY
      } : begin
        if (ssg_over) begin
          base_rate   = ssg_hold ? 5'd0 : arate;
          state_next  = ssg_hold ? HOLD : ATTACK;
          ssg_inv_out = ssg_en & (ssg_alt ^ ssg_inv_in);
        end else begin
          base_rate   = eg[9:5] >= sustain ? rate2 : rate1;  // equal comparison according to Nuke
          state_next  = DECAY;
          ssg_inv_out = ssg_inv_in;
        end
      end
      {
        2'b00, HOLD
      } : begin
        base_rate   = 5'd0;
        state_next  = HOLD;
        ssg_inv_out = ssg_inv_in;
      end
      default: begin  // RELEASE, note that keyoff_now==1 will enter this state too
        base_rate   = {rrate, 1'b1};
        state_next  = RELEASE;  // release
        ssg_inv_out = 1'b0;  // this can produce a glitch in the output
        // But to release from SSG cannot be done nicely while
        // inverting the ouput
      end
    endcase


endmodule


///////////////////////////////////////////
// MODULE jt12_eg_step
module jt12_eg_step (
    input             attack,
    input      [ 4:0] base_rate,
    input      [ 4:0] keycode,
    input      [14:0] eg_cnt,
    input             cnt_in,
    input      [ 1:0] ks,
    output            cnt_lsb,
    output reg        step,
    output reg [ 5:0] rate,
    output reg        sum_up
);

  reg [6:0] pre_rate;

  always @(*) begin : pre_rate_calc
    if (base_rate == 5'd0) pre_rate = 7'd0;
    else
      case (ks)
        2'd3: pre_rate = {base_rate, 1'b0} + {1'b0, keycode};
        2'd2: pre_rate = {base_rate, 1'b0} + {2'b0, keycode[4:1]};
        2'd1: pre_rate = {base_rate, 1'b0} + {3'b0, keycode[4:2]};
        2'd0: pre_rate = {base_rate, 1'b0} + {4'b0, keycode[4:3]};
      endcase
  end

  always @(*) rate = pre_rate[6] ? 6'd63 : pre_rate[5:0];

  reg [2:0] cnt;

  reg [4:0] mux_sel;
  always @(*) begin
    mux_sel = attack ? (rate[5:2] + 4'd1) : {1'b0, rate[5:2]};
  end  // always @(*)

  always @(*)
    case (mux_sel)
      5'h0: cnt = eg_cnt[14:12];
      5'h1: cnt = eg_cnt[13:11];
      5'h2: cnt = eg_cnt[12:10];
      5'h3: cnt = eg_cnt[11:9];
      5'h4: cnt = eg_cnt[10:8];
      5'h5: cnt = eg_cnt[9:7];
      5'h6: cnt = eg_cnt[8:6];
      5'h7: cnt = eg_cnt[7:5];
      5'h8: cnt = eg_cnt[6:4];
      5'h9: cnt = eg_cnt[5:3];
      5'ha: cnt = eg_cnt[4:2];
      5'hb: cnt = eg_cnt[3:1];
      default: cnt = eg_cnt[2:0];
    endcase

  ////////////////////////////////
  reg [7:0] step_idx;

  always @(*) begin : rate_step
    if (rate[5:4] == 2'b11) begin  // 0 means 1x, 1 means 2x
      if (rate[5:2] == 4'hf && attack) step_idx = 8'b11111111;  // Maximum attack speed, rates 60&61
      else
        case (rate[1:0])
          2'd0: step_idx = 8'b00000000;
          2'd1: step_idx = 8'b10001000;  // 2
          2'd2: step_idx = 8'b10101010;  // 4
          2'd3: step_idx = 8'b11101110;  // 6
        endcase
    end else begin
      if (rate[5:2] == 4'd0 && !attack) step_idx = 8'b11111110;  // limit slowest decay rate
      else
        case (rate[1:0])
          2'd0: step_idx = 8'b10101010;  // 4
          2'd1: step_idx = 8'b11101010;  // 5
          2'd2: step_idx = 8'b11101110;  // 6
          2'd3: step_idx = 8'b11111110;  // 7
        endcase
    end
    // a rate of zero keeps the level still
    step = rate[5:1] == 5'd0 ? 1'b0 : step_idx[cnt];
  end

  assign cnt_lsb = cnt[0];
  always @(*) begin
    sum_up = cnt[0] != cnt_in;
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_eg_pure
module jt12_eg_pure (
    input            attack,
    input            step,
    input      [5:1] rate,
    input      [9:0] eg_in,
    input            ssg_en,
    input            sum_up,
    output reg [9:0] eg_pure
);

  reg [ 3:0] dr_sum;
  reg [ 9:0] dr_adj;
  reg [10:0] dr_result;

  always @(*) begin : dr_calculation
    case (rate[5:2])
      4'b1100: dr_sum = {2'b0, step, ~step};  // 12
      4'b1101: dr_sum = {1'b0, step, ~step, 1'b0};  // 13
      4'b1110: dr_sum = {step, ~step, 2'b0};  // 14
      4'b1111: dr_sum = 4'd8;  // 15
      default: dr_sum = {2'b0, step, 1'b0};
    endcase
    // Decay rate attenuation is multiplied by 4 for SSG operation
    dr_adj    = ssg_en ? {4'd0, dr_sum, 2'd0} : {6'd0, dr_sum};
    dr_result = dr_adj + eg_in;
  end

  reg [ 7:0] ar_sum0;
  reg [ 8:0] ar_sum1;
  reg [10:0] ar_result;
  reg [ 9:0] ar_sum;

  always @(*) begin : ar_calculation
    casez (rate[5:2])
      default: ar_sum0 = {2'd0, eg_in[9:4]};
      4'b1101: ar_sum0 = {1'd0, eg_in[9:3]};
      4'b111?: ar_sum0 = eg_in[9:2];
    endcase
    ar_sum1 = ar_sum0 + 9'd1;
    if (rate[5:4] == 2'b11) ar_sum = step ? {ar_sum1, 1'b0} : {1'b0, ar_sum1};
    else ar_sum = step ? {1'b0, ar_sum1} : 10'd0;
    ar_result = eg_in - ar_sum;
  end
  ///////////////////////////////////////////////////////////
  // rate not used below this point
  reg [9:0] eg_pre_fastar;  // pre fast attack rate
  always @(*) begin
    if (sum_up) begin
      if (attack) eg_pre_fastar = ar_result[10] ? 10'd0 : ar_result[9:0];
      else eg_pre_fastar = dr_result[10] ? 10'h3FF : dr_result[9:0];
    end else eg_pre_fastar = eg_in;
    eg_pure = (attack & rate[5:1] == 5'h1F) ? 10'd0 : eg_pre_fastar;
  end

endmodule


///////////////////////////////////////////
// MODULE jt12_eg_final
module jt12_eg_final (
    input      [6:0] lfo_mod,
    input            amsen,
    input      [1:0] ams,
    input      [6:0] tl,
    input      [9:0] eg_pure_in,
    input            ssg_inv,
    output reg [9:0] eg_limited
);

  reg [ 8:0] am_final;
  reg [11:0] sum_eg_tl;
  reg [11:0] sum_eg_tl_am;
  reg [ 5:0] am_inverted;
  reg [ 9:0] eg_pream;

  always @(*) begin
    am_inverted = lfo_mod[6] ? ~lfo_mod[5:0] : lfo_mod[5:0];
  end

  always @(*) begin
    casez ({
      amsen, ams
    })
      default: am_final = 9'd0;
      3'b1_01: am_final = {5'd0, am_inverted[5:2]};
      3'b1_10: am_final = {3'd0, am_inverted};
      3'b1_11: am_final = {2'd0, am_inverted, 1'b0};
    endcase
    eg_pream = ssg_inv ? (10'h200 - eg_pure_in) : eg_pure_in;
    sum_eg_tl = {1'b0, tl, 3'd0} + {1'b0, eg_pream};  // leading zeros needed to compute correctly
    sum_eg_tl_am = sum_eg_tl + {3'd0, am_final};
  end

  always @(*) eg_limited = sum_eg_tl_am[11:10] == 2'd0 ? sum_eg_tl_am[9:0] : 10'h3ff;

endmodule


///////////////////////////////////////////
// MODULE jt12_eg_comb
module jt12_eg_comb (
    input        keyon_now,
    input        keyoff_now,
    input  [2:0] state_in,
    input  [9:0] eg_in,
    // envelope configuration   
    input  [4:0] arate,       // attack  rate
    input  [4:0] rate1,       // decay   rate
    input  [4:0] rate2,       // sustain rate
    input  [3:0] rrate,
    input  [3:0] sl,          // sustain level
    // SSG operation
    input        ssg_en,
    input  [2:0] ssg_eg,
    // SSG output inversion
    input        ssg_inv_in,
    output       ssg_inv_out,

    output [ 4:0] base_rate,
    output [ 2:0] state_next,
    output        pg_rst,
    ///////////////////////////////////
    // II
    input         step_attack,
    input  [ 4:0] step_rate_in,
    input  [ 4:0] keycode,
    input  [14:0] eg_cnt,
    input         cnt_in,
    input  [ 1:0] ks,
    output        cnt_lsb,
    output        step,
    output [ 5:0] step_rate_out,
    output        sum_up_out,
    ///////////////////////////////////
    // III
    input         pure_attack,
    input         pure_step,
    input  [ 5:1] pure_rate,
    input         pure_ssg_en,
    input  [ 9:0] pure_eg_in,
    output [ 9:0] pure_eg_out,
    input         sum_up_in,
    ///////////////////////////////////
    // IV
    input  [ 6:0] lfo_mod,
    input         amsen,
    input  [ 1:0] ams,
    input  [ 6:0] tl,
    input  [ 9:0] final_eg_in,
    input         final_ssg_inv,
    output [ 9:0] final_eg_out
);

  // I
  jt12_eg_ctrl u_ctrl (
      .keyon_now  (keyon_now),
      .keyoff_now (keyoff_now),
      .state_in   (state_in),
      .eg         (eg_in),
      // envelope configuration   
      .arate      (arate),       // attack  rate
      .rate1      (rate1),       // decay   rate
      .rate2      (rate2),       // sustain rate
      .rrate      (rrate),
      .sl         (sl),          // sustain level
      // SSG operation
      .ssg_en     (ssg_en),
      .ssg_eg     (ssg_eg),
      // SSG output inversion
      .ssg_inv_in (ssg_inv_in),
      .ssg_inv_out(ssg_inv_out),

      .base_rate (base_rate),
      .state_next(state_next),
      .pg_rst    (pg_rst)
  );

  // II

  jt12_eg_step u_step (
      .attack   (step_attack),
      .base_rate(step_rate_in),
      .keycode  (keycode),
      .eg_cnt   (eg_cnt),
      .cnt_in   (cnt_in),
      .ks       (ks),
      .cnt_lsb  (cnt_lsb),
      .step     (step),
      .rate     (step_rate_out),
      .sum_up   (sum_up_out)
  );

  // III

  wire [9:0] egin, egout;
  jt12_eg_pure u_pure (
      .attack (pure_attack),
      .step   (pure_step),
      .rate   (pure_rate),
      .ssg_en (pure_ssg_en),
      .eg_in  (pure_eg_in),
      .eg_pure(pure_eg_out),
      .sum_up (sum_up_in)
  );

  // IV

  jt12_eg_final u_final (
      .lfo_mod   (lfo_mod),
      .amsen     (amsen),
      .ams       (ams),
      .tl        (tl),
      .ssg_inv   (final_ssg_inv),
      .eg_pure_in(final_eg_in),
      .eg_limited(final_eg_out)
  );

endmodule


///////////////////////////////////////////
// MODULE jt12_sh
module jt12_sh #(
    parameter width  = 5,
              stages = 24
) (
    input                    clk,
    input                    clk_en  /* synthesis direct_enable */,
    input        [width-1:0] din,
    output       [width-1:0] drop,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input        [     31:0] auto_ss_data_in,
    input        [      7:0] auto_ss_device_idx,
    input        [     15:0] auto_ss_state_idx,
    input        [      7:0] auto_ss_base_device_idx,
    output logic [     31:0] auto_ss_data_out,
    output logic             auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [stages-1:0] bits[width-1:0];

  always @(posedge clk) begin
    begin
      if (clk_en) begin
        for (int i = 0; i < width; i = i + 1) begin
          bits[i] <= {bits[i][stages-2:0], din[i]};
        end
      end
    end
    if (auto_ss_wr && device_match) begin
      if (auto_ss_state_idx < (width)) begin
        bits[auto_ss_state_idx] <= auto_ss_data_in[stages-1:0];
      end
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      if (auto_ss_state_idx < (width)) begin
        auto_ss_data_out[stages-1:0] = bits[auto_ss_state_idx];
        auto_ss_ack                  = 1'b1;
      end
    end
  end




  genvar i;
  generate
    for (i = 0; i < width; i = i + 1) begin : bit_shifter
      assign drop[i] = bits[i][stages-1];
    end
  endgenerate

endmodule


///////////////////////////////////////////
// MODULE jt12_eg
module jt12_eg (
    input       rst,
    input       clk,
    input       clk_en  /* synthesis direct_enable */,
    input       zero,
    input       eg_stop,
    // envelope configuration
    input [4:0] keycode_II,
    input [4:0] arate_I,                                // attack  rate
    input [4:0] rate1_I,                                // decay   rate
    input [4:0] rate2_I,                                // sustain rate
    input [3:0] rrate_I,                                // release rate
    input [3:0] sl_I,                                   // sustain level
    input [1:0] ks_II,                                  // key scale
    // SSG operation
    input       ssg_en_I,
    input [2:0] ssg_eg_I,
    // envelope operation
    input       keyon_I,
    // envelope number
    input [6:0] lfo_mod,
    input       amsen_IV,
    input [1:0] ams_IV,
    input [6:0] tl_IV,

    output reg   [ 9:0] eg_V,
    output reg          pg_rst_II,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_egcnt_ack | auto_ss_u_cntsh_ack | auto_ss_u_egsh_ack | auto_ss_u_egstate_ack | auto_ss_u_ssg_inv_ack | auto_ss_u_konsh_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_egcnt_data_out | auto_ss_u_cntsh_data_out | auto_ss_u_egsh_data_out | auto_ss_u_egstate_data_out | auto_ss_u_ssg_inv_data_out | auto_ss_u_konsh_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_konsh_ack;

  wire  [31:0] auto_ss_u_konsh_data_out;

  wire         auto_ss_u_ssg_inv_ack;

  wire  [31:0] auto_ss_u_ssg_inv_data_out;

  wire         auto_ss_u_egstate_ack;

  wire  [31:0] auto_ss_u_egstate_data_out;

  wire         auto_ss_u_egsh_ack;

  wire  [31:0] auto_ss_u_egsh_data_out;

  wire         auto_ss_u_cntsh_ack;

  wire  [31:0] auto_ss_u_cntsh_data_out;

  wire         auto_ss_u_egcnt_ack;

  wire  [31:0] auto_ss_u_egcnt_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;

  wire [14:0] eg_cnt;

  jt12_eg_cnt u_egcnt (
      .rst                    (rst),
      .clk                    (clk),
      .clk_en                 (clk_en & ~eg_stop),
      .zero                   (zero),
      .eg_cnt                 (eg_cnt),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_egcnt_data_out),
      .auto_ss_ack            (auto_ss_u_egcnt_ack)

  );

  wire keyon_last_I;
  wire keyon_now_I = !keyon_last_I && keyon_I;
  wire keyoff_now_I = keyon_last_I && !keyon_I;

  wire cnt_in_II, cnt_lsb_II, step_II, pg_rst_I;

  wire ssg_inv_in_I, ssg_inv_out_I;
  reg ssg_inv_II, ssg_inv_III, ssg_inv_IV;
  wire [2:0] state_in_I, state_next_I;

  reg attack_II, attack_III;
  wire [4:0] base_rate_I;
  reg  [4:0] base_rate_II;
  wire [5:0] rate_out_II;
  reg  [5:1] rate_in_III;
  reg step_III, ssg_en_II, ssg_en_III;
  wire sum_out_II;
  reg  sum_in_III;

  wire [9:0] eg_in_I, pure_eg_out_III, eg_next_III, eg_out_IV;
  reg [9:0] eg_in_II, eg_in_III, eg_in_IV;



  jt12_eg_comb u_comb (
      ///////////////////////////////////
      // I
      .keyon_now  (keyon_now_I),
      .keyoff_now (keyoff_now_I),
      .state_in   (state_in_I),
      .eg_in      (eg_in_I),
      // envelope configuration   
      .arate      (arate_I),       // attack  rate
      .rate1      (rate1_I),       // decay   rate
      .rate2      (rate2_I),       // sustain rate
      .rrate      (rrate_I),
      .sl         (sl_I),          // sustain level
      // SSG operation
      .ssg_en     (ssg_en_I),
      .ssg_eg     (ssg_eg_I),
      // SSG output inversion
      .ssg_inv_in (ssg_inv_in_I),
      .ssg_inv_out(ssg_inv_out_I),

      .base_rate    (base_rate_I),
      .state_next   (state_next_I),
      .pg_rst       (pg_rst_I),
      ///////////////////////////////////
      // II
      .step_attack  (attack_II),
      .step_rate_in (base_rate_II),
      .keycode      (keycode_II),
      .eg_cnt       (eg_cnt),
      .cnt_in       (cnt_in_II),
      .ks           (ks_II),
      .cnt_lsb      (cnt_lsb_II),
      .step         (step_II),
      .step_rate_out(rate_out_II),
      .sum_up_out   (sum_out_II),
      ///////////////////////////////////
      // III
      .pure_attack  (attack_III),
      .pure_step    (step_III),
      .pure_rate    (rate_in_III[5:1]),
      .pure_ssg_en  (ssg_en_III),
      .pure_eg_in   (eg_in_III),
      .pure_eg_out  (pure_eg_out_III),
      .sum_up_in    (sum_in_III),
      ///////////////////////////////////
      // IV
      .lfo_mod      (lfo_mod),
      .amsen        (amsen_IV),
      .ams          (ams_IV),
      .tl           (tl_IV),
      .final_ssg_inv(ssg_inv_IV),
      .final_eg_in  (eg_in_IV),
      .final_eg_out (eg_out_IV)
  );

  always @(posedge clk) begin
    if (clk_en) begin
      eg_in_II     <= eg_in_I;
      attack_II    <= state_next_I[0];
      base_rate_II <= base_rate_I;
      ssg_en_II    <= ssg_en_I;
      ssg_inv_II   <= ssg_inv_out_I;
      pg_rst_II    <= pg_rst_I;

      eg_in_III    <= eg_in_II;
      attack_III   <= attack_II;
      rate_in_III  <= rate_out_II[5:1];
      ssg_en_III   <= ssg_en_II;
      ssg_inv_III  <= ssg_inv_II;
      step_III     <= step_II;
      sum_in_III   <= sum_out_II;

      ssg_inv_IV   <= ssg_inv_III;
      eg_in_IV     <= pure_eg_out_III;
      eg_V         <= eg_out_IV;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          eg_V      <= auto_ss_data_in[9:0];
          eg_in_II  <= auto_ss_data_in[19:10];
          eg_in_III <= auto_ss_data_in[29:20];
        end
        1: begin
          eg_in_IV     <= auto_ss_data_in[9:0];
          base_rate_II <= auto_ss_data_in[14:10];
          rate_in_III  <= auto_ss_data_in[19:15];
          attack_II    <= auto_ss_data_in[20];
          attack_III   <= auto_ss_data_in[21];
          pg_rst_II    <= auto_ss_data_in[22];
          ssg_en_II    <= auto_ss_data_in[23];
          ssg_en_III   <= auto_ss_data_in[24];
          ssg_inv_II   <= auto_ss_data_in[25];
          ssg_inv_III  <= auto_ss_data_in[26];
          ssg_inv_IV   <= auto_ss_data_in[27];
          step_III     <= auto_ss_data_in[28];
          sum_in_III   <= auto_ss_data_in[29];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[29:0] = {eg_in_III, eg_in_II, eg_V};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[29:0] = {
            sum_in_III,
            step_III,
            ssg_inv_IV,
            ssg_inv_III,
            ssg_inv_II,
            ssg_en_III,
            ssg_en_II,
            pg_rst_II,
            attack_III,
            attack_II,
            rate_in_III,
            base_rate_II,
            eg_in_IV
          };
          auto_ss_local_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt12_sh #(
      .width (1),
      .stages(4 * num_ch)
  ) u_cntsh (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (cnt_lsb_II),
      .drop                   (cnt_in_II),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_cntsh_data_out),
      .auto_ss_ack            (auto_ss_u_cntsh_ack)

  );

  jt12_sh_rst #(
      .width (10),
      .stages(4 * num_ch - 3),
      .rstval(1'b1)
  ) u_egsh (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (eg_in_IV),
      .drop                   (eg_in_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 3),
      .auto_ss_data_out       (auto_ss_u_egsh_data_out),
      .auto_ss_ack            (auto_ss_u_egsh_ack)

  );

  jt12_sh_rst #(
      .width (3),
      .stages(4 * num_ch),
      .rstval(1'b1)
  ) u_egstate (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (state_next_I),
      .drop                   (state_in_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 4),
      .auto_ss_data_out       (auto_ss_u_egstate_data_out),
      .auto_ss_ack            (auto_ss_u_egstate_ack)

  );

  jt12_sh_rst #(
      .width (1),
      .stages(4 * num_ch - 3),
      .rstval(1'b0)
  ) u_ssg_inv (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (ssg_inv_IV),
      .drop                   (ssg_inv_in_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
      .auto_ss_data_out       (auto_ss_u_ssg_inv_data_out),
      .auto_ss_ack            (auto_ss_u_ssg_inv_ack)

  );

  jt12_sh_rst #(
      .width (1),
      .stages(4 * num_ch),
      .rstval(1'b0)
  ) u_konsh (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .rst                    (rst),
      .din                    (keyon_I),
      .drop                   (keyon_last_I),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 6),
      .auto_ss_data_out       (auto_ss_u_konsh_data_out),
      .auto_ss_ack            (auto_ss_u_konsh_ack)

  );


endmodule


///////////////////////////////////////////
// MODULE jt12_logsin
module jt12_logsin (
    input        [ 7:0] addr,
    input               clk,
    input               clk_en,
    output reg   [11:0] logsin,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [11:0] sinelut[255:0];
  initial begin
    sinelut[8'd000] = 12'h000;
    sinelut[8'd001] = 12'h000;
    sinelut[8'd002] = 12'h000;
    sinelut[8'd003] = 12'h000;
    sinelut[8'd004] = 12'h000;
    sinelut[8'd005] = 12'h000;
    sinelut[8'd006] = 12'h000;
    sinelut[8'd007] = 12'h000;
    sinelut[8'd008] = 12'h001;
    sinelut[8'd009] = 12'h001;
    sinelut[8'd010] = 12'h001;
    sinelut[8'd011] = 12'h001;
    sinelut[8'd012] = 12'h001;
    sinelut[8'd013] = 12'h001;
    sinelut[8'd014] = 12'h001;
    sinelut[8'd015] = 12'h002;
    sinelut[8'd016] = 12'h002;
    sinelut[8'd017] = 12'h002;
    sinelut[8'd018] = 12'h002;
    sinelut[8'd019] = 12'h003;
    sinelut[8'd020] = 12'h003;
    sinelut[8'd021] = 12'h003;
    sinelut[8'd022] = 12'h004;
    sinelut[8'd023] = 12'h004;
    sinelut[8'd024] = 12'h004;
    sinelut[8'd025] = 12'h005;
    sinelut[8'd026] = 12'h005;
    sinelut[8'd027] = 12'h005;
    sinelut[8'd028] = 12'h006;
    sinelut[8'd029] = 12'h006;
    sinelut[8'd030] = 12'h007;
    sinelut[8'd031] = 12'h007;
    sinelut[8'd032] = 12'h007;
    sinelut[8'd033] = 12'h008;
    sinelut[8'd034] = 12'h008;
    sinelut[8'd035] = 12'h009;
    sinelut[8'd036] = 12'h009;
    sinelut[8'd037] = 12'h00a;
    sinelut[8'd038] = 12'h00a;
    sinelut[8'd039] = 12'h00b;
    sinelut[8'd040] = 12'h00c;
    sinelut[8'd041] = 12'h00c;
    sinelut[8'd042] = 12'h00d;
    sinelut[8'd043] = 12'h00d;
    sinelut[8'd044] = 12'h00e;
    sinelut[8'd045] = 12'h00f;
    sinelut[8'd046] = 12'h00f;
    sinelut[8'd047] = 12'h010;
    sinelut[8'd048] = 12'h011;
    sinelut[8'd049] = 12'h011;
    sinelut[8'd050] = 12'h012;
    sinelut[8'd051] = 12'h013;
    sinelut[8'd052] = 12'h014;
    sinelut[8'd053] = 12'h014;
    sinelut[8'd054] = 12'h015;
    sinelut[8'd055] = 12'h016;
    sinelut[8'd056] = 12'h017;
    sinelut[8'd057] = 12'h017;
    sinelut[8'd058] = 12'h018;
    sinelut[8'd059] = 12'h019;
    sinelut[8'd060] = 12'h01a;
    sinelut[8'd061] = 12'h01b;
    sinelut[8'd062] = 12'h01c;
    sinelut[8'd063] = 12'h01d;
    sinelut[8'd064] = 12'h01e;
    sinelut[8'd065] = 12'h01f;
    sinelut[8'd066] = 12'h020;
    sinelut[8'd067] = 12'h021;
    sinelut[8'd068] = 12'h022;
    sinelut[8'd069] = 12'h023;
    sinelut[8'd070] = 12'h024;
    sinelut[8'd071] = 12'h025;
    sinelut[8'd072] = 12'h026;
    sinelut[8'd073] = 12'h027;
    sinelut[8'd074] = 12'h028;
    sinelut[8'd075] = 12'h029;
    sinelut[8'd076] = 12'h02a;
    sinelut[8'd077] = 12'h02b;
    sinelut[8'd078] = 12'h02d;
    sinelut[8'd079] = 12'h02e;
    sinelut[8'd080] = 12'h02f;
    sinelut[8'd081] = 12'h030;
    sinelut[8'd082] = 12'h031;
    sinelut[8'd083] = 12'h033;
    sinelut[8'd084] = 12'h034;
    sinelut[8'd085] = 12'h035;
    sinelut[8'd086] = 12'h037;
    sinelut[8'd087] = 12'h038;
    sinelut[8'd088] = 12'h039;
    sinelut[8'd089] = 12'h03b;
    sinelut[8'd090] = 12'h03c;
    sinelut[8'd091] = 12'h03e;
    sinelut[8'd092] = 12'h03f;
    sinelut[8'd093] = 12'h040;
    sinelut[8'd094] = 12'h042;
    sinelut[8'd095] = 12'h043;
    sinelut[8'd096] = 12'h045;
    sinelut[8'd097] = 12'h046;
    sinelut[8'd098] = 12'h048;
    sinelut[8'd099] = 12'h04a;
    sinelut[8'd100] = 12'h04b;
    sinelut[8'd101] = 12'h04d;
    sinelut[8'd102] = 12'h04e;
    sinelut[8'd103] = 12'h050;
    sinelut[8'd104] = 12'h052;
    sinelut[8'd105] = 12'h053;
    sinelut[8'd106] = 12'h055;
    sinelut[8'd107] = 12'h057;
    sinelut[8'd108] = 12'h059;
    sinelut[8'd109] = 12'h05b;
    sinelut[8'd110] = 12'h05c;
    sinelut[8'd111] = 12'h05e;
    sinelut[8'd112] = 12'h060;
    sinelut[8'd113] = 12'h062;
    sinelut[8'd114] = 12'h064;
    sinelut[8'd115] = 12'h066;
    sinelut[8'd116] = 12'h068;
    sinelut[8'd117] = 12'h06a;
    sinelut[8'd118] = 12'h06c;
    sinelut[8'd119] = 12'h06e;
    sinelut[8'd120] = 12'h070;
    sinelut[8'd121] = 12'h072;
    sinelut[8'd122] = 12'h074;
    sinelut[8'd123] = 12'h076;
    sinelut[8'd124] = 12'h078;
    sinelut[8'd125] = 12'h07a;
    sinelut[8'd126] = 12'h07d;
    sinelut[8'd127] = 12'h07f;
    sinelut[8'd128] = 12'h081;
    sinelut[8'd129] = 12'h083;
    sinelut[8'd130] = 12'h086;
    sinelut[8'd131] = 12'h088;
    sinelut[8'd132] = 12'h08a;
    sinelut[8'd133] = 12'h08d;
    sinelut[8'd134] = 12'h08f;
    sinelut[8'd135] = 12'h092;
    sinelut[8'd136] = 12'h094;
    sinelut[8'd137] = 12'h097;
    sinelut[8'd138] = 12'h099;
    sinelut[8'd139] = 12'h09c;
    sinelut[8'd140] = 12'h09f;
    sinelut[8'd141] = 12'h0a1;
    sinelut[8'd142] = 12'h0a4;
    sinelut[8'd143] = 12'h0a7;
    sinelut[8'd144] = 12'h0a9;
    sinelut[8'd145] = 12'h0ac;
    sinelut[8'd146] = 12'h0af;
    sinelut[8'd147] = 12'h0b2;
    sinelut[8'd148] = 12'h0b5;
    sinelut[8'd149] = 12'h0b8;
    sinelut[8'd150] = 12'h0bb;
    sinelut[8'd151] = 12'h0be;
    sinelut[8'd152] = 12'h0c1;
    sinelut[8'd153] = 12'h0c4;
    sinelut[8'd154] = 12'h0c7;
    sinelut[8'd155] = 12'h0ca;
    sinelut[8'd156] = 12'h0cd;
    sinelut[8'd157] = 12'h0d1;
    sinelut[8'd158] = 12'h0d4;
    sinelut[8'd159] = 12'h0d7;
    sinelut[8'd160] = 12'h0db;
    sinelut[8'd161] = 12'h0de;
    sinelut[8'd162] = 12'h0e2;
    sinelut[8'd163] = 12'h0e5;
    sinelut[8'd164] = 12'h0e9;
    sinelut[8'd165] = 12'h0ec;
    sinelut[8'd166] = 12'h0f0;
    sinelut[8'd167] = 12'h0f4;
    sinelut[8'd168] = 12'h0f8;
    sinelut[8'd169] = 12'h0fb;
    sinelut[8'd170] = 12'h0ff;
    sinelut[8'd171] = 12'h103;
    sinelut[8'd172] = 12'h107;
    sinelut[8'd173] = 12'h10b;
    sinelut[8'd174] = 12'h10f;
    sinelut[8'd175] = 12'h114;
    sinelut[8'd176] = 12'h118;
    sinelut[8'd177] = 12'h11c;
    sinelut[8'd178] = 12'h121;
    sinelut[8'd179] = 12'h125;
    sinelut[8'd180] = 12'h129;
    sinelut[8'd181] = 12'h12e;
    sinelut[8'd182] = 12'h133;
    sinelut[8'd183] = 12'h137;
    sinelut[8'd184] = 12'h13c;
    sinelut[8'd185] = 12'h141;
    sinelut[8'd186] = 12'h146;
    sinelut[8'd187] = 12'h14b;
    sinelut[8'd188] = 12'h150;
    sinelut[8'd189] = 12'h155;
    sinelut[8'd190] = 12'h15b;
    sinelut[8'd191] = 12'h160;
    sinelut[8'd192] = 12'h166;
    sinelut[8'd193] = 12'h16b;
    sinelut[8'd194] = 12'h171;
    sinelut[8'd195] = 12'h177;
    sinelut[8'd196] = 12'h17c;
    sinelut[8'd197] = 12'h182;
    sinelut[8'd198] = 12'h188;
    sinelut[8'd199] = 12'h18f;
    sinelut[8'd200] = 12'h195;
    sinelut[8'd201] = 12'h19b;
    sinelut[8'd202] = 12'h1a2;
    sinelut[8'd203] = 12'h1a9;
    sinelut[8'd204] = 12'h1b0;
    sinelut[8'd205] = 12'h1b7;
    sinelut[8'd206] = 12'h1be;
    sinelut[8'd207] = 12'h1c5;
    sinelut[8'd208] = 12'h1cd;
    sinelut[8'd209] = 12'h1d4;
    sinelut[8'd210] = 12'h1dc;
    sinelut[8'd211] = 12'h1e4;
    sinelut[8'd212] = 12'h1ec;
    sinelut[8'd213] = 12'h1f5;
    sinelut[8'd214] = 12'h1fd;
    sinelut[8'd215] = 12'h206;
    sinelut[8'd216] = 12'h20f;
    sinelut[8'd217] = 12'h218;
    sinelut[8'd218] = 12'h222;
    sinelut[8'd219] = 12'h22c;
    sinelut[8'd220] = 12'h236;
    sinelut[8'd221] = 12'h240;
    sinelut[8'd222] = 12'h24b;
    sinelut[8'd223] = 12'h256;
    sinelut[8'd224] = 12'h261;
    sinelut[8'd225] = 12'h26d;
    sinelut[8'd226] = 12'h279;
    sinelut[8'd227] = 12'h286;
    sinelut[8'd228] = 12'h293;
    sinelut[8'd229] = 12'h2a0;
    sinelut[8'd230] = 12'h2af;
    sinelut[8'd231] = 12'h2bd;
    sinelut[8'd232] = 12'h2cd;
    sinelut[8'd233] = 12'h2dc;
    sinelut[8'd234] = 12'h2ed;
    sinelut[8'd235] = 12'h2ff;
    sinelut[8'd236] = 12'h311;
    sinelut[8'd237] = 12'h324;
    sinelut[8'd238] = 12'h339;
    sinelut[8'd239] = 12'h34e;
    sinelut[8'd240] = 12'h365;
    sinelut[8'd241] = 12'h37e;
    sinelut[8'd242] = 12'h398;
    sinelut[8'd243] = 12'h3b5;
    sinelut[8'd244] = 12'h3d3;
    sinelut[8'd245] = 12'h3f5;
    sinelut[8'd246] = 12'h41a;
    sinelut[8'd247] = 12'h443;
    sinelut[8'd248] = 12'h471;
    sinelut[8'd249] = 12'h4a6;
    sinelut[8'd250] = 12'h4e4;
    sinelut[8'd251] = 12'h52e;
    sinelut[8'd252] = 12'h58b;
    sinelut[8'd253] = 12'h607;
    sinelut[8'd254] = 12'h6c3;
    sinelut[8'd255] = 12'h859;
  end

  always @(posedge clk) begin
    if (clk_en) logsin <= sinelut[addr];
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          logsin <= auto_ss_data_in[11:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[12-1:0] = logsin;
          auto_ss_ack              = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_exprom
module jt12_exprom (
    input        [ 7:0] addr,
    input               clk,
    input               clk_en  /* synthesis direct_enable */,
    output reg   [ 9:0] exp,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [9:0] explut_jt51[255:0];
  initial begin
    explut_jt51[8'd000] = 10'd1018;
    explut_jt51[8'd001] = 10'd1013;
    explut_jt51[8'd002] = 10'd1007;
    explut_jt51[8'd003] = 10'd1002;
    explut_jt51[8'd004] = 10'd0996;
    explut_jt51[8'd005] = 10'd0991;
    explut_jt51[8'd006] = 10'd0986;
    explut_jt51[8'd007] = 10'd0980;
    explut_jt51[8'd008] = 10'd0975;
    explut_jt51[8'd009] = 10'd0969;
    explut_jt51[8'd010] = 10'd0964;
    explut_jt51[8'd011] = 10'd0959;
    explut_jt51[8'd012] = 10'd0953;
    explut_jt51[8'd013] = 10'd0948;
    explut_jt51[8'd014] = 10'd0942;
    explut_jt51[8'd015] = 10'd0937;
    explut_jt51[8'd016] = 10'd0932;
    explut_jt51[8'd017] = 10'd0927;
    explut_jt51[8'd018] = 10'd0921;
    explut_jt51[8'd019] = 10'd0916;
    explut_jt51[8'd020] = 10'd0911;
    explut_jt51[8'd021] = 10'd0906;
    explut_jt51[8'd022] = 10'd0900;
    explut_jt51[8'd023] = 10'd0895;
    explut_jt51[8'd024] = 10'd0890;
    explut_jt51[8'd025] = 10'd0885;
    explut_jt51[8'd026] = 10'd0880;
    explut_jt51[8'd027] = 10'd0874;
    explut_jt51[8'd028] = 10'd0869;
    explut_jt51[8'd029] = 10'd0864;
    explut_jt51[8'd030] = 10'd0859;
    explut_jt51[8'd031] = 10'd0854;
    explut_jt51[8'd032] = 10'd0849;
    explut_jt51[8'd033] = 10'd0844;
    explut_jt51[8'd034] = 10'd0839;
    explut_jt51[8'd035] = 10'd0834;
    explut_jt51[8'd036] = 10'd0829;
    explut_jt51[8'd037] = 10'd0824;
    explut_jt51[8'd038] = 10'd0819;
    explut_jt51[8'd039] = 10'd0814;
    explut_jt51[8'd040] = 10'd0809;
    explut_jt51[8'd041] = 10'd0804;
    explut_jt51[8'd042] = 10'd0799;
    explut_jt51[8'd043] = 10'd0794;
    explut_jt51[8'd044] = 10'd0789;
    explut_jt51[8'd045] = 10'd0784;
    explut_jt51[8'd046] = 10'd0779;
    explut_jt51[8'd047] = 10'd0774;
    explut_jt51[8'd048] = 10'd0770;
    explut_jt51[8'd049] = 10'd0765;
    explut_jt51[8'd050] = 10'd0760;
    explut_jt51[8'd051] = 10'd0755;
    explut_jt51[8'd052] = 10'd0750;
    explut_jt51[8'd053] = 10'd0745;
    explut_jt51[8'd054] = 10'd0741;
    explut_jt51[8'd055] = 10'd0736;
    explut_jt51[8'd056] = 10'd0731;
    explut_jt51[8'd057] = 10'd0726;
    explut_jt51[8'd058] = 10'd0722;
    explut_jt51[8'd059] = 10'd0717;
    explut_jt51[8'd060] = 10'd0712;
    explut_jt51[8'd061] = 10'd0708;
    explut_jt51[8'd062] = 10'd0703;
    explut_jt51[8'd063] = 10'd0698;
    explut_jt51[8'd064] = 10'd0693;
    explut_jt51[8'd065] = 10'd0689;
    explut_jt51[8'd066] = 10'd0684;
    explut_jt51[8'd067] = 10'd0680;
    explut_jt51[8'd068] = 10'd0675;
    explut_jt51[8'd069] = 10'd0670;
    explut_jt51[8'd070] = 10'd0666;
    explut_jt51[8'd071] = 10'd0661;
    explut_jt51[8'd072] = 10'd0657;
    explut_jt51[8'd073] = 10'd0652;
    explut_jt51[8'd074] = 10'd0648;
    explut_jt51[8'd075] = 10'd0643;
    explut_jt51[8'd076] = 10'd0639;
    explut_jt51[8'd077] = 10'd0634;
    explut_jt51[8'd078] = 10'd0630;
    explut_jt51[8'd079] = 10'd0625;
    explut_jt51[8'd080] = 10'd0621;
    explut_jt51[8'd081] = 10'd0616;
    explut_jt51[8'd082] = 10'd0612;
    explut_jt51[8'd083] = 10'd0607;
    explut_jt51[8'd084] = 10'd0603;
    explut_jt51[8'd085] = 10'd0599;
    explut_jt51[8'd086] = 10'd0594;
    explut_jt51[8'd087] = 10'd0590;
    explut_jt51[8'd088] = 10'd0585;
    explut_jt51[8'd089] = 10'd0581;
    explut_jt51[8'd090] = 10'd0577;
    explut_jt51[8'd091] = 10'd0572;
    explut_jt51[8'd092] = 10'd0568;
    explut_jt51[8'd093] = 10'd0564;
    explut_jt51[8'd094] = 10'd0560;
    explut_jt51[8'd095] = 10'd0555;
    explut_jt51[8'd096] = 10'd0551;
    explut_jt51[8'd097] = 10'd0547;
    explut_jt51[8'd098] = 10'd0542;
    explut_jt51[8'd099] = 10'd0538;
    explut_jt51[8'd100] = 10'd0534;
    explut_jt51[8'd101] = 10'd0530;
    explut_jt51[8'd102] = 10'd0526;
    explut_jt51[8'd103] = 10'd0521;
    explut_jt51[8'd104] = 10'd0517;
    explut_jt51[8'd105] = 10'd0513;
    explut_jt51[8'd106] = 10'd0509;
    explut_jt51[8'd107] = 10'd0505;
    explut_jt51[8'd108] = 10'd0501;
    explut_jt51[8'd109] = 10'd0496;
    explut_jt51[8'd110] = 10'd0492;
    explut_jt51[8'd111] = 10'd0488;
    explut_jt51[8'd112] = 10'd0484;
    explut_jt51[8'd113] = 10'd0480;
    explut_jt51[8'd114] = 10'd0476;
    explut_jt51[8'd115] = 10'd0472;
    explut_jt51[8'd116] = 10'd0468;
    explut_jt51[8'd117] = 10'd0464;
    explut_jt51[8'd118] = 10'd0460;
    explut_jt51[8'd119] = 10'd0456;
    explut_jt51[8'd120] = 10'd0452;
    explut_jt51[8'd121] = 10'd0448;
    explut_jt51[8'd122] = 10'd0444;
    explut_jt51[8'd123] = 10'd0440;
    explut_jt51[8'd124] = 10'd0436;
    explut_jt51[8'd125] = 10'd0432;
    explut_jt51[8'd126] = 10'd0428;
    explut_jt51[8'd127] = 10'd0424;
    explut_jt51[8'd128] = 10'd0420;
    explut_jt51[8'd129] = 10'd0416;
    explut_jt51[8'd130] = 10'd0412;
    explut_jt51[8'd131] = 10'd0409;
    explut_jt51[8'd132] = 10'd0405;
    explut_jt51[8'd133] = 10'd0401;
    explut_jt51[8'd134] = 10'd0397;
    explut_jt51[8'd135] = 10'd0393;
    explut_jt51[8'd136] = 10'd0389;
    explut_jt51[8'd137] = 10'd0385;
    explut_jt51[8'd138] = 10'd0382;
    explut_jt51[8'd139] = 10'd0378;
    explut_jt51[8'd140] = 10'd0374;
    explut_jt51[8'd141] = 10'd0370;
    explut_jt51[8'd142] = 10'd0367;
    explut_jt51[8'd143] = 10'd0363;
    explut_jt51[8'd144] = 10'd0359;
    explut_jt51[8'd145] = 10'd0355;
    explut_jt51[8'd146] = 10'd0352;
    explut_jt51[8'd147] = 10'd0348;
    explut_jt51[8'd148] = 10'd0344;
    explut_jt51[8'd149] = 10'd0340;
    explut_jt51[8'd150] = 10'd0337;
    explut_jt51[8'd151] = 10'd0333;
    explut_jt51[8'd152] = 10'd0329;
    explut_jt51[8'd153] = 10'd0326;
    explut_jt51[8'd154] = 10'd0322;
    explut_jt51[8'd155] = 10'd0318;
    explut_jt51[8'd156] = 10'd0315;
    explut_jt51[8'd157] = 10'd0311;
    explut_jt51[8'd158] = 10'd0308;
    explut_jt51[8'd159] = 10'd0304;
    explut_jt51[8'd160] = 10'd0300;
    explut_jt51[8'd161] = 10'd0297;
    explut_jt51[8'd162] = 10'd0293;
    explut_jt51[8'd163] = 10'd0290;
    explut_jt51[8'd164] = 10'd0286;
    explut_jt51[8'd165] = 10'd0283;
    explut_jt51[8'd166] = 10'd0279;
    explut_jt51[8'd167] = 10'd0276;
    explut_jt51[8'd168] = 10'd0272;
    explut_jt51[8'd169] = 10'd0268;
    explut_jt51[8'd170] = 10'd0265;
    explut_jt51[8'd171] = 10'd0262;
    explut_jt51[8'd172] = 10'd0258;
    explut_jt51[8'd173] = 10'd0255;
    explut_jt51[8'd174] = 10'd0251;
    explut_jt51[8'd175] = 10'd0248;
    explut_jt51[8'd176] = 10'd0244;
    explut_jt51[8'd177] = 10'd0241;
    explut_jt51[8'd178] = 10'd0237;
    explut_jt51[8'd179] = 10'd0234;
    explut_jt51[8'd180] = 10'd0231;
    explut_jt51[8'd181] = 10'd0227;
    explut_jt51[8'd182] = 10'd0224;
    explut_jt51[8'd183] = 10'd0220;
    explut_jt51[8'd184] = 10'd0217;
    explut_jt51[8'd185] = 10'd0214;
    explut_jt51[8'd186] = 10'd0210;
    explut_jt51[8'd187] = 10'd0207;
    explut_jt51[8'd188] = 10'd0204;
    explut_jt51[8'd189] = 10'd0200;
    explut_jt51[8'd190] = 10'd0197;
    explut_jt51[8'd191] = 10'd0194;
    explut_jt51[8'd192] = 10'd0190;
    explut_jt51[8'd193] = 10'd0187;
    explut_jt51[8'd194] = 10'd0184;
    explut_jt51[8'd195] = 10'd0181;
    explut_jt51[8'd196] = 10'd0177;
    explut_jt51[8'd197] = 10'd0174;
    explut_jt51[8'd198] = 10'd0171;
    explut_jt51[8'd199] = 10'd0168;
    explut_jt51[8'd200] = 10'd0164;
    explut_jt51[8'd201] = 10'd0161;
    explut_jt51[8'd202] = 10'd0158;
    explut_jt51[8'd203] = 10'd0155;
    explut_jt51[8'd204] = 10'd0152;
    explut_jt51[8'd205] = 10'd0148;
    explut_jt51[8'd206] = 10'd0145;
    explut_jt51[8'd207] = 10'd0142;
    explut_jt51[8'd208] = 10'd0139;
    explut_jt51[8'd209] = 10'd0136;
    explut_jt51[8'd210] = 10'd0133;
    explut_jt51[8'd211] = 10'd0130;
    explut_jt51[8'd212] = 10'd0126;
    explut_jt51[8'd213] = 10'd0123;
    explut_jt51[8'd214] = 10'd0120;
    explut_jt51[8'd215] = 10'd0117;
    explut_jt51[8'd216] = 10'd0114;
    explut_jt51[8'd217] = 10'd0111;
    explut_jt51[8'd218] = 10'd0108;
    explut_jt51[8'd219] = 10'd0105;
    explut_jt51[8'd220] = 10'd0102;
    explut_jt51[8'd221] = 10'd0099;
    explut_jt51[8'd222] = 10'd0096;
    explut_jt51[8'd223] = 10'd0093;
    explut_jt51[8'd224] = 10'd0090;
    explut_jt51[8'd225] = 10'd0087;
    explut_jt51[8'd226] = 10'd0084;
    explut_jt51[8'd227] = 10'd0081;
    explut_jt51[8'd228] = 10'd0078;
    explut_jt51[8'd229] = 10'd0075;
    explut_jt51[8'd230] = 10'd0072;
    explut_jt51[8'd231] = 10'd0069;
    explut_jt51[8'd232] = 10'd0066;
    explut_jt51[8'd233] = 10'd0063;
    explut_jt51[8'd234] = 10'd0060;
    explut_jt51[8'd235] = 10'd0057;
    explut_jt51[8'd236] = 10'd0054;
    explut_jt51[8'd237] = 10'd0051;
    explut_jt51[8'd238] = 10'd0048;
    explut_jt51[8'd239] = 10'd0045;
    explut_jt51[8'd240] = 10'd0042;
    explut_jt51[8'd241] = 10'd0040;
    explut_jt51[8'd242] = 10'd0037;
    explut_jt51[8'd243] = 10'd0034;
    explut_jt51[8'd244] = 10'd0031;
    explut_jt51[8'd245] = 10'd0028;
    explut_jt51[8'd246] = 10'd0025;
    explut_jt51[8'd247] = 10'd0022;
    explut_jt51[8'd248] = 10'd0020;
    explut_jt51[8'd249] = 10'd0017;
    explut_jt51[8'd250] = 10'd0014;
    explut_jt51[8'd251] = 10'd0011;
    explut_jt51[8'd252] = 10'd0008;
    explut_jt51[8'd253] = 10'd0006;
    explut_jt51[8'd254] = 10'd0003;
    explut_jt51[8'd255] = 10'd0000;
  end

  always @(posedge clk) begin
    if (clk_en) exp <= explut_jt51[addr];
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          exp <= auto_ss_data_in[9:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[10-1:0] = exp;
          auto_ss_ack              = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_op
module jt12_op (
    input       rst,
    input       clk,
    input       clk_en  /* synthesis direct_enable */,
    input [9:0] pg_phase_VIII,
    input [9:0] eg_atten_IX,                            // output from envelope generator
    input [2:0] fb_II,                                  // voice feedback
    input       xuse_prevprev1,
    input       xuse_prev2,
    input       xuse_internal,
    input       yuse_prev1,
    input       yuse_prev2,
    input       yuse_internal,
    input       test_214,

    input s1_enters,
    input s2_enters,
    input s3_enters,
    input s4_enters,
    input zero,

    output signed [ 8:0] op_result,
    output signed [13:0] full_result,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_prev1_buffer_ack | auto_ss_prevprev1_buffer_ack | auto_ss_prev2_buffer_ack | auto_ss_phasemod_sh_ack | auto_ss_u_logsin_ack | auto_ss_u_exprom_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_prev1_buffer_data_out | auto_ss_prevprev1_buffer_data_out | auto_ss_prev2_buffer_data_out | auto_ss_phasemod_sh_data_out | auto_ss_u_logsin_data_out | auto_ss_u_exprom_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_exprom_ack;

  wire  [31:0] auto_ss_u_exprom_data_out;

  wire         auto_ss_u_logsin_ack;

  wire  [31:0] auto_ss_u_logsin_data_out;

  wire         auto_ss_phasemod_sh_ack;

  wire  [31:0] auto_ss_phasemod_sh_data_out;

  wire         auto_ss_prev2_buffer_ack;

  wire  [31:0] auto_ss_prev2_buffer_data_out;

  wire         auto_ss_prevprev1_buffer_ack;

  wire  [31:0] auto_ss_prevprev1_buffer_data_out;

  wire         auto_ss_prev1_buffer_ack;

  wire  [31:0] auto_ss_prev1_buffer_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter num_ch = 6;

  /*  enters  exits
    S1      S2
    S3      S4
    S2      S1
    S4      S3
*/

  reg [13:0] op_result_internal, op_XII;
  reg [11:0] atten_internal_IX;

  assign op_result   = op_result_internal[13:5];
  assign full_result = op_result_internal;

  reg signbit_IX, signbit_X, signbit_XI;
  reg [11:0] totalatten_X;

  wire [13:0] prev1, prevprev1, prev2;

  reg [13:0] prev1_din, prevprev1_din, prev2_din;

  always @(*)
    if (num_ch == 3) begin
      prev1_din     = s1_enters ? op_result_internal : prev1;
      prevprev1_din = s3_enters ? op_result_internal : prevprev1;
      prev2_din     = s2_enters ? op_result_internal : prev2;
    end else begin  // 6 channels
      prev1_din     = s2_enters ? op_result_internal : prev1;
      prevprev1_din = s2_enters ? prev1 : prevprev1;
      prev2_din     = s1_enters ? op_result_internal : prev2;
    end

  jt12_sh #(
      .width (14),
      .stages(num_ch)
  ) prev1_buffer (
      //  .rst    ( rst       ),
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (prev1_din),
      .drop                   (prev1),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_prev1_buffer_data_out),
      .auto_ss_ack            (auto_ss_prev1_buffer_ack)

  );

  jt12_sh #(
      .width (14),
      .stages(num_ch)
  ) prevprev1_buffer (
      //  .rst    ( rst           ),
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (prevprev1_din),
      .drop                   (prevprev1),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_prevprev1_buffer_data_out),
      .auto_ss_ack            (auto_ss_prevprev1_buffer_ack)

  );

  jt12_sh #(
      .width (14),
      .stages(num_ch)
  ) prev2_buffer (
      //  .rst    ( rst       ),
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (prev2_din),
      .drop                   (prev2),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 3),
      .auto_ss_data_out       (auto_ss_prev2_buffer_data_out),
      .auto_ss_ack            (auto_ss_prev2_buffer_ack)

  );


  reg [10:0] subtresult;

  reg [12:0] shifter, shifter_2, shifter_3;

  // REGISTER/CYCLE 1
  // Creation of phase modulation (FM) feedback signal, before shifting
  reg [13:0] x, y;
  reg [14:0] xs, ys, pm_preshift_II;
  reg s1_II;

  always @(*) begin
    casez ({
      xuse_prevprev1, xuse_prev2, xuse_internal
    })
      3'b1??:  x = prevprev1;
      3'b01?:  x = prev2;
      3'b001:  x = op_result_internal;
      default: x = 14'd0;
    endcase
    casez ({
      yuse_prev1, yuse_prev2, yuse_internal
    })
      3'b1??:  y = prev1;
      3'b01?:  y = prev2;
      3'b001:  y = op_result_internal;
      default: y = 14'd0;
    endcase
    xs = {x[13], x};  // sign-extend
    ys = {y[13], y};  // sign-extend
  end

  always @(posedge clk) begin
    if (clk_en) begin
      pm_preshift_II <= xs + ys;  // carry is discarded
      s1_II          <= s1_enters;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pm_preshift_II <= auto_ss_data_in[14:0];
        end
        2: begin
          s1_II <= auto_ss_data_in[0];
        end
        default: begin
        end
      endcase
    end
  end



  /* REGISTER/CYCLE 2-7 (also YM2612 extra cycles 1-6)
   Shifting of FM feedback signal, adding phase from PG to FM phase
   In YM2203, phasemod_II is not registered at all, it is latched on the first edge 
   in add_pg_phase and the second edge is the output of add_pg_phase. In the YM2612, there
   are 6 cycles worth of registers between the generated (non-registered) phasemod_II signal
   and the input to add_pg_phase.     */

  reg  [9:0] phasemod_II;
  wire [9:0] phasemod_VIII;

  always @(*) begin
    // Shift FM feedback signal
    if (!s1_II)  // Not S1
      phasemod_II = pm_preshift_II[10:1];  // Bit 0 of pm_preshift_II is never used
    else  // S1
      case (fb_II)
        3'd0: phasemod_II = 10'd0;
        3'd1: phasemod_II = {{4{pm_preshift_II[14]}}, pm_preshift_II[14:9]};
        3'd2: phasemod_II = {{3{pm_preshift_II[14]}}, pm_preshift_II[14:8]};
        3'd3: phasemod_II = {{2{pm_preshift_II[14]}}, pm_preshift_II[14:7]};
        3'd4: phasemod_II = {pm_preshift_II[14], pm_preshift_II[14:6]};
        3'd5: phasemod_II = pm_preshift_II[14:5];
        3'd6: phasemod_II = pm_preshift_II[13:4];
        3'd7: phasemod_II = pm_preshift_II[12:3];
      endcase
  end

  // REGISTER/CYCLE 2-7
  //generate
  //    if( num_ch==6 )
  jt12_sh #(
      .width (10),
      .stages(6)
  ) phasemod_sh (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (phasemod_II),
      .drop                   (phasemod_VIII),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 4),
      .auto_ss_data_out       (auto_ss_phasemod_sh_data_out),
      .auto_ss_ack            (auto_ss_phasemod_sh_ack)

  );
  //     else begin
  //         assign phasemod_VIII = phasemod_II;
  //     end
  // endgenerate

  // REGISTER/CYCLE 8
  reg [9:0] phase;
  // Sets the maximum number of fanouts for a register or combinational
  // cell.  The Quartus II software will replicate the cell and split
  // the fanouts among the duplicates until the fanout of each cell
  // is below the maximum.

  reg [7:0] aux_VIII;

  always @(*) begin
    phase    = phasemod_VIII + pg_phase_VIII;
    aux_VIII = phase[7:0] ^ {8{~phase[8]}};
  end

  always @(posedge clk) begin
    if (clk_en) begin
      signbit_IX <= phase[9];
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        2: begin
          signbit_IX <= auto_ss_data_in[1];
        end
        default: begin
        end
      endcase
    end
  end



  wire [11:0] logsin_IX;

  jt12_logsin u_logsin (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .addr                   (aux_VIII[7:0]),
      .logsin                 (logsin_IX),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
      .auto_ss_data_out       (auto_ss_u_logsin_data_out),
      .auto_ss_ack            (auto_ss_u_logsin_ack)

  );


  // REGISTER/CYCLE 9
  // Sine table    
  // Main sine table body

  always @(*) begin
    subtresult        = eg_atten_IX + logsin_IX[11:2];
    atten_internal_IX = {subtresult[9:0], logsin_IX[1:0]} | {12{subtresult[10]}};
  end

  wire [9:0] mantissa_X;
  reg  [9:0] mantissa_XI;
  reg [3:0] exponent_X, exponent_XI;

  jt12_exprom u_exprom (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .addr                   (atten_internal_IX[7:0]),
      .exp                    (mantissa_X),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 6),
      .auto_ss_data_out       (auto_ss_u_exprom_data_out),
      .auto_ss_ack            (auto_ss_u_exprom_ack)

  );

  always @(posedge clk) begin
    if (clk_en) begin
      exponent_X <= atten_internal_IX[11:8];
      signbit_X  <= signbit_IX;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          exponent_X <= auto_ss_data_in[27:24];
        end
        2: begin
          signbit_X <= auto_ss_data_in[2];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk) begin
    if (clk_en) begin
      mantissa_XI <= mantissa_X;
      exponent_XI <= exponent_X;
      signbit_XI  <= signbit_X;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          mantissa_XI <= auto_ss_data_in[23:14];
          exponent_XI <= auto_ss_data_in[31:28];
        end
        2: begin
          signbit_XI <= auto_ss_data_in[3];
        end
        default: begin
        end
      endcase
    end
  end



  // REGISTER/CYCLE 11
  // Introduce test bit as MSB, 2's complement & Carry-out discarded

  always @(*) begin
    // Floating-point to integer, and incorporating sign bit
    // Two-stage shifting of mantissa_XI by exponent_XI
    shifter = {3'b001, mantissa_XI};
    case (~exponent_XI[1:0])
      2'b00: shifter_2 = {1'b0, shifter[12:1]};  // LSB discarded
      2'b01: shifter_2 = shifter;
      2'b10: shifter_2 = {shifter[11:0], 1'b0};
      2'b11: shifter_2 = {shifter[10:0], 2'b0};
    endcase
    case (~exponent_XI[3:2])
      2'b00: shifter_3 = {12'b0, shifter_2[12]};
      2'b01: shifter_3 = {8'b0, shifter_2[12:8]};
      2'b10: shifter_3 = {4'b0, shifter_2[12:4]};
      2'b11: shifter_3 = shifter_2;
    endcase
  end

  always @(posedge clk) begin
    if (clk_en) begin
      // REGISTER CYCLE 11
      op_XII             <= ({test_214, shifter_3} ^ {14{signbit_XI}}) + {13'd0, signbit_XI};
      // REGISTER CYCLE 12
      // Extra register, take output after here
      op_result_internal <= op_XII;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          op_XII <= auto_ss_data_in[28:15];
        end
        1: begin
          op_result_internal <= auto_ss_data_in[13:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[28:0] = {op_XII, pm_preshift_II};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[31:0] = {exponent_XI, exponent_X, mantissa_XI, op_result_internal};
          auto_ss_local_ack = 1'b1;
        end
        2: begin
          auto_ss_local_data_out[3:0] = {signbit_XI, signbit_X, signbit_IX, s1_II};
          auto_ss_local_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end





endmodule


///////////////////////////////////////////
// MODULE jt12_rst
module jt12_rst (
    input               rst,
    input               clk,
    output reg          rst_n,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg r;

  always @(negedge clk) begin

    if (rst) begin
      r     <= 1'b0;
      rst_n <= 1'b0;
    end else begin
      {rst_n, r} <= {r, 1'b1};
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          r     <= auto_ss_data_in[0];
          rst_n <= auto_ss_data_in[1];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[1:0] = {rst_n, r};
          auto_ss_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_cnt
module jt10_adpcm_cnt (
    input               rst_n,
    input               clk,                      // CPU clock
    input               cen,                      // 666 kHz
    // pipeline channel
    input        [ 5:0] cur_ch,
    input        [ 5:0] en_ch,
    // Address writes from CPU
    input        [15:0] addr_in,
    input        [ 2:0] addr_ch,
    input               up_start,
    input               up_end,
    // Counter control
    input               aon,
    input               aoff,
    // ROM driver
    output       [19:0] addr_out,
    output       [ 3:0] bank,
    output              sel,
    output              roe_n,
    output              decon,
    output              clr,                      // inform the decoder that a new section begins
    // Flags
    output reg   [ 5:0] flags,
    input        [ 5:0] clr_flags,
    //
    output       [15:0] start_top,
    output       [15:0] end_top,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [20:0] addr1, addr2, addr3, addr4, addr5, addr6;
  reg [3:0] bank1, bank2, bank3, bank4, bank5, bank6;
  reg [11:0] start1, start2, start3, start4, start5, start6, end1, end2, end3, end4, end5, end6;
  reg on1, on2, on3, on4, on5, on6;
  reg done1, done2, done3, done4, done5, done6;
  reg [5:0] done_sr, zero;

  reg roe_n1, decon1;

  reg clr1, clr2, clr3, clr4, clr5, clr6;
  reg skip1, skip2, skip3, skip4, skip5, skip6;

  // All outputs from stage 1
  assign addr_out = addr1[20:1];
  assign sel      = addr1[0];
  assign bank     = bank1;
  assign roe_n    = roe_n1;
  assign clr      = clr1;
  assign decon    = decon1;

  // Two cycles early:  0            0             1            1             2            2             3            3             4            4             5            5
  wire active5 = (en_ch[1] && cur_ch[4]) || (en_ch[2] && cur_ch[5]) || (en_ch[2] && cur_ch[0]) || (en_ch[3] && cur_ch[1]) || (en_ch[4] && cur_ch[2]) || (en_ch[5] && cur_ch[3]);//{ cur_ch[3:0], cur_ch[5:4] } == en_ch;
  wire sumup5 = on5 && !done5 && active5;
  reg sumup6;

  reg [5:0] last_done, set_flags;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      zero      <= 6'd1;
      done_sr   <= ~6'd0;
      last_done <= ~6'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        11: begin
          done_sr <= auto_ss_data_in[29:24];
        end
        12: begin
          last_done <= auto_ss_data_in[5:0];
          set_flags <= auto_ss_data_in[11:6];
          zero      <= auto_ss_data_in[17:12];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      zero    <= {zero[0], zero[5:1]};
      done_sr <= {done1, done_sr[5:1]};
      if (zero[0]) begin
        last_done <= done_sr;
        set_flags <= ~last_done & done_sr;
      end
    end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      flags <= 6'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        12: begin
          flags <= auto_ss_data_in[23:18];
        end
        default: begin
        end
      endcase
    end else begin
      flags <= ~clr_flags & (set_flags | flags);
    end



  assign start_top = {bank1, start1};
  assign end_top   = {bank1, end1};

  reg [5:0] addr_ch_dec;

  always @(*)
    case (addr_ch)
      3'd0: addr_ch_dec = 6'b000_001;
      3'd1: addr_ch_dec = 6'b000_010;
      3'd2: addr_ch_dec = 6'b000_100;
      3'd3: addr_ch_dec = 6'b001_000;
      3'd4: addr_ch_dec = 6'b010_000;
      3'd5: addr_ch_dec = 6'b100_000;
      default: addr_ch_dec = 6'd0;
    endcase  // up_addr

  wire up1 = cur_ch == addr_ch_dec;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      addr1  <= 'd0;
      addr2  <= 'd0;
      addr3  <= 'd0;
      addr4  <= 'd0;
      addr5  <= 'd0;
      addr6  <= 'd0;
      done1  <= 'd1;
      done2  <= 'd1;
      done3  <= 'd1;
      done4  <= 'd1;
      done5  <= 'd1;
      done6  <= 'd1;
      start1 <= 'd0;
      start2 <= 'd0;
      start3 <= 'd0;
      start4 <= 'd0;
      start5 <= 'd0;
      start6 <= 'd0;
      end1   <= 'd0;
      end2   <= 'd0;
      end3   <= 'd0;
      end4   <= 'd0;
      end5   <= 'd0;
      end6   <= 'd0;
      skip1  <= 'd0;
      skip2  <= 'd0;
      skip3  <= 'd0;
      skip4  <= 'd0;
      skip5  <= 'd0;
      skip6  <= 'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          addr1 <= auto_ss_data_in[20:0];
        end
        1: begin
          addr2 <= auto_ss_data_in[20:0];
        end
        2: begin
          addr3 <= auto_ss_data_in[20:0];
        end
        3: begin
          addr4 <= auto_ss_data_in[20:0];
        end
        4: begin
          addr5 <= auto_ss_data_in[20:0];
        end
        5: begin
          addr6 <= auto_ss_data_in[20:0];
        end
        6: begin
          end1 <= auto_ss_data_in[11:0];
          end2 <= auto_ss_data_in[23:12];
        end
        7: begin
          end3 <= auto_ss_data_in[11:0];
          end4 <= auto_ss_data_in[23:12];
        end
        8: begin
          end5 <= auto_ss_data_in[11:0];
          end6 <= auto_ss_data_in[23:12];
        end
        9: begin
          start1 <= auto_ss_data_in[11:0];
          start2 <= auto_ss_data_in[23:12];
        end
        10: begin
          start3 <= auto_ss_data_in[11:0];
          start4 <= auto_ss_data_in[23:12];
        end
        11: begin
          start5 <= auto_ss_data_in[11:0];
          start6 <= auto_ss_data_in[23:12];
        end
        12: begin
          bank1 <= auto_ss_data_in[27:24];
          bank2 <= auto_ss_data_in[31:28];
        end
        13: begin
          bank3  <= auto_ss_data_in[3:0];
          bank4  <= auto_ss_data_in[7:4];
          bank5  <= auto_ss_data_in[11:8];
          bank6  <= auto_ss_data_in[15:12];
          clr1   <= auto_ss_data_in[16];
          clr2   <= auto_ss_data_in[17];
          clr3   <= auto_ss_data_in[18];
          clr4   <= auto_ss_data_in[19];
          clr5   <= auto_ss_data_in[20];
          clr6   <= auto_ss_data_in[21];
          decon1 <= auto_ss_data_in[22];
          done1  <= auto_ss_data_in[23];
          done2  <= auto_ss_data_in[24];
          done3  <= auto_ss_data_in[25];
          done4  <= auto_ss_data_in[26];
          done5  <= auto_ss_data_in[27];
          done6  <= auto_ss_data_in[28];
          on1    <= auto_ss_data_in[29];
          on2    <= auto_ss_data_in[30];
          on3    <= auto_ss_data_in[31];
        end
        14: begin
          on4    <= auto_ss_data_in[0];
          on5    <= auto_ss_data_in[1];
          on6    <= auto_ss_data_in[2];
          roe_n1 <= auto_ss_data_in[3];
          skip1  <= auto_ss_data_in[4];
          skip2  <= auto_ss_data_in[5];
          skip3  <= auto_ss_data_in[6];
          skip4  <= auto_ss_data_in[7];
          skip5  <= auto_ss_data_in[8];
          skip6  <= auto_ss_data_in[9];
          sumup6 <= auto_ss_data_in[10];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      addr2  <= addr1;
      on2    <= aoff ? 1'b0 : (aon | (on1 && ~done1));
      clr2   <= aoff || aon || done1;  // Each time a A-ON is sent the address counter restarts
      done2  <= done1;
      start2 <= (up_start && up1) ? addr_in[11:0] : start1;
      end2   <= (up_end && up1) ? addr_in[11:0] : end1;
      bank2  <= (up_start && up1) ? addr_in[15:12] : bank1;
      skip2  <= skip1;

      addr3  <= addr2;  // clr2 ? {start2,9'd0} : addr2;
      on3    <= on2;
      clr3   <= clr2;
      done3  <= done2;
      start3 <= start2;
      end3   <= end2;
      bank3  <= bank2;
      skip3  <= skip2;

      addr4  <= addr3;
      on4    <= on3;
      clr4   <= clr3;
      done4  <= done3;
      start4 <= start3;
      end4   <= end3;
      bank4  <= bank3;
      skip4  <= skip3;

      addr5  <= addr4;
      on5    <= on4;
      clr5   <= clr4;
      done5  <= ~on4 ? done4 : (addr4[20:9] == end4 && addr4[8:0] == ~9'b0 && ~clr4);
      start5 <= start4;
      end5   <= end4;
      bank5  <= bank4;
      skip5  <= skip4;
      // V
      addr6  <= addr5;
      on6    <= on5;
      clr6   <= clr5;
      done6  <= done5;
      start6 <= start5;
      end6   <= end5;
      bank6  <= bank5;
      sumup6 <= sumup5;
      skip6  <= skip5;

      addr1  <= (clr6 && on6) ? {start6, 9'd0} : (sumup6 && ~skip6 ? addr6 + 21'd1 : addr6);
      on1    <= on6;
      done1  <= done6;
      start1 <= start6;
      end1   <= end6;
      roe_n1 <= ~sumup6;
      decon1 <= sumup6;
      bank1  <= bank6;
      clr1   <= clr6;
      skip1  <= (clr6 && on6) ? 1'b1 : sumup6 ? 1'b0 : skip6;
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[21-1:0] = addr1;
          auto_ss_ack              = 1'b1;
        end
        1: begin
          auto_ss_data_out[21-1:0] = addr2;
          auto_ss_ack              = 1'b1;
        end
        2: begin
          auto_ss_data_out[21-1:0] = addr3;
          auto_ss_ack              = 1'b1;
        end
        3: begin
          auto_ss_data_out[21-1:0] = addr4;
          auto_ss_ack              = 1'b1;
        end
        4: begin
          auto_ss_data_out[21-1:0] = addr5;
          auto_ss_ack              = 1'b1;
        end
        5: begin
          auto_ss_data_out[21-1:0] = addr6;
          auto_ss_ack              = 1'b1;
        end
        6: begin
          auto_ss_data_out[23:0] = {end2, end1};
          auto_ss_ack            = 1'b1;
        end
        7: begin
          auto_ss_data_out[23:0] = {end4, end3};
          auto_ss_ack            = 1'b1;
        end
        8: begin
          auto_ss_data_out[23:0] = {end6, end5};
          auto_ss_ack            = 1'b1;
        end
        9: begin
          auto_ss_data_out[23:0] = {start2, start1};
          auto_ss_ack            = 1'b1;
        end
        10: begin
          auto_ss_data_out[23:0] = {start4, start3};
          auto_ss_ack            = 1'b1;
        end
        11: begin
          auto_ss_data_out[29:0] = {done_sr, start6, start5};
          auto_ss_ack            = 1'b1;
        end
        12: begin
          auto_ss_data_out[31:0] = {bank2, bank1, flags, zero, set_flags, last_done};
          auto_ss_ack            = 1'b1;
        end
        13: begin
          auto_ss_data_out[31:0] = {
            on3,
            on2,
            on1,
            done6,
            done5,
            done4,
            done3,
            done2,
            done1,
            decon1,
            clr6,
            clr5,
            clr4,
            clr3,
            clr2,
            clr1,
            bank6,
            bank5,
            bank4,
            bank3
          };
          auto_ss_ack = 1'b1;
        end
        14: begin
          auto_ss_data_out[10:0] = {
            sumup6, skip6, skip5, skip4, skip3, skip2, skip1, roe_n1, on6, on5, on4
          };
          auto_ss_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcma_lut
module jt10_adpcma_lut (
    input               clk,                      // CPU clock
    input               rst_n,
    input               cen,
    input        [ 8:0] addr,                     //  = {step,delta};
    output reg   [11:0] inc,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [11:0] lut[0:391];

  initial begin
    lut[9'o00_0] = 12'o0002;
    lut[9'o00_1] = 12'o0006;
    lut[9'o00_2] = 12'o0012;
    lut[9'o00_3] = 12'o0016;
    lut[9'o00_4] = 12'o0022;
    lut[9'o00_5] = 12'o0026;
    lut[9'o00_6] = 12'o0032;
    lut[9'o00_7] = 12'o0036;
    lut[9'o01_0] = 12'o0002;
    lut[9'o01_1] = 12'o0006;
    lut[9'o01_2] = 12'o0012;
    lut[9'o01_3] = 12'o0016;
    lut[9'o01_4] = 12'o0023;
    lut[9'o01_5] = 12'o0027;
    lut[9'o01_6] = 12'o0033;
    lut[9'o01_7] = 12'o0037;
    lut[9'o02_0] = 12'o0002;
    lut[9'o02_1] = 12'o0007;
    lut[9'o02_2] = 12'o0013;
    lut[9'o02_3] = 12'o0020;
    lut[9'o02_4] = 12'o0025;
    lut[9'o02_5] = 12'o0032;
    lut[9'o02_6] = 12'o0036;
    lut[9'o02_7] = 12'o0043;
    lut[9'o03_0] = 12'o0002;
    lut[9'o03_1] = 12'o0007;
    lut[9'o03_2] = 12'o0015;
    lut[9'o03_3] = 12'o0022;
    lut[9'o03_4] = 12'o0027;
    lut[9'o03_5] = 12'o0034;
    lut[9'o03_6] = 12'o0042;
    lut[9'o03_7] = 12'o0047;
    lut[9'o04_0] = 12'o0002;
    lut[9'o04_1] = 12'o0010;
    lut[9'o04_2] = 12'o0016;
    lut[9'o04_3] = 12'o0024;
    lut[9'o04_4] = 12'o0031;
    lut[9'o04_5] = 12'o0037;
    lut[9'o04_6] = 12'o0045;
    lut[9'o04_7] = 12'o0053;
    lut[9'o05_0] = 12'o0003;
    lut[9'o05_1] = 12'o0011;
    lut[9'o05_2] = 12'o0017;
    lut[9'o05_3] = 12'o0025;
    lut[9'o05_4] = 12'o0034;
    lut[9'o05_5] = 12'o0042;
    lut[9'o05_6] = 12'o0050;
    lut[9'o05_7] = 12'o0056;
    lut[9'o06_0] = 12'o0003;
    lut[9'o06_1] = 12'o0012;
    lut[9'o06_2] = 12'o0021;
    lut[9'o06_3] = 12'o0030;
    lut[9'o06_4] = 12'o0037;
    lut[9'o06_5] = 12'o0046;
    lut[9'o06_6] = 12'o0055;
    lut[9'o06_7] = 12'o0064;
    lut[9'o07_0] = 12'o0003;
    lut[9'o07_1] = 12'o0013;
    lut[9'o07_2] = 12'o0023;
    lut[9'o07_3] = 12'o0033;
    lut[9'o07_4] = 12'o0042;
    lut[9'o07_5] = 12'o0052;
    lut[9'o07_6] = 12'o0062;
    lut[9'o07_7] = 12'o0072;
    lut[9'o10_0] = 12'o0004;
    lut[9'o10_1] = 12'o0014;
    lut[9'o10_2] = 12'o0025;
    lut[9'o10_3] = 12'o0035;
    lut[9'o10_4] = 12'o0046;
    lut[9'o10_5] = 12'o0056;
    lut[9'o10_6] = 12'o0067;
    lut[9'o10_7] = 12'o0077;
    lut[9'o11_0] = 12'o0004;
    lut[9'o11_1] = 12'o0015;
    lut[9'o11_2] = 12'o0027;
    lut[9'o11_3] = 12'o0040;
    lut[9'o11_4] = 12'o0051;
    lut[9'o11_5] = 12'o0062;
    lut[9'o11_6] = 12'o0074;
    lut[9'o11_7] = 12'o0105;
    lut[9'o12_0] = 12'o0005;
    lut[9'o12_1] = 12'o0017;
    lut[9'o12_2] = 12'o0031;
    lut[9'o12_3] = 12'o0043;
    lut[9'o12_4] = 12'o0056;
    lut[9'o12_5] = 12'o0070;
    lut[9'o12_6] = 12'o0102;
    lut[9'o12_7] = 12'o0114;
    lut[9'o13_0] = 12'o0005;
    lut[9'o13_1] = 12'o0020;
    lut[9'o13_2] = 12'o0034;
    lut[9'o13_3] = 12'o0047;
    lut[9'o13_4] = 12'o0062;
    lut[9'o13_5] = 12'o0075;
    lut[9'o13_6] = 12'o0111;
    lut[9'o13_7] = 12'o0124;
    lut[9'o14_0] = 12'o0006;
    lut[9'o14_1] = 12'o0022;
    lut[9'o14_2] = 12'o0037;
    lut[9'o14_3] = 12'o0053;
    lut[9'o14_4] = 12'o0070;
    lut[9'o14_5] = 12'o0104;
    lut[9'o14_6] = 12'o0121;
    lut[9'o14_7] = 12'o0135;
    lut[9'o15_0] = 12'o0006;
    lut[9'o15_1] = 12'o0024;
    lut[9'o15_2] = 12'o0042;
    lut[9'o15_3] = 12'o0060;
    lut[9'o15_4] = 12'o0075;
    lut[9'o15_5] = 12'o0113;
    lut[9'o15_6] = 12'o0131;
    lut[9'o15_7] = 12'o0147;
    lut[9'o16_0] = 12'o0007;
    lut[9'o16_1] = 12'o0026;
    lut[9'o16_2] = 12'o0045;
    lut[9'o16_3] = 12'o0064;
    lut[9'o16_4] = 12'o0103;
    lut[9'o16_5] = 12'o0122;
    lut[9'o16_6] = 12'o0141;
    lut[9'o16_7] = 12'o0160;
    lut[9'o17_0] = 12'o0010;
    lut[9'o17_1] = 12'o0030;
    lut[9'o17_2] = 12'o0051;
    lut[9'o17_3] = 12'o0071;
    lut[9'o17_4] = 12'o0112;
    lut[9'o17_5] = 12'o0132;
    lut[9'o17_6] = 12'o0153;
    lut[9'o17_7] = 12'o0173;
    lut[9'o20_0] = 12'o0011;
    lut[9'o20_1] = 12'o0033;
    lut[9'o20_2] = 12'o0055;
    lut[9'o20_3] = 12'o0077;
    lut[9'o20_4] = 12'o0122;
    lut[9'o20_5] = 12'o0144;
    lut[9'o20_6] = 12'o0166;
    lut[9'o20_7] = 12'o0210;
    lut[9'o21_0] = 12'o0012;
    lut[9'o21_1] = 12'o0036;
    lut[9'o21_2] = 12'o0062;
    lut[9'o21_3] = 12'o0106;
    lut[9'o21_4] = 12'o0132;
    lut[9'o21_5] = 12'o0156;
    lut[9'o21_6] = 12'o0202;
    lut[9'o21_7] = 12'o0226;
    lut[9'o22_0] = 12'o0013;
    lut[9'o22_1] = 12'o0041;
    lut[9'o22_2] = 12'o0067;
    lut[9'o22_3] = 12'o0115;
    lut[9'o22_4] = 12'o0143;
    lut[9'o22_5] = 12'o0171;
    lut[9'o22_6] = 12'o0217;
    lut[9'o22_7] = 12'o0245;
    lut[9'o23_0] = 12'o0014;
    lut[9'o23_1] = 12'o0044;
    lut[9'o23_2] = 12'o0074;
    lut[9'o23_3] = 12'o0124;
    lut[9'o23_4] = 12'o0155;
    lut[9'o23_5] = 12'o0205;
    lut[9'o23_6] = 12'o0235;
    lut[9'o23_7] = 12'o0265;
    lut[9'o24_0] = 12'o0015;
    lut[9'o24_1] = 12'o0050;
    lut[9'o24_2] = 12'o0102;
    lut[9'o24_3] = 12'o0135;
    lut[9'o24_4] = 12'o0170;
    lut[9'o24_5] = 12'o0223;
    lut[9'o24_6] = 12'o0255;
    lut[9'o24_7] = 12'o0310;
    lut[9'o25_0] = 12'o0016;
    lut[9'o25_1] = 12'o0054;
    lut[9'o25_2] = 12'o0111;
    lut[9'o25_3] = 12'o0147;
    lut[9'o25_4] = 12'o0204;
    lut[9'o25_5] = 12'o0242;
    lut[9'o25_6] = 12'o0277;
    lut[9'o25_7] = 12'o0335;
    lut[9'o26_0] = 12'o0020;
    lut[9'o26_1] = 12'o0060;
    lut[9'o26_2] = 12'o0121;
    lut[9'o26_3] = 12'o0161;
    lut[9'o26_4] = 12'o0222;
    lut[9'o26_5] = 12'o0262;
    lut[9'o26_6] = 12'o0323;
    lut[9'o26_7] = 12'o0363;
    lut[9'o27_0] = 12'o0021;
    lut[9'o27_1] = 12'o0065;
    lut[9'o27_2] = 12'o0131;
    lut[9'o27_3] = 12'o0175;
    lut[9'o27_4] = 12'o0240;
    lut[9'o27_5] = 12'o0304;
    lut[9'o27_6] = 12'o0350;
    lut[9'o27_7] = 12'o0414;
    lut[9'o30_0] = 12'o0023;
    lut[9'o30_1] = 12'o0072;
    lut[9'o30_2] = 12'o0142;
    lut[9'o30_3] = 12'o0211;
    lut[9'o30_4] = 12'o0260;
    lut[9'o30_5] = 12'o0327;
    lut[9'o30_6] = 12'o0377;
    lut[9'o30_7] = 12'o0446;
    lut[9'o31_0] = 12'o0025;
    lut[9'o31_1] = 12'o0100;
    lut[9'o31_2] = 12'o0154;
    lut[9'o31_3] = 12'o0227;
    lut[9'o31_4] = 12'o0302;
    lut[9'o31_5] = 12'o0355;
    lut[9'o31_6] = 12'o0431;
    lut[9'o31_7] = 12'o0504;
    lut[9'o32_0] = 12'o0027;
    lut[9'o32_1] = 12'o0107;
    lut[9'o32_2] = 12'o0166;
    lut[9'o32_3] = 12'o0246;
    lut[9'o32_4] = 12'o0325;
    lut[9'o32_5] = 12'o0405;
    lut[9'o32_6] = 12'o0464;
    lut[9'o32_7] = 12'o0544;
    lut[9'o33_0] = 12'o0032;
    lut[9'o33_1] = 12'o0116;
    lut[9'o33_2] = 12'o0202;
    lut[9'o33_3] = 12'o0266;
    lut[9'o33_4] = 12'o0353;
    lut[9'o33_5] = 12'o0437;
    lut[9'o33_6] = 12'o0523;
    lut[9'o33_7] = 12'o0607;
    lut[9'o34_0] = 12'o0034;
    lut[9'o34_1] = 12'o0126;
    lut[9'o34_2] = 12'o0217;
    lut[9'o34_3] = 12'o0311;
    lut[9'o34_4] = 12'o0402;
    lut[9'o34_5] = 12'o0474;
    lut[9'o34_6] = 12'o0565;
    lut[9'o34_7] = 12'o0657;
    lut[9'o35_0] = 12'o0037;
    lut[9'o35_1] = 12'o0136;
    lut[9'o35_2] = 12'o0236;
    lut[9'o35_3] = 12'o0335;
    lut[9'o35_4] = 12'o0434;
    lut[9'o35_5] = 12'o0533;
    lut[9'o35_6] = 12'o0633;
    lut[9'o35_7] = 12'o0732;
    lut[9'o36_0] = 12'o0042;
    lut[9'o36_1] = 12'o0150;
    lut[9'o36_2] = 12'o0256;
    lut[9'o36_3] = 12'o0364;
    lut[9'o36_4] = 12'o0471;
    lut[9'o36_5] = 12'o0577;
    lut[9'o36_6] = 12'o0705;
    lut[9'o36_7] = 12'o1013;
    lut[9'o37_0] = 12'o0046;
    lut[9'o37_1] = 12'o0163;
    lut[9'o37_2] = 12'o0277;
    lut[9'o37_3] = 12'o0414;
    lut[9'o37_4] = 12'o0531;
    lut[9'o37_5] = 12'o0646;
    lut[9'o37_6] = 12'o0762;
    lut[9'o37_7] = 12'o1077;
    lut[9'o40_0] = 12'o0052;
    lut[9'o40_1] = 12'o0176;
    lut[9'o40_2] = 12'o0322;
    lut[9'o40_3] = 12'o0446;
    lut[9'o40_4] = 12'o0573;
    lut[9'o40_5] = 12'o0717;
    lut[9'o40_6] = 12'o1043;
    lut[9'o40_7] = 12'o1167;
    lut[9'o41_0] = 12'o0056;
    lut[9'o41_1] = 12'o0213;
    lut[9'o41_2] = 12'o0347;
    lut[9'o41_3] = 12'o0504;
    lut[9'o41_4] = 12'o0641;
    lut[9'o41_5] = 12'o0776;
    lut[9'o41_6] = 12'o1132;
    lut[9'o41_7] = 12'o1267;
    lut[9'o42_0] = 12'o0063;
    lut[9'o42_1] = 12'o0231;
    lut[9'o42_2] = 12'o0377;
    lut[9'o42_3] = 12'o0545;
    lut[9'o42_4] = 12'o0713;
    lut[9'o42_5] = 12'o1061;
    lut[9'o42_6] = 12'o1227;
    lut[9'o42_7] = 12'o1375;
    lut[9'o43_0] = 12'o0070;
    lut[9'o43_1] = 12'o0250;
    lut[9'o43_2] = 12'o0430;
    lut[9'o43_3] = 12'o0610;
    lut[9'o43_4] = 12'o0771;
    lut[9'o43_5] = 12'o1151;
    lut[9'o43_6] = 12'o1331;
    lut[9'o43_7] = 12'o1511;
    lut[9'o44_0] = 12'o0075;
    lut[9'o44_1] = 12'o0271;
    lut[9'o44_2] = 12'o0464;
    lut[9'o44_3] = 12'o0660;
    lut[9'o44_4] = 12'o1053;
    lut[9'o44_5] = 12'o1247;
    lut[9'o44_6] = 12'o1442;
    lut[9'o44_7] = 12'o1636;
    lut[9'o45_0] = 12'o0104;
    lut[9'o45_1] = 12'o0314;
    lut[9'o45_2] = 12'o0524;
    lut[9'o45_3] = 12'o0734;
    lut[9'o45_4] = 12'o1144;
    lut[9'o45_5] = 12'o1354;
    lut[9'o45_6] = 12'o1564;
    lut[9'o45_7] = 12'o1774;
    lut[9'o46_0] = 12'o0112;
    lut[9'o46_1] = 12'o0340;
    lut[9'o46_2] = 12'o0565;
    lut[9'o46_3] = 12'o1013;
    lut[9'o46_4] = 12'o1240;
    lut[9'o46_5] = 12'o1466;
    lut[9'o46_6] = 12'o1713;
    lut[9'o46_7] = 12'o2141;
    lut[9'o47_0] = 12'o0122;
    lut[9'o47_1] = 12'o0366;
    lut[9'o47_2] = 12'o0633;
    lut[9'o47_3] = 12'o1077;
    lut[9'o47_4] = 12'o1344;
    lut[9'o47_5] = 12'o1610;
    lut[9'o47_6] = 12'o2055;
    lut[9'o47_7] = 12'o2321;
    lut[9'o50_0] = 12'o0132;
    lut[9'o50_1] = 12'o0417;
    lut[9'o50_2] = 12'o0704;
    lut[9'o50_3] = 12'o1171;
    lut[9'o50_4] = 12'o1456;
    lut[9'o50_5] = 12'o1743;
    lut[9'o50_6] = 12'o2230;
    lut[9'o50_7] = 12'o2515;
    lut[9'o51_0] = 12'o0143;
    lut[9'o51_1] = 12'o0452;
    lut[9'o51_2] = 12'o0761;
    lut[9'o51_3] = 12'o1270;
    lut[9'o51_4] = 12'o1577;
    lut[9'o51_5] = 12'o2106;
    lut[9'o51_6] = 12'o2415;
    lut[9'o51_7] = 12'o2724;
    lut[9'o52_0] = 12'o0155;
    lut[9'o52_1] = 12'o0510;
    lut[9'o52_2] = 12'o1043;
    lut[9'o52_3] = 12'o1376;
    lut[9'o52_4] = 12'o1731;
    lut[9'o52_5] = 12'o2264;
    lut[9'o52_6] = 12'o2617;
    lut[9'o52_7] = 12'o3152;
    lut[9'o53_0] = 12'o0170;
    lut[9'o53_1] = 12'o0551;
    lut[9'o53_2] = 12'o1131;
    lut[9'o53_3] = 12'o1512;
    lut[9'o53_4] = 12'o2073;
    lut[9'o53_5] = 12'o2454;
    lut[9'o53_6] = 12'o3034;
    lut[9'o53_7] = 12'o3415;
    lut[9'o54_0] = 12'o0204;
    lut[9'o54_1] = 12'o0615;
    lut[9'o54_2] = 12'o1226;
    lut[9'o54_3] = 12'o1637;
    lut[9'o54_4] = 12'o2250;
    lut[9'o54_5] = 12'o2661;
    lut[9'o54_6] = 12'o3272;
    lut[9'o54_7] = 12'o3703;
    lut[9'o55_0] = 12'o0221;
    lut[9'o55_1] = 12'o0665;
    lut[9'o55_2] = 12'o1330;
    lut[9'o55_3] = 12'o1774;  // Not sure if these should clip at 11 bits or not
    lut[9'o55_4] = 12'o2437;
    lut[9'o55_5] = 12'o3103;
    lut[9'o55_6] = 12'o3546;
    lut[9'o55_7] = 12'o4212;  //12'o3777; 
    lut[9'o56_0] = 12'o0240;
    lut[9'o56_1] = 12'o0740;
    lut[9'o56_2] = 12'o1441;
    lut[9'o56_3] = 12'o2141;
    lut[9'o56_4] = 12'o2642;
    lut[9'o56_5] = 12'o3342;
    lut[9'o56_6] = 12'o4043;
    lut[9'o56_7] = 12'o4543;  //12'o3777; lut[9'o56_7] = 12'o3777; 
    lut[9'o57_0] = 12'o0260;
    lut[9'o57_1] = 12'o1021;
    lut[9'o57_2] = 12'o1561;
    lut[9'o57_3] = 12'o2322;
    lut[9'o57_4] = 12'o3063;
    lut[9'o57_5] = 12'o3624;
    lut[9'o57_6] = 12'o4364;
    lut[9'o57_7] = 12'o5125;  //12'o3777; lut[9'o57_7] = 12'o3777;  
    lut[9'o60_0] = 12'o0302;
    lut[9'o60_1] = 12'o1106;
    lut[9'o60_2] = 12'o1712;
    lut[9'o60_3] = 12'o2516;
    lut[9'o60_4] = 12'o3322;
    lut[9'o60_5] = 12'o4126;
    lut[9'o60_6] = 12'o4732;
    lut[9'o60_7] = 12'o5536;  //12'o3777; lut[9'o60_6] = 12'o3777; lut[9'o60_7] = 12'o3777; 
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) inc <= 'd0;
    else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          inc <= auto_ss_data_in[11:0];
        end
        default: begin
        end
      endcase
    end else if (cen) inc <= lut[addr];
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[12-1:0] = inc;
          auto_ss_ack              = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm
module jt10_adpcm (
    input rst_n,
    input clk,  // CPU clock
    input cen,  // optional clock enable, if not needed leave as 1'b1
    input [3:0] data,
    input chon,  // high if this channel is on
    input clr,
    output signed [15:0] pcm,
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_local_ack | auto_ss_u_lut_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_lut_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_lut_ack;

  wire  [31:0] auto_ss_u_lut_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  localparam sigw = 12;

  reg signed [sigw-1:0] x1, x2, x3, x4, x5, x6;
  reg signed [sigw-1:0] inc4;
  reg [5:0] step1, step2, step6, step3, step4, step5;
  reg [5:0] step_next, step_1p;
  reg sign2, sign3, sign4, sign5, xsign5;

  // All outputs from stage 1
  assign pcm = {{16 - sigw{x1[sigw-1]}}, x1};

  // This could be decomposed in more steps as the pipeline
  // has room for it
  always @(*) begin
    casez (data[2:0])
      3'b0??: step_next = step1 == 6'd0 ? 6'd0 : (step1 - 1'd1);
      3'b100: step_next = step1 + 6'd2;
      3'b101: step_next = step1 + 6'd5;
      3'b110: step_next = step1 + 6'd7;
      3'b111: step_next = step1 + 6'd9;
    endcase
    step_1p = step_next > 6'd48 ? 6'd48 : step_next;
  end

  wire [11:0] inc3;
  reg  [ 8:0] lut_addr2;


  jt10_adpcma_lut u_lut (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .cen                    (cen),
      .addr                   (lut_addr2),
      .inc                    (inc3),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_lut_data_out),
      .auto_ss_ack            (auto_ss_u_lut_ack)

  );

  // Original pipeline: 6 stages, 6 channels take 36 clock cycles
  // 8 MHz -> /12 divider -> 666 kHz
  // 666 kHz -> 18.5 kHz = 55.5/3 kHz

  reg chon2, chon3, chon4;
  wire [sigw-1:0] inc3_long = {{sigw - 12{1'b0}}, inc3};

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      x1        <= 'd0;
      step1     <= 0;
      x2        <= 'd0;
      step2     <= 0;
      x3        <= 'd0;
      step3     <= 0;
      x4        <= 'd0;
      step4     <= 0;
      x5        <= 'd0;
      step5     <= 0;
      x6        <= 'd0;
      step6     <= 0;
      sign2     <= 'b0;
      chon2     <= 'b0;
      chon3     <= 'b0;
      chon4     <= 'b0;
      lut_addr2 <= 'd0;
      inc4      <= 'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          lut_addr2 <= auto_ss_data_in[8:0];
          step1     <= auto_ss_data_in[14:9];
          step2     <= auto_ss_data_in[20:15];
          step3     <= auto_ss_data_in[26:21];
        end
        1: begin
          step4 <= auto_ss_data_in[5:0];
          step5 <= auto_ss_data_in[11:6];
          step6 <= auto_ss_data_in[17:12];
          chon2 <= auto_ss_data_in[18];
          chon3 <= auto_ss_data_in[19];
          chon4 <= auto_ss_data_in[20];
          sign2 <= auto_ss_data_in[21];
          sign3 <= auto_ss_data_in[22];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      // I
      sign2     <= data[3];
      x2        <= clr ? {sigw{1'b0}} : x1;
      step2     <= clr ? 6'd0 : (chon ? step_1p : step1);
      chon2     <= ~clr && chon;
      lut_addr2 <= {step1, data[2:0]};
      // II 2's complement of inc2 if necessary
      sign3     <= sign2;
      x3        <= x2;
      step3     <= step2;
      chon3     <= chon2;
      // III
      //sign4     <= sign3;
      inc4      <= sign3 ? ~inc3_long + 1'd1 : inc3_long;
      x4        <= x3;
      step4     <= step3;
      chon4     <= chon3;
      // IV
      //sign5     <= sign4;
      //xsign5    <= x4[sigw-1];
      x5        <= chon4 ? x4 + inc4 : x4;
      step5     <= step4;
      // V
      x6        <= x5;
      step6     <= step5;
      // VI: close the loop
      x1        <= x6;
      step1     <= step6;
    end
  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[26:0] = {step3, step2, step1, lut_addr2};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[22:0] = {sign3, sign2, chon4, chon3, chon2, step6, step5, step4};
          auto_ss_local_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_gain
module jt10_adpcm_gain (
    input       rst_n,
    input       clk,     // CPU clock
    input       cen,     // 666 kHz
    // pipeline channel
    input [5:0] cur_ch,
    input [5:0] en_ch,
    input       match,

    input         [ 5:0] atl,                      // ADPCM Total Level
    // Gain update
    input         [ 7:0] lracl,
    input         [ 2:0] up_ch,
    // Data
    output        [ 1:0] lr,
    input  signed [15:0] pcm_in,
    output signed [15:0] pcm_att,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [9:0] lin_5b, lin1, lin2, lin6;
  reg [7:0] lracl1, lracl2, lracl3, lracl4, lracl5, lracl6;
  reg [6:0] db5;
  reg [5:0] up_ch_dec;
  reg [3:0] sh1, sh6;

  always @(*)
    case (up_ch)
      3'd0: up_ch_dec = 6'b000_001;
      3'd1: up_ch_dec = 6'b000_010;
      3'd2: up_ch_dec = 6'b000_100;
      3'd3: up_ch_dec = 6'b001_000;
      3'd4: up_ch_dec = 6'b010_000;
      3'd5: up_ch_dec = 6'b100_000;
      default: up_ch_dec = 6'd0;
    endcase

  //wire [5:0] en_ch2 = { en_ch[4:0], en_ch[5] }; // shift the bits to fit in the pipeline slot correctly

  always @(*)
    case (db5[2:0])
      3'd0: lin_5b = 10'd512;
      3'd1: lin_5b = 10'd470;
      3'd2: lin_5b = 10'd431;
      3'd3: lin_5b = 10'd395;
      3'd4: lin_5b = 10'd362;
      3'd5: lin_5b = 10'd332;
      3'd6: lin_5b = 10'd305;
      3'd7: lin_5b = 10'd280;
    endcase


  // dB to linear conversion
  assign lr = lracl1[7:6];

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      lracl1 <= 8'd0;
      lracl2 <= 8'd0;
      lracl3 <= 8'd0;
      lracl4 <= 8'd0;
      lracl5 <= 8'd0;
      lracl6 <= 8'd0;
      db5    <= 'd0;
      sh1    <= 4'd0;
      sh6    <= 4'd0;
      lin1   <= 10'd0;
      lin6   <= 10'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        3: begin
          lin1 <= auto_ss_data_in[9:0];
          lin6 <= auto_ss_data_in[19:10];
        end
        4: begin
          lracl1 <= auto_ss_data_in[7:0];
          lracl2 <= auto_ss_data_in[15:8];
          lracl3 <= auto_ss_data_in[23:16];
          lracl4 <= auto_ss_data_in[31:24];
        end
        5: begin
          lracl5 <= auto_ss_data_in[7:0];
          lracl6 <= auto_ss_data_in[15:8];
          db5    <= auto_ss_data_in[22:16];
          sh1    <= auto_ss_data_in[26:23];
          sh6    <= auto_ss_data_in[30:27];
        end
        default: begin
        end
      endcase
    end else if (cen) begin

      // I
      lracl2 <= up_ch_dec == cur_ch ? lracl : lracl1;
      // II
      lracl3 <= lracl2;
      // III
      lracl4 <= lracl3;
      // IV: new data is accepted here
      lracl5 <= lracl4;
      db5    <= {2'b0, ~lracl4[4:0]} + {1'b0, ~atl};
      // V
      lracl6 <= lracl5;
      lin6   <= lin_5b;
      sh6    <= db5[6:3];
      // VI close the loop
      lracl1 <= lracl6;
      lin1   <= sh6[3] ? 10'h0 : lin6;
      sh1    <= sh6;
    end

  // Apply gain
  // The pipeline has 6 stages, there is new input data once every 6*6=36 clock cycles
  // New data is read once and it takes 4*6 cycles to get through because the shift
  // operation is distributed among several iterations. This prevents the need of
  // a 10x16-input mux which is very large. Instead of that, this uses two 10x2-input mux'es
  // which iterated allow the max 16 shift operation

  reg [3:0] shcnt1, shcnt2, shcnt3, shcnt4, shcnt5, shcnt6;

  reg shcnt_mod3, shcnt_mod4, shcnt_mod5;
  reg         [31:0] pcm2_mul;
  wire signed [15:0] lin2s = {6'b0, lin2};
  reg signed [15:0] pcm1, pcm2, pcm3, pcm4, pcm5, pcm6;
  reg match2;

  always @(*) begin
    shcnt_mod3 = shcnt3 != 0;
    shcnt_mod4 = shcnt4 != 0;
    shcnt_mod5 = shcnt5 != 0;
    pcm2_mul   = pcm2 * lin2s;
  end

  assign pcm_att = pcm1;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pcm1   <= 'd0;
      pcm2   <= 'd0;
      pcm3   <= 'd0;
      pcm4   <= 'd0;
      pcm5   <= 'd0;
      pcm6   <= 'd0;
      shcnt1 <= 'd0;
      shcnt2 <= 'd0;
      shcnt3 <= 'd0;
      shcnt4 <= 'd0;
      shcnt5 <= 'd0;
      shcnt6 <= 'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pcm1 <= auto_ss_data_in[15:0];
          pcm2 <= auto_ss_data_in[31:16];
        end
        1: begin
          pcm3 <= auto_ss_data_in[15:0];
          pcm4 <= auto_ss_data_in[31:16];
        end
        2: begin
          pcm5 <= auto_ss_data_in[15:0];
          pcm6 <= auto_ss_data_in[31:16];
        end
        3: begin
          lin2 <= auto_ss_data_in[29:20];
        end
        6: begin
          shcnt1 <= auto_ss_data_in[3:0];
          shcnt2 <= auto_ss_data_in[7:4];
          shcnt3 <= auto_ss_data_in[11:8];
          shcnt4 <= auto_ss_data_in[15:12];
          shcnt5 <= auto_ss_data_in[19:16];
          shcnt6 <= auto_ss_data_in[23:20];
          match2 <= auto_ss_data_in[24];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      // I
      pcm2   <= match ? pcm_in : pcm1;
      lin2   <= lin1;
      shcnt2 <= match ? sh1 : shcnt1;
      match2 <= match;
      // II
      pcm3   <= match2 ? pcm2_mul[24:9] : pcm2;
      shcnt3 <= shcnt2;
      // III, shift by 0 or 1
      if (shcnt_mod3) begin
        pcm4   <= pcm3 >>> 1;
        shcnt4 <= shcnt3 - 1'd1;
      end else begin
        pcm4   <= pcm3;
        shcnt4 <= shcnt3;
      end
      // IV, shift by 0 or 1
      if (shcnt_mod4) begin
        pcm5   <= pcm4 >>> 1;
        shcnt5 <= shcnt4 - 1'd1;
      end else begin
        pcm5   <= pcm4;
        shcnt5 <= shcnt4;
      end
      // V, shift by 0 or 1
      if (shcnt_mod5) begin
        pcm6   <= pcm5 >>> 1;
        shcnt6 <= shcnt5 - 1'd1;
      end else begin
        pcm6   <= pcm5;
        shcnt6 <= shcnt5;
      end
      // VI close the loop and output
      pcm1   <= pcm6;
      shcnt1 <= shcnt6;
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[31:0] = {pcm2, pcm1};
          auto_ss_ack            = 1'b1;
        end
        1: begin
          auto_ss_data_out[31:0] = {pcm4, pcm3};
          auto_ss_ack            = 1'b1;
        end
        2: begin
          auto_ss_data_out[31:0] = {pcm6, pcm5};
          auto_ss_ack            = 1'b1;
        end
        3: begin
          auto_ss_data_out[29:0] = {lin2, lin6, lin1};
          auto_ss_ack            = 1'b1;
        end
        4: begin
          auto_ss_data_out[31:0] = {lracl4, lracl3, lracl2, lracl1};
          auto_ss_ack            = 1'b1;
        end
        5: begin
          auto_ss_data_out[30:0] = {sh6, sh1, db5, lracl6, lracl5};
          auto_ss_ack            = 1'b1;
        end
        6: begin
          auto_ss_data_out[24:0] = {match2, shcnt6, shcnt5, shcnt4, shcnt3, shcnt2, shcnt1};
          auto_ss_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_acc
module jt10_adpcm_acc (
    input       rst_n,
    input       clk,     // CPU clock
    input       cen,     // 111 kHz
    // pipeline channel
    input [5:0] cur_ch,
    input [5:0] en_ch,
    input       match,

    input                    en_sum,
    input  signed     [15:0] pcm_in,                   // 18.5 kHz
    output reg signed [15:0] pcm_out,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input             [31:0] auto_ss_data_in,
    input             [ 7:0] auto_ss_device_idx,
    input             [15:0] auto_ss_state_idx,
    input             [ 7:0] auto_ss_base_device_idx,
    output logic      [31:0] auto_ss_data_out,
    output logic             auto_ss_ack
    // 55.5 kHz
);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  wire signed [17:0] pcm_in_long = en_sum ? {{2{pcm_in[15]}}, pcm_in} : 18'd0;
  reg signed [17:0] acc, last, pcm_full;
  reg signed [17:0] step;

  reg signed [17:0] diff;
  reg signed [22:0] diff_ext, step_full;

  always @(*) begin
    diff = acc - last;
    diff_ext = {{5{diff[17]}}, diff};
    step_full = diff_ext  // 1/128
    + (diff_ext << 1)  // 1/64
    + (diff_ext << 3)  // 1/16
    + (diff_ext << 5);  // 1/4

  end

  wire adv = en_ch[0] & cur_ch[0];

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      step <= 'd0;
      acc  <= 18'd0;
      last <= 18'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          acc <= auto_ss_data_in[17:0];
        end
        1: begin
          last <= auto_ss_data_in[17:0];
        end
        2: begin
          step <= auto_ss_data_in[17:0];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      if (match) acc <= cur_ch[0] ? pcm_in_long : (pcm_in_long + acc);
      if (adv) begin
        // step = diff * (1/4+1/16+1/64+1/128)
        step <= {{2{step_full[22]}}, step_full[22:7]};  // >>>7;
        last <= acc;
      end
    end
  wire overflow = |pcm_full[17:15] & ~&pcm_full[17:15];

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pcm_full <= 18'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        3: begin
          pcm_full <= auto_ss_data_in[17:0];
        end
        4: begin
          pcm_out <= auto_ss_data_in[15:0];
        end
        default: begin
        end
      endcase
    end else if (cen && cur_ch[0]) begin
      case (en_ch)
        6'b000_001: pcm_full <= last;
        6'b000_100, 6'b010_000: pcm_full <= pcm_full + step;
        default: ;
      endcase
      if (overflow) pcm_out <= pcm_full[17] ? 16'h8000 : 16'h7fff;  // saturate
      else pcm_out <= pcm_full[15:0];
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[18-1:0] = acc;
          auto_ss_ack              = 1'b1;
        end
        1: begin
          auto_ss_data_out[18-1:0] = last;
          auto_ss_ack              = 1'b1;
        end
        2: begin
          auto_ss_data_out[18-1:0] = step;
          auto_ss_ack              = 1'b1;
        end
        3: begin
          auto_ss_data_out[18-1:0] = pcm_full;
          auto_ss_ack              = 1'b1;
        end
        4: begin
          auto_ss_data_out[16-1:0] = pcm_out;
          auto_ss_ack              = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_drvA
module jt10_adpcm_drvA (
    input rst_n,
    input clk,    // CPU clock
    input cen,    // same cen as MMR
    input cen6,   // clk & cen = 666 kHz
    input cen1,   // clk & cen = 111 kHz

    output [19:0] addr,  // real hardware has 10 pins multiplexed through RMPX pin
    output [ 3:0] bank,
    output        roe_n, // ADPCM-A ROM output enable

    // Control Registers
    input [ 5:0] atl,       // ADPCM Total Level
    input [ 7:0] lracl_in,
    input [15:0] addr_in,

    input [2:0] up_lracl,
    input       up_start,
    input       up_end,
    input [2:0] up_addr,

    input [7:0] aon_cmd,  // ADPCM ON equivalent to key on for FM
    input       up_aon,

    input [7:0] datain,

    // Flags
    output [5:0] flags,
    input  [5:0] clr_flags,

    output signed [15:0] pcm55_l,
    output signed [15:0] pcm55_r,
    input         [ 5:0] ch_enable,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_cnt_ack | auto_ss_u_decoder_ack | auto_ss_u_gain_ack | auto_ss_u_acc_left_ack | auto_ss_u_acc_right_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_cnt_data_out | auto_ss_u_decoder_data_out | auto_ss_u_gain_data_out | auto_ss_u_acc_left_data_out | auto_ss_u_acc_right_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_acc_right_ack;

  wire  [31:0] auto_ss_u_acc_right_data_out;

  wire         auto_ss_u_acc_left_ack;

  wire  [31:0] auto_ss_u_acc_left_data_out;

  wire         auto_ss_u_gain_ack;

  wire  [31:0] auto_ss_u_gain_data_out;

  wire         auto_ss_u_decoder_ack;

  wire  [31:0] auto_ss_u_decoder_data_out;

  wire         auto_ss_u_cnt_ack;

  wire  [31:0] auto_ss_u_cnt_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg         [ 5:0] cur_ch;
  reg         [ 5:0] en_ch;
  reg         [ 3:0] data;
  wire               nibble_sel;
  wire signed [15:0] pcm_att;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      data <= 4'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          data <= auto_ss_data_in[3:0];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      data <= !nibble_sel ? datain[7:4] : datain[3:0];
    end

  reg [5:0] aon_sr, aoff_sr;

  reg [7:0] aon_cmd_cpy;

  always @(posedge clk) begin
    if (cen) begin
      if (up_aon) aon_cmd_cpy <= aon_cmd;
      else if (cur_ch[5] && cen6) aon_cmd_cpy <= 8'd0;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          aon_cmd_cpy <= auto_ss_data_in[7:0];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk) begin
    if (cen6) begin
      if (cur_ch[5]) begin
        aon_sr  <= ~{6{aon_cmd_cpy[7]}} & aon_cmd_cpy[5:0];
        aoff_sr <= {6{aon_cmd_cpy[7]}} & aon_cmd_cpy[5:0];
      end else begin
        aon_sr  <= {1'b0, aon_sr[5:1]};
        aoff_sr <= {1'b0, aoff_sr[5:1]};
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          aoff_sr <= auto_ss_data_in[13:8];
          aon_sr  <= auto_ss_data_in[19:14];
        end
        default: begin
        end
      endcase
    end
  end



  reg        match;  // high when cur_ch==en_ch, but calculated one clock cycle ahead
  // so it can be latched
  wire [5:0] cur_next = {cur_ch[4:0], cur_ch[5]};
  wire [5:0] en_next = {en_ch[0], en_ch[5:1]};

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      cur_ch <= 6'b1;
      en_ch  <= 6'b1;
      match  <= 0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cur_ch <= auto_ss_data_in[25:20];
          en_ch  <= auto_ss_data_in[31:26];
        end
        1: begin
          match <= auto_ss_data_in[4];
        end
        default: begin
        end
      endcase
    end else if (cen6) begin
      cur_ch <= cur_next;
      if (cur_ch[5]) en_ch <= en_next;
      match <= cur_next == (cur_ch[5] ? en_next : en_ch);
    end
  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[31:0] = {en_ch, cur_ch, aon_sr, aoff_sr, aon_cmd_cpy};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[4:0] = {match, data};
          auto_ss_local_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  wire [15:0] start_top, end_top;

  wire clr_dec, decon;

  jt10_adpcm_cnt u_cnt (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen6),
      // Pipeline
      .cur_ch                 (cur_ch),
      .en_ch                  (en_ch),
      // START/END update
      .addr_in                (addr_in),
      .addr_ch                (up_addr),
      .up_start               (up_start),
      .up_end                 (up_end),
      // Control
      .aon                    (aon_sr[0]),
      .aoff                   (aoff_sr[0]),
      .clr                    (clr_dec),
      // ROM driver
      .addr_out               (addr),
      .bank                   (bank),
      .sel                    (nibble_sel),
      .roe_n                  (roe_n),
      .decon                  (decon),
      // Flags
      .flags                  (flags),
      .clr_flags              (clr_flags),
      .start_top              (start_top),
      .end_top                (end_top),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_cnt_data_out),
      .auto_ss_ack            (auto_ss_u_cnt_ack)

  );

  // wire chactive = chon & cen6;
  wire signed [15:0] pcmdec;

  jt10_adpcm u_decoder (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen6),
      .data                   (data),
      .chon                   (decon),
      .clr                    (clr_dec),
      .pcm                    (pcmdec),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_decoder_data_out),
      .auto_ss_ack            (auto_ss_u_decoder_ack)

  );
  /*

always @(posedge clk) begin
    if( cen3 && chon ) begin
        pcm55_l <= pre_pcm55_l;
        pcm55_r <= pre_pcm55_r;
    end
end
*/

  wire [1:0] lr;

  jt10_adpcm_gain u_gain (
      .rst_n (rst_n),
      .clk   (clk),
      .cen   (cen6),
      // Pipeline
      .cur_ch(cur_ch),
      .en_ch (en_ch),
      .match (match),
      // Gain control
      .atl   (atl),       // ADPCM Total Level
      .lracl (lracl_in),
      .up_ch (up_lracl),

      .lr                     (lr),
      .pcm_in                 (pcmdec),
      .pcm_att                (pcm_att),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 4),
      .auto_ss_data_out       (auto_ss_u_gain_data_out),
      .auto_ss_ack            (auto_ss_u_gain_ack)

  );

  wire signed [15:0] pre_pcm55_l, pre_pcm55_r;

  assign pcm55_l = pre_pcm55_l;
  assign pcm55_r = pre_pcm55_r;

  jt10_adpcm_acc u_acc_left (
      .rst_n (rst_n),
      .clk   (clk),
      .cen   (cen6),
      // Pipeline
      .cur_ch(cur_ch),
      .en_ch (en_ch),
      .match (match),
      // left/right enable
      .en_sum(lr[1] & |(ch_enable & cur_ch)),

      .pcm_in                 (pcm_att),                      // 18.5 kHz
      .pcm_out                (pre_pcm55_l),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
      .auto_ss_data_out       (auto_ss_u_acc_left_data_out),
      .auto_ss_ack            (auto_ss_u_acc_left_ack)
      // 55.5 kHz
  );

  jt10_adpcm_acc u_acc_right (
      .rst_n (rst_n),
      .clk   (clk),
      .cen   (cen6),
      // Pipeline
      .cur_ch(cur_ch),
      .en_ch (en_ch),
      .match (match),
      // left/right enable
      .en_sum(lr[0] & |(ch_enable & cur_ch)),

      .pcm_in                 (pcm_att),                       // 18.5 kHz
      .pcm_out                (pre_pcm55_r),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 6),
      .auto_ss_data_out       (auto_ss_u_acc_right_data_out),
      .auto_ss_ack            (auto_ss_u_acc_right_ack)
      // 55.5 kHz
  );




endmodule


///////////////////////////////////////////
// MODULE jt10_adpcmb_cnt
module jt10_adpcmb_cnt (
    input rst_n,
    input clk,    // CPU clock
    input cen,    // clk & cen = 55 kHz

    // counter control
    input      [15:0] delta_n,
    input             clr,
    input             on,
    input             acmd_up_b,
    // Address
    input      [15:0] astart,
    input      [15:0] aend,
    input             arepeat,
    output reg [23:0] addr,
    output reg        nibble_sel,
    // Flag
    output reg        chon,
    output reg        flag,
    input             clr_flag,
    output reg        clr_dec,

    output reg          adv,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  // Counter
  reg [15:0] cnt;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      cnt <= 'd0;
      adv <= 'b0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          cnt <= auto_ss_data_in[15:0];
          adv <= auto_ss_data_in[16];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      if (clr) begin
        cnt <= 'd0;
        adv <= 'b0;
      end else begin
        if (on) {adv, cnt} <= {1'b0, cnt} + {1'b0, delta_n};
        else begin
          cnt <= 'd0;
          adv <= 1'b1;  // let the rest of the signal chain advance
          // when channel is off so all registers go to reset values
        end
      end
    end

  reg set_flag, last_set;
  reg restart;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      flag     <= 1'b0;
      last_set <= 'b0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          flag     <= auto_ss_data_in[17];
          last_set <= auto_ss_data_in[18];
        end
        default: begin
        end
      endcase
    end else begin
      last_set <= set_flag;
      if (clr_flag) flag <= 1'b0;
      if (!last_set && set_flag) flag <= 1'b1;
    end

  // Address
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      addr       <= 'd0;
      nibble_sel <= 'b0;
      set_flag   <= 'd0;
      chon       <= 'b0;
      restart    <= 'b0;
      clr_dec    <= 'b1;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          addr <= auto_ss_data_in[23:0];
        end
        1: begin
          chon       <= auto_ss_data_in[19];
          clr_dec    <= auto_ss_data_in[20];
          nibble_sel <= auto_ss_data_in[21];
          restart    <= auto_ss_data_in[22];
          set_flag   <= auto_ss_data_in[23];
        end
        default: begin
        end
      endcase
    end else if (!on || clr) begin
      restart <= 'd0;
      chon    <= 'd0;
      clr_dec <= 'd1;
    end else if (acmd_up_b && on) begin
      restart <= 'd1;
    end else if (cen) begin
      if (restart && adv) begin
        addr       <= {astart, 8'd0};
        nibble_sel <= 'b0;
        restart    <= 'd0;
        chon       <= 'd1;
        clr_dec    <= 'd0;
      end else if (chon && adv) begin
        if ({addr, nibble_sel} != {aend, 8'hFF, 1'b1}) begin
          {addr, nibble_sel} <= {addr, nibble_sel} + 25'd1;
          set_flag           <= 'd0;
        end else if (arepeat) begin
          restart <= 'd1;
          clr_dec <= 'd1;
        end else begin
          set_flag <= 'd1;
          chon     <= 'd0;
          clr_dec  <= 'd1;
        end
      end
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[24-1:0] = addr;
          auto_ss_ack              = 1'b1;
        end
        1: begin
          auto_ss_data_out[23:0] = {
            set_flag, restart, nibble_sel, clr_dec, chon, last_set, flag, adv, cnt
          };
          auto_ss_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end

  // cen


endmodule


///////////////////////////////////////////
// MODULE jt10_adpcmb
module jt10_adpcmb (
    input rst_n,
    input clk,  // CPU clock
    input cen,  // optional clock enable, if not needed leave as 1'b1
    input [3:0] data,
    input chon,  // high if this channel is on
    input adv,
    input clr,
    output signed [15:0] pcm,
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  localparam stepw = 15, xw = 16;

  reg signed [xw-1:0] x1, next_x5;
  reg [stepw-1:0] step1;
  reg [stepw+1:0] next_step3;
  assign pcm = x1[xw-1:xw-16];

  wire [xw-1:0] limpos = {1'b0, {xw - 1{1'b1}}};
  wire [xw-1:0] limneg = {1'b1, {xw - 1{1'b0}}};

  reg  [  18:0] d2l;
  reg [xw-1:0] d3, d4;
  reg [ 3:0] d2;
  reg [ 7:0] step_val;
  reg [22:0] step2l;

  always @(*) begin
    casez (d2[3:1])
      3'b0_??: step_val = 8'd57;
      3'b1_00: step_val = 8'd77;
      3'b1_01: step_val = 8'd102;
      3'b1_10: step_val = 8'd128;
      3'b1_11: step_val = 8'd153;
    endcase
    d2l    = d2 * step1;  // 4 + 15 = 19 bits -> div by 8 -> 16 bits
    step2l = step_val * step1;  // 15 bits + 8 bits = 23 bits -> div 64 -> 17 bits
  end

  // Original pipeline: 6 stages, 6 channels take 36 clock cycles
  // 8 MHz -> /12 divider -> 666 kHz
  // 666 kHz -> 18.5 kHz = 55.5/3 kHz

  reg [3:0] data2;
  reg sign_data2, sign_data3, sign_data4, sign_data5;

  reg  [3:0] adv2;
  reg        need_clr;

  wire [3:0] data_use = clr || ~chon ? 4'd0 : data;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      x1       <= 'd0;
      step1    <= 'd127;
      d2       <= 'd0;
      d3       <= 'd0;
      d4       <= 'd0;
      need_clr <= 0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          adv2       <= auto_ss_data_in[3:0];
          d2         <= auto_ss_data_in[7:4];
          need_clr   <= auto_ss_data_in[8];
          sign_data2 <= auto_ss_data_in[9];
          sign_data3 <= auto_ss_data_in[10];
          sign_data4 <= auto_ss_data_in[11];
          sign_data5 <= auto_ss_data_in[12];
        end
        default: begin
        end
      endcase
    end else begin
      if (clr) need_clr <= 1'd1;
      if (cen) begin
        adv2 <= {1'b0, adv2[3:1]};
        // I
        if (adv) begin
          d2         <= {data_use[2:0], 1'b1};
          sign_data2 <= data_use[3];
          adv2[3]    <= 1'b1;
        end
        // II multiply and obtain the offset
        d3         <= {{xw - 16{1'b0}}, d2l[18:3]};  // xw bits
        next_step3 <= step2l[22:6];
        sign_data3 <= sign_data2;
        // III 2's complement of d3 if necessary
        d4         <= sign_data3 ? ~d3 + 1'd1 : d3;
        sign_data4 <= sign_data3;
        // IV   Advance the waveform
        next_x5    <= x1 + d4;
        sign_data5 <= sign_data4;
        // V: limit or reset outputs
        if (chon) begin  // update values if needed
          if (adv2[0]) begin
            if (sign_data5 == x1[xw-1] && (x1[xw-1] != next_x5[xw-1]))
              x1 <= x1[xw-1] ? limneg : limpos;
            else x1 <= next_x5;

            if (next_step3 < 127) step1 <= 15'd127;
            else if (next_step3 > 24576) step1 <= 15'd24576;
            else step1 <= next_step3[14:0];
          end
        end else begin
          x1    <= 'd0;
          step1 <= 'd127;
        end
        if (need_clr) begin
          x1         <= 'd0;
          step1      <= 'd127;
          next_step3 <= 'd127;
          d2         <= 'd0;
          d3         <= 'd0;
          d4         <= 'd0;
          next_x5    <= 'd0;
          need_clr   <= 1'd0;
        end
      end
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[12:0] = {
            sign_data5, sign_data4, sign_data3, sign_data2, need_clr, d2, adv2
          };
          auto_ss_ack = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_div
module jt10_adpcm_div #(
    parameter DW = 16
) (
    input                 rst_n,
    input                 clk,                      // CPU clock
    input                 cen,
    input                 start,                    // strobe
    input        [DW-1:0] a,
    input        [DW-1:0] b,
    output reg   [DW-1:0] d,
    output reg   [DW-1:0] r,
    output                working,
    input                 auto_ss_rd,
    input                 auto_ss_wr,
    input        [  31:0] auto_ss_data_in,
    input        [   7:0] auto_ss_device_idx,
    input        [  15:0] auto_ss_state_idx,
    input        [   7:0] auto_ss_base_device_idx,
    output logic [  31:0] auto_ss_data_out,
    output logic          auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [DW-1:0] cycle;
  assign working = cycle[0];

  wire [DW:0] sub = {r[DW-2:0], d[DW-1]} - b;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      cycle <= 'd0;
    end else
    if (auto_ss_wr && device_match) begin
    end else if (cen) begin
      if (start) begin
        cycle <= {DW{1'b1}};
        r     <= 0;
        d     <= a;
      end else if (cycle[0]) begin
        cycle <= {1'b0, cycle[DW-1:1]};
        if (sub[DW] == 0) begin
          r <= sub[DW-1:0];
          d <= {d[DW-2:0], 1'b1};
        end else begin
          r <= {r[DW-2:0], d[DW-1]};
          d <= {d[DW-2:0], 1'b0};
        end
      end
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcmb_interpol
module jt10_adpcmb_interpol (
    input                rst_n,
    input                clk,
    input                cen,                      // 8MHz cen
    input                cen55,                    // clk & cen55  =  55 kHz
    input                adv,
    input  signed [15:0] pcmdec,
    output signed [15:0] pcmout,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_local_ack | auto_ss_u_div_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_div_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_div_ack;

  wire  [31:0] auto_ss_u_div_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  localparam stages = 6;

  reg signed [15:0] pcmlast, delta_x;
  reg signed [16:0] pre_dx;
  reg               start_div = 1'b0;
  reg [3:0] deltan, pre_dn;
  reg        [stages-1:0] adv2;
  reg signed [      15:0] pcminter;
  wire       [      15:0] next_step;
  reg        [      15:0] step;
  reg step_sign, next_step_sign;

  assign pcmout = pcminter;

  always @(posedge clk) begin
    if (cen) begin
      adv2 <= {adv2[stages-2:0], cen55 & adv};  // give some time to get the data from memory
    end
    if (auto_ss_wr && device_match) begin
    end
  end



  always @(posedge clk) begin
    if (cen55) begin
      if (adv) begin
        pre_dn <= 'd1;
        deltan <= pre_dn;
      end else if (pre_dn != 4'hF) pre_dn <= pre_dn + 1'd1;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        3: begin
          deltan <= auto_ss_data_in[3:0];
          pre_dn <= auto_ss_data_in[7:4];
        end
        default: begin
        end
      endcase
    end
  end




  always @(posedge clk) begin
    if (cen) begin
      start_div <= 1'b0;
      if (adv2[1]) begin
        pcmlast <= pcmdec;
      end
      if (adv2[4]) begin
        pre_dx <= {pcmdec[15], pcmdec} - {pcmlast[15], pcmlast};
      end
      if (adv2[5]) begin
        start_div      <= 1'b1;
        delta_x        <= pre_dx[16] ? ~pre_dx[15:0] + 1'd1 : pre_dx[15:0];
        next_step_sign <= pre_dx[16];
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pre_dx <= auto_ss_data_in[16:0];
        end
        1: begin
          delta_x <= auto_ss_data_in[15:0];
          pcmlast <= auto_ss_data_in[31:16];
        end
        3: begin
          next_step_sign <= auto_ss_data_in[8];
          start_div      <= auto_ss_data_in[9];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk) begin
    if (cen55) begin
      if (adv) begin
        step      <= next_step;
        step_sign <= next_step_sign;
        pcminter  <= pcmlast;
      end else
        pcminter <= ( (pcminter < pcmlast) == step_sign ) ? pcminter : step_sign ? pcminter - step : pcminter + step;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        2: begin
          pcminter <= auto_ss_data_in[15:0];
          step     <= auto_ss_data_in[31:16];
        end
        3: begin
          step_sign <= auto_ss_data_in[10];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[17-1:0] = pre_dx;
          auto_ss_local_ack              = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[31:0] = {pcmlast, delta_x};
          auto_ss_local_ack            = 1'b1;
        end
        2: begin
          auto_ss_local_data_out[31:0] = {step, pcminter};
          auto_ss_local_ack            = 1'b1;
        end
        3: begin
          auto_ss_local_data_out[10:0] = {step_sign, start_div, next_step_sign, pre_dn, deltan};
          auto_ss_local_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt10_adpcm_div #(
      .DW(16)
  ) u_div (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen),
      .start                  (start_div),
      .a                      (delta_x),
      .b                      ({12'd0, deltan}),
      .d                      (next_step),
      .r                      (),
      .working                (),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_div_data_out),
      .auto_ss_ack            (auto_ss_u_div_ack)

  );


endmodule


///////////////////////////////////////////
// MODULE jt10_adpcmb_gain
module jt10_adpcmb_gain (
    input                    rst_n,
    input                    clk,                      // CPU clock
    input                    cen55,
    input             [ 7:0] tl,                       // ADPCM Total Level
    input  signed     [15:0] pcm_in,
    output reg signed [15:0] pcm_out,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input             [31:0] auto_ss_data_in,
    input             [ 7:0] auto_ss_device_idx,
    input             [15:0] auto_ss_state_idx,
    input             [ 7:0] auto_ss_base_device_idx,
    output logic      [31:0] auto_ss_data_out,
    output logic             auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  wire signed [15:0] factor = {8'd0, tl};
  wire signed [31:0] pcm_mul = pcm_in * factor;  // linear gain

  always @(posedge clk) begin
    if (cen55) pcm_out <= pcm_mul[23:8];
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pcm_out <= auto_ss_data_in[15:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[16-1:0] = pcm_out;
          auto_ss_ack              = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_adpcm_drvB
module jt10_adpcm_drvB (
    input             rst_n,
    input             clk,
    input             cen,         // 8MHz cen
    input             cen55,       // clk & cen55  =  55 kHz
    // Control
    input             acmd_on_b,   // Control - Process start, Key On
    input             acmd_rep_b,  // Control - Repeat
    input             acmd_rst_b,  // Control - Reset
    input             acmd_up_b,   // Control - New command received
    input      [ 1:0] alr_b,       // Left / Right
    input      [15:0] astart_b,    // Start address
    input      [15:0] aend_b,      // End   address
    input      [15:0] adeltan_b,   // Delta-N
    input      [ 7:0] aeg_b,       // Envelope Generator Control
    output            flag,
    input             clr_flag,
    // memory
    output     [23:0] addr,
    input      [ 7:0] data,
    output reg        roe_n,

    output reg signed [15:0] pcm55_l,
    output reg signed [15:0] pcm55_r,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input             [31:0] auto_ss_data_in,
    input             [ 7:0] auto_ss_device_idx,
    input             [15:0] auto_ss_state_idx,
    input             [ 7:0] auto_ss_base_device_idx,
    output logic      [31:0] auto_ss_data_out,
    output logic             auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_cnt_ack | auto_ss_u_decoder_ack | auto_ss_u_interpol_ack | auto_ss_u_gain_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_cnt_data_out | auto_ss_u_decoder_data_out | auto_ss_u_interpol_data_out | auto_ss_u_gain_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_gain_ack;

  wire  [31:0] auto_ss_u_gain_data_out;

  wire         auto_ss_u_interpol_ack;

  wire  [31:0] auto_ss_u_interpol_data_out;

  wire         auto_ss_u_decoder_ack;

  wire  [31:0] auto_ss_u_decoder_data_out;

  wire         auto_ss_u_cnt_ack;

  wire  [31:0] auto_ss_u_cnt_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  wire nibble_sel;
  wire adv;  // advance to next reading
  wire clr_dec;
  wire chon;

  // `ifdef SIMULATION
  // real fsample;
  // always @(posedge acmd_on_b) begin
  //     fsample = adeltan_b;
  //     fsample = fsample/65536;
  //     fsample = fsample * 55.5;
  //     $display("\nINFO: ADPCM-B ON: %X delta N = %6d (%2.1f kHz)", astart_b, adeltan_b, fsample );
  // end
  // `endif

  always @(posedge clk) begin
    roe_n <= ~(adv & cen55);
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          roe_n <= auto_ss_data_in[4];
        end
        default: begin
        end
      endcase
    end
  end



  jt10_adpcmb_cnt u_cnt (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen55),
      .delta_n                (adeltan_b),
      .acmd_up_b              (acmd_up_b),
      .clr                    (acmd_rst_b),
      .on                     (acmd_on_b),
      .astart                 (astart_b),
      .aend                   (aend_b),
      .arepeat                (acmd_rep_b),
      .addr                   (addr),
      .nibble_sel             (nibble_sel),
      // Flag control
      .chon                   (chon),
      .clr_flag               (clr_flag),
      .flag                   (flag),
      .clr_dec                (clr_dec),
      .adv                    (adv),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_cnt_data_out),
      .auto_ss_ack            (auto_ss_u_cnt_ack)

  );

  reg [3:0] din;

  always @(posedge clk) begin
    din <= !nibble_sel ? data[7:4] : data[3:0];
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          din <= auto_ss_data_in[3:0];
        end
        default: begin
        end
      endcase
    end
  end



  wire signed [15:0] pcmdec, pcminter, pcmgain;

  jt10_adpcmb u_decoder (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen),
      .adv                    (adv & cen55),
      .data                   (din),
      .chon                   (chon),
      .clr                    (clr_dec),
      .pcm                    (pcmdec),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_decoder_data_out),
      .auto_ss_ack            (auto_ss_u_decoder_ack)

  );


  jt10_adpcmb_interpol u_interpol (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (cen),
      .cen55                  (cen55 && chon),
      .adv                    (adv),
      .pcmdec                 (pcmdec),
      .pcmout                 (pcminter),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 3),
      .auto_ss_data_out       (auto_ss_u_interpol_data_out),
      .auto_ss_ack            (auto_ss_u_interpol_ack)

  );


  jt10_adpcmb_gain u_gain (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen55                  (cen55),
      .tl                     (aeg_b),
      .pcm_in                 (pcminter),
      .pcm_out                (pcmgain),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
      .auto_ss_data_out       (auto_ss_u_gain_data_out),
      .auto_ss_ack            (auto_ss_u_gain_ack)

  );

  always @(posedge clk) begin
    if (cen55) begin
      pcm55_l <= alr_b[1] ? pcmgain : 16'd0;
      pcm55_r <= alr_b[0] ? pcmgain : 16'd0;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pcm55_l <= auto_ss_data_in[15:0];
          pcm55_r <= auto_ss_data_in[31:16];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[31:0] = {pcm55_r, pcm55_l};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[4:0] = {roe_n, din};
          auto_ss_local_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_single_acc
module jt12_single_acc #(
    parameter win  = 14,  // input data width 
              wout = 16   // output data width
) (
    input                   clk,
    input                   clk_en  /* synthesis direct_enable */,
    input        [ win-1:0] op_result,
    input                   sum_en,
    input                   zero,
    output reg   [wout-1:0] snd,
    input                   auto_ss_rd,
    input                   auto_ss_wr,
    input        [    31:0] auto_ss_data_in,
    input        [     7:0] auto_ss_device_idx,
    input        [    15:0] auto_ss_state_idx,
    input        [     7:0] auto_ss_base_device_idx,
    output logic [    31:0] auto_ss_data_out,
    output logic            auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  // for full resolution use win=14, wout=16
  // for cut down resolution use win=9, wout=12
  // wout-win should be > 0

  reg signed [wout-1:0] next, acc, current;
  reg             overflow;

  wire [wout-1:0] plus_inf = {1'b0, {(wout - 1) {1'b1}}};  // maximum positive value
  wire [wout-1:0] minus_inf = {1'b1, {(wout - 1) {1'b0}}};  // minimum negative value

  always @(*) begin
    current  = sum_en ? {{(wout - win) {op_result[win-1]}}, op_result} : {wout{1'b0}};
    next     = zero ? current : current + acc;
    overflow = !zero && (current[wout-1] == acc[wout-1]) && (acc[wout-1] != next[wout-1]);
  end

  always @(posedge clk) begin
    if (clk_en) begin
      acc <= overflow ? (acc[wout-1] ? minus_inf : plus_inf) : next;
      if (zero) snd <= acc;
    end
    if (auto_ss_wr && device_match) begin
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt10_acc
module jt10_acc (
    input                clk,
    input                clk_en  /* synthesis direct_enable */,
    input  signed [13:0] op_result,
    input         [ 1:0] rl,
    input                zero,
    input                s1_enters,
    input                s2_enters,
    input                s3_enters,
    input                s4_enters,
    input         [ 2:0] cur_ch,
    input         [ 1:0] cur_op,
    input         [ 2:0] alg,
    input  signed [15:0] adpcmA_l,
    input  signed [15:0] adpcmA_r,
    input  signed [15:0] adpcmB_l,
    input  signed [15:0] adpcmB_r,
    // LOCAL CHANGE (Arcade-TaitoB): YM2610B has six FM channels instead of four.
    input                ym2610b,
    // combined output
    output signed [15:0] left,
    output signed [15:0] right,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_u_left_ack | auto_ss_u_right_ack;

  assign auto_ss_data_out = auto_ss_u_left_data_out | auto_ss_u_right_data_out;

  wire        auto_ss_u_right_ack;

  wire [31:0] auto_ss_u_right_data_out;

  wire        auto_ss_u_left_ack;

  wire [31:0] auto_ss_u_left_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg sum_en;

  always @(*) begin
    case (alg)
      default: sum_en = s4_enters;
      3'd4: sum_en = s2_enters | s4_enters;
      3'd5, 3'd6: sum_en = ~s1_enters;
      3'd7: sum_en = 1'b1;
    endcase
  end

  wire               left_en = rl[1];
  wire               right_en = rl[0];
  wire signed [15:0] opext = {{2{op_result[13]}}, op_result};

  // LOCAL CHANGE (Arcade-TaitoB): the YM2610 spends two accumulator slots on its ADPCM
  // streams, which is why it has four FM channels and not six. The YM2610B has all six AND
  // both ADPCM streams, so in that mode those slots carry the ADPCM value plus whatever FM
  // output the slot would otherwise have contributed. Mirrors rtl/jt12/hdl/jt10_acc.v; if
  // this file is ever regenerated the change comes back from there.
  wire signed [15:0] fm_extra_l = (ym2610b & sum_en & left_en) ? (opext >>> 1) : 16'sd0;
  wire signed [15:0] fm_extra_r = (ym2610b & sum_en & right_en) ? (opext >>> 1) : 16'sd0;
  reg signed [15:0] acc_input_l, acc_input_r;
  reg acc_en_l, acc_en_r;

  // YM2610 mode:
  // uses channels 0 and 4 for ADPCM data, throwing away FM data for those channels
  // reference: YM2610 Application Notes.
  always @(*)
    case ({
      cur_op, cur_ch
    })
      {
        2'd0, 3'd0
      } : begin  // ADPCM-A:
        acc_input_l = (adpcmA_l <<< 2) + (adpcmA_l <<< 1) + fm_extra_l;
        acc_input_r = (adpcmA_r <<< 2) + (adpcmA_r <<< 1) + fm_extra_r;

        acc_en_l    = 1'b1;
        acc_en_r    = 1'b1;

      end
      {
        2'd0, 3'd4
      } : begin  // ADPCM-B:
        acc_input_l = (adpcmB_l >>> 1) + fm_extra_l;  // Operator width 14 bit, ADPCM-B 16
        acc_input_r = (adpcmB_r >>> 1) + fm_extra_r;  // accumulator is 14 bit per input

        acc_en_l    = 1'b1;
        acc_en_r    = 1'b1;

      end
      default: begin
        // Note by Jose Tejada:
        // I don't think we should divide down the FM output
        // but someone was looking at the balance of the different
        // channels and made this arrangement
        // I suppose ADPCM-A would saturate if taken up a factor of 8 instead of 4
        // I'll leave it as it is but I think it is worth revisiting this:
        acc_input_l = opext >>> 1;
        acc_input_r = opext >>> 1;
        acc_en_l    = sum_en & left_en;
        acc_en_r    = sum_en & right_en;
      end
    endcase

  // Continuous output

  jt12_single_acc #(
      .win (16),
      .wout(16)
  ) u_left (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .op_result              (acc_input_l),
      .sum_en                 (acc_en_l),
      .zero                   (zero),
      .snd                    (left),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_left_data_out),
      .auto_ss_ack            (auto_ss_u_left_ack)

  );

  jt12_single_acc #(
      .win (16),
      .wout(16)
  ) u_right (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .op_result              (acc_input_r),
      .sum_en                 (acc_en_r),
      .zero                   (zero),
      .snd                    (right),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_right_data_out),
      .auto_ss_ack            (auto_ss_u_right_ack)

  );



endmodule


///////////////////////////////////////////
// MODULE jt12_lfo
module jt12_lfo (
    input               rst,
    input               clk,
    input               clk_en,
    input               zero,
    input               lfo_rst,
    input               lfo_en,
    input        [ 2:0] lfo_freq,
    output reg   [ 6:0] lfo_mod,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack
    // 7-bit width according to spritesmind.net
);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [6:0] cnt, limit;

  always @(*)
    case (lfo_freq)  // same values as in MAME
      3'd0: limit = 7'd108;
      3'd1: limit = 7'd77;
      3'd2: limit = 7'd71;
      3'd3: limit = 7'd67;
      3'd4: limit = 7'd62;
      3'd5: limit = 7'd44;
      3'd6: limit = 7'd8;
      3'd7: limit = 7'd5;
    endcase

  always @(posedge clk) begin

    if (rst || !lfo_en) {lfo_mod, cnt} <= 14'd0;
    else if (clk_en && zero) begin
      if (cnt == limit) begin
        cnt     <= 7'd0;
        lfo_mod <= lfo_mod + 1'b1;
      end else begin
        cnt <= cnt + 1'b1;
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cnt     <= auto_ss_data_in[6:0];
          lfo_mod <= auto_ss_data_in[13:7];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[13:0] = {lfo_mod, cnt};
          auto_ss_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt49_cen
module jt49_cen (
    input               clk,
    input               rst_n,
    input               cen,                      // base clock enable signal
    input               sel,                      // when low, divide by 2 once more
    output reg          cen16,
    output reg          cen256,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [9:0] cencnt;
  parameter CLKDIV = 3;  // use 3 for standalone JT49 or 2
  localparam eg = CLKDIV;  //8;

  wire toggle16 = sel ? ~|cencnt[CLKDIV-1:0] : ~|cencnt[CLKDIV:0];
  wire toggle256 = sel ? ~|cencnt[eg-2:0] : ~|cencnt[eg-1:0];


  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) cencnt <= 10'd0;
    else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cencnt <= auto_ss_data_in[9:0];
        end
        default: begin
        end
      endcase
    end else begin
      if (cen) cencnt <= cencnt + 10'd1;
    end
  end

  always @(posedge clk) begin
    begin
      cen16  <= cen & toggle16;
      cen256 <= cen & toggle256;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          cen16  <= auto_ss_data_in[10];
          cen256 <= auto_ss_data_in[11];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[11:0] = {cen256, cen16, cencnt};
          auto_ss_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end




endmodule


///////////////////////////////////////////
// MODULE jt49_div
module jt49_div #(
    parameter W = 12
) (
    (* direct_enable *) input cen,
    input clk,  // this is the divided down clock from the core
    input rst_n,
    input [W-1:0] period,
    output reg div,
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg  [W-1:0] count;

  wire [W-1:0] one = {{W - 1{1'b0}}, 1'b1};

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      count <= one;
      div   <= 1'b0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          div <= auto_ss_data_in[0];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      if (count >= period) begin
        count <= one;
        div   <= ~div;
      end else begin
        count <= count + one;
      end
      if (period == 0) div <= 0;
    end
  end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[0] = div;
          auto_ss_ack         = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt49_noise
module jt49_noise (
    (* direct_enable *) input               cen,
                        input               clk,
                        input               rst_n,
                        input        [ 4:0] period,
                        output reg          noise,
                        input               auto_ss_rd,
                        input               auto_ss_wr,
                        input        [31:0] auto_ss_data_in,
                        input        [ 7:0] auto_ss_device_idx,
                        input        [15:0] auto_ss_state_idx,
                        input        [ 7:0] auto_ss_base_device_idx,
                        output logic [31:0] auto_ss_data_out,
                        output logic        auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_local_ack | auto_ss_u_div_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_div_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_div_ack;

  wire  [31:0] auto_ss_u_div_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg  [ 5:0] count;
  reg  [16:0] poly17;
  wire        poly17_zero = poly17 == 17'b0;
  wire        noise_en;
  reg         last_en;

  wire        noise_up = noise_en && !last_en;

  always @(posedge clk) begin
    if (cen) begin
      noise <= ~poly17[0];
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          noise <= auto_ss_data_in[17];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk, negedge rst_n)
    if (!rst_n) poly17 <= 17'd0;
    else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          poly17  <= auto_ss_data_in[16:0];
          last_en <= auto_ss_data_in[18];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      last_en <= noise_en;
      if (noise_up) poly17 <= {poly17[0] ^ poly17[3] ^ poly17_zero, poly17[16:1]};
    end
  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[18:0] = {last_en, noise, poly17};
          auto_ss_local_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt49_div #(5) u_div (
      .clk                    (clk),
      .cen                    (cen),
      .rst_n                  (rst_n),
      .period                 (period),
      .div                    (noise_en),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_div_data_out),
      .auto_ss_ack            (auto_ss_u_div_ack)

  );

endmodule


///////////////////////////////////////////
// MODULE jt49_eg
module jt49_eg (
    (* direct_enable *) input cen,
    input clk,  // this is the divided down clock from the core
    input step,
    input null_period,
    input rst_n,
    input restart,
    input [3:0] ctrl,
    output reg [4:0] env,
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg inv, stop;
  reg  [4:0] gain;

  wire       CONT = ctrl[3];
  wire       ATT = ctrl[2];
  wire       ALT = ctrl[1];
  wire       HOLD = ctrl[0];

  wire       will_hold = !CONT || HOLD;

  always @(posedge clk) begin

    if (cen) env <= inv ? ~gain : gain;
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          env <= auto_ss_data_in[4:0];
        end
        default: begin
        end
      endcase
    end
  end



  reg  last_step;
  wire step_edge = (step && !last_step) || null_period;
  wire will_invert = (!CONT && ATT) || (CONT && ALT);
  reg rst_latch, rst_clr;

  always @(posedge clk) begin
    begin
      if (restart) rst_latch <= 1;
      else if (rst_clr) rst_latch <= 0;
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          rst_latch <= auto_ss_data_in[10];
        end
        default: begin
        end
      endcase
    end
  end



  always @(posedge clk, negedge rst_n)
    if (!rst_n) begin
      gain    <= 5'h1F;
      inv     <= 0;
      stop    <= 0;
      rst_clr <= 0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          gain      <= auto_ss_data_in[9:5];
          inv       <= auto_ss_data_in[11];
          last_step <= auto_ss_data_in[12];
          rst_clr   <= auto_ss_data_in[13];
          stop      <= auto_ss_data_in[14];
        end
        default: begin
        end
      endcase
    end else if (cen) begin
      last_step <= step;
      if (rst_latch) begin
        gain    <= 5'h1F;
        inv     <= ATT;
        stop    <= 1'b0;
        rst_clr <= 1;
      end else begin
        rst_clr <= 0;
        if (step_edge && !stop) begin
          if (gain == 5'h00) begin
            if (will_hold) stop <= 1'b1;
            else gain <= gain - 5'b1;
            if (will_invert) inv <= ~inv;
          end else gain <= gain - 5'b1;
        end
      end
    end
  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[14:0] = {stop, rst_clr, last_step, inv, rst_latch, gain, env};
          auto_ss_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt49_exp
module jt49_exp (
    input               clk,
    input        [ 2:0] comp,                     // compression
    input        [ 4:0] din,
    output reg   [ 7:0] dout,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  wire device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg [7:0] lut[0:159];

  always @(posedge clk) begin

    dout <= lut[{comp, din}];
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          dout <= auto_ss_data_in[7:0];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_data_out = 32'h0;
    auto_ss_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_data_out[8-1:0] = dout;
          auto_ss_ack             = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  initial begin
    lut[0]   = 8'd0;
    lut[1]   = 8'd1;
    lut[2]   = 8'd1;
    lut[3]   = 8'd1;
    lut[4]   = 8'd2;
    lut[5]   = 8'd2;
    lut[6]   = 8'd3;
    lut[7]   = 8'd3;
    lut[8]   = 8'd4;
    lut[9]   = 8'd5;
    lut[10]  = 8'd6;
    lut[11]  = 8'd7;
    lut[12]  = 8'd9;
    lut[13]  = 8'd11;
    lut[14]  = 8'd13;
    lut[15]  = 8'd15;
    lut[16]  = 8'd18;
    lut[17]  = 8'd22;
    lut[18]  = 8'd26;
    lut[19]  = 8'd31;
    lut[20]  = 8'd37;
    lut[21]  = 8'd45;
    lut[22]  = 8'd53;
    lut[23]  = 8'd63;
    lut[24]  = 8'd75;
    lut[25]  = 8'd90;
    lut[26]  = 8'd107;
    lut[27]  = 8'd127;
    lut[28]  = 8'd151;
    lut[29]  = 8'd180;
    lut[30]  = 8'd214;
    lut[31]  = 8'd255;
    lut[32]  = 8'd0;
    lut[33]  = 8'd7;
    lut[34]  = 8'd8;
    lut[35]  = 8'd10;
    lut[36]  = 8'd11;
    lut[37]  = 8'd12;
    lut[38]  = 8'd14;
    lut[39]  = 8'd15;
    lut[40]  = 8'd17;
    lut[41]  = 8'd20;
    lut[42]  = 8'd22;
    lut[43]  = 8'd25;
    lut[44]  = 8'd28;
    lut[45]  = 8'd31;
    lut[46]  = 8'd35;
    lut[47]  = 8'd40;
    lut[48]  = 8'd45;
    lut[49]  = 8'd50;
    lut[50]  = 8'd56;
    lut[51]  = 8'd63;
    lut[52]  = 8'd71;
    lut[53]  = 8'd80;
    lut[54]  = 8'd90;
    lut[55]  = 8'd101;
    lut[56]  = 8'd113;
    lut[57]  = 8'd127;
    lut[58]  = 8'd143;
    lut[59]  = 8'd160;
    lut[60]  = 8'd180;
    lut[61]  = 8'd202;
    lut[62]  = 8'd227;
    lut[63]  = 8'd255;
    lut[64]  = 8'd0;
    lut[65]  = 8'd18;
    lut[66]  = 8'd20;
    lut[67]  = 8'd22;
    lut[68]  = 8'd24;
    lut[69]  = 8'd26;
    lut[70]  = 8'd29;
    lut[71]  = 8'd31;
    lut[72]  = 8'd34;
    lut[73]  = 8'd37;
    lut[74]  = 8'd41;
    lut[75]  = 8'd45;
    lut[76]  = 8'd49;
    lut[77]  = 8'd53;
    lut[78]  = 8'd58;
    lut[79]  = 8'd63;
    lut[80]  = 8'd69;
    lut[81]  = 8'd75;
    lut[82]  = 8'd82;
    lut[83]  = 8'd90;
    lut[84]  = 8'd98;
    lut[85]  = 8'd107;
    lut[86]  = 8'd116;
    lut[87]  = 8'd127;
    lut[88]  = 8'd139;
    lut[89]  = 8'd151;
    lut[90]  = 8'd165;
    lut[91]  = 8'd180;
    lut[92]  = 8'd196;
    lut[93]  = 8'd214;
    lut[94]  = 8'd233;
    lut[95]  = 8'd255;
    lut[96]  = 8'd0;
    lut[97]  = 8'd51;
    lut[98]  = 8'd54;
    lut[99]  = 8'd57;
    lut[100] = 8'd60;
    lut[101] = 8'd63;
    lut[102] = 8'd67;
    lut[103] = 8'd70;
    lut[104] = 8'd74;
    lut[105] = 8'd78;
    lut[106] = 8'd83;
    lut[107] = 8'd87;
    lut[108] = 8'd92;
    lut[109] = 8'd97;
    lut[110] = 8'd103;
    lut[111] = 8'd108;
    lut[112] = 8'd114;
    lut[113] = 8'd120;
    lut[114] = 8'd127;
    lut[115] = 8'd134;
    lut[116] = 8'd141;
    lut[117] = 8'd149;
    lut[118] = 8'd157;
    lut[119] = 8'd166;
    lut[120] = 8'd175;
    lut[121] = 8'd185;
    lut[122] = 8'd195;
    lut[123] = 8'd206;
    lut[124] = 8'd217;
    lut[125] = 8'd229;
    lut[126] = 8'd241;
    lut[127] = 8'd255;
    lut[128] = 8'd0;
    lut[129] = 8'd8;
    lut[130] = 8'd10;
    lut[131] = 8'd12;
    lut[132] = 8'd16;
    lut[133] = 8'd22;
    lut[134] = 8'd29;
    lut[135] = 8'd35;
    lut[136] = 8'd44;
    lut[137] = 8'd50;
    lut[138] = 8'd56;
    lut[139] = 8'd60;
    lut[140] = 8'd64;
    lut[141] = 8'd85;
    lut[142] = 8'd97;
    lut[143] = 8'd103;
    lut[144] = 8'd108;
    lut[145] = 8'd120;
    lut[146] = 8'd127;
    lut[147] = 8'd134;
    lut[148] = 8'd141;
    lut[149] = 8'd149;
    lut[150] = 8'd157;
    lut[151] = 8'd166;
    lut[152] = 8'd175;
    lut[153] = 8'd185;
    lut[154] = 8'd195;
    lut[155] = 8'd206;
    lut[156] = 8'd217;
    lut[157] = 8'd229;
    lut[158] = 8'd241;
    lut[159] = 8'd255;

  end
endmodule


///////////////////////////////////////////
// MODULE jt49
module jt49 (  // note that input ports are not multiplexed
    input rst_n,
    input clk,  // signal on positive edge
    input clk_en  /* synthesis direct_enable = 1 */,
    input [3:0] addr,
    input cs_n,
    input wr_n,  // write
    input [7:0] din,
    input sel,  // if sel is low, the clock is divided by 2
    output reg [7:0] dout,
    output reg [9:0] sound,  // combined channel output
    output reg [7:0] A,  // linearised channel output
    output reg [7:0] B,
    output reg [7:0] C,
    output sample,

    input  [7:0] IOA_in,
    output [7:0] IOA_out,
    output       IOA_oe,

    input        [ 7:0] IOB_in,
    output       [ 7:0] IOB_out,
    output              IOB_oe,
    input               auto_ss_rd,
    input               auto_ss_wr,
    input        [31:0] auto_ss_data_in,
    input        [ 7:0] auto_ss_device_idx,
    input        [15:0] auto_ss_state_idx,
    input        [ 7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic        auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_cen_ack | auto_ss_u_chA_ack | auto_ss_u_chB_ack | auto_ss_u_chC_ack | auto_ss_u_ng_ack | auto_ss_u_envdiv_ack | auto_ss_u_env_ack | auto_ss_u_exp_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_cen_data_out | auto_ss_u_chA_data_out | auto_ss_u_chB_data_out | auto_ss_u_chC_data_out | auto_ss_u_ng_data_out | auto_ss_u_envdiv_data_out | auto_ss_u_env_data_out | auto_ss_u_exp_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_exp_ack;

  wire  [31:0] auto_ss_u_exp_data_out;

  wire         auto_ss_u_env_ack;

  wire  [31:0] auto_ss_u_env_data_out;

  wire         auto_ss_u_envdiv_ack;

  wire  [31:0] auto_ss_u_envdiv_data_out;

  wire         auto_ss_u_ng_ack;

  wire  [31:0] auto_ss_u_ng_data_out;

  wire         auto_ss_u_chC_ack;

  wire  [31:0] auto_ss_u_chC_data_out;

  wire         auto_ss_u_chB_ack;

  wire  [31:0] auto_ss_u_chB_data_out;

  wire         auto_ss_u_chA_ack;

  wire  [31:0] auto_ss_u_chA_data_out;

  wire         auto_ss_u_cen_ack;

  wire  [31:0] auto_ss_u_cen_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  parameter [2:0] COMP = 3'b000;
  parameter YM2203_LUMPED = 0;
  parameter CLKDIV = 3;
  wire [2:0] comp = COMP;

  reg  [7:0] regarray    [15:0];
  wire [7:0] port_A, port_B;
  wire [11:0] periodA, periodB, periodC;

  wire [4:0] envelope;
  wire bitA, bitB, bitC;
  wire noise;
  reg Amix, Bmix, Cmix;

  wire cen16, cen256;

  assign IOA_out = regarray[14];
  assign IOB_out = regarray[15];
  assign port_A  = IOA_in;
  assign port_B  = IOB_in;
  assign IOA_oe  = regarray[7][6];
  assign IOB_oe  = regarray[7][7];
  assign sample  = cen16;
  assign periodA = {regarray[1][3:0], regarray[0][7:0]};
  assign periodB = {regarray[3][3:0], regarray[2][7:0]};
  assign periodC = {regarray[5][3:0], regarray[4][7:0]};


  jt49_cen #(
      .CLKDIV(CLKDIV)
  ) u_cen (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .cen                    (clk_en),
      .sel                    (sel),
      .cen16                  (cen16),
      .cen256                 (cen256),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_cen_data_out),
      .auto_ss_ack            (auto_ss_u_cen_ack)

  );

  // internal modules operate at clk/16
  jt49_div #(12) u_chA (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .cen                    (cen16),
      .period                 (periodA),
      .div                    (bitA),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_chA_data_out),
      .auto_ss_ack            (auto_ss_u_chA_ack)

  );

  jt49_div #(12) u_chB (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .cen                    (cen16),
      .period                 (periodB),
      .div                    (bitB),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 3),
      .auto_ss_data_out       (auto_ss_u_chB_data_out),
      .auto_ss_ack            (auto_ss_u_chB_ack)

  );

  jt49_div #(12) u_chC (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .cen                    (cen16),
      .period                 (periodC),
      .div                    (bitC),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 4),
      .auto_ss_data_out       (auto_ss_u_chC_data_out),
      .auto_ss_ack            (auto_ss_u_chC_ack)

  );

  jt49_noise u_ng (
      .clk                    (clk),
      .cen                    (cen16),
      .rst_n                  (rst_n),
      .period                 (regarray[6][4:0]),
      .noise                  (noise),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 5),
      .auto_ss_data_out       (auto_ss_u_ng_data_out),
      .auto_ss_ack            (auto_ss_u_ng_ack)

  );

  // envelope generator
  wire        eg_step;
  wire [15:0] eg_period = {regarray[4'hc], regarray[4'hb]};
  wire        null_period = eg_period == 16'h0;

  jt49_div #(16) u_envdiv (
      .clk                    (clk),
      .cen                    (cen256),
      .rst_n                  (rst_n),
      .period                 (eg_period),
      .div                    (eg_step),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 7),
      .auto_ss_data_out       (auto_ss_u_envdiv_data_out),
      .auto_ss_ack            (auto_ss_u_envdiv_ack)

  );

  reg eg_restart;

  jt49_eg u_env (
      .clk                    (clk),
      .cen                    (cen256),
      .step                   (eg_step),
      .rst_n                  (rst_n),
      .restart                (eg_restart),
      .null_period            (null_period),
      .ctrl                   (regarray[4'hD][3:0]),
      .env                    (envelope),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 8),
      .auto_ss_data_out       (auto_ss_u_env_data_out),
      .auto_ss_ack            (auto_ss_u_env_ack)

  );

  reg [4:0] logA, logB, logC, log;
  wire [7:0] lin;

  jt49_exp u_exp (
      .clk                    (clk),
      .comp                   (comp),
      .din                    (log),
      .dout                   (lin),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 9),
      .auto_ss_data_out       (auto_ss_u_exp_data_out),
      .auto_ss_ack            (auto_ss_u_exp_ack)

  );

  wire [4:0] volA = {regarray[8][3:0], regarray[8][3]};
  wire [4:0] volB = {regarray[9][3:0], regarray[9][3]};
  wire [4:0] volC = {regarray[10][3:0], regarray[10][3]};
  wire       use_envA = regarray[8][4];
  wire       use_envB = regarray[9][4];
  wire       use_envC = regarray[10][4];
  wire       use_noA = regarray[7][3];
  wire       use_noB = regarray[7][4];
  wire       use_noC = regarray[7][5];

  reg  [3:0] acc_st;

  always @(posedge clk) begin
    if (clk_en) begin
      Amix <= (noise | use_noA) & (bitA | regarray[7][0]);
      Bmix <= (noise | use_noB) & (bitB | regarray[7][1]);
      Cmix <= (noise | use_noC) & (bitC | regarray[7][2]);

      logA <= !Amix ? 5'd0 : (use_envA ? envelope : volA);
      logB <= !Bmix ? 5'd0 : (use_envB ? envelope : volB);
      logC <= !Cmix ? 5'd0 : (use_envC ? envelope : volC);
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          logA <= auto_ss_data_in[28:24];
        end
        2: begin
          logB <= auto_ss_data_in[4:0];
          logC <= auto_ss_data_in[9:5];
          Amix <= auto_ss_data_in[19];
          Bmix <= auto_ss_data_in[20];
          Cmix <= auto_ss_data_in[21];
        end
        default: begin
        end
      endcase
    end
  end



  reg  [9:0] acc;
  wire [9:0] elin;

  assign elin = {2'd0, lin};

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      acc_st <= 4'b1;
      acc    <= 10'd0;
      A      <= 8'd0;
      B      <= 8'd0;
      C      <= 8'd0;
      sound  <= 10'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          acc   <= auto_ss_data_in[9:0];
          sound <= auto_ss_data_in[19:10];
          A     <= auto_ss_data_in[27:20];
        end
        1: begin
          B <= auto_ss_data_in[7:0];
          C <= auto_ss_data_in[15:8];
        end
        2: begin
          log    <= auto_ss_data_in[14:10];
          acc_st <= auto_ss_data_in[18:15];
        end
        default: begin
        end
      endcase
    end else if (clk_en) begin
      acc_st <= {acc_st[2:0], acc_st[3]};
      // Lumping the channel outputs for YM2203 will cause only the higher
      // voltage to pass throuh, as the outputs seem to use a source follower.
      acc    <= YM2203_LUMPED == 1 ? (acc > elin ? acc : elin) : acc + elin;
      case (acc_st)
        4'b0001: begin
          log   <= logA;
          acc   <= 10'd0;
          sound <= acc;
        end
        4'b0010: begin
          A   <= lin;
          log <= logB;
        end
        4'b0100: begin
          B   <= lin;
          log <= logC;
        end
        4'b1000: begin  // last sum
          C <= lin;
        end
        default: ;
      endcase
    end
  end

  reg [7:0] read_mask;

  always @(*)
    case (addr)
      4'h0, 4'h2, 4'h4, 4'h7, 4'hb, 4'hc, 4'he, 4'hf: read_mask = 8'hff;
      4'h1, 4'h3, 4'h5, 4'hd: read_mask = 8'h0f;
      4'h6, 4'h8, 4'h9, 4'ha: read_mask = 8'h1f;
    endcase  // addr

  // register array
  wire write;
  reg  last_write;
  wire wr_edge = write & ~last_write;

  assign write = !wr_n && !cs_n;

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      dout         <= 8'd0;
      last_write   <= 0;
      eg_restart   <= 0;
      regarray[0]  <= 8'd0;
      regarray[4]  <= 8'd0;
      regarray[8]  <= 8'd0;
      regarray[12] <= 8'd0;
      regarray[1]  <= 8'd0;
      regarray[5]  <= 8'd0;
      regarray[9]  <= 8'd0;
      regarray[13] <= 8'd0;
      regarray[2]  <= 8'd0;
      regarray[6]  <= 8'd0;
      regarray[10] <= 8'd0;
      regarray[14] <= 8'd0;
      regarray[3]  <= 8'd0;
      regarray[7]  <= 8'd0;
      regarray[11] <= 8'd0;
      regarray[15] <= 8'd0;
    end else if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        1: begin
          dout <= auto_ss_data_in[23:16];
        end
        2: begin
          eg_restart <= auto_ss_data_in[22];
          last_write <= auto_ss_data_in[23];
        end
        default: begin
          if (auto_ss_state_idx >= (3) && auto_ss_state_idx < (19)) begin
            regarray[auto_ss_state_idx-3] <= auto_ss_data_in[7:0];
          end
        end
      endcase
    end else begin
      last_write <= write;
      // Data read
      case (addr)
        4'he: dout <= port_A;
        4'hf: dout <= port_B;
        default: dout <= regarray[addr] & read_mask;
      endcase
      // Data write
      if (write) begin
        regarray[addr] <= din;
        if (addr == 4'hD && wr_edge) eg_restart <= 1;
      end else begin
        eg_restart <= 0;
      end
    end
  end
  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[27:0] = {A, sound, acc};
          auto_ss_local_ack            = 1'b1;
        end
        1: begin
          auto_ss_local_data_out[28:0] = {logA, dout, C, B};
          auto_ss_local_ack            = 1'b1;
        end
        2: begin
          auto_ss_local_data_out[23:0] = {
            last_write, eg_restart, Cmix, Bmix, Amix, acc_st, log, logC, logB
          };
          auto_ss_local_ack = 1'b1;
        end
        default: begin
          if (auto_ss_state_idx >= (3) && auto_ss_state_idx < (19)) begin
            auto_ss_local_data_out[8-1:0] = regarray[auto_ss_state_idx-3];
            auto_ss_local_ack             = 1'b1;
          end
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt12_pcm_interpol
module jt12_pcm_interpol #(
    parameter DW    = 9,
              stepw = 5
) (
    input                      rst_n,
    input                      clk,
    input                      cen,                      // 8MHz cen
    input                      cen55,                    // clk & cen55  =  55 kHz
    input                      pcm_wr,                   // advance to next sample
    input  signed     [DW-1:0] pcmin,
    output reg signed [DW-1:0] pcmout,
    input                      auto_ss_rd,
    input                      auto_ss_wr,
    input             [  31:0] auto_ss_data_in,
    input             [   7:0] auto_ss_device_idx,
    input             [  15:0] auto_ss_state_idx,
    input             [   7:0] auto_ss_base_device_idx,
    output logic      [  31:0] auto_ss_data_out,
    output logic               auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_local_ack | auto_ss_u_div_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_div_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_div_ack;

  wire  [31:0] auto_ss_u_div_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg sign, last_pcm_wr;
  reg [stepw-1:0] dn, pre_dn = {stepw{1'b1}};
  wire posedge_pcmwr = pcm_wr && !last_pcm_wr;
  wire negedge_pcmwr = !pcm_wr && last_pcm_wr;

  reg  start_div = 0;
  wire working;

  reg signed [DW-1:0] pcmnew, dx, pcmlast, pcminter;
  wire signed [DW:0] dx_ext = {pcmin[DW-1], pcmin} - {pcmnew[DW-1], pcmnew};

  // latch new data and compute the two deltas : dx and dn, slope = dx/dn
  always @(posedge clk) begin
    begin
      last_pcm_wr <= pcm_wr;
      start_div   <= posedge_pcmwr;

      if (posedge_pcmwr) begin
        pre_dn    <= 1;
        pcmnew    <= pcmin;
        pcmlast   <= pcmnew;
        dn        <= pre_dn;
        dx        <= dx_ext[DW] ? -dx_ext[DW-1:0] : dx_ext[DW-1:0];
        sign      <= dx_ext[DW];
        start_div <= 1;
      end

      if (!pcm_wr && cen55) begin
        if (pre_dn != {stepw{1'b1}}) pre_dn <= pre_dn + 'd1;
      end
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          last_pcm_wr <= auto_ss_data_in[0];
          sign        <= auto_ss_data_in[1];
          start_div   <= auto_ss_data_in[2];
        end
        default: begin
        end
      endcase
    end
  end



  // interpolate samples
  wire        [DW-1:0] step;
  wire signed [DW-1:0] next_up = pcminter + step;
  wire signed [DW-1:0] next_down = pcminter - step;
  wire                 overflow_up = 0;  //next_up[DW-1]   != pcmnew[DW-1];
  wire                 overflow_down = 0;  //next_down[DW-1] != pcmnew[DW-1];


  always @(posedge clk) begin
    begin
      if (negedge_pcmwr) begin
        pcminter <= pcmlast;
      end else if (cen55 && !working && !pcm_wr) begin  // only advance if the divider has finished
        if (sign) begin  // subtract
          if (next_down > pcmnew && !overflow_down) pcminter <= next_down;
          else pcminter <= pcmnew;  // done
        end else begin  // add
          if (next_up < pcmnew && !overflow_up) pcminter <= next_up;
          else pcminter <= pcmnew;  // done
        end
      end
    end
    if (auto_ss_wr && device_match) begin
    end
  end



  // output only at cen55

  always @(posedge clk) begin
    if (cen55) pcmout <= pcminter;
    if (auto_ss_wr && device_match) begin
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[2:0] = {start_div, sign, last_pcm_wr};
          auto_ss_local_ack           = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



  jt10_adpcm_div #(
      .DW(DW)
  ) u_div (
      .rst_n                  (rst_n),
      .clk                    (clk),
      .cen                    (1'b1),
      .start                  (start_div),
      .a                      (dx),
      .b                      ({{DW - stepw{1'b0}}, dn}),
      .d                      (step),
      .r                      (),
      .working                (working),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_div_data_out),
      .auto_ss_ack            (auto_ss_u_div_ack)

  );


endmodule


///////////////////////////////////////////
// MODULE jt12_acc
module jt12_acc (
    input                    rst,
    input                    clk,
    input                    clk_en  /* synthesis direct_enable */,
    input  signed     [ 8:0] op_result,
    input             [ 1:0] rl,
    input                    zero,
    input                    s1_enters,
    input                    s2_enters,
    input                    s3_enters,
    input                    s4_enters,
    input                    ch6op,
    input             [ 2:0] alg,
    input                    pcm_en,                                 // only enabled for channel 6
    input  signed     [ 8:0] pcm,
    // combined output
    output reg signed [11:0] left,
    output reg signed [11:0] right,
    input                    auto_ss_rd,
    input                    auto_ss_wr,
    input             [31:0] auto_ss_data_in,
    input             [ 7:0] auto_ss_device_idx,
    input             [15:0] auto_ss_state_idx,
    input             [ 7:0] auto_ss_base_device_idx,
    output logic      [31:0] auto_ss_data_out,
    output logic             auto_ss_ack

);
  assign auto_ss_ack = auto_ss_local_ack | auto_ss_u_left_ack | auto_ss_u_right_ack;

  assign auto_ss_data_out = auto_ss_local_data_out | auto_ss_u_left_data_out | auto_ss_u_right_data_out;

  logic        auto_ss_local_ack;

  logic [31:0] auto_ss_local_data_out;

  wire         auto_ss_u_right_ack;

  wire  [31:0] auto_ss_u_right_data_out;

  wire         auto_ss_u_left_ack;

  wire  [31:0] auto_ss_u_left_data_out;

  wire         device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg sum_en;

  always @(*) begin
    case (alg)
      default: sum_en = s4_enters;
      3'd4: sum_en = s2_enters | s4_enters;
      3'd5, 3'd6: sum_en = ~s1_enters;
      3'd7: sum_en = 1'b1;
    endcase
  end

  reg pcm_sum;

  always @(posedge clk) begin
    if (clk_en)
      if (zero) pcm_sum <= 1'b1;
      else if (ch6op) pcm_sum <= 1'b0;
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          pcm_sum <= auto_ss_data_in[24];
        end
        default: begin
        end
      endcase
    end
  end



  wire              use_pcm = ch6op && pcm_en;
  wire              sum_or_pcm = sum_en | use_pcm;
  wire              left_en = rl[1];
  wire              right_en = rl[0];
  wire signed [8:0] pcm_data = pcm_sum ? pcm : 9'd0;
  wire        [8:0] acc_input = use_pcm ? pcm_data : op_result;

  // Continuous output
  wire signed [11:0] pre_left, pre_right;
  jt12_single_acc #(
      .win (9),
      .wout(12)
  ) u_left (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .op_result              (acc_input),
      .sum_en                 (sum_or_pcm & left_en),
      .zero                   (zero),
      .snd                    (pre_left),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_left_data_out),
      .auto_ss_ack            (auto_ss_u_left_ack)

  );

  jt12_single_acc #(
      .win (9),
      .wout(12)
  ) u_right (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .op_result              (acc_input),
      .sum_en                 (sum_or_pcm & right_en),
      .zero                   (zero),
      .snd                    (pre_right),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_right_data_out),
      .auto_ss_ack            (auto_ss_u_right_ack)

  );

  // Output can be amplied by 8/6=1.33 to use full range
  // an easy alternative is to add 1/4th and get 1.25 amplification
  always @(posedge clk) begin
    if (clk_en) begin
      left  <= pre_left + {{2{pre_left[11]}}, pre_left[11:2]};
      right <= pre_right + {{2{pre_right[11]}}, pre_right[11:2]};
    end
    if (auto_ss_wr && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          left  <= auto_ss_data_in[11:0];
          right <= auto_ss_data_in[23:12];
        end
        default: begin
        end
      endcase
    end
  end


  always_comb begin
    auto_ss_local_data_out = 32'h0;
    auto_ss_local_ack      = 1'b0;
    if (auto_ss_rd && device_match) begin
      case (auto_ss_state_idx)
        0: begin
          auto_ss_local_data_out[24:0] = {pcm_sum, right, left};
          auto_ss_local_ack            = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end



endmodule


///////////////////////////////////////////
// MODULE jt03_acc
module jt03_acc (
    input                rst,
    input                clk,
    input                clk_en  /* synthesis direct_enable */,
    input  signed [13:0] op_result,
    input                s1_enters,
    input                s2_enters,
    input                s3_enters,
    input                s4_enters,
    input                zero,
    input         [ 2:0] alg,
    // combined output
    output signed [15:0] snd,
    input                auto_ss_rd,
    input                auto_ss_wr,
    input         [31:0] auto_ss_data_in,
    input         [ 7:0] auto_ss_device_idx,
    input         [15:0] auto_ss_state_idx,
    input         [ 7:0] auto_ss_base_device_idx,
    output logic  [31:0] auto_ss_data_out,
    output logic         auto_ss_ack

);
  assign auto_ss_ack      = auto_ss_u_mono_ack;

  assign auto_ss_data_out = auto_ss_u_mono_data_out;

  wire        auto_ss_u_mono_ack;

  wire [31:0] auto_ss_u_mono_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  reg sum_en;

  always @(*) begin
    case (alg)
      default: sum_en = s4_enters;
      3'd4: sum_en = s2_enters | s4_enters;
      3'd5, 3'd6: sum_en = ~s1_enters;
      3'd7: sum_en = 1'b1;
    endcase
  end

  // real YM2608 drops the op_result LSB, resulting in a 13-bit accumulator
  // but in YM2203, a 13-bit acc for 3 channels only requires 15 bits
  // and YM3014 has a 16-bit dynamic range.
  // I am leaving the LSB and scaling the output voltage accordingly. This
  // should result in less quantification noise.
  jt12_single_acc #(
      .win (14),
      .wout(16)
  ) u_mono (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .op_result              (op_result),
      .sum_en                 (sum_en),
      .zero                   (zero),
      .snd                    (snd),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_mono_data_out),
      .auto_ss_ack            (auto_ss_u_mono_ack)

  );

endmodule


///////////////////////////////////////////
// MODULE jt12_top
module jt12_top (
                        input       rst,   // rst should be at least 6 clk&cen cycles long
                        input       clk,   // CPU clock
    (* direct_enable *) input       cen,   // optional clock enable, if not needed leave as 1'b1
                        input [7:0] din,
                        input [1:0] addr,
                        input       cs_n,
                        input       wr_n,

    output [7:0] dout,
    output irq_n,
    // Configuration
    input en_hifi_pcm,  // high to enable PCM interpolation on YM2612 mode
    // ADPCM pins
    output [19:0] adpcma_addr,  // real hardware has 10 pins multiplexed through RMPX pin
    output [3:0] adpcma_bank,
    output adpcma_roe_n,  // ADPCM-A ROM output enable
    input [7:0] adpcma_data,  // Data from RAM
    output [23:0] adpcmb_addr,  // real hardware has 12 pins multiplexed through PMPX pin
    input [7:0] adpcmb_data,
    output adpcmb_roe_n,  // ADPCM-B ROM output enable
    // I/O pins used by YM2203 embedded YM2149 chip
    input [7:0] IOA_in,
    input [7:0] IOB_in,
    output [7:0] IOA_out,
    output [7:0] IOB_out,
    output IOA_oe,
    output IOB_oe,
    // Separated output
    output [7:0] psg_A,
    output [7:0] psg_B,
    output [7:0] psg_C,
    output signed [15:0] fm_snd_left,
    output signed [15:0] fm_snd_right,
    output signed [15:0] adpcmA_l,
    output signed [15:0] adpcmA_r,
    output signed [15:0] adpcmB_l,
    output signed [15:0] adpcmB_r,
    // combined output
    output [9:0] psg_snd,
    output signed [15:0] snd_right,  // FM+PSG
    output signed [15:0] snd_left,  // FM+PSG
    output snd_sample,
    input [5:0] ch_enable,  // ADPCM-A channels
    input ym2610b,  // LOCAL (Arcade-TaitoB): six FM channels instead of four
    input [7:0] debug_bus,
    output [7:0] debug_view,
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack

);
  assign auto_ss_ack = auto_ss_u_dout_ack | auto_ss_u_mmr_ack | auto_ss_u_timers_ack | auto_ss_u_pg_ack | auto_ss_u_eg_ack | auto_ss_u_egpad_ack | auto_ss_u_op_ack | auto_ss_u_rst_ack | auto_ss_u_adpcm_a_ack | auto_ss_u_adpcm_b_ack | auto_ss_u_acc_ack | auto_ss_u_lfo_ack | auto_ss_u_psg_ack | auto_ss_u_rst_pcm_ack | auto_ss_u_pcm_ack;

  assign auto_ss_data_out = auto_ss_u_dout_data_out | auto_ss_u_mmr_data_out | auto_ss_u_timers_data_out | auto_ss_u_pg_data_out | auto_ss_u_eg_data_out | auto_ss_u_egpad_data_out | auto_ss_u_op_data_out | auto_ss_u_rst_data_out | auto_ss_u_adpcm_a_data_out | auto_ss_u_adpcm_b_data_out | auto_ss_u_acc_data_out | auto_ss_u_lfo_data_out | auto_ss_u_psg_data_out | auto_ss_u_rst_pcm_data_out | auto_ss_u_pcm_data_out;

  wire        auto_ss_u_pcm_ack;

  wire [31:0] auto_ss_u_pcm_data_out;

  wire        auto_ss_u_rst_pcm_ack;

  wire [31:0] auto_ss_u_rst_pcm_data_out;

  wire        auto_ss_u_psg_ack;

  wire [31:0] auto_ss_u_psg_data_out;

  wire        auto_ss_u_lfo_ack;

  wire [31:0] auto_ss_u_lfo_data_out;

  wire        auto_ss_u_acc_ack;

  wire [31:0] auto_ss_u_acc_data_out;

  wire        auto_ss_u_adpcm_b_ack;

  wire [31:0] auto_ss_u_adpcm_b_data_out;

  wire        auto_ss_u_adpcm_a_ack;

  wire [31:0] auto_ss_u_adpcm_a_data_out;

  wire        auto_ss_u_rst_ack;

  wire [31:0] auto_ss_u_rst_data_out;

  wire        auto_ss_u_op_ack;

  wire [31:0] auto_ss_u_op_data_out;

  wire        auto_ss_u_egpad_ack;

  wire [31:0] auto_ss_u_egpad_data_out;

  wire        auto_ss_u_eg_ack;

  wire [31:0] auto_ss_u_eg_data_out;

  wire        auto_ss_u_pg_ack;

  wire [31:0] auto_ss_u_pg_data_out;

  wire        auto_ss_u_timers_ack;

  wire [31:0] auto_ss_u_timers_data_out;

  wire        auto_ss_u_mmr_ack;

  wire [31:0] auto_ss_u_mmr_data_out;

  wire        auto_ss_u_dout_ack;

  wire [31:0] auto_ss_u_dout_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  // parameters to select the features for each chip type
  // defaults to YM2612
  parameter use_lfo = 1, use_ssg = 0, num_ch = 6, use_pcm = 1;
  parameter use_adpcm = 0;
  parameter JT49_DIV = 2, YM2203_LUMPED = 0;
  parameter mask_div = 1;

  wire flag_A, flag_B, busy;

  wire write = !cs_n && !wr_n;
  wire clk_en, clk_en_ssg;

  // Timers
  wire [9:0] value_A;
  wire [7:0] value_B;
  wire load_A, load_B;
  wire enable_irq_A, enable_irq_B;
  wire clr_flag_A, clr_flag_B;
  wire        overflow_A;
  wire        fast_timers;

  wire        zero;  // Single-clock pulse at the begginig of s1_enters
  // LFO
  wire [ 2:0] lfo_freq;
  wire        lfo_en;
  // Operators
  wire        amsen_IV;
  wire [ 2:0] dt1_I;
  wire [ 3:0] mul_II;
  wire [ 6:0] tl_IV;

  wire [ 4:0] keycode_II;
  wire [ 4:0] ar_I;
  wire [ 4:0] d1r_I;
  wire [ 4:0] d2r_I;
  wire [ 3:0] rr_I;
  wire [ 3:0] sl_I;
  wire [ 1:0] ks_II;
  // SSG operation
  wire        ssg_en_I;
  wire [ 2:0] ssg_eg_I;
  // envelope operation
  wire        keyon_I;
  wire [ 9:0] eg_IX;
  wire        pg_rst_II;
  // Channel
  wire [10:0] fnum_I;
  wire [ 2:0] block_I;
  wire [ 1:0] rl;
  wire [ 2:0] fb_II;
  wire [ 2:0] alg_I;
  wire [ 2:0] pms_I;
  wire [ 1:0] ams_IV;
  // PCM
  wire pcm_en, pcm_wr;
  wire [8:0] pcm;
  // Test
  wire pg_stop, eg_stop;

  wire       ch6op;
  wire [2:0] cur_ch;
  wire [1:0] cur_op;

  // Operator
  wire xuse_internal, yuse_internal;
  wire xuse_prevprev1, xuse_prev2, yuse_prev1, yuse_prev2;
  wire [9:0] phase_VIII;
  wire s1_enters, s2_enters, s3_enters, s4_enters;
  wire       rst_int;
  // LFO
  wire [6:0] lfo_mod;
  wire       lfo_rst;
  // PSG
  wire [3:0] psg_addr;
  wire [7:0] psg_data, psg_dout;
  wire        psg_wr_n;
  // ADPCM-A
  wire [15:0] addr_a;
  wire [2:0] up_addr, up_lracl;
  wire up_start, up_end;
  wire [7:0] aon_a, lracl;
  wire [ 5:0] atl_a;  // ADPCM Total Level
  wire        up_aon;
  // APDCM-B
  wire        acmd_on_b;  // Control - Process start, Key On
  wire        acmd_rep_b;  // Control - Repeat
  wire        acmd_rst_b;  // Control - Reset
  wire        acmd_up_b;  // Control - New cmd received
  wire [ 1:0] alr_b;  // Left / Right
  wire [15:0] astart_b;  // Start address
  wire [15:0] aend_b;  // End   address
  wire [15:0] adeltan_b;  // Delta-N
  wire [ 7:0] aeg_b;  // Envelope Generator Control
  wire [ 5:0] adpcma_flags;  // ADPMC-A read over flags
  wire        adpcmb_flag;
  wire [ 6:0] flag_ctl;
  wire [ 6:0] flag_mask;
  wire [ 1:0] div_setting;

  wire clk_en_2, clk_en_666, clk_en_111, clk_en_55;

  assign debug_view = {4'd0, flag_B, flag_A, div_setting};

  generate
    if (use_adpcm == 1) begin : gen_adpcm
      wire rst_n;

      jt12_rst u_rst (
          .rst                    (rst),
          .clk                    (clk),
          .rst_n                  (rst_n),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 39),
          .auto_ss_data_out       (auto_ss_u_rst_data_out),
          .auto_ss_ack            (auto_ss_u_rst_ack)

      );

      jt10_adpcm_drvA u_adpcm_a (
          .rst_n(rst_n),
          .clk  (clk),
          .cen  (cen),
          .cen6 (clk_en_666),  // clk & cen must be 666  kHz
          .cen1 (clk_en_111),  // clk & cen must be 111 kHz

          .addr  (adpcma_addr),   // real hardware has 10 pins multiplexed through RMPX pin
          .bank  (adpcma_bank),
          .roe_n (adpcma_roe_n),  // ADPCM-A ROM output enable
          .datain(adpcma_data),

          // Control Registers
          .atl     (atl_a),     // ADPCM Total Level
          .addr_in (addr_a),
          .lracl_in(lracl),
          .up_start(up_start),
          .up_end  (up_end),
          .up_addr (up_addr),
          .up_lracl(up_lracl),

          .aon_cmd  (aon_a),         // ADPCM ON equivalent to key on for FM
          .up_aon   (up_aon),
          // Flags
          .flags    (adpcma_flags),
          .clr_flags(flag_ctl[5:0]),

          .pcm55_l                (adpcmA_l),
          .pcm55_r                (adpcmA_r),
          .ch_enable              (ch_enable),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 40),
          .auto_ss_data_out       (auto_ss_u_adpcm_a_data_out),
          .auto_ss_ack            (auto_ss_u_adpcm_a_ack)

      );

      jt10_adpcm_drvB u_adpcm_b (
          .rst_n(rst_n),
          .clk  (clk),
          .cen  (cen),
          .cen55(clk_en_55),

          // Control
          .acmd_on_b (acmd_on_b),    // Control - Process start, Key On
          .acmd_rep_b(acmd_rep_b),   // Control - Repeat
          .acmd_rst_b(acmd_rst_b),   // Control - Reset
          .acmd_up_b (acmd_up_b),    // Control - New command received
          .alr_b     (alr_b),        // Left / Right
          .astart_b  (astart_b),     // Start address
          .aend_b    (aend_b),       // End   address
          .adeltan_b (adeltan_b),    // Delta-N
          .aeg_b     (aeg_b),        // Envelope Generator Control
          // Flag
          .flag      (adpcmb_flag),
          .clr_flag  (flag_ctl[6]),
          // memory
          .addr      (adpcmb_addr),
          .data      (adpcmb_data),
          .roe_n     (adpcmb_roe_n),

          .pcm55_l                (adpcmB_l),
          .pcm55_r                (adpcmB_r),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 47),
          .auto_ss_data_out       (auto_ss_u_adpcm_b_data_out),
          .auto_ss_ack            (auto_ss_u_adpcm_b_ack)

      );

      assign snd_sample = zero;
      jt10_acc u_acc (
          .clk                    (clk),
          .clk_en                 (clk_en),
          .op_result              (op_result_hd),
          .rl                     (rl),
          .zero                   (zero),
          .s1_enters              (s2_enters),
          .s2_enters              (s1_enters),
          .s3_enters              (s4_enters),
          .s4_enters              (s3_enters),
          .cur_ch                 (cur_ch),
          .cur_op                 (cur_op),
          .alg                    (alg_I),
          .adpcmA_l               (adpcmA_l),
          .adpcmA_r               (adpcmA_r),
          .adpcmB_l               (adpcmB_l),
          .adpcmB_r               (adpcmB_r),
          .ym2610b                (ym2610b),
          // combined output
          .left                   (fm_snd_left),
          .right                  (fm_snd_right),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 53),
          .auto_ss_data_out       (auto_ss_u_acc_data_out),
          .auto_ss_ack            (auto_ss_u_acc_ack)

      );
    end else begin : gen_adpcm_no
      assign adpcmA_l     = 'd0;
      assign adpcmA_r     = 'd0;
      assign adpcmB_l     = 'd0;
      assign adpcmB_r     = 'd0;
      assign adpcma_addr  = 'd0;
      assign adpcma_bank  = 'd0;
      assign adpcma_roe_n = 'b1;
      assign adpcmb_addr  = 'd0;
      assign adpcmb_roe_n = 'd1;
      assign adpcma_flags = 0;
      assign adpcmb_flag  = 0;
    end
  endgenerate

  jt12_dout #(
      .use_ssg  (use_ssg),
      .use_adpcm(use_adpcm)
  ) u_dout (
      //    .rst_n          ( rst_n         ),
      .clk                    (clk),                            // CPU clock
      .flag_A                 (flag_A),
      .flag_B                 (flag_B),
      .busy                   (busy),
      .adpcma_flags           (adpcma_flags & flag_mask[5:0]),
      .adpcmb_flag            (adpcmb_flag & flag_mask[6]),
      .psg_dout               (psg_dout),
      .addr                   (addr),
      .dout                   (dout),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out       (auto_ss_u_dout_data_out),
      .auto_ss_ack            (auto_ss_u_dout_ack)

  );

  jt12_mmr #(
      .use_ssg  (use_ssg),
      .num_ch   (num_ch),
      .use_pcm  (use_pcm),
      .use_adpcm(use_adpcm),
      .mask_div (mask_div)
  ) u_mmr (
      .rst           (rst),
      .clk           (clk),
      .cen           (cen),             // external clock enable
      .clk_en        (clk_en),          // internal clock enable
      .clk_en_2      (clk_en_2),        // input cen divided by 2
      .clk_en_ssg    (clk_en_ssg),      // internal clock enable
      .clk_en_666    (clk_en_666),
      .clk_en_111    (clk_en_111),
      .clk_en_55     (clk_en_55),
      .din           (din),
      .write         (write),
      .addr          (addr),
      .busy          (busy),
      .ch6op         (ch6op),
      .cur_ch        (cur_ch),
      .cur_op        (cur_op),
      // LFO
      .lfo_freq      (lfo_freq),
      .lfo_en        (lfo_en),
      // Timers
      .value_A       (value_A),
      .value_B       (value_B),
      .load_A        (load_A),
      .load_B        (load_B),
      .enable_irq_A  (enable_irq_A),
      .enable_irq_B  (enable_irq_B),
      .clr_flag_A    (clr_flag_A),
      .clr_flag_B    (clr_flag_B),
      .flag_A        (flag_A),
      .overflow_A    (overflow_A),
      .fast_timers   (fast_timers),
      // PCM
      .pcm           (pcm),
      .pcm_en        (pcm_en),
      .pcm_wr        (pcm_wr),
      // ADPCM-A
      .aon_a         (aon_a),           // ON
      .atl_a         (atl_a),           // TL
      .addr_a        (addr_a),          // address latch
      .lracl         (lracl),           // L/R ADPCM Channel Level
      .up_start      (up_start),        // write enable start address latch
      .up_end        (up_end),          // write enable end address latch
      .up_addr       (up_addr),         // write enable end address latch
      .up_lracl      (up_lracl),
      .up_aon        (up_aon),
      // ADPCM-B
      .acmd_on_b     (acmd_on_b),       // Control - Process start, Key On
      .acmd_rep_b    (acmd_rep_b),      // Control - Repeat
      .acmd_rst_b    (acmd_rst_b),      // Control - Reset
      .acmd_up_b     (acmd_up_b),       // Control - New command received
      .alr_b         (alr_b),           // Left / Right
      .astart_b      (astart_b),        // Start address
      .aend_b        (aend_b),          // End   address
      .adeltan_b     (adeltan_b),       // Delta-N
      .aeg_b         (aeg_b),           // Envelope Generator Control
      .flag_ctl      (flag_ctl),
      .flag_mask     (flag_mask),
      // Operator
      .xuse_prevprev1(xuse_prevprev1),
      .xuse_internal (xuse_internal),
      .yuse_internal (yuse_internal),
      .xuse_prev2    (xuse_prev2),
      .yuse_prev1    (yuse_prev1),
      .yuse_prev2    (yuse_prev2),
      // PG
      .fnum_I        (fnum_I),
      .block_I       (block_I),
      .pg_stop       (pg_stop),
      // EG
      .rl            (rl),
      .fb_II         (fb_II),
      .alg_I         (alg_I),
      .pms_I         (pms_I),
      .ams_IV        (ams_IV),
      .amsen_IV      (amsen_IV),
      .dt1_I         (dt1_I),
      .mul_II        (mul_II),
      .tl_IV         (tl_IV),

      .ar_I (ar_I),
      .d1r_I(d1r_I),
      .d2r_I(d2r_I),
      .rr_I (rr_I),
      .sl_I (sl_I),
      .ks_II(ks_II),

      .eg_stop (eg_stop),
      // SSG operation
      .ssg_en_I(ssg_en_I),
      .ssg_eg_I(ssg_eg_I),

      .keyon_I                (keyon_I),
      // Operator
      .zero                   (zero),
      .s1_enters              (s1_enters),
      .s2_enters              (s2_enters),
      .s3_enters              (s3_enters),
      .s4_enters              (s4_enters),
      // PSG interace
      .psg_addr               (psg_addr),
      .psg_data               (psg_data),
      .psg_wr_n               (psg_wr_n),
      .debug_bus              (debug_bus),
      .div_setting            (div_setting),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 2),
      .auto_ss_data_out       (auto_ss_u_mmr_data_out),
      .auto_ss_ack            (auto_ss_u_mmr_ack)

  );

  // YM2203 seems to use a fixed cen/3 clock for the timers, regardless
  // of the prescaler setting
  wire timer_cen = fast_timers ? cen : clk_en;
  jt12_timers #(
      .num_ch(num_ch)
  ) u_timers (
      .clk                    (clk),
      .clk_en                 (timer_cen),
      .rst                    (rst),
      .zero                   (zero),
      .value_A                (value_A),
      .value_B                (value_B),
      .load_A                 (load_A),
      .load_B                 (load_B),
      .enable_irq_A           (enable_irq_A),
      .enable_irq_B           (enable_irq_B),
      .clr_flag_A             (clr_flag_A),
      .clr_flag_B             (clr_flag_B),
      .flag_A                 (flag_A),
      .flag_B                 (flag_B),
      .overflow_A             (overflow_A),
      .irq_n                  (irq_n),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 18),
      .auto_ss_data_out       (auto_ss_u_timers_data_out),
      .auto_ss_ack            (auto_ss_u_timers_ack)

  );

  // YM2203 does not have LFO
  generate
    if (use_lfo == 1) begin : gen_lfo
      jt12_lfo u_lfo (
          .rst   (rst),
          .clk   (clk),
          .clk_en(clk_en),
          .zero  (zero),

          .lfo_rst(1'b0),

          .lfo_en                 (lfo_en),
          .lfo_freq               (lfo_freq),
          .lfo_mod                (lfo_mod),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 56),
          .auto_ss_data_out       (auto_ss_u_lfo_data_out),
          .auto_ss_ack            (auto_ss_u_lfo_ack)

      );
    end else begin : gen_nolfo
      assign lfo_mod = 7'd0;
    end
  endgenerate

  // YM2203/YM2610 have a PSG


  generate
    if (use_ssg == 1) begin : gen_ssg
      jt49 #(
          .COMP         (3'b01),
          .CLKDIV       (JT49_DIV),
          .YM2203_LUMPED(YM2203_LUMPED)
      ) u_psg (  // note that input ports are not multiplexed
          .rst_n                  (~rst),
          .clk                    (clk),                           // signal on positive edge
          .clk_en                 (clk_en_ssg),                    // clock enable on negative edge
          .addr                   (psg_addr),
          .cs_n                   (1'b0),
          .wr_n                   (psg_wr_n),                      // write
          .din                    (psg_data),
          .sound                  (psg_snd),                       // combined output
          .A                      (psg_A),
          .B                      (psg_B),
          .C                      (psg_C),
          .dout                   (psg_dout),
          .sel                    (1'b1),                          // half clock speed
          .IOA_out                (IOA_out),
          .IOB_out                (IOB_out),
          .IOA_in                 (IOA_in),
          .IOB_in                 (IOB_in),
          .IOA_oe                 (IOA_oe),
          .IOB_oe                 (IOB_oe),
          // Unused:
          .sample                 (),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 57),
          .auto_ss_data_out       (auto_ss_u_psg_data_out),
          .auto_ss_ack            (auto_ss_u_psg_ack)

      );
      assign snd_left  = fm_snd_left;
      assign snd_right = fm_snd_right;
    end else begin : gen_nossg
      assign psg_snd   = 10'd0;
      assign snd_left  = fm_snd_left;
      assign snd_right = fm_snd_right;
      assign psg_dout  = 8'd0;
      assign psg_A     = 8'd0;
      assign psg_B     = 8'd0;
      assign psg_C     = 8'd0;
      assign IOA_oe    = 0;
      assign IOB_oe    = 0;
      assign IOA_out   = 0;
      assign IOB_out   = 0;
    end
  endgenerate


  wire [ 8:0] op_result;
  wire [13:0] op_result_hd;


  jt12_pg #(
      .num_ch(num_ch)
  ) u_pg (
      .rst                    (rst),
      .clk                    (clk),
      .clk_en                 (clk_en),
      // Channel frequency
      .fnum_I                 (fnum_I),
      .block_I                (block_I),
      // Operator multiplying
      .mul_II                 (mul_II),
      // Operator detuning
      .dt1_I                  (dt1_I),                         // same as JT51's DT1
      // Phase modulation by LFO
      .lfo_mod                (lfo_mod),
      .pms_I                  (pms_I),
      // phase operation
      .pg_rst_II              (pg_rst_II),
      .pg_stop                (pg_stop),
      .keycode_II             (keycode_II),
      .phase_VIII             (phase_VIII),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 21),
      .auto_ss_data_out       (auto_ss_u_pg_data_out),
      .auto_ss_ack            (auto_ss_u_pg_ack)

  );

  wire [9:0] eg_V;

  jt12_eg #(
      .num_ch(num_ch)
  ) u_eg (
      .rst       (rst),
      .clk       (clk),
      .clk_en    (clk_en),
      .zero      (zero),
      .eg_stop   (eg_stop),
      // envelope configuration
      .keycode_II(keycode_II),
      .arate_I   (ar_I),        // attack  rate
      .rate1_I   (d1r_I),       // decay   rate
      .rate2_I   (d2r_I),       // sustain rate
      .rrate_I   (rr_I),        // release rate
      .sl_I      (sl_I),        // sustain level
      .ks_II     (ks_II),       // key scale
      // SSG operation
      .ssg_en_I  (ssg_en_I),
      .ssg_eg_I  (ssg_eg_I),
      // envelope operation
      .keyon_I   (keyon_I),
      // envelope number
      .lfo_mod   (lfo_mod),
      .tl_IV     (tl_IV),
      .ams_IV    (ams_IV),
      .amsen_IV  (amsen_IV),

      .eg_V                   (eg_V),
      .pg_rst_II              (pg_rst_II),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 24),
      .auto_ss_data_out       (auto_ss_u_eg_data_out),
      .auto_ss_ack            (auto_ss_u_eg_ack)

  );

  jt12_sh #(
      .width (10),
      .stages(4)
  ) u_egpad (
      .clk                    (clk),
      .clk_en                 (clk_en),
      .din                    (eg_V),
      .drop                   (eg_IX),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 31),
      .auto_ss_data_out       (auto_ss_u_egpad_data_out),
      .auto_ss_ack            (auto_ss_u_egpad_ack)

  );

  jt12_op #(
      .num_ch(num_ch)
  ) u_op (
      .rst          (rst),
      .clk          (clk),
      .clk_en       (clk_en),
      .pg_phase_VIII(phase_VIII),
      .eg_atten_IX  (eg_IX),
      .fb_II        (fb_II),

      .test_214               (1'b0),
      .s1_enters              (s1_enters),
      .s2_enters              (s2_enters),
      .s3_enters              (s3_enters),
      .s4_enters              (s4_enters),
      .xuse_prevprev1         (xuse_prevprev1),
      .xuse_internal          (xuse_internal),
      .yuse_internal          (yuse_internal),
      .xuse_prev2             (xuse_prev2),
      .yuse_prev1             (yuse_prev1),
      .yuse_prev2             (yuse_prev2),
      .zero                   (zero),
      .op_result              (op_result),
      .full_result            (op_result_hd),
      .auto_ss_rd             (auto_ss_rd),
      .auto_ss_wr             (auto_ss_wr),
      .auto_ss_data_in        (auto_ss_data_in),
      .auto_ss_device_idx     (auto_ss_device_idx),
      .auto_ss_state_idx      (auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 32),
      .auto_ss_data_out       (auto_ss_u_op_data_out),
      .auto_ss_ack            (auto_ss_u_op_ack)

  );


  generate
    if (use_pcm == 1) begin : gen_pcm_acc  // YM2612 accumulator
      assign fm_snd_right[3:0] = 4'd0;
      assign fm_snd_left[3:0]  = 4'd0;
      assign snd_sample        = zero;
      reg signed [8:0] pcm2;

      // interpolate PCM samples with automatic sample rate detection
      // this feature is not present in original YM2612
      // this improves PCM sample sound greatly
      /*
        jt12_pcm u_pcm(
            .rst        ( rst       ),
            .clk        ( clk       ),
            .clk_en     ( clk_en    ),
            .zero       ( zero      ),
            .pcm        ( pcm       ),
            .pcm_wr     ( pcm_wr    ),
            .pcm_resampled ( pcm2   )
        );
        */
      wire             rst_pcm_n;

      jt12_rst u_rst_pcm (
          .rst                    (rst),
          .clk                    (clk),
          .rst_n                  (rst_pcm_n),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 67),
          .auto_ss_data_out       (auto_ss_u_rst_pcm_data_out),
          .auto_ss_ack            (auto_ss_u_rst_pcm_ack)

      );


      wire signed [10:0] pcm_full;
      always @(*) pcm2 = en_hifi_pcm ? pcm_full[9:1] : pcm;

      jt12_pcm_interpol #(
          .DW   (11),
          .stepw(5)
      ) u_pcm (
          .rst_n                  (rst_pcm_n),
          .clk                    (clk),
          .cen                    (clk_en),
          .cen55                  (clk_en_55),
          .pcm_wr                 (pcm_wr),
          .pcmin                  ({pcm[8], pcm, 1'b0}),
          .pcmout                 (pcm_full),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 68),
          .auto_ss_data_out       (auto_ss_u_pcm_data_out),
          .auto_ss_ack            (auto_ss_u_pcm_ack)

      );


      jt12_acc u_acc (
          .rst                    (rst),
          .clk                    (clk),
          .clk_en                 (clk_en),
          .op_result              (op_result),
          .rl                     (rl),
          // note that the order changes to deal
          // with the operator pipeline delay
          .zero                   (zero),
          .s1_enters              (s2_enters),
          .s2_enters              (s1_enters),
          .s3_enters              (s4_enters),
          .s4_enters              (s3_enters),
          .ch6op                  (ch6op),
          .pcm_en                 (pcm_en),                        // only enabled for channel 6
          .pcm                    (pcm2),
          .alg                    (alg_I),
          // combined output
          .left                   (fm_snd_left[15:4]),
          .right                  (fm_snd_right[15:4]),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 70),
          .auto_ss_data_out       (auto_ss_u_acc_data_out),
          .auto_ss_ack            (auto_ss_u_acc_ack)

      );
    end
    if (use_pcm == 0 && use_adpcm == 0) begin : gen_2203_acc  // YM2203 accumulator
      wire signed [15:0] mono_snd;
      assign fm_snd_left  = mono_snd;
      assign fm_snd_right = mono_snd;
      assign snd_sample   = zero;
      jt03_acc u_acc (
          .rst                    (rst),
          .clk                    (clk),
          .clk_en                 (clk_en),
          .op_result              (op_result_hd),
          // note that the order changes to deal
          // with the operator pipeline delay
          .s1_enters              (s1_enters),
          .s2_enters              (s2_enters),
          .s3_enters              (s3_enters),
          .s4_enters              (s4_enters),
          .alg                    (alg_I),
          .zero                   (zero),
          // combined output
          .snd                    (mono_snd),
          .auto_ss_rd             (auto_ss_rd),
          .auto_ss_wr             (auto_ss_wr),
          .auto_ss_data_in        (auto_ss_data_in),
          .auto_ss_device_idx     (auto_ss_device_idx),
          .auto_ss_state_idx      (auto_ss_state_idx),
          .auto_ss_base_device_idx(auto_ss_base_device_idx + 73),
          .auto_ss_data_out       (auto_ss_u_acc_data_out),
          .auto_ss_ack            (auto_ss_u_acc_ack)

      );
    end
  endgenerate


endmodule


///////////////////////////////////////////
// MODULE jt10
module jt10 (
    input       rst,   // rst should be at least 6 clk&cen cycles long
    input       clk,   // CPU clock
    input       cen,   // optional clock enable, if not needed leave as 1'b1
    input [7:0] din,
    input [1:0] addr,
    input       cs_n,
    input       wr_n,

    output [7:0] dout,
    output irq_n,
    // ADPCM pins
    output [19:0] adpcma_addr,  // real hardware has 10 pins multiplexed through RMPX pin
    output [3:0] adpcma_bank,
    output adpcma_roe_n,  // ADPCM-A ROM output enable
    input [7:0] adpcma_data,  // Data from RAM
    output [23:0] adpcmb_addr,  // real hardware has 12 pins multiplexed through PMPX pin
    output adpcmb_roe_n,  // ADPCM-B ROM output enable
    input [7:0] adpcmb_data,
    // Separated output
    output [7:0] psg_A,
    output [7:0] psg_B,
    output [7:0] psg_C,
    output signed [15:0] fm_snd,
    // combined output
    output [9:0] psg_snd,
    output signed [15:0] snd_right,
    output signed [15:0] snd_left,
    output snd_sample,
    input [5:0] ch_enable,
    input ym2610b,  // LOCAL (Arcade-TaitoB): six FM channels instead of four
    input auto_ss_rd,
    input auto_ss_wr,
    input [31:0] auto_ss_data_in,
    input [7:0] auto_ss_device_idx,
    input [15:0] auto_ss_state_idx,
    input [7:0] auto_ss_base_device_idx,
    output logic [31:0] auto_ss_data_out,
    output logic auto_ss_ack
    // ADPCM-A channels
);
  assign auto_ss_ack      = auto_ss_u_jt12_ack;

  assign auto_ss_data_out = auto_ss_u_jt12_data_out;

  wire        auto_ss_u_jt12_ack;

  wire [31:0] auto_ss_u_jt12_data_out;

  wire        device_match = (auto_ss_device_idx == auto_ss_base_device_idx);

  genvar auto_ss_idx;


  // Uses 6 FM channels but only 4 are outputted
  jt12_top #(
      .use_lfo  (1),
      .use_ssg  (1),
      .num_ch   (6),
      .use_pcm  (0),
      .use_adpcm(1),
      .JT49_DIV (3)
  ) u_jt12 (
      .rst (rst),   // rst should be at least 6 clk&cen cycles long
      .clk (clk),   // CPU clock
      .cen (cen),   // optional clock enable, it not needed leave as 1'b1
      .din (din),
      .addr(addr),
      .cs_n(cs_n),
      .wr_n(wr_n),

      .dout(dout),
      .irq_n(irq_n),
      // ADPCM pins
      .adpcma_addr(adpcma_addr),  // real hardware has 10 pins multiplexed through RMPX pin
      .adpcma_bank(adpcma_bank),
      .adpcma_roe_n(adpcma_roe_n),  // ADPCM-A ROM output enable
      .adpcma_data(adpcma_data),  // Data from RAM
      .adpcmb_addr(adpcmb_addr),  // real hardware has 12 pins multiplexed through PMPX pin
      .adpcmb_roe_n(adpcmb_roe_n),  // ADPCM-B ROM output enable
      .adpcmb_data(adpcmb_data),  // Data from RAM
      // Separated output
      .psg_A(psg_A),
      .psg_B(psg_B),
      .psg_C(psg_C),
      .psg_snd(psg_snd),
      .fm_snd_left(fm_snd),
      .fm_snd_right(),
      .adpcmA_l(),
      .adpcmA_r(),
      .adpcmB_l(),
      .adpcmB_r(),
      // Unused YM2203
      // unused
      .IOA_in(8'b0),
      .IOB_in(8'b0),
      .IOA_out(),
      .IOB_out(),
      .IOA_oe(),
      .IOB_oe(),
      .debug_bus(8'd0),
      // Sound output
      .snd_right(snd_right),
      .snd_left(snd_left),
      .snd_sample(snd_sample),
      .ch_enable(ch_enable),
      .ym2610b(ym2610b),
      // unused pins
      .en_hifi_pcm(1'b0),  // used only on YM2612 mode
      .debug_view(),
      .auto_ss_rd(auto_ss_rd),
      .auto_ss_wr(auto_ss_wr),
      .auto_ss_data_in(auto_ss_data_in),
      .auto_ss_device_idx(auto_ss_device_idx),
      .auto_ss_state_idx(auto_ss_state_idx),
      .auto_ss_base_device_idx(auto_ss_base_device_idx + 1),
      .auto_ss_data_out(auto_ss_u_jt12_data_out),
      .auto_ss_ack(auto_ss_u_jt12_ack)

  );

endmodule


