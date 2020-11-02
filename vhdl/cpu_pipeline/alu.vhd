library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity alu is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      src_data_i : in  std_logic_vector(15 downto 0);
      dst_data_i : in  std_logic_vector(15 downto 0);
      sr_i       : in  std_logic_vector(7 downto 0);
      opcode_i   : in  std_logic_vector(3 downto 0);
      res_data_o : out std_logic_vector(15 downto 0);
      sr_o       : out std_logic_vector(7 downto 0)
   );
end entity alu;

architecture synthesis of alu is

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

begin

   p_res_data : process (src_data_i, dst_data_i, opcode_i)
   begin
      res_data_o <= src_data_i;  -- Default value to avoid latches
      case conv_integer(opcode_i) is
         when C_OP_MOVE => res_data_o <= src_data_i;
         when C_OP_ADD  => res_data_o <= dst_data_i + src_data_i;
         when C_OP_ADDC => res_data_o <= dst_data_i + src_data_i + ("000000000000000" & sr_i(C_SR_C));
         when C_OP_SUB  => res_data_o <= dst_data_i - src_data_i;
         when C_OP_SUBC => res_data_o <= dst_data_i - src_data_i - ("000000000000000" & sr_i(C_SR_C));
         when C_OP_SHL  => null; -- TBD
         when C_OP_SHR  => null; -- TBD
         when C_OP_SWAP => res_data_o <= src_data_i(7 downto 0) & src_data_i(15 downto 8);
         when C_OP_NOT  => res_data_o <= not src_data_i;
         when C_OP_AND  => res_data_o <= dst_data_i and src_data_i;
         when C_OP_OR   => res_data_o <= dst_data_i or src_data_i;
         when C_OP_XOR  => res_data_o <= dst_data_i xor src_data_i;
         when C_OP_CMP  => null; -- TBD
         when C_OP_RES  => null; -- TBD
         when C_OP_CTRL => null; -- TBD
         when C_OP_BRA  => null; -- TBD
         when others    => null;
      end case;
   end process p_res_data;

   sr_o <= sr_i;  -- TBD

end architecture synthesis;

