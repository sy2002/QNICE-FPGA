----------------------------------------------------------------------------------
-- Miscellaneous Tools for QNICE
-- 
-- done in July 2020 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package qnice_tools is

-- calculate the width (amount of bits) needed to store x
function f_log2(x: positive) return natural;

end qnice_tools;

package body qnice_tools is

function f_log2(x: positive) return natural is
variable i : natural;
begin
   i := 0;  
   while (2**i < x) and i < 127 loop
      i := i + 1;
   end loop;
   return i;
end function;

end qnice_tools;