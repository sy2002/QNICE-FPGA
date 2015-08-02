-- Block RAM (synchronous)
-- read and write on rising clock edge
-- the RAM is initialized to zero on system start
-- can be directly connected to a bus, as it goes high impedance on low chip enable and on writing
-- can directly control the CPU's WAIT_FOR_DATA line
-- inspired by http://vhdlguru.blogspot.de/2011/01/block-and-distributed-rams-on-xilinx.html
-- done by sy2002 in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.env1_globals.all;

entity BRAM is
port (
   clk      : in std_logic;                        -- read and write on rising clock edge
   ce       : in std_logic;                        -- chip enable, when low then high impedance on output
   
   address  : in std_logic_vector(15 downto 0);    -- address is for now 16 bit hard coded
   we       : in std_logic;                        -- write enable
   data_i   : in std_logic_vector(15 downto 0);    -- write data
   data_o   : out std_logic_vector(15 downto 0);   -- read data
   
   -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA, goes high impedance
   -- if not needed (ce = 0) and can therefore directly be connected to a bus
   busy     : out std_logic                       
);
end BRAM;

architecture beh of BRAM is

type bram_t is array (0 to BLOCK_RAM_SIZE - 1) of std_logic_vector(15 downto 0);
signal bram : bram_t := (others => x"BABA");

signal output : std_logic_vector(15 downto 0);

signal counter : std_logic_vector(1 downto 0) := "00";

signal address_old : std_logic_vector(15 downto 0) := (others => 'U');

begin

   -- process for read and write operation on the rising clock edge
   ram_readwrite : process (clk)
   begin
      if rising_edge(clk) then
         if we = '1' and ce = '1' then
            bram(conv_integer(address)) <= data_i;
         end if;
         
         output <= bram(conv_integer(address));
         
         address_old <= address;
      end if;
   end process;
   
   -- high impedance while not ce OR while writing
   manage_tristate : process (we, ce, output)
   begin
      if (ce = '0') or (ce = '1' and we = '1') then
         data_o <= (others => 'Z');
      else
         data_o <= output;
      end if;
   end process;
   
   -- generate a busy signal for one clock cycle, because this is
   -- the read delay that this block RAM is having
   -- output high impedance when ce = 0 so that the busy line can be
   -- part of a bus
   manage_busy : process (clk, ce, we, counter, address)
   begin
      if rising_edge(ce) and we = '0' and counter = "00" then
         counter <= "01";
      elsif falling_edge(clk) and counter = "01" then
         counter <= "10";
      elsif rising_edge(clk) and counter = "10" then
         counter <= "00";
      elsif address_old /= address and we = '0' and counter = "00" then
         counter <= "01";
      end if;
      
      if ce = '1' then
         busy <= counter(0) or counter(1);
      else
         busy <= 'Z';
      end if;
   end process;
   
end beh;
