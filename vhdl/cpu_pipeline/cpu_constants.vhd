library ieee;
use ieee.std_logic_1164.all;

package cpu_constants is

   -- Instruction format is as follows
   subtype R_OPCODE    is natural range 15 downto 12;
   subtype R_SRC_REG   is natural range 11 downto  8;
   subtype R_SRC_MODE  is natural range  7 downto  6;
   subtype R_DEST_REG  is natural range  5 downto  2;
   subtype R_DEST_MODE is natural range  1 downto  0;

   -- Decode status bits
   constant C_SR_V : integer := 5;
   constant C_SR_N : integer := 4;
   constant C_SR_Z : integer := 3;
   constant C_SR_C : integer := 2;
   constant C_SR_X : integer := 1;

   -- Opcodes
   constant C_OP_MOVE : integer := 0;
   constant C_OP_ADD  : integer := 1;
   constant C_OP_ADDC : integer := 2;
   constant C_OP_SUB  : integer := 3;
   constant C_OP_SUBC : integer := 4;
   constant C_OP_SHL  : integer := 5;
   constant C_OP_SHR  : integer := 6;
   constant C_OP_SWAP : integer := 7;
   constant C_OP_NOT  : integer := 8;
   constant C_OP_AND  : integer := 9;
   constant C_OP_OR   : integer := 10;
   constant C_OP_XOR  : integer := 11;
   constant C_OP_CMP  : integer := 12;
   constant C_OP_RES  : integer := 13;
   constant C_OP_CTRL : integer := 14;
   constant C_OP_BRA  : integer := 15;

   -- Addressing modes
   constant C_MODE_REG  : integer := 0;   -- R
   constant C_MODE_MEM  : integer := 1;   -- @R
   constant C_MODE_POST : integer := 2;   -- @R++
   constant C_MODE_PRE  : integer := 3;   -- @--R

   -- Special registers
   constant C_REG_PC : integer := 15;
   constant C_REG_SR : integer := 14;
   constant C_REG_SP : integer := 13;

end cpu_constants;

package body cpu_constants is
end cpu_constants;
