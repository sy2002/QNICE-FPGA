-- This is the top level entity used to synthesize the pipelined CPU.
-- There is an accompanying project file in cpu_pipeline/cpu_pipeline.xpr and
-- an associated constraint file in top.xdc.
-- The LED output is connected to the PC of the CPU.

library ieee;
use ieee.std_logic_1164.all;

entity top is
   generic (
      G_ROM_FILE : string := "prog.rom"
   );
   port (
      clk_i  : in  std_logic;
      rstn_i : in  std_logic;
      led_o  : out std_logic_vector(15 downto 0)
   );
end entity top;

architecture synthesis of top is

   signal clk : std_logic;
   signal rst : std_logic;

begin

   -- Instantiate custom clock signal
   i_clk : entity work.clk
      port map (
         clk_i => clk_i,
         clk_o => clk
      ); -- i_clk

   -- Make sure the reset signal is synchronized to the clock
   p_rst : process (clk)
   begin
      if rising_edge(clk) then
         rst <= not rstn_i;
      end if;
   end process p_rst;

   i_system : entity work.system
      port map (
         clk_i => clk,
         rst_i => rst,
         led_o => led_o
      ); -- i_system

end architecture synthesis;

