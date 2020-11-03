library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity registers is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      pc_o       : out std_logic_vector(15 downto 0);
      pc_i       : in  std_logic_vector(15 downto 0);
      sr_o       : out std_logic_vector(15 downto 0);
      sr_i       : in  std_logic_vector(15 downto 0);
      src_reg_i  : in  std_logic_vector(3 downto 0);
      src_data_o : out std_logic_vector(15 downto 0);
      src_wr_i   : in  std_logic;
      src_data_i : in  std_logic_vector(15 downto 0);
      dst_reg_i  : in  std_logic_vector(3 downto 0);
      dst_data_o : out std_logic_vector(15 downto 0);
      dst_wr_i   : in  std_logic;
      dst_data_i : in  std_logic_vector(15 downto 0);
      res_wr_i   : in  std_logic;
      res_reg_i  : in  std_logic_vector(3 downto 0);
      res_data_i : in  std_logic_vector(15 downto 0)
   );
end entity registers;

architecture synthesis of registers is

   type mem_t is array (0 to 15) of std_logic_vector(15 downto 0);

   signal regs : mem_t := (others => (others => '0'));

begin

   pc_o <= regs(C_REG_PC);
   sr_o <= regs(C_REG_SR);

   src_data_o <= regs(conv_integer(src_reg_i));
   dst_data_o <= regs(conv_integer(dst_reg_i));

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         regs(C_REG_PC) <= pc_i;
         regs(C_REG_SR) <= sr_i;
         if src_wr_i = '1' then
            regs(conv_integer(src_reg_i)) <= src_data_i;
         end if;
         if dst_wr_i = '1' then
            regs(conv_integer(dst_reg_i)) <= dst_data_i;
         end if;
         if res_wr_i = '1' then
            regs(conv_integer(res_reg_i)) <= res_data_i;
         end if;

         if rst_i = '1' then
            regs <= (others => (others => '0'));
            regs(C_REG_SR)(0) <= '1';
            regs(C_REG_PC) <= X"0010";   -- TBD
         end if;
      end if;
   end process p_write;

end architecture synthesis;

