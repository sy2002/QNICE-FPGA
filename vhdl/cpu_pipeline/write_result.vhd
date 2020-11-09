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
      ready_o           : out std_logic;
      stage3_i          : in  t_stage;

      -- From memory
      mem_data_i        : in  std_logic_vector(15 downto 0);

      -- From register file
      pc_i             : in  std_logic_vector(15 downto 0);
      sr_i             : in  std_logic_vector(15 downto 0);
      sp_i             : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      sr_o             : out std_logic_vector(15 downto 0);
      pc_wr_o          : out std_logic;
      pc_o             : out std_logic_vector(15 downto 0);
      sp_wr_o          : out std_logic;
      sp_o             : out std_logic_vector(15 downto 0);

      -- Write to memory subsystem (combinatorial)
      mem_valid_o      : out std_logic;
      mem_address_o    : out std_logic_vector(15 downto 0);
      mem_data_o       : out std_logic_vector(15 downto 0);
      mem_ready_i      : in  std_logic;

      -- Write to register file (combinatorial)
      reg_wr_reg_o     : out std_logic_vector(3 downto 0);
      reg_wr_o         : out std_logic;
      reg_wr_data_o    : out std_logic_vector(15 downto 0);
      reg_ready_i      : in  std_logic;

      flush_o          : out std_logic
   );
end entity write_result;

architecture synthesis of write_result is

   signal dst_operand       : std_logic_vector(15 downto 0);

   signal res_data          : std_logic_vector(15 downto 0);

   signal res_mem_wr_ready  : std_logic;
   signal res_reg_wr_ready  : std_logic;
   signal ready             : std_logic;

   signal branch_execute    : std_logic;
   signal branch_dest       : std_logic_vector(15 downto 0);

begin

   -----------------------------------------------------------------------
   -- Determine destination operand
   -----------------------------------------------------------------------

   dst_operand <= mem_data_i when stage3_i.dst_mem_rd_request = '1' else
                  stage3_i.dst_mem_rd_address;


   -----------------------------------------------------------------------
   -- Calculate result
   -----------------------------------------------------------------------

   i_alu : entity work.alu
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         valid_i    => stage3_i.valid,
         src_data_i => stage3_i.src_operand,
         dst_data_i => dst_operand,
         sr_i       => sr_i,
         opcode_i   => stage3_i.inst_opcode,
         res_data_o => res_data,
         sr_o       => sr_o
      ); -- i_alu


   -----------------------------------------------------------------------
   -- Optionally write result to memory
   -----------------------------------------------------------------------

   mem_valid_o   <= stage3_i.res_mem_wr_request and ready;
   mem_address_o <= stage3_i.res_mem_wr_address;
   mem_data_o    <= stage3_i.pc_inst + 2 when stage3_i.res_reg_sp_update = '1' else
                   res_data;


   -----------------------------------------------------------------------
   -- Optionally write result to destination register
   -----------------------------------------------------------------------

   -- To register write subsystem (combinatorial)
   reg_wr_o      <= stage3_i.res_reg_wr_request and ready;
   reg_wr_reg_o  <= stage3_i.inst_dst_reg;
   reg_wr_data_o <= res_data;


   -----------------------------------------------------------------------
   -- Optionally update Program Counter
   -----------------------------------------------------------------------

   -- Are we executing and jumping on a branch?
   branch_execute <= '0' when stage3_i.valid = '0' else
                     '0' when conv_integer(stage3_i.inst_opcode) /= C_OP_BRA else
                     '0' when sr_i(conv_integer(stage3_i.inst_bra_cond)) /= not stage3_i.inst_bra_negate else
                     '1';


   -- Where are we jumping to?
   branch_dest <= stage3_i.src_operand + stage3_i.pc_inst + 2 when stage3_i.inst_bra_mode = C_BRA_RBRA else
                  stage3_i.src_operand + stage3_i.pc_inst + 2 when stage3_i.inst_bra_mode = C_BRA_RSUB else
                  stage3_i.src_operand;


   pc_wr_o <= branch_execute;
   pc_o    <= branch_dest;

   sp_wr_o <= stage3_i.res_reg_sp_update;
   sp_o    <= sp_i-1;

   -----------------------------------------------------------------------
   -- Are we ready to complete this stage?
   -----------------------------------------------------------------------

   -- Are we waiting for memory write access?
   res_mem_wr_ready <= not (stage3_i.res_mem_wr_request and not mem_ready_i);

   -- Are we waiting for register write access?
   res_reg_wr_ready <= not (stage3_i.res_reg_wr_request and not reg_ready_i);

   -- Everything must be ready before we can proceed
   ready <= res_mem_wr_ready and res_reg_wr_ready;


   -- To previous stage (combinatorial)
   flush_o <= '1' when branch_execute = '1' else
              '1' when (stage3_i.res_reg_wr_request and ready) = '1' and
                        stage3_i.inst_dst_reg = C_REG_PC else
              '0';

   ready_o <= ready;


   -- synthesis translate_off
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if stage3_i.valid = '1' and ready = '1' then
            disassemble(stage3_i.pc_inst, stage3_i.instruction, stage3_i.src_operand);
         end if;
      end if;
   end process;
   -- synthesis translate_on

end architecture synthesis;

