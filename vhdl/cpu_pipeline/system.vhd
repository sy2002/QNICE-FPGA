-- This module instantiates the CPU and a small memory
-- It is to be used for both simulation (in tb_system.vhd) and for synthesis (in top.vhd).

library ieee;
use ieee.std_logic_1164.all;

entity system is
   generic (
      G_ROM_FILE : string := "prog.rom"
   );
   port (
      clk_i : in  std_logic;
      rst_i : in  std_logic;
      led_o : out std_logic_vector(15 downto 0)
   );
end entity system;

architecture synthesis of system is

   signal mem_address : std_logic_vector(15 downto 0);
   signal mem_wr_data : std_logic_vector(15 downto 0);
   signal mem_write   : std_logic;
   signal mem_rd_data : std_logic_vector(15 downto 0);
   signal mem_read    : std_logic;

begin

   i_cpu_pipeline : entity work.cpu_pipeline
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         mem_address_o => mem_address,
         mem_wr_data_o => mem_wr_data,
         mem_write_o   => mem_write,
         mem_rd_data_i => mem_rd_data,
         mem_read_o    => mem_read,
         debug_o       => led_o
      ); -- i_cpu_pipeline

   i_memory : entity work.memory
      generic map (
         G_ROM_FILE => G_ROM_FILE
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         address_i => mem_address,
         wr_data_i => mem_wr_data,
         write_i   => mem_write,
         rd_data_o => mem_rd_data,
         read_i    => mem_read
      ); -- i_memory

end architecture synthesis;

