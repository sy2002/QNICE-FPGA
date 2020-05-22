-- 8-bit data video BRAM with a 16-bit address bus
-- reads and writes on the rising clock edge
-- meant to be connected with vga80x40.vhd
-- can be used as a ROM (in the sense of a prefilled RAM), if the string
-- CONTENT_FILE is not empty and a valid .rom file is specified
-- additionally, for performant reading, there is a separately clocked 32-bit data reading facility
-- done by sy2002 in December 2015

-- inspired by 
-- http://vhdlguru.blogspot.de/2011/01/block-and-distributed-rams-on-xilinx.html

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;

entity video_bram is
generic (
   SIZE_BYTES     : integer;
   CONTENT_FILE   : string;
   FILE_LINES     : integer;
   DEFAULT_VALUE  : bit_vector
);
port (
   clk            : in std_logic;

   we             : in std_logic;   
   address_i      : in std_logic_vector(15 downto 0);
   data_i         : in std_logic_vector(7 downto 0);

   address1_o     : in std_logic_vector(15 downto 0);
   data1_o        : out std_logic_vector(7 downto 0);
   address2_o     : in std_logic_vector(15 downto 0);
   data2_o        : out std_logic_vector(7 downto 0)
);
end video_bram;

architecture beh of video_bram is

type ram_t is array (0 to SIZE_BYTES - 1) of bit_vector(7 downto 0);

impure function read_romfile(rom_file_name : in string) return ram_t is
   file     rom_file  : text is in rom_file_name;                       
   variable line_v    : line;                                 
   variable rom_v     : ram_t;
begin
   for i in 0 to SIZE_BYTES - 1 loop
      rom_v(i) := DEFAULT_VALUE;
   end loop;
   
   if FILE_LINES /= 0 then
      for i in 0 to FILE_LINES - 1 loop  
         readline(rom_file, line_v);                             
         read(line_v, rom_v(i));                                  
      end loop;
   end if;
   
   return rom_v;                                                  
end function;

signal ram : ram_t := read_romfile(CONTENT_FILE);

attribute ramstyle : string;
attribute ramstyle of ram : signal is "block";

begin

-- process for read and write operation
process (clk)
begin
    if rising_edge(clk) then
        if(we = '1') then
            ram(conv_integer(address_i)) <= to_bitvector(data_i);
        end if;
        data1_o <= to_stdlogicvector(ram(conv_integer(address1_o)));
        data2_o <= to_stdlogicvector(ram(conv_integer(address2_o)));
    end if;
end process;

end beh;
