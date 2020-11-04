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
      sr_o          : out std_logic_vector(15 downto 0);
      sr_i          : in  std_logic_vector(15 downto 0);
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

   type mem_t is array (0 to 15) of std_logic_vector(15 downto 0);

   signal regs : mem_t := (others => (others => '0'));

   signal pc : std_logic_vector(15 downto 0);
   signal sr : std_logic_vector(15 downto 0);

begin

   pc_o <= pc;
   sr_o <= sr;

   src_data_o <= pc when conv_integer(src_reg_i) = C_REG_PC else
                 sr when conv_integer(src_reg_i) = C_REG_SR else
                 regs(conv_integer(src_reg_i));

   dst_data_o <= pc when conv_integer(dst_reg_i) = C_REG_PC else
                 sr when conv_integer(dst_reg_i) = C_REG_SR else
                 regs(conv_integer(dst_reg_i));

   p_special : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pc <= pc_i;
         sr <= sr_i or X"0001";

         if rst_i = '1' then
            pc <= X"0010"; -- TBD
            sr <= X"0001";
         end if;
      end if;
   end process p_special;

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if reg_valid_i = '1' then
            regs(conv_integer(reg_address_i)) <= reg_data_i;
         end if;
      end if;
   end process p_write;

end architecture synthesis;

