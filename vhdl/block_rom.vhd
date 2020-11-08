-- Block ROM (synchronous)
-- based on block_ram.vhd and rom_from_file.vhd
-- done by sy2002 in August 2015
-- refactored by MJoergen and sy2002 in 2020

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;

entity BROM is
generic (
   FILE_NAME   : string;
   ROM_WIDTH   : integer := 16
);
port (
   clk         : in std_logic;                        -- read and write on rising clock edge
   ce          : in std_logic;                        -- chip enable, when low then zero on output

   address     : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   data        : out std_logic_vector(ROM_WIDTH - 1 downto 0);   -- read data

   -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA, goes zero
   -- if not needed (ce = 0) and can therefore directly be connected to a bus
   busy        : out std_logic
);
end BROM;

architecture beh of BROM is

signal output : std_logic_vector(ROM_WIDTH - 1 downto 0);

signal counter : std_logic := '1'; -- important to be initialized to one
signal address_old : std_logic_vector(14 downto 0) := (others => 'U');
signal async_reset : std_logic;

impure function get_lines_in_romfile(rom_file_name : in string) return natural is
   file     rom_file  : text is in rom_file_name;
   variable line_v    : line;
   variable lines_v   : natural := 0;
begin
   while not endfile(rom_file) loop
      readline(rom_file, line_v);   -- Just ignore the line read from the file.
      lines_v := lines_v + 1;
   end loop;
   return lines_v;
end function;

constant C_LINES : natural := get_lines_in_romfile(FILE_NAME);

type brom_t is array (0 to C_LINES - 1) of bit_vector(ROM_WIDTH - 1 downto 0);

impure function read_romfile(rom_file_name : in string) return brom_t is
   file     rom_file  : text is in rom_file_name;
   variable line_v    : line;
   variable rom_v     : brom_t;
begin
   for i in brom_t'range loop
      if not endfile(rom_file) then
         readline(rom_file, line_v);
         read(line_v, rom_v(i));
      end if;
   end loop;
   return rom_v;
end function;

signal brom : brom_t := read_romfile(FILE_NAME);

begin

   -- process for read and write operation on the rising clock edge
   rom_read : process (clk)
   begin
      if falling_edge(clk) then
         if ce = '1' then
            data <= to_stdlogicvector(brom(conv_integer(address)));
         else
            data <= (others => '0');
         end if;
      end if;
   end process;
   
   busy <= '0';

end beh;
