library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_pipeline is
   generic (
      G_ROM_FILE : string := "prog.rom"
   );
end entity tb_cpu_pipeline;

architecture simulation of tb_cpu_pipeline is

   signal clk  : std_logic;
   signal rstn : std_logic;

begin

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns; -- 100 MHz
   end process p_clk;

   rstn <= '0', '1' after 100 ns;

   i_top : entity work.top
      generic map (
         G_ROM_FILE => G_ROM_FILE
      )
      port map (
         clk_i  => clk,
         rstn_i => rstn,
         led_o  => open
      ); -- i_top

end architecture simulation;

