library ieee;
use ieee.std_logic_1164.all;
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

   signal res_data : std_logic_vector(16 downto 0);
   signal res_shr  : std_logic_vector(16 downto 0);
   signal res_shl  : std_logic_vector(16 downto 0);

   signal cmp_n    : std_logic;
   signal cmp_v    : std_logic;
   signal cmp_z    : std_logic;

   signal zero     : std_logic;
   signal carry    : std_logic;
   signal negative : std_logic;
   signal overflow : std_logic;

begin

   -- dst << src, fill with X, shift to C
   p_shift_left : process (src_data_i, dst_data_i, sr_i)
      variable tmp   : std_logic_vector(32 downto 0);
      variable res   : std_logic_vector(16 downto 0);
      variable shift : integer;
   begin
      -- Prepare for shift
      tmp(32)           := sr_i(C_SR_C);  -- Old value of C
      tmp(31 downto 16) := dst_data_i;
      tmp(15 downto 0)  := (15 downto 0 => sr_i(C_SR_X));  -- Fill with X

      shift := to_integer(unsigned(src_data_i));
      if shift <= 16 then
         res := tmp(32-shift downto 16-shift);
      else
         res := (others => sr_i(C_SR_X));
      end if;

      res_shl <= res;
   end process p_shift_left;

   -- dst >> src, fill with C, shift to X
   p_shift_right : process (src_data_i, dst_data_i, sr_i)
      variable tmp   : std_logic_vector(32 downto 0);
      variable res   : std_logic_vector(16 downto 0);
      variable shift : integer;
   begin
      -- Prepare for shift
      tmp(32 downto 17) := (32 downto 17 => sr_i(C_SR_C));  -- Fill with C
      tmp(16 downto 1)  := dst_data_i;
      tmp(0)            := sr_i(C_SR_X);  -- Old value of X

      shift := to_integer(unsigned(src_data_i));
      if shift <= 16 then
         res := tmp(shift+16 downto shift);
      else
         res := (others => sr_i(C_SR_C));
      end if;

      res_shr <= res;
   end process p_shift_right;

   p_res_data : process (src_data_i, dst_data_i, opcode_i, sr_i)
   begin
      res_data <= ("0" & src_data_i);  -- Default value to avoid latches
      case to_integer(unsigned(opcode_i)) is
         when C_OP_MOVE => res_data <= "0" & src_data_i;
         when C_OP_ADD  => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) + ("0" & unsigned(src_data_i)));
         when C_OP_ADDC => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) + ("0" & unsigned(src_data_i)) + (X"0000" & sr_i(C_SR_C)));
         when C_OP_SUB  => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) - ("0" & unsigned(src_data_i)));
         when C_OP_SUBC => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) - ("0" & unsigned(src_data_i)) - (X"0000" & sr_i(C_SR_C)));
         when C_OP_SHL  => res_data <= "0" & (res_shl(15 downto 0));
         when C_OP_SHR  => res_data <= "0" & (res_shr(16 downto 1));
         when C_OP_SWAP => res_data <= "0" & (src_data_i(7 downto 0) & src_data_i(15 downto 8));
         when C_OP_NOT  => res_data <= "0" & (not src_data_i);
         when C_OP_AND  => res_data <= "0" & (dst_data_i and src_data_i);
         when C_OP_OR   => res_data <= "0" & (dst_data_i or src_data_i);
         when C_OP_XOR  => res_data <= "0" & (dst_data_i xor src_data_i);
         when C_OP_CMP  => null; -- TBD
         when C_OP_RES  => null; -- TBD
         when C_OP_CTRL => null; -- TBD
         when C_OP_BRA  => null; -- TBD
         when others    => null;
      end case;
   end process p_res_data;

   zero     <= '1' when res_data(15 downto 0) = X"0000" else
               '0';
   carry    <= res_data(16);
   negative <= res_data(15);

   -- Overflow is true if adding/subtracting two negative numbers yields a positive
   -- number or if adding/subtracting two positive numbers yields a negative number
   overflow <= (not src_data_i(15) and not dst_data_i(15) and     res_data(15)) or
               (    src_data_i(15) and     dst_data_i(15) and not res_data(15));

   cmp_n <= '1' when signed(src_data_i) > signed(dst_data_i) else
            '0';

   cmp_v <= '1' when unsigned(src_data_i) > unsigned(dst_data_i) else
            '0';

   cmp_z <= '1' when src_data_i = dst_data_i else
            '0';

   p_sr : process (res_data, opcode_i, sr_i)
   begin
      sr_o <= sr_i or X"0001";  -- Default value to preserve bits that are not changed.
      case to_integer(unsigned(opcode_i)) is
         when C_OP_MOVE =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_ADD  => sr_o(C_SR_V) <= overflow; sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero; sr_o(C_SR_C) <= carry;
         when C_OP_ADDC => sr_o(C_SR_V) <= overflow; sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero; sr_o(C_SR_C) <= carry;
         when C_OP_SUB  => sr_o(C_SR_V) <= overflow; sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero; sr_o(C_SR_C) <= carry;
         when C_OP_SUBC => sr_o(C_SR_V) <= overflow; sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero; sr_o(C_SR_C) <= carry;
         when C_OP_SHL  => sr_o(C_SR_C) <= res_shl(16);
         when C_OP_SHR  => sr_o(C_SR_X) <= res_shr(0);
         when C_OP_SWAP =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_NOT  =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_AND  =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_OR   =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_XOR  =>                           sr_o(C_SR_N) <= negative; sr_o(C_SR_Z) <= zero;
         when C_OP_CMP  => sr_o(C_SR_V) <= cmp_v;    sr_o(C_SR_N) <= cmp_n;    sr_o(C_SR_Z) <= cmp_z;
         when C_OP_RES  => null; -- No status bits are changed
         when C_OP_CTRL => null; -- No status bits are changed
         when C_OP_BRA  => null; -- No status bits are changed
         when others    => null;
      end case;
   end process p_sr;

   res_data_o <= res_data(15 downto 0);

end architecture synthesis;

