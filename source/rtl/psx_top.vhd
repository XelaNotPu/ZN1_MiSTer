library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pexport.all;
use work.pJoypad.all;

entity psx_top is
   generic
   (
      is_simu               : std_logic := '0'
   );
   port 
   (
      clk1x                 : in  std_logic;  
      clk2x                 : in  std_logic;   
      clk3x                 : in  std_logic;   
      clkvid                : in  std_logic;   
      reset                 : in  std_logic; 
      isPaused              : out std_logic;
      -- commands 
      pause                 : in  std_logic;
      hps_busy              : in  std_logic;
      loadExe               : in  std_logic;
      exe_initial_pc        : in  unsigned(31 downto 0);
      exe_initial_gp        : in  unsigned(31 downto 0);
      exe_load_address      : in  unsigned(31 downto 0);
      exe_file_size         : in  unsigned(31 downto 0);
      exe_stackpointer      : in  unsigned(31 downto 0);
      fastboot              : in  std_logic;
      ram8mb                : in  std_logic;
      TURBO_MEM             : in  std_logic;
      TURBO_COMP            : in  std_logic;
      TURBO_CACHE           : in  std_logic;
      ROM_PREFETCH          : in  std_logic;
      FAST_BIOS             : in  std_logic;
      FAST_MATH             : in  std_logic;
      CPU_LATE_READ_SKIP    : in  std_logic;
      TURBO_CACHE50         : in  std_logic;
      REPRODUCIBLEGPUTIMING : in  std_logic;
      INSTANTSEEK           : in  std_logic;
      FORCECDSPEED          : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED        : in  std_logic;
      IGNORECDDMATIMING     : in  std_logic;
      ditherOff             : in  std_logic;
      interlaced480pHack    : in  std_logic;
      showGunCrosshairs     : in  std_logic;
      enableNeGconRumble    : in  std_logic;
      fpscountOn            : in  std_logic;
      cdslowOn              : in  std_logic;
      testSeek              : in  std_logic;
      pauseOnCDSlow         : in  std_logic;
      errorOn               : in  std_logic;
      LBAOn                 : in  std_logic;
      PATCHSERIAL           : in  std_logic;
      noTexture             : in  std_logic;
      textureFilter         : in  std_logic_vector(1 downto 0);
      textureFilterStrength : in  std_logic_vector(1 downto 0);
      textureFilter2DOff    : in  std_logic;
      dither24              : in  std_logic;
      render24              : in  std_logic;
      drawSlow              : in  std_logic;
      syncVideoOut          : in  std_logic;
      syncInterlace         : in  std_logic;
      rotate180             : in  std_logic;
      fixedVBlank           : in  std_logic;
      vCrop                 : in  std_logic_vector(1 downto 0);
      hCrop                 : in  std_logic;
      SPUon                 : in  std_logic;
      SPUIRQTrigger         : in  std_logic;
      SPUSDRAM              : in  std_logic;
      REVERBOFF             : in  std_logic;
      REPRODUCIBLESPUDMA    : in  std_logic;
      WIDESCREEN            : in  std_logic_vector(1 downto 0);
	  oldGPU                : in  std_logic;
      -- RAM/BIOS interface  
      biosregion            : in  std_logic_vector(1 downto 0);      
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead32        : in  std_logic_vector(31 downto 0);
      ram_Adr               : out std_logic_vector(26 downto 0);
      ram_cntDMA            : out std_logic_vector(1 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_dma               : out std_logic;
      ram_cache             : out std_logic;
      ram_done              : in  std_logic;
      ram_dmafifo_adr       : out std_logic_vector(22 downto 0);
      ram_dmafifo_data      : out std_logic_vector(31 downto 0);
      ram_dmafifo_empty     : out std_logic;
      ram_dmafifo_read      : in  std_logic;
      cache_wr              : in  std_logic_vector(3 downto 0);
      cache_data            : in  std_logic_vector(31 downto 0);
      cache_addr            : in  std_logic_vector(7 downto 0);
      dma_wr                : in  std_logic;
      dma_reqprocessed      : in  std_logic;
      dma_data              : in  std_logic_vector(31 downto 0);
      -- vram/savestate interface
      ddr3_BUSY             : in  std_logic;                    
      ddr3_DOUT             : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY       : in  std_logic;
      ddr3_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0');
      ddr3_ADDR             : out std_logic_vector(27 downto 0) := (others => '0');
      ddr3_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE               : out std_logic_vector(7 downto 0) := (others => '0');
      ddr3_WE               : out std_logic := '0';
      ddr3_RD               : out std_logic := '0';
      -- cd
      region                : in  std_logic_vector(1 downto 0);
      region_out            : out std_logic_vector(1 downto 0);
      hasCD                 : in  std_logic;
      fastCD                : in  std_logic;
      LIDopen               : in  std_logic;
      trackinfo_data        : in  std_logic_vector(31 downto 0);
      trackinfo_addr        : in  std_logic_vector(8 downto 0);
      trackinfo_write       : in  std_logic;
      resetFromCD           : out std_logic;
      cd_hps_req            : out std_logic := '0';
      cd_hps_lba            : out std_logic_vector(31 downto 0);
      cd_hps_lba_sim        : out std_logic_vector(31 downto 0);
      cd_hps_ack            : in  std_logic;
      cd_hps_write          : in  std_logic;
      cd_hps_data           : in  std_logic_vector(15 downto 0);
      -- spuram
      spuram_dataWrite      : out std_logic_vector(31 downto 0);
      spuram_Adr            : out std_logic_vector(18 downto 0);
      spuram_be             : out std_logic_vector(3 downto 0);
      spuram_rnw            : out std_logic;
      spuram_ena            : out std_logic;
      spuram_dataRead       : in  std_logic_vector(31 downto 0);
      spuram_done           : in  std_logic;
      -- memcard
      memcard_changed       : out std_logic;
      saving_memcard        : out std_logic;
      memcard1_load         : in  std_logic;
      memcard2_load         : in  std_logic;
      memcard_save          : in  std_logic;
      memcard1_mounted      : in  std_logic;
      memcard1_available    : in  std_logic;
      memcard1_rd           : out std_logic := '0';
      memcard1_wr           : out std_logic := '0';
      memcard1_lba          : out std_logic_vector(6 downto 0);
      memcard1_ack          : in  std_logic;
      memcard1_write        : in  std_logic;
      memcard1_addr         : in  std_logic_vector(8 downto 0);
      memcard1_dataIn       : in  std_logic_vector(15 downto 0);
      memcard1_dataOut      : out std_logic_vector(15 downto 0);
      memcard2_mounted      : in  std_logic;               
      memcard2_available    : in  std_logic;               
      memcard2_rd           : out std_logic := '0';
      memcard2_wr           : out std_logic := '0';
      memcard2_lba          : out std_logic_vector(6 downto 0);
      memcard2_ack          : in  std_logic;
      memcard2_write        : in  std_logic;
      memcard2_addr         : in  std_logic_vector(8 downto 0);
      memcard2_dataIn       : in  std_logic_vector(15 downto 0);
      memcard2_dataOut      : out std_logic_vector(15 downto 0);
      -- video
      videoout_on           : in  std_logic;
      isPal                 : in  std_logic;
      pal60                 : in  std_logic;
      hsync                 : out std_logic;
      vsync                 : out std_logic;
      hblank                : out std_logic;
      vblank                : out std_logic;
      DisplayWidth          : out unsigned(10 downto 0);
      DisplayHeight         : out unsigned( 9 downto 0);
      DisplayOffsetX        : out unsigned( 9 downto 0);
      DisplayOffsetY        : out unsigned( 8 downto 0);
      video_ce              : out std_logic;
      video_interlace       : out std_logic;
      video_r               : out std_logic_vector(7 downto 0);
      video_g               : out std_logic_vector(7 downto 0);
      video_b               : out std_logic_vector(7 downto 0);
      video_isPal           : out std_logic;
      video_fbmode          : out std_logic;
      video_fb24            : out std_logic;
      video_hResMode        : out std_logic_vector(2 downto 0);
      video_frameindex      : out std_logic_vector(3 downto 0);

      DSAltSwitchMode       : in  std_logic;
      joypad1               : in  joypad_t;
      joypad2               : in  joypad_t;
      joypad3               : in  joypad_t;
      joypad4               : in  joypad_t;
      multitap              : in  std_logic;
      multitapDigital       : in  std_logic;
      multitapAnalog        : in  std_logic;
      neGconRumble          : in  std_logic;
      joypad1_rumble        : out std_logic_vector(15 downto 0);
      joypad2_rumble        : out std_logic_vector(15 downto 0);
      joypad3_rumble        : out std_logic_vector(15 downto 0);
      joypad4_rumble        : out std_logic_vector(15 downto 0);
      padMode               : out std_logic_vector(1 downto 0);

      MouseEvent            : in  std_logic;
      MouseLeft             : in  std_logic;
      MouseRight            : in  std_logic;
      MouseX                : in  signed(8 downto 0);
      MouseY                : in  signed(8 downto 0);
      --snac
      snacPort1             : in  std_logic;
      snacPort2             : in  std_logic;
      irq10Snac             : in  std_logic;
      actionNextSnac        : in  std_logic;
      receiveValidSnac      : in  std_logic;
      ackSnac               : in  std_logic;
      snacMC                : in  std_logic;
      receiveBufferSnac	    : in  std_logic_vector(7 downto 0);
      transmitValueSnac     : out std_logic_vector(7 downto 0);		
      selectedPort1Snac     : out std_logic;
      selectedPort2Snac     : out std_logic;
      clk9Snac              : out std_logic;
      beginTransferSnac     : out std_logic;

      -- sound                            
      sound_out_left        : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right       : out std_logic_vector(15 downto 0) := (others => '0');
       -- savestates
      increaseSSHeaderCount : in  std_logic;
      save_state            : in  std_logic;
      load_state            : in  std_logic;
      savestate_number      : in  integer range 0 to 3;
      state_loaded          : out std_logic;
      validSStates          : out std_logic_vector(3 downto 0);
      rewind_on             : in  std_logic;
      rewind_active         : in  std_logic;
      -- cheats
      cheat_clear           : in  std_logic;
      cheats_enabled        : in  std_logic;
      cheat_on              : in  std_logic;
      cheat_in              : in  std_logic_vector(127 downto 0);
      cheats_active         : out std_logic := '0';

      Cheats_BusAddr        : buffer std_logic_vector(20 downto 0);
      Cheats_BusRnW         : out    std_logic;
      Cheats_BusByteEnable  : out    std_logic_vector(3 downto 0);
      Cheats_BusWriteData   : out    std_logic_vector(31 downto 0);
      Cheats_Bus_ena        : out    std_logic := '0';
      Cheats_BusReadData    : in     std_logic_vector(31 downto 0);
      Cheats_BusDone        : in     std_logic;

      -- ZN-1 Arcade I/O inputs
      zn_p1_right     : in  std_logic;
      zn_p1_left      : in  std_logic;
      zn_p1_down      : in  std_logic;
      zn_p1_up        : in  std_logic;
      zn_p1_btn       : in  std_logic_vector(5 downto 0);
      zn_p1_start     : in  std_logic;
      zn_p1_coin      : in  std_logic;
      zn_p2_right     : in  std_logic;
      zn_p2_left      : in  std_logic;
      zn_p2_down      : in  std_logic;
      zn_p2_up        : in  std_logic;
      zn_p2_btn       : in  std_logic_vector(5 downto 0);
      zn_p2_start     : in  std_logic;
      zn_p2_coin      : in  std_logic;
      zn_service      : in  std_logic;
      zn_test_mode    : in  std_logic;
      zn_dsw          : in  std_logic_vector(7 downto 0);
      zn_cat702_key   : in  std_logic_vector(63 downto 0);
      zn_cat702_key_b : in  std_logic_vector(63 downto 0);
      zn_platform     : in  std_logic_vector(3 downto 0) := "0000";
      -- EEPROM preload (MRA ioctl index 9) -> zn1_io EEPROM BRAM
      zn_ee_dl_wr     : in  std_logic := '0';
      zn_ee_dl_addr   : in  std_logic_vector(8 downto 0) := (others => '0');
      zn_ee_dl_data   : in  std_logic_vector(31 downto 0) := (others => '0');
      zn_ee_dl_be     : in  std_logic_vector(3 downto 0)  := (others => '0');
      -- Debug: {sio_ever_seen, check2_seen, check1_seen, sec_select[1:0]}
      zn_debug_out    : out std_logic_vector(6 downto 0);
      -- build #50: raw 32-bit SDRAM word latched at green anchor (CPU 0x1F644810)
      zn_debug_val    : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #51: computed SDRAM byte address latched at green anchor (expect 0x00E44810)
      zn_debug_addr   : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #52: 8 contiguous bank0 words [0x1F644800,0x1F644820)
      zn_debug_words  : out std_logic_vector(255 downto 0) := (others => '0')
   );
end entity;

architecture arch of psx_top is

   signal reset_in               : std_logic := '0';
   signal reset_intern           : std_logic := '0';
   signal reset_exe              : std_logic;
   
   signal ce                     : std_logic := '0';
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';

   signal clk1xToggle3X          : std_logic := '0';
   signal clk1xToggle3X_1        : std_logic := '0';
   signal clk3xIndex             : std_logic := '0';
   
   signal Pause_Idle             : std_logic;
   signal pausing                : std_logic := '0';
   signal pausingSS              : std_logic := '0';
   signal allowunpause           : std_logic;
   
   signal pauseCD                : std_logic;
   signal Pause_idle_cd          : std_logic;
   
   -- ddr3 arbiter
   type tddr3State is
   (
      ARBITERIDLE,
      WAITGPUPAUSED,
      REQUEST,
      WAITDONE
   );
   signal ddr3state              : tddr3State := ARBITERIDLE;
   
   signal arbiter_active         : std_logic := '0';
   
   signal memDDR3card1_acknext   : std_logic := '0';
   signal memDDR3card2_acknext   : std_logic := '0';
   signal memHPScard1_acknext    : std_logic := '0';
   signal memHPScard2_acknext    : std_logic := '0';
   signal memSPU_acknext         : std_logic := '0';
   
   signal arbiter_BURSTCNT       : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_ADDR           : std_logic_vector(27 downto 0) := (others => '0');                       
   signal arbiter_DIN            : std_logic_vector(63 downto 0) := (others => '0');
   signal arbiter_BE             : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_WE             : std_logic := '0';
   signal arbiter_RD             : std_logic := '0';
   
   signal memDDR3card1_request   : std_logic;
   signal memDDR3card1_ack       : std_logic := '0';
   signal memDDR3card1_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card1_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card1_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_WE        : std_logic := '0';
   signal memDDR3card1_RD        : std_logic := '0';
   
   signal memDDR3card2_request   : std_logic;
   signal memDDR3card2_ack       : std_logic := '0';
   signal memDDR3card2_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card2_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card2_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_WE        : std_logic := '0';
   signal memDDR3card2_RD        : std_logic := '0';
   
   signal memSPU_request         : std_logic;
   signal memSPU_ack             : std_logic := '0';
   signal memSPU_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0');
   signal memSPU_ADDR            : std_logic_vector(19 downto 0) := (others => '0');
   signal memSPU_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal memSPU_BE              : std_logic_vector(7 downto 0) := (others => '0');
   signal memSPU_WE              : std_logic := '0';
   signal memSPU_RD              : std_logic := '0';

   -- Busses
   signal bios_memctrl           : unsigned(13 downto 0);
   
   signal ex1_memctrl            : unsigned(13 downto 0);
   --signal bus_exp1_addr          : unsigned(22 downto 0); 
   --signal bus_exp1_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp1_read          : std_logic;
   --signal bus_exp1_write         : std_logic;
   signal bus_exp1_dataRead      : std_logic_vector(7 downto 0);
   
   signal bus_memc_addr          : unsigned(5 downto 0); 
   signal bus_memc_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_memc_read          : std_logic;
   signal bus_memc_write         : std_logic;
   signal bus_memc_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_pad_addr           : unsigned(3 downto 0); 
   signal bus_pad_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_pad_read           : std_logic;
   signal bus_pad_write          : std_logic;
   signal bus_pad_writeMask      : std_logic_vector(3 downto 0);
   signal bus_pad_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_sio_addr           : unsigned(3 downto 0); 
   signal bus_sio_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_sio_read           : std_logic;
   signal bus_sio_write          : std_logic;
   signal bus_sio_writeMask      : std_logic_vector(3 downto 0);
   signal bus_sio_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_memc2_addr         : unsigned(3 downto 0); 
   signal bus_memc2_dataWrite    : std_logic_vector(31 downto 0);
   signal bus_memc2_read         : std_logic;
   signal bus_memc2_write        : std_logic;
   signal bus_memc2_dataRead     : std_logic_vector(31 downto 0);
   
   signal bus_irq_addr           : unsigned(3 downto 0); 
   signal bus_irq_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_irq_read           : std_logic;
   signal bus_irq_write          : std_logic;
   signal bus_irq_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_dma_addr           : unsigned(6 downto 0); 
   signal bus_dma_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_dma_read           : std_logic;
   signal bus_dma_write          : std_logic;
   signal bus_dma_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_tmr_addr           : unsigned(5 downto 0); 
   signal bus_tmr_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_tmr_read           : std_logic;
   signal bus_tmr_write          : std_logic;
   signal bus_tmr_dataRead       : std_logic_vector(31 downto 0);
   
   signal cd_memctrl             : unsigned(13 downto 0);
   signal bus_cd_addr            : unsigned(3 downto 0); 
   signal bus_cd_dataWrite       : std_logic_vector(7 downto 0);
   signal bus_cd_read            : std_logic;
   signal bus_cd_write           : std_logic;
   signal bus_cd_dataRead        : std_logic_vector(7 downto 0);
   
   signal bus_gpu_addr           : unsigned(3 downto 0); 
   signal bus_gpu_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_gpu_read           : std_logic;
   signal bus_gpu_write          : std_logic;
   signal bus_gpu_dataRead       : std_logic_vector(31 downto 0);
   signal bus_gpu_stall          : std_logic;
   
   signal bus_mdec_addr          : unsigned(3 downto 0); 
   signal bus_mdec_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_mdec_read          : std_logic;
   signal bus_mdec_write         : std_logic;
   signal bus_mdec_dataRead      : std_logic_vector(31 downto 0);
   
   signal spu_memctrl            : unsigned(13 downto 0);
   signal bus_spu_addr           : unsigned(9 downto 0); 
   signal bus_spu_dataWrite      : std_logic_vector(15 downto 0);
   signal bus_spu_read           : std_logic;
   signal bus_spu_write          : std_logic;
   signal bus_spu_dataRead       : std_logic_vector(15 downto 0);
   
   signal ex2_memctrl            : unsigned(13 downto 0);
   signal bus_exp2_addr          : unsigned(12 downto 0); 
   signal bus_exp2_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp2_read          : std_logic;
   signal bus_exp2_write         : std_logic;
   signal bus_exp2_dataRead      : std_logic_vector(7 downto 0);  
   
   signal ex3_memctrl            : unsigned(13 downto 0);
   --signal bus_exp3_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp3_read          : std_logic;
   --signal bus_exp3_write         : std_logic;
   signal bus_exp3_dataRead      : std_logic_vector(15 downto 0);
   
   signal com0_delay             : unsigned(3 downto 0);
   signal com1_delay             : unsigned(3 downto 0);
   signal com2_delay             : unsigned(3 downto 0);
   signal com3_delay             : unsigned(3 downto 0);
   
   signal dma_spu_timing_on      : std_logic;
   signal dma_spu_timing_value   : unsigned(3 downto 0);
   
   -- Memory mux
   signal memMuxIdle             : std_logic;
   
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_isData             : std_logic; 
   signal mem_isCache            : std_logic; 
   signal mem_oldtagvalids       : std_logic_vector(3 downto 0);
   signal mem_addressInstr       : unsigned(31 downto 0); 
   signal mem_addressData        : unsigned(31 downto 0); 
   signal mem_reqsize            : unsigned(1 downto 0); 
   signal mem_writeMask          : std_logic_vector(3 downto 0);
   signal mem_dataWrite          : std_logic_vector(31 downto 0); 
   signal mem_dataRead           : std_logic_vector(31 downto 0); 
   signal mem_done               : std_logic;
   signal mem_fifofull           : std_logic;
   signal mem_tagvalids          : std_logic_vector(3 downto 0);
   
   signal ram_next_cpu           : std_logic;
   
   signal ram_cpu_dataWrite      : std_logic_vector(31 downto 0);
   signal ram_cpu_Adr            : std_logic_vector(26 downto 0);
   signal ram_cpu_be             : std_logic_vector(3 downto 0);
   signal ram_cpu_rnw            : std_logic;
   signal ram_cpu_ena            : std_logic;
   signal ram_cpu_cache          : std_logic;
   signal ram_cpu_done           : std_logic;
   
   -- gpu
   signal vblank_tmr             : std_logic;
   signal hblank_tmr             : std_logic;
   signal dotclock               : std_logic;
   
   signal vram_pause             : std_logic; 
   signal vram_paused            : std_logic; 
   signal vram_BURSTCNT          : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_ADDR              : std_logic_vector(27 downto 0) := (others => '0');                       
   signal vram_DIN               : std_logic_vector(63 downto 0) := (others => '0');
   signal vram_BE                : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_WE                : std_logic := '0';
   signal vram_RD                : std_logic := '0'; 
   
   -- irq
   signal irqRequest             : std_logic;
   signal irq_VBLANK             : std_logic;
   signal gpustat31_sig          : std_logic;  -- build #169: GPUSTAT bit 31 from gpu.vhd
   signal drawingAreaBottom_sig  : std_logic_vector(9 downto 0);   -- build #172
   signal drawingOffsetY_sig     : std_logic_vector(10 downto 0);  -- build #172
   signal b172_drawArea_high_ever  : std_logic := '0';
   signal b172_drawOffset_high_ever: std_logic := '0';
   signal irq_GPU                : std_logic;
   signal irq_CDROM              : std_logic;
   signal irq_DMA                : std_logic;
   signal irq_TIMER0             : std_logic;
   signal irq_TIMER1             : std_logic;
   signal irq_TIMER2             : std_logic;
   signal irq_PAD                : std_logic;
   -- PROPOSED FIX (Tecmo ZNMCU boot-hang): joypad's raw PAD IRQ, before OR-ing in the
   -- ZNMCU unsolicited DSR pulse from zn_sio. See combined assignment near the joypad instance.
   signal irq_PAD_joy            : std_logic;
   signal zn_znmcu_irq           : std_logic;
   signal irq_SIO                : std_logic;
   signal irq_SPU                : std_logic;
   signal irq_LIGHTPEN           : std_logic;
   
   -- dma
   signal cpuPaused              : std_logic := '0';
   signal dmaOn                  : std_logic;
   signal dmaRequest             : std_logic;
   signal dmaStallCPU            : std_logic;
   signal canDMA                 : std_logic;
   signal ignoreDMACDTiming      : std_logic;
   
   signal ram_dma_Adr            : std_logic_vector(22 downto 0);
   signal ram_dma_ena            : std_logic;
   
   signal dma_cache_Adr          : std_logic_vector(22 downto 0);  -- B24: was 20:0 (alias bug)
   signal dma_cache_data         : std_logic_vector(31 downto 0);
   signal dma_cache_write        : std_logic;
   
   signal gpu_dmaRequest         : std_logic;
   signal DMA_GPU_waiting        : std_logic;
   signal DMA_GPU_writeEna       : std_logic;
   signal DMA_GPU_readEna        : std_logic;
   signal DMA_GPU_write          : std_logic_vector(31 downto 0);
   signal DMA_GPU_read           : std_logic_vector(31 downto 0);
   
   signal mdec_dmaWriteRequest   : std_logic;
   signal mdec_dmaReadRequest    : std_logic;
   signal DMA_MDEC_writeEna      : std_logic := '0';
   signal DMA_MDEC_readEna       : std_logic := '0';
   signal DMA_MDEC_write         : std_logic_vector(31 downto 0);
   signal DMA_MDEC_read          : std_logic_vector(31 downto 0);
   
   signal DMA_CD_readEna         : std_logic;
   signal DMA_CD_read            : std_logic_vector(7 downto 0);
   
   signal spu_dmaRequest         : std_logic;
   signal DMA_SPU_writeEna       : std_logic := '0';
   signal DMA_SPU_readEna        : std_logic := '0';
   signal DMA_SPU_write          : std_logic_vector(15 downto 0);
   signal DMA_SPU_read           : std_logic_vector(15 downto 0);
   
   -- SPU
   signal spu_tick               : std_logic;
   signal cd_left                : signed(15 downto 0);
   signal cd_right               : signed(15 downto 0);
   
   -- cpu
   signal ce_intern              : std_logic := '0';
   signal stallNext              : std_logic;
   
   -- GTE
   signal gte_busy               : std_logic;
   signal cpu_hilo_stall         : std_logic;
   signal cpu_pipeline_stall     : std_logic;
   signal cpu_mem_inflight       : std_logic;
   signal gte_readEna            : std_logic;
   signal gte_readAddr           : unsigned(5 downto 0);
   signal gte_readData           : unsigned(31 downto 0);
   signal gte_writeAddr          : unsigned(5 downto 0);
   signal gte_writeData          : unsigned(31 downto 0);
   signal gte_writeEna           : std_logic; 
   signal gte_cmdData            : unsigned(31 downto 0);
   signal gte_cmdEna             : std_logic; 

   -- overlay + error codes
   signal cdSlow                 : std_logic;
   signal cdslowEna              : std_logic;
   signal errorEna               : std_logic;
   signal errorCode              : unsigned(3 downto 0) := (others => '0');
   signal LBAdisplay             : unsigned(19 downto 0);
   
   signal errorCD                : std_logic;
   signal errorCPU               : std_logic;
   signal errorCPU2              : std_logic;
   signal errorLINE              : std_logic;
   signal errorRECT              : std_logic;
   signal errorPOLY              : std_logic;
   signal errorGPU               : std_logic;
   signal errorMASK              : std_logic;
   signal errorCHOP              : std_logic;
   signal errorGPUFIFO           : std_logic;
   signal errorSPUTIME           : std_logic;
   signal errorDMACPU            : std_logic;
   signal errorDMAFIFO           : std_logic;
   signal errorTimer             : std_logic;
   signal errorBuswidth          : std_logic;
   
   signal debugmodeOn            : std_logic;

   signal Gun1CrosshairOn        : std_logic;
   signal Gun2CrosshairOn        : std_logic;
   signal Gun1X                  : unsigned(7 downto 0);
   signal Gun1Y                  : unsigned(7 downto 0);
   signal Gun2X                  : unsigned(7 downto 0);
   signal Gun2Y                  : unsigned(7 downto 0);
   signal Gun1Y_scanlines        : unsigned(8 downto 0);
   signal Gun2Y_scanlines        : unsigned(8 downto 0);
   signal Gun1AimOffscreen       : std_logic;
   signal Gun2AimOffscreen       : std_logic;   
   signal Gun1offscreen          : std_logic;
   signal Gun2offscreen          : std_logic;
   signal Gun1IRQ10              : std_logic;
   signal Gun2IRQ10              : std_logic;
   signal JustifierIrqEnable     : std_logic_vector(1 downto 0);

   -- memcard
   signal memcard1_pause         : std_logic;
   signal memcard2_pause         : std_logic;
   
   signal MemCard_changePending1 : std_logic;
   signal MemCard_changePending2 : std_logic;   
   
   signal MemCard_saving_memcard1: std_logic;
   signal MemCard_saving_memcard2: std_logic;
   
   signal memHPScard1_request    : std_logic;
   signal memHPScard1_ack        : std_logic := '0';
   signal memHPScard1_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard1_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard1_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_WE         : std_logic := '0';
   signal memHPScard1_RD         : std_logic := '0';
                                 
   signal memHPScard2_request    : std_logic;
   signal memHPScard2_ack        : std_logic := '0';
   signal memHPScard2_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard2_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard2_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_WE         : std_logic := '0';
   signal memHPScard2_RD         : std_logic := '0';

   -- ZN-1 I/O bus signals (connects memorymux to zn1_io)
   signal bus_znio_addr          : unsigned(20 downto 0);
   signal bus_znio_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_znio_read          : std_logic;
   signal bus_znio_write         : std_logic;
   signal bus_znio_writeMask     : std_logic_vector(3 downto 0);
   signal bus_znio_dataRead      : std_logic_vector(31 downto 0);
   signal zn_sec_select          : std_logic_vector(2 downto 0);  -- {data[7],data[3],data[2]}
   signal zn_coin_out            : std_logic_vector(7 downto 0);

   -- ZN SNAC intermediaries (joypad outputs → zn_sio inputs, zn_sio outputs → joypad inputs)
   signal zn_beginTransfer       : std_logic;
   signal zn_txbyte              : std_logic_vector(7 downto 0);
   signal zn_action_next         : std_logic;
   signal zn_receive_valid       : std_logic;
   signal zn_ack                 : std_logic;
   signal zn_rxbyte              : std_logic_vector(7 downto 0);
   signal zn_sel_p2              : std_logic := '0';  -- selectedPort2Snac; also drives chip_sel
   signal zn_joy_baud            : std_logic_vector(15 downto 0);  -- task #285: JOY_BAUD → zn_sio
   signal ram_accessed_seen      : std_logic := '0';  -- latches on any CPU RAM request (read or write)
   signal ram_done_seen          : std_logic := '0';  -- latches when SDRAM completes a CPU transaction
   signal nonzero_read_seen      : std_logic := '0';  -- latches when SDRAM returns non-zero data (BIOS loaded)
   signal gpu_accessed_seen      : std_logic := '0';  -- latches on any GPU bus access
   signal ram_exec_seen          : std_logic := '0';  -- latches when CPU fetches instruction from physical RAM
   signal io_ever_seen           : std_logic := '0';  -- latches when any ZN I/O access occurs
   signal spu_ever_seen          : std_logic := '0';  -- latches when SPU registers accessed
   signal cd_ever_seen           : std_logic := '0';  -- latches when CD-ROM registers accessed
   signal dma_ever_seen          : std_logic := '0';  -- latches when DMA registers written
   signal dma_gpu_write_seen     : std_logic := '0';  -- latches when DMA ch2 actually wrote a word to GPU
   signal dma2_e5_write_seen    : std_logic := '0';  -- latches when DMA ch2 wrote a word with cmd byte 0xE5
   signal dma2_prim_seen         : std_logic := '0';  -- latches when DMA ch2 wrote a word whose upper byte is a drawing primitive (0x20..0x7F: polygon/line/rect)
   signal pio_prim_seen          : std_logic := '0';  -- latches when CPU PIO wrote GP0 with upper byte 0x20..0x7F (any primitive)
   -- build #150: sticky latches for CPU PC at the cube CLUT PIO upload site (MAME PC 0x8003CB20).
   --   h50_pc_cube_loop_seen : CPU fetched instruction at exactly 0x8003CB20 ever (the load-store body of the loop)
   --   h50_pc_cube_area_seen : CPU fetched any instruction in [0x8003CB00, 0x8003CB60) ever (the surrounding function)
   --   h50_game_ram_exec_seen : CPU fetched any instruction in [0x80050000, 0x80060000) ever (positive control: game code is running)
   signal h50_pc_cube_loop_seen  : std_logic := '0';
   signal h50_pc_cube_area_seen  : std_logic := '0';
   signal h50_game_ram_exec_seen : std_logic := '0';
   -- build #151: sticky latches on CPU PIO writes to GP0 (bus_gpu_addr="0000")
   --   h51_gp0_cubeclut_seen : CPU ever wrote 0x7FFF0000 to GP0 (cube CLUT entries 0+1 packed)
   --   h51_gp0_a0cmd_seen    : CPU ever wrote 0xA0xxxxxx to GP0 (CPU2VRAM mode command)
   --   h51_gp0_r31_seen      : CPU ever wrote a value with R=31 in upper-halfword pixel (PIO upload of any R=31 pixel)
   signal h51_gp0_cubeclut_seen  : std_logic := '0';
   signal h51_gp0_a0cmd_seen     : std_logic := '0';
   signal h51_gp0_r31_seen       : std_logic := '0';
   -- build #152: sticky latches on cube CLUT data words 1-3 at GP0 PIO.
   signal h52_gp0_word1_seen     : std_logic := '0';
   signal h52_gp0_word2_seen     : std_logic := '0';
   signal h52_gp0_word3_seen     : std_logic := '0';
   -- build #153: bisect cube CLUT init step. CPU init copies banked ROM → PSX RAM.
   signal h53_rd_cubesrc_seen    : std_logic := '0';
   signal h53_wr_staging_seen    : std_logic := '0';
   signal h53_data_7fff0000_seen : std_logic := '0';
   -- build #154: bank-value capture at the cube CLUT read.
   --   h54_bank0_at_read : zn_bank_8mb = "000" when CPU reads 0x1F7B61CC ever
   --   h54_bank1_at_read : zn_bank_8mb = "001" when CPU reads 0x1F7B61CC ever
   --   h54_bankhi_at_read: zn_bank_8mb >= "010" when CPU reads 0x1F7B61CC ever
   signal h54_bank0_at_read      : std_logic := '0';
   signal h54_bank1_at_read      : std_logic := '0';
   signal h54_bankhi_at_read     : std_logic := '0';
   signal dbg_pipeline_pixelWrite: std_logic;          -- live from GPU: rasterizer produced a pixel write
   signal raster_pixel_seen      : std_logic := '0';  -- latches when GPU rasterizer ever produced a VRAM pixel write
   signal dbg_pipeline_write_in_top : std_logic;        -- live from GPU: rasterizer wrote to Y<256
   signal dbg_vram_WE_tap        : std_logic;          -- live from GPU: vram_WE asserted toward DDR3
   signal raster_pixel_top_seen  : std_logic := '0';  -- latches when rasterizer pixel landed in Y<256 (visible top half)
   signal vram_actual_write_seen : std_logic := '0';  -- latches when vram_WE was actually asserted to DDR3
   signal dbg_pipeline_color_varied : std_logic;       -- live: rasterizer produced non-navy color
   signal dbg_vram_din_non_navy : std_logic;           -- live: vram_DIN contained non-navy data on a write
   signal pipeline_color_varied_seen : std_logic := '0';  -- latches when rasterizer ever produced non-navy color
   signal vram_din_non_navy_seen   : std_logic := '0';  -- latches when vram_DIN ever had non-navy data on write
   signal dbg_vram_dout_nonnavy           : std_logic; -- live: DDR3 returned non-navy lane on a GPU read
   signal dbg_videoout_linebuf_nonnavy    : std_logic; -- live: videoout line buffer 16-bit read != navy
   -- build #56: per-frame pixel COUNTS (uncontaminated by sticky text). Magnitude discriminates
   -- full-scene rendering (~150-245K/frame) from text-only (~few K). Sampled in clk1x (half-rate;
   -- relative magnitudes preserved across all three). Latched to disp_* at VBLANK rising edge.
   signal cnt_stage4       : unsigned(17 downto 0) := (others => '0');  -- textured pixels reaching stage4 this frame
   signal cnt_pxwr         : unsigned(17 downto 0) := (others => '0');  -- rasterizer pixel writes this frame
   signal cnt_texraw      : unsigned(17 downto 0) := (others => '0');  -- build #57: stage4 textured pixels w/ non-zero RAW texel index (texture DATA present pre-CLUT)
   signal disp_cnt_stage4  : unsigned(17 downto 0) := (others => '0');
   signal disp_cnt_pxwr    : unsigned(17 downto 0) := (others => '0');
   signal disp_cnt_texraw : unsigned(17 downto 0) := (others => '0');
   signal dbg_videoout_pixeldata_nonnavy  : std_logic; -- live: videoout pixelData_R/G/B != pure navy
   signal vram_dout_nonnavy_seen          : std_logic := '0';  -- (unused now; kept for reference) sticky version
   signal videoout_linebuf_nonnavy_seen   : std_logic := '0';  -- (unused now)
   signal videoout_pixeldata_nonnavy_seen : std_logic := '0';  -- (unused now)
   -- Frame-windowed latches (build #7: pipeline color-path narrowing).
   signal vblank_d                        : std_logic := '0';
   signal dbg_rast_display_nonnavy        : std_logic;
   signal dbg_rast_offdisp_nonnavy        : std_logic;
   signal dbg_vramdin_display_nonnavy     : std_logic;
   signal dbg_clut_write_nonnavy          : std_logic;
   signal dbg_clut_read_nonnavy           : std_logic;
   signal dbg_stage4_texture              : std_logic;
   signal dbg_stage4_texraw_nz            : std_logic;  -- build #57: stage4 textured pixel w/ non-zero raw texel index
   signal dbg_textPalReqY_clut            : std_logic;  -- build #63: textPalReqY in [460,500)
   signal dbg_last_succ_palX              : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_last_succ_palY              : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_textPalReqY_lo              : std_logic;  -- build #68: textPalReqY in [460,480)
   signal dbg_textPalReqY_hi              : std_logic;  -- build #68: textPalReqY in [480,500)
   signal dbg_b82_byte_redslot            : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_byte_greenslot          : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_captured                : std_logic;                      -- build #82
   signal clut_succ_lo_seen               : std_logic := '0';  -- build #68: sticky for Y<480 success
   signal clut_succ_hi_seen               : std_logic := '0';  -- build #68: sticky for Y>=480 success
   signal latch_lo_y_fan                  : std_logic_vector(17 downto 0);  -- build #68: latch fanned for bar
   signal latch_hi_y_fan                  : std_logic_vector(17 downto 0);  -- build #68: latch fanned for bar
   -- build #80: generic triage bars (any title) — RED=ram_exec_seen, GREEN=raster_pixel_seen, BLUE=gpu_accessed_seen
   signal triage_red_fan                  : std_logic_vector(8 downto 0);
   signal triage_green_fan                : std_logic_vector(8 downto 0);
   signal triage_blue_fan                 : std_logic_vector(8 downto 0);
   -- Performance counters (replaces the three triage bars when status[93] is on).
   -- Each runs a 2^27-cycle window (~4 s at 33 MHz clk1x), counts cycles where the
   -- target condition is true, then latches the top 9 bits as the bar width.
   --   RED  = ROM read stall   (banked-ROM lw in flight)        [B-meas]
   --   GREEN= RAM read stall    (RAM lw / instr fetch in flight) [B-meas]
   --   BLUE = RAM write stall   (RAM sw past write FIFO)         [B-meas]
   signal perf_window                     : unsigned(26 downto 0) := (others => '0');
   signal perf_evt_ramwait                : unsigned(26 downto 0) := (others => '0');
   signal perf_evt_arbiter                : unsigned(26 downto 0) := (others => '0');
   signal perf_evt_vrampause              : unsigned(26 downto 0) := (others => '0');
   signal perf_disp_ramwait               : std_logic_vector(8 downto 0) := (others => '0');
   signal perf_disp_arbiter               : std_logic_vector(8 downto 0) := (others => '0');
   signal perf_disp_vrampause             : std_logic_vector(8 downto 0) := (others => '0');
   -- B-meas: CPU memory-stall classification from memorymux (debug overlay only)
   signal sig_busy_rom                    : std_logic;
   signal sig_busy_ramrd                  : std_logic;
   signal sig_busy_ramwr                  : std_logic;
   -- B-meas5: rising-edge detect regs for the frame-rate event counters
   signal evt_fclr_d                      : std_logic := '0';
   signal evt_fset_d                      : std_logic := '0';
   signal evt_vblk_d                      : std_logic := '0';
   -- B-meas10: latched ZN-IO poll address from memorymux
   signal sig_znio_addr                   : std_logic_vector(20 downto 0);
   -- build #119: CAT702 byte-exchange diagnostics from zn_sio
   signal dbg_first_kn01_rx               : std_logic_vector(7 downto 0);
   -- build #157: BR2 CAT702 byte-0/byte-3 captures
   signal b157_byte0_sig                  : std_logic_vector(7 downto 0);
   signal b157_byte3_sig                  : std_logic_vector(7 downto 0);
   signal b157_anchor_sig                 : std_logic;
   signal dbg_first_kn02_rx               : std_logic_vector(7 downto 0);
   signal dbg_kn02_ever                   : std_logic;
   -- build #114 H1+H2: cube 0x64 rect path test
   signal h12_red_anchor_sig              : std_logic;
   signal h12_green_dm_ok_sig             : std_logic;
   signal h12_blue_dm_stale_sig           : std_logic;
   signal h12_yellow_busy0_sig            : std_logic;
   signal h12_white_dm_chg_sig            : std_logic;
   signal h12_cyan_emit_busy0_sig         : std_logic;
   signal h12_magenta_busy_long_sig       : std_logic;
   -- build #115: H1 race-frequency counters (9-bit upper portion of 16-bit counter)
   signal h12_stale_count_hi_sig          : std_logic_vector(8 downto 0);
   signal h12_ok_count_hi_sig             : std_logic_vector(8 downto 0);
   signal h12_stale_gt_ok_sig             : std_logic;
   -- build #117: G+B stripping locator stickys
   signal h17_anchor_sig                  : std_logic;
   signal h17_g_sig                       : std_logic;
   signal h17_b_sig                       : std_logic;
   -- build #119: vram_DIN G+B locator
   signal h19_anchor_sig                  : std_logic;
   signal h19_g_sig                       : std_logic;
   signal h19_b_sig                       : std_logic;
   -- build #120: counter-based G+B prevalence at cube area writes
   signal h20_anchor_count_hi_sig         : std_logic_vector(8 downto 0);
   signal h20_g_count_hi_sig              : std_logic_vector(8 downto 0);
   signal h20_b_count_hi_sig              : std_logic_vector(8 downto 0);
   -- build #122: vram_DOUT capture at hi-Y CLUT[3] load
   signal h22_anchor_sig                  : std_logic;
   signal h22_clut3_r_sig                 : std_logic_vector(4 downto 0);
   signal h22_clut3_g_sig                 : std_logic_vector(4 downto 0);
   -- build #124: SDRAM round-trip self-test
   signal h24_write_r_sig                 : std_logic_vector(4 downto 0);
   signal h24_read_r_sig                  : std_logic_vector(4 downto 0);
   signal h24_both_anchors_sig            : std_logic;
   -- build #128: cpu2vram vs vram_DIN comparison
   signal h28_cpu_r_sig                   : std_logic_vector(4 downto 0);
   signal h28_vram_r_sig                  : std_logic_vector(4 downto 0);
   signal h28_both_anchors_sig            : std_logic;
   -- build #129: Tecmo bank verification
   signal h29_bank_sig                    : std_logic_vector(2 downto 0);
   signal h29_bank_anchor_sig             : std_logic;
   signal h29_bank_ever_changed_sig       : std_logic;
   -- build #131: DMA delivery instrumentation
   signal h31_pixel1_r_sig                : std_logic_vector(4 downto 0);
   signal h31_pixel2_r_sig                : std_logic_vector(4 downto 0);
   signal h31_rich_ever_sig               : std_logic;
   -- build #132: DMA R-value sticky detectors
   signal h32_r31_ever_sig                : std_logic;
   signal h32_r_high_ever_sig             : std_logic;
   signal h32_pixel1_nonzero_ever_sig     : std_logic;
   -- build #133: fifo_data_1 vs cpu2vram_pixelColor at cube CLUT lane-3
   signal h33_fifo_data_1_r_sig           : std_logic_vector(4 downto 0);
   signal h33_cpu_color_r_sig             : std_logic_vector(4 downto 0);
   signal h33_anchor_sig                  : std_logic;
   signal h33_r31_ever_sig                : std_logic;
   -- build #134: fifoIn_Dout halfword R bits stickys
   signal h34_lower_r31_ever_sig          : std_logic;
   signal h34_upper_r31_ever_sig          : std_logic;
   signal h34_upper_msb_ever_sig          : std_logic;
   -- build #137: cpu2vram FSM latch-chain probes
   signal h37_input_r31_ever_sig          : std_logic;
   signal h37_writing_r31_ever_sig        : std_logic;
   signal h37_latch_r31_ever_sig          : std_logic;
   -- build #138: cube-CLUT-specific lane probes
   signal h38_lane2_input_r31_ever_sig    : std_logic;
   signal h38_lane3_latch_r31_ever_sig    : std_logic;
   signal h38_lane3_anchor_ever_sig       : std_logic;
   -- build #139: cube-shape Y observability probes
   signal h39_cubeshape_any_ever_sig      : std_logic;
   signal h39_cubeshape_y482_ever_sig     : std_logic;
   signal h39_cubeshape_y488_ever_sig     : std_logic;
   -- build #140: CLUT-RAM cube CLUT presence probes
   signal h40_cube_clut_loaded_ever_sig   : std_logic;
   signal h40_clut_read_7fff_ever_sig     : std_logic;
   signal h40_clut_read_023f_ever_sig     : std_logic;
   -- build #158: H4 cache-staleness sticky probes
   signal h58_x_stale_seen_sig            : std_logic;
   signal h58_y_stale_seen_sig            : std_logic;
   signal h58_pixel_seen_sig              : std_logic;
   -- build #159: H7 CLUT load value capture
   signal h59_loaded_entry0_lo_sig        : std_logic_vector(8 downto 0);
   signal h59_loaded_y_sig                : std_logic_vector(8 downto 0);
   signal h59_anchor_sig                  : std_logic;
   -- build #145: Y=482/480 pixelWrite probes
   signal h45_y482_anchor_sig             : std_logic;
   signal h45_y482_pixwrite_sig           : std_logic;
   signal h45_y480_pixwrite_sig           : std_logic;
   -- build #146-149: cpu2vram value-capture probes
   signal h46_y_minus_240_sig             : std_logic_vector(8 downto 0);
   signal h46_y_high_bit_sig              : std_logic;
   signal h46_anchor_sig                  : std_logic;
   signal h49_entry1_low_sig              : std_logic_vector(8 downto 0);
   -- build #63: sticky latches for CLUT-RAM ever receiving real data, by Y range (still updated, not displayed in #65)
   signal clut_real_data_hi_y_seen        : std_logic := '0';
   signal clut_real_data_lo_y_seen        : std_logic := '0';
   -- build #8 CLUT-load chain pinpoint taps
   signal dbg_textPalNew                  : std_logic;
   signal dbg_textPalReq_set              : std_logic;
   signal dbg_state_REQ_PAL               : std_logic;
   signal dbg_CLUTwrenA_any               : std_logic;
   signal dbg_drawMode_8                  : std_logic;
   signal dbg_noTexture_pin               : std_logic;
   -- derived events
   signal evt_ram_exec                    : std_logic;
   -- per-frame accumulators (one per bar — build #7 layout)
   signal frame_ram_exec                  : std_logic := '0';
   signal frame_clut_write_nonnavy        : std_logic := '0';
   signal frame_clut_read_nonnavy         : std_logic := '0';
   signal frame_stage4_texture            : std_logic := '0';
   signal frame_pipeline_color_varied     : std_logic := '0';
   signal frame_pixeldata_nonnavy         : std_logic := '0';
   signal frame_pipeline_write_any        : std_logic := '0';
   -- build #8 frame accumulators (CLUT-load chain pinpoint)
   signal frame_b8_textPalNew             : std_logic := '0';
   signal frame_b8_textPalReq_set         : std_logic := '0';
   signal frame_b8_state_REQ_PAL          : std_logic := '0';
   signal frame_b8_CLUTwrenA_any          : std_logic := '0';
   signal frame_b8_drawMode_8             : std_logic := '0';
   signal frame_b8_noTexture_pin          : std_logic := '0';
   -- displayed snapshots
   signal disp_ram_exec                   : std_logic := '0';
   signal disp_clut_write_nonnavy         : std_logic := '0';
   signal disp_clut_read_nonnavy          : std_logic := '0';
   signal disp_stage4_texture             : std_logic := '0';
   signal disp_pipeline_color_varied      : std_logic := '0';
   signal disp_pixeldata_nonnavy          : std_logic := '0';
   signal disp_pipeline_write_any         : std_logic := '0';
   -- build #8 displayed snapshots (latched-forever sticky to make missed events catchable)
   signal disp_b8_textPalNew              : std_logic := '0';
   signal disp_b8_textPalReq_set          : std_logic := '0';
   signal disp_b8_state_REQ_PAL           : std_logic := '0';
   signal disp_b8_CLUTwrenA_any           : std_logic := '0';
   signal disp_b8_drawMode_8              : std_logic := '0';
   signal disp_b8_noTexture_pin           : std_logic := '0';
   -- build #10 LATCHED-FOREVER VRAM data taps
   signal disp_vram_dout_nonnavy_b10      : std_logic := '0';
   signal disp_vram_din_nonnavy_b10       : std_logic := '0';
   -- build #11 CPU2VRAM taps
   signal dbg_cpu2vram_pixelWrite         : std_logic;
   signal dbg_cpu2vram_color_nonnavy      : std_logic;
   signal disp_cpu2vram_active_ever       : std_logic := '0';
   signal disp_cpu2vram_nonnavy_ever      : std_logic := '0';
   -- build #12 readback chain LATCHED-FOREVER
   signal disp_clut_write_nv_ever         : std_logic := '0';
   signal disp_clut_read_nv_ever          : std_logic := '0';
   signal disp_pipeline_color_var_ever    : std_logic := '0';
   signal disp_pixeldata_nv_ever          : std_logic := '0';
   signal disp_pipeline_pxwr_ever         : std_logic := '0';
   -- build #13 CLUT addressing
   signal dbg_textPalReqX_nz              : std_logic;
   signal dbg_textPalReqY_nz              : std_logic;
   signal dbg_cpu2vram_dstY_bit8          : std_logic;
   signal dbg_cpu2vram_dstY_nz            : std_logic;
   signal disp_clut_X_nz_ever             : std_logic := '0';
   signal disp_clut_Y_nz_ever             : std_logic := '0';
   signal disp_cpu2vram_dstY_bit8_ever    : std_logic := '0';
   signal disp_cpu2vram_dstY_nz_ever      : std_logic := '0';
   -- build #14 CPU2VRAM destination X
   signal dbg_cpu2vram_dstX_zero          : std_logic;
   signal dbg_cpu2vram_dstX_nz            : std_logic;
   signal disp_cpu2vram_dstX_zero_ever    : std_logic := '0';
   signal disp_cpu2vram_dstX_nz_ever      : std_logic := '0';
   -- build #15 ANY write at X=0
   signal dbg_vram_we_x_zero              : std_logic;
   signal dbg_vram_we_x_zero_nv           : std_logic;
   signal dbg_vram2vram_active            : std_logic;
   signal dbg_vramFill_active             : std_logic;
   signal disp_vram_we_x_zero_ever        : std_logic := '0';
   signal disp_vram_we_x_zero_nv_ever     : std_logic := '0';
   signal disp_vram2vram_active_ever      : std_logic := '0';
   signal disp_vramFill_active_ever       : std_logic := '0';
   -- build #17 verify Y-wrap fix
   signal dbg_pixelAddr_Y_hi              : std_logic;
   signal dbg_cpu2vram_Y_hi               : std_logic;
   signal dbg_vram_addr_Y_hi_we           : std_logic;
   signal dbg_vram_addr_Y_hi_rd           : std_logic;
   signal disp_pixelAddr_Y_hi_ever        : std_logic := '0';
   signal disp_cpu2vram_Y_hi_ever         : std_logic := '0';
   signal disp_vram_addr_Y_hi_we_ever     : std_logic := '0';
   signal disp_vram_addr_Y_hi_rd_ever     : std_logic := '0';
   -- build #19: lpadv-tuned diagnostics
   signal dbg_textPalReqX_ge_256          : std_logic;
   signal dbg_textPalReqX_hi              : std_logic;
   signal dbg_cpu2vram_dstX_hi            : std_logic;
   signal dbg_cpu2vram_parsed_dstX_hi     : std_logic;  -- build #21
   signal dbg_pipeline_g_set              : std_logic;  -- build #23
   signal dbg_pipeline_b_set              : std_logic;  -- build #23
   signal dbg_vram_din_gb                 : std_logic;  -- build #23
   signal dbg_cpu2vram_color_gb           : std_logic;  -- build #23
   -- build #24: live + frame-windowed textured-rect drawMode tracking
   signal dbg_rect_tex_4bit               : std_logic;
   signal dbg_rect_tex_8bit               : std_logic;
   signal dbg_rect_tex_15bit              : std_logic;
   signal dbg_rect_tex_pixel_gb           : std_logic;
   signal frame_rect_tex_4bit             : std_logic := '0';
   signal frame_rect_tex_8bit             : std_logic := '0';
   signal frame_rect_tex_15bit            : std_logic := '0';
   signal frame_rect_tex_pixel_gb         : std_logic := '0';
   signal disp_rect_tex_4bit              : std_logic := '0';
   signal disp_rect_tex_8bit              : std_logic := '0';
   signal disp_rect_tex_15bit             : std_logic := '0';
   signal disp_rect_tex_pixel_gb          : std_logic := '0';
   signal cpu2vram_parsed_dstX_hi_seen    : std_logic := '0';
   signal cpu2vram_color_nonnavy_seen     : std_logic := '0';  -- build #22
   signal pixelcolor_g_seen               : std_logic := '0';  -- build #23: any VRAM pixel write had G bits non-zero
   signal pixelcolor_b_seen               : std_logic := '0';  -- build #23: any VRAM pixel write had B bits non-zero
   signal texpal_gb_seen                  : std_logic := '0';  -- build #23: texdata_palette had G or B bit non-zero ever
   signal vram_din_gb_seen                : std_logic := '0';  -- build #23: vram_DIN had G or B bit non-zero (any lane)
   signal cmd_64_seen_ever                : std_logic := '0';  -- any GP0 write (PIO+DMA) with upper byte 0x64
   signal cmd_2C_seen_ever                : std_logic := '0';  -- any GP0 write (PIO+DMA) with upper byte 0x2C
   signal cmd_A0_seen_ever                : std_logic := '0';  -- build #20: any GP0 write with upper byte 0xA0 (cpu2vram dispatch)
   signal textPalX_ge_256_seen            : std_logic := '0';
   signal textPalX_hi_seen                : std_logic := '0';  -- X>=512 (CLUT X=768)
   signal cpu2vram_dstX_hi_seen           : std_logic := '0';
   -- build #26: cube-CLUT (X>=512) readback color forensics
   signal dbg_cubeclut_gb                 : std_logic;
   signal dbg_cubeclut_ronly              : std_logic;
   signal dbg_loclut_gb                   : std_logic;
   signal cubeclut_gb_seen                : std_logic := '0';  -- cube CLUT (X>=512) ever read back colorful
   signal cubeclut_ronly_seen             : std_logic := '0';  -- cube CLUT (X>=512) ever read back red-only
   signal loclut_gb_seen                  : std_logic := '0';  -- low-X CLUT ever read back colorful (positive control)
   signal dma_gpu_waiting_seen   : std_logic := '0';  -- latches when DMA ch2 was waiting for GPU (potential stall)
   signal irq_dma_seen           : std_logic := '0';  -- latches when DMA IRQ fires (DMA completed a transfer)
   signal dma_spu_write_seen     : std_logic := '0';  -- latches when DMA ch4 (SPU) wrote data
   signal irq_stat_read_seen     : std_logic := '0';  -- latches when CPU reads I_STAT/I_MASK (IRQ polling)
   signal irq_stat_write_seen    : std_logic := '0';  -- latches when CPU writes I_STAT/I_MASK (IRQ acknowledge)
   signal irq_cdrom_seen         : std_logic := '0';  -- latches when CD-ROM module generates an IRQ
   signal irq_timer_seen         : std_logic := '0';  -- latches when any timer (0/1/2) generates an IRQ
   signal vblank_irq_seen        : std_logic := '0';  -- latches when irq_VBLANK fires (VBLANK IRQ reached I_STAT[0])
   -- ZN security debug latches
   signal zn_sio_ever_seen       : std_logic := '0';  -- any SIO byte started on port 2
   signal zn_check1_seen         : std_logic := '0';  -- sec_select="110" (0x88=KN01) ever written
   signal zn_check2_seen         : std_logic := '0';  -- sec_select="101" (0x84=KN02) ever written
   signal zn_kn02_rx_nonzero    : std_logic := '0';  -- KN02 returned non-trivial byte (not 0x00/0xFF)

   -- build #168: sanity-check the detection mechanism by probing 3 known-good addresses.
   -- All 3 should light up bright if detection works; any dark indicates a wiring issue.
   --   RED   = ANY write to 0x000969E0 (state byte — what B167 tried; expected dark from prior data)
   --   GREEN = ANY write to 0x000C6D0 (wait_vsync flag — B166 verified fires ~240/4s)
   --   BLUE  = ANY write to 0x1FB00006 (Tecmo bank reg — B130 verified fires ~40/4s)
   signal b163_win_cnt           : unsigned(26 downto 0) := (others => '0');
   signal b163_win_tick          : std_logic := '0';
   signal b163_dma2_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: state=3 writes
   signal b163_dma4_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: state=5 writes
   signal b163_bank_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: any state write
   signal b163_dma2_disp         : std_logic_vector(8 downto 0) := (others => '0');
   signal b163_dma4_disp         : std_logic_vector(8 downto 0) := (others => '0');
   signal b163_bank_disp         : std_logic_vector(8 downto 0) := (others => '0');
   -- B30: stuck-PC capture. Latch the CPU PC once per vblank (stable per frame),
   -- display PC[25:2] across the 3 bars: RED=PC[9:2], GREEN=PC[17:10], BLUE=PC[25:18].
   -- Reconstruct PC = (BLUE<<18)|(GREEN<<10)|(RED<<2) | 0x80000000.
   signal dbg_cpu_pc_sig         : std_logic_vector(31 downto 0);
   signal dbg_ee_word0_sig       : std_logic_vector(31 downto 0);  -- DIAG: EEPROM word-0 readback
   signal dbg_ee_stat_sig        : std_logic_vector(127 downto 0); -- DIAG: EEPROM write/read stats
   -- ===== B-inst4 (2026-07-17): 4-bug instrument block, read out via the 160-bit ZNSC ISSP =====
   -- probe. Serves: BR2 ch2-DMA-IRQ delivery (#279), hvnsgate post-upload freeze (#280),
   -- raystorm ROM R-3 first-read capture (#286), 2.02O register-spin ID (#285).
   -- The live PC at [159:128] doubles as a JTAG sampling profiler: repeated ISSP reads of a
   -- spinning core name the loop PCs directly.
   signal dbg_rs_valid           : std_logic := '0';                        -- raystorm latch armed->fired
   signal dbg_rs_pending         : std_logic := '0';
   signal dbg_rs_addr            : unsigned(22 downto 4) := (others => '0');
   signal dbg_rs_data            : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_last_io_rd         : unsigned(11 downto 0) := (others => '0');
   signal dbg_io_rd_cnt          : unsigned(7 downto 0) := (others => '0');
   signal dbg_ch2_kick_cnt       : unsigned(7 downto 0) := (others => '0');
   signal dbg_dma_irq_cnt        : unsigned(7 downto 0) := (others => '0');
   signal dbg_vblank_cnt         : unsigned(7 downto 0) := (others => '0');
   signal dbg_gpustat_hi         : std_logic_vector(4 downto 0) := (others => '0');
   signal dbg_gpustat_pend       : std_logic := '0';
   signal dbg_irq_dma_d          : std_logic := '0';
   signal dbg_vblank_d2          : std_logic := '0';
   signal dbg_istat_live         : unsigned(15 downto 0);  -- synthesizable copy of irq.vhd export_irq
   -- ===== B-inst5 (2026-07-17 late): round-2 probes in zn_debug_words[255:160] =====
   -- raystorm R-3 checksum shadow: mimic the game's lhu-sum over the Taito bank-0
   -- window 0x1F600000-0x1F7FFFFF; compare rs_sum_all vs the game's expected 0x7F9E.
   -- rs_sum_lo covers only 0x600000-0x6FFFFF (addr[20]=0) for one-step bisection.
   signal rs2_pending            : std_logic := '0';
   signal rs2_half               : std_logic := '0';                        -- addr(1) of pending lhu
   signal rs2_lo                 : std_logic := '0';                        -- addr(20)=0 → lo half of window
   signal rs2_sum_all            : unsigned(15 downto 0) := (others => '0');
   signal rs2_sum_lo             : unsigned(15 downto 0) := (others => '0');
   signal rs2_rd_cnt             : unsigned(20 downto 0) := (others => '0');
   -- BR2 bank-2 probe (Raizing) / hvnsgate loop-bounds probe (Atlus) — shared capture
   -- slot, platform-gated so only one is ever active per boot.
   signal dbg_zn_bank_sig        : std_logic_vector(2 downto 0);
   signal bank2_ever             : std_logic := '0';
   signal sh_pending             : std_logic := '0';
   signal sh_valid               : std_logic := '0';
   signal sh_data                : std_logic_vector(31 downto 0) := (others => '0');
   signal sh_addr                : unsigned(22 downto 2) := (others => '0');
   signal rs2_sum_all_slv        : std_logic_vector(15 downto 0);
   signal rs2_sum_lo_slv         : std_logic_vector(15 downto 0);
   signal sh_addr_slv            : std_logic_vector(20 downto 0);
   signal rs2_cnt_hi_slv         : std_logic_vector(5 downto 0);
   signal pc_latch               : std_logic_vector(31 downto 0) := (others => '0');
   -- B32: last cache-hit read word-addr (from cpu). Display byte-addr = (raddr<<2)|0x80000000:
   -- RED=raddr[7:0], GREEN=raddr[15:8], BLUE=raddr[20:16].
   signal dbg_dcache_raddr_sig   : std_logic_vector(20 downto 0);
   signal raddr_latch            : std_logic_vector(20 downto 0) := (others => '0');
   signal dbg_shadow_sig         : std_logic_vector(127 downto 0);  -- B-sc: D-cache shadow-compare results
   signal b163_DMA_GPU_writeEna_d : std_logic := '0';  -- B167: state=3 edge
   signal b163_DMA_SPU_writeEna_d : std_logic := '0';  -- B167: state=5 edge
   signal b163_bank_write_d       : std_logic := '0';  -- B167: any state write edge

   -- savestates
   signal loading_savestate      : std_logic;
   signal savestate_pause        : std_logic;
   signal ddr3_savestate         : std_logic;
   
   signal SS_reset               : std_logic;
   
   signal savestate_savestate    : std_logic; 
   signal savestate_loadstate    : std_logic; 
   signal savestate_address      : integer; 
   signal savestate_busy         : std_logic; 
   
   signal SS_DataWrite           : std_logic_vector(31 downto 0);
   signal SS_Adr                 : unsigned(18 downto 0);
   signal SS_wren                : std_logic_vector(16 downto 0);
   signal SS_rden                : std_logic_vector(16 downto 0);
   signal SS_DataRead_CPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPUTiming  : std_logic_vector(31 downto 0);
   signal SS_DataRead_DMA        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GTE        : std_logic_vector(31 downto 0);
   signal SS_DataRead_JOYPAD     : std_logic_vector(31 downto 0);
   signal SS_DataRead_MDEC       : std_logic_vector(31 downto 0);
   signal SS_DataRead_MEMORY     : std_logic_vector(31 downto 0);
   signal SS_DataRead_TIMER      : std_logic_vector(31 downto 0);
   signal SS_DataRead_SOUND      : std_logic_vector(31 downto 0);
   signal SS_DataRead_IRQ        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SIO        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SCP        : std_logic_vector(31 downto 0);
   signal SS_DataRead_CD         : std_logic_vector(31 downto 0);
   
   signal ss_ram_BUSY            : std_logic;                    
   signal ss_ram_DOUT            : std_logic_vector(63 downto 0);
   signal ss_ram_DOUT_READY      : std_logic;
   signal ss_ram_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_ADDR            : std_logic_vector(25 downto 0) := (others => '0');                       
   signal ss_ram_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal ss_ram_BE              : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_WE              : std_logic := '0';
   signal ss_ram_RD              : std_logic := '0'; 
   
   signal SS_SPURAM_dataWrite    : std_logic_vector(15 downto 0);
   signal SS_SPURAM_Adr          : std_logic_vector(18 downto 0);
   signal SS_SPURAM_request      : std_logic;
   signal SS_SPURAM_rnw          : std_logic;
   signal SS_SPURAM_dataRead     : std_logic_vector(15 downto 0);
   signal SS_SPURAM_done         : std_logic;
   
   signal SS_Idle                : std_logic; 
   signal SS_Idle_gpu            : std_logic; 
   signal SS_Idle_mdec           : std_logic; 
   signal SS_Idle_cd             : std_logic; 
   signal SS_Idle_spu            : std_logic; 
   signal SS_idle_pad            : std_logic; 
   signal SS_idle_irq            : std_logic; 
   signal SS_idle_cpu            : std_logic; 
   signal SS_idle_gte            : std_logic; 
   signal SS_idle_dma            : std_logic; 

-- synthesis translate_off
   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal export_8               : std_logic_vector(7 downto 0);
   signal export_16              : std_logic_vector(15 downto 0);
   signal export_32              : std_logic_vector(31 downto 0);
   signal export_irq             : unsigned(15 downto 0);
   signal export_gtm             : unsigned(11 downto 0);
   signal export_line            : unsigned(11 downto 0);
   signal export_gpus            : unsigned(31 downto 0);
   signal export_gobj            : unsigned(15 downto 0);
   signal export_t_current0      : unsigned(15 downto 0);
   signal export_t_current1      : unsigned(15 downto 0);
   signal export_t_current2      : unsigned(15 downto 0);
-- synthesis translate_on
   
   signal debug_firstGTE         : std_logic;

   -- build #39: Tecmo bank register exposed from memorymux for debug instrumentation in gpu
   signal zn_bank_8mb_dbg        : std_logic_vector(2 downto 0);
   signal dbg_palrd_green        : std_logic;  -- build #47
   signal dbg_palrd_red          : std_logic;  -- build #47
   signal dbg_palrd_any          : std_logic;  -- build #47
   signal dbg_palrd_redrow_red   : std_logic;  -- build #47 red-row control
   signal dbg_palrd_value        : std_logic_vector(31 downto 0);  -- build #50
   signal dbg_palrd_addr         : std_logic_vector(31 downto 0);  -- build #51
   signal dbg_palrd_words        : std_logic_vector(255 downto 0); -- build #52
   signal dbg_cubeclut_window_seen : std_logic;  -- build #135
   signal dbg_cubeclut_exact_seen  : std_logic;  -- build #135
   signal dbg_cubeclut_bank0_seen  : std_logic;  -- build #135

begin
   
   -- reset
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         reset_in <= reset or reset_exe;
      end if;
   end process;
   

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;

   process (clk3x)
   begin
      if rising_edge(clk3x) then
         clk1xToggle3x   <= clk1xToggle;
         clk1xToggle3X_1 <= clk1xToggle3X;
         clk3xIndex    <= '0';
         if (clk1xToggle3X_1 = clk1xToggle) then
            clk3xIndex <= '1';
         end if;
      end if;
   end process;

   -- Expose ZN SNAC intermediary signals through entity ports
   transmitValueSnac <= zn_txbyte;
   beginTransferSnac <= zn_beginTransfer;

   -- busses
   process (clk1x)
   begin
      if rising_edge(clk1x) then

         bus_exp1_dataRead <= (others => '0');
         if (bus_exp1_read = '1') then
            bus_exp1_dataRead <= (others => '1');
         end if;

         bus_exp3_dataRead <= (others => '0');
         if (bus_exp3_read = '1') then
            bus_exp3_dataRead <= (others => '1');
         end if;

      end if;
   end process;
 
   SS_idle    <= SS_Idle_gpu and SS_Idle_mdec and SS_Idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma;
   
   Pause_Idle <= SS_Idle_gpu and SS_Idle_mdec and Pause_idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma; 
   
   -- ce generation
   canDMA <= memMuxIdle;
   
   isPaused <= pausing;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1' or pausing = '1') then
         
            ce        <= '0';
            if (reset_intern = '1') then
               cpuPaused <= '0';
            end if;
            
            if (pause = '1') then
               pausing   <= '1';
            end if;
            
            if (pause = '0' and savestate_pause = '0' and memcard1_pause = '0' and memcard2_pause = '0' and pauseCD = '0' and allowunpause = '1') then
               pausing   <= '0';
               pausingSS <= '0';
            end if;
            
            if (savestate_pause = '1' and pausingSS = '0' and allowunpause = '1') then -- must go out of pause for savestate if not in a saveable state
               pausing <= '0';
            end if;
         
         else
      
            ce        <= '1';
         
            if (reset_intern = '1') then
               cpuPaused <= '0';
            else
         
               -- switch to pause when CD data fetch is slow
               if ((pauseCD = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and Pause_Idle = '1') then
                  pausing   <= '1';
                  ce        <= '0';
               -- switch to pause/savestate pausing
               elsif ((pause = '1' or savestate_pause = '1' or memcard1_pause = '1' or memcard2_pause = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and SS_idle = '1') then
                  pausing   <= '1';
                  pausingSS <= '1';
                  ce        <= '0';
               elsif ((cpuPaused = '1' and dmaOn = '1') or (dmaRequest = '1' and canDMA = '1')) then -- switch to dma
                  cpuPaused <= '1';
               elsif (dmaOn = '0') then -- switch to CPU
                  cpuPaused <= '0';
               end if;
               
            end if;
            
         end if;   
         
         if (reset_in = '1') then
            pausing   <= '0';
            pausingSS <= '0';
         end if;
         
      end if;
   end process;
   
   -- error codes
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset_intern = '1') then
            errorEna  <= '0';
            errorCode <= x"0";
         else
         
            if (errorEna = '0') then
               if (errorCD       = '1') then errorEna  <= '1'; errorCode <= x"1"; end if;
               if (errorCPU      = '1') then errorEna  <= '1'; errorCode <= x"2"; end if;
               if (errorGPU      = '1') then errorEna  <= '1'; errorCode <= x"3"; end if;
               if (errorMASK     = '1') then errorEna  <= '1'; errorCode <= x"7"; end if;
               if (errorCHOP     = '1') then errorEna  <= '1'; errorCode <= x"8"; end if;
               if (errorGPUFIFO  = '1') then errorEna  <= '1'; errorCode <= x"9"; end if;
               if (errorSPUTIME  = '1') then errorEna  <= '1'; errorCode <= x"A"; end if;
               if (errorDMACPU   = '1') then errorEna  <= '1'; errorCode <= x"B"; end if;
               if (errorDMAFIFO  = '1') then errorEna  <= '1'; errorCode <= x"C"; end if;
               if (errorCPU2     = '1') then errorEna  <= '1'; errorCode <= x"D"; end if;
               if (errorTimer    = '1') then errorEna  <= '1'; errorCode <= x"E"; end if;
               if (errorBuswidth = '1') then errorEna  <= '1'; errorCode <= x"F"; end if;
            end if;
            
            if (errorEna = '0' or errorCode = x"3") then
               if (errorLINE = '1') then errorEna  <= '1'; errorCode <= x"4"; end if;
               if (errorRECT = '1') then errorEna  <= '1'; errorCode <= x"5"; end if;
               if (errorPOLY = '1') then errorEna  <= '1'; errorCode <= x"6"; end if;
            end if;
            
         end if;
         
         debugmodeOn <= '0';
         if (REPRODUCIBLEGPUTIMING = '1') then debugmodeOn <= '1'; end if;
         if (noTexture             = '1') then debugmodeOn <= '1'; end if;
         if (SPUon                 = '0') then debugmodeOn <= '1'; end if;
         if (REVERBOFF             = '1') then debugmodeOn <= '1'; end if;
         if (REPRODUCIBLESPUDMA    = '1') then debugmodeOn <= '1'; end if;
         if (PATCHSERIAL           = '1') then debugmodeOn <= '1'; end if;
         
      end if;
   end process;
   
   -- DDR3 arbiter
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         memDDR3card1_ack    <= '0';
         memDDR3card2_ack    <= '0';
         memHPScard1_ack     <= '0';
         memHPScard2_ack     <= '0';
         memSPU_ack          <= '0';

         if (reset_intern = '1') then
            arbiter_active    <= '0';
            vram_pause        <= '0';
            ddr3state         <= ARBITERIDLE;

            memDDR3card1_acknext  <= '0';
            memDDR3card2_acknext  <= '0';
            memHPScard1_acknext   <= '0';
            memHPScard2_acknext   <= '0';
            memSPU_acknext        <= '0';
         else
         
            case (ddr3state) is
            
               when ARBITERIDLE =>
                  memDDR3card1_acknext  <= '0';
                  memDDR3card2_acknext  <= '0';
                  memHPScard1_acknext   <= '0';
                  memHPScard2_acknext   <= '0';
                  memSPU_acknext        <= '0';
                  if (memDDR3card1_request = '1' or memDDR3card2_request = '1' or memHPScard1_request = '1' or memHPScard2_request = '1' or memSPU_request = '1') then
                     vram_pause <= '1';
                     ddr3state  <= WAITGPUPAUSED;
                  end if;
                  
               when WAITGPUPAUSED =>
                  if (vram_paused = '1' and ddr3_savestate = '0') then
                     ddr3state      <= REQUEST; 
                     arbiter_active <= '1';
                     if (memDDR3card1_request = '1') then
                        memDDR3card1_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memDDR3card1_ADDR;    
                        arbiter_DIN          <= memDDR3card1_DIN;     
                        arbiter_BE           <= memDDR3card1_BE;      
                        arbiter_WE           <= memDDR3card1_WE;      
                        arbiter_RD           <= memDDR3card1_RD;
                     elsif (memDDR3card2_request = '1') then
                        memDDR3card2_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memDDR3card2_ADDR;    
                        arbiter_DIN          <= memDDR3card2_DIN;     
                        arbiter_BE           <= memDDR3card2_BE;      
                        arbiter_WE           <= memDDR3card2_WE;      
                        arbiter_RD           <= memDDR3card2_RD;
                     elsif (memHPScard1_request = '1') then
                        memHPScard1_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memHPScard1_ADDR;    
                        arbiter_DIN          <= memHPScard1_DIN;     
                        arbiter_BE           <= memHPScard1_BE;      
                        arbiter_WE           <= memHPScard1_WE;      
                        arbiter_RD           <= memHPScard1_RD;
                     elsif (memHPScard2_request = '1') then
                        memHPScard2_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memHPScard2_ADDR;    
                        arbiter_DIN          <= memHPScard2_DIN;     
                        arbiter_BE           <= memHPScard2_BE;      
                        arbiter_WE           <= memHPScard2_WE;      
                        arbiter_RD           <= memHPScard2_RD;
                     elsif (memSPU_request = '1') then
                        memSPU_acknext       <= '1';
                        arbiter_BURSTCNT     <= memSPU_BURSTCNT;
                        arbiter_ADDR         <= x"03" & memSPU_ADDR;
                        arbiter_DIN          <= memSPU_DIN;
                        arbiter_BE           <= memSPU_BE;
                        arbiter_WE           <= memSPU_WE;
                        arbiter_RD           <= memSPU_RD;
                     end if;
                  end if;
               
               when REQUEST =>
                  if (ddr3_BUSY = '0') then
                     ddr3state  <= WAITDONE;
                     arbiter_WE <= '0';
                     arbiter_RD <= '0';
                     if (memDDR3card1_acknext = '1') then memDDR3card1_ack <= '1'; end if;
                     if (memDDR3card2_acknext = '1') then memDDR3card2_ack <= '1'; end if;
                     if (memHPScard1_acknext  = '1') then memHPScard1_ack <= '1';  end if;
                     if (memHPScard2_acknext  = '1') then memHPScard2_ack <= '1';  end if;
                     if (memSPU_acknext       = '1') then memSPU_ack <= '1';       end if;
                  end if;

               when WAITDONE =>
                  if (
                      (memDDR3card1_request and memDDR3card1_acknext) = '0' and
                      (memDDR3card2_request and memDDR3card2_acknext) = '0' and
                      (memHPScard1_request  and memHPScard1_acknext ) = '0' and
                      (memHPScard2_request  and memHPScard2_acknext ) = '0' and
                      (memSPU_request       and memSPU_acknext      ) = '0'
                     ) then
                     ddr3state      <= ARBITERIDLE;
                     arbiter_active <= '0';
                     vram_pause     <= '0';
                  end if;
               
            end case;
         end if;
      end if;
   end process;
   
   
   imemctrl : entity work.memctrl
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,

      bus_addr             => bus_memc_addr,     
      bus_dataWrite        => bus_memc_dataWrite,
      bus_read             => bus_memc_read,     
      bus_write            => bus_memc_write,    
      bus_dataRead         => bus_memc_dataRead,      
      
      bus2_addr            => bus_memc2_addr,     
      bus2_dataWrite       => bus_memc2_dataWrite,
      bus2_read            => bus_memc2_read,     
      bus2_write           => bus_memc2_write,    
      bus2_dataRead        => bus_memc2_dataRead,
      
      errorBuswidth        => errorBuswidth,
      
      spu_memctrl          => spu_memctrl, 
      cd_memctrl           => cd_memctrl, 
      bios_memctrl         => bios_memctrl, 
      ex1_memctrl          => ex1_memctrl, 
      ex2_memctrl          => ex2_memctrl, 
      ex3_memctrl          => ex3_memctrl, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      dma_spu_timing_on    => dma_spu_timing_on,   
      dma_spu_timing_value => dma_spu_timing_value,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(4 downto 0),      
      SS_wren              => SS_wren(7),     
      SS_rden              => SS_rden(7),     
      SS_DataRead          => SS_DataRead_MEMORY      
   );

   -- Gun coordinate mapping is toplevel so that the gun's
   -- coordinates can be passed to both joypad
   -- and GPU (for crosshair overlays)
   Gun1X <= to_unsigned(to_integer(joypad1.Analog1X + 128), 8);
   Gun2X <= to_unsigned(to_integer(joypad2.Analog1X + 128), 8);

   Gun1Y <= to_unsigned(to_integer(joypad1.Analog1Y + 128), 8);
   Gun2Y <= to_unsigned(to_integer(joypad2.Analog1Y + 128), 8);

   Gun1AimOffscreen <= '1' when Gun1X = x"00" or Gun1X = x"FF" or Gun1Y = x"00" or Gun1Y = x"FF" else '0';
   Gun2AimOffscreen <= '1' when Gun2X = x"00" or Gun2X = x"FF" or Gun2Y = x"00" or Gun2Y = x"FF" else '0';

   Gun1offscreen <= '1' when (Gun1AimOffscreen = '1' or joypad1.KeyTriangle = '1') else '0';
   Gun2offscreen <= '1' when (Gun2AimOffscreen = '1' or joypad2.KeyTriangle = '1') else '0';

   Gun1CrosshairOn <= '1' when
                      showGunCrosshairs = '1' and
                      (joypad1.PadPortGunCon = '1' or joypad1.PadPortJustif = '1') and
                      Gun1AimOffscreen = '0'
                   else '0';
   Gun2CrosshairOn <= '1' when
                      showGunCrosshairs = '1' and
                      (joypad2.PadPortGunCon = '1' or joypad2.PadPortJustif = '1') and
                      Gun2AimOffscreen = '0'
                   else '0';

   -- Map the gun's Y coordinate to 240 scanlines
   Gun1Y_scanlines <= resize(Gun1Y, 9) - resize(Gun1Y(7 downto 4), 9); -- Gun1Y * 240 / 256
   Gun2Y_scanlines <= resize(Gun2Y, 9) - resize(Gun2Y(7 downto 4), 9); -- Gun1Y * 240 / 256

   ijoypad: entity work.joypad
   port map 
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => ce,   
      reset                => reset_intern,

      isPal                => isPal, -- passed through for GunCon
      
      DSAltSwitchMode      => DSAltSwitchMode,
      joypad1              => joypad1,
      joypad2              => joypad2,
      joypad3              => joypad3,
      joypad4              => joypad4,
      multitap             => multitap,
      multitapDigital      => multitapDigital,
      multitapAnalog       => multitapAnalog,
			neGconRumble         => neGconRumble,
      joypad1_rumble       => joypad1_rumble,
      joypad2_rumble       => joypad2_rumble,
      joypad3_rumble       => joypad3_rumble,
      joypad4_rumble       => joypad4_rumble,
      padMode              => padMode,

      -- build #141: ZN-1 arcade has no memory cards; force "not available"
      -- so joypad never tries to enter memcard-protocol responses on SIO0
      -- (which would otherwise contend with CAT702's reuse of the same bus).
      memcard1_available   => '0',
      memcard2_available   => '0',
      
      irqRequest           => irq_PAD_joy,

      MouseEvent           => MouseEvent,
      MouseLeft            => MouseLeft,
      MouseRight           => MouseRight,
      MouseX               => MouseX,
      MouseY               => MouseY,
      Gun1X                => Gun1X,
      Gun2X                => Gun2X,
      Gun1Y_scanlines      => Gun1Y_scanlines,
      Gun2Y_scanlines      => Gun2Y_scanlines,
      Gun1AimOffscreen     => Gun1AimOffscreen,
      Gun2AimOffscreen     => Gun2AimOffscreen,
      JustifierIrqEnable   => JustifierIrqEnable,
      
      snacPort1_in         => '0',              -- ZN: security uses port 2 (JOY_CTRL bit13=1)
      snacPort2_in         => '1',              -- ZN: always enable SNAC port 2
      selectedPort1Snac    => selectedPort1Snac,
      selectedPort2Snac    => zn_sel_p2,
      transmitValueSnac    => zn_txbyte,        -- internal; exposed via port below
      clk9Snac             => clk9Snac,
      receiveBufferSnac    => zn_rxbyte,        -- driven by zn_sio
      beginTransferSnac    => zn_beginTransfer, -- internal; exposed via port below
      joyBaudSnac          => zn_joy_baud,      -- task #285: baud → zn_sio latency scaling
      actionNextSnac       => zn_action_next,   -- driven by zn_sio
      receiveValidSnac     => zn_receive_valid, -- driven by zn_sio
      ackSnac              => zn_ack,           -- driven by zn_sio
      snacMC               => '1',              -- ZN: prevent snacMCEN disable on 0x81
      
      mem1_request         => memDDR3card1_request,   
      mem1_BURSTCNT        => memDDR3card1_BURSTCNT,  
      mem1_ADDR            => memDDR3card1_ADDR,      
      mem1_DIN             => memDDR3card1_DIN,       
      mem1_BE              => memDDR3card1_BE,        
      mem1_WE              => memDDR3card1_WE,        
      mem1_RD              => memDDR3card1_RD,       
      mem1_ack             => memDDR3card1_ack,       
      
      mem2_request         => memDDR3card2_request,   
      mem2_BURSTCNT        => memDDR3card2_BURSTCNT,  
      mem2_ADDR            => memDDR3card2_ADDR,      
      mem2_DIN             => memDDR3card2_DIN,       
      mem2_BE              => memDDR3card2_BE,        
      mem2_WE              => memDDR3card2_WE,        
      mem2_RD              => memDDR3card2_RD,       
      mem2_ack             => memDDR3card2_ack,  
      
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
      
      bus_addr             => bus_pad_addr,     
      bus_dataWrite        => bus_pad_dataWrite,
      bus_read             => bus_pad_read,     
      bus_write            => bus_pad_write,    
      bus_writeMask        => bus_pad_writeMask,   
      bus_dataRead         => bus_pad_dataRead,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),      
      SS_wren              => SS_wren(5),     
      SS_rden              => SS_rden(5),     
      SS_DataRead          => SS_DataRead_JOYPAD,
      SS_idle              => SS_idle_pad
   );
   
   icheats : entity work.cheats
   port map
   (
      clk1x          => clk1x,
      ce             => ce,
      reset          => reset_intern,

      dmaOn          => dmaOn,

      cheat_clear    => cheat_clear,
      cheats_enabled => cheats_enabled,
      cheat_on       => cheat_on,
      cheat_in       => cheat_in,
      cheats_active  => cheats_active,

      vsync          => IRQ_VBlank,

      --bus_ena_in     => mem_bus_ena,

      BusAddr        => Cheats_BusAddr,
      BusRnW         => Cheats_BusRnW,
      BusByteEnable  => Cheats_BusByteEnable,
      BusWriteData   => Cheats_BusWriteData,
      Bus_ena        => Cheats_Bus_ena,
      BusReadData    => Cheats_BusReadData,
      BusDone        => Cheats_BusDone
   );

   -- build #142: ZN-1 arcade — SIO1 (PSX link cable @ 0x1F801050) removed.
   -- Arcade boards have no link cable. Stub bus + savestate outputs.
   bus_sio_dataRead  <= (others => '0');
   SS_DataRead_SIO   <= (others => '0');
   
   irq_SIO       <= '0'; -- todo
   irq_LIGHTPEN  <= '1' when
                    (irq10Snac = '1' and snacport1 = '1') or
                    (irq10Snac = '1' and snacport2 = '1') or
                    (Gun1IRQ10 = '1' and joypad1.PadPortJustif = '1' and JustifierIrqEnable(0) = '1') or
                    (Gun2IRQ10 = '1' and joypad2.PadPortJustif = '1' and JustifierIrqEnable(1) = '1')
                 else '0';

   iirq : entity work.irq
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,     
      irq_CDROM            => irq_CDROM,   
      irq_DMA              => irq_DMA,     
      irq_TIMER0           => irq_TIMER0,  
      irq_TIMER1           => irq_TIMER1,  
      irq_TIMER2           => irq_TIMER2,  
      irq_PAD              => irq_PAD,     
      irq_SIO              => irq_SIO,     
      irq_SPU              => irq_SPU,     
      irq_LIGHTPEN         => irq_LIGHTPEN,
      
      bus_addr             => bus_irq_addr,     
      bus_dataWrite        => bus_irq_dataWrite,
      bus_read             => bus_irq_read,     
      bus_write            => bus_irq_write,    
      bus_dataRead         => bus_irq_dataRead,
      
      irqRequest           => irqRequest,

      export_irq           => dbg_istat_live,   -- B-inst4: live I_STAT (synthesized; sim alias below)
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(0 downto 0),      
      SS_wren              => SS_wren(10),     
      SS_rden              => SS_rden(10),     
      SS_DataRead          => SS_DataRead_IRQ,
      SS_idle              => SS_idle_irq
   );
   
   ignoreDMACDTiming <= '1' when (TURBO_MEM = '1' or IGNORECDDMATIMING = '1' or unsigned(FORCECDSPEED) >= 3) else '0';
   
   idma : entity work.dma
   port map
   (
      clk1x                => clk1x,
      clk3x                => clk3x,
      clk3xIndex           => clk3xIndex,
      ce                   => ce,   
      reset                => reset_intern,
      
      errorCHOP            => errorCHOP, 
      errorDMACPU          => errorDMACPU, 
      errorDMAFIFO         => errorDMAFIFO, 
      
      TURBO                => TURBO_COMP,
      TURBO_CACHE          => TURBO_CACHE,
      ram8mb               => ram8mb,
      ignoreCDTiming       => ignoreDMACDTiming,
      
      canDMA               => canDMA,
      cpuPaused            => cpuPaused,
      dmaRequest           => dmaRequest,
      dmaStallCPU          => dmaStallCPU,
      dmaOn                => dmaOn,
      irqOut               => irq_DMA,
      
      ram_Adr              => ram_dma_Adr,  
      ram_cnt              => ram_cntDMA,  
      ram_ena              => ram_dma_ena,
      
      dma_wr               => dma_wr, 
      dma_reqprocessed     => dma_reqprocessed,      
      dma_data             => dma_data,
      
      ram_dmafifo_adr      => ram_dmafifo_adr, 
      ram_dmafifo_data     => ram_dmafifo_data,
      ram_dmafifo_empty    => ram_dmafifo_empty,
      ram_dmafifo_read     => ram_dmafifo_read, 

      dma_cache_Adr        => dma_cache_Adr,  
      dma_cache_data       => dma_cache_data, 
      dma_cache_write      => dma_cache_write,      
      
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,   
      
      mdec_dmaWriteRequest => mdec_dmaWriteRequest,
      mdec_dmaReadRequest  => mdec_dmaReadRequest, 
      DMA_MDEC_writeEna    => DMA_MDEC_writeEna,   
      DMA_MDEC_readEna     => DMA_MDEC_readEna,    
      DMA_MDEC_write       => DMA_MDEC_write,      
      DMA_MDEC_read        => DMA_MDEC_read,   

      cd_memctrl           => cd_memctrl,
      com0_delay           => com0_delay,
      DMA_CD_readEna       => DMA_CD_readEna,
      DMA_CD_read          => DMA_CD_read,   
      
      spu_timing_on        => dma_spu_timing_on,   
      spu_timing_value     => dma_spu_timing_value,
      spu_dmaRequest       => spu_dmaRequest, 
      DMA_SPU_writeEna     => DMA_SPU_writeEna,   
      DMA_SPU_readEna      => DMA_SPU_readEna,    
      DMA_SPU_write        => DMA_SPU_write,    
      DMA_SPU_read         => DMA_SPU_read,
      
      bus_addr             => bus_dma_addr,     
      bus_dataWrite        => bus_dma_dataWrite,
      bus_read             => bus_dma_read,     
      bus_write            => bus_dma_write,    
      bus_dataRead         => bus_dma_dataRead,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),      
      SS_wren              => SS_wren(3),     
      SS_rden              => SS_rden(3),     
      SS_DataRead          => SS_DataRead_DMA,
      SS_idle              => SS_idle_dma
   );
   
   ram_refresh   <= reset_intern;
   
   ram_dataWrite <=                                                ram_cpu_dataWrite;
   ram_be        <=                                                ram_cpu_be;       
   ram_rnw       <= '1'                when (cpuPaused = '1') else ram_cpu_rnw;      
   ram_ena       <= ram_dma_ena        when (cpuPaused = '1') else ram_cpu_ena;      
   ram_dma       <= '1'                when (cpuPaused = '1') else '0';      
   ram_cache     <= '0'                when (cpuPaused = '1') else ram_cpu_cache;    
   
   ram_Adr       <=   "0000" & ram_dma_Adr(22 downto 0) when (cpuPaused = '1' and ram8mb = '1') else
                    "000000" & ram_dma_Adr(20 downto 0) when (cpuPaused = '1' and ram8mb = '0') else
                    ram_cpu_Adr(26 downto 0)                                    when (ram8mb = '1') else
                    ram_cpu_Adr(26 downto 23) & "00" & ram_cpu_Adr(20 downto 0);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (ram_ena = '1') then
            ram_next_cpu <= '0';
            if (cpuPaused = '0') then
               ram_next_cpu <= '1';
            end if;
         end if;
      
      end if;
   end process;
   
   ram_cpu_done <= ram_done and ram_next_cpu;
   
   itimer : entity work.timer
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      error                => errorTimer,
      
      dotclock             => dotclock,
      hblank               => hblank_tmr,
      vblank               => vblank_tmr,
      
      irqRequest0          => irq_TIMER0,
      irqRequest1          => irq_TIMER1,
      irqRequest2          => irq_TIMER2,
      
      bus_addr             => bus_tmr_addr,     
      bus_dataWrite        => bus_tmr_dataWrite,
      bus_read             => bus_tmr_read,     
      bus_write            => bus_tmr_write,       
      bus_dataRead         => bus_tmr_dataRead,
      
-- synthesis translate_off
      export_t_current0    => export_t_current0,
      export_t_current1    => export_t_current1,
      export_t_current2    => export_t_current2,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(3 downto 0),      
      SS_wren              => SS_wren(8),     
      SS_rden              => SS_rden(8),     
      SS_DataRead          => SS_DataRead_TIMER
   );
   
   -- build #25: stub out cd_top for ZN-1. ZN-1 arcades don't use CD-ROM (data via
   -- banked ROM at 0x1FB00006). The PSX_MiSTer-derived cd_top entity was a latent
   -- bug source (irq_CDROM, resetFromCD, DMA ch3 could spuriously fire) and consumed
   -- ~10-15% of ALMs. Replace with cd_top_zn1stub which drives all outputs inactive.
   icd_top : entity work.cd_top_zn1stub
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,
      reset                => reset_intern,
     
      INSTANTSEEK          => INSTANTSEEK,
      FORCECDSPEED         => FORCECDSPEED,
      LIMITREADSPEED       => LIMITREADSPEED,
      hasCD                => hasCD,
      fastCD               => fastCD,
      testSeek             => testSeek,
      pauseOnCDSlow        => pauseOnCDSlow,
      LIDopen              => LIDopen,
      region               => region,
      region_out           => region_out,	  
      
      pauseCD              => pauseCD,
      Pause_idle_cd        => Pause_idle_cd,
      cdSlow               => cdSlow,
      error                => errorCD,
      LBAdisplay           => LBAdisplay,
          
      irqOut               => irq_CDROM,
      
      spu_tick             => spu_tick,
      cd_left              => cd_left,
      cd_right             => cd_right,
      
      mdec_idle            => SS_Idle_mdec,
                            
      bus_addr             => bus_cd_addr,     
      bus_dataWrite        => bus_cd_dataWrite,
      bus_read             => bus_cd_read,     
      bus_write            => bus_cd_write,     
      bus_dataRead         => bus_cd_dataRead,
                            
      dma_read             => DMA_CD_readEna,
      dma_readdata         => DMA_CD_read,
      
      cd_hps_req           => cd_hps_req,  
      cd_hps_lba           => cd_hps_lba,
      cd_hps_lba_sim       => cd_hps_lba_sim,
      cd_hps_ack           => cd_hps_ack,
      cd_hps_write         => cd_hps_write,
      cd_hps_data          => cd_hps_data, 
      
      trackinfo_data       => trackinfo_data,
      trackinfo_addr       => trackinfo_addr, 
      trackinfo_write      => trackinfo_write,
      resetFromCD          => resetFromCD,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(13 downto 0),      
      SS_wren              => SS_wren(13),     
      SS_rden              => SS_rden(13),     
      SS_DataRead          => SS_DataRead_CD,
      SS_Idle              => SS_Idle_cd
   );

   cdslowEna <= cdSlow and cdslowOn;

   igpu : entity work.gpu
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      clkvid               => clkvid,
      ce                   => ce,   
      reset                => reset_intern,
      
      allowunpause         => allowunpause,
      savestate_busy       => savestate_busy,
      system_paused        => pausing,
      
      ditherOff            => ditherOff,
      interlaced480pHack   => interlaced480pHack,
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,
      videoout_on          => videoout_on,
      isPal                => isPal,
      pal60                => pal60,
      fpscountOn           => fpscountOn,
      noTexture            => noTexture,
      textureFilter        => textureFilter,
      textureFilterStrength=> textureFilterStrength,
      textureFilter2DOff   => textureFilter2DOff,
      dither24             => dither24,
      render24             => render24,
      drawSlow             => drawSlow,
      debugmodeOn          => debugmodeOn,
      syncVideoOut         => syncVideoOut,
      syncInterlace        => syncInterlace,
      rotate180            => rotate180,
      fixedVBlank          => fixedVBlank,
      vCrop                => vCrop,   
      hCrop                => hCrop,   
      
	  oldGPU               => oldGPU,
	  
      Gun1CrosshairOn      => Gun1CrosshairOn,
      Gun1X                => Gun1X,
      Gun1Y_scanlines      => Gun1Y_scanlines,
      Gun1offscreen        => Gun1offscreen,
      Gun1IRQ10            => Gun1IRQ10,

      Gun2CrosshairOn      => Gun2CrosshairOn,
      Gun2X                => Gun2X,
      Gun2Y_scanlines      => Gun2Y_scanlines,
      Gun2offscreen        => Gun2offscreen,
      Gun2IRQ10            => Gun2IRQ10,

      cdSlow               => cdslowEna,
      
      errorOn              => errorOn,  
      errorEna             => errorEna, 
      errorCode            => errorCode,
      
      LBAOn                => LBAOn,
      LBAdisplay           => LBAdisplay,
      
      errorLINE            => errorLINE,
      errorRECT            => errorRECT,
      errorPOLY            => errorPOLY,
      errorGPU             => errorGPU, 
      errorMASK            => errorMASK, 
      errorFIFO            => errorGPUFIFO,
      
      bus_addr             => bus_gpu_addr,     
      bus_dataWrite        => bus_gpu_dataWrite,
      bus_read             => bus_gpu_read,     
      bus_write            => bus_gpu_write,    
      bus_dataRead         => bus_gpu_dataRead, 
      bus_stall            => bus_gpu_stall, 
      
      dmaOn                => dmaOn,
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,  
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,
      gpustat31_out        => gpustat31_sig,  -- build #169
      drawingAreaBottom_out => drawingAreaBottom_sig,  -- build #172
      drawingOffsetY_out    => drawingOffsetY_sig,     -- build #172

      vram_pause           => vram_pause,
      vram_paused          => vram_paused,
      vram_BUSY            => ddr3_BUSY,       
      vram_DOUT            => ddr3_DOUT,       
      vram_DOUT_READY      => ddr3_DOUT_READY,
      vram_BURSTCNT        => vram_BURSTCNT,  
      vram_ADDR            => vram_ADDR,      
      vram_DIN             => vram_DIN,       
      vram_BE              => vram_BE,        
      vram_WE              => vram_WE,        
      vram_RD              => vram_RD, 

      hblank_tmr           => hblank_tmr,
      vblank_tmr           => vblank_tmr,
      dotclock             => dotclock,
      
      video_hsync          => hsync, 
      video_vsync          => vsync, 
      video_hblank         => hblank,
      video_vblank         => vblank,
      video_DisplayWidth   => DisplayWidth, 
      video_DisplayHeight  => DisplayHeight,
      video_DisplayOffsetX => DisplayOffsetX,
      video_DisplayOffsetY => DisplayOffsetY,
      video_ce             => video_ce,
      video_interlace      => video_interlace,
      video_r              => video_r, 
      video_g              => video_g, 
      video_b              => video_b, 
      video_isPal          => video_isPal, 
      video_fbmode         => video_fbmode, 
      video_fb24           => video_fb24, 
      video_hResMode       => video_hResMode, 
      video_frameindex     => video_frameindex,
      
-- synthesis translate_off
      export_gtm           => export_gtm,
      export_line          => export_line,
      export_gpus          => export_gpus,
      export_gobj          => export_gobj,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),
      SS_wren_GPU          => SS_wren(1),     
      SS_wren_Timing       => SS_wren(2),      
      SS_rden_GPU          => SS_rden(1),     
      SS_rden_Timing       => SS_rden(2),
      SS_DataRead_GPU      => SS_DataRead_GPU,
      SS_DataRead_Timing   => SS_DataRead_GPUTiming,
      SS_Idle              => SS_Idle_gpu,
      dbg_pipeline_pixelWrite => dbg_pipeline_pixelWrite,
      dbg_pipeline_write_in_top => dbg_pipeline_write_in_top,
      dbg_vram_WE              => dbg_vram_WE_tap,
      dbg_pipeline_color_varied => dbg_pipeline_color_varied,
      dbg_vram_din_non_navy    => dbg_vram_din_non_navy,
      dbg_vram_dout_nonnavy           => dbg_vram_dout_nonnavy,
      dbg_videoout_linebuf_nonnavy    => dbg_videoout_linebuf_nonnavy,
      dbg_videoout_pixeldata_nonnavy  => dbg_videoout_pixeldata_nonnavy,
      dbg_rast_display_nonnavy        => dbg_rast_display_nonnavy,
      dbg_rast_offdisp_nonnavy        => dbg_rast_offdisp_nonnavy,
      dbg_vramdin_display_nonnavy     => dbg_vramdin_display_nonnavy,
      dbg_clut_write_nonnavy          => dbg_clut_write_nonnavy,
      dbg_clut_read_nonnavy           => dbg_clut_read_nonnavy,
      dbg_stage4_texture              => dbg_stage4_texture,
      dbg_textPalNew                  => dbg_textPalNew,
      dbg_textPalReq_set              => dbg_textPalReq_set,
      dbg_state_REQ_PAL               => dbg_state_REQ_PAL,
      dbg_CLUTwrenA_any               => dbg_CLUTwrenA_any,
      dbg_drawMode_8                  => dbg_drawMode_8,
      dbg_noTexture_pin               => dbg_noTexture_pin,
      dbg_cpu2vram_pixelWrite         => dbg_cpu2vram_pixelWrite,
      dbg_cpu2vram_color_nonnavy      => dbg_cpu2vram_color_nonnavy,
      dbg_textPalReqX_nonzero         => dbg_textPalReqX_nz,
      dbg_textPalReqY_nonzero         => dbg_textPalReqY_nz,
      dbg_cpu2vram_dstY_bit8_LATCHED_src => dbg_cpu2vram_dstY_bit8,
      dbg_cpu2vram_dstY_nonzero       => dbg_cpu2vram_dstY_nz,
      dbg_cpu2vram_dstX_zero          => dbg_cpu2vram_dstX_zero,
      dbg_cpu2vram_dstX_nonzero       => dbg_cpu2vram_dstX_nz,
      dbg_vram_we_x_zero              => dbg_vram_we_x_zero,
      dbg_vram_we_x_zero_nonnavy      => dbg_vram_we_x_zero_nv,
      dbg_vram2vram_active            => dbg_vram2vram_active,
      dbg_vramFill_active             => dbg_vramFill_active,
      dbg_pixelAddr_Y_hi              => dbg_pixelAddr_Y_hi,
      dbg_cpu2vram_Y_hi               => dbg_cpu2vram_Y_hi,
      dbg_vram_addr_Y_hi_we           => dbg_vram_addr_Y_hi_we,
      dbg_vram_addr_Y_hi_rd           => dbg_vram_addr_Y_hi_rd,
      -- build #19: lpadv-tuned
      dbg_textPalReqX_ge_256          => dbg_textPalReqX_ge_256,
      dbg_textPalReqX_hi              => dbg_textPalReqX_hi,
      dbg_cpu2vram_dstX_hi            => dbg_cpu2vram_dstX_hi,
      dbg_cpu2vram_parsed_dstX_hi     => dbg_cpu2vram_parsed_dstX_hi,
      dbg_pipeline_g_set              => dbg_pipeline_g_set,
      dbg_pipeline_b_set              => dbg_pipeline_b_set,
      dbg_vram_din_gb                 => dbg_vram_din_gb,
      dbg_cpu2vram_color_gb           => dbg_cpu2vram_color_gb,
      dbg_rect_tex_4bit               => dbg_rect_tex_4bit,
      dbg_rect_tex_8bit               => dbg_rect_tex_8bit,
      dbg_rect_tex_15bit              => dbg_rect_tex_15bit,
      dbg_rect_tex_pixel_gb           => dbg_rect_tex_pixel_gb,
      -- build #26
      dbg_cubeclut_gb                 => dbg_cubeclut_gb,
      dbg_cubeclut_ronly              => dbg_cubeclut_ronly,
      dbg_loclut_gb                   => dbg_loclut_gb,
      -- build #57
      dbg_stage4_texraw_nz            => dbg_stage4_texraw_nz,
      -- build #63
      dbg_textPalReqY_clut            => dbg_textPalReqY_clut,
      -- build #67
      dbg_last_succ_palX              => dbg_last_succ_palX,
      dbg_last_succ_palY              => dbg_last_succ_palY,
      -- build #68
      dbg_textPalReqY_lo              => dbg_textPalReqY_lo,
      dbg_textPalReqY_hi              => dbg_textPalReqY_hi,
      -- build #82
      dbg_b82_byte_redslot            => dbg_b82_byte_redslot,
      dbg_b82_byte_greenslot          => dbg_b82_byte_greenslot,
      dbg_b82_captured                => dbg_b82_captured,
      -- build #39: Tecmo bank register state for upstream-data forensic
      bank_8mb_in                     => zn_bank_8mb_dbg,
      -- build #114 H1+H2: cube rect path investigation
      dbg_h12_red_anchor              => h12_red_anchor_sig,
      dbg_h12_green_dm_ok             => h12_green_dm_ok_sig,
      dbg_h12_blue_dm_stale           => h12_blue_dm_stale_sig,
      dbg_h12_yellow_busy0            => h12_yellow_busy0_sig,
      dbg_h12_white_dm_chg            => h12_white_dm_chg_sig,
      dbg_h12_cyan_emit_busy0         => h12_cyan_emit_busy0_sig,
      dbg_h12_magenta_busy_long       => h12_magenta_busy_long_sig,
      -- build #115: H1 race-frequency counters
      dbg_h12_stale_count_hi          => h12_stale_count_hi_sig,
      dbg_h12_ok_count_hi             => h12_ok_count_hi_sig,
      dbg_h12_stale_gt_ok             => h12_stale_gt_ok_sig,
      -- build #117: G+B stripping locator
      dbg_h17_anchor                  => h17_anchor_sig,
      dbg_h17_g_set                   => h17_g_sig,
      dbg_h17_b_set                   => h17_b_sig,
      -- build #119: vram_DIN G+B locator
      dbg_h19_anchor                  => h19_anchor_sig,
      dbg_h19_g_in_din                => h19_g_sig,
      dbg_h19_b_in_din                => h19_b_sig,
      -- build #120: counter-based G+B prevalence
      dbg_h20_anchor_count_hi         => h20_anchor_count_hi_sig,
      dbg_h20_g_count_hi              => h20_g_count_hi_sig,
      dbg_h20_b_count_hi              => h20_b_count_hi_sig,
      -- build #122: vram_DOUT capture at hi-Y CLUT[3]
      dbg_h22_anchor                  => h22_anchor_sig,
      dbg_h22_clut3_r                 => h22_clut3_r_sig,
      dbg_h22_clut3_g                 => h22_clut3_g_sig,
      -- build #124: SDRAM round-trip self-test
      dbg_h24_write_r                 => h24_write_r_sig,
      dbg_h24_read_r                  => h24_read_r_sig,
      dbg_h24_both_anchors            => h24_both_anchors_sig,
      -- build #128: cpu2vram vs vram_DIN comparison
      dbg_h28_cpu_r                   => h28_cpu_r_sig,
      dbg_h28_vram_r                  => h28_vram_r_sig,
      dbg_h28_both_anchors            => h28_both_anchors_sig,
      -- build #129: Tecmo bank verification
      dbg_h29_bank                    => h29_bank_sig,
      dbg_h29_bank_anchor             => h29_bank_anchor_sig,
      dbg_h29_bank_ever_changed       => h29_bank_ever_changed_sig,
      -- build #131: DMA delivery instrumentation
      dbg_h31_pixel1_r                => h31_pixel1_r_sig,
      dbg_h31_pixel2_r                => h31_pixel2_r_sig,
      dbg_h31_rich_ever               => h31_rich_ever_sig,
      -- build #132: DMA R-value sticky detectors
      dbg_h32_r31_ever                => h32_r31_ever_sig,
      dbg_h32_r_high_ever             => h32_r_high_ever_sig,
      dbg_h32_pixel1_nonzero_ever     => h32_pixel1_nonzero_ever_sig,
      -- build #133: fifo_data_1 vs cpu2vram_pixelColor at cube CLUT lane-3
      dbg_h33_fifo_data_1_r           => h33_fifo_data_1_r_sig,
      dbg_h33_cpu_color_r             => h33_cpu_color_r_sig,
      dbg_h33_anchor                  => h33_anchor_sig,
      dbg_h33_r31_ever                => h33_r31_ever_sig,
      -- build #134: fifoIn_Dout halfword R bits stickys
      dbg_h34_lower_r31_ever          => h34_lower_r31_ever_sig,
      dbg_h34_upper_r31_ever          => h34_upper_r31_ever_sig,
      dbg_h34_upper_msb_ever          => h34_upper_msb_ever_sig,
      -- build #137: cpu2vram FSM latch-chain probes
      dbg_h37_input_r31_ever          => h37_input_r31_ever_sig,
      dbg_h37_writing_r31_ever        => h37_writing_r31_ever_sig,
      dbg_h37_latch_r31_ever          => h37_latch_r31_ever_sig,
      -- build #138: cube-CLUT-specific lane probes
      dbg_h38_lane2_input_r31_ever    => h38_lane2_input_r31_ever_sig,
      dbg_h38_lane3_latch_r31_ever    => h38_lane3_latch_r31_ever_sig,
      dbg_h38_lane3_anchor_ever       => h38_lane3_anchor_ever_sig,
      -- build #139: cube-shape Y observability probes
      dbg_h39_cubeshape_any_ever      => h39_cubeshape_any_ever_sig,
      dbg_h39_cubeshape_y482_ever     => h39_cubeshape_y482_ever_sig,
      dbg_h39_cubeshape_y488_ever     => h39_cubeshape_y488_ever_sig,
      -- build #140: CLUT-RAM cube CLUT presence probes
      dbg_h40_cube_clut_loaded_ever   => h40_cube_clut_loaded_ever_sig,
      dbg_h40_clut_read_7fff_ever     => h40_clut_read_7fff_ever_sig,
      dbg_h40_clut_read_023f_ever     => h40_clut_read_023f_ever_sig,
      -- build #158: H4 cache-staleness probes
      dbg_h58_x_stale_seen            => h58_x_stale_seen_sig,
      dbg_h58_y_stale_seen            => h58_y_stale_seen_sig,
      dbg_h58_pixel_seen              => h58_pixel_seen_sig,
      -- build #159: H7 CLUT load capture
      dbg_h59_loaded_entry0_lo        => h59_loaded_entry0_lo_sig,
      dbg_h59_loaded_y                => h59_loaded_y_sig,
      dbg_h59_anchor                  => h59_anchor_sig,
      -- build #145: Y=482/480 pixelWrite probes
      dbg_h45_y482_anchor   => h45_y482_anchor_sig,
      dbg_h45_y482_pixwrite => h45_y482_pixwrite_sig,
      dbg_h45_y480_pixwrite => h45_y480_pixwrite_sig,
      -- build #146-149: cpu2vram value-capture probes
      dbg_h46_y_minus_240   => h46_y_minus_240_sig,
      dbg_h46_y_high_bit    => h46_y_high_bit_sig,
      dbg_h46_anchor        => h46_anchor_sig,
      dbg_h49_entry1_low    => h49_entry1_low_sig
   );

   -- build #142: ZN-1 arcade — MDEC (MPEG decoder @ 0x1F801820) removed.
   -- Arcade games (aerofgts/hvnsgate/lpadv/doapp/etc.) don't use FMV cutscenes,
   -- so MDEC + its DMA0 (in) / DMA1 (out) channels are unused. Stub all outputs
   -- to inert values so DMA arbiter never sees an MDEC request and savestate
   -- machinery sees MDEC as permanently idle.
   bus_mdec_dataRead    <= (others => '0');
   mdec_dmaWriteRequest <= '0';
   mdec_dmaReadRequest  <= '0';
   DMA_MDEC_read        <= (others => '0');
   SS_DataRead_MDEC     <= (others => '0');
   SS_Idle_mdec         <= '1';

   ispu : entity work.spu
   port map
   (
      clk1x                => clk1x,   
      clk2x                => clk2x,    
      clk2xIndex           => clk2xIndex,      
      ce                   => ce,        
      reset                => reset_intern,     
      
      SPUon                => SPUon,
      SPUIRQTrigger        => SPUIRQTrigger,
      useSDRAM             => SPUSDRAM,
      REPRODUCIBLESPUIRQ   => '1',
      REPRODUCIBLESPUDMA   => REPRODUCIBLESPUDMA,
      REVERBOFF            => REVERBOFF,
      
      cpuPaused            => cpuPaused,
      
      spu_tick             => spu_tick,
      cd_left              => cd_left,
      cd_right             => cd_right,
      
      irqOut               => irq_SPU,
      
      sound_timeout        => errorSPUTIME,
      
      sound_out_left       => sound_out_left, 
      sound_out_right      => sound_out_right,
      
      bus_addr             => bus_spu_addr,     
      bus_dataWrite        => bus_spu_dataWrite,
      bus_read             => bus_spu_read,     
      bus_write            => bus_spu_write,    
      bus_dataRead         => bus_spu_dataRead, 
      
      spu_dmaRequest       => spu_dmaRequest, 
      dma_read             => DMA_SPU_readEna,      
      dma_readdata         => DMA_SPU_read, 
      dma_write            => DMA_SPU_writeEna, 
      dma_writedata        => DMA_SPU_write,
          
      sdram_dataWrite      => spuram_dataWrite,
      sdram_dataRead       => spuram_dataRead, 
      sdram_Adr            => spuram_Adr,      
      sdram_be             => spuram_be,      
      sdram_rnw            => spuram_rnw,      
      sdram_ena            => spuram_ena,           
      sdram_done           => spuram_done,
      
      mem_request          => memSPU_request,  
      mem_BURSTCNT         => memSPU_BURSTCNT, 
      mem_ADDR             => memSPU_ADDR,     
      mem_DIN              => memSPU_DIN,      
      mem_BE               => memSPU_BE,       
      mem_WE               => memSPU_WE,       
      mem_RD               => memSPU_RD,       
      mem_ack              => memSPU_ack,      
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
      
      SS_reset             => SS_reset,
      loading_savestate    => loading_savestate,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(8 downto 0),  
      SS_wren              => SS_wren(9),     
      SS_rden              => SS_rden(9),     
      SS_DataRead          => SS_DataRead_SOUND,
      SS_idle              => SS_idle_spu,
      
      SS_RAM_dataWrite     => SS_SPURAM_dataWrite,
      SS_RAM_Adr           => SS_SPURAM_Adr,      
      SS_RAM_request       => SS_SPURAM_request,  
      SS_RAM_rnw           => SS_SPURAM_rnw,      
      SS_RAM_dataRead      => SS_SPURAM_dataRead, 
      SS_RAM_done          => SS_SPURAM_done     
   );
   
   iexp2 : entity work.exp2
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_exp2_addr,
      bus_dataWrite        => bus_exp2_dataWrite,
      bus_read             => bus_exp2_read,
      bus_write            => bus_exp2_write,
      bus_dataRead         => bus_exp2_dataRead
   );

   -- ZN-1 Arcade I/O register block
   izn1_io : entity work.zn1_io
   port map
   (
      clk          => clk1x,
      reset        => reset_intern,
      addr         => bus_znio_addr,
      data_write   => bus_znio_dataWrite,
      write_mask   => bus_znio_writeMask,
      read_en      => bus_znio_read,
      write_en     => bus_znio_write,
      data_read    => bus_znio_dataRead,
      p1_right     => zn_p1_right,
      p1_left      => zn_p1_left,
      p1_down      => zn_p1_down,
      p1_up        => zn_p1_up,
      p1_btn       => zn_p1_btn,
      p1_start     => zn_p1_start,
      p1_coin      => zn_p1_coin,
      p2_right     => zn_p2_right,
      p2_left      => zn_p2_left,
      p2_down      => zn_p2_down,
      p2_up        => zn_p2_up,
      p2_btn       => zn_p2_btn,
      p2_start     => zn_p2_start,
      p2_coin      => zn_p2_coin,
      service      => zn_service,  -- B126 hack reverted: service=1 didn't help, real bug is elsewhere
      test_mode    => zn_test_mode,
      zn_platform  => zn_platform,
      sec_select   => zn_sec_select,
      coin_out     => zn_coin_out,
      ee_dl_wr     => zn_ee_dl_wr,
      ee_dl_addr   => zn_ee_dl_addr,
      ee_dl_data   => zn_ee_dl_data,
      ee_dl_be     => zn_ee_dl_be,
      dbg_ee_word0 => dbg_ee_word0_sig,
      dbg_ee_stat  => dbg_ee_stat_sig
   );

   -- ZN-1 SIO0 Security Adapter (CAT702 A/B + ZNMCU over SNAC byte interface)
   izn_sio : entity work.zn_sio
   port map
   (
      clk           => clk1x,
      reset         => reset_intern,
      beginTransfer => zn_beginTransfer,
      txbyte        => zn_txbyte,
      rxbyte        => zn_rxbyte,
      action_next   => zn_action_next,
      receive_valid => zn_receive_valid,
      ack           => zn_ack,
      chip_sel      => zn_sel_p2,
      sec_select    => zn_sec_select,
      cat702_key    => zn_cat702_key,
      cat702_key_b  => zn_cat702_key_b,
      dsw           => zn_dsw,
      coin1         => zn_p1_coin,
      coin2         => zn_p2_coin,
      service       => zn_service,
      frame_tick    => irq_VBLANK,
      -- build #119
      dbg_first_kn01_rx => dbg_first_kn01_rx,
      dbg_first_kn02_rx => dbg_first_kn02_rx,
      dbg_kn02_ever     => dbg_kn02_ever,
      -- build #157
      dbg_b157_byte0    => b157_byte0_sig,
      dbg_b157_byte3    => b157_byte3_sig,
      dbg_b157_anchor   => b157_anchor_sig,
      -- PROPOSED FIX (Tecmo ZNMCU boot-hang): unsolicited DSR pulse output
      znmcu_irq         => zn_znmcu_irq,
      -- task #285: baud-scaled SNAC latency
      joy_baud          => zn_joy_baud
   );
   selectedPort2Snac <= zn_sel_p2;

   -- PROPOSED FIX (Tecmo ZNMCU boot-hang, e.g. mfjump): OR the ZNMCU's unsolicited
   -- DSR pulse into the PAD IRQ line. irq.vhd latches the rising edge into I_STATUS
   -- bit7 (the SIO0/controller IRQ). Only pulses when a game selects the ZNMCU
   -- (znsecsel=0x8C); titles that use the parallel input ports (doapp/lpadv) are
   -- unaffected. HW-accurate: MAME znmcu_device drives DSR on select the same way.
   irq_PAD <= irq_PAD_joy or zn_znmcu_irq;
   -- DIAGNOSTIC build #15: does ANY mechanism (cpu2vram/vram2vram/vramFill/rasterizer) write at VRAM X=0?
   -- Build #14: CPU2VRAM never writes X=0 (GREEN dark). But CLUT reads X=0. Maybe vram2vram or vramFill writes there?
   -- [0]=disp_ram_exec                      RED:     PER-FRAME — CPU executing (sanity)
   -- [1]=disp_vram_we_x_zero_ever           GREEN:   LATCHED  — ANY vram_WE at X=0 ever (any source)
   -- [2]=disp_vram_we_x_zero_nv_ever        BLUE:    LATCHED  — ANY non-navy write at X=0 ever
   -- [3]=disp_vram2vram_active_ever         YELLOW:  LATCHED  — vram2vram_pixelWrite ever fired
   -- [4]=disp_vramFill_active_ever          WHITE:   LATCHED  — vramFill_pixelWrite ever fired
   -- [5]=disp_clut_write_nv_ever            CYAN:    LATCHED  — CLUT non-navy ever (control)
   -- [6]=disp_vram_dout_nonnavy_b10         MAGENTA: LATCHED  — DDR3 non-navy read ever (control)
   --
   -- Decision tree:
   --   GREEN dark → ZERO writes ever to X=0 column → game uses palettes at X != 0 (CLUT-X parser bug?) OR truly no X=0 use
   --   GREEN bright, BLUE dark → writes at X=0 always navy → fill or fastclear hitting X=0 column
   --   BLUE bright → real data IS in VRAM at X=0 but CLUT still reads navy → DDR3 read/write inconsistency
   --   WHITE bright → vramFill is active → could be clearing X=0 column with navy → check fill destinations
   evt_ram_exec  <= '1' when (mem_request = '1' and mem_isData = '0' and
                              mem_addressInstr(28 downto 0) >= to_unsigned(16#40000#, 29) and
                              mem_addressInstr(28 downto 0) <  to_unsigned(16#800000#, 29)) else '0';
   -- BUILD #17: verify Y-wrap fix. GREEN/BLUE/YELLOW expected DARK after fix (no Y>=512 anywhere).
   -- build #24: frame-windowed textured-rect drawMode mode tracking. Reset each VBLANK so the
   -- bars reflect the LAST FRAME's activity, not history. Screenshots during red-rectangle
   -- phase will show what mode the cube rendering frame was using.
   -- build #26: cube-CLUT (X>=512) forensics. All sticky. X=768 is the ONLY CLUT at X>=512 in
   -- lpadv's entire stream (MAME log: CLUT X in {0,256,768}), so a sticky latch firing == the cubes.
   -- Decision table after a full attract run (let it reach + pass the cube screen ~20s in):
   --   BLUE dark              -> FPGA never requested the X=768 CLUT read  -> UPSTREAM (rect CLUT pointer wrong)
   --   RED  dark              -> FPGA never wrote VRAM at X>=512            -> UPSTREAM (0xA0 dst wrong)
   --   BLUE+WHITE (GREEN on)  -> cube CLUT read RED-ONLY, low-X reads fine  -> X>=512 VRAM storage bug (RTL-fixable)
   --   BLUE+YELLOW            -> cube CLUT read COLORFUL but still renders red -> bug downstream of CLUT
   -- build #44 (DECISIVE cube-palette color probe at cpu2vram dest X<256,Y=488; banking+MRA proven OK):
   -- build #114 H1+H2 bar wiring:
   --   [0] RED     = h12_red_anchor       — cube rect emit ever (sanity; if DARK, instrument never fired)
   --   [1] GREEN   = h12_green_dm_ok      — drawMode[3:0]=0xA/0xB at cube rect emit (expected E1 texpage)
   --   [2] BLUE    = h12_blue_dm_stale    — drawMode[3:0]!=0xA/0xB at cube rect emit → H1 CONFIRMED
   --   [3] YELLOW  = h12_yellow_busy0     — pipeline_busy='0' ever during cube period (H2 refuted if lit)
   --   [4] WHITE   = h12_white_dm_chg     — drawMode register changed during cube (E1 processing OK if lit)
   --   [5] CYAN    = h12_cyan_emit_busy0  — cube rect emit happened with pipeline_busy='0' same cycle
   --   [6] MAGENTA = h12_magenta_busy_long — pipeline_busy held high ≥4096 cycles during cube → H2 strong
   zn_debug_out <= h12_magenta_busy_long_sig
                 & h12_cyan_emit_busy0_sig
                 & h12_white_dm_chg_sig
                 & h12_yellow_busy0_sig
                 & h12_blue_dm_stale_sig
                 & h12_green_dm_ok_sig
                 & h12_red_anchor_sig;
   zn_debug_val <= dbg_palrd_value;   -- build #50: raw SDRAM word at green anchor
   zn_debug_addr <= dbg_palrd_addr;   -- build #51: computed SDRAM addr at green anchor
   -- build #82: direct-VRAM-read capture bars — replaces B80 triage with diagnostic latches.
   --   RED slot [17:9]    = vram_DOUT(31:24) at first hi-Y CLUTwrenA (Y=482 CLUTaddrA=0). Expected 0x7F.
   --   GREEN slot [72:64] = vram_DOUT(23:16) at same event. Expected 0xFF.
   --   BLUE slot [136:128] = captured flag (full lit if latch fired, dark if not).
   -- Display: each byte is rendered as a magnitude bar (value 0..255 of a 9-bit slot 0..511).
   -- Diagnostic outcomes:
   --   BLUE lit, RED half-lit, GREEN full → DDR3 returns correct data (0x7FFF) → bug downstream of vram_DOUT.
   --   BLUE lit, RED dark, GREEN dark → DDR3 returns zero → write-doesn't-commit (old hypothesis).
   --   BLUE lit, RED dark, GREEN ≈0x01 → DDR3 returns index pattern.
   --   BLUE dark → latch never triggered (Y=482 CLUT never loaded — filter too restrictive).
   latch_hi_y_fan <= (others => clut_succ_hi_seen);  -- legacy retained
   latch_lo_y_fan <= (others => clut_succ_lo_seen);
   -- B82 bar values: 8-bit byte zero-extended to 9 bits.
   -- build #134: probe fifoIn_Dout halfword R bits — localize where R=31 is lost.
   -- build #140 bars: CLUT-RAM cube CLUT presence probes (sticky-once-set)
   -- Probes the GPU's internal CLUT cache directly inside gpu_pixelpipeline.vhd.
   -- RED   = h40_cube_clut_loaded_ever — CLUTwrenA + CLUTaddrA=0 + vram_DOUT[31:16]=0x7FFF + vram_DOUT[47:32]=0x023F
   --         (cube CLUT word 0 loaded into dpram with the EXACT MAME-verified values)
   -- GREEN = h40_clut_read_7fff_ever   — any CLUTDataB lane ever = 0x7FFF (cube entry 1, white)
   -- BLUE  = h40_clut_read_023f_ever   — any CLUTDataB lane ever = 0x023F (cube entry 2, R=31 G=1 B=0)
   -- Outcome matrix:
   --   all 3 LIT          → cube CLUT IS in CLUT-RAM and IS read out → bug downstream of CLUT lookup
   --   R LIT, G+B DARK    → loaded but never read back → CLUT-RAM read path broken
   --   R DARK, G+B either → cube CLUT word 0 never loaded with correct values → upload corrupts data
   --   all 3 DARK         → CLUT-RAM never sees cube CLUT values — load path entirely broken
   -- DECISIVE:
   --   RED=LIT, GREEN=LIT → R=31 reaches FIFO output in both halfwords → bug is in cpu2vram latch step
   --   RED=LIT, GREEN=DARK → upper halfword loses R=31 between DMA and FIFO output
   --   RED=DARK, GREEN=LIT → lower halfword stripped (less likely)
   --   BOTH=DARK → fifoIn corrupts ALL R=31 (rare)
   --   GREEN=DARK, BLUE=LIT → upper halfword has R≥16 sometimes but never exactly 31
   -- build #145 bars:
   --   RED   = h45_y482_anchor    — state=WRITING + copyDstY=482 ever (must fire; sanity)
   --   GREEN = h45_y482_pixwrite  — pixelWrite at row=482 ever (does FSM emit cube row?)
   --   BLUE  = h45_y480_pixwrite  — pixelWrite at row=480 ever (positive control)
   -- Outcomes:
   --   R lit, G dark, B lit → FSM enters WRITING for Y=482 but never emits pixelWrite at row 482.
   --     Bug in WRITING-state emit gating for that specific row.
   --   R lit, G lit, B lit → FSM emits writes. Bug downstream (vram_DIN, DDR3 path).
   --   R dark → FSM never enters WRITING for Y=482 — earlier-stage bug (REQUESTWORD2 parse?)
   -- build #154 bars: bank-value capture at cube CLUT read.
   --   RED   = h54_bank0_at_read   — zn_bank_8mb was "000" when CPU read 0x1F7B61CC
   --   GREEN = h54_bank1_at_read   — zn_bank_8mb was "001" when CPU read 0x1F7B61CC
   --   BLUE  = h54_bankhi_at_read  — zn_bank_8mb was ≥ "010" when CPU read 0x1F7B61CC
   -- Outcome:
   --   RED lit, GREEN+BLUE dark   → bank IS 0 at read → SDRAM at 0x0FB61CC has wrong data
   --                                  (MRA load problem or SDRAM controller bug)
   --   RED+GREEN+BLUE mixed       → multiple bank values at read times — game switches banks
   --                                  between attract iterations
   --   GREEN or BLUE only         → bank mis-selected at every read → cube CLUT code expects
   --                                  bank=0 but FPGA's bank is wrong at that moment
   -- build #159 bars: H7 CLUT-RAM data staleness test.
   --   RED  9-bit = h59_loaded_entry0_lo : bits 8:0 of the first CLUT entry 0 loaded
   --   GREEN 9-bit = h59_loaded_y         : bits 8:0 of textPalReqY at that load
   --   BLUE sticky = h59_anchor           : capture has fired
   -- After test, decode RED/GREEN bar widths and /dev/mem read VRAM at Y (low 9 bits +
   -- assumed Y high bit) at the suspected X. If RED bar matches VRAM[Y][X] low 9 bits,
   -- the CLUT load delivered correct VRAM data → H7 REFUTED.
   -- build #172: Raizing GPU buffer-swap probe.
   -- Hypothesis: Raizing games (Bloody Roar, Brave Blade, Beastorizer) only draw to the back
   -- buffer at VRAM Y=0..239; never set the draw area or offset to the front buffer at Y=240+.
   -- Display origin is at Y=240 per MAME GP1 0x05 trace, so screen shows the empty front buffer.
   --   RED   = sticky: drawingAreaBottom ever > 239 (game ever set draw area to extend into front buffer)
   --   GREEN = sticky: drawingOffsetY ever >= 240 (game ever shifted offset into front buffer region)
   --   BLUE  = b157_anchor_sig (CAT702 anchor — sanity that BIOS check passed)
   -- Outcome on Raizing titles: RED+GREEN dark → buffer swap never happens → black screen.
   --                            RED+GREEN lit + still black → swap works, display origin issue.
   -- Performance counter window/event process. Free-runs at clk1x. Each window
   -- ends every 2^27 cycles (~4 s); the top 9 bits of each event counter become
   -- the bar width, then the counters reset for the next window.
   process(clk1x)
   begin
      if rising_edge(clk1x) then
         -- B-meas10: display the LATCHED ZN-IO poll address (bar width = value):
         --   RED   = znio_addr(20:12)  (high offset; bank 0x1FB0xxxx=>256, 0x1FA4x=>64)
         --   GREEN = znio_addr(11:3)   (mid offset bits)
         --   BLUE  = poll-active flag (full if a ZN-IO read in range is in flight)
         perf_disp_ramwait   <= sig_znio_addr(20 downto 12);
         perf_disp_arbiter   <= sig_znio_addr(11 downto 3);
         -- BLUE full = bit20 set = polled addr is 0x1FB00000+ (bank region)
         perf_disp_vrampause <= (others => sig_znio_addr(20));
      end if;
   end process;

   -- triage_*_fan retained for fallback but no longer drives the bars
   triage_red_fan   <= (others => b172_drawArea_high_ever);
   triage_green_fan <= (others => b172_drawOffset_high_ever);
   triage_blue_fan  <= (others => b157_anchor_sig);
   -- B32: bars display the latched cache-hit READ word-addr. RED=raddr[7:0],
   -- GREEN=raddr[15:8], BLUE=raddr[20:16]. Reconstruct byte-addr =
   -- ((BLUE<<16)|(GREEN<<8)|RED) << 2 | 0x80000000.
   -- ===== B-inst4 ZNSC probe layout ([159:0] visible over JTAG, MSB-first) =====
   --   [159:128] live CPU PC (read repeatedly -> sampling profiler of a hung/spinning core)
   --   [127:96]  rs_data   : raystorm - value of the FIRST CPU data read from the Taito bank-0
   --                         window 0x1F600000-0x1F7FFFFF (the failing R-3 region). Expected
   --                         first read @0x1F600000 = LE word of e24-02.1[0x200000..3].
   --   [95]      rs_valid  : that latch fired
   --   [94:76]   rs_addr   : its address bits [22:4] (window offset)
   --   [75:64]   last_io_rd: byte addr[11:0] of the most recent CPU read in 0x1F801xxx
   --                         (names the register a spin loop polls - 2.02O / hvnsgate)
   --   [63:56]   ch2_kick_cnt : count of DMA2 CHCR (0x1F8010A8) writes with bit24 (start) set
   --   [55:48]   dma_irq_cnt  : count of irq_DMA completion pulses raised to I_STAT[3]
   --                         (BR2: kicks >> irqs = dropped ch2 completions, the smoking gun)
   --   [47:40]   vblank_cnt   : VBLANK IRQ pulse count (liveness; rolls over)
   --   [39:24]   export_irq   : LIVE I_STATUS (bit3=DMA, bit0=VBLANK, bit7=SIO)
   --   [23:19]   gpustat_hi   : bits [28:24] of the last CPU-read GPUSTAT value
   --                         (28=DMA-ready, 26=cmd-ready - hvnsgate DrawSync suspect)
   --   [18:11]   io_rd_cnt    : rolling count of 0x1F801xxx CPU reads (I/O activity liveness)
   --   [10:0]    zeros
   -- ===== B-inst5 upper-96 layout ([255:160], MSB-first) =====
   --   [255:240] rs2_sum_all : shadow lhu-sum over the whole R-3 window (expect 0x7F9E)
   --   [239:224] rs2_sum_lo  : same, only 0x600000-0x6FFFFF (bisection)
   --   [223:221] zn_bank live (memorymux zn_bank_8mb)
   --   [220]     bank2_ever  : any platform ever selected bank 2
   --   [219:188] sh_data     : shared capture - Raizing: first bank-2-window read data;
   --                           Atlus: first data read with PC in 0x8001487x (loop bounds)
   --   [187:167] sh_addr     : its address bits [22:2]
   --   [166]     sh_valid
   --   [165:160] rs2_rd_cnt[20:15] : coarse window-read count (32K units; full scan = 0x20+)
   zn_debug_words <= rs2_sum_all_slv &
                     rs2_sum_lo_slv &
                     dbg_zn_bank_sig &
                     bank2_ever &
                     sh_data &
                     sh_addr_slv &
                     sh_valid &
                     rs2_cnt_hi_slv &
                     dbg_cpu_pc_sig &
                     dbg_rs_data &
                     dbg_rs_valid &
                     std_logic_vector(dbg_rs_addr) &
                     std_logic_vector(dbg_last_io_rd) &
                     std_logic_vector(dbg_ch2_kick_cnt) &
                     std_logic_vector(dbg_dma_irq_cnt) &
                     std_logic_vector(dbg_vblank_cnt) &
                     std_logic_vector(dbg_istat_live) &
                     dbg_gpustat_hi &
                     std_logic_vector(dbg_io_rd_cnt) &
                     std_logic_vector(to_unsigned(0,11));

   -- B-inst5 cast helpers for the probe concat
   rs2_sum_all_slv <= std_logic_vector(rs2_sum_all);
   rs2_sum_lo_slv  <= std_logic_vector(rs2_sum_lo);
   sh_addr_slv     <= std_logic_vector(sh_addr);
   rs2_cnt_hi_slv  <= std_logic_vector(rs2_rd_cnt(20 downto 15));

   -- B-inst4 capture process
   process(clk1x)
   begin
      if rising_edge(clk1x) then
         -- completion/liveness pulse counters (edge-detected)
         dbg_irq_dma_d <= irq_DMA;
         if (irq_DMA = '1' and dbg_irq_dma_d = '0') then
            dbg_dma_irq_cnt <= dbg_dma_irq_cnt + 1;
         end if;
         dbg_vblank_d2 <= irq_VBLANK;
         if (irq_VBLANK = '1' and dbg_vblank_d2 = '0') then
            dbg_vblank_cnt <= dbg_vblank_cnt + 1;
         end if;

         if (mem_request = '1' and mem_isData = '1') then
            if (mem_rnw = '1') then
               -- I/O read tracking (0x1F801000-0x1F801FFF)
               if (mem_addressData(28 downto 12) = to_unsigned(16#1F801#, 17)) then
                  dbg_last_io_rd <= mem_addressData(11 downto 0);
                  dbg_io_rd_cnt  <= dbg_io_rd_cnt + 1;
                  if (mem_addressData(11 downto 0) = to_unsigned(16#814#, 12)) then
                     dbg_gpustat_pend <= '1';   -- capture GPUSTAT value at mem_done below
                  end if;
               end if;
               -- raystorm: arm on the first Taito-platform data read inside the R-3 window
               -- (0x1F600000-0x1F7FFFFF <=> addr[28:21] = 0xFB)
               if (zn_platform = "0010" and dbg_rs_valid = '0' and dbg_rs_pending = '0' and
                   mem_addressData(28 downto 21) = x"FB") then
                  dbg_rs_pending <= '1';
                  dbg_rs_addr    <= mem_addressData(22 downto 4);
               end if;
               -- B-inst5 raystorm checksum shadow: arm on EVERY Taito data read in the window
               if (zn_platform = "0010" and mem_addressData(28 downto 21) = x"FB") then
                  rs2_pending <= '1';
                  rs2_half    <= mem_addressData(1);
                  rs2_lo      <= not mem_addressData(20);
               end if;
               -- B-inst5 shared capture: BR2 bank-2 window read (Raizing, bank=2) OR
               -- hvnsgate loop-bounds read (Atlus, PC inside the 0x80014874 walker entry)
               if (sh_valid = '0' and sh_pending = '0' and
                   ((zn_platform = "0001" and dbg_zn_bank_sig = "010" and
                     mem_addressData(28 downto 23) = "111110") or
                    (zn_platform = "0011" and
                     dbg_cpu_pc_sig(31 downto 4) = x"8001487"))) then
                  sh_pending <= '1';
                  sh_addr    <= mem_addressData(22 downto 2);
               end if;
            else
               -- DMA2 (GPU) CHCR kick: write to 0x1F8010A8 with the start/busy bit set
               if (mem_addressData(28 downto 0) = to_unsigned(16#1F8010A8#, 29) and
                   mem_dataWrite(24) = '1') then
                  dbg_ch2_kick_cnt <= dbg_ch2_kick_cnt + 1;
               end if;
            end if;
         end if;

         if (mem_done = '1') then
            if (dbg_rs_pending = '1') then
               dbg_rs_pending <= '0';
               dbg_rs_valid   <= '1';
               dbg_rs_data    <= mem_dataRead;
            end if;
            if (dbg_gpustat_pend = '1') then
               dbg_gpustat_pend <= '0';
               dbg_gpustat_hi   <= mem_dataRead(28 downto 24);
            end if;
            -- B-inst5: accumulate the halfword the lhu actually selected (mimics game sum)
            if (rs2_pending = '1') then
               rs2_pending <= '0';
               rs2_rd_cnt  <= rs2_rd_cnt + 1;
               if (rs2_half = '1') then
                  rs2_sum_all <= rs2_sum_all + unsigned(mem_dataRead(31 downto 16));
                  if (rs2_lo = '1') then
                     rs2_sum_lo <= rs2_sum_lo + unsigned(mem_dataRead(31 downto 16));
                  end if;
               else
                  rs2_sum_all <= rs2_sum_all + unsigned(mem_dataRead(15 downto 0));
                  if (rs2_lo = '1') then
                     rs2_sum_lo <= rs2_sum_lo + unsigned(mem_dataRead(15 downto 0));
                  end if;
               end if;
            end if;
            if (sh_pending = '1') then
               sh_pending <= '0';
               sh_valid   <= '1';
               sh_data    <= mem_dataRead;
            end if;
         end if;

         if (dbg_zn_bank_sig = "010") then
            bank2_ever <= '1';   -- B-inst5: Raizing/any platform ever selected bank 2
         end if;

         if (reset_intern = '1') then
            dbg_rs_valid     <= '0';
            dbg_rs_pending   <= '0';
            dbg_gpustat_pend <= '0';
            dbg_ch2_kick_cnt <= (others => '0');
            dbg_dma_irq_cnt  <= (others => '0');
            dbg_vblank_cnt   <= (others => '0');
            dbg_io_rd_cnt    <= (others => '0');
            rs2_pending      <= '0';
            rs2_sum_all      <= (others => '0');
            rs2_sum_lo       <= (others => '0');
            rs2_rd_cnt       <= (others => '0');
            sh_pending       <= '0';
            sh_valid         <= '0';
            bank2_ever       <= '0';
         end if;
      end if;
   end process;

   process(clk1x)
   begin
      if rising_edge(clk1x) then
         if reset_intern = '1' then
            ram_accessed_seen <= '0';
            ram_done_seen     <= '0';
            nonzero_read_seen <= '0';
            gpu_accessed_seen <= '0';
            ram_exec_seen     <= '0';
            io_ever_seen      <= '0';
            spu_ever_seen     <= '0';
            cd_ever_seen      <= '0';
            dma_ever_seen        <= '0';
            dma_gpu_write_seen   <= '0';
            dma2_e5_write_seen   <= '0';
            dma2_prim_seen       <= '0';
            pio_prim_seen        <= '0';
            raster_pixel_seen    <= '0';
            raster_pixel_top_seen <= '0';
            -- build #150: CPU PC sticky latches
            h50_pc_cube_loop_seen  <= '0';
            h50_pc_cube_area_seen  <= '0';
            h50_game_ram_exec_seen <= '0';
            -- build #151: CPU GP0 write sticky latches
            h51_gp0_cubeclut_seen <= '0';
            h51_gp0_a0cmd_seen    <= '0';
            h51_gp0_r31_seen      <= '0';
            -- build #152: cube CLUT data words 1-3 latches
            h52_gp0_word1_seen    <= '0';
            h52_gp0_word2_seen    <= '0';
            h52_gp0_word3_seen    <= '0';
            -- build #153: cube CLUT init-step bisect latches
            h53_rd_cubesrc_seen    <= '0';
            h53_wr_staging_seen    <= '0';
            h53_data_7fff0000_seen <= '0';
            -- build #154: bank-at-read latches
            h54_bank0_at_read      <= '0';
            h54_bank1_at_read      <= '0';
            h54_bankhi_at_read     <= '0';
            cnt_stage4       <= (others => '0');
            cnt_pxwr         <= (others => '0');
            cnt_texraw      <= (others => '0');
            disp_cnt_stage4  <= (others => '0');
            disp_cnt_pxwr    <= (others => '0');
            disp_cnt_texraw <= (others => '0');
            -- build #63
            clut_real_data_hi_y_seen <= '0';
            clut_real_data_lo_y_seen <= '0';
            -- build #68
            clut_succ_lo_seen <= '0';
            clut_succ_hi_seen <= '0';
            -- build #19: lpadv-tuned latches
            cmd_64_seen_ever      <= '0';
            cmd_2C_seen_ever      <= '0';
            cmd_A0_seen_ever      <= '0';
            cpu2vram_parsed_dstX_hi_seen <= '0';
            cpu2vram_color_nonnavy_seen <= '0';
            pixelcolor_g_seen <= '0';
            pixelcolor_b_seen <= '0';
            vram_din_gb_seen <= '0';
            texpal_gb_seen <= '0';
            textPalX_ge_256_seen  <= '0';
            textPalX_hi_seen      <= '0';
            cpu2vram_dstX_hi_seen <= '0';
            -- build #26
            cubeclut_gb_seen      <= '0';
            cubeclut_ronly_seen   <= '0';
            loclut_gb_seen        <= '0';
            vram_actual_write_seen <= '0';
            pipeline_color_varied_seen <= '0';
            vram_din_non_navy_seen <= '0';
            vram_dout_nonnavy_seen <= '0';
            videoout_linebuf_nonnavy_seen <= '0';
            videoout_pixeldata_nonnavy_seen <= '0';
            vblank_d                       <= '0';
            -- frame accumulators (build #7)
            frame_ram_exec                 <= '0';
            frame_clut_write_nonnavy       <= '0';
            frame_clut_read_nonnavy        <= '0';
            frame_stage4_texture           <= '0';
            frame_pipeline_color_varied    <= '0';
            -- build #24 frame/disp resets
            frame_rect_tex_4bit            <= '0';
            frame_rect_tex_8bit            <= '0';
            frame_rect_tex_15bit           <= '0';
            frame_rect_tex_pixel_gb        <= '0';
            disp_rect_tex_4bit             <= '0';
            disp_rect_tex_8bit             <= '0';
            disp_rect_tex_15bit            <= '0';
            disp_rect_tex_pixel_gb         <= '0';
            frame_pixeldata_nonnavy        <= '0';
            frame_pipeline_write_any       <= '0';
            -- displayed snapshots (build #7)
            disp_ram_exec                  <= '0';
            disp_clut_write_nonnavy        <= '0';
            disp_clut_read_nonnavy         <= '0';
            disp_stage4_texture            <= '0';
            disp_pipeline_color_varied     <= '0';
            disp_pixeldata_nonnavy         <= '0';
            disp_pipeline_write_any        <= '0';
            -- build #8 accumulators + displayed
            frame_b8_textPalNew            <= '0';
            frame_b8_textPalReq_set        <= '0';
            frame_b8_state_REQ_PAL         <= '0';
            frame_b8_CLUTwrenA_any         <= '0';
            frame_b8_drawMode_8            <= '0';
            frame_b8_noTexture_pin         <= '0';
            disp_b8_textPalNew             <= '0';
            disp_b8_textPalReq_set         <= '0';
            disp_b8_state_REQ_PAL          <= '0';
            disp_b8_CLUTwrenA_any          <= '0';
            disp_b8_drawMode_8             <= '0';
            disp_b8_noTexture_pin          <= '0';
            disp_vram_dout_nonnavy_b10     <= '0';
            disp_vram_din_nonnavy_b10      <= '0';
            disp_cpu2vram_active_ever      <= '0';
            disp_cpu2vram_nonnavy_ever     <= '0';
            disp_clut_write_nv_ever        <= '0';
            disp_clut_read_nv_ever         <= '0';
            disp_pipeline_color_var_ever   <= '0';
            disp_pixeldata_nv_ever         <= '0';
            disp_pipeline_pxwr_ever        <= '0';
            disp_clut_X_nz_ever            <= '0';
            disp_clut_Y_nz_ever            <= '0';
            disp_cpu2vram_dstY_bit8_ever   <= '0';
            disp_cpu2vram_dstY_nz_ever     <= '0';
            disp_cpu2vram_dstX_zero_ever   <= '0';
            disp_cpu2vram_dstX_nz_ever     <= '0';
            disp_vram_we_x_zero_ever       <= '0';
            disp_vram_we_x_zero_nv_ever    <= '0';
            disp_vram2vram_active_ever     <= '0';
            disp_vramFill_active_ever      <= '0';
            disp_pixelAddr_Y_hi_ever       <= '0';
            disp_cpu2vram_Y_hi_ever        <= '0';
            disp_vram_addr_Y_hi_we_ever    <= '0';
            disp_vram_addr_Y_hi_rd_ever    <= '0';
            dma_gpu_waiting_seen <= '0';
            irq_dma_seen         <= '0';
            dma_spu_write_seen   <= '0';
            irq_stat_read_seen   <= '0';
            irq_stat_write_seen  <= '0';
            irq_cdrom_seen       <= '0';
            irq_timer_seen       <= '0';
            vblank_irq_seen      <= '0';
            zn_sio_ever_seen  <= '0';
            zn_check1_seen    <= '0';
            zn_check2_seen    <= '0';
            zn_kn02_rx_nonzero <= '0';
            -- build #172: drawing-area sticky latches
            b172_drawArea_high_ever   <= '0';
            b172_drawOffset_high_ever <= '0';
            -- build #163: throughput counters reset
            b163_win_cnt      <= (others => '0');
            b163_win_tick     <= '0';
            b163_dma2_cnt     <= (others => '0');
            b163_dma4_cnt     <= (others => '0');
            b163_bank_cnt     <= (others => '0');
            b163_dma2_disp    <= (others => '0');
            b163_dma4_disp    <= (others => '0');
            b163_bank_disp    <= (others => '0');
            b163_DMA_GPU_writeEna_d <= '0';
            b163_DMA_SPU_writeEna_d <= '0';
            b163_bank_write_d <= '0';
         else
            -- ram_accessed_seen: CPU put any request on RAM bus (read or write)
            if ram_cpu_ena = '1' then
               ram_accessed_seen <= '1';
            end if;
            -- ram_done_seen: SDRAM completed a CPU transaction
            if ram_cpu_done = '1' then
               ram_done_seen <= '1';
            end if;
            -- nonzero_read_seen: SDRAM returned non-zero data on a CPU read (BIOS is loaded)
            if ram_cpu_done = '1' and ram_dataRead32 /= x"00000000" then
               nonzero_read_seen <= '1';
            end if;
            -- gpu_accessed_seen: CPU read or wrote GPU registers
            if bus_gpu_read = '1' or bus_gpu_write = '1' then
               gpu_accessed_seen <= '1';
            end if;
            -- ram_exec_seen: CPU fetch from physical RAM above 0x40000 (game at ~0x80050000, not 0xA0000500 stub)
            if mem_request = '1' and mem_isData = '0' and
               mem_addressInstr(28 downto 0) >= to_unsigned(16#40000#, 29) and
               mem_addressInstr(28 downto 0) < to_unsigned(16#800000#, 29) then
               ram_exec_seen <= '1';
            end if;
            -- build #150: CPU PC sticky latches at the cube CLUT PIO upload site.
            if mem_request = '1' and mem_isData = '0' then
               if mem_addressInstr = x"8003CB20" then
                  h50_pc_cube_loop_seen <= '1';
               end if;
               if mem_addressInstr >= x"8003CB00" and mem_addressInstr < x"8003CB60" then
                  h50_pc_cube_area_seen <= '1';
               end if;
               if mem_addressInstr >= x"80050000" and mem_addressInstr < x"80060000" then
                  h50_game_ram_exec_seen <= '1';
               end if;
            end if;
            -- build #151+#152: CPU GP0 PIO write sticky latches.
            -- B151: word 0 (0x7FFF0000) was DARK → entries 0+1 not written together.
            -- B152: now also check words 1-3 to see whether ANY cube CLUT data is
            -- being written, or if the staging buffer is fully corrupted.
            if bus_gpu_write = '1' and bus_gpu_addr = "0000" then
               -- B151 detectors (kept for cross-reference at next read)
               if bus_gpu_dataWrite = x"7FFF0000" then
                  h51_gp0_cubeclut_seen <= '1';
               end if;
               if bus_gpu_dataWrite(31 downto 24) = x"A0" then
                  h51_gp0_a0cmd_seen <= '1';
               end if;
               if bus_gpu_dataWrite(20 downto 16) = "11111" then
                  h51_gp0_r31_seen <= '1';
               end if;
               -- B152 cube CLUT data words 1-3 (ground truth from rp00.u0216 0x3B61CC)
               if bus_gpu_dataWrite = x"3FFF023F" then
                  h52_gp0_word1_seen <= '1';
               end if;
               if bus_gpu_dataWrite = x"03FF033F" then
                  h52_gp0_word2_seen <= '1';
               end if;
               if bus_gpu_dataWrite = x"039F02DF" then
                  h52_gp0_word3_seen <= '1';
               end if;
            end if;
            -- build #153: cube CLUT init-step bisect at the CPU↔memory bus.
            -- (Outside the bus_gpu_write gate — these probe mem_addressData directly.)
            if mem_request = '1' and mem_isData = '1' then
               -- data READ from banked ROM at the cube CLUT source word
               if mem_rnw = '1' and mem_addressData = x"1F7B61CC" then
                  h53_rd_cubesrc_seen <= '1';
               end if;
               -- data WRITE at the staging buffer destination (lower 28 bits match
               -- both KSEG0 0x800BED40 and KUSEG 0x000BED40)
               if mem_rnw = '0' and mem_addressData(27 downto 0) = x"00BED40" then
                  h53_wr_staging_seen <= '1';
               end if;
            end if;
            -- mem_dataRead delivers 0x7FFF0000 on any completed data read
            -- (catches the cube CLUT first word arriving at the CPU from any source).
            if mem_done = '1' and mem_dataRead = x"7FFF0000" then
               h53_data_7fff0000_seen <= '1';
            end if;
            -- build #154: capture bank register value AT the moment CPU reads 0x1F7B61CC.
            -- Bank 0 + offset 0x7B61CC should map to FPGA SDRAM 0x0FB61CC (rp00 cube CLUT).
            -- If bank != 0 at the moment of the read, CPU reads from the wrong bank ROM region.
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '1'
               and mem_addressData = x"1F7B61CC" then
               if zn_bank_8mb_dbg = "000" then
                  h54_bank0_at_read <= '1';
               elsif zn_bank_8mb_dbg = "001" then
                  h54_bank1_at_read <= '1';
               else
                  h54_bankhi_at_read <= '1';
               end if;
            end if;
            -- io_ever_seen: any access to ZN I/O space
            if bus_znio_read = '1' or bus_znio_write = '1' then
               io_ever_seen <= '1';
            end if;
            -- spu_ever_seen: any SPU register access (0x1F801C00-0x1F801FFF)
            if bus_spu_read = '1' or bus_spu_write = '1' then
               spu_ever_seen <= '1';
            end if;
            -- cd_ever_seen: any CD-ROM register access (0x1F801800-0x1F80180F)
            if bus_cd_read = '1' or bus_cd_write = '1' then
               cd_ever_seen <= '1';
            end if;
            -- dma_ever_seen: DMA registers written (0x1F801080-0x1F8010FF)
            if bus_dma_write = '1' then
               dma_ever_seen <= '1';
            end if;
            -- dma_gpu_write_seen: DMA ch2 (GPU) wrote a word to GPU (linked-list or block mode)
            if DMA_GPU_writeEna = '1' then
               dma_gpu_write_seen <= '1';
            end if;
            -- dma2_e5_write_seen: DMA ch2 wrote a word with cmd byte 0xE5 (drawing offset)
            if DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"E5" then
               dma2_e5_write_seen <= '1';
            end if;
            -- dma2_prim_seen: DMA ch2 wrote a word whose upper byte is a drawing primitive
            -- (0x20-0x3F polygon, 0x40-0x5F line, 0x60-0x7F rectangle). May false-positive on
            -- parameter words; sufficient for "did any primitive command ever reach the GPU".
            if DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) >= x"20" and DMA_GPU_write(31 downto 24) <= x"7F" then
               dma2_prim_seen <= '1';
            end if;
            -- pio_prim_seen: CPU PIO wrote GP0 (bus_gpu_addr=0) with upper byte 0x20-0x7F
            -- (any drawing primitive). Same false-positive caveat as dma2_prim_seen.
            if bus_gpu_write = '1' and bus_gpu_addr = "0000" and
               bus_gpu_dataWrite(31 downto 24) >= x"20" and bus_gpu_dataWrite(31 downto 24) <= x"7F" then
               pio_prim_seen <= '1';
            end if;
            -- build #19: cmd_64_seen — any GP0 write (DMA2 or PIO) with upper byte 0x64
            -- (lpadv's dominant primitive — variable-size textured opaque rect). False-positive caveat:
            -- a parameter word with bits 31:24 == 0x64 will also light this bar.
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"64") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"64") then
               cmd_64_seen_ever <= '1';
            end if;
            -- build #19: cmd_2C_seen — any GP0 write with upper byte 0x2C (textured 4-vertex poly)
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"2C") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"2C") then
               cmd_2C_seen_ever <= '1';
            end if;
            -- build #20: cmd_A0_seen — any GP0 write with upper byte 0xA0 (CPU2VRAM dispatch).
            -- False-positive caveat as with the 0x64/0x2C detectors: a parameter word whose
            -- upper byte happens to be 0xA0 will also light this. Sufficient to answer
            -- "did the game ever try to upload a texture via CPU2VRAM?"
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"A0") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"A0") then
               cmd_A0_seen_ever <= '1';
            end if;
            -- build #44: DECISIVE cube-palette color probe. Banking + MRA ROM layout were proven
            -- correct vs MAME (byte-for-byte), so the upstream ROM->SDRAM->banked-read path is clean.
            -- The classification now happens in gpu.vhd gated on the cube CLUT's UNIQUE VRAM
            -- destination (X<256, Y=488 = MAME's exact cube-CLUT upload), removing the value/address
            -- ambiguity that contaminated builds #40-43. Here we just sticky-latch those results
            -- (gpu.vhd runs in clk2x; re-latch into the clk1x bar domain):
            -- build #47: TIGHT-window banked-ROM palette-read classifier (memorymux).
            --   [4] WHITE cubeclut_ronly_seen = dbg_palrd_any        (a read in the GREEN-row window [0x..4800,0x..4A00) completed = anchor)
            --   [1] GREEN loclut_gb_seen      = dbg_palrd_green      (green-row read returns GREEN -> read-path CLEAN, bug downstream: CPU-store/DMA)
            --   [3] YELLOW cubeclut_gb_seen   = dbg_palrd_red        (green-row read returns RED -> SMOKING GUN: read-path/SDRAM corrupts)
            --   [2] BLUE  textPalX_hi_seen    = dbg_palrd_redrow_red (CONTROL: red row [0x..5000,0x..5200) reads RED -> instrument distinguishes rows; expect lit)
            if dbg_palrd_any        = '1' then cubeclut_ronly_seen <= '1'; end if;
            if dbg_palrd_green      = '1' then loclut_gb_seen      <= '1'; end if;
            if dbg_palrd_red        = '1' then cubeclut_gb_seen    <= '1'; end if;
            if dbg_palrd_redrow_red = '1' then textPalX_hi_seen    <= '1'; end if;
            -- [0] RED sanity: any cpu2vram 0xA0 upload ever dispatched (confirms uploads occur)
            if cmd_A0_seen_ever = '1' then cpu2vram_parsed_dstX_hi_seen <= '1'; end if;
            -- build #22: cpu2vram ever wrote non-navy non-zero pixel data
            -- (dbg_cpu2vram_color_nonnavy already filters pixelColor /= 0x4000 and /= 0x0000)
            if dbg_cpu2vram_color_nonnavy = '1' then
               cpu2vram_color_nonnavy_seen <= '1';
            end if;
            -- build #23: G/B channel-bit detection
            if dbg_pipeline_g_set = '1' then
               pixelcolor_g_seen <= '1';
            end if;
            if dbg_pipeline_b_set = '1' then
               pixelcolor_b_seen <= '1';
            end if;
            if dbg_vram_din_gb = '1' then
               vram_din_gb_seen <= '1';
            end if;
            if dbg_cpu2vram_color_gb = '1' then
               texpal_gb_seen <= '1';  -- reusing the name; actually "cpu2vram color had G/B"
            end if;
            -- raster_pixel_seen: GPU rasterizer produced at least one pixel write to VRAM
            -- (does not include fast-fill or CPU->VRAM transfers — purely the primitive pipeline)
            if dbg_pipeline_pixelWrite = '1' then
               raster_pixel_seen <= '1';
            end if;
            -- raster_pixel_top_seen: rasterizer pixel write where Y < 256 (top half of VRAM)
            -- If raster_pixel_seen is bright but this stays dark, pixels are landing in Y >= 256 (off-screen).
            if dbg_pipeline_write_in_top = '1' then
               raster_pixel_top_seen <= '1';
            end if;
            -- vram_actual_write_seen: vram_WE actually asserted toward DDR3.
            -- If raster_pixel_seen is bright but this stays dark, pixel writes are killed
            -- between pipeline output and DDR3 (FIFO drop / stall / arbitration loss).
            if dbg_vram_WE_tap = '1' then
               vram_actual_write_seen <= '1';
            end if;
            -- pipeline_color_varied_seen: rasterizer produced any non-navy color
            if dbg_pipeline_color_varied = '1' then
               pipeline_color_varied_seen <= '1';
            end if;
            -- vram_din_non_navy_seen: vram_DIN contained non-navy data during a write
            if dbg_vram_din_non_navy = '1' then
               vram_din_non_navy_seen <= '1';
            end if;
            -- vram_dout_nonnavy_seen: DDR3 returned non-navy data on a GPU read (sticky — kept for reference)
            if dbg_vram_dout_nonnavy = '1' then
               vram_dout_nonnavy_seen <= '1';
            end if;
            if dbg_videoout_linebuf_nonnavy = '1' then
               videoout_linebuf_nonnavy_seen <= '1';
            end if;
            if dbg_videoout_pixeldata_nonnavy = '1' then
               videoout_pixeldata_nonnavy_seen <= '1';
            end if;
            -- Frame-windowed latches (build #7).
            vblank_d <= irq_VBLANK;
            if irq_VBLANK = '1' and vblank_d = '0' then
               -- build #65: per-frame counts — latch and reset all three
               disp_cnt_stage4  <= cnt_stage4;
               disp_cnt_pxwr    <= cnt_pxwr;
               disp_cnt_texraw  <= cnt_texraw;
               cnt_stage4       <= (others => '0');
               cnt_pxwr         <= (others => '0');
               cnt_texraw       <= (others => '0');
               disp_ram_exec              <= frame_ram_exec;
               disp_clut_write_nonnavy    <= frame_clut_write_nonnavy;
               disp_clut_read_nonnavy     <= frame_clut_read_nonnavy;
               disp_stage4_texture        <= frame_stage4_texture;
               disp_pipeline_color_varied <= frame_pipeline_color_varied;
               disp_pixeldata_nonnavy     <= frame_pixeldata_nonnavy;
               disp_pipeline_write_any    <= frame_pipeline_write_any;
               -- restart accumulators with this cycle's events
               frame_ram_exec              <= evt_ram_exec;
               frame_clut_write_nonnavy    <= dbg_clut_write_nonnavy;
               frame_clut_read_nonnavy     <= dbg_clut_read_nonnavy;
               frame_stage4_texture        <= dbg_stage4_texture;
               frame_pipeline_color_varied <= dbg_pipeline_color_varied;
               frame_pixeldata_nonnavy     <= dbg_videoout_pixeldata_nonnavy;
               frame_pipeline_write_any    <= dbg_pipeline_pixelWrite;
               -- build #8: per-frame transfer for textPalNew/Req/REQ_PAL/CLUTwrenA
               disp_b8_textPalNew          <= frame_b8_textPalNew;
               disp_b8_textPalReq_set      <= frame_b8_textPalReq_set;
               disp_b8_state_REQ_PAL       <= frame_b8_state_REQ_PAL;
               disp_b8_CLUTwrenA_any       <= frame_b8_CLUTwrenA_any;
               frame_b8_textPalNew         <= dbg_textPalNew;
               frame_b8_textPalReq_set     <= dbg_textPalReq_set;
               frame_b8_state_REQ_PAL      <= dbg_state_REQ_PAL;
               frame_b8_CLUTwrenA_any     <= dbg_CLUTwrenA_any;
               -- build #24: textured-rect drawMode tracking, frame-windowed.
               -- disp_* carries the PREVIOUS frame's state; frame_* accumulates the new frame.
               disp_rect_tex_4bit          <= frame_rect_tex_4bit;
               disp_rect_tex_8bit          <= frame_rect_tex_8bit;
               disp_rect_tex_15bit         <= frame_rect_tex_15bit;
               disp_rect_tex_pixel_gb      <= frame_rect_tex_pixel_gb;
               frame_rect_tex_4bit         <= dbg_rect_tex_4bit;
               frame_rect_tex_8bit         <= dbg_rect_tex_8bit;
               frame_rect_tex_15bit        <= dbg_rect_tex_15bit;
               frame_rect_tex_pixel_gb     <= dbg_rect_tex_pixel_gb;
            else
               -- build #56: per-frame stage4 textured pixel count (saturating at 18-bit max)
               if dbg_stage4_texture = '1' and cnt_stage4 < to_unsigned(262143, 18) then
                  cnt_stage4 <= cnt_stage4 + 1;
               end if;
               -- build #65: GREEN = PER-FRAME count of CLUT-RAM real-data writes targeting Y in [460,500)
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '1'
                  and cnt_pxwr < to_unsigned(262143, 18) then
                  cnt_pxwr <= cnt_pxwr + 1;
               end if;
               -- build #65: BLUE = PER-FRAME count of CLUT-RAM real-data writes targeting Y < 460 (low-Y, e.g., BIOS text)
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '0'
                  and cnt_texraw < to_unsigned(262143, 18) then
                  cnt_texraw <= cnt_texraw + 1;
               end if;
               if evt_ram_exec = '1' then frame_ram_exec <= '1'; end if;
               -- build #63: sticky latches for CLUT-RAM ever receiving real data, by Y range of textPalReqY
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '1' then
                  clut_real_data_hi_y_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '0' then
                  clut_real_data_lo_y_seen <= '1';
               end if;
               -- build #68: split sticky latches at Y=480 boundary
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_lo = '1' then
                  clut_succ_lo_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_hi = '1' then
                  clut_succ_hi_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' then frame_clut_write_nonnavy <= '1'; end if;
               if dbg_clut_read_nonnavy = '1' then frame_clut_read_nonnavy <= '1'; end if;
               if dbg_stage4_texture = '1' then frame_stage4_texture <= '1'; end if;
               if dbg_pipeline_color_varied = '1' then frame_pipeline_color_varied <= '1'; end if;
               if dbg_videoout_pixeldata_nonnavy = '1' then frame_pixeldata_nonnavy <= '1'; end if;
               if dbg_pipeline_pixelWrite = '1' then frame_pipeline_write_any <= '1'; end if;
               -- build #8 frame accumulators
               if dbg_textPalNew = '1' then frame_b8_textPalNew <= '1'; end if;
               if dbg_textPalReq_set = '1' then frame_b8_textPalReq_set <= '1'; end if;
               if dbg_state_REQ_PAL = '1' then frame_b8_state_REQ_PAL <= '1'; end if;
               if dbg_CLUTwrenA_any = '1' then frame_b8_CLUTwrenA_any <= '1'; end if;
               -- build #24 frame accumulators (within-frame)
               if dbg_rect_tex_4bit = '1' then frame_rect_tex_4bit <= '1'; end if;
               if dbg_rect_tex_8bit = '1' then frame_rect_tex_8bit <= '1'; end if;
               if dbg_rect_tex_15bit = '1' then frame_rect_tex_15bit <= '1'; end if;
               if dbg_rect_tex_pixel_gb = '1' then frame_rect_tex_pixel_gb <= '1'; end if;
            end if;
            -- build #8 LATCHED-FOREVER confounders (drawMode_8 and noTexture):
            -- these should be 0 in normal operation; latch sticky-on to make any occurrence visible
            if dbg_drawMode_8 = '1' then disp_b8_drawMode_8 <= '1'; end if;
            if dbg_noTexture_pin = '1' then disp_b8_noTexture_pin <= '1'; end if;
            -- build #10 LATCHED-FOREVER VRAM data taps
            if dbg_vram_dout_nonnavy = '1' then disp_vram_dout_nonnavy_b10 <= '1'; end if;
            if dbg_vram_din_non_navy = '1' then disp_vram_din_nonnavy_b10 <= '1'; end if;
            -- build #11 LATCHED-FOREVER CPU2VRAM taps
            if dbg_cpu2vram_pixelWrite = '1' then disp_cpu2vram_active_ever <= '1'; end if;
            if dbg_cpu2vram_color_nonnavy = '1' then disp_cpu2vram_nonnavy_ever <= '1'; end if;
            -- build #12 LATCHED-FOREVER readback chain
            if dbg_clut_write_nonnavy = '1' then disp_clut_write_nv_ever <= '1'; end if;
            if dbg_clut_read_nonnavy = '1' then disp_clut_read_nv_ever <= '1'; end if;
            if dbg_pipeline_color_varied = '1' then disp_pipeline_color_var_ever <= '1'; end if;
            if dbg_videoout_pixeldata_nonnavy = '1' then disp_pixeldata_nv_ever <= '1'; end if;
            if dbg_pipeline_pixelWrite = '1' then disp_pipeline_pxwr_ever <= '1'; end if;
            -- build #13 CLUT addressing latches
            if dbg_textPalReqX_nz = '1' then disp_clut_X_nz_ever <= '1'; end if;
            if dbg_textPalReqY_nz = '1' then disp_clut_Y_nz_ever <= '1'; end if;
            if dbg_cpu2vram_dstY_bit8 = '1' then disp_cpu2vram_dstY_bit8_ever <= '1'; end if;
            if dbg_cpu2vram_dstY_nz = '1' then disp_cpu2vram_dstY_nz_ever <= '1'; end if;
            -- build #14 CPU2VRAM destination X
            if dbg_cpu2vram_dstX_zero = '1' then disp_cpu2vram_dstX_zero_ever <= '1'; end if;
            if dbg_cpu2vram_dstX_nz = '1' then disp_cpu2vram_dstX_nz_ever <= '1'; end if;
            -- build #15 ANY write at X=0
            if dbg_vram_we_x_zero = '1' then disp_vram_we_x_zero_ever <= '1'; end if;
            if dbg_vram_we_x_zero_nv = '1' then disp_vram_we_x_zero_nv_ever <= '1'; end if;
            if dbg_vram2vram_active = '1' then disp_vram2vram_active_ever <= '1'; end if;
            if dbg_vramFill_active = '1' then disp_vramFill_active_ever <= '1'; end if;
            -- build #17 Y-wrap verification
            if dbg_pixelAddr_Y_hi = '1' then disp_pixelAddr_Y_hi_ever <= '1'; end if;
            if dbg_cpu2vram_Y_hi = '1' then disp_cpu2vram_Y_hi_ever <= '1'; end if;
            if dbg_vram_addr_Y_hi_we = '1' then disp_vram_addr_Y_hi_we_ever <= '1'; end if;
            if dbg_vram_addr_Y_hi_rd = '1' then disp_vram_addr_Y_hi_rd_ever <= '1'; end if;
            -- dma_gpu_waiting_seen: DMA ch2 was blocked waiting for GPU (hangs here if GPU stalls)
            if DMA_GPU_waiting = '1' then
               dma_gpu_waiting_seen <= '1';
            end if;
            -- irq_dma_seen: DMA IRQ fired = DMA completed at least one transfer
            if irq_DMA = '1' then
               irq_dma_seen <= '1';
            end if;
            -- dma_spu_write_seen: DMA ch4 (SPU) wrote data to SPU RAM
            if DMA_SPU_writeEna = '1' then
               dma_spu_write_seen <= '1';
            end if;
            -- irq_stat_read_seen: CPU read the IRQ status register (I_STAT at 0x1F801070)
            if bus_irq_read = '1' then
               irq_stat_read_seen <= '1';
            end if;
            -- irq_stat_write_seen: CPU wrote to I_STAT or I_MASK (interrupt acknowledge)
            -- DARK → game reads I_STAT but never writes back → not doing proper IRQ acknowledge
            -- BRIGHT → game attempts IRQ acknowledge (write); irqRequest still bright = something re-fires
            if bus_irq_write = '1' then
               irq_stat_write_seen <= '1';
            end if;
            -- irq_cdrom_seen: CD-ROM module generated an interrupt
            -- BRIGHT → CD-ROM generating IRQs (spurious INT5 without disc = likely persistent irqRequest source)
            if irq_CDROM = '1' then
               irq_cdrom_seen <= '1';
            end if;
            -- irq_timer_seen: any timer (0/1/2) generated an interrupt
            if irq_TIMER0 = '1' or irq_TIMER1 = '1' or irq_TIMER2 = '1' then
               irq_timer_seen <= '1';
            end if;
            -- vblank_irq_seen: VBLANK IRQ source fired (feeds into I_STAT[0])
            if irq_VBLANK = '1' then
               vblank_irq_seen <= '1';
            end if;
            -- ZN security debug: latch security check initiations and any SIO byte
            if zn_beginTransfer = '1' then
               zn_sio_ever_seen <= '1';
            end if;
            if zn_sec_select = "110" then  -- 0x88: bit2=0→KN01 active-low (check 1)
               zn_check1_seen <= '1';
            end if;
            if zn_sec_select = "101" then  -- 0x84: bit3=0→KN02 active-low (check 2)
               zn_check2_seen <= '1';
            end if;
            -- kn02_rx_nonzero: KN02 replied with a byte that is not 0x00 or 0xFF
            if zn_receive_valid = '1' and zn_sec_select = "101" and
               zn_rxbyte /= x"00" and zn_rxbyte /= x"FF" then
               zn_kn02_rx_nonzero <= '1';
            end if;

            -- build #172: sticky latch — drawingAreaBottom > 239 (game ever drew to front buffer)
            if unsigned(drawingAreaBottom_sig) > to_unsigned(239, 10) then
               b172_drawArea_high_ever <= '1';
            end if;
            -- build #172: sticky latch — drawingOffsetY >= 240 (treating as signed; check positive)
            -- drawingOffsetY is signed(10:0); if MSB=0 (positive) and value >= 240
            if drawingOffsetY_sig(10) = '0' and unsigned(drawingOffsetY_sig(9 downto 0)) >= to_unsigned(240, 10) then
               b172_drawOffset_high_ever <= '1';
            end if;

            -- build #163: per-window throughput counters
            -- Window timer: 2^27 clk1x cycles ≈ 3.96s at 33.8688 MHz
            b163_win_cnt <= b163_win_cnt + 1;
            if b163_win_cnt = to_unsigned(16#7FFFFFF#, 27) then
               -- end of window: latch counts to display regs, reset counters
               b163_dma2_disp <= std_logic_vector(b163_dma2_cnt);
               b163_dma4_disp <= std_logic_vector(b163_dma4_cnt);
               b163_bank_disp <= std_logic_vector(b163_bank_cnt);
               b163_dma2_cnt  <= (others => '0');
               b163_dma4_cnt  <= (others => '0');
               b163_bank_cnt  <= (others => '0');
            else
               -- B28: RED = vblank IRQ rising edges per window (is the IRQ still firing during the hang?)
               if irq_VBLANK = '1' and b163_DMA_GPU_writeEna_d = '0' and b163_dma2_cnt /= "111111111" then
                  b163_dma2_cnt <= b163_dma2_cnt + 1;
               end if;
               -- B28: GREEN = flag CLEAR (write 0 to wait_vsync 0x0008C6D0) — VSync completion by IRQ handler
               if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
                  and mem_addressData(28 downto 0) = to_unsigned(16#0008C6D0#, 29)
                  and mem_dataWrite = x"00000000"
                  and b163_DMA_SPU_writeEna_d = '0' and b163_dma4_cnt /= "111111111" then
                  b163_dma4_cnt <= b163_dma4_cnt + 1;
               end if;
               -- B28: BLUE = flag SET (write 1 to wait_vsync 0x0008C6D0) — main code calls VSync (still running?)
               if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
                  and mem_addressData(28 downto 0) = to_unsigned(16#0008C6D0#, 29)
                  and mem_dataWrite = x"00000001"
                  and b163_DMA_SPU_writeEna_d = '0' and b163_bank_cnt /= "111111111" then
                  b163_bank_cnt <= b163_bank_cnt + 1;
               end if;
            end if;
            -- B30: latch the live CPU PC on each vblank rising edge (stable per frame).
            -- During the hang this samples the stuck loop's instruction address.
            if irq_VBLANK = '1' and b163_DMA_GPU_writeEna_d = '0' then
               pc_latch    <= dbg_cpu_pc_sig;
               raddr_latch <= dbg_dcache_raddr_sig;
            end if;
            -- B28 edge-detect: vblank level (GPU_writeEna_d) + any flag write (SPU_writeEna_d)
            b163_DMA_GPU_writeEna_d <= irq_VBLANK;
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
               and mem_addressData(28 downto 0) = to_unsigned(16#0008C6D0#, 29) then
               b163_DMA_SPU_writeEna_d <= '1';
            else
               b163_DMA_SPU_writeEna_d <= '0';
            end if;

         end if;
      end if;
   end process;

   imemorymux : entity work.memorymux
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      ce                   => ce,   
      reset                => reset_intern,
      
      pauseNext            => cpuPaused or (dmaRequest and canDMA),
      isIdle               => memMuxIdle,
         
      loadExe              => loadExe,
      exe_initial_pc       => exe_initial_pc,  
      exe_initial_gp       => exe_initial_gp,  
      exe_load_address     => exe_load_address,
      exe_file_size        => exe_file_size,   
      exe_stackpointer     => exe_stackpointer,
      reset_exe            => reset_exe,
      
      fastboot             => fastboot,
      TURBO                => TURBO_MEM,
      ROM_PREFETCH         => ROM_PREFETCH,
      FAST_BIOS            => FAST_BIOS,
      region_in            => biosregion,
      PATCHSERIAL          => PATCHSERIAL,
            
      ram_dataWrite        => ram_cpu_dataWrite,
      ram_dataRead         => ram_dataRead32,  
      ram_Adr              => ram_cpu_Adr,  
      ram_be               => ram_cpu_be,        
      ram_rnw              => ram_cpu_rnw,      
      ram_ena              => ram_cpu_ena,   
      ram_cache            => ram_cpu_cache,      
      ram_done             => ram_cpu_done,
      
      mem_in_request       => mem_request,  
      mem_in_rnw           => mem_rnw,      
      mem_in_isData        => mem_isData,      
      mem_in_isCache       => mem_isCache,      
      mem_in_oldtagvalids  => mem_oldtagvalids,  
      mem_in_addressInstr  => mem_addressInstr,  
      mem_in_addressData   => mem_addressData,  
      mem_in_reqsize       => mem_reqsize,  
      mem_in_writeMask     => mem_writeMask,
      mem_in_dataWrite     => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_done             => mem_done,
      mem_fifofull         => mem_fifofull,  
      mem_tagvalids        => mem_tagvalids,

      bios_memctrl         => bios_memctrl,

      ex1_memctrl          => ex1_memctrl,
      --bus_exp1_addr        => bus_exp1_addr,   
      --bus_exp1_dataWrite   => bus_exp1_dataWrite,
      bus_exp1_read        => bus_exp1_read,   
      --bus_exp1_write       => bus_exp1_write,  
      bus_exp1_dataRead    => bus_exp1_dataRead,
      
      bus_memc_addr        => bus_memc_addr,     
      bus_memc_dataWrite   => bus_memc_dataWrite,
      bus_memc_read        => bus_memc_read,     
      bus_memc_write       => bus_memc_write,    
      bus_memc_dataRead    => bus_memc_dataRead,   
      
      bus_pad_addr         => bus_pad_addr,     
      bus_pad_dataWrite    => bus_pad_dataWrite,
      bus_pad_read         => bus_pad_read,     
      bus_pad_write        => bus_pad_write,    
      bus_pad_writeMask    => bus_pad_writeMask,
      bus_pad_dataRead     => bus_pad_dataRead,       
      
      bus_sio_addr         => bus_sio_addr,     
      bus_sio_dataWrite    => bus_sio_dataWrite,
      bus_sio_read         => bus_sio_read,     
      bus_sio_write        => bus_sio_write,    
      bus_sio_writeMask    => bus_sio_writeMask,
      bus_sio_dataRead     => bus_sio_dataRead, 

      bus_memc2_addr       => bus_memc2_addr,     
      bus_memc2_dataWrite  => bus_memc2_dataWrite,
      bus_memc2_read       => bus_memc2_read,     
      bus_memc2_write      => bus_memc2_write,    
      bus_memc2_dataRead   => bus_memc2_dataRead, 

      bus_irq_addr         => bus_irq_addr,     
      bus_irq_dataWrite    => bus_irq_dataWrite,
      bus_irq_read         => bus_irq_read,     
      bus_irq_write        => bus_irq_write,    
      bus_irq_dataRead     => bus_irq_dataRead,       
      
      bus_dma_addr         => bus_dma_addr,     
      bus_dma_dataWrite    => bus_dma_dataWrite,
      bus_dma_read         => bus_dma_read,     
      bus_dma_write        => bus_dma_write,    
      bus_dma_dataRead     => bus_dma_dataRead,     

      bus_tmr_addr         => bus_tmr_addr,     
      bus_tmr_dataWrite    => bus_tmr_dataWrite,
      bus_tmr_read         => bus_tmr_read,     
      bus_tmr_write        => bus_tmr_write,    
      bus_tmr_dataRead     => bus_tmr_dataRead,  

      cd_memctrl           => cd_memctrl,
      bus_cd_addr          => bus_cd_addr,     
      bus_cd_dataWrite     => bus_cd_dataWrite,
      bus_cd_read          => bus_cd_read,     
      bus_cd_write         => bus_cd_write,    
      bus_cd_dataRead      => bus_cd_dataRead,      
      
      bus_gpu_addr         => bus_gpu_addr,     
      bus_gpu_dataWrite    => bus_gpu_dataWrite,
      bus_gpu_read         => bus_gpu_read,     
      bus_gpu_write        => bus_gpu_write,    
      bus_gpu_dataRead     => bus_gpu_dataRead,
      bus_gpu_stall        => bus_gpu_stall,
      
      bus_mdec_addr        => bus_mdec_addr,
      bus_mdec_dataWrite   => bus_mdec_dataWrite,
      bus_mdec_read        => bus_mdec_read,
      bus_mdec_write       => bus_mdec_write,
      bus_mdec_dataRead    => bus_mdec_dataRead,

      bus_znio_addr        => bus_znio_addr,
      bus_znio_dataWrite   => bus_znio_dataWrite,
      bus_znio_read        => bus_znio_read,
      bus_znio_write       => bus_znio_write,
      bus_znio_writeMask   => bus_znio_writeMask,
      bus_znio_dataRead    => bus_znio_dataRead,

      zn_platform          => zn_platform,
      dbg_zn_bank          => dbg_zn_bank_sig,   -- B-inst5

      spu_memctrl          => spu_memctrl, 
      bus_spu_addr         => bus_spu_addr,     
      bus_spu_dataWrite    => bus_spu_dataWrite,
      bus_spu_read         => bus_spu_read,     
      bus_spu_write        => bus_spu_write,    
      bus_spu_dataRead     => bus_spu_dataRead, 
      
      ex2_memctrl          => ex2_memctrl,
      bus_exp2_addr        => bus_exp2_addr,     
      bus_exp2_dataWrite   => bus_exp2_dataWrite,
      bus_exp2_read        => bus_exp2_read,     
      bus_exp2_write       => bus_exp2_write,    
      bus_exp2_dataRead    => bus_exp2_dataRead,
      
      ex3_memctrl          => ex3_memctrl,
      --bus_exp3_dataWrite   => bus_exp3_dataWrite,
      bus_exp3_read        => bus_exp3_read,     
      --bus_exp3_write       => bus_exp3_write,    
      bus_exp3_dataRead    => bus_exp3_dataRead, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(18 downto 0),
      SS_wren_SDRam        => SS_wren(16),
      SS_rden_SDRam        => SS_rden(16),
      zn_bank_8mb_out      => zn_bank_8mb_dbg, -- build #39
      dbg_palrd_green      => dbg_palrd_green,  -- build #47
      dbg_palrd_red        => dbg_palrd_red,    -- build #47
      dbg_palrd_any        => dbg_palrd_any,    -- build #47
      dbg_palrd_redrow_red => dbg_palrd_redrow_red, -- build #47
      dbg_palrd_value      => dbg_palrd_value,      -- build #50
      dbg_palrd_addr       => dbg_palrd_addr,       -- build #51
      dbg_palrd_words      => dbg_palrd_words,        -- build #52
      dbg_cubeclut_window_seen => dbg_cubeclut_window_seen,  -- build #135
      dbg_cubeclut_exact_seen  => dbg_cubeclut_exact_seen,   -- build #135
      dbg_cubeclut_bank0_seen  => dbg_cubeclut_bank0_seen,   -- build #135
      dbg_busy_rom             => sig_busy_rom,              -- B-meas
      dbg_busy_ramrd           => sig_busy_ramrd,            -- B-meas
      dbg_busy_ramwr           => sig_busy_ramwr,            -- B-meas
      dbg_znio_addr            => sig_znio_addr              -- B-meas10
   );

   icpu : entity work.cpu
   port map
   (
      clk1x             => clk1x,
      clk2x             => clk2x,
      clk3x             => clk3x,
      ce                => ce,   
      reset             => reset_intern,
      
      TURBO             => (TURBO_COMP or CPU_LATE_READ_SKIP),
      TURBO_CACHE       => TURBO_CACHE,
      TURBO_CACHE50     => TURBO_CACHE50,
      FAST_MATH         => FAST_MATH,
      cpu_hilo_stall    => cpu_hilo_stall,
      cpu_pipeline_stall => cpu_pipeline_stall,
      cpu_mem_inflight  => cpu_mem_inflight,
         
      irqRequest        => irqRequest,
      dmaStallCPU       => dmaStallCPU,
      cpuPaused         => cpuPaused,
      
      error             => errorCPU,
      error2            => errorCPU2,
         
      mem_request       => mem_request,  
      mem_rnw           => mem_rnw,      
      mem_isData        => mem_isData,      
      mem_isCache       => mem_isCache, 
      mem_oldtagvalids  => mem_oldtagvalids,      
      mem_addressInstr  => mem_addressInstr,  
      mem_addressData   => mem_addressData,  
      mem_reqsize       => mem_reqsize,  
      mem_writeMask     => mem_writeMask,
      mem_dataWrite     => mem_dataWrite,
      mem_dataRead      => mem_dataRead, 
      mem_done          => mem_done,
      mem_fifofull      => mem_fifofull,
      mem_tagvalids     => mem_tagvalids,
      
      cache_wr          => cache_wr,  
      cache_data        => cache_data,
      cache_addr        => cache_addr,
      
      stallNext         => stallNext,
      
      dma_cache_Adr     => dma_cache_Adr,  
      dma_cache_data    => dma_cache_data, 
      dma_cache_write   => dma_cache_write,  
      
      ram_dataRead      => ram_dataRead32,    
      ram_rnw           => ram_cpu_rnw,
      ram_done          => ram_cpu_done,
      
      gte_busy          => gte_busy, 
      gte_readEna       => gte_readEna,
      gte_readAddr      => gte_readAddr, 
      gte_readData      => gte_readData, 
      gte_writeAddr     => gte_writeAddr,
      gte_writeData     => gte_writeData,
      gte_writeEna      => gte_writeEna, 
      gte_cmdData       => gte_cmdData,  
      gte_cmdEna        => gte_cmdEna, 

      SS_reset          => SS_reset,
      SS_DataWrite      => SS_DataWrite,
      SS_Adr            => SS_Adr(7 downto 0),   
      SS_wren_CPU       => SS_wren(0),     
      SS_wren_SCP       => SS_wren(12),  
      SS_rden_CPU       => SS_rden(0),     
      SS_rden_SCP       => SS_rden(12),        
      SS_DataRead_CPU   => SS_DataRead_CPU,
      SS_DataRead_SCP   => SS_DataRead_SCP,
      SS_idle           => SS_idle_cpu,
      
-- synthesis translate_off
      cpu_done          => cpu_done,  
      cpu_export        => cpu_export,
-- synthesis translate_on

      dbg_cpu_pc        => dbg_cpu_pc_sig,
      dbg_dcache_raddr  => dbg_dcache_raddr_sig,
      dbg_shadow        => dbg_shadow_sig,
      debug_firstGTE    => debug_firstGTE
   );
   
   igte : entity work.gte
   port map
   (
      clk1x                => clk1x,     
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset_intern,     
      
      WIDESCREEN           => WIDESCREEN,
      TURBO                => TURBO_COMP,
      
      gte_busy             => gte_busy,     
      gte_readAddr         => gte_readAddr, 
      gte_readData         => gte_readData, 
      gte_readEna          => gte_readEna,
      gte_writeAddr_in     => gte_writeAddr,
      gte_writeData_in     => gte_writeData,
      gte_writeEna_in      => gte_writeEna, 
      gte_cmdData          => gte_cmdData,  
      gte_cmdEna           => gte_cmdEna,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),
      SS_wren              => SS_wren(4),     
      SS_rden              => SS_rden(4),     
      SS_DataRead          => SS_DataRead_GTE,
      SS_idle              => SS_idle_gte,
      
      debug_firstGTE       => debug_firstGTE
   );
   
   ddr3_BURSTCNT <= ss_ram_BURSTCNT     when (ddr3_savestate = '1') else arbiter_BURSTCNT when (arbiter_active = '1') else  vram_BURSTCNT;
   ddr3_ADDR     <= ss_ram_ADDR & "00"  when (ddr3_savestate = '1') else arbiter_ADDR     when (arbiter_active = '1') else  vram_ADDR;
   ddr3_DIN      <= ss_ram_DIN          when (ddr3_savestate = '1') else arbiter_DIN      when (arbiter_active = '1') else  vram_DIN;
   ddr3_BE       <= ss_ram_BE           when (ddr3_savestate = '1') else arbiter_BE       when (arbiter_active = '1') else  vram_BE;
   ddr3_WE       <= ss_ram_WE           when (ddr3_savestate = '1') else arbiter_WE       when (arbiter_active = '1') else  vram_WE;
   ddr3_RD       <= ss_ram_RD           when (ddr3_savestate = '1') else arbiter_RD       when (arbiter_active = '1') else  vram_RD;
   
   -- build #141: ZN-1 arcade — memcard1/memcard2 instances removed.
   -- Arcade has no memory cards; PSX-console memcard logic was a candidate for SIO0
   -- bus contention with CAT702 reuse of the same SIO0 path (zn_sio module bridges
   -- joypad SNAC pins to CAT702). All memcard outputs stubbed to inert values so
   -- entity ports, pause arbitration, and DDR3 arbitration still get safe inputs.

   memcard_changed <= '0';
   saving_memcard  <= '0';

   -- pause-arbitration inputs (no memcard activity)
   memcard1_pause           <= '0';
   memcard2_pause           <= '0';
   MemCard_changePending1   <= '0';
   MemCard_changePending2   <= '0';
   MemCard_saving_memcard1  <= '0';
   MemCard_saving_memcard2  <= '0';

   -- entity-port outputs to sys layer (memcards never read/write)
   memcard1_rd      <= '0';
   memcard1_wr      <= '0';
   memcard1_lba     <= (others => '0');
   memcard1_dataOut <= (others => '0');
   memcard2_rd      <= '0';
   memcard2_wr      <= '0';
   memcard2_lba     <= (others => '0');
   memcard2_dataOut <= (others => '0');

   -- DDR3 arbiter inputs from memcards (no DDR3 traffic)
   memHPScard1_request  <= '0';
   memHPScard1_BURSTCNT <= (others => '0');
   memHPScard1_ADDR     <= (others => '0');
   memHPScard1_DIN      <= (others => '0');
   memHPScard1_BE       <= (others => '0');
   memHPScard1_WE       <= '0';
   memHPScard1_RD       <= '0';
   memHPScard2_request  <= '0';
   memHPScard2_BURSTCNT <= (others => '0');
   memHPScard2_ADDR     <= (others => '0');
   memHPScard2_DIN      <= (others => '0');
   memHPScard2_BE       <= (others => '0');
   memHPScard2_WE       <= '0';
   memHPScard2_RD       <= '0';
   
   isavestates : entity work.savestates
   generic map
   (
      FASTSIM                 => is_simu,
      Softmap_SaveState_ADDR  => 58720256
   )
   port map
   (
      clk1x                   => clk1x,
      clk2x                   => clk2x,
      clk2xIndex              => clk2xIndex,
      ce                      => ce,
      reset_in                => reset_in,
      reset_out               => reset_intern,
      ss_reset                => SS_reset,
      
      hps_busy                => hps_busy,
      loadExe                 => loadExe,
           
      load_done               => state_loaded,
      validSStates            => validSStates,
            
      savestate_number        => savestate_number,
      increaseSSHeaderCount   => increaseSSHeaderCount,
      save                    => savestate_savestate,
      load                    => savestate_loadstate,
      savestate_address       => savestate_address,  
      savestate_busy          => savestate_busy,    

      SS_idle                 => SS_idle,
      system_paused           => pausingSS,
      savestate_pause         => savestate_pause,
      ddr3_savestate          => ddr3_savestate,
      
      useSPUSDRAM             => SPUSDRAM,
      
      SS_DataWrite            => SS_DataWrite,   
      SS_Adr                  => SS_Adr,         
      SS_wren                 => SS_wren,       
      SS_rden                 => SS_rden,       
      SS_DataRead_CPU         => SS_DataRead_CPU,
      SS_DataRead_GPU         => SS_DataRead_GPU,
      SS_DataRead_GPUTiming   => SS_DataRead_GPUTiming,
      SS_DataRead_DMA         => SS_DataRead_DMA,
      SS_DataRead_GTE         => SS_DataRead_GTE,
      SS_DataRead_JOYPAD      => SS_DataRead_JOYPAD,
      SS_DataRead_MDEC        => SS_DataRead_MDEC,
      SS_DataRead_MEMORY      => SS_DataRead_MEMORY,
      SS_DataRead_TIMER       => SS_DataRead_TIMER,
      SS_DataRead_SOUND       => SS_DataRead_SOUND,
      SS_DataRead_IRQ         => SS_DataRead_IRQ,
      SS_DataRead_SIO         => SS_DataRead_SIO,
      SS_DataRead_SCP         => SS_DataRead_SCP,
      SS_DataRead_CD          => SS_DataRead_CD,

      sdram_done              => ram_done,
      
      loading_savestate       => loading_savestate,
      saving_savestate        => open,
            
      ddr3_BUSY               => ddr3_BUSY,      
      ddr3_DOUT               => ddr3_DOUT,      
      ddr3_DOUT_READY         => ddr3_DOUT_READY,
      ddr3_BURSTCNT           => ss_ram_BURSTCNT,
      ddr3_ADDR               => ss_ram_ADDR,    
      ddr3_DIN                => ss_ram_DIN,     
      ddr3_BE                 => ss_ram_BE,      
      ddr3_WE                 => ss_ram_WE,      
      ddr3_RD                 => ss_ram_RD,

      ram_done                => ram_cpu_done,   
      ram_data                => ram_dataRead32,
      
      SS_SPURAM_dataWrite     => SS_SPURAM_dataWrite,
      SS_SPURAM_Adr           => SS_SPURAM_Adr,      
      SS_SPURAM_request       => SS_SPURAM_request,  
      SS_SPURAM_rnw           => SS_SPURAM_rnw,      
      SS_SPURAM_dataRead      => SS_SPURAM_dataRead, 
      SS_SPURAM_done          => SS_SPURAM_done     
   );  

   istatemanager : entity work.statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => 58720256,
      Softmap_Rewind_ADDR      => 33554432
   )
   port map
   (
      clk                 => clk2x,  
      ce                  => ce,  
      reset               => reset_in,
                         
      rewind_on           => rewind_on,    
      rewind_active       => rewind_active,
                        
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
                       
      sleep_rewind        => open,
      vsync               => IRQ_VBlank,
      system_idle         => '1',
                 
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy    
   );
   
   -- export
-- synthesis translate_off
   export_irq <= dbg_istat_live;  -- B-inst4: sim alias (port now drives the synthesizable signal)
   gexport : if is_simu = '1' generate
   begin

      new_export <= cpu_done;
      
      iexport : entity work.export
      port map
      (
         clk               => clk1x,
         ce                => ce,
         reset             => reset_intern,
            
         new_export        => cpu_done,
         export_cpu        => cpu_export,
            
         export_irq        => export_irq,
            
         export_gtm        => export_gtm,
         export_line       => export_line,
         export_gpus       => export_gpus,
         export_gobj       => export_gobj,
         
         export_t_current0 => export_t_current0,
         export_t_current1 => export_t_current1,
         export_t_current2 => export_t_current2,
            
         export_8          => export_8,
         export_16         => export_16,
         export_32         => export_32
      );
   
   
   end generate;
-- synthesis translate_on
   
end architecture;





