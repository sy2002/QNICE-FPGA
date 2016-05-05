----------------------------------------------------------------------------------
-- @TODO: find name for the overall computer system (QBM-1?)
--
-- Top Module for synthesizing the whole machine
-- 
-- done on-again-off-again in 2015, 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

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
   vga_red     : out std_logic_vector(3 downto 0);
   vga_green   : out std_logic_vector(3 downto 0);
   vga_blue    : out std_logic_vector(3 downto 0);
   vga_hs      : out std_logic;
   vga_vs      : out std_logic
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
   reset    : in  std_logic;     -- async reset
   clk      : in std_logic;      -- system clock
   clk50MHz : in  std_logic;     -- needs to be a 50 MHz clock

   -- VGA registers
   en       : in std_logic;     -- enable for reading from or writing to the bus
   we       : in std_logic;     -- write to VGA's registers via system's data bus
   reg      : in std_logic_vector(3 downto 0);     -- register selector
   data     : inout std_logic_vector(15 downto 0); -- system's data bus
   
   -- VGA signals, monochrome only
   R        : out std_logic;
   G        : out std_logic;
   B        : out std_logic;
   hsync    : out std_logic;
   vsync    : out std_logic
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
   
   -- conntect to CPU's address and data bus (data high impedance when en=0)
   uart_en        : in std_logic;
   uart_we        : in std_logic;
   uart_reg       : in std_logic_vector(1 downto 0);
   cpu_data       : inout std_logic_vector(15 downto 0)
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
   
   -- conntect to CPU's data bus (data high impedance when all reg_* are 0)
   kbd_en        : in std_logic;
   kbd_we        : in std_logic;
   kbd_reg       : in std_logic_vector(1 downto 0);   
   cpu_data      : inout std_logic_vector(15 downto 0)
);
end component;

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
         hsync => vga_hs,
         vsync => vga_vs,
         en => vga_en,
         we => vga_we,
         reg => vga_reg,
         data => cpu_data
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
         cpu_data => cpu_data         
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
         cpu_data => cpu_data
      );
      
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
       
   -- debug mode handling: if switch 2 is on then:
   --   show the current cpu address in realtime on the LEDs
   --   on halt show the last PC (aka cpu address) on TIL
   debug_mode_handler : process(SWITCHES, cpu_data, cpu_halt, til_reg0_enable)
   variable halt_address : unsigned(15 downto 0);
   begin
      -- debug mode
      if SWITCHES(2) = '1' then
         if cpu_halt = '1' then
            halt_address := unsigned(cpu_addr) - 1;
            i_til_reg0_enable <= '1';
            i_til_data_in <= std_logic_vector(halt_address);
         else
            i_til_reg0_enable <= til_reg0_enable;
            i_til_data_in <= cpu_data;
            
            LEDs <= cpu_addr;
         end if;
      
      -- normal mode
      else
         i_til_reg0_enable <= til_reg0_enable;
         i_til_data_in <= cpu_data;
      
         -- HALT LED: LED #15
         LEDs <= cpu_halt & "000000000000000";
      end if;
   end process;
       
   -- wire the simplified color system of the VGA component to the VGA outputs
   vga_red <= vga_r & vga_r & vga_r & vga_r;
   vga_green <= vga_g & vga_g & vga_g & vga_g;
   vga_blue <= vga_b & vga_b & vga_b & vga_b;
   
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';
end beh;

