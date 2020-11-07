library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_dst_operand is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;

      -- From previous stage
      valid_i          : in  std_logic;
      ready_o          : out std_logic;
      pc_inst_i        : in  std_logic_vector(15 downto 0);
      instruction_i    : in  std_logic_vector(15 downto 0);
      src_operand_i    : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      reg_rd_reg_o     : out std_logic_vector(3 downto 0);
      reg_data_i       : in  std_logic_vector(15 downto 0);
      reg_wr_reg_o     : out std_logic_vector(3 downto 0);
      reg_wr_o         : out std_logic;
      reg_ready_i      : in  std_logic;
      reg_data_o       : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o      : out std_logic;
      mem_ready_i      : in  std_logic;
      mem_address_o    : out std_logic_vector(15 downto 0);
      mem_data_i       : in  std_logic_vector(15 downto 0);

      -- To next stage (registered)
      valid_o          : out std_logic := '0';
      ready_i          : in  std_logic;
      src_operand_o    : out std_logic_vector(15 downto 0);
      dst_operand_o    : out std_logic_vector(15 downto 0);
      dst_address_o    : out std_logic_vector(15 downto 0);
      pc_inst_o        : out std_logic_vector(15 downto 0);
      instruction_o    : out std_logic_vector(15 downto 0)
   );
end entity read_dst_operand;

architecture synthesis of read_dst_operand is

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal mem_address : std_logic_vector(15 downto 0);
   signal reg_request : std_logic;
   signal reg_ready   : std_logic;
   signal reg_data    : std_logic_vector(15 downto 0);
   signal ready       : std_logic;

begin

   -- Do we want to read from memory?
   mem_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_OPCODE) = C_OP_MOVE else
                  '0' when instruction_i(R_OPCODE) = C_OP_SWAP else
                  '0' when instruction_i(R_OPCODE) = C_OP_NOT else
                  '0' when instruction_i(R_OPCODE) = C_OP_RES else
                  '0' when instruction_i(R_OPCODE) = C_OP_CTRL else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '1';


   -- Do we want register write access?
   reg_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_OPCODE) = C_OP_RES else
                  '0' when instruction_i(R_OPCODE) = C_OP_CTRL else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_MEM else
                  '1';


   -- Are we waiting for memory read access?
   mem_ready <= not (mem_request and not mem_ready_i);

   -- Are we waiting for register write access?
   reg_ready <= not (reg_request and not reg_ready_i);

   -- Are we ready to complete this stage?
   ready <= mem_ready and reg_ready and ready_i;

   -- To previous stage (combinatorial)
   ready_o <= ready;


   -- To register file (combinatorial)
   reg_data <= reg_data_i + 1 when instruction_i(R_DEST_MODE) = C_MODE_POST else
               reg_data_i - 1 when instruction_i(R_DEST_MODE) = C_MODE_PRE else
               reg_data_i;

   reg_wr_o     <= reg_request;
   reg_wr_reg_o <= instruction_i(R_DEST_REG);
   reg_data_o   <= reg_data;


   -- To memory subsystem (combinatorial)
   mem_address <= reg_data_i-1 when instruction_i(R_DEST_MODE) = C_MODE_PRE else
                  reg_data_i;

   mem_valid_o   <= mem_request;
   mem_address_o <= mem_address;


   -- To register file (combinatorial)
   reg_rd_reg_o <= instruction_i(R_DEST_REG);


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

         -- Shall we complete this stage?
         if valid_i = '1' and ready = '1' then
            if instruction_i(R_DEST_MODE) = C_MODE_REG then
               valid_o       <= '1';
               dst_operand_o <= reg_data_i;
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
               dst_address_o <= reg_data_i-1;
            else
               dst_address_o <= reg_data_i;
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

