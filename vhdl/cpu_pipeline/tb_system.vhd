library ieee;
use ieee.std_logic_1164.all;

entity tb_system is
end entity tb_system;

architecture simulation of tb_system is

   signal clk : std_logic;
   signal rst : std_logic;

begin

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns; -- 100 MHz
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;

   i_system : entity work.system
      port map (
         clk_i => clk,
         rst_i => rst,
         led_o => open
      ); -- i_system

end architecture simulation;

