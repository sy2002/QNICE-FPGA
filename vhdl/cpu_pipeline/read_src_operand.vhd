library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity read_src_operand is
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      -- From previous stage
      instruction_i  : in  std_logic_vector(15 downto 0);

      -- To register file
      reg_src_reg_o  : out std_logic_vector(3 downto 0);
      reg_src_data_i : in  std_logic_vector(15 downto 0);
      reg_src_wr_o   : out std_logic;
      reg_src_data_o : out std_logic_vector(15 downto 0);

      -- To memory subsystem
      mem_valid_o    : out std_logic;
      mem_ready_i    : in  std_logic;
      mem_address_o  : out std_logic_vector(15 downto 0);
      mem_data_i     : in  std_logic_vector(15 downto 0);

      -- To next stage
      src_operand_o  : out std_logic_vector(15 downto 0);
      instruction_o  : out std_logic_vector(15 downto 0)
   );
end entity read_src_operand;

architecture synthesis of read_src_operand is

begin

   reg_src_reg_o <= instruction_i(R_SRC_REG);

   p_mem : process (instruction_i, reg_src_data_i)
   begin
      -- Default values to avoid latch
      mem_valid_o   <= '0';
      mem_address_o <= (others => '0');

      case conv_integer(instruction_i(R_SRC_MODE)) is
         when C_MODE_REG  => null;
         when C_MODE_MEM  => mem_address_o <= reg_src_data_i;   mem_valid_o <= '1';
         when C_MODE_POST => mem_address_o <= reg_src_data_i;   mem_valid_o <= '1';
         when C_MODE_PRE  => mem_address_o <= reg_src_data_i-1; mem_valid_o <= '1';
         when others      => null;
      end case;
   end process p_mem;


   p_reg : process (instruction_i, reg_src_data_i)
   begin
      reg_src_wr_o   <= '0';
      reg_src_data_o <= reg_src_data_i;
      case conv_integer(instruction_i(R_SRC_MODE)) is
         when C_MODE_REG  => null;
         when C_MODE_MEM  => null;
         when C_MODE_POST => reg_src_data_o <= reg_src_data_i+1; reg_src_wr_o <= '1';
         when C_MODE_PRE  => reg_src_data_o <= reg_src_data_i-1; reg_src_wr_o <= '1';
         when others      => null;
      end case;
   end process p_reg;


   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if instruction_i(R_SRC_MODE) = C_MODE_REG then
            src_operand_o <= reg_src_data_i;
         elsif mem_ready_i = '1' then
            src_operand_o <= mem_data_i;
         end if;

         instruction_o <= instruction_i;

         if rst_i = '1' then
            src_operand_o <= (others => '0');
            instruction_o <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

end architecture synthesis;

