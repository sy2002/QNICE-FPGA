----------------------------------------------------------------------------------
-- QNICE CPU's ALU
-- 
-- done in 2015 and enhanced in May 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.cpu_constants.all;

entity alu is
port (
   opcode      : in std_logic_vector(3 downto 0);
   
   -- input1 is meant to be source (Src) and input2 is meant to be destination (Dst)
   -- c_in is carry in, x_in is X-flag in
   input1      : in unsigned(15 downto 0);
   input2      : in unsigned(15 downto 0);
   c_in        : in std_logic;
   x_in        : in std_logic;
   
   -- ALU operation result and flags
   result      : out unsigned(15 downto 0);
   X           : out std_logic;
   C           : out std_logic;
   Z           : out std_logic;
   N           : out std_logic;
   V           : out std_logic
);
end alu;

architecture beh of alu is

component alu_shifter is
port (
   -- dir = 0 means left, direction = 1 means right
   dir         : in std_logic;

   -- input1 is meant to be source (Src) and input2 is meant to be destination (Dst)
   -- c_in is carry in, x_in is X-flag in
   input1      : in unsigned(15 downto 0);
   input2      : in unsigned(15 downto 0);
   c_in        : in std_logic;
   x_in        : in std_logic;
   
   -- result
   result      : out unsigned(15 downto 0);
   c_out       : out std_logic;
   x_out       : out std_logic
);
end component;

signal s_input1 : signed(15 downto 0);
signal s_input2 : signed(15 downto 0);

-- use a 17 bit signal for working with 16 bit inputs for having the carry in the topmost bit
signal res : unsigned(16 downto 0);

-- reuse adders, subtractors, ...
signal r_sub : unsigned(16 downto 0);

-- results from the shifter
signal shifter_result : unsigned(15 downto 0);
signal shifter_c_out : std_logic;
signal shifter_x_out : std_logic;

begin

   shifter : alu_shifter
      port map
      (
         dir => not opcode(3) and opcode(2) and opcode(1) and not opcode(0), -- SHR opcode = 0110
         input1 => input1,
         input2 => input2,
         c_in => c_in,
         x_in => x_in,
         result => shifter_result,
         c_out => shifter_c_out,
         x_out => shifter_x_out
      );

   calculate : process (opcode, input1, input2, r_sub, c_in, shifter_result, shifter_c_out)
   begin
      case opcode is
         when opcMOVE =>
            res <= "0" & input1;
            
         when opcADD =>
            res <= ("0" & input2) + ("0" & input1);
            
         when opcADDC =>
            res <= ("0" & input2) + ("0" & input1) + ("0000000000000000" & c_in);
            
         when opcSUB =>
            res <= r_sub;
            
         when opcSUBC =>
            res <= r_sub - ("0000000000000000" & c_in);

         when opcSHL =>
            res <= shifter_c_out & shifter_result;
                                    
         when opcSHR =>
            res <= shifter_c_out & shifter_result;
            
         when opcSWAP =>
            res <= "0" & input1(7 downto 0) & input1(15 downto 8);

         when opcNOT =>
            res <= "0" & (not input1); -- as the carry shall not be set after this operation, set it to 1 before the not

         when opcAND =>
            res <= ("0" & input1) and ("0" & input2);
            
         when opcOR =>
            res <= ("0" & input1) or ("0" & input2);
                        
         when opcXOR =>
            res <= ("0" & input1) xor ("0" & input2);
                     
         when opcCMP =>
            res <= "0" & input2;
                     
         when others =>
            res <= (others => '0');
      end case;
   end process;
   
   manage_flags : process (res, opcode, input1, input2, s_input1, s_input2, shifter_x_out)
   begin
   
      -- CMP FLAG HANDLING
      --    X = 0
      --    Z = 1, if Src = Dst otherwise Z = 0
      --    N = 1, if unsigned(Src) > unsigned(Dst), otherwise N = 0
      --    V = 1, if signed(Src) > signed(Dst), otherwise V = 0
      if Opcode = opcCMP then
      
         X <= '0';
      
         if input1 = input2 then
            Z <= '1';
         else
            Z <= '0';
         end if;
         
         if input1 > input2 then
            N <= '1';
         else
            N <= '0';
         end if;
         
         if s_input1 > s_input2 then
            V <= '1';
         else
            V <= '0';
         end if;
      
      -- REGULAR FLAG HANDLING
      else
         -- the X register is context sensitive
         if opcode /= opcSHR then
            -- X is true if result is FFFF
            if res(15 downto 0) = x"FFFF" then
               X <= '1';
            else
               X <= '0';
            end if;
         else
            X <= shifter_x_out;
         end if;
         
         -- Z is true if result is 0000
         if res(15 downto 0) = x"0000" then
            Z <= '1';
         else
            Z <= '0';
         end if;
         
         -- N is true if result is < 0
         N <= res(15);
                  
         -- V is true if adding/subtracting two negative numbers yields a positive
         -- number or if adding/subtracting two positive numbers yields a negative number
         if Opcode = opcADD or Opcode = opcADDC or Opcode = opcSUB or Opcode = opcSUBC or
            Opcode = opcAND or Opcode = opcOR or Opcode = opcXOR then
            if (input1(15) = '0' and input2(15) = '0' and res(15) = '1') or
               (input1(15) = '1' and input2(15) = '1' and res(15) = '0')
            then
               V <= '1';
            else
               V <= '0';
            end if;
         else
            V <= '0';
         end if;
      end if;
   end process;



s_input1 <= signed(input1);
s_input2 <= signed(input2);

r_sub <= ("0" & input2) - ("0" & input1);

result <= res(15 downto 0);
C <= res(16);

end beh;

