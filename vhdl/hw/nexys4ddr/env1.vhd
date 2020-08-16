----------------------------------------------------------------------------------
-- QNICE-FPGA on a Nexys4 DDR board
--
-- Top Module for synthesizing the whole machine
--
-- done on-again-off-again in 2015, 2016, 2020 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

-- UNISIM is used for the Xilinx specific clock generator MMCME. 
-- Comment everything about it out and comment in below-mentioned "generate_clk25MHz" process
-- to port this top file to another hardware and for more details refer to the file
-- "hw/README.md" section "General advise for porting"
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity env1 is
port (
   CLK         : in std_logic;                      -- 100 MHz clock
   RESET_N     : in std_logic;                      -- CPU reset button (negative, i.e. 0 = reset)
   
   -- 7 segment display: common anode and cathode
   SSEG_AN     : out std_logic_vector(7 downto 0);  -- common anode: selects digit
   SSEG_CA     : out std_logic_vector(7 downto 0);  -- cathode: selects segment within a digit 

   -- serial communication
   UART_RXD    : in std_logic;                      -- receive data
   UART_TXD    : out std_logic;                     -- send data
   UART_RTS    : in std_logic;                      -- (active low) equals cts from dte, i.e. fpga is allowed to send to dte
   UART_CTS    : out std_logic;                     -- (active low) clear to send (dte is allowed to send to fpga)   
   
   -- switches and LEDs
   SWITCHES    : in std_logic_vector(15 downto 0);  -- 16 on/off "dip" switches
   LEDs        : out std_logic_vector(15 downto 0); -- 16 LEDs
   
   -- PS/2 keyboard
   PS2_CLK     : in std_logic;
   PS2_DAT     : in std_logic;

   -- VGA
   VGA_RED     : out std_logic_vector(3 downto 0);
   VGA_GREEN   : out std_logic_vector(3 downto 0);
   VGA_BLUE    : out std_logic_vector(3 downto 0);
   VGA_HS      : out std_logic;
   VGA_VS      : out std_logic;
   
   -- SD Card
   SD_RESET    : out std_logic;
   SD_CLK      : out std_logic;
   SD_MOSI     : out std_logic;
   SD_MISO     : in std_logic;
   SD_DAT      : out std_logic_vector(3 downto 1)
); 
end env1;

architecture beh of env1 is

-- QNICE CPU
component QNICE_CPU
port (
   -- clock
   CLK            : in std_logic;
   RESET          : in std_logic;
   
   WAIT_FOR_DATA  : in std_logic;                            -- 1=CPU adds wait cycles while re-reading from bus
      
   ADDR           : out std_logic_vector(15 downto 0);      -- 16 bit address bus
   
   -- bidirectional 16 bit data bus
   DATA_IN        : in std_logic_vector(15 downto 0);       -- receive data
   DATA_OUT       : out std_logic_vector(15 downto 0);      -- send data
   DATA_DIR       : out std_logic;                          -- 1=DATA is sending, 0=DATA is receiving
   DATA_VALID     : out std_logic;                          -- while DATA_DIR = 1: DATA contains valid data
   
   -- signals about the CPU state
   HALT           : out std_logic;                          -- 1=CPU halted due to the HALT command, 0=running
   INS_CNT_STROBE : out std_logic;                          -- goes high for one clock cycle for each new instruction
   
   -- interrupt system                                      -- refer to doc/intro/qnice_intro.pdf to learn how this works
   INT_N          : in std_logic   := '1';
   IGRANT_N       : out std_logic
    
);
end component;

-- ROM
component BROM is
generic (
   FILE_NAME   : string
);
port (
   clk         : in std_logic;                        -- read and write on rising clock edge
   ce          : in std_logic;                        -- chip enable, when low then zero on output
   
   address     : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   data        : out std_logic_vector(15 downto 0);   -- read data
   
   busy        : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA               
);
end component;

-- BLOCK RAM
component BRAM is
port (
   clk      : in std_logic;                        -- read and write on rising clock edge
   ce       : in std_logic;                        -- chip enable, when low then zero on output
   
   address  : in std_logic_vector(14 downto 0);    -- address is for now 16 bit hard coded
   we       : in std_logic;                        -- write enable
   data_i   : in std_logic_vector(15 downto 0);    -- write data
   data_o   : out std_logic_vector(15 downto 0);   -- read data
   
   busy     : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA   
);
end component;

-- VGA 80x40 monoschrome screen
component vga_textmode is
port (
   reset       : in std_logic;     -- async reset
   clk25MHz    : in std_logic;
   clk50MHz    : in std_logic;

   -- VGA registers
   en          : in std_logic;     -- enable for reading from or writing to the bus
   we          : in std_logic;     -- write to VGA's registers via system's data bus
   reg         : in std_logic_vector(3 downto 0);     -- register selector
   data_in     : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out    : out std_logic_vector(15 downto 0);   -- system's data bus
   
   -- VGA output signals, monochrome only
   R           : out std_logic;
   G           : out std_logic;
   B           : out std_logic;
   hsync       : out std_logic;
   vsync       : out std_logic
);
end component;

-- TIL display emulation (4 digits)
component til_display is
port (
   clk               : in std_logic;
   reset             : in std_logic;
   
   til_reg0_enable   : in std_logic;      -- data register
   til_reg1_enable   : in std_logic;      -- mask register (each bit equals one digit)
   
   data_in           : in std_logic_vector(15 downto 0);
   
   -- 7 segment display needs multiplexed approach due to common anode
   SSEG_AN           : out std_logic_vector(7 downto 0); -- common anode: selects digit
   SSEG_CA           : out std_logic_vector(7 downto 0) -- cathode: selects segment within a digit 
);
end component;

-- UART
component bus_uart is
generic (
   DIVISOR        : natural               -- see UART_DIVISOR in env1_globals.vhd
);
port (
   clk            : in std_logic;                       
   reset          : in std_logic;

   -- physical interface
   rx             : in std_logic;
   tx             : out std_logic;
   rts            : in std_logic;
   cts            : out std_logic;   
   
   -- conntect to CPU's address and data bus (data goes zero when en=0)
   uart_en        : in std_logic;
   uart_we        : in std_logic;
   uart_reg       : in std_logic_vector(1 downto 0);
   uart_cpu_ws    : out std_logic;   
   cpu_data_in    : in std_logic_vector(15 downto 0);
   cpu_data_out   : out std_logic_vector(15 downto 0)
);
end component;

-- PS/2 keyboard
component keyboard is
generic (
   clk_freq      : integer
);
port (
   clk           : in std_logic;               -- system clock input
   reset         : in std_logic;               -- system reset

   -- PS/2
   ps2_clk       : in std_logic;               -- clock signal from PS/2 keyboard
   ps2_data      : in std_logic;               -- data signal from PS/2 keyboard
   
   -- conntect to CPU's data bus (data goes zero when all reg_* are 0)
   kbd_en        : in std_logic;
   kbd_we        : in std_logic;
   kbd_reg       : in std_logic_vector(1 downto 0);   
   cpu_data_in   : in std_logic_vector(15 downto 0);
   cpu_data_out  : out std_logic_vector(15 downto 0)
);
end component;

-- Interrupt generator: Timer Module
component timer_module is
generic (
   CLK_FREQ       : natural                              -- system clock in Hertz
);
port (
   clk            : in std_logic;                        -- system clock
   reset          : in std_logic;                        -- async reset
   
   -- Daisy Chaining: "left/right" comments are meant to describe a situation, where the CPU is the leftmost device
   int_n_out      : out std_logic;                        -- left device's interrupt signal input
   grant_n_in     : in std_logic;                         -- left device's grant signal output
   int_n_in       : in std_logic;                         -- right device's interrupt signal output
   grant_n_out    : out std_logic;                        -- right device's grant signal input
   
   -- Registers
   en             : in std_logic;                        -- enable for reading from or writing to the bus
   we             : in std_logic;                        -- write to the registers via system's data bus
   reg            : in std_logic_vector(2 downto 0);     -- register selector
   data_in        : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out       : out std_logic_vector(15 downto 0)    -- system's data bus
);
end component;

-- impulse (cycle) counter
component cycle_counter is
port (
   clk      : in std_logic;         -- system clock
   impulse  : in std_logic;         -- impulse that is counted   
   reset    : in std_logic;         -- async reset
   
   -- cycle counter's registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to VGA's registers via system's data bus
   reg      : in std_logic_vector(1 downto 0);     -- register selector
   data_in  : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out : out std_logic_vector(15 downto 0)    -- system's data bus
);
end component;

-- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
component EAE is
port (
   clk      : in std_logic;                        -- system clock
   reset    : in std_logic;                        -- system reset
   
   -- EAE registers
   en       : in std_logic;                        -- chip enable
   we       : in std_logic;                        -- write enable
   reg      : in std_logic_vector(2 downto 0);     -- register selector
   data_in  : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out : out std_logic_vector(15 downto 0)    -- system's data bus
);
end component;

-- SD Card
component sdcard is
port (
   clk      : in std_logic;         -- system clock
   reset    : in std_logic;         -- async reset
   
   -- registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to the registers via system's data bus
   reg      : in std_logic_vector(2 downto 0);      -- register selector
   data_in  : in std_logic_vector(15 downto 0);     -- system's data bus
   data_out : out std_logic_vector(15 downto 0);    -- system's data bus
   
   -- hardware interface
   sd_reset : out std_logic;
   sd_clk   : out std_logic;
   sd_mosi  : out std_logic;
   sd_miso  : in std_logic
);
end component;


-- CPU Bus Test
component cpu_bus_test is
port (
   clk      : in std_logic;         -- system clock
   reset    : in std_logic;         -- async reset

   -- registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to the registers via system's data bus
   reg      : in std_logic_vector(2 downto 0);      -- register selector
   data     : inout std_logic_vector(15 downto 0)   -- system's data bus
);
end component;


-- multiplexer to control the data bus (enable/disable the different parties)
component mmio_mux is
port (
   -- input from hardware
   HW_RESET          : in std_logic;
   CLK               : in std_logic;

   
   -- input from CPU
   addr              : in std_logic_vector(15 downto 0);
   data_dir          : in std_logic;
   data_valid        : in std_logic;
   cpu_halt          : in std_logic;
   cpu_igrant_n      : in std_logic; -- if this goes to 0, then all devices need to leave the DATA bus alone,
                                     -- because the interrupt device will put the ISR address on the bus
      
   -- let the CPU wait for data from the bus
   cpu_wait_for_data : out std_logic;   
   
   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable        : out std_logic;
   ram_enable        : out std_logic;
   rom_busy          : in std_logic;
   ram_busy          : in std_logic;
   pore_rom_enable   : out std_logic;
   pore_rom_busy     : in std_logic;   
   
   -- signals for peripheral devices
   til_reg0_enable   : out std_logic;
   til_reg1_enable   : out std_logic;
   switch_reg_enable : out std_logic;
   kbd_en            : out std_logic;
   kbd_we            : out std_logic;
   kbd_reg           : out std_logic_vector(1 downto 0);
   tin_en            : out std_logic;
   tin_we            : out std_logic;
   tin_reg           : out std_logic_vector(2 downto 0);
      
   vga_en            : out std_logic;
   vga_we            : out std_logic;
   vga_reg           : out std_logic_vector(3 downto 0);
   uart_en           : out std_logic;
   uart_we           : out std_logic;
   uart_reg          : out std_logic_vector(1 downto 0);
   uart_cpu_ws       : in std_logic;   
   cyc_en            : out std_logic;
   cyc_we            : out std_logic;
   cyc_reg           : out std_logic_vector(1 downto 0);
   ins_en            : out std_logic;
   ins_we            : out std_logic;
   ins_reg           : out std_logic_vector(1 downto 0);
   eae_en            : out std_logic;
   eae_we            : out std_logic;
   eae_reg           : out std_logic_vector(2 downto 0);
   sd_en             : out std_logic;
   sd_we             : out std_logic;
   sd_reg            : out std_logic_vector(2 downto 0);   
   cbt_en            : out std_logic;
   cbt_we            : out std_logic;
   cbt_reg           : out std_logic_vector(2 downto 0);
   reset_pre_pore    : out std_logic;
   reset_post_pore   : out std_logic   
);
end component;

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data_in            : std_logic_vector(15 downto 0);
signal cpu_data_out           : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;
signal cpu_ins_cnt_strobe     : std_logic;
signal cpu_int_n              : std_logic;
signal cpu_igrant_n           : std_logic;

-- MMIO control signals
signal rom_enable             : std_logic;
signal rom_busy               : std_logic;
signal rom_data_out           : std_logic_vector(15 downto 0);
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal ram_data_out           : std_logic_vector(15 downto 0);
signal pore_rom_enable        : std_logic;
signal pore_rom_busy          : std_logic;
signal pore_rom_data_out      : std_logic_vector(15 downto 0);
signal til_reg0_enable        : std_logic;
signal til_reg1_enable        : std_logic;
signal switch_reg_enable      : std_logic;
signal switch_data_out        : std_logic_vector(15 downto 0);
signal kbd_en                 : std_logic;
signal kbd_we                 : std_logic;
signal kbd_reg                : std_logic_vector(1 downto 0);
signal kbd_data_out           : std_logic_vector(15 downto 0);
signal tin_en                 : std_logic;
signal tin_we                 : std_logic;
signal tin_reg                : std_logic_vector(2 downto 0);
signal timer_data_out         : std_logic_vector(15 downto 0);
signal vga_en                 : std_logic;
signal vga_we                 : std_logic;
signal vga_reg                : std_logic_vector(3 downto 0);
signal vga_data_out           : std_logic_vector(15 downto 0);
signal uart_en                : std_logic;
signal uart_we                : std_logic;
signal uart_reg               : std_logic_vector(1 downto 0);
signal uart_data_out          : std_logic_vector(15 downto 0);
signal uart_cpu_ws            : std_logic;
signal cyc_en                 : std_logic;
signal cyc_we                 : std_logic;
signal cyc_reg                : std_logic_vector(1 downto 0);
signal cyc_data_out           : std_logic_vector(15 downto 0);
signal ins_en                 : std_logic;
signal ins_we                 : std_logic;
signal ins_reg                : std_logic_vector(1 downto 0);
signal ins_data_out           : std_logic_vector(15 downto 0);
signal eae_en                 : std_logic;
signal eae_we                 : std_logic;
signal eae_reg                : std_logic_vector(2 downto 0);
signal eae_data_out           : std_logic_vector(15 downto 0);
signal sd_en                  : std_logic;
signal sd_we                  : std_logic;
signal sd_reg                 : std_logic_vector(2 downto 0); 
signal sd_data_out            : std_logic_vector(15 downto 0);
signal cbt_en                 : std_logic;
signal cbt_we                 : std_logic;
signal cbt_reg                : std_logic_vector(2 downto 0);
signal cbt_data_out           : std_logic_vector(15 downto 0);

signal reset_pre_pore         : std_logic;
signal reset_post_pore        : std_logic;

-- VGA control signals
signal vga_r                  : std_logic;
signal vga_g                  : std_logic;
signal vga_b                  : std_logic;

-- 50 MHz as long as we did not solve the timing issues of the register file
signal SLOW_CLOCK             : std_logic := '0';

-- 25 MHz or 25.175 MHz pixelclock for VGA
-- The 25.175 MHz pixelclock creates a much sharper image on most monitors, but the
-- code for creating it is not as portable as the 25 MHz code (which is a simple clock divider)
-- Have a look at hw/README.md "General advise for porting"
signal clk25MHz               : std_logic := '0';

-- MMCME related signals
signal clk_fb_main            : std_logic;
signal pll_locked_main        : std_logic;

-- combined pre- and post pore reset
signal reset_ctl              : std_logic;

-- enable displaying of address bus on system halt, if switch 2 is on
signal i_til_reg0_enable      : std_logic;
signal i_til_data_in          : std_logic_vector(15 downto 0);

begin

   -- Merge data outputs from all devices into a single data input to the CPU.
   -- This requires that all devices output 0's when not selected.
   cpu_data_in <= pore_rom_data_out or
                  rom_data_out      or
                  ram_data_out      or
                  switch_data_out   or
                  kbd_data_out      or
                  vga_data_out      or
                  uart_data_out     or
                  timer_data_out    or
                  cyc_data_out      or
                  ins_data_out      or
                  eae_data_out      or
                  sd_data_out;

  -- Non portable (Xilinx specific) way to generate the 25.175 MHz pixel clock
  -- Comment out and replace by the below-mentioned process "generate_clk25MHz"
  -- if you want to be portable and have a look at hw/README.md "General advise for porting"
  clk_main: mmcme2_base
  generic map
  (
    clkin1_period    => 10.0,       --   100 MHz (10 ns)
    clkfbout_mult_f  => 8.0,        --   800 MHz common multiply
    divclk_divide    => 1,          --   800 MHz /1 common divide to stay within 600MHz-1600MHz range
    clkout0_divide_f => 31.7775571  --   25.175 MHz / 31.7775571 == pixelclock
  )
  port map
  (
    pwrdwn   => '0',
    rst      => '0',
    clkin1   => CLK,
    clkfbin  => clk_fb_main,
    clkfbout => clk_fb_main,
    clkout0  => clk25MHz,           --  pixelclock
    locked   => pll_locked_main
  );

   -- QNICE CPU
   cpu : QNICE_CPU
      port map (
         CLK => SLOW_CLOCK,
         RESET => reset_ctl,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA_IN => cpu_data_in,
         DATA_OUT => cpu_data_out,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt,
         INS_CNT_STROBE => cpu_ins_cnt_strobe,
         INT_N => cpu_int_n,
         IGRANT_N => cpu_igrant_n
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : BROM
      generic map (
         FILE_NAME   => ROM_FILE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => rom_data_out,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : BRAM
      port map (
         clk         => SLOW_CLOCK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data_out,
         data_o      => ram_data_out,
         busy        => ram_busy         
      );
      
   -- PORE ROM: Power On & Reset Execution ROM
   -- contains code that is executed during power on and/or during reset
   -- MMIO is managing the PORE process
   pore_rom : BROM
      generic map (
         FILE_NAME   => PORE_ROM_FILE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => pore_rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => pore_rom_data_out,
         busy        => pore_rom_busy
      );
                 
   -- VGA: 80x40 textmode VGA adaptor   
   vga_screen : vga_textmode
      port map (
         reset => reset_ctl,
         clk25MHz => clk25MHz,
         clk50MHz => SLOW_CLOCK,
         R => vga_r,
         G => vga_g,
         B => vga_b,
         hsync => VGA_HS,
         vsync => VGA_VS,
         en => vga_en,
         we => vga_we,
         reg => vga_reg,
         data_in => cpu_data_out,
         data_out => vga_data_out
      );

   -- TIL display emulation (4 digits)
   til_leds : til_display
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         til_reg0_enable => i_til_reg0_enable,
         til_reg1_enable => til_reg1_enable,
         data_in => i_til_data_in,
         SSEG_AN => SSEG_AN,
         SSEG_CA => SSEG_CA
      );

   -- special UART with FIFO that can be directly connected to the CPU bus
   uart : bus_uart
      generic map (
         DIVISOR => UART_DIVISOR
      )
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         rx => UART_RXD,
         tx => UART_TXD,
         rts => UART_RTS,
         cts => UART_CTS,
         uart_en => uart_en,
         uart_we => uart_we,
         uart_reg => uart_reg,
         uart_cpu_ws => uart_cpu_ws,         
         cpu_data_in => cpu_data_out,
         cpu_data_out => uart_data_out
      );
      
   -- PS/2 keyboard
   kbd : keyboard
      generic map (
         clk_freq => 50000000                -- see @TODO in keyboard.vhd and TODO.txt
      )
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         ps2_clk => PS2_CLK,
         ps2_data => PS2_DAT,
         kbd_en => kbd_en,
         kbd_we => kbd_we,
         kbd_reg => kbd_reg,
         cpu_data_in => cpu_data_out,
         cpu_data_out => kbd_data_out
      );
      
   timer_interrupt : timer_module   
      generic map (
         CLK_FREQ => 50000000
      )
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         int_n_out => cpu_int_n,
         grant_n_in => cpu_igrant_n,
         int_n_in => '1',        -- no more devices to in Daisy Chain: 1=no interrupt
         grant_n_out => open,    -- ditto: open=grant goes nowhere
         en => tin_en,
         we => tin_we,
         reg => tin_reg,
         data_in => cpu_data_out,
         data_out => timer_data_out
      );
            
   -- cycle counter
   cyc : cycle_counter
      port map (
         clk => SLOW_CLOCK,
         impulse => '1',
         reset => reset_ctl,
         en => cyc_en,
         we => cyc_we,
         reg => cyc_reg,
         data_in => cpu_data_out,
         data_out => cyc_data_out
      );
      
   -- instruction counter
   ins : cycle_counter
      port map (
         clk => SLOW_CLOCK,
         impulse => cpu_ins_cnt_strobe,
         reset => reset_ctl,
         en => ins_en,
         we => ins_we,
         reg => ins_reg,
         data_in => cpu_data_out,
         data_out => ins_data_out
      );
      
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : eae
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         en => eae_en,
         we => eae_we,
         reg => eae_reg,
         data_in => cpu_data_out,
         data_out => eae_data_out
      );

   -- SD Card
   sd_card : sdcard
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         en => sd_en,
         we => sd_we,
         reg => sd_reg,
         data_in => cpu_data_out,
         data_out => sd_data_out,
         sd_reset => SD_RESET,
         sd_clk => SD_CLK,
         sd_mosi => SD_MOSI,
         sd_miso => SD_MISO
      );
                        
   -- CPU Bus Test
   cbt_inst : cpu_bus_test
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         en => cbt_en,
         we => cbt_we,
         reg => cbt_reg,
         data => cpu_data
      );

   -- memory mapped i/o controller
   mmio_controller : mmio_mux
      port map (
         HW_RESET => not RESET_N,
         CLK => SLOW_CLOCK,                  -- @TODO change debouncer bitsize when going to 100 MHz
         addr => cpu_addr,
         data_dir => cpu_data_dir,
         data_valid => cpu_data_valid,
         cpu_wait_for_data => cpu_wait_for_data,
         cpu_halt => cpu_halt,
         cpu_igrant_n => cpu_igrant_n,         
         rom_enable => rom_enable,
         rom_busy => rom_busy,
         ram_enable => ram_enable,
         ram_busy => ram_busy,
         pore_rom_enable => pore_rom_enable,
         pore_rom_busy => pore_rom_busy,       
         til_reg0_enable => til_reg0_enable,
         til_reg1_enable => til_reg1_enable,
         switch_reg_enable => switch_reg_enable,
         kbd_en => kbd_en,
         kbd_we => kbd_we,
         kbd_reg => kbd_reg,
         tin_en => tin_en,
         tin_we => tin_we,
         tin_reg => tin_reg,         
         vga_en => vga_en,
         vga_we => vga_we,
         vga_reg => vga_reg,
         uart_en => uart_en,
         uart_we => uart_we,
         uart_reg => uart_reg,
         uart_cpu_ws => uart_cpu_ws,
         cyc_en => cyc_en,
         cyc_we => cyc_we,
         cyc_reg => cyc_reg,
         ins_en => ins_en,
         ins_we => ins_we,
         ins_reg => ins_reg,         
         eae_en => eae_en,
         eae_we => eae_we,
         eae_reg => eae_reg,
         sd_en => sd_en,
         sd_we => sd_we,
         sd_reg => sd_reg,
         cbt_en => cbt_en,
         cbt_we => cbt_we,
         cbt_reg => cbt_reg,
         reset_pre_pore => reset_pre_pore,
         reset_post_pore => reset_post_pore
      );
   
   -- handle the toggle switches
   switch_driver : process(switch_reg_enable, SWITCHES)
   begin
      if switch_reg_enable = '1' then
         switch_data_out <= SWITCHES;
      else
         switch_data_out <= (others => '0');
      end if;
   end process;
   
   -- clock divider: create a 50 MHz clock from the 100 MHz input
   generate_slow_clock : process(CLK)
   begin
      if rising_edge(CLK) then
         SLOW_CLOCK <= not SLOW_CLOCK;
      end if;      
   end process;
   
   -- clock divider of the clock divider: create a 25 MHz clock from the 50 MHz clock
--   generate_clk25MHz : process(SLOW_CLOCK)
--   begin
--      if rising_edge(SLOW_CLOCK) then
--         clk25MHz <= not clk25MHz;
--      end if;
--   end process;
       
   -- debug mode handling: if switch 2 is on then:
   --   show the current cpu address in realtime on the LEDs
   --   on halt show the PC of the HALT command (aka address bus value) on TIL
   debug_mode_handler : process(SWITCHES, cpu_addr, cpu_data_out, cpu_halt, til_reg0_enable)
   begin
      i_til_reg0_enable <= til_reg0_enable;
      i_til_data_in <= cpu_data_out;
      LEDs <= cpu_halt & "000000000000000";
   
      -- debug mode
      if SWITCHES(2) = '1' then
         LEDs <= cpu_addr;
      
         if cpu_halt = '1' then
            i_til_reg0_enable <= '1';
            i_til_data_in <= cpu_addr;            
         end if;
      end if;
   end process;
       
   -- wire the simplified color system of the VGA component to the VGA outputs
   VGA_RED   <= vga_r & vga_r & vga_r & vga_r;
   VGA_GREEN <= vga_g & vga_g & vga_g & vga_g;
   VGA_BLUE  <= vga_b & vga_b & vga_b & vga_b;
   
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';
   
   -- pull DAT1, DAT2 and DAT3 to GND (Nexys' pull-ups by default pull to VDD)
   SD_DAT <= "000";
end beh;

