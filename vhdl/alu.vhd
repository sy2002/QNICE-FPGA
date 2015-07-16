----------------------------------------------------------------------------------
-- QNICE CPU's ALU
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.cpu_constants.all;

entity alu is
port (
   opcode      : in std_logic_vector(3 downto 0);
   input1      : in signed(15 downto 0);
   input2      : in signed(15 downto 0);
   result      : out signed(15 downto 0)
);
end alu;

architecture beh of alu is
begin

   calculate : process (opcode, input1, input2)
   begin
      case opcode is
         when opcMOVE =>
            result <= input1;
            
         when others =>
            result <= x"0000";
      end case;
   end process;

end beh;

