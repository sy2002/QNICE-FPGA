-- This is the main CPU module.
-- Currently, it requires the memory to read combinatorially (or alternatively
-- on the falling clock edge).

library ieee;
use ieee.std_logic_1164.all;

entity cpu_pipeline is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);
      mem_wr_data_o : out std_logic_vector(15 downto 0);
      mem_write_o   : out std_logic;
      mem_rd_data_i : in  std_logic_vector(15 downto 0);
      mem_read_o    : out std_logic;
      debug_o       : out std_logic_vector(15 downto 0)
   );
end entity cpu_pipeline;

architecture synthesis of cpu_pipeline is

   type t_stage1 is record
      valid         : std_logic;
      ready         : std_logic;
      pc_inst       : std_logic_vector(15 downto 0);
      src_reg_value : std_logic_vector(15 downto 0);
      instruction   : std_logic_vector(15 downto 0);
   end record t_stage1;

   type t_stage2 is record
      valid         : std_logic;
      ready         : std_logic;
      pc_inst       : std_logic_vector(15 downto 0);
      instruction   : std_logic_vector(15 downto 0);
      src_operand   : std_logic_vector(15 downto 0);
   end record t_stage2;

   type t_stage3 is record
      valid         : std_logic;
      ready         : std_logic;
      pc_inst       : std_logic_vector(15 downto 0);
      instruction   : std_logic_vector(15 downto 0);
      src_operand   : std_logic_vector(15 downto 0);
      dst_operand   : std_logic_vector(15 downto 0);
      dst_address   : std_logic_vector(15 downto 0);
   end record t_stage3;

   signal stage1          : t_stage1;
   signal stage2          : t_stage2;
   signal stage3          : t_stage3;

   -- Connections to the arbiter
   signal inst_valid      : std_logic;
   signal inst_ready      : std_logic;
   signal inst_address    : std_logic_vector(15 downto 0);
   signal inst_data       : std_logic_vector(15 downto 0);
   signal src_valid       : std_logic;
   signal src_ready       : std_logic;
   signal src_address     : std_logic_vector(15 downto 0);
   signal src_data        : std_logic_vector(15 downto 0);
   signal dst_valid       : std_logic;
   signal dst_ready       : std_logic;
   signal dst_address     : std_logic_vector(15 downto 0);
   signal dst_data        : std_logic_vector(15 downto 0);
   signal res_valid       : std_logic;
   signal res_ready       : std_logic;
   signal res_address     : std_logic_vector(15 downto 0);
   signal res_data        : std_logic_vector(15 downto 0);

   -- Connections to the arbiter_regs
   signal reg_src_rd_reg  : std_logic_vector(3 downto 0);
   signal reg_src_rd_data : std_logic_vector(15 downto 0);
   signal reg_src_wr_reg  : std_logic_vector(3 downto 0);
   signal reg_src_wr      : std_logic;
   signal reg_src_ready   : std_logic;
   signal reg_src_wr_data : std_logic_vector(15 downto 0);
   signal reg_dst_rd_reg  : std_logic_vector(3 downto 0);
   signal reg_dst_rd_data : std_logic_vector(15 downto 0);
   signal reg_dst_wr_reg  : std_logic_vector(3 downto 0);
   signal reg_dst_wr      : std_logic;
   signal reg_dst_ready   : std_logic;
   signal reg_dst_wr_data : std_logic_vector(15 downto 0);
   signal reg_res_wr      : std_logic;
   signal reg_res_ready   : std_logic;
   signal reg_res_wr_reg  : std_logic_vector(3 downto 0);
   signal reg_res_wr_data : std_logic_vector(15 downto 0);
   signal reg_rd_pc       : std_logic_vector(15 downto 0);
   signal reg_wr_pc       : std_logic_vector(15 downto 0);
   signal reg_rd_sr       : std_logic_vector(15 downto 0);
   signal reg_wr_sr       : std_logic_vector(15 downto 0);

   -- Connections to the register file
   signal arb_valid       : std_logic;
   signal arb_address     : std_logic_vector(3 downto 0);
   signal arb_data        : std_logic_vector(15 downto 0);

begin

   -- Stage 1
   i_read_instruction : entity work.read_instruction
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         pc_i             => reg_rd_pc,
         pc_o             => reg_wr_pc,
         reg_rd_reg_o     => reg_src_rd_reg,
         reg_data_i       => reg_src_rd_data,
         mem_valid_o      => inst_valid,
         mem_ready_i      => inst_ready,
         mem_address_o    => inst_address,
         mem_data_i       => inst_data,
         valid_o          => stage1.valid,
         ready_i          => stage1.ready,
         pc_inst_o        => stage1.pc_inst,
         src_reg_value_o  => stage1.src_reg_value,
         instruction_o    => stage1.instruction
      ); -- i_read_instruction

   -- Stage 2
   i_read_src_operand : entity work.read_src_operand
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         valid_i          => stage1.valid,
         ready_o          => stage1.ready,
         pc_inst_i        => stage1.pc_inst,
         src_reg_value_i  => stage1.src_reg_value,
         instruction_i    => stage1.instruction,
         reg_wr_reg_o     => reg_src_wr_reg,
         reg_wr_o         => reg_src_wr,
         reg_ready_i      => reg_src_ready,
         reg_data_o       => reg_src_wr_data,
         mem_valid_o      => src_valid,
         mem_ready_i      => src_ready,
         mem_address_o    => src_address,
         mem_data_i       => src_data,
         valid_o          => stage2.valid,
         ready_i          => stage2.ready,
         src_operand_o    => stage2.src_operand,
         pc_inst_o        => stage2.pc_inst,
         instruction_o    => stage2.instruction
      ); -- i_read_src_operand

   -- Stage 3
   i_read_dst_operand : entity work.read_dst_operand
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         valid_i          => stage2.valid,
         ready_o          => stage2.ready,
         pc_inst_i        => stage2.pc_inst,
         instruction_i    => stage2.instruction,
         src_operand_i    => stage2.src_operand,
         reg_rd_reg_o     => reg_dst_rd_reg,
         reg_data_i       => reg_dst_rd_data,
         reg_wr_reg_o     => reg_dst_wr_reg,
         reg_wr_o         => reg_dst_wr,
         reg_ready_i      => reg_dst_ready,
         reg_data_o       => reg_dst_wr_data,
         mem_valid_o      => dst_valid,
         mem_ready_i      => dst_ready,
         mem_address_o    => dst_address,
         mem_data_i       => dst_data,
         valid_o          => stage3.valid,
         ready_i          => stage3.ready,
         src_operand_o    => stage3.src_operand,
         dst_operand_o    => stage3.dst_operand,
         dst_address_o    => stage3.dst_address,
         pc_inst_o        => stage3.pc_inst,
         instruction_o    => stage3.instruction
      ); -- i_read_dst_operand

   -- Stage 4
   i_write_result : entity work.write_result
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         valid_i          => stage3.valid,
         ready_o          => stage3.ready,
         pc_inst_i        => stage3.pc_inst,
         instruction_i    => stage3.instruction,
         src_operand_i    => stage3.src_operand,
         dst_operand_i    => stage3.dst_operand,
         dst_address_i    => stage3.dst_address,
         pc_i             => reg_rd_pc,
         sr_i             => reg_rd_sr,
         sr_o             => reg_wr_sr,
         mem_valid_o      => res_valid,
         mem_ready_i      => res_ready,
         mem_address_o    => res_address,
         mem_data_o       => res_data,
         reg_wr_reg_o     => reg_res_wr_reg,
         reg_wr_o         => reg_res_wr,
         reg_ready_i      => reg_res_ready,
         reg_data_o       => reg_res_wr_data
      ); -- i_write_result

   i_arbiter_mem : entity work.arbiter_mem
      port map (
         clk_i          => clk_i,
         rst_i          => rst_i,
         inst_valid_i   => inst_valid,
         inst_ready_o   => inst_ready,
         inst_address_i => inst_address,
         inst_data_o    => inst_data,
         src_valid_i    => src_valid,
         src_ready_o    => src_ready,
         src_address_i  => src_address,
         src_data_o     => src_data,
         dst_valid_i    => dst_valid,
         dst_ready_o    => dst_ready,
         dst_address_i  => dst_address,
         dst_data_o     => dst_data,
         res_valid_i    => res_valid,
         res_ready_o    => res_ready,
         res_address_i  => res_address,
         res_data_i     => res_data,
         mem_address_o  => mem_address_o,
         mem_wr_data_o  => mem_wr_data_o,
         mem_write_o    => mem_write_o,
         mem_rd_data_i  => mem_rd_data_i,
         mem_read_o     => mem_read_o
      ); -- i_arbiter

   i_arbiter_regs : entity work.arbiter_regs
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         src_valid_i   => reg_src_wr,
         src_ready_o   => reg_src_ready,
         src_reg_i     => reg_src_wr_reg,
         src_data_i    => reg_src_wr_data,
         dst_valid_i   => reg_dst_wr,
         dst_ready_o   => reg_dst_ready,
         dst_reg_i     => reg_dst_wr_reg,
         dst_data_i    => reg_dst_wr_data,
         res_valid_i   => reg_res_wr,
         res_ready_o   => reg_res_ready,
         res_reg_i     => reg_res_wr_reg,
         res_data_i    => reg_res_wr_data,
         reg_valid_o   => arb_valid,
         reg_address_o => arb_address,
         reg_data_o    => arb_data
      ); -- i_arbiter_regs

   i_registers : entity work.registers
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         pc_o          => reg_rd_pc,
         pc_i          => reg_wr_pc,
         sr_o          => reg_rd_sr,
         sr_i          => reg_wr_sr,
         src_reg_i     => reg_src_rd_reg,
         src_data_o    => reg_src_rd_data,
         dst_reg_i     => reg_dst_rd_reg,
         dst_data_o    => reg_dst_rd_data,
         reg_valid_i   => arb_valid,
         reg_address_i => arb_address,
         reg_data_i    => arb_data
      ); -- i_registers

   debug_o <= reg_rd_pc;

end architecture synthesis;

