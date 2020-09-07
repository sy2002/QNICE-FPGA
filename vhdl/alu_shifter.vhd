----------------------------------------------------------------------------------
-- QNICE CPU's ALU's shifter
-- implements QNICE specific shift behaviour:
--    SHL src, dst: dst << src, fill with X, shift to C
--    SHR src, dst: dst >> src, fill with C, shift to X
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_shifter is
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
end alu_shifter;

architecture Behavioral of alu_shifter is

begin

   shifter : process (dir, input1, input2, c_in, x_in)
   begin
      c_out <= c_in;
      x_out <= x_in;
      
      -- shift left
      if dir = '0' then      
         case input1 is
            when x"0000" =>
               result <= input2;
               c_out <= c_in;
               
            when x"0001" =>
               result(15 downto 1) <= input2(14 downto 0);
               result(0) <= x_in;
               c_out <= input2(15);
            
            when x"0002" =>
               result(15 downto 2) <= input2(13 downto 0);
               result(1 downto 0) <= (others => x_in);
               c_out <= input2(14);
            
            when x"0003" =>
               result(15 downto 3) <= input2(12 downto 0);
               result(2 downto 0) <= (others => x_in);
               c_out <= input2(13);
            
            when x"0004" =>
               result(15 downto 4) <= input2(11 downto 0);
               result(3 downto 0) <= (others => x_in);
               c_out <= input2(12);
            
            when x"0005" =>
               result(15 downto 5) <= input2(10 downto 0);
               result(4 downto 0) <= (others => x_in);
               c_out <= input2(11);
            
            when x"0006" =>
               result(15 downto 6) <= input2(9 downto 0);
               result(5 downto 0) <= (others => x_in);
               c_out <= input2(10);
            
            when x"0007" =>
               result(15 downto 7) <= input2(8 downto 0);
               result(6 downto 0) <= (others => x_in);
               c_out <= input2(9);
            
            when x"0008" =>
               result(15 downto 8) <= input2(7 downto 0);
               result(7 downto 0) <= (others => x_in);
               c_out <= input2(8);
            
            when x"0009" =>
               result(15 downto 9) <= input2(6 downto 0);
               result(8 downto 0) <= (others => x_in);
               c_out <= input2(7);
            
            when x"000A" =>
               result(15 downto 10) <= input2(5 downto 0);
               result(9 downto 0) <= (others => x_in);
               c_out <= input2(6);
            
            when x"000B" =>
               result(15 downto 11) <= input2(4 downto 0);
               result(10 downto 0) <= (others => x_in);
               c_out <= input2(5);
            
            when x"000C" =>
               result(15 downto 12) <= input2(3 downto 0);
               result(11 downto 0) <= (others => x_in);
               c_out <= input2(4);
            
            when x"000D" =>
               result(15 downto 13) <= input2(2 downto 0);
               result(12 downto 0) <= (others => x_in);
               c_out <= input2(3);
            
            when x"000E" =>
               result(15 downto 14) <= input2(1 downto 0);
               result(13 downto 0) <= (others => x_in);
               c_out <= input2(2);
            
            when x"000F" =>
               result(15) <= input2(0);
               result(14 downto 0) <= (others => x_in);
               c_out <= input2(1);
               
            when x"0010" =>
               result <= (others => x_in);
               c_out <= input2(0);
            
            when others =>
               result <= (others => x_in);
               c_out <= x_in;
         end case;
      
      -- shift right
      else
         case input1 is
            when x"0000" =>
               result <= input2;
               x_out <= x_in;
               
            when x"0001" =>
               result(14 downto 0) <= input2(15 downto 1);
               result(15) <= c_in;
               x_out <= input2(0);
               
            when x"0002" =>
               result(13 downto 0) <= input2(15 downto 2);
               result(15 downto 14) <= (others => c_in);
               x_out <= input2(1);
               
            when x"0003" =>
               result(12 downto 0) <= input2(15 downto 3);
               result(15 downto 13) <= (others => c_in);
               x_out <= input2(2);
               
            when x"0004" =>
               result(11 downto 0) <= input2(15 downto 4);
               result(15 downto 12) <= (others => c_in);
               x_out <= input2(3);
               
            when x"0005" =>
               result(10 downto 0) <= input2(15 downto 5);
               result(15 downto 11) <= (others => c_in);
               x_out <= input2(4);
               
            when x"0006" =>
               result(9 downto 0) <= input2(15 downto 6);
               result(15 downto 10) <= (others => c_in);
               x_out <= input2(5);
               
            when x"0007" =>
               result(8 downto 0) <= input2(15 downto 7);
               result(15 downto 9) <= (others => c_in);
               x_out <= input2(6);
               
            when x"0008" =>
               result(7 downto 0) <= input2(15 downto 8);
               result(15 downto 8) <= (others => c_in);
               x_out <= input2(7);
               
            when x"0009" =>
               result(6 downto 0) <= input2(15 downto 9);
               result(15 downto 7) <= (others => c_in);
               x_out <= input2(8);
               
            when x"000A" =>
               result(5 downto 0) <= input2(15 downto 10);
               result(15 downto 6) <= (others => c_in);
               x_out <= input2(9);
               
            when x"000B" =>
               result(4 downto 0) <= input2(15 downto 11);
               result(15 downto 5) <= (others => c_in);
               x_out <= input2(10);
               
            when x"000C" =>
               result(3 downto 0) <= input2(15 downto 12);
               result(15 downto 4) <= (others => c_in);
               x_out <= input2(11);
               
            when x"000D" =>
               result(2 downto 0) <= input2(15 downto 13);
               result(15 downto 3) <= (others => c_in);
               x_out <= input2(12);
               
            when x"000E" =>
               result(1 downto 0) <= input2(15 downto 14);
               result(15 downto 2) <= (others => c_in);
               x_out <= input2(13);
               
            when x"000F" =>
               result(0) <= input2(15);
               result(15 downto 1) <= (others => c_in);
               x_out <= input2(14);
               
            when x"0010" =>
               result <= (others => c_in);
               x_out <= input2(15);
               
            when others =>
               result <= (others => c_in);
               x_out <= c_in;
         end case;
      end if;
   end process;

end Behavioral;

