library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity vga_test is
   port (
      clk_i        : in  std_logic;            -- System clock (100 MHz)

      vga_hsync_o  : out std_logic;
      vga_vsync_o  : out std_logic;
      vga_colour_o : out std_logic_vector(11 downto 0)
   );
end vga_test;

architecture synthesis of vga_test is

   signal clkfbout_raw : std_logic;
   signal cpu_clk_raw  : std_logic;
   signal vga_clk_raw  : std_logic;

   signal clkfbout     : std_logic;
   signal cpu_clk      : std_logic;
   signal vga_clk      : std_logic;

begin

   -- Instantiation of the MMCM PRIMITIVE
   mmcm_adv_inst : MMCME2_ADV
   generic map (
      BANDWIDTH            => "OPTIMIZED",
      CLKOUT4_CASCADE      => FALSE,
      COMPENSATION         => "ZHOLD",
      STARTUP_WAIT         => FALSE,
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT_F      => 10.500,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => FALSE,
      CLKOUT0_DIVIDE_F     => 21.000, -- CPU @ 50 MHz
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_USE_FINE_PS  => FALSE,
      CLKOUT1_DIVIDE       => 42,     -- VGA @ 25 MHz
      CLKOUT1_PHASE        => 0.000,
      CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKOUT1_USE_FINE_PS  => FALSE,
      CLKIN1_PERIOD        => 10.0,
      REF_JITTER1          => 0.010
   )
   port map
   -- Output clocks
   (
      CLKFBOUT            => clkfbout_raw,
      CLKFBOUTB           => open,
      CLKOUT0             => cpu_clk_raw,
      CLKOUT0B            => open,
      CLKOUT1             => vga_clk_raw,
      CLKOUT1B            => open,
      CLKOUT2             => open,
      CLKOUT2B            => open,
      CLKOUT3             => open,
      CLKOUT3B            => open,
      CLKOUT4             => open,
      CLKOUT5             => open,
      CLKOUT6             => open,
       -- Input clock control
      CLKFBIN             => clkfbout,
      CLKIN1              => clk_i,
      CLKIN2              => '0',
      -- Tied to always select the primary input clock
      CLKINSEL            => '1',
      -- Ports for dynamic reconfiguration
      DADDR               => (others => '0'),
      DCLK                => '0',
      DEN                 => '0',
      DI                  => (others => '0'),
      DO                  => open,
      DRDY                => open,
      DWE                 => '0',
      -- Ports for dynamic phase shift
      PSCLK               => '0',
      PSEN                => '0',
      PSINCDEC            => '0',
      PSDONE              => open,
      -- Other control and status signals
      LOCKED              => open,
      CLKINSTOPPED        => open,
      CLKFBSTOPPED        => open,
      PWRDWN              => '0',
      RST                 => '0'
   );


   -- Output buffering
   -------------------------------------

   clkf_buf : BUFG
   port map (
      I => clkfbout_raw,
      O => clkfbout
   );


   clkout1_buf : BUFG
   port map (
      I   => cpu_clk_raw,
      O   => cpu_clk
   );

   clkout2_buf : BUFG
   port map (
      I   => vga_clk_raw,
      O   => vga_clk
   );


   i_vga_multicolour : entity work.vga_multicolour
      port map (
         cpu_clk_i     => cpu_clk,
         cpu_rst_i     => '1',
         cpu_en_i      => '0',
         cpu_we_i      => '0',
         cpu_reg_i     => (others => '0'),
         cpu_data_i    => (others => '0'),
         cpu_data_o    => open,
         vga_clk_i     => vga_clk,
         vga_hsync_o   => vga_hsync_o,
         vga_vsync_o   => vga_vsync_o,
         vga_colour_o  => vga_colour_o,
         vga_data_en_o => open
      ); -- i_vga_multicolour

end synthesis;


