-- 8-bit data dual-clock video BRAM with a 16-bit address bus
-- reads at the rising clock edge of clk1 and clk2
-- if we = 1: writes at the rising clock edge of clk1 only
-- meant to be connected with vga80x40.vhd
-- done by sy2002 in December 2015, refactored in May and June 2020
-- inspired by 
-- http://vhdlguru.blogspot.de/2011/01/block-and-distributed-rams-on-xilinx.html

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;

entity video_bram is
generic (
   SIZE_BYTES     : integer
);
port (
   clk1           : in std_logic;
   we             : in std_logic;   
   address_i      : in std_logic_vector(15 downto 0);
   data_i         : in std_logic_vector(7 downto 0);
   address1_o     : in std_logic_vector(15 downto 0);
   data1_o        : out std_logic_vector(7 downto 0);

   clk2           : in std_logic;
   address2_o     : in std_logic_vector(15 downto 0);
   data2_o        : out std_logic_vector(7 downto 0)
);
end video_bram;

architecture beh of video_bram is

type ram_t is array (0 to SIZE_BYTES - 1) of bit_vector(7 downto 0);

signal ram : ram_t;

attribute ramstyle : string;
attribute ramstyle of ram : signal is "block";

begin

process (clk1)
begin
    if rising_edge(clk1) then
        if we = '1' then
            ram(conv_integer(address_i)) <= to_bitvector(data_i);
        end if;
        data1_o <= to_stdlogicvector(ram(conv_integer(address1_o)));
    end if;
end process;

process (clk2)
begin
    if rising_edge(clk2) then
        data2_o <= to_stdlogicvector(ram(conv_integer(address2_o)));
    end if;
end process;

end beh;
