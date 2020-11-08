library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_dst_operand is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
   
      flush_i          : in  std_logic;

      -- From previous stage
      ready_o           : out std_logic;
      stage2_i          : in  t_stage;

      -- From memory
      mem_data_i        : in  std_logic_vector(15 downto 0);

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
      stage3_o          : out t_stage;
      ready_i           : in  std_logic
   );
end entity read_dst_operand;

architecture synthesis of read_dst_operand is

   signal dst_mem_ready : std_logic;
   signal dst_reg_ready : std_logic;
   signal ready         : std_logic;

begin

   -----------------------------------------------------------------------
   -- Optionally read destination operand from memory
   -----------------------------------------------------------------------

   mem_valid_o   <= stage2_i.dst_mem_rd_request and ready;
   mem_address_o <= stage2_i.dst_mem_rd_address;


   -----------------------------------------------------------------------
   -- Optionaly write update destination register
   -----------------------------------------------------------------------

   reg_wr_o      <= stage2_i.dst_reg_wr_request and ready;
   reg_wr_reg_o  <= stage2_i.inst_dst_reg;
   reg_wr_data_o <= stage2_i.dst_reg_wr_value;


   -----------------------------------------------------------------------
   -- Are we ready to complete this stage?
   -----------------------------------------------------------------------

   -- Are we waiting for memory read access?
   dst_mem_ready <= not (stage2_i.dst_mem_rd_request and not mem_ready_i);

   -- Are we waiting for register write access?
   dst_reg_ready <= not (stage2_i.dst_reg_wr_request and not reg_ready_i);

   -- Everything must be ready before we can proceed
   ready <= dst_mem_ready and dst_reg_ready and ready_i and not flush_i;


   -- To next stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Has next stage consumed the output?
         if ready_i = '1' or flush_i = '1' then
            stage3_o <= C_STAGE_INIT;
         end if;

         -- Shall we complete this stage?
         if stage2_i.valid = '1' and ready = '1' then
            stage3_o <= stage2_i;
            if stage2_i.src_mem_rd_request = '1' then
               stage3_o.src_operand <= mem_data_i;
            end if;
         end if;

         if rst_i = '1' then
            stage3_o <= C_STAGE_INIT;
         end if;
      end if;
   end process p_next_stage;

   -- To previous stage (combinatorial)
   ready_o <= ready;

end architecture synthesis;

