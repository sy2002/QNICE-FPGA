-- This block sends commands to the SDCard and receives responses.
-- Only one outstanding command is allowed at any time.
-- This module checks for timeout, and always generates a response, when a response is expected.
-- CRC generation is performed on all commands.

-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/SDCard).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdcard_debug is
   port (
      clk_i          : in  std_logic; -- 50 MHz
      rst_i          : in  std_logic;

      data_i         : in  std_logic_vector(7 downto 0);
      valid_i        : in  std_logic;

      data_o         : out std_logic_vector(7 downto 0)
   );
end entity sdcard_debug;

architecture synthesis of sdcard_debug is

   constant C_NUM_ENTRIES : natural := 2**10;

   type ram_t is array (0 to C_NUM_ENTRIES-1) of std_logic_vector(7 downto 0);

   signal ram : ram_t;
   signal wr_ptr : natural range 0 to C_NUM_ENTRIES-1;
   signal rd_ptr : natural range 0 to C_NUM_ENTRIES-1;

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if valid_i = '1' then
            ram(wr_ptr) <= data_i;
            wr_ptr <= wr_ptr + 1;
         end if;

         if rst_i = '1' then
            wr_ptr <= 0;
         end if;
      end if;
   end process p_write;

   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         data_o <= ram(rd_ptr);
         rd_ptr <= rd_ptr + 1;

         if rd_ptr = wr_ptr then
            rd_ptr <= 0;
         end if;

         if rst_i = '1' or valid_i = '1' then
            rd_ptr <= 0;
         end if;
      end if;
   end process p_read;

end architecture synthesis;

