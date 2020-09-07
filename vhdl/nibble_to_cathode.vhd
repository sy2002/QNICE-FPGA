----------------------------------------------------------------------------------
-- Create cathode signals for the Nexys 4 DDR 7-segment display.
-- The nibble_to_cathode entity is used by the drive_7digits driver.
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- map a 4 bit number (aka nibble) to a bit pattern that
-- drives the cathode in the right way to display a hex number
-- on the Nexys 4 DDR board
entity nibble_to_cathode is
port (
   nibble   : in std_logic_vector(3 downto 0);
   cathode  : out std_logic_vector(7 downto 0)
);
end nibble_to_cathode;

architecture beh_ntc of nibble_to_cathode is
begin
   with nibble select
      -- cathode: low means active
      cathode <= "11000000" when "0000", -- 0
                 "11111001" when "0001", -- 1
                 "10100100" when "0010", -- 2
                 "10110000" when "0011", -- 3
                 "10011001" when "0100", -- 4
                 "10010010" when "0101", -- 5
                 "10000010" when "0110", -- 6
                 "11111000" when "0111", -- 7
                 "10000000" when "1000", -- 8
                 "10010000" when "1001", -- 9
                 "10001000" when "1010", -- 10 = A
                 "10000011" when "1011", -- 11 = b
                 "11000110" when "1100", -- 12 = C
                 "10100001" when "1101", -- 13 = d
                 "10000110" when "1110", -- 14 = E
                 "10001110" when "1111", -- 15 = F
                 "11111111" when others;  
end beh_ntc;