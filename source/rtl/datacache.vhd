library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use ieee.math_real.all;  

library mem;

entity datacache is
   generic
   (
      SIZE                     : integer;
      SIZEBASEBITS             : integer;
      BITWIDTH                 : integer
   );
   port 
   (
      clk1x             : in  std_logic;
      clk2x             : in  std_logic;
      reset             : in  std_logic;
      halfrate          : in  std_logic;
                        
      read_enable       : in  std_logic;
      read_addr         : in  std_logic_vector(SIZEBASEBITS-1 downto 0);
      read_hit          : out std_logic := '0';
      read_data         : out std_logic_vector(BITWIDTH -1 downto 0) := (others => '0');
      
      write_enable      : in  std_logic;
      write_clear       : in  std_logic;
      write_addr        : in  std_logic_vector(SIZEBASEBITS-1 downto 0);
      write_data        : in  std_logic_vector(BITWIDTH -1 downto 0) := (others => '0')
   );
end entity;

architecture arch of datacache is
  
   constant SIZEBITS     : integer := integer(ceil(log2(real(SIZE))));
   constant ADDRSAVEBITS : integer := SIZEBASEBITS - SIZEBITS;
   
   type tState is
   (
      IDLE,
      CLEARCACHE
   );
   signal state : tstate := IDLE;
   
   -- memory
   signal memory_addr_a      : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal memory_addr_b      : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal memory_datain      : std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0');
   signal memory_dataout     : std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0');
   signal memory_we          : std_logic := '0';
                
   signal cache_hit          : std_logic;
   signal cache_half         : std_logic := '0';
                
   -- addr save --  uppermost bit is invalid bit        
   signal addrsave_addr_a    : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal addrsave_addr_b    : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal addrsave_datain    : std_logic_vector(ADDRSAVEBITS downto 0) := (others => '0');
   signal addrsave_dataout   : std_logic_vector(ADDRSAVEBITS downto 0) := (others => '0');
   signal addrsave_we        : std_logic := '0';
   signal upperbits          : std_logic_vector(SIZEBASEBITS - SIZEBITS - 1 downto 0) := (others => '0');
   
   -- clear cache
   signal clear_counter      : unsigned(SIZEBITS - 1 downto 0);
   
   -- debug
   signal cache_requests     : integer := 0;
   signal cache_hits         : integer := 0;

   -- B25: write-bypass register.
   -- The two dprams below have port-A (read, clk2x) and port-B (write, clk1x)
   -- racing each other on cross-port write-then-read of the same address.
   -- Altera M9K block RAM default behavior on that race is "DON'T_CARE" — the
   -- read can return OLD data even after the write committed at the cycle
   -- boundary. Concretely: CPU does sw to X then immediately lw from X; cache
   -- returns the pre-write value, CPU operates on stale data, control flow
   -- diverges, game hangs. Bypass captures the last write here and serves it
   -- directly when a read comes for the same address; bypass also covers the
   -- companion addrsave dpram race because cache_hit is overridden when bypass
   -- fires. Sim's shared-variable dpram does not reproduce this race so the
   -- bug was invisible until silicon.
   -- B37: multi-entry (shift-register) write-forward bypass. The single-entry B25/B27
   -- bypass only covered the LAST write; the bisect (B36) showed CPU full-word write-UPDATE
   -- still corrupts because reads of an address written a FEW writes ago race the dpram's
   -- multi-cycle cross-port write->read-port commit (bp had already moved on). Hold the last
   -- BPN writes; on a read, the NEWEST matching entry decides: non-clear -> forward its data;
   -- clear -> force a MISS (refill from SDRAM); no match -> use the dpram cache_hit.
   constant BPN              : integer := 4;
   type bp_addr_t is array(0 to BPN-1) of std_logic_vector(SIZEBASEBITS-1 downto 0);
   type bp_data_t is array(0 to BPN-1) of std_logic_vector(BITWIDTH-1 downto 0);
   signal bp_valid           : std_logic_vector(BPN-1 downto 0) := (others => '0');  -- entry 0 = newest
   signal bp_addr            : bp_addr_t := (others => (others => '0'));
   signal bp_data            : bp_data_t := (others => (others => '0'));
   signal bp_clear           : std_logic_vector(BPN-1 downto 0) := (others => '0');
   signal bp_match           : std_logic_vector(BPN-1 downto 0);  -- per-entry addr match
   signal bp_anymatch        : std_logic;
   signal bp_fhit            : std_logic;                          -- newest matching entry is a non-clear write
   signal bp_fdata           : std_logic_vector(BITWIDTH-1 downto 0);

begin

   iRamMemory: entity work.dpram
   generic map ( addr_width => SIZEBITS, data_width => BITWIDTH, rdw_mixed => "OLD_DATA")  -- B31
   port map
   (
      clock_a     => clk2x,
      address_a   => memory_addr_a,
      data_a      => (memory_dataout'range => '0'),
      wren_a      => '0',
      q_a         => memory_dataout,
      
      clock_b     => clk1x,
      address_b   => memory_addr_b,
      data_b      => memory_datain,
      wren_b      => memory_we,
      q_b         => open
   );
   
   iRamaddrsave: entity work.dpram
   generic map ( addr_width => SIZEBITS, data_width => ADDRSAVEBITS + 1, rdw_mixed => "OLD_DATA")  -- B31
   port map
   (
      clock_a     => clk2x,
      address_a   => addrsave_addr_a,
      data_a      => (addrsave_dataout'range => '0'),
      wren_a      => '0',
      q_a         => addrsave_dataout,
      
      clock_b     => clk1x,
      address_b   => addrsave_addr_b,
      data_b      => addrsave_datain,
      wren_b      => addrsave_we,
      q_b         => open
   );
   
   -- reading
   memory_addr_a    <= read_addr(SIZEBITS - 1 downto 0);
   addrsave_addr_a  <= read_addr(SIZEBITS - 1 downto 0);
   
   upperbits       <= read_addr(SIZEBASEBITS-1 downto SIZEBITS);
   
   cache_hit        <= '1' when (addrsave_dataout = '0' & upperbits) else '0';
   
   -- B37: per-entry address match against the BPN most-recent writes (entry 0 = newest).
   gen_bp_match: for i in 0 to BPN-1 generate
      bp_match(i) <= '1' when (bp_valid(i) = '1' and bp_addr(i) = read_addr) else '0';
   end generate;
   bp_anymatch <= '1' when (bp_match /= std_logic_vector(to_unsigned(0, BPN))) else '0';

   -- The NEWEST matching entry is authoritative (priority entry 0 > 1 > 2 > 3):
   -- non-clear -> forward its data (bp_fhit); clear -> not a forward (forces MISS below).
   bp_fhit  <= not bp_clear(0) when bp_match(0) = '1' else
               not bp_clear(1) when bp_match(1) = '1' else
               not bp_clear(2) when bp_match(2) = '1' else
               not bp_clear(3) when bp_match(3) = '1' else '0';
   bp_fdata <= bp_data(0) when bp_match(0) = '1' else
               bp_data(1) when bp_match(1) = '1' else
               bp_data(2) when bp_match(2) = '1' else
               bp_data(3);

   -- Forward newest non-clear write; if newest match is a clear (or any match with no
   -- non-clear newest) force a MISS so the CPU refills from SDRAM; else use dpram cache_hit.
   read_hit         <= bp_fhit or (cache_hit and cache_half and not bp_anymatch);
   read_data        <= bp_fdata when bp_fhit = '1' else memory_dataout;
   
   -- writing
   addrsave_addr_b <= std_logic_vector(clear_counter) when (state = CLEARCACHE) else write_addr(SIZEBITS - 1 downto 0);
   addrsave_datain <= (others => '1')                 when (state = CLEARCACHE) else write_clear & write_addr(SIZEBASEBITS-1 downto SIZEBITS);
   addrsave_we     <= '1'                             when (state = CLEARCACHE) else write_enable;
   
   memory_addr_b   <= write_addr(SIZEBITS - 1 downto 0);
   memory_datain   <= write_data;
   memory_we       <= write_enable;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then

         if (halfrate = '1') then
            cache_half <= not cache_half;
         elsif (halfrate = '0') then
            cache_half <= '1';
         end if;

         if (reset = '1') then
            state          <= CLEARCACHE;
            clear_counter  <= (others => '0');
            cache_requests <= 0;
            cache_hits     <= 0;
            bp_valid       <= (others => '0');
         else

            -- B37: shift-register bypass capture (entry 0 = newest). Only fire in IDLE —
            -- during CLEARCACHE write_enable is ignored (addrsave_we overridden by the clear
            -- counter); capturing then would seed stale entries.
            if (state = IDLE and write_enable = '1') then
               for i in BPN-1 downto 1 loop
                  bp_valid(i) <= bp_valid(i-1);
                  bp_addr(i)  <= bp_addr(i-1);
                  bp_data(i)  <= bp_data(i-1);
                  bp_clear(i) <= bp_clear(i-1);
               end loop;
               bp_valid(0) <= '1';
               bp_addr(0)  <= write_addr;
               bp_data(0)  <= write_data;
               bp_clear(0) <= write_clear;
            end if;

            case(state) is

               when IDLE =>
                  if (read_enable = '1') then
                     cache_requests  <= cache_requests + 1;
                     if (read_hit = '1') then
                        cache_hits <= cache_hits + 1;
                     end if;
                  end if;

               when CLEARCACHE =>
                  if (clear_counter < SIZE - 1) then
                     clear_counter <= clear_counter + 1;
                  else
                     state          <= IDLE;
                  end if;

            end case;

         end if;
         
         if (cache_requests = 0 and cache_hits = 1) then
            cache_hits <= 0;
         end if;

      end if;
   end process;

   
end architecture;




























