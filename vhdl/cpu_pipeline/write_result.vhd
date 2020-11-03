library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity write_result is
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      -- From previous stage
      valid_i        : in  std_logic;
      ready_o        : out std_logic;
      instruction_i  : in  std_logic_vector(15 downto 0);
      src_operand_i  : in  std_logic_vector(15 downto 0);
      dst_operand_i  : in  std_logic_vector(15 downto 0);
      dst_address_i  : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      sr_i           : in  std_logic_vector(15 downto 0);
      sr_o           : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o    : out std_logic;
      mem_ready_i    : in  std_logic;
      mem_address_o  : out std_logic_vector(15 downto 0);
      mem_data_o     : out std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      reg_res_reg_o  : out std_logic_vector(3 downto 0);
      reg_res_wr_o   : out std_logic;
      reg_res_data_o : out std_logic_vector(15 downto 0)
   );
end entity write_result;

architecture synthesis of write_result is

   signal res_data : std_logic_vector(15 downto 0);

begin

   i_alu : entity work.alu
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         src_data_i => src_operand_i,
         dst_data_i => dst_operand_i,
         sr_i       => sr_i,
         opcode_i   => instruction_i(R_OPCODE),
         res_data_o => res_data,
         sr_o       => sr_o
      ); -- i_alu


   -- To memory subsystem (combinatorial)
   p_mem : process (valid_i, instruction_i, res_data, dst_address_i)
   begin
      -- Default values to avoid latch
      mem_valid_o   <= '0';
      mem_address_o <= dst_address_i;
      mem_data_o    <= res_data;

      if valid_i = '1' then
         case conv_integer(instruction_i(R_DEST_MODE)) is
            when C_MODE_REG  => null;
            when C_MODE_MEM  => mem_valid_o <= '1';
            when C_MODE_POST => mem_valid_o <= '1';
            when C_MODE_PRE  => mem_valid_o <= '1';
            when others      => null;
         end case;
      end if;
   end process p_mem;


   -- To register file (combinatorial)
   p_reg : process (valid_i, instruction_i, res_data)
   begin
      -- Default values to avoid latch
      reg_res_reg_o  <= (others => '0');
      reg_res_wr_o   <= '0';
      reg_res_data_o <= (others => '0');

      if valid_i = '1' then
         if conv_integer(instruction_i(R_DEST_MODE)) = C_MODE_REG then
            reg_res_reg_o  <= instruction_i(R_DEST_REG);
            reg_res_wr_o   <= '1';
            reg_res_data_o <= res_data;
         end if;
      end if;
   end process p_reg;

end architecture synthesis;

