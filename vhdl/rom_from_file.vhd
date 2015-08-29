-- Simple asynchronous ROM (no clock) that is initialized from a file
-- if not "en", then high impedance on "data", i.e. the ROM can be directly connected to a bus
-- done by sy2002 in July 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;


entity ROM_FROM_FILE is
generic (
   ADDR_WIDTH : integer range 2 to 64;    -- address width
   DATA_WIDTH : integer range 2 to 64;    -- word width of ROM output port (aka DATA)
   SIZE       : integer;                  -- amount of words (aka lines in input file)
   FILE_NAME  : string                    -- name of input file; input file format:
                                          -- DATA_WIDTH bits, written as 0 and 1 in each line
);
port (
   en    : in std_logic;                                 -- new values only if enable is 1
   addr  : in std_logic_vector(ADDR_WIDTH - 1 downto 0); -- address
   data  : out std_logic_vector(DATA_WIDTH - 1 downto 0) -- data located at address
);
end ROM_FROM_FILE;

architecture beh of ROM_FROM_FILE is

type romtype is array(0 to SIZE - 1) of bit_vector(DATA_WIDTH - 1 downto 0);

impure function read_romfile(rom_file_name : in string) return romtype is
   file     rom_file  : text is in rom_file_name;                       
   variable line_v    : line;                                 
   variable rom_v     : romtype;
begin                                                        
   for i in romtype'range loop  
      readline(rom_file, line_v);                             
      read(line_v, rom_v(i));                                  
   end loop;                                                    
   return rom_v;                                                  
end function;

signal rom : romtype := read_romfile(FILE_NAME);

begin

   with en select
      data <= to_stdlogicvector(rom(conv_integer(addr))) when '1',
              (others => 'Z') when '0',
              (others => 'U') when others;

end beh;
