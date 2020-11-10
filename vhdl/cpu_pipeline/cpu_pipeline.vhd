-- This is the main CPU module.
-- Currently, it requires the memory to read combinatorially (or alternatively
-- on the falling clock edge).

library ieee;
use ieee.std_logic_1164.all;

use work.cpu_constants.all;

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

   signal stage1             : t_stage;
   signal stage2             : t_stage;
   signal stage3             : t_stage;
   signal stage1_ready       : std_logic;
   signal stage2_ready       : std_logic;
   signal stage3_ready       : std_logic;

   signal stage1_wait        : std_logic;

   -- Connections to the arbiter_mem
   signal mem_inst_valid     : std_logic;
   signal mem_inst_ready     : std_logic;
   signal mem_inst_address   : std_logic_vector(15 downto 0);
   signal mem_inst_data      : std_logic_vector(15 downto 0);
   signal mem_src_valid      : std_logic;
   signal mem_src_ready      : std_logic;
   signal mem_src_address    : std_logic_vector(15 downto 0);
   signal mem_src_data       : std_logic_vector(15 downto 0);
   signal mem_src_data_valid : std_logic;
   signal mem_dst_valid      : std_logic;
   signal mem_dst_ready      : std_logic;
   signal mem_dst_address    : std_logic_vector(15 downto 0);
   signal mem_dst_data       : std_logic_vector(15 downto 0);
   signal mem_dst_data_valid : std_logic;
   signal mem_res_valid      : std_logic;
   signal mem_res_ready      : std_logic;
   signal mem_res_address    : std_logic_vector(15 downto 0);
   signal mem_res_data       : std_logic_vector(15 downto 0);

   -- Connections to the arbiter_regs
   signal reg_src_rd_reg     : std_logic_vector(3 downto 0);
   signal reg_src_rd_data    : std_logic_vector(15 downto 0);
   signal reg_dst_rd_reg     : std_logic_vector(3 downto 0);
   signal reg_dst_rd_data    : std_logic_vector(15 downto 0);
   signal reg_dst_wr_reg     : std_logic_vector(3 downto 0);
   signal reg_dst_wr         : std_logic;
   signal reg_dst_ready      : std_logic;
   signal reg_dst_wr_data    : std_logic_vector(15 downto 0);
   signal reg_res_wr         : std_logic;
   signal reg_res_ready      : std_logic;
   signal reg_res_wr_reg     : std_logic_vector(3 downto 0);
   signal reg_res_wr_data    : std_logic_vector(15 downto 0);
   signal reg_rd_pc          : std_logic_vector(15 downto 0);
   signal reg_wr_pc          : std_logic_vector(15 downto 0);
   signal reg_rd_sr          : std_logic_vector(15 downto 0);
   signal reg_wr_sr          : std_logic_vector(15 downto 0);
   signal reg_rd_sp          : std_logic_vector(15 downto 0);

   signal reg_res_wr_pc      : std_logic;
   signal reg_res_pc         : std_logic_vector(15 downto 0);
   signal reg_res_wr_sp      : std_logic;
   signal reg_res_sp         : std_logic_vector(15 downto 0);

   -- Connections to the register file
   signal arb_valid          : std_logic;
   signal arb_address        : std_logic_vector(3 downto 0);
   signal arb_data           : std_logic_vector(15 downto 0);

   signal flush              : std_logic;

begin

   -- Stage 1
   i_read_instruction : entity work.read_instruction
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         flush_i          => flush,
         pc_i             => reg_rd_pc,
         pc_o             => reg_wr_pc,
         mem_valid_o      => mem_inst_valid,
         mem_ready_i      => mem_inst_ready,
         mem_address_o    => mem_inst_address,
         valid_o          => stage1.valid,
         ready_i          => stage1_ready,
         pc_inst_o        => stage1.pc_inst,
         wait_i           => stage1_wait
      ); -- i_read_instruction


   -- Stage 2
   i_read_src_operand : entity work.read_src_operand
      port map (
         clk_i             => clk_i,
         rst_i             => rst_i,
         wait_o            => stage1_wait,
         flush_i           => flush,
         ready_o           => stage1_ready,
         stage1_i          => stage1,
         mem_data_i        => mem_inst_data,
         sp_i              => reg_rd_sp,
         reg_rd_src_reg_o  => reg_src_rd_reg,
         reg_rd_src_data_i => reg_src_rd_data,
         reg_rd_dst_reg_o  => reg_dst_rd_reg,
         reg_rd_dst_data_i => reg_dst_rd_data,
         mem_valid_o       => mem_src_valid,
         mem_address_o     => mem_src_address,
         mem_ready_i       => mem_src_ready,
         stage2_o          => stage2,
         ready_i           => stage2_ready
      ); -- i_read_src_operand


   -- Stage 3
   i_read_dst_operand : entity work.read_dst_operand
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         flush_i          => flush,
         ready_o          => stage2_ready,
         stage2_i         => stage2,
         mem_data_i       => mem_src_data,
         mem_valid_i      => mem_src_data_valid,
         reg_wr_o         => reg_dst_wr,
         reg_wr_reg_o     => reg_dst_wr_reg,
         reg_wr_data_o    => reg_dst_wr_data,
         reg_ready_i      => reg_dst_ready,
         mem_valid_o      => mem_dst_valid,
         mem_ready_i      => mem_dst_ready,
         mem_address_o    => mem_dst_address,
         stage3_o         => stage3,
         ready_i          => stage3_ready
      ); -- i_read_dst_operand


   -- Stage 4
   i_write_result : entity work.write_result
      port map (
         clk_i            => clk_i,
         rst_i            => rst_i,
         stage3_i         => stage3,
         ready_o          => stage3_ready,
         mem_data_i       => mem_dst_data,
         mem_valid_i      => mem_dst_data_valid,
         pc_i             => reg_rd_pc,
         sr_i             => reg_rd_sr,
         sp_i             => reg_rd_sp,
         sr_o             => reg_wr_sr,
         pc_wr_o          => reg_res_wr_pc,
         pc_o             => reg_res_pc,
         sp_wr_o          => reg_res_wr_sp,
         sp_o             => reg_res_sp,
         mem_valid_o      => mem_res_valid,
         mem_address_o    => mem_res_address,
         mem_data_o       => mem_res_data,
         mem_ready_i      => mem_res_ready,
         reg_wr_reg_o     => reg_res_wr_reg,
         reg_wr_o         => reg_res_wr,
         reg_wr_data_o    => reg_res_wr_data,
         reg_ready_i      => reg_res_ready,
         flush_o          => flush
      ); -- i_write_result


   i_arbiter_mem : entity work.arbiter_mem
      port map (
         clk_i          => clk_i,
         rst_i          => rst_i,
         inst_valid_i   => mem_inst_valid,
         inst_ready_o   => mem_inst_ready,
         inst_address_i => mem_inst_address,
         inst_data_o    => mem_inst_data,
         src_valid_i    => mem_src_valid,
         src_ready_o    => mem_src_ready,
         src_address_i  => mem_src_address,
         src_data_o     => mem_src_data,
         src_valid_o    => mem_src_data_valid,
         dst_valid_i    => mem_dst_valid,
         dst_ready_o    => mem_dst_ready,
         dst_address_i  => mem_dst_address,
         dst_data_o     => mem_dst_data,
         dst_valid_o    => mem_dst_data_valid,
         res_valid_i    => mem_res_valid,
         res_ready_o    => mem_res_ready,
         res_address_i  => mem_res_address,
         res_data_i     => mem_res_data,
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
         res_wr_pc_i   => reg_res_wr_pc,
         res_pc_i      => reg_res_pc,
         sr_o          => reg_rd_sr,
         sr_i          => reg_wr_sr,
         sp_o          => reg_rd_sp,
         res_wr_sp_i   => reg_res_wr_sp,
         res_sp_i      => reg_res_sp,
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

