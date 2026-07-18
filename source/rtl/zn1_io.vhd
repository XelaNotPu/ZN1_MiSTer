-- ZN-1 Arcade I/O block
-- Handles the arcade-specific memory-mapped I/O at 0x1FA00000-0x1FAFFFFF.
-- All reads are 32-bit; addresses are the low 21 bits of the physical address.
--
-- Address map (CPU physical):
--   0x1FA00000  P1 inputs   [31:0]  active-low button bits
--   0x1FA00100  P2 inputs   [31:0]
--   0x1FA00200  Service     [31:0]
--   0x1FA00300  System      [31:0]  (coin counters, test, system)
--   0x1FA10000  P3 inputs   [31:0]  (unused for 2-player Visco games)
--   0x1FA10100  P4 inputs   [31:0]  (unused)
--   0x1FA10200  Board cfg   [7:0]   R/O: vmem/smem/ram size + rev bits
--   0x1FA10300  Sec select  [7:0]   R/W: selects CAT702 instance or ZNMCU
--   0x1FA20000  Coin I/O    [7:0]   R/W: coin counter / lockout outputs
--   0x1FAF0000  AT28C16     [7:0]   R/W: 2KB EEPROM (settings, high scores)
--
-- Input bit encoding for P1/P2 (active-low, matches ZN MAME driver):
--   [0]  Up       [1]  Down    [2]  Left   [3]  Right
--   [4]  Button1  [5]  Button2 [6]  Button3 [7]  Button4
--   [8]  Button5  [9]  Button6  all other bits: 1 (unused)
--   Start/Coin are NOT in P1/P2 — they are in the SYSTEM register (0x1FA00300).
--
-- SYSTEM register (0x1FA00300, active-low):
--   [0]  Start1   [1]  Start2   [4]  Coin1   [5]  Coin2  all other bits: 1

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

entity zn1_io is
   port (
      clk          : in  std_logic;
      reset        : in  std_logic;
      -- Bus interface (address = CPU[20:0], aligned to 32-bit)
      addr         : in  unsigned(20 downto 0);
      data_write   : in  std_logic_vector(31 downto 0);
      write_mask   : in  std_logic_vector(3 downto 0);   -- byte enables [3:0]=byte[3:0]
      read_en      : in  std_logic;
      write_en     : in  std_logic;
      data_read    : out std_logic_vector(31 downto 0);
      -- Player inputs (active high from MiSTer joystick)
      p1_right     : in  std_logic;
      p1_left      : in  std_logic;
      p1_down      : in  std_logic;
      p1_up        : in  std_logic;
      p1_btn       : in  std_logic_vector(5 downto 0);  -- buttons 1-6
      p1_start     : in  std_logic;
      p1_coin      : in  std_logic;
      p2_right     : in  std_logic;
      p2_left      : in  std_logic;
      p2_down      : in  std_logic;
      p2_up        : in  std_logic;
      p2_btn       : in  std_logic_vector(5 downto 0);
      p2_start     : in  std_logic;
      p2_coin      : in  std_logic;
      service      : in  std_logic;
      test_mode    : in  std_logic;
      -- Platform: 0=Visco, 1=Raizing, 2=Taito FX, 3=Atlus, 4=Tecmo. Drives boardconfig.
      zn_platform  : in  std_logic_vector(3 downto 0) := "0000";
      -- Security select: {data[7], data[3], data[2]} from 0x1FA10300 write
      -- [2]=bit7, [1]=bit3 (cat702[1]/KN02), [0]=bit2 (cat702[0]/KN01)
      sec_select   : out std_logic_vector(2 downto 0);
      -- Coin outputs (to coin counter LEDs if desired)
      coin_out     : out std_logic_vector(7 downto 0);
      -- EEPROM preload port (MRA ioctl index 9). During ioctl download the MIPS is held in
      -- reset, so these write straight into the EEPROM BRAM port A (muxed ahead of the CPU
      -- bus). Used to preload a valid AT28C16 image (e.g. Taito FX-1A "TAITO_TG..." NVRAM) so
      -- the game reads a valid signature and skips first-boot init. Games with no index-9 part
      -- keep the eeprom_ff.mif (all-0xFF) default. addr is the 32-bit word index (2KB=512 words);
      -- be selects which byte lanes of data are written (16-bit ioctl -> 2 bytes per write).
      ee_dl_wr     : in  std_logic := '0';
      ee_dl_addr   : in  std_logic_vector(8 downto 0) := (others => '0');
      ee_dl_data   : in  std_logic_vector(31 downto 0) := (others => '0');
      ee_dl_be     : in  std_logic_vector(3 downto 0)  := (others => '0');
      -- DIAGNOSTIC: last EEPROM word-0 value the CPU read back (to verify the preload landed)
      dbg_ee_word0 : out std_logic_vector(31 downto 0) := (others => '0');
      -- DIAGNOSTIC: EEPROM interaction stats for JTAG readout.
      -- [15:0]=write count (sat), [16]=write_seen, [17]=busy_seen (data-polling active on a read),
      -- [26:18]=last write addr, [34:27]=last write data, [36:35]=last write lane,
      -- [52:37]=last read addr(9)+read-was-polled(1)+6'b0, [68:53]=last read data[15:0].
      dbg_ee_stat  : out std_logic_vector(127 downto 0) := (others => '0')
   );
end entity;

architecture arch of zn1_io is

   signal sec_sel_r : std_logic_vector(2 downto 0) := "000";  -- default: 0 (nothing selected)
   signal coin_r    : std_logic_vector(7 downto 0) := x"FF";
   -- build #117b: store the full znsecsel byte for verifiable readback (MAME returns whatever
   -- was written). Without this, Taito BIOS write-verifies znsecsel and sees a mismatch.
   signal znsecsel_byte : std_logic_vector(7 downto 0) := x"00";
   -- FIX (loading): zn2_spu_hack register at 0x1FA60000. MAME's zn2_spu_hack_r
   -- TOGGLES bit 3 (^=8) on every read; DoA++ (and likely other ZN titles) poll
   -- this register during the post-coin load waiting for that bit to change.
   -- The FPGA previously returned 0 here (fell through to `when others => null`),
   -- so the poll never saw the toggle and spun ~55s until an internal timeout.
   -- Replicate MAME: return spu_hack_reg, toggling bit 3 once per read.
   signal spu_hack_reg  : std_logic_vector(15 downto 0) := (others => '0');
   signal spu_hack_rd_d : std_logic := '0';

   -- AT28C16 EEPROM: 2KB (512×32-bit words) at 0x1FAF0000-0x1FAF07FF.
   -- Implemented as altsyncram M10K (0 LABs) with 4-bit byte-enable.
   -- Not reset on soft-reset — contents persist across game resets like real EEPROM.
   -- M10K initialises to 0x00 at power-on; game detects uninitialised and writes defaults.
   signal eeprom_cs   : std_logic;                      -- address in EEPROM range
   signal eeprom_addr_s : std_logic_vector(8 downto 0); -- word address within EEPROM
   signal eeprom_wr   : std_logic;                      -- write enable to altsyncram
   signal eeprom_dout : std_logic_vector(31 downto 0);  -- unregistered M10K output
   -- EEPROM BRAM port-A inputs, muxed between the preload/download port (ee_dl_wr, active
   -- during ioctl load while the MIPS is in reset) and the live game bus path. The two are
   -- temporally exclusive (download happens only during ioctl load), so no contention.
   signal ee_ram_addr    : std_logic_vector(8 downto 0);
   signal ee_ram_wren    : std_logic;
   signal ee_ram_byteena : std_logic_vector(3 downto 0);
   signal ee_ram_data    : std_logic_vector(31 downto 0);

   -- Build a 32-bit P1/P2 input register, active-low. Start/Coin go in SYSTEM register.
   function make_input(r, l, d, u : std_logic;
                       btn : std_logic_vector(5 downto 0))
      return std_logic_vector is
      variable v : std_logic_vector(31 downto 0) := (others => '1');
   begin
      v(0)  := not u;     -- bit0 = Up
      v(1)  := not d;     -- bit1 = Down
      v(2)  := not l;     -- bit2 = Left
      v(3)  := not r;     -- bit3 = Right
      v(4)  := not btn(0);
      v(5)  := not btn(1);
      v(6)  := not btn(2);
      v(7)  := not btn(3);
      v(8)  := not btn(4);
      v(9)  := not btn(5);
      return v;
   end function;

   -- Board config register value (matches MAME zn_state::boardconfig_r):
   --   [7:5] = "011" → rev=1 (always for ZN-1)
   --   [3]   = vmem (1=2MB, 0=1MB) — set by m_gpu->vram_size() in MAME
   --   [2]   = smem (1=2MB SPU SGRAM) — MAME never sets this; left 0
   --   [1:0] = "01"  → RAM=4MB (ZN-1 standard)
   -- Per MAME zn.cpp: Taito FX-1A (coh1000ta) and FX-1B (coh1000tb) use zn1_1mb_vram (1MB).
   -- All other ZN-1 boards (Visco, Raizing, Atlus, Tecmo) use zn1_2mb_vram (2MB).
   -- Taito titles read this register at boot and use it to determine VRAM layout. Returning
   -- 0x69 (2MB) to a Taito BIOS expecting 0x61 (1MB) causes incorrect VRAM-Y addressing.
   signal board_cfg : std_logic_vector(7 downto 0);

   -- build #117: AT28C16 data-polling emulation. Real AT28C16 returns inverted bit 7 during
   -- 200μs write cycle (per MAME at28c16_device::read). Taito BIOS uses this to verify EEPROM
   -- is present (vs RAM). Without it, BIOS shows "EE-PROM ERROR". Track last-write addr/byte/data,
   -- 256-clk busy counter; reads to the busy byte return data XOR 0x80.
   signal eeprom_pending_addr : std_logic_vector(8 downto 0) := (others => '0');
   signal eeprom_pending_lane : std_logic_vector(1 downto 0) := (others => '0');
   signal eeprom_pending_data : std_logic_vector(7 downto 0) := (others => '0');
   signal eeprom_busy_count   : unsigned(7 downto 0) := (others => '0');
   signal eeprom_dout_polled  : std_logic_vector(31 downto 0);
   -- DIAGNOSTIC capture signals (EEPROM write/read activity for JTAG readout)
   signal dbg_ee_write_seen   : std_logic := '0';
   signal dbg_ee_busy_seen    : std_logic := '0';
   signal dbg_ee_write_cnt    : unsigned(15 downto 0) := (others => '0');
   signal dbg_ee_last_wr_addr : std_logic_vector(8 downto 0) := (others => '0');
   signal dbg_ee_last_wr_data : std_logic_vector(7 downto 0) := (others => '0');
   signal dbg_ee_last_wr_lane : std_logic_vector(1 downto 0) := (others => '0');
   signal dbg_ee_last_rd_addr : std_logic_vector(8 downto 0) := (others => '0');
   signal dbg_ee_last_rd_data : std_logic_vector(15 downto 0) := (others => '0');
   -- DIAGNOSTIC: first-read capture of EEPROM words 0-4 (initial validation reads)
   signal dbg_ee_rd_w0        : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_ee_rd_w1        : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_ee_rd_w2        : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_ee_rd_w3        : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_ee_rd_w4        : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_ee_rd_cap       : std_logic_vector(4 downto 0)  := (others => '0');

begin

   sec_select <= sec_sel_r;
   coin_out   <= coin_r;

   -- Board config: clear bit 3 (vmem) for Taito (1MB VRAM), set otherwise.
   board_cfg <= "01100001" when zn_platform = "0010" else  -- 0x61: Taito FX-1A/FX-1B (1MB VRAM)
                "01101001";                                  -- 0x69: all others (2MB VRAM)

   -- EEPROM address decode and write enable (combinatorial).
   -- FIX (loading): the AT28C16 (2KB) is decoded coarsely on real ZN HW and
   -- MIRRORS across the whole 0x1FAF0000-0x1FAFFFFF page. DoA++ accesses the
   -- EEPROM via a mirror (~0x1FAF7xxx) during the post-coin load to save/poll
   -- data; the previous narrow decode (only 0x1FAF0000-0x1FAF07FF) returned 0
   -- there, so the EEPROM write+data-poll never completed and the game spun
   -- ~55s to a timeout. Widen to addr(20:16)="01111" (0x1FAF0000-0x1FAFFFFF);
   -- eeprom_addr_s = addr(10:2) keeps the 2KB mirrored.
   eeprom_cs     <= '1' when std_logic_vector(addr(20 downto 16)) = "01111" else '0';
   eeprom_addr_s <= std_logic_vector(addr(10 downto 2));
   eeprom_wr     <= write_en and eeprom_cs;

   -- build #117: data-polling state machine
   process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' then
            eeprom_busy_count <= (others => '0');
         else
            if eeprom_wr = '1' then
               -- Capture last byte written. For multi-byte writes (SH/SW), priority is byte 0.
               -- MAME at28c16_device::write(): the busy/data-poll window (and the write) only
               -- engage when the new byte DIFFERS from what is stored (read_byte(offset) != data).
               -- Writing an already-matching byte is a no-op with NO busy window. Without this,
               -- a game that rewrites already-correct NVRAM (psyforce with a valid preload) sees
               -- the toggle bit (data^0x80) on every verify read and never converges → EE-PROM
               -- ERROR. eeprom_dout is the current stored word at eeprom_addr_s (pre-write).
               eeprom_pending_addr <= eeprom_addr_s;
               if write_mask(0) = '1' then
                  eeprom_pending_lane <= "00";
                  eeprom_pending_data <= data_write(7 downto 0);
                  if data_write( 7 downto  0) /= eeprom_dout( 7 downto  0) then eeprom_busy_count <= to_unsigned(255, 8); end if;
               elsif write_mask(1) = '1' then
                  eeprom_pending_lane <= "01";
                  eeprom_pending_data <= data_write(15 downto 8);
                  if data_write(15 downto  8) /= eeprom_dout(15 downto  8) then eeprom_busy_count <= to_unsigned(255, 8); end if;
               elsif write_mask(2) = '1' then
                  eeprom_pending_lane <= "10";
                  eeprom_pending_data <= data_write(23 downto 16);
                  if data_write(23 downto 16) /= eeprom_dout(23 downto 16) then eeprom_busy_count <= to_unsigned(255, 8); end if;
               else
                  eeprom_pending_lane <= "11";
                  eeprom_pending_data <= data_write(31 downto 24);
                  if data_write(31 downto 24) /= eeprom_dout(31 downto 24) then eeprom_busy_count <= to_unsigned(255, 8); end if;
               end if;
            elsif eeprom_busy_count > 0 then
               eeprom_busy_count <= eeprom_busy_count - 1;
            end if;

            -- DIAGNOSTIC capture: EEPROM write/read activity for JTAG readout
            if eeprom_wr = '1' then
               dbg_ee_write_seen <= '1';
               if dbg_ee_write_cnt /= x"FFFF" then dbg_ee_write_cnt <= dbg_ee_write_cnt + 1; end if;
               dbg_ee_last_wr_addr <= eeprom_addr_s;
               if write_mask(0) = '1' then dbg_ee_last_wr_data <= data_write(7 downto 0); dbg_ee_last_wr_lane <= "00";
               elsif write_mask(1) = '1' then dbg_ee_last_wr_data <= data_write(15 downto 8); dbg_ee_last_wr_lane <= "01";
               elsif write_mask(2) = '1' then dbg_ee_last_wr_data <= data_write(23 downto 16); dbg_ee_last_wr_lane <= "10";
               else dbg_ee_last_wr_data <= data_write(31 downto 24); dbg_ee_last_wr_lane <= "11"; end if;
            end if;
            if read_en = '1' and eeprom_cs = '1' then
               dbg_ee_last_rd_addr <= eeprom_addr_s;
               dbg_ee_last_rd_data <= eeprom_dout(15 downto 0);
               if eeprom_busy_count > 0 then dbg_ee_busy_seen <= '1'; end if;
               -- DIAGNOSTIC: latch the FIRST read of EEPROM words 0-4 while NOT busy (= the game's
               -- initial NVRAM validation read, before it writes). Golden signature "TAITO_TG.."+cfg:
               -- w0=54494154 w1=47545F4F w2=0007B8A4 w3=C3040203 w4=00001211. If these read golden,
               -- the preload LOADED correctly and the bug is in write/verify; if garbage, load bug.
               if eeprom_busy_count = 0 then
                  if    eeprom_addr_s = "000000000" and dbg_ee_rd_cap(0) = '0' then dbg_ee_rd_w0 <= eeprom_dout; dbg_ee_rd_cap(0) <= '1';
                  elsif eeprom_addr_s = "000000001" and dbg_ee_rd_cap(1) = '0' then dbg_ee_rd_w1 <= eeprom_dout; dbg_ee_rd_cap(1) <= '1';
                  elsif eeprom_addr_s = "000000010" and dbg_ee_rd_cap(2) = '0' then dbg_ee_rd_w2 <= eeprom_dout; dbg_ee_rd_cap(2) <= '1';
                  elsif eeprom_addr_s = "000000011" and dbg_ee_rd_cap(3) = '0' then dbg_ee_rd_w3 <= eeprom_dout; dbg_ee_rd_cap(3) <= '1';
                  elsif eeprom_addr_s = "000000100" and dbg_ee_rd_cap(4) = '0' then dbg_ee_rd_w4 <= eeprom_dout; dbg_ee_rd_cap(4) <= '1';
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;

   -- DIAGNOSTIC pack: 5-word EEPROM validation-read dump (FIRST read of each word, not busy).
   -- dbg_ee_word0 -> zn_debug_words[159:128] = word0; words 1-4 packed here. The ZNSC JTAG probe
   -- then exposes words 0..4 = the "TAITO_TG"+cfg signature exactly as the game read it during
   -- initial NVRAM validation. Golden: w0=54494154 w1=47545F4F w2=0007B8A4 w3=C3040203 w4=00001211.
   dbg_ee_word0               <= dbg_ee_rd_w0;
   dbg_ee_stat(127 downto 96) <= dbg_ee_rd_w1;
   dbg_ee_stat( 95 downto 64) <= dbg_ee_rd_w2;
   dbg_ee_stat( 63 downto 32) <= dbg_ee_rd_w3;
   dbg_ee_stat( 31 downto  0) <= dbg_ee_rd_w4;

   -- Override the BRAM output byte for the busy address with inverted bit 7.
   -- Per MAME: read returns m_last_write XOR 0x80 during write-in-progress.
   eeprom_dout_polled <=
      eeprom_dout(31 downto 24) & eeprom_dout(23 downto 16) & eeprom_dout(15 downto 8)
         & (eeprom_pending_data xor x"80")
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "00") else
      eeprom_dout(31 downto 24) & eeprom_dout(23 downto 16)
         & (eeprom_pending_data xor x"80") & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "01") else
      eeprom_dout(31 downto 24)
         & (eeprom_pending_data xor x"80") & eeprom_dout(15 downto 8) & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "10") else
      (eeprom_pending_data xor x"80")
         & eeprom_dout(23 downto 16) & eeprom_dout(15 downto 8) & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "11") else
      eeprom_dout;

   -- AT28C16: 512×32-bit M10K BRAM, 4-bit byte-enable, unregistered output.
   -- UNREGISTERED output: q_a reflects data at address_a with 1 clock cycle latency
   -- (addr sampled at rising edge → q_a valid before next edge), which matches the
   -- BUSREADREQUEST→BUSREAD 2-cycle window in memorymux.
   -- build #115: initialize EEPROM BRAM to 0xFF (AT28C16 factory state per MAME nvram_default).
   -- Without this, Taito titles show "EEPROM ERROR" because they read 0x00 (BRAM default)
   -- and treat it as corrupt EEPROM, never reaching game logic.
   -- Port-A mux: during ioctl preload (ee_dl_wr='1', MIPS in reset) the download drives
   -- address/wren/byteena/data; otherwise the live game bus does. init_file still provides the
   -- all-0xFF power-up state for games whose MRA ships no index-9 EEPROM part.
   ee_ram_addr    <= ee_dl_addr when ee_dl_wr = '1' else eeprom_addr_s;
   ee_ram_wren    <= '1'        when ee_dl_wr = '1' else eeprom_wr;
   ee_ram_byteena <= ee_dl_be   when ee_dl_wr = '1' else write_mask;
   ee_ram_data    <= ee_dl_data when ee_dl_wr = '1' else data_write;

   ieeprom : altsyncram
   generic map (
      operation_mode      => "SINGLE_PORT",
      width_a             => 32,
      widthad_a           => 9,
      numwords_a          => 512,
      width_byteena_a     => 4,
      outdata_reg_a       => "UNREGISTERED",
      ram_block_type      => "M10K",
      init_file           => "eeprom_ff.mif",
      lpm_type            => "altsyncram"
   )
   port map (
      clock0    => clk,
      address_a => ee_ram_addr,
      wren_a    => ee_ram_wren,
      byteena_a => ee_ram_byteena,
      data_a    => ee_ram_data,
      q_a       => eeprom_dout
   );

   process(clk)
      variable p1_v, p2_v, svc_v, sys_v : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            sec_sel_r <= "000";  -- reset: nothing selected (distinguishes from BIOS 0x0C write)
            coin_r    <= x"FF";
            data_read <= (others => '1');
         else
            p1_v  := make_input(p1_right, p1_left, p1_down, p1_up, p1_btn);
            p2_v  := make_input(p2_right, p2_left, p2_down, p2_up, p2_btn);

            -- Service register 0x1FA00200: bit0=test(SERVICE2), bit1=service(SERVICE1)
            svc_v := (others => '1');
            svc_v(0) := not test_mode;
            svc_v(1) := not service;

            -- System register 0x1FA00300: bit0=START1, bit1=START2, bit4=COIN1, bit5=COIN2
            sys_v := (others => '1');
            sys_v(0) := not p1_start;
            sys_v(1) := not p2_start;
            sys_v(4) := not p1_coin;
            sys_v(5) := not p2_coin;

            data_read <= (others => '0');  -- must be 0: dataFromBusses in memorymux is OR-reduced

            -- FIX (loading): toggle bit 3 of the zn2_spu_hack reg (0x1FA60000)
            -- exactly once per read (rising edge of read_en at that address),
            -- matching MAME's `m_zn2_spu_hack ^= 8` so the load's poll exits.
            if (read_en = '1' and addr(20 downto 2) = "0011000000000000000") then
               if spu_hack_rd_d = '0' then
                  spu_hack_reg(3) <= not spu_hack_reg(3);
               end if;
               spu_hack_rd_d <= '1';
            else
               spu_hack_rd_d <= '0';
            end if;

            if eeprom_cs = '1' then
               if read_en = '1' then
                  data_read <= eeprom_dout_polled;  -- build #117: data-polling overlay
               end if;
               -- writes handled combinatorially via eeprom_wr → altsyncram
            else

               if read_en = '1' then
                  -- addr(20 downto 2) = word index = byte_offset/4; patterns: format(byte>>2, '019b')
                  case addr(20 downto 2) is
                     when "0000000000000000000" =>  -- 0x000000 P1
                        data_read <= p1_v;
                     when "0000000000001000000" =>  -- 0x000100 P2
                        data_read <= p2_v;
                     when "0000000000010000000" =>  -- 0x000200 Service
                        data_read <= svc_v;
                     when "0000000000011000000" =>  -- 0x000300 System
                        data_read <= sys_v;
                     when "0000100000000000000" =>  -- 0x010000 P3 (unused, all not-pressed)
                        data_read <= (others => '1');
                     when "0000100000001000000" =>  -- 0x010100 P4 (unused, all not-pressed)
                        data_read <= (others => '1');
                     when "0000100000010000000" =>  -- 0x010200 Board config
                        data_read <= x"000000" & board_cfg;
                     when "0000100000011000000" =>  -- 0x010300 Sec select
                        -- build #117b: return full byte (MAME returns m_znsecsel verbatim)
                        data_read <= x"000000" & znsecsel_byte;
                     when "0001000000000000000" =>  -- 0x020000 Coin I/O
                        data_read <= x"000000" & coin_r;
                     when "0011000000000000000" =>  -- 0x060000 zn2_spu_hack (MAME toggles bit 3 each read)
                        data_read <= x"0000" & spu_hack_reg;
                     when others =>
                        null;  -- MAME: noprw/nopr returns 0 for unrecognised ZN I/O addresses
                  end case;
               end if;

               if write_en = '1' then
                  case addr(20 downto 2) is
                     when "0000100000011000000" =>  -- 0x010300 Sec select
                        sec_sel_r <= data_write(7) & data_write(3 downto 2);
                        znsecsel_byte <= data_write(7 downto 0);  -- build #117b
                     when "0001000000000000000" =>  -- 0x020000 Coin I/O
                        coin_r <= data_write(7 downto 0);
                     when others => null;
                  end case;
               end if;

            end if;
         end if;
      end if;
   end process;

end architecture;
