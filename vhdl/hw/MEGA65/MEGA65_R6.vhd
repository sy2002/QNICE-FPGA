----------------------------------------------------------------------------------
-- MEGA65 port of QNICE-FGA
--
-- Top Module for synthesizing the whole machine
--
-- done on-again-off-again in 2015, 2016 by sy2002
-- MEGA65 port done in April to August 2020 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity MEGA65 is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button

   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                     -- receive data
   UART_TXD       : out std_logic;                    -- send data

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard

   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;

   -- Built-in HyperRAM
   hr_d           : inout unsigned(7 downto 0);    -- Data/Address
   hr_rwds        : inout std_logic;               -- RW Data strobe
   hr_reset       : out std_logic;                 -- Active low RESET line to HyperRAM
   hr_clk_p       : out std_logic;
   hr_cs0         : out std_logic
);
end entity MEGA65;

architecture beh of MEGA65 is

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
signal hram_en                : std_logic;
signal hram_we                : std_logic;
signal hram_reg               : std_logic_vector(3 downto 0);
signal hram_data_out          : std_logic_vector(15 downto 0);
signal hram_cpu_ws            : std_logic;

signal reset_pre_pore         : std_logic;
signal reset_post_pore        : std_logic;

-- VGA control signals
signal vga_r                  : std_logic;
signal vga_g                  : std_logic;
signal vga_b                  : std_logic;
signal vga_hsync              : std_logic;
signal vga_vsync              : std_logic;

-- 50 MHz as long as we did not solve the timing issues of the register file
signal SLOW_CLOCK             : std_logic := '0';

-- Pixelclock and fast clock for HRAM
signal CLK1x                  : std_logic;   -- 100 MHz clock created by mmcme2 for congruent phase
signal CLK2x                  : std_logic;   -- 4x SLOW_CLOCK = 200 MHz
signal clk25MHz               : std_logic;   -- 25.175 MHz pixelclock for 640x480 @ 60 Hz
signal pll_locked_main        : std_logic;
signal clk_fb_main            : std_logic;

-- combined pre- and post pore reset
signal reset_ctl              : std_logic;

-- enable displaying of address bus on system halt, if switch 2 is on
signal i_til_reg0_enable      : std_logic;
signal i_til_data_in          : std_logic_vector(15 downto 0);

-- emulate the switches on the Nexys4 dev board to toggle VGA and PS/2
signal SWITCHES               : std_logic_vector(15 downto 0);

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
                  sd_data_out       or
                  hram_data_out;

  clk_main: mmcme2_base
  generic map
  (
    clkin1_period    => 10.0,       --   100 MHz (10 ns)
    clkfbout_mult_f  => 8.0,        --   800 MHz common multiply
    divclk_divide    => 1,          --   800 MHz /1 common divide to stay within 600MHz-1600MHz range
    clkout0_divide_f => 31.75,      --   Should be 25.175 MHz, but actual value is 25.197 MHz
    clkout1_divide   => 8,          --   100 MHz /8
    clkout2_divide   => 16,         --   50  MHz /16
    clkout3_divide   => 4          --    200 MHz /4
  )
  port map
  (
    pwrdwn   => '0',
    rst      => '0',
    clkin1   => CLK,
    clkfbin  => clk_fb_main,
    clkfbout => clk_fb_main,
    clkout0  => clk25MHz,           --  pixelclock
    clkout1  => CLK1x,              --  100 MHz
    clkout2  => SLOW_CLOCK,         --  50 MHz
    clkout3  => CLK2x,              --  200 MHz
    locked   => pll_locked_main
  );

   -- QNICE CPU
   cpu : entity work.QNICE_CPU
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
   rom : entity work.BROM
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
   ram : entity work.BRAM
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
   pore_rom : entity work.BROM
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
   vga_screen : entity work.vga_textmode
      port map (
         reset => reset_ctl,
         clk25MHz => clk25MHz,
         clk50MHz => SLOW_CLOCK,
         R => vga_r,
         G => vga_g,
         B => vga_b,
         hsync => vga_hsync,
         vsync => vga_vsync,
         hdmi_de => open,
         en => vga_en,
         we => vga_we,
         reg => vga_reg,
         data_in => cpu_data_out,
         data_out => vga_data_out
      );

   -- special UART with FIFO that can be directly connected to the CPU bus
   uart : entity work.bus_uart
      generic map (
         DIVISOR => UART_DIVISOR
      )
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         rx => UART_RXD,
         tx => UART_TXD,
         rts => '0',
         cts => open,
         uart_en => uart_en,
         uart_we => uart_we,
         uart_reg => uart_reg,
         uart_cpu_ws => uart_cpu_ws,
         cpu_data_in => cpu_data_out,
         cpu_data_out => uart_data_out
      );

   -- MEGA65 keyboard
   kbd : entity work.keyboard
      generic map (
         clk_freq => 50000000
      )
      port map (
         clk => SLOW_CLOCK,
         reset => reset_ctl,
         kb_io0 => kb_io0,
         kb_io1 => kb_io1,
         kb_io2 => kb_io2,
         kbd_en => kbd_en,
         kbd_we => kbd_we,
         kbd_reg => kbd_reg,
         cpu_data_in => cpu_data_out,
         cpu_data_out => kbd_data_out,
         stdinout => SWITCHES(1 downto 0)
      );

   timer_interrupt : entity work.timer_module
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
   cyc : entity work.cycle_counter
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
   ins : entity work.cycle_counter
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
   eae_inst : entity work.eae
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
   sd_card : entity work.sdcard
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

   -- HyperRAM
   HRAM : entity work.hyperram_ctl
      port map (
         clk => SLOW_CLOCK,
         clk2x => CLK1x,
         clk4x => CLK2x,
         reset => reset_ctl,
         hram_en => hram_en,
         hram_we => hram_we,
         hram_reg => hram_reg,
         hram_cpu_ws => hram_cpu_ws,
         data_in => cpu_data_out,
         data_out => hram_data_out,
         hr_d => hr_d,
         hr_rwds => hr_rwds,
         hr_reset => hr_reset,
         hr_clk_p => hr_clk_p,
         hr_cs0 => hr_cs0
      );

   -- memory mapped i/o controller
   mmio_controller : entity work.mmio_mux
      generic map (
         GD_TIL => false,      -- no support for TIL leds on MEGA65
         GD_SWITCHES => true,  -- we emulate the switch register as described in doc/README.md
         GD_HRAM => true       -- support HyperRAM
      )
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
         hram_en => hram_en,
         hram_we => hram_we,
         hram_reg => hram_reg,
         hram_cpu_ws => hram_cpu_ws,

         -- no TIL leds on the MEGA65         ,
         til_reg0_enable => open,
         til_reg1_enable => open,

         reset_pre_pore => reset_pre_pore,
         reset_post_pore => reset_post_pore
      );

   -- emulate the toggle switches as described in doc/README.md
   switch_driver : process(switch_reg_enable, SWITCHES)
   begin
      if switch_reg_enable = '1' then
         switch_data_out <= SWITCHES;
      else
         switch_data_out <= (others => '0');
      end if;
   end process;

   video_signal_latches : process(clk25MHz)
   begin
      if rising_edge(clk25MHz) then
         -- VGA: wire the simplified color system of the VGA component to the VGA outputs
         VGA_RED     <= vga_r & vga_r & vga_r & vga_r & vga_r & vga_r & vga_r & vga_r;
         VGA_GREEN   <= vga_g & vga_g & vga_g & vga_g & vga_g & vga_g & vga_g & vga_g;
         VGA_BLUE    <= vga_b & vga_b & vga_b & vga_b & vga_b & vga_b & vga_b & vga_b;

         -- VGA horizontal and vertical sync
         VGA_HS      <= vga_hsync;
         VGA_VS      <= vga_vsync;
      end if;
   end process;

   -- make the VDAC output the image
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';

   -- Fix of the Vivado induced "blurry VGA screen":
   -- As of the  time writing this (June 2020): it is absolutely unclear for me, why I need to
   -- invert the phase of the vdac_clk when use Vivado 2019.2. When using ISE 14.7, it works
   -- fine without the phase shift.
   vdac_clk <= not clk25MHz;

   -- emulate the switches on the Nexys4 to toggle VGA and PS/2 keyboard
   -- bit #0: use UART as STDIN (0)  / use MEGA65 keyboard as STDIN (1)
   -- bit #1: use UART AS STDOUT (0) / use VGA as STDOUT (1)
   SWITCHES(15 downto 2) <= "00000000000000";

   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1' or pll_locked_main = '0') else '0';

end architecture beh;

