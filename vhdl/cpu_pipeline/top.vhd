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

   signal rst         : std_logic;
   signal mem_address : std_logic_vector(15 downto 0);
   signal mem_wr_data : std_logic_vector(15 downto 0);
   signal mem_write   : std_logic;
   signal mem_rd_data : std_logic_vector(15 downto 0);
   signal mem_read    : std_logic;

begin

   -- Make sure the reset signal is synchronized to the clock
   p_rst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rst <= not rstn_i;
      end if;
   end process p_rst;

   i_cpu_pipeline : entity work.cpu_pipeline
      port map (
         clk_i         => clk_i,
         rst_i         => rst,
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
         rst_i     => rst,
         address_i => mem_address,
         wr_data_i => mem_wr_data,
         write_i   => mem_write,
         rd_data_o => mem_rd_data,
         read_i    => mem_read
      ); -- i_memory

end architecture synthesis;

