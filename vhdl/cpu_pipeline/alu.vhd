library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity alu is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      src_data_i : in  std_logic_vector(15 downto 0);
      dst_data_i : in  std_logic_vector(15 downto 0);
      sr_i       : in  std_logic_vector(15 downto 0);
      opcode_i   : in  std_logic_vector(3 downto 0);
      res_data_o : out std_logic_vector(15 downto 0);
      sr_o       : out std_logic_vector(15 downto 0)
   );
end entity alu;

architecture synthesis of alu is

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

