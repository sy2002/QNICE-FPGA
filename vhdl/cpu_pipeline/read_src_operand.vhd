library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_src_operand is
   port (
      clk_i             : in  std_logic;
      rst_i             : in  std_logic;

      flush_i           : in  std_logic;

      -- From previous stage
      ready_o           : out std_logic;
      stage1_i          : in  t_stage;

      -- From memory
      mem_data_i        : in  std_logic_vector(15 downto 0);

      -- Read from register file (combinatorial)
      reg_rd_src_reg_o  : out std_logic_vector(3 downto 0);
      reg_rd_src_data_i : in  std_logic_vector(15 downto 0);
      reg_rd_dst_reg_o  : out std_logic_vector(3 downto 0);
      reg_rd_dst_data_i : in  std_logic_vector(15 downto 0);

      -- Write to register file (combinatorial)
      reg_wr_o          : out std_logic;
      reg_wr_reg_o      : out std_logic_vector(3 downto 0);
      reg_wr_data_o     : out std_logic_vector(15 downto 0);
      reg_ready_i       : in  std_logic;

      -- Read from memory subsystem (combinatorial)
      mem_valid_o       : out std_logic;
      mem_address_o     : out std_logic_vector(15 downto 0);
      mem_ready_i       : in  std_logic;

      -- To next stage (registered)
      stage2_o          : out t_stage;
      ready_i           : in  std_logic
   );
end entity read_src_operand;

architecture synthesis of read_src_operand is

   -- Decode instruction
   signal inst_opcode        : std_logic_vector(3 downto 0);
   signal inst_src_mode      : std_logic_vector(1 downto 0);
   signal inst_src_reg       : std_logic_vector(3 downto 0);
   signal inst_dst_mode      : std_logic_vector(1 downto 0);
   signal inst_dst_reg       : std_logic_vector(3 downto 0);
   signal inst_bra_mode      : std_logic_vector(1 downto 0);
   signal inst_bra_negate    : std_logic;
   signal inst_bra_cond      : std_logic_vector(2 downto 0);

   signal src_reg_valid      : std_logic;
   signal src_reg_wr_request : std_logic;
   signal src_reg_rd_value   : std_logic_vector(15 downto 0);
   signal src_reg_wr_value   : std_logic_vector(15 downto 0);
   signal src_mem_rd_request : std_logic;
   signal src_mem_rd_address : std_logic_vector(15 downto 0);
   signal dst_reg_valid      : std_logic;
   signal dst_reg_wr_request : std_logic;
   signal dst_reg_rd_value   : std_logic_vector(15 downto 0);
   signal dst_reg_wr_value   : std_logic_vector(15 downto 0);
   signal dst_mem_rd_request : std_logic;
   signal dst_mem_rd_address : std_logic_vector(15 downto 0);
   signal res_reg_wr_request : std_logic;
   signal res_mem_wr_request : std_logic;
   signal res_mem_wr_address : std_logic_vector(15 downto 0);

   signal src_mem_rd_ready   : std_logic;
   signal src_reg_wr_ready   : std_logic;
   signal ready              : std_logic;

begin

   -----------------------------------------------------------------------
   -- Decode instruction
   -----------------------------------------------------------------------

   inst_opcode     <= mem_data_i(R_OPCODE);
   inst_src_mode   <= mem_data_i(R_SRC_MODE);
   inst_src_reg    <= mem_data_i(R_SRC_REG);
   inst_dst_mode   <= mem_data_i(R_DEST_MODE);
   inst_dst_reg    <= mem_data_i(R_DEST_REG);
   inst_bra_mode   <= mem_data_i(R_BRA_MODE);
   inst_bra_negate <= mem_data_i(R_BRA_NEGATE);
   inst_bra_cond   <= mem_data_i(R_BRA_COND);

   -- Does the instruction use the source register field?
   src_reg_valid <= '0' when stage1_i.valid = '0' or flush_i = '1' else
                    '0' when inst_opcode = C_OP_RES else
                    '0' when inst_opcode = C_OP_CTRL else
                    '1';

   -- Does the instruction use the destination register field?
   dst_reg_valid <= '0' when stage1_i.valid = '0' or flush_i = '1' else
                    '0' when inst_opcode = C_OP_RES else
                    '0' when inst_opcode = C_OP_BRA else
                    '1';

   -- Do we want to read source operand from memory?
   src_mem_rd_request <= '0' when src_reg_valid = '0' else
                         '0' when inst_src_mode = C_MODE_REG else
                         '1';

   -- Do we want to read destination operand from memory?
   dst_mem_rd_request <= '0' when dst_reg_valid = '0' else
                         '0' when inst_opcode = C_OP_MOVE else
                         '0' when inst_opcode = C_OP_SWAP else
                         '0' when inst_opcode = C_OP_NOT else
                         '0' when inst_opcode = C_OP_RES else
                         '0' when inst_opcode = C_OP_CTRL else
                         '0' when inst_opcode = C_OP_BRA else
                         '0' when inst_dst_mode = C_MODE_REG else
                         '1';

   -- Do we want to write result memory?
   res_mem_wr_request <= '0' when dst_reg_valid = '0' else
                         '0' when inst_opcode = C_OP_RES else
                         '0' when inst_opcode = C_OP_CTRL else
                         '0' when inst_opcode = C_OP_BRA and inst_bra_mode = C_BRA_ABRA else
                         '0' when inst_opcode = C_OP_BRA and inst_bra_mode = C_BRA_RBRA else
                         '0' when inst_dst_mode = C_MODE_REG else
                         '1';

   -- Do we want to update source register?
   src_reg_wr_request <= '0' when src_reg_valid = '0' else
                         '0' when inst_src_mode = C_MODE_REG else
                         '0' when inst_src_mode = C_MODE_MEM else
                         '1';

   -- Do we want to update destination register?
   dst_reg_wr_request <= '0' when dst_reg_valid = '0' else
                         '0' when inst_dst_mode = C_MODE_REG else
                         '0' when inst_dst_mode = C_MODE_MEM else
                         '1';

   -- Do we want to write to destination register?
   res_reg_wr_request <= '0' when stage1_i.valid = '0' or flush_i = '1' else
                         '0' when inst_opcode = C_OP_BRA else
                         '0' when inst_opcode = C_OP_RES else
                         '0' when inst_opcode = C_OP_CTRL else
                         '0' when inst_opcode = C_OP_CMP else
                         '0' when inst_dst_mode = C_MODE_MEM else
                         '1';


   -----------------------------------------------------------------------
   -- Read registers from register file
   -----------------------------------------------------------------------

   reg_rd_src_reg_o <= inst_src_reg;
   reg_rd_dst_reg_o <= inst_dst_reg;

   src_reg_rd_value <= reg_rd_src_data_i;
   dst_reg_rd_value <= reg_rd_dst_data_i;


   -----------------------------------------------------------------------
   -- Calculate addresses in memory
   -----------------------------------------------------------------------

   src_mem_rd_address <= src_reg_rd_value-1 when inst_src_mode = C_MODE_PRE else
                         src_reg_rd_value;

   dst_mem_rd_address <= dst_reg_rd_value-1 when inst_dst_mode = C_MODE_PRE else
                         dst_reg_rd_value;

   res_mem_wr_address <= dst_reg_rd_value-1 when inst_dst_mode = C_MODE_PRE else
                         dst_reg_rd_value;


   -----------------------------------------------------------------------
   -- Calculate updated registers
   -----------------------------------------------------------------------

   src_reg_wr_value <= src_reg_rd_value + 1 when inst_src_mode = C_MODE_POST else
                       src_reg_rd_value - 1 when inst_src_mode = C_MODE_PRE else
                       src_reg_rd_value;

   dst_reg_wr_value <= dst_reg_rd_value + 1 when inst_dst_mode = C_MODE_POST else
                       dst_reg_rd_value - 1 when inst_dst_mode = C_MODE_PRE else
                       dst_reg_rd_value;


   -----------------------------------------------------------------------
   -- Optionally read source operand from memory
   -----------------------------------------------------------------------

   mem_valid_o   <= src_mem_rd_request and ready;
   mem_address_o <= src_mem_rd_address;


   -----------------------------------------------------------------------
   -- Optionaly write update source register
   -----------------------------------------------------------------------

   reg_wr_o      <= src_reg_wr_request and ready;
   reg_wr_reg_o  <= inst_src_reg;
   reg_wr_data_o <= src_reg_wr_value;


   -----------------------------------------------------------------------
   -- Are we ready to complete this stage?
   -----------------------------------------------------------------------

   -- Are we waiting for memory read access?
   src_mem_rd_ready <= not (src_mem_rd_request and not mem_ready_i);

   -- Are we waiting for register write access?
   src_reg_wr_ready <= not (src_reg_wr_request and not reg_ready_i);

   -- Everything must be ready before we can proceed
   ready <= src_mem_rd_ready and src_reg_wr_ready and ready_i and not flush_i;


   -- To next stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Has next stage consumed the output?
         if ready_i = '1' or flush_i = '1' then
            stage2_o <= C_STAGE_INIT;
         end if;

         if stage1_i.valid = '1' and ready = '1' then
            stage2_o.valid              <= '1';
            stage2_o.pc_inst            <= stage1_i.pc_inst;
            stage2_o.instruction        <= mem_data_i;
            stage2_o.inst_opcode        <= inst_opcode;
            stage2_o.inst_src_mode      <= inst_src_mode;
            stage2_o.inst_src_reg       <= inst_src_reg;
            stage2_o.inst_dst_mode      <= inst_dst_mode;
            stage2_o.inst_dst_reg       <= inst_dst_reg;
            stage2_o.inst_bra_mode      <= inst_bra_mode;
            stage2_o.inst_bra_negate    <= inst_bra_negate;
            stage2_o.inst_bra_cond      <= inst_bra_cond;
            stage2_o.src_reg_valid      <= src_reg_valid;
            stage2_o.src_mem_rd_request <= src_mem_rd_request;
            stage2_o.src_reg_wr_request <= src_reg_wr_request;
            stage2_o.src_reg_wr_value   <= src_reg_wr_value;
            stage2_o.src_mem_rd_address <= src_mem_rd_address;
            stage2_o.dst_reg_valid      <= dst_reg_valid;
            stage2_o.dst_mem_rd_request <= dst_mem_rd_request;
            stage2_o.dst_reg_wr_request <= dst_reg_wr_request;
            stage2_o.dst_reg_wr_value   <= dst_reg_wr_value;
            stage2_o.dst_mem_rd_address <= dst_mem_rd_address;
            stage2_o.res_mem_wr_request <= res_mem_wr_request;
            stage2_o.res_mem_wr_address <= res_mem_wr_address;
            stage2_o.res_reg_wr_request <= res_reg_wr_request;
            stage2_o.src_operand        <= src_reg_rd_value;
         end if;

         if rst_i = '1' then
            stage2_o <= C_STAGE_INIT;
         end if;
      end if;
   end process p_next_stage;

   -- To previous stage (combinatorial)
   ready_o <= ready;

end architecture synthesis;

