library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity registers is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      pc_o          : out std_logic_vector(15 downto 0);
      pc_i          : in  std_logic_vector(15 downto 0);
      res_wr_pc_i   : in  std_logic;
      res_pc_i      : in  std_logic_vector(15 downto 0);
      sr_o          : out std_logic_vector(15 downto 0);
      sr_i          : in  std_logic_vector(15 downto 0);
      sp_o          : out std_logic_vector(15 downto 0);
      res_wr_sp_i   : in  std_logic;
      res_sp_i      : in  std_logic_vector(15 downto 0);
      src_reg_i     : in  std_logic_vector(3 downto 0);
      src_data_o    : out std_logic_vector(15 downto 0);
      dst_reg_i     : in  std_logic_vector(3 downto 0);
      dst_data_o    : out std_logic_vector(15 downto 0);
      reg_valid_i   : in  std_logic;
      reg_address_i : in  std_logic_vector(3 downto 0);
      reg_data_i    : in  std_logic_vector(15 downto 0)
   );
end entity registers;

architecture synthesis of registers is

   type upper_mem_t is array (8 to 15) of std_logic_vector(15 downto 0);
   type lower_mem_t is array (0 to 8*256-1) of std_logic_vector(15 downto 0);

   signal upper_regs : upper_mem_t := (others => (others => '0'));
   signal lower_regs : lower_mem_t := (others => (others => '0'));

   signal pc : std_logic_vector(15 downto 0);
   signal sr : std_logic_vector(15 downto 0);
   signal sp : std_logic_vector(15 downto 0);

begin

   pc_o <= pc;
   sr_o <= sr;
   sp_o <= sp;

   src_data_o <= pc when conv_integer(src_reg_i) = C_REG_PC else
                 sr when conv_integer(src_reg_i) = C_REG_SR else
                 sp when conv_integer(src_reg_i) = C_REG_SP else
                 upper_regs(conv_integer(src_reg_i)) when conv_integer(src_reg_i) >= 8 else
                 lower_regs(conv_integer(sr(15 downto 8))*8+conv_integer(src_reg_i));

   dst_data_o <= pc when conv_integer(dst_reg_i) = C_REG_PC else
                 sr when conv_integer(dst_reg_i) = C_REG_SR else
                 sp when conv_integer(dst_reg_i) = C_REG_SP else
                 upper_regs(conv_integer(dst_reg_i)) when conv_integer(dst_reg_i) >= 8 else
                 lower_regs(conv_integer(sr(15 downto 8))*8+conv_integer(dst_reg_i));

   p_special : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if reg_valid_i = '1' and conv_integer(reg_address_i) = C_REG_PC then
            assert res_wr_pc_i = '0' report "Multiple writes to PC" severity failure;
            pc <= reg_data_i;
         elsif res_wr_pc_i = '1' then
            pc <= res_pc_i;
         else
            pc <= pc_i;
         end if;

         if reg_valid_i = '1' and conv_integer(reg_address_i) = C_REG_SP then
            assert res_wr_sp_i = '0' report "Multiple writes to SP" severity failure;
            sp <= reg_data_i;
         elsif res_wr_sp_i = '1' then
            sp <= res_sp_i;
         end if;

         if reg_valid_i = '1' and conv_integer(reg_address_i) = C_REG_SR then
            sr <= reg_data_i or X"0001";
         else
            sr <= sr_i or X"0001";
         end if;

         if rst_i = '1' then
            pc <= X"0000";
            sr <= X"0001";
            sp <= X"0000";
         end if;
      end if;
   end process p_special;

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if reg_valid_i = '1' then
            if conv_integer(reg_address_i) >= 8 then
               upper_regs(conv_integer(reg_address_i)) <= reg_data_i;
            else
               lower_regs(conv_integer(sr(15 downto 8))*8+conv_integer(reg_address_i)) <= reg_data_i;
            end if;
         end if;
      end if;
   end process p_write;

end architecture synthesis;

