library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity memory is
   generic (
      G_ROM_FILE : string
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      address_i : in  std_logic_vector(15 downto 0);
      wr_data_i : in  std_logic_vector(15 downto 0);
      write_i   : in  std_logic;
      rd_data_o : out std_logic_vector(15 downto 0);
      read_i    : in  std_logic
   );
end entity memory;

architecture synthesis of memory is

   type mem_t is array (0 to 8191) of std_logic_vector(15 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return mem_t is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable ram : mem_t := (others => (others => '0'));
   begin
      for i in mem_t'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, ram(i));
         if endfile(RamFile) then
            return ram;
         end if;
      end loop;
      return ram;
   end function;

   -- Initialize memory contents
   signal mem_r : mem_t := InitRamFromFile(G_ROM_FILE);

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if write_i = '1' then
            mem_r(conv_integer(address_i)) <= wr_data_i;
         end if;
      end if;
   end process p_write;

   -- Synchronuos read on falling_edge.
   -- To the CPU this appears as a combinatorial read, but
   -- leaves only half a clock cycle for the CPU processing.
   p_read : process (clk_i)
   begin
      if falling_edge(clk_i) then
         rd_data_o <= mem_r(conv_integer(address_i));
      end if;
   end process p_read;

end architecture synthesis;

