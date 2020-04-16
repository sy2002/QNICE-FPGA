----------------------------------------------------------------------------------
-- MEGA65 port of QNICE-FGA
--
-- Top Module for synthesizing the whole machine
-- 
-- done on-again-off-again in 2015, 2016 by sy2002
-- MEGA65 port done in April 2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

entity MEGA65 is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button
   
   -- serial communication
   UART_RXD    : in std_logic;                     -- receive data
   UART_TXD    : out std_logic;                    -- send data
--   UART_RTS    : in std_logic;                     -- (active low) equals cts from dte, i.e. fpga is allowed to send to dte
--   UART_CTS    : out std_logic;                    -- (active low) clear to send (dte is allowed to send to fpga)   
      
--   -- PS/2 keyboard
--   PS2_CLK     : in std_logic;
--   PS2_DAT     : in std_logic;

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;
   
   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic
   
--   -- SD Card
--   SD_RESET    : out std_logic;
--   SD_CLK      : out std_logic;
--   SD_MOSI     : out std_logic;
--   SD_MISO     : in std_logic;
--   SD_DAT      : out std_logic_vector(3 downto 1)
); 
end MEGA65;

architecture beh of MEGA65 is

-- QNICE CPU
component QNICE_CPU
port (
   -- clock
   CLK            : in std_logic;
   RESET          : in std_logic;
   
   WAIT_FOR_DATA  : in std_logic;                            -- 1=CPU adds wait cycles while re-reading from bus
      
   ADDR           : out std_logic_vector(15 downto 0);      -- 16 bit address bus
   
   --tristate 16 bit data bus
   DATA           : inout std_logic_vector(15 downto 0);    -- send/receive data
   DATA_DIR       : out std_logic;                          -- 1=DATA is sending, 0=DATA is receiving
   DATA_VALID     : out std_logic;                          -- while DATA_DIR = 1: DATA contains valid data
   
   -- signals about the CPU state
   HALT           : out std_logic                           -- 1=CPU halted due to the HALT command, 0=running   
);
end component;

-- ROM
component BROM is
generic (
   FILE_NAME   : string;
   ROM_LINES   : integer
);
port (
   clk         : in std_logic;                        -- read and write on rising clock edge
   ce          : in std_logic;                        -- chip enable, when low then high impedance on output
   
   address     : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   data        : out std_logic_vector(15 downto 0);   -- read data
   
   busy        : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA               
);
end component;

-- BLOCK RAM
component BRAM is
port (
   clk      : in std_logic;                        -- read and write on rising clock edge
   ce       : in std_logic;                        -- chip enable, when low then high impedance
   
   address  : in std_logic_vector(14 downto 0);    -- address is for now 16 bit hard coded
   we       : in std_logic;                        -- write enable
   data_i   : in std_logic_vector(15 downto 0);    -- write data
   data_o   : out std_logic_vector(15 downto 0);   -- read data
   
   busy     : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA   
);
end component;

-- VGA 80x40 monoschrome screen
component vga_textmode
port (
   reset       : in  std_logic;     -- async reset
   clk         : in std_logic;      -- system clock
   clk50MHz    : in  std_logic;     -- needs to be a 50 MHz clock

   -- VGA registers
   en          : in std_logic;     -- enable for reading from or writing to the bus
   we          : in std_logic;     -- write to VGA's registers via system's data bus
   reg         : in std_logic_vector(3 downto 0);     -- register selector
   data        : inout std_logic_vector(15 downto 0); -- system's data bus
   
   -- VGA signals, monochrome only
   R           : out std_logic;
   G           : out std_logic;
   B           : out std_logic;
   hsync       : out std_logic;
   vsync       : out std_logic;
   pixelclock  : out std_logic
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
   
   -- conntect to CPU's address and data bus (data high impedance when en=0)
   uart_en        : in std_logic;
   uart_we        : in std_logic;
   uart_reg       : in std_logic_vector(1 downto 0);
   cpu_data       : inout std_logic_vector(15 downto 0)
);
end component;

---- PS/2 keyboard
--component keyboard is
--generic (
--   clk_freq      : integer
--);
--port (
--   clk           : in std_logic;               -- system clock input
--   reset         : in std_logic;               -- system reset
--
--   -- PS/2
--   ps2_clk       : in std_logic;               -- clock signal from PS/2 keyboard
--   ps2_data      : in std_logic;               -- data signal from PS/2 keyboard
--   
--   -- conntect to CPU's data bus (data high impedance when all reg_* are 0)
--   kbd_en        : in std_logic;
--   kbd_we        : in std_logic;
--   kbd_reg       : in std_logic_vector(1 downto 0);   
--   cpu_data      : inout std_logic_vector(15 downto 0)
--);
--end component;

-- clock cycle counter
component cycle_counter is
port (
   clk      : in std_logic;         -- system clock
   reset    : in std_logic;         -- async reset
   
   -- cycle counter's registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to VGA's registers via system's data bus
   reg      : in std_logic_vector(1 downto 0);     -- register selector
   data     : inout std_logic_vector(15 downto 0)  -- system's data bus
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
   data     : inout std_logic_vector(15 downto 0)  -- system's data bus
);
end component;

---- SD Card
--component sdcard is
--port (
--   clk      : in std_logic;         -- system clock
--   reset    : in std_logic;         -- async reset
--   
--   -- registers
--   en       : in std_logic;         -- enable for reading from or writing to the bus
--   we       : in std_logic;         -- write to the registers via system's data bus
--   reg      : in std_logic_vector(2 downto 0);      -- register selector
--   data     : inout std_logic_vector(15 downto 0);  -- system's data bus
--   
--   -- hardware interface
--   sd_reset : out std_logic;
--   sd_clk   : out std_logic;
--   sd_mosi  : out std_logic;
--   sd_miso  : in std_logic
--);
--end component;


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
   vga_en            : out std_logic;
   vga_we            : out std_logic;
   vga_reg           : out std_logic_vector(3 downto 0);
   uart_en           : out std_logic;
   uart_we           : out std_logic;
   uart_reg          : out std_logic_vector(1 downto 0);
   cyc_en            : out std_logic;
   cyc_we            : out std_logic;
   cyc_reg           : out std_logic_vector(1 downto 0);
   eae_en            : out std_logic;
   eae_we            : out std_logic;
   eae_reg           : out std_logic_vector(2 downto 0);
   sd_en             : out std_logic;
   sd_we             : out std_logic;
   sd_reg            : out std_logic_vector(2 downto 0);   
   reset_pre_pore    : out std_logic;
   reset_post_pore   : out std_logic   
);
end component;

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data               : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;

-- MMIO control signals
signal rom_enable             : std_logic;
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal rom_busy               : std_logic;
signal pore_rom_enable        : std_logic;
signal pore_rom_busy          : std_logic;
signal til_reg0_enable        : std_logic;
signal til_reg1_enable        : std_logic;
signal switch_reg_enable      : std_logic;
signal kbd_en                 : std_logic;
signal kbd_we                 : std_logic;
signal kbd_reg                : std_logic_vector(1 downto 0);
signal vga_en                 : std_logic;
signal vga_we                 : std_logic;
signal vga_reg                : std_logic_vector(3 downto 0);
signal uart_en                : std_logic;
signal uart_we                : std_logic;
signal uart_reg               : std_logic_vector(1 downto 0);
signal cyc_en                 : std_logic;
signal cyc_we                 : std_logic;
signal cyc_reg                : std_logic_vector(1 downto 0);
signal eae_en                 : std_logic;
signal eae_we                 : std_logic;
signal eae_reg                : std_logic_vector(2 downto 0);
signal sd_en                  : std_logic;
signal sd_we                  : std_logic;
signal sd_reg                 : std_logic_vector(2 downto 0); 

signal reset_pre_pore         : std_logic;
signal reset_post_pore        : std_logic;

-- VGA control signals
signal vga_r                  : std_logic;
signal vga_g                  : std_logic;
signal vga_b                  : std_logic;

-- 50 MHz as long as we did not solve the timing issues of the register file
signal SLOW_CLOCK             : std_logic := '0';

-- combined pre- and post pore reset
signal reset_ctl              : std_logic;

-- enable displaying of address bus on system halt, if switch 2 is on
signal i_til_reg0_enable      : std_logic;
signal i_til_data_in          : std_logic_vector(15 downto 0);

-- emulate the switches on the Nexys4 dev board to toggle VGA and PS/2
signal SWITCHES               : std_logic_vector(15 downto 0);

begin

   -- QNICE CPU
   cpu : QNICE_CPU
      port map (
         CLK => SLOW_CLOCK,
         RESET => reset_ctl,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA => cpu_data,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : BROM
      generic map (
         FILE_NAME   => ROM_FILE,
         ROM_LINES   => ROM_SIZE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => cpu_data,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : BRAM
      port map (
         clk         => SLOW_CLOCK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data,
         data_o      => cpu_data,
         busy        => ram_busy         
      );
      
   -- PORE ROM: Power On & Reset Execution ROM
   -- contains code that is executed during power on and/or during reset
   -- MMIO is managing the PORE process
   pore_rom : BROM
      generic map (
         FILE_NAME   => PORE_ROM_FILE,
         ROM_LINES   => PORE_ROM_SIZE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => pore_rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => cpu_data,
         busy        => pore_rom_busy
      );
                 
   -- VGA: 80x40 textmode VGA adaptor
   vga_screen : vga_textmode
      port map (
         reset => reset_ctl,
         clk => SLOW_CLOCK,
         clk50MHz => SLOW_CLOCK,
         R => vga_r,
         G => vga_g,
         B => vga_b,
         hsync => VGA_HS,
         vsync => VGA_VS,
         pixelclock => vdac_clk,
         en => vga_en,
         we => vga_we,
         reg => vga_reg,
         data => cpu_data
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
         rts => '0',      -- TODO
         cts => open,     -- TODO
         uart_en => uart_en,
         uart_we => uart_we,
         uart_reg => uart_reg,
         cpu_data => cpu_data         
      );

--   -- PS/2 keyboard
--   kbd : keyboard
--      generic map (
--         clk_freq => 50000000                -- see @TODO in keyboard.vhd and TODO.txt
--      )
--      port map (
--         clk => SLOW_CLOCK,
--         reset => reset_ctl,
--         ps2_clk => PS2_CLK,
--         ps2_data => PS2_DAT,
--         kbd_en => kbd_en,
--         kbd_we => kbd_we,
--         kbd_reg => kbd_reg,
--         cpu_data => cpu_data
--      );
      
   -- cycle counter
   cyc : cycle_counter
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         en => cyc_en,
         we => cyc_we,
         reg => cyc_reg,
         data => cpu_data
      );
      
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : eae
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         en => eae_en,
         we => eae_we,
         reg => eae_reg,
         data => cpu_data         
      );

--   -- SD Card
--   sd_card : sdcard
--      port map (
--         clk => SLOW_CLOCK,
--         reset => reset_ctl,
--         en => sd_en,
--         we => sd_we,
--         reg => sd_reg,
--         data => cpu_data,
--         sd_reset => SD_RESET,
--         sd_clk => SD_CLK,
--         sd_mosi => SD_MOSI,
--         sd_miso => SD_MISO
--      );
                        
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
         vga_en => vga_en,
         vga_we => vga_we,
         vga_reg => vga_reg,
         uart_en => uart_en,
         uart_we => uart_we,
         uart_reg => uart_reg,
         cyc_en => cyc_en,
         cyc_we => cyc_we,
         cyc_reg => cyc_reg,
         eae_en => eae_en,
         eae_we => eae_we,
         eae_reg => eae_reg,
         sd_en => sd_en,
         sd_we => sd_we,
         sd_reg => sd_reg,
         reset_pre_pore => reset_pre_pore,
         reset_post_pore => reset_post_pore
      );
   
   -- handle the toggle switches
   switch_driver : process(switch_reg_enable, SWITCHES)
   begin
      if switch_reg_enable = '1' then
         cpu_data <= SWITCHES;
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;
   
   -- clock divider: create a 50 MHz clock from the 100 MHz input
   generate_slow_clock : process(CLK)
   begin
      if rising_edge(CLK) then
         SLOW_CLOCK <= not SLOW_CLOCK;
      end if;
   end process;
              
   -- wire the simplified color system of the VGA component to the VGA outputs
   VGA_RED   <= vga_r & vga_r & vga_r & vga_r & vga_r & vga_r & vga_r & vga_r;
   VGA_GREEN <= vga_g & vga_g & vga_g & vga_g & vga_g & vga_g & vga_g & vga_g;
   VGA_BLUE  <= vga_b & vga_b & vga_b & vga_b & vga_b & vga_b & vga_b & vga_b;
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';
   
   -- emulate the switches on the Nexys4 to toggle VGA and PS/2 keyboard
   SWITCHES <= "0000000000000010";
   
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';
   
   -- pull DAT1, DAT2 and DAT3 to GND (Nexys' pull-ups by default pull to VDD)
   --SD_DAT <= "000";
end beh;

