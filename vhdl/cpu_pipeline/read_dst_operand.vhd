library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_dst_operand is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From previous stage
      valid_i         : in  std_logic;
      ready_o         : out std_logic;
      pc_inst_i       : in  std_logic_vector(15 downto 0);
      instruction_i   : in  std_logic_vector(15 downto 0);
      src_operand_i   : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      reg_dst_reg_o   : out std_logic_vector(3 downto 0);
      reg_dst_data_i  : in  std_logic_vector(15 downto 0);
      reg_dst_wr_o    : out std_logic;
      reg_dst_ready_i : in  std_logic;
      reg_dst_data_o  : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o     : out std_logic;
      mem_ready_i     : in  std_logic;
      mem_address_o   : out std_logic_vector(15 downto 0);
      mem_data_i      : in  std_logic_vector(15 downto 0);

      -- To next stage (registered)
      valid_o         : out std_logic;
      ready_i         : in  std_logic;
      src_operand_o   : out std_logic_vector(15 downto 0);
      dst_operand_o   : out std_logic_vector(15 downto 0);
      dst_address_o   : out std_logic_vector(15 downto 0);
      pc_inst_o       : out std_logic_vector(15 downto 0);
      instruction_o   : out std_logic_vector(15 downto 0)
   );
end entity read_dst_operand;

architecture synthesis of read_dst_operand is

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal reg_ready   : std_logic;
   signal ready       : std_logic;

begin

   -- Do we want to read from memory?
   mem_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '0' when instruction_i(R_OPCODE) = C_OP_MOVE else
                  '0' when instruction_i(R_OPCODE) = C_OP_SWAP else
                  '0' when instruction_i(R_OPCODE) = C_OP_NOT else
                  '0' when instruction_i(R_OPCODE) = C_OP_RES else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '1';

   -- Are we waiting for memory read access?
   mem_ready <= (not mem_request) or mem_ready_i;

   -- Are we waiting for register write access?
   reg_ready <= '1' when valid_i = '0' else
                '1' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                '1' when instruction_i(R_DEST_MODE) = C_MODE_MEM else
                reg_dst_ready_i;

   -- Are we ready to complete this stage?
   ready <= mem_ready and reg_ready and ready_i;

   -- To previous stage (combinatorial)
   ready_o <= ready;


   -- To register file (combinatorial)
   p_reg : process (valid_i, instruction_i, reg_dst_data_i, ready)
   begin
      -- Default values to avoid latch
      reg_dst_reg_o  <= instruction_i(R_DEST_REG);
      reg_dst_wr_o   <= '0';
      reg_dst_data_o <= reg_dst_data_i;

      if valid_i = '1' and ready = '1' then
         case conv_integer(instruction_i(R_DEST_MODE)) is
            when C_MODE_REG  => null;
            when C_MODE_MEM  => null;
            when C_MODE_POST => reg_dst_data_o <= reg_dst_data_i+1; reg_dst_wr_o <= '1';
            when C_MODE_PRE  => reg_dst_data_o <= reg_dst_data_i-1; reg_dst_wr_o <= '1';
            when others      => null;
         end case;
      end if;
   end process p_reg;


   -- To memory subsystem (combinatorial)
   p_mem : process (valid_i, instruction_i, reg_dst_data_i, ready, mem_request)
   begin
      -- Default values to avoid latch
      mem_valid_o   <= '0';
      mem_address_o <= (others => '0');

      if valid_i = '1' and ready = '1' and mem_request = '1' then
         case conv_integer(instruction_i(R_DEST_MODE)) is
            when C_MODE_REG  => null;
            when C_MODE_MEM  => mem_address_o <= reg_dst_data_i;   mem_valid_o <= '1';
            when C_MODE_POST => mem_address_o <= reg_dst_data_i;   mem_valid_o <= '1';
            when C_MODE_PRE  => mem_address_o <= reg_dst_data_i-1; mem_valid_o <= '1';
            when others      => null;
         end case;
      end if;
   end process p_mem;


   -- To next stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Has next stage consumed the output?
         if ready_i = '1' then
            valid_o       <= '0';
            instruction_o <= (others => '0');
            src_operand_o <= (others => '0');
            dst_operand_o <= (others => '0');
            dst_address_o <= (others => '0');
         end if;

         if valid_i = '1' and ready = '1' then
            if instruction_i(R_DEST_MODE) = C_MODE_REG then
               valid_o       <= '1';
               dst_operand_o <= reg_dst_data_i;
               pc_inst_o     <= pc_inst_i;
               instruction_o <= instruction_i;
               src_operand_o <= src_operand_i;
            elsif mem_ready = '1' then
               valid_o       <= '1';
               if mem_request = '1' then
                  dst_operand_o <= mem_data_i;
               else
                  dst_operand_o <= (others => '0');
               end if;
               pc_inst_o     <= pc_inst_i;
               instruction_o <= instruction_i;
               src_operand_o <= src_operand_i;
            end if;

            if instruction_i(R_DEST_MODE) = C_MODE_PRE then
               dst_address_o <= reg_dst_data_i-1;
            else
               dst_address_o <= reg_dst_data_i;
            end if;
         end if;

         if rst_i = '1' then
            valid_o       <= '0';
            instruction_o <= (others => '0');
            src_operand_o <= (others => '0');
            dst_operand_o <= (others => '0');
            dst_address_o <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

end architecture synthesis;

