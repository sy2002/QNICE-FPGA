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
   
   -- input1 is meant to be source (Src) and input2 is meant to be destination (Dst)
   -- c_in is carry in
   input1      : in signed(15 downto 0);
   input2      : in signed(15 downto 0);
   c_in        : in std_logic;
   
   -- ALU operation result and flags
   result      : out signed(15 downto 0);
   X           : out std_logic;
   C           : out std_logic;
   Z           : out std_logic;
   N           : out std_logic;
   V           : out std_logic
);
end alu;

architecture beh of alu is

-- use a 17 bit signal for working with 16 bit inputs for having the carry in the topmost bit
signal res : signed(16 downto 0);

begin

   calculate : process (opcode, input1, input2, c_in)
   begin
      case opcode is
         when opcMOVE =>
            res <= "0" & input1;
            
         when opcADD =>
            res <= ("0" & input2) + ("0" & input1);
            
         when opcADDC =>
            res <= ("0" & input2) + ("0" & input1) + ("0000000000000000" & c_in);
            
         when opcSUB =>
            res <= ("0" & input2) - ("0" & input1) - ("0000000000000000" & c_in);
            
         when others =>
            res <= (others => '0');
      end case;
   end process;
   
   manage_flags : process (res, Opcode, input1, input2)
   begin
      -- X is true if result is FFFF
      if res = x"FFFF" then
         X <= '1';
      else
         X <= '0';
      end if;
      
      -- Z is true if result is 0000
      if res = x"0000" then
         Z <= '1';
      else
         Z <= '0';
      end if;
      
      -- N is true if result is < 0
      if res < 0 then
         N <= '1';
      else
         N <= '0';
      end if;
      
      -- V is true if adding/subtracting two negative numbers yields a positive
      -- number or if adding/subtracting two positive numbers yields a negative number
      if Opcode = opcADD or Opcode = opcADDC or Opcode = opcSUB or Opcode = opcSUBC then
         if (input1 > 0 and input2 > 0 and res < 0) or
            (input1 < 0 and input2 < 0 and res > 0)
         then
            V <= '1';
         else
            V <= '0';
         end if;
      else
         V <= '0';
      end if;
   end process;

result <= res(15 downto 0);
C <= res(16);

end beh;

