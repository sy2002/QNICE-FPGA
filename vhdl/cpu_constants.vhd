----------------------------------------------------------------------------------
-- QNICE CPU private constants (e.g. opcodes, addressing modes, ...)
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package cpu_constants is

-- opcodes
constant opcMOVE  : std_logic_vector(3 downto 0) := x"0";
constant opcADD   : std_logic_vector(3 downto 0) := x"1";
constant opcADDC  : std_logic_vector(3 downto 0) := x"2";
constant opcSUB   : std_logic_vector(3 downto 0) := x"3";
constant opcSUBC  : std_logic_vector(3 downto 0) := x"4";
constant opcSHL   : std_logic_vector(3 downto 0) := x"5";
constant opcSHR   : std_logic_vector(3 downto 0) := x"6"; -- bit pattern of SHR hardcoded in ALU's shifter component instantiation
constant opcSWAP  : std_logic_vector(3 downto 0) := x"7";
constant opcNOT   : std_logic_vector(3 downto 0) := x"8";
constant opcAND   : std_logic_vector(3 downto 0) := x"9";
constant opcOR    : std_logic_vector(3 downto 0) := x"A";
constant opcXOR   : std_logic_vector(3 downto 0) := x"B";
constant opcCMPU  : std_logic_vector(3 downto 0) := x"C";
constant opcCMPS  : std_logic_vector(3 downto 0) := x"D";
constant opcHALT  : std_logic_vector(3 downto 0) := x"E";
constant opcBRA   : std_logic_vector(3 downto 0) := x"F";

-- addressing modes
constant amDirect       : std_logic_vector(1 downto 0) := "00"; -- use the specified register directly
constant amIndirect     : std_logic_vector(1 downto 0) := "01"; -- use the memory address specified by the register
constant amIndirPostInc : std_logic_vector(1 downto 0) := "10"; -- perform amIndirect and increment the register afterwards
constant amIndirPreDec  : std_logic_vector(1 downto 0) := "11"; -- decrement the register and then perform amIndirect

-- branch modes / branch types
constant bmABRA         : std_logic_vector(1 downto 0) := "00"; -- absolute branch ("jump")
constant bmASUB         : std_logic_vector(1 downto 0) := "01"; -- absolute subroutine ("jsr")
constant bmRBRA         : std_logic_vector(1 downto 0) := "10"; -- relative branch
constant bmRSUB         : std_logic_vector(1 downto 0) := "11"; -- relative subroutine

end cpu_constants;

package body cpu_constants is
end cpu_constants;
