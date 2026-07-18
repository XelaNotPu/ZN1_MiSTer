-- ZN SIO0 Security Adapter
-- Hooks into the PSX joypad SNAC interface to emulate CAT702 A/B and ZNMCU.
-- Uses the byte-level SNAC protocol: fires actionNextSnac twice per byte:
--   pulse 1 (after DELAY1 cycles): actionNext + receiveValid + ack — latches byte and asserts ACK
--   pulse 2 (after DELAY2 more cycles): actionNext only — advances joypad to next byte
--
-- CAT702 chip select is ACTIVE LOW: write_select(BIT(data,2)) for cat702[0]=KN01,
--                                   write_select(BIT(data,3)) for cat702[1]=KN02.
-- sec_select[2:0] = {data_write[7], data_write[3], data_write[2]} from BIOS write to 0x1FA10300:
--   sec_select="000" (0x00: bit3=0,bit2=0) → BOTH chips active (wired-AND TXD)  ← Tecmo BIOS
--   sec_select="101" (0x84: bit7=1,bit3=0,bit2=1) → KN02 only (bit3=0→active-low select)
--   sec_select="110" (0x88: bit7=1,bit3=1,bit2=0) → KN01 only (bit2=0→active-low select)
--   sec_select="111" (0x8C: all three bits set)    → ZNMCU selected (MAME: (data&0x8C)==0x8C)
--   sec_select="011" (0x0C: bit7=0,bit3=1,bit2=1) → both deselected (no exchange expected)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity zn_sio is
   port (
      clk           : in  std_logic;
      reset         : in  std_logic;
      -- SNAC byte interface (connected to joypad SNAC ports in psx_top)
      beginTransfer : in  std_logic;  -- 1-cycle pulse at start of each byte from host
      txbyte        : in  std_logic_vector(7 downto 0);  -- byte host is sending
      rxbyte        : out std_logic_vector(7 downto 0);  -- byte we return to host
      action_next   : out std_logic;  -- actionNextSnac to joypad
      receive_valid : out std_logic;  -- receiveValidSnac to joypad
      ack           : out std_logic;  -- ackSnac to joypad
      -- Chip select: high when joypad SNAC port 2 is active (selectedPort2Snac).
      -- Rising edge (0→1) resets CAT702 state to 0xFC, matching real hardware.
      chip_sel      : in  std_logic;
      -- ZN security select (from zn1_io register 0x1FA10300)
      -- [2]=data[7], [1]=data[3], [0]=data[2]; ZNMCU when all three bits set ("111"=0x8C per MAME logic)
      sec_select    : in  std_logic_vector(2 downto 0);
      -- CAT702 keys (64 bits = 8 bytes each, byte 0 in bits [7:0])
      -- cat702_key   = mg01/KN01 chip; active when sec_select[0]='0' (data[2]=0, active-low)
      -- cat702_key_b = mg05/KN02 chip; active when sec_select[1]='0' (data[3]=0, active-low)
      -- Both active when sec_select="000" (0x00): outputs are ANDed (wired-AND / open-drain)
      cat702_key    : in  std_logic_vector(63 downto 0);
      cat702_key_b  : in  std_logic_vector(63 downto 0);
      -- ZNMCU inputs
      dsw           : in  std_logic_vector(7 downto 0);
      coin1         : in  std_logic;
      coin2         : in  std_logic;
      service       : in  std_logic;
      frame_tick    : in  std_logic;
      -- build #119: CAT702 byte-exchange diagnostics
      -- dbg_first_kn01_rx: first RX byte seen for KN01 (KN01-only events). Expected 0xFF per MAME exchange 0.
      -- dbg_first_kn02_rx: first RX byte seen for KN02 (KN02-only events). Expected 0xAF per MAME psyforce exchange 8.
      -- dbg_kn02_ever:     '1' if any KN02-only byte exchange occurred since reset.
      dbg_first_kn01_rx : out std_logic_vector(7 downto 0) := (others => '0');
      dbg_first_kn02_rx : out std_logic_vector(7 downto 0) := (others => '0');
      dbg_kn02_ever     : out std_logic := '0';
      -- build #157: capture bytes 0 and 3 of the FIRST chip-A (KN01) exchange after a
      -- fresh chip-A select. MAME ground truth for BR2 Ex1 with et01 motherboard key:
      --   byte0 = 0xFF, byte3 = 0x0A. If FPGA matches, the algorithm is right and the bug
      --   is elsewhere. If different, this localises a CAT702 byte-level mismatch.
      dbg_b157_byte0    : out std_logic_vector(7 downto 0) := (others => '0');
      dbg_b157_byte3    : out std_logic_vector(7 downto 0) := (others => '0');
      dbg_b157_anchor   : out std_logic := '0';
      -- ===== PROPOSED FIX (Tecmo ZNMCU boot-hang, e.g. mfjump) =====
      -- ZNMCU unsolicited DSR pulse. 1-cycle strobe emitted ~50us after the ZNMCU
      -- is selected (and again after byte0), mirroring MAME znmcu_device's DSR line.
      -- psx_top ORs this into irq_PAD so irq.vhd latches it into I_STATUS bit7 (the
      -- SIO0/controller IRQ the game polls). Without it, Tecmo titles that read the
      -- ZNMCU per-frame poll I_STAT bit7 for a pulse that never comes and take their
      -- "time out a/b" error path (black screen). See arch body for details.
      znmcu_irq         : out std_logic := '0';
      -- ===== FIX (tondemo/twcupmil game-side CAT702 abort loop, task #285) =====
      -- Programmed SIO0 baud reload value (JOY_BAUD register, from joypad.vhd).
      -- Used to scale the first-pulse latency to ~one real byte-time so that
      -- RX-ready (JOY_STAT bit1) and the completion IRQ (I_STAT bit7) arrive with
      -- real-hardware timing at every baud. tondemo runs its game-side CAT702
      -- driver at JOY_BAUD=2 (~2 MHz, byte=16 clk) and bounds its I_STAT-bit7
      -- poll to ~81 iterations; the old fixed DELAY1=1200 exceeded that budget,
      -- so every byte "timed out", the driver aborted (RX path itself was
      -- byte-exact - proven by 211/211 replay vs MAME) and the verification
      -- restarted forever (the endless 0x88/0x84/0x0C znsecsel churn).
      joy_baud          : in  std_logic_vector(15 downto 0) := x"0088"
   );
end entity;

architecture arch of zn_sio is

   -- Timing: delay from beginTransfer before firing first actionNext pulse.
   -- Must exceed one full byte time at the slowest JOY_BAUD setting used by ZN BIOS.
   -- ZN BIOS uses ~300 KHz (JOY_BAUD≈136, byte=1088 clk) and ~2 MHz (JOY_BAUD≈17).
   constant DELAY1 : integer := 1200;  -- > 1088, safe for both speeds
   -- Lower clamp for the dynamic (baud-scaled) first-pulse latency. Must leave the
   -- response-computation window at the end of WAIT1 intact and stay comfortably
   -- above the joypad SNAC handoff (txbyte stable 1 cycle after beginTransfer).
   constant DELAY1_MIN : integer := 32;
   -- Delay between pulse 1 and pulse 2.
   -- MUST be SMALL enough that PULSE2 fires BEFORE the CPU writes the next TX byte
   -- in polling mode. The joypad.vhd chaining mechanism (PULSE2 with transmitFilled=1)
   -- fires beginTransfer while zn_sio is still in PULSE2 state (not IDLE), so the
   -- pulse is missed → poll timeout → exchange failure → blue screen.
   -- Tecmo BIOS (polling mode) writes next TX ~25+ cycles after PULSE1 (uncached IO).
   -- Visco BIOS (interrupt mode) writes TX after PULSE2 via ISR → no chaining issue.
   -- 5 cycles (PULSE2 fires 6 cycles after PULSE1) is safe: < 25 cycle minimum CPU path.
   constant DELAY2 : integer := 5;

   -- CAT702 sbox types (reused from cat702.vhd logic)
   type t_sbox8 is array(0 to 7) of std_logic_vector(7 downto 0);

   constant INITIAL_SBOX : t_sbox8 := (
      x"FF", x"FE", x"FC", x"F8", x"F0", x"E0", x"C0", x"7F"
   );

   -- Extract byte i from the 64-bit key (byte 0 at bits [7:0])
   function key_byte(k : std_logic_vector(63 downto 0); idx : integer)
      return std_logic_vector is
   begin
      return k(idx*8+7 downto idx*8);
   end function;

   -- Apply TF2 (fixed initial sbox) to state
   function apply_tf2(s : std_logic_vector(7 downto 0))
      return std_logic_vector is
      variable r : std_logic_vector(7 downto 0) := (others => '0');
   begin
      for i in 0 to 7 loop
         if s(i) = '1' then
            r := r xor INITIAL_SBOX(i);
         end if;
      end loop;
      return r;
   end function;

   -- Recursive sbox coefficient derivation (identical to cat702.vhd)
   function compute_coef(k : std_logic_vector(63 downto 0); sel : integer; bit_in : integer)
      return std_logic_vector is
      variable r  : std_logic_vector(7 downto 0);
      variable r0 : std_logic_vector(7 downto 0);
   begin
      if sel = 0 then
         return key_byte(k, bit_in);
      else
         r := compute_coef(k, sel-1, (bit_in-1) mod 8);
         r := r(6 downto 0) & (r(7) xor r(6));  -- Shift
         if bit_in /= 7 then
            return r;
         else
            r0 := compute_coef(k, sel, 0);
            return r xor r0;
         end if;
      end if;
   end function;

   function get_coefs(k : std_logic_vector(63 downto 0); sel : integer)
      return t_sbox8 is
      variable c : t_sbox8;
   begin
      for i in 0 to 7 loop
         c(i) := compute_coef(k, sel, i);
      end loop;
      return c;
   end function;

   function apply_sbox(s : std_logic_vector(7 downto 0); coefs : t_sbox8)
      return std_logic_vector is
      variable r : std_logic_vector(7 downto 0) := (others => '0');
   begin
      for i in 0 to 7 loop
         if s(i) = '1' then
            r := r xor coefs(i);
         end if;
      end loop;
      return r;
   end function;

   -- Process one CAT702 byte exchange.
   -- TF2 is applied at the start of every byte (matches real hardware:
   -- the initial sbox fires on every falling edge when bit counter == 0).
   -- Returns (new_state, response_byte).
   procedure cat702_byte(
      key     : in  std_logic_vector(63 downto 0);
      tx      : in  std_logic_vector(7 downto 0);
      st_in   : in  std_logic_vector(7 downto 0);
      rx      : out std_logic_vector(7 downto 0);
      st_out  : out std_logic_vector(7 downto 0)
   ) is
      variable s     : std_logic_vector(7 downto 0);
      variable r     : std_logic_vector(7 downto 0);
      variable coefs : t_sbox8;
   begin
      s := apply_tf2(st_in);  -- always applied, once per byte
      r := (others => '0');
      for i in 0 to 7 loop
         r(i) := s(i);
         if tx(i) = '0' then
            coefs := get_coefs(key, i);
            s := apply_sbox(s, coefs);
         end if;
      end loop;
      rx     := r;
      st_out := s;
   end procedure;

   -- CAT702 state — separate register per chip; both reset to 0xFC on session start.
   -- cat_state_a = mg01/KN01 state; cat_state_b = mg05/KN02 state.
   signal cat_state_a   : std_logic_vector(7 downto 0) := x"FC";
   signal cat_state_b   : std_logic_vector(7 downto 0) := x"FC";
   signal prev_sec      : std_logic_vector(2 downto 0) := "011";  -- both chips deselected (active-low)
   signal prev_chip_sel : std_logic := '0';

   -- ZNMCU state (MAME reference: src/mame/sony/znmcu.cpp znmcu_device)
   -- MAME protocol: select is active when (znsecsel & 0x8C) == 0x8C. On the
   -- select-active edge the bit/byte counters reset; 50us later the MCU pulses
   -- DSR low for 5us (and again after each non-final byte). Session content:
   --   byte0 = (databytes << 4) | (dsw & 0x0F); databytes = 8 if analog_read
   --   (znsecsel bit4), 6 if trackball_read (bit5), else 1 (standard mode).
   --   In standard mode every byte after byte0 is 0x00 (m_send[] is zero-filled
   --   and bytes beyond databytes shift out 0 bits).
   -- Known limitations of this implementation (documented, not open bugs):
   --   * znsecsel bits 4/5 are not wired into sec_select (zn1_io extracts only
   --     bits 7,3,2), so analog/trackball sessions cannot be distinguished.
   --     No ZN-1 title in this core's library uses them (Taito FX-1 is all
   --     digital), so standard mode (databytes=1) is always assumed.
   --   * The unsolicited 50us DSR pulse BEFORE the first byte cannot be
   --     emulated from here: joypad.vhd sets JOY_STAT bit7 only via a completed
   --     transfer (waitAck path). The Taito FX-1 BIOS polls JOY_STAT bit7 for
   --     that pulse (BFC0B0A0..BFC0B11C) but falls through after a bounded
   --     0x2710-iteration timeout and clocks the byte anyway, so the missing
   --     pre-byte pulse is non-fatal (verified via MAME debugger trace).
   signal znmcu_byte    : unsigned(1 downto 0) := (others => '0');
   signal znmcu_frame   : unsigned(7 downto 0) := (others => '0');
   -- High from a ZNMCU-mode beginTransfer until the FSM completes (PULSE2).
   -- While set, receive_valid/ack are asserted as LEVELS so that port-1
   -- (JOY_CTRL bit13=0) transfers — sampled by joypad.vhd's internal baud
   -- engine ~JOY_BAUD*8 cycles after beginTransfer, long before this FSM's
   -- SNAC pulses at DELAY1 — still pick up the ZNMCU response byte and set
   -- the post-byte ACK (JOY_STAT bit7), mirroring MAME's inter-byte DSR pulse.
   -- The Taito FX-1 BIOS reads the ZNMCU on SIO port 1 (JOY_CTRL=0x0003),
   -- where the SNAC path (enabled for port 2 only) never engages; without
   -- this, joypad.vhd returns 0xFF instead of byte0=0x10|dsw[3:0].
   signal znmcu_session : std_logic := '0';

   -- ===== PROPOSED FIX (Tecmo ZNMCU boot-hang) =====
   -- MAME znmcu_device arms a 50us timer on select-active that drives DSR low
   -- (raising SIO0 IRQ7 / I_STAT bit7), then re-arms after each byte while the
   -- transferred byte index < databytes. In this core databytes is always 1
   -- (standard digital mode, see header), so MAME emits exactly TWO DSR pulses per
   -- session: one on select (before byte0) and one after byte0 (before byte1).
   -- mfjump asserts DTR (JOY_CTRL=0x1013, ACKIEN set) then polls I_STAT bit7 for
   -- these pulses BEFORE clocking any byte; on timeout it prints "time out a/b" and
   -- aborts to a black screen. We reproduce the pulses as a 1-cycle znmcu_irq strobe.
   -- ZNMCU_DSR_DELAY ~= 50us at 33.8688 MHz clk1x; value is non-critical (must land
   -- after the game clears I_STAT and before its ~10000-iteration poll timeout).
   constant ZNMCU_DSR_DELAY : integer := 1693;
   signal znmcu_dsr_timer   : integer range 0 to 2047 := 0;   -- 0 = idle
   signal znmcu_dsr_count   : unsigned(1 downto 0) := (others => '0'); -- DSR pulses emitted this session
   signal znmcu_irq_r       : std_logic := '0';               -- 1-cycle output strobe

   -- Timing state machine
   type tState is (IDLE, WAIT1, PULSE1, WAIT2, PULSE2);
   signal state       : tState := IDLE;
   signal timer       : integer range 0 to 1299 := 0;
   signal rxbyte_r    : std_logic_vector(7 downto 0) := (others => '1');

   -- build #143: latch sec_select at beginTransfer so classification at WAIT1
   -- end uses the value present when the SIO session started, not whatever value
   -- the BIOS may have written during the ~1300-cycle WAIT1 delay. Without this,
   -- back-to-back exchanges where BIOS writes the NEXT sec_select before the
   -- CURRENT exchange completes get misclassified — root cause of "B122: 8 extra
   -- KN02 byte events" and likely the same bug halting Atlus/Tecmo/Taito/Raizing.
   signal sec_select_latched : std_logic_vector(2 downto 0) := "011";

   -- build #119/120/121/122/123 diagnostics
   -- B119-121: verified KN02 bytes 1-4 = AF, 95, 94, 14 match MAME exchange 8 exactly
   -- B122: FPGA count=58 vs MAME=50 → 8 EXTRA KN02 byte events on FPGA. Last byte 0xF5 vs expected 0x11.
   -- B123: capture KN02 byte at index 50 (= MAME's last). Verify exchange 8 is byte-perfect through 50,
   --       and that the extra 8 bytes are spurious (post-exchange-8 misclassification).
   signal first_kn01_rx_r   : std_logic_vector(7 downto 0) := (others => '0');
   signal byte_50_kn02_rx_r : std_logic_vector(7 downto 0) := (others => '0');
   signal last_kn02_rx_r    : std_logic_vector(7 downto 0) := (others => '0');
   signal kn01_captured_r   : std_logic := '0';
   signal kn02_count_r      : unsigned(7 downto 0) := (others => '0');
   signal kn02_ever_r       : std_logic := '0';
   -- build #157: per-chip-A-exchange byte counter + byte0/byte3 latch for first exchange
   signal b157_cycle_byte   : unsigned(3 downto 0) := (others => '0');  -- byte index within current chip-A active window
   signal b157_byte0_r      : std_logic_vector(7 downto 0) := (others => '0');
   signal b157_byte3_r      : std_logic_vector(7 downto 0) := (others => '0');
   signal b157_anchor_r     : std_logic := '0';

   -- Baud-scaled first-pulse latency (task #285, tondemo/twcupmil CAT702 abort loop):
   -- one byte-time at the programmed baud (JOY_BAUD*8 clk) + 16 clk margin, clamped
   -- to [DELAY1_MIN, DELAY1]. At the ZN BIOS's slow baud (~136) this gives ~1104,
   -- preserving the previous fixed-1200 behaviour; at tondemo's game-driver baud 2
   -- it gives DELAY1_MIN=32, so RX-ready (PULSE1) and the completion IRQ (PULSE2)
   -- arrive with real-hardware ordering, inside the game's ~81-iteration bounded
   -- I_STAT-bit7 poll. Registered to keep the multiply off the FSM timing path.
   signal delay1_dyn : integer range 0 to 2047 := DELAY1;

begin

   rxbyte        <= rxbyte_r;

   -- delay1_dyn register (see declaration comment)
   process (clk)
      variable bt : integer range 0 to 2097167;
   begin
      if rising_edge(clk) then
         bt := to_integer(unsigned(joy_baud)) * 8 + 16;
         if (bt < DELAY1_MIN) then
            delay1_dyn <= DELAY1_MIN;
         elsif (bt > DELAY1) then
            delay1_dyn <= DELAY1;
         else
            delay1_dyn <= bt;
         end if;
      end if;
   end process;

   action_next   <= '1' when (state = PULSE1 or state = PULSE2) else '0';
   -- ZNMCU sessions additionally hold receive_valid/ack high for the whole
   -- transfer (see znmcu_session comment): joypad.vhd samples these as
   -- combinational levels at its OWN actionNext moment, which for port-1
   -- (non-SNAC) transfers arrives long before this FSM's PULSE1. Harmless for
   -- the SNAC (port-2) route, which only samples at our action_next pulses.
   receive_valid <= '1' when (state = PULSE1 or znmcu_session = '1') else '0';
   ack           <= '1' when (state = PULSE1 or znmcu_session = '1') else '0';

   -- build #124 outputs: identify TX byte of first spurious KN02 event (event 51)
   -- B123 confirmed byte 50 = 0x11 (exchange 8 byte-perfect). 8 spurious events 51-58 follow.
   -- If TX of event 51 = 0x10 or 0x4A or 0x88 or 0x0F → matches KN01 BIOS init pattern,
   -- confirming the 8 extras are KN01 transfers misclassified as KN02.
   dbg_first_kn01_rx <= byte_50_kn02_rx_r;         -- RED bar = TX byte of event 51 (first spurious)
   dbg_first_kn02_rx <= last_kn02_rx_r;            -- GREEN bar = LAST KN02 RX byte (= 0xF5 per B122)
   dbg_kn02_ever     <= kn02_ever_r;
   -- build #157: first chip-A exchange byte0/byte3 capture (BR2 et01 expected: byte0=0xFF, byte3=0x0A)
   dbg_b157_byte0    <= b157_byte0_r;
   dbg_b157_byte3    <= b157_byte3_r;
   dbg_b157_anchor   <= b157_anchor_r;
   -- PROPOSED FIX: ZNMCU unsolicited DSR strobe (see decls / entity port)
   znmcu_irq         <= znmcu_irq_r;

   process(clk)
      variable rx_a  : std_logic_vector(7 downto 0);
      variable rx_b  : std_logic_vector(7 downto 0);
      variable st_a  : std_logic_vector(7 downto 0);
      variable st_b  : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk) then

         -- PROPOSED FIX: default the ZNMCU DSR strobe low; asserted for 1 cycle below.
         znmcu_irq_r <= '0';

         if frame_tick = '1' then
            znmcu_frame <= znmcu_frame + 1;
         end if;

         if reset = '1' then
            state         <= IDLE;
            cat_state_a   <= x"FC";
            cat_state_b   <= x"FC";
            prev_sec      <= "011";  -- both chips deselected (active-low: bits 1,0 = '1')
            prev_chip_sel <= '0';
            znmcu_byte    <= (others => '0');
            znmcu_frame   <= (others => '0');
            znmcu_session <= '0';
            rxbyte_r      <= (others => '1');
            -- PROPOSED FIX: clear ZNMCU DSR timer/counter
            znmcu_dsr_timer <= 0;
            znmcu_dsr_count <= (others => '0');

         else

            -- PROPOSED FIX: ZNMCU DSR pulse timer. Counts down to a 1-cycle strobe.
            if znmcu_dsr_timer > 0 then
               znmcu_dsr_timer <= znmcu_dsr_timer - 1;
               if znmcu_dsr_timer = 1 then
                  znmcu_irq_r <= '1';                    -- fire DSR pulse (I_STAT bit7)
                  if znmcu_dsr_count /= "11" then
                     znmcu_dsr_count <= znmcu_dsr_count + 1;
                  end if;
               end if;
            end if;

            -- SIO session start: reset FSM and ZNMCU byte counter.
            -- chip_sel tracks JOY_CTRL(1); it rises at the start of every SIO session
            -- and falls when the BIOS deasserts (between exchanges).  Do NOT reset
            -- CAT702 state here — that is controlled per-chip by sec_select below.
            prev_chip_sel <= chip_sel;
            if prev_chip_sel = '0' and chip_sel = '1' then
               znmcu_byte    <= (others => '0');
               znmcu_session <= '0';
               state         <= IDLE;
            end if;

            -- Per-chip CAT702 reset: mirrors MAME cat702_device::write_select(0).
            -- The chip resets to 0xFC only when its own active-low select bit transitions
            -- from deselected (1) to selected (0) — i.e. the ZN BIOS writes 0x1FA10300
            -- with that chip's bit going low.  Resetting both chips on any sec_select
            -- change is wrong: it corrupts KN01 state during multi-exchange sequences
            -- (e.g. check2 does 3 KN01 exchanges then 1 KN02 exchange).
            prev_sec <= sec_select;
            if prev_sec(0) = '1' and sec_select(0) = '0' then  -- KN01 newly selected
               cat_state_a <= x"FC";
               -- build #157: reset per-exchange byte counter on each fresh chip-A select
               b157_cycle_byte <= (others => '0');
            end if;
            if prev_sec(1) = '1' and sec_select(1) = '0' then  -- KN02 newly selected
               cat_state_b <= x"FC";
            end if;
            -- ZNMCU newly selected: mirrors MAME znmcu_device::select(0), which
            -- resets the bit/byte counters on the select-active edge (znsecsel
            -- write where bits 7,3,2 all become set, e.g. 0x8C). The Taito FX-1
            -- BIOS arms the MCU this way ~30us before clocking the first byte.
            if prev_sec /= "111" and sec_select = "111" then
               znmcu_byte <= (others => '0');
               -- PROPOSED FIX: arm the first (pre-byte0) DSR pulse and reset the
               -- per-session pulse counter. Mirrors MAME znmcu.select(0) arming the
               -- 50us DSR timer. The next pulse (pre-byte1) is armed at PULSE2 below.
               znmcu_dsr_timer <= ZNMCU_DSR_DELAY;
               znmcu_dsr_count <= (others => '0');
            end if;

            case state is

               when IDLE =>
                  if beginTransfer = '1' then
                     -- txbyte (transmitValueSnac) is NOT yet stable here: joypad loads
                     -- transmitValue one cycle after beginTransfer (via beginTransferdelayed).
                     -- Defer response computation to the end of WAIT1 where txbyte is valid.
                     -- Baud-scaled: was fixed DELAY1=1200; see delay1_dyn declaration (task #285)
                     timer <= delay1_dyn - 1;
                     state <= WAIT1;
                     -- build #143: latch sec_select at session start. BIOS often writes
                     -- the NEXT exchange's sec_select before the CURRENT one's response
                     -- is computed (~1300 cycles later in WAIT1). Without latching, the
                     -- classification at WAIT1 end uses the new value → misclassification.
                     sec_select_latched <= sec_select;
                     -- ZNMCU mode (MAME src/mame/sony/znmcu.cpp): the response never
                     -- depends on the TX byte, so unlike CAT702 it can (and must) be
                     -- loaded immediately: port-1 transfers are consumed by joypad.vhd's
                     -- internal baud engine within ~JOY_BAUD*8 cycles of beginTransfer,
                     -- long before the WAIT1 delay elapses.
                     --   byte0 = (databytes<<4)|(dsw&0xF) = 0x10|dsw[3:0]  (standard
                     --   mode, databytes=1 — znsecsel bits 4/5 not wired, see header)
                     --   byte1..n = 0x00 (MAME m_send[] is zero-filled; bytes beyond
                     --   databytes shift out 0 bits, NOT 0xFF)
                     if sec_select = "111" then
                        if znmcu_byte = "00" then
                           rxbyte_r <= "0001" & dsw(3 downto 0);
                        else
                           rxbyte_r <= x"00";
                        end if;
                        if znmcu_byte /= "11" then
                           znmcu_byte <= znmcu_byte + 1;
                        end if;
                        znmcu_session <= '1';
                     end if;
                  end if;

               when WAIT1 =>
                  if timer > 0 then
                     timer <= timer - 1;
                  else
                     -- txbyte is stable (many cycles after beginTransfer).
                     -- Compute response now so rxbyte_r is valid when PULSE1 fires next cycle.
                     -- build #143: use sec_select_latched (captured at session start) so a
                     -- BIOS write to sec_select during WAIT1 doesn't misclassify this byte.
                     if sec_select_latched = "111" then
                        -- ZNMCU mode: sec_select="111" (0x8C, all bits set) activates ZNMCU
                        -- per MAME znmcu.select((data & 0x8C) == 0x8C). The response byte was
                        -- already loaded into rxbyte_r at beginTransfer (IDLE state) because
                        -- it does not depend on txbyte — nothing more to compute here.
                        null;
                     else
                        -- CAT702 mode:
                        --   sec_select_latched(0)='0' → mg01/KN01 active (data[2]=0, active-low)
                        --   sec_select_latched(1)='0' → mg05/KN02 active (data[3]=0, active-low)
                        -- Tecmo BIOS writes 0x00 → both bits 0 → BOTH chips active simultaneously.
                        -- Real hardware: open-drain TXD lines ANDed on the bus.
                        cat702_byte(cat702_key,   txbyte, cat_state_a, rx_a, st_a);
                        cat702_byte(cat702_key_b, txbyte, cat_state_b, rx_b, st_b);
                        -- build #118 fix: only commit state for actually-selected chips.
                        -- Previously the else branch handled both "KN01 only" AND "both deselected"
                        -- and incorrectly updated cat_state_a in the deselected case.
                        if sec_select_latched(0) = '0' and sec_select_latched(1) = '0' then
                           -- Both chips selected (e.g. 0x00): wired-AND of both TXD outputs
                           rxbyte_r    <= rx_a and rx_b;
                           cat_state_a <= st_a;
                           cat_state_b <= st_b;
                        elsif sec_select_latched(0) = '0' and sec_select_latched(1) = '1' then
                           -- mg01/KN01 only (e.g. 0x88)
                           rxbyte_r    <= rx_a;
                           cat_state_a <= st_a;
                           -- build #119: latch first KN01 RX byte
                           if kn01_captured_r = '0' then
                              first_kn01_rx_r <= rx_a;
                              kn01_captured_r <= '1';
                           end if;
                           -- build #157: capture bytes 0 and 3 of the FIRST chip-A exchange.
                           -- b157_cycle_byte was reset on the fresh chip-A select edge above.
                           if b157_anchor_r = '0' then
                              if b157_cycle_byte = "0000" then
                                 b157_byte0_r <= rx_a;
                              elsif b157_cycle_byte = "0011" then  -- 4th byte (index 3)
                                 b157_byte3_r <= rx_a;
                                 b157_anchor_r <= '1';  -- lock latches after byte 3 captured
                              end if;
                           end if;
                           if b157_cycle_byte /= "1111" then  -- saturate at 15
                              b157_cycle_byte <= b157_cycle_byte + 1;
                           end if;
                        elsif sec_select_latched(0) = '1' and sec_select_latched(1) = '0' then
                           -- mg05/KN02 only (e.g. 0x84)
                           rxbyte_r    <= rx_b;
                           cat_state_b <= st_b;
                           -- build #124: capture TX byte during spurious KN02 event (byte 51, first spurious)
                           --             AND latest TX byte being processed as KN02
                           kn02_ever_r <= '1';
                           last_kn02_rx_r <= rx_b;
                           if kn02_count_r = x"32" then  -- 51st event (first spurious after MAME's 50)
                              byte_50_kn02_rx_r <= txbyte;  -- repurpose: TX byte of spurious event 51
                           end if;
                           if kn02_count_r /= x"FF" then
                              kn02_count_r <= kn02_count_r + 1;
                           end if;
                        else
                           -- Both chips deselected (e.g. 0x0C): no chip drives bus → 0xFF (open-drain default)
                           -- DO NOT update either cat_state (real chips don't process clocks when deselected)
                           rxbyte_r    <= x"FF";
                        end if;
                     end if;
                     state <= PULSE1;
                  end if;

               when PULSE1 =>
                  -- action_next + receive_valid + ack are driven combinatorially
                  timer <= DELAY2 - 1;
                  state <= WAIT2;

               when WAIT2 =>
                  if timer > 0 then
                     timer <= timer - 1;
                  else
                     state <= PULSE2;
                  end if;

               when PULSE2 =>
                  -- action_next driven combinatorially for 1 cycle
                  znmcu_session <= '0';
                  state <= IDLE;
                  -- PROPOSED FIX: after a ZNMCU byte completes, re-arm the DSR pulse
                  -- for the next byte while databytes (=1) is not exhausted. MAME emits
                  -- DSR before byte0 (armed on select) and before byte1 (armed here after
                  -- byte0). znmcu_dsr_count=1 means the pre-byte0 pulse has fired and the
                  -- byte just completed was byte0 → arm the pre-byte1 pulse exactly once.
                  if sec_select_latched = "111" and znmcu_dsr_count = "01" then
                     znmcu_dsr_timer <= ZNMCU_DSR_DELAY;
                  end if;

            end case;

         end if;
      end if;
   end process;

end architecture;
