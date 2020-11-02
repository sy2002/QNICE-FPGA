library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_pipeline is
end entity tb_cpu_pipeline;

architecture simulation of tb_cpu_pipeline is

   signal clk         : std_logic;
   signal rst         : std_logic;
   signal mem_address : std_logic_vector(15 downto 0);
   signal mem_wr_data : std_logic_vector(15 downto 0);
   signal mem_write   : std_logic;
   signal mem_rd_data : std_logic_vector(15 downto 0);
   signal mem_read    : std_logic;

begin

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns; -- 100 MHz
   end process p_clk;

   rst <= '1', '0' after 100 ns;

   i_cpu_pipeline : entity work.cpu_pipeline
      port map (
         clk_i         => clk,
         rst_i         => rst,
         mem_address_o => mem_address,
         mem_wr_data_o => mem_wr_data,
         mem_write_o   => mem_write,
         mem_rd_data_i => mem_rd_data,
         mem_read_o    => mem_read
      ); -- i_cpu_pipeline

   i_memory : entity work.memory
      port map (
         clk_i     => clk,
         rst_i     => rst,
         address_i => mem_address,
         wr_data_i => mem_wr_data,
         write_i   => mem_write,
         rd_data_o => mem_rd_data,
         read_i    => mem_read
      ); -- i_memory

end architecture simulation;

