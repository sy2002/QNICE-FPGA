----------------------------------------------------------------------------------
-- Counter that counts to COUNTER_FINISH and then fires 'overflow' for one 'clk'
-- cycle. It offers an async 'reset' and outputs the current value at 'cnt'
--
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SyTargetCounter is
generic (
   COUNTER_FINISH : integer;                 -- target value
   COUNTER_WIDTH  : integer range 2 to 32    -- bit width of target value
);
port (
   clk       : in std_logic;                 -- clock
   reset     : in std_logic;                 -- async reset
   
   cnt       : out std_logic_vector(COUNTER_WIDTH - 1 downto 0); -- current value
   overflow  : out std_logic := '0' -- true for one clock cycle when the counter wraps around
);
end SyTargetCounter;

architecture beh of SyTargetCounter is

signal TheCounter : std_logic_vector(COUNTER_WIDTH - 1 downto 0) := (others => '0');

begin
   cnt <= TheCounter;

   count_clocks : process (clk, reset)
   begin 
      if reset = '1' then
         TheCounter <= (others => '0');
      elsif rising_edge(clk) then      
         -- working with a "=" instead of a "<" is more efficient (faster, less gates)
         -- because checking for "=" is easy and needs no "maths"
         if TheCounter = COUNTER_FINISH then
            TheCounter <= (others => '0');
            overflow <= '1';        
         else
            TheCounter <= TheCounter + 1;
            overflow <= '0';        
         end if;
      end if;
   end process;

end beh;
