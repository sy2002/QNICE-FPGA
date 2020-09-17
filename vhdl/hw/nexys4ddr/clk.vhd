library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk is
   port (
      sys_clk_i  : in  std_logic;
      clk25MHz_o : out std_logic;
      clk50MHz_o : out std_logic
   );
end clk;

architecture rtl of clk is

   signal clkfb      : std_logic;
   signal clkfb_mmcm : std_logic;
   signal clk25_mmcm : std_logic;
   signal clk50_mmcm : std_logic;

begin

   i_mmcme2_adv : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,      -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => 8.000,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 31.750,    -- VGA @ 25.20 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 16,        -- MAIN @ 50.00 MHz
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb_mmcm,
         CLKOUT0             => clk25_mmcm,
         CLKOUT1             => clk50_mmcm,
         -- Input clock control
         CLKFBIN             => clkfb,
         CLKIN1              => sys_clk_i,
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


   -------------------------------------
   -- Output buffering
   -------------------------------------

   clkfb_bufg : BUFG
      port map (
         I => clkfb_mmcm,
         O => clkfb
      );

   clk25_bufg : BUFG
      port map (
         I => clk25_mmcm,
         O => clk25MHz_o
      );

   clk50_bufg : BUFG
      port map (
         I => clk50_mmcm,
         O => clk50MHz_o
      );

end architecture rtl;

