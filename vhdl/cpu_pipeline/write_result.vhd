library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity write_result is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;

      -- From previous stage
      valid_i          : in  std_logic;
      ready_o          : out std_logic;
      pc_inst_i        : in  std_logic_vector(15 downto 0);
      instruction_i    : in  std_logic_vector(15 downto 0);
      src_operand_i    : in  std_logic_vector(15 downto 0);
      dst_operand_i    : in  std_logic_vector(15 downto 0);
      dst_address_i    : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      pc_i             : in  std_logic_vector(15 downto 0);
      sr_i             : in  std_logic_vector(15 downto 0);
      sr_o             : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o      : out std_logic;
      mem_ready_i      : in  std_logic;
      mem_address_o    : out std_logic_vector(15 downto 0);
      mem_data_o       : out std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      reg_res_wr_reg_o : out std_logic_vector(3 downto 0);
      reg_res_wr_o     : out std_logic;
      reg_res_ready_i  : in  std_logic;
      reg_res_data_o   : out std_logic_vector(15 downto 0)
   );
end entity write_result;

architecture synthesis of write_result is

   signal res_data : std_logic_vector(15 downto 0);

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal reg_request : std_logic;
   signal reg_ready   : std_logic;
   signal ready       : std_logic;

begin

   -- Do we want to write to memory?
   mem_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_OPCODE) = C_OP_CMP else
                  '1';

   -- Are we waiting for memory read access?
   mem_ready <= (not mem_request) or mem_ready_i;

   -- Do we want register write access?
   reg_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_OPCODE) = C_OP_CMP else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '1';

   -- Are we waiting for register write access?
   reg_ready <= (not reg_request) or reg_res_ready_i;

   -- Are we ready to complete this stage?
   ready <= mem_ready and reg_ready;

   -- To previous stage (combinatorial)
   ready_o <= ready;


   i_alu : entity work.alu
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         valid_i    => valid_i,
         src_data_i => src_operand_i,
         dst_data_i => dst_operand_i,
         sr_i       => sr_i,
         opcode_i   => instruction_i(R_OPCODE),
         res_data_o => res_data,
         sr_o       => sr_o
      ); -- i_alu


   -- To memory subsystem (combinatorial)
   p_mem : process (valid_i, instruction_i, res_data, dst_address_i, ready, mem_request)
   begin
      -- Default values to avoid latch
      mem_valid_o   <= '0';
      mem_address_o <= dst_address_i;
      mem_data_o    <= res_data;

      if valid_i = '1' and ready = '1' and mem_request = '1' then
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
   p_reg : process (valid_i, instruction_i, res_data, ready, pc_i, clk_i, pc_inst_i)
   begin
      -- Default values to avoid latch
      reg_res_wr_reg_o <= (others => '0');
      reg_res_wr_o     <= '0';
      reg_res_data_o   <= (others => '0');

      if valid_i = '1' and ready = '1' then
         -- Is this is branch type instruction ?
         if conv_integer(instruction_i(R_OPCODE)) = C_OP_BRA then

            -- Is the condition satisfied ?
            if sr_i(conv_integer(instruction_i(R_BRA_COND))) = not instruction_i(R_BRA_NEGATE) then

               reg_res_wr_reg_o <= std_logic_vector(to_unsigned(C_REG_PC, 4));
               reg_res_wr_o     <= '1';

               case conv_integer(instruction_i(R_BRA_MODE)) is
                  when C_BRA_ABRA => reg_res_data_o <= res_data;
                  when C_BRA_ASUB => reg_res_data_o <= res_data;
                  when C_BRA_RBRA => reg_res_data_o <= pc_i + res_data;
                  when C_BRA_RSUB => reg_res_data_o <= pc_i + res_data;
                  when others => null;
               end case;
            end if;
         elsif conv_integer(instruction_i(R_OPCODE)) = C_OP_CTRL then
            report "Control instruction";
         elsif conv_integer(instruction_i(R_OPCODE)) = C_OP_CMP then
            null;
         elsif conv_integer(instruction_i(R_DEST_MODE)) = C_MODE_REG then
            reg_res_wr_reg_o <= instruction_i(R_DEST_REG);
            reg_res_wr_o     <= '1';
            reg_res_data_o   <= res_data;
         end if;

         -- synthesis translate_off
         if rising_edge(clk_i) then
            disassemble(pc_inst_i, instruction_i, res_data);
         end if;
         -- synthesis translate_on

      end if;
   end process p_reg;

end architecture synthesis;

