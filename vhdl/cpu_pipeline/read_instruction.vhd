library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_instruction is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;

      -- To register file (combinatorial)
      pc_i             : in  std_logic_vector(15 downto 0);
      pc_o             : out std_logic_vector(15 downto 0);
      reg_rd_reg_o     : out std_logic_vector(3 downto 0);
      reg_data_i       : in  std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o      : out std_logic;
      mem_ready_i      : in  std_logic;
      mem_address_o    : out std_logic_vector(15 downto 0);
      mem_data_i       : in  std_logic_vector(15 downto 0);

      -- To next pipeline stage (registered)
      valid_o          : out std_logic;
      ready_i          : in  std_logic;
      pc_inst_o        : out std_logic_vector(15 downto 0);
      src_reg_value_o  : out std_logic_vector(15 downto 0);
      instruction_o    : out std_logic_vector(15 downto 0)
   );
end entity read_instruction;

architecture synthesis of read_instruction is

   signal dbg_cycle_counter_r : std_logic_vector(15 downto 0);
   signal dbg_inst_counter_r  : std_logic_vector(15 downto 0);

   signal mem_request     : std_logic;
   signal mem_ready       : std_logic;
   signal ready           : std_logic;
   signal reg_data        : std_logic_vector(15 downto 0);

   signal count_r         : integer range 0 to 4;
   signal valid_r         : std_logic := '0';
   signal pc_inst_r       : std_logic_vector(15 downto 0);
   signal src_reg_value_r : std_logic_vector(15 downto 0);
   signal instruction_r   : std_logic_vector(15 downto 0);

begin

   -- Do we want to read from memory?
   mem_request <= '0' when count_r /= 0 else
                  '0' when valid_r = '1' and ready_i = '0' else
                  '1';

   -- Are we waiting for memory read access?
   mem_ready <= not (mem_request and not mem_ready_i);

   -- Are we ready to complete this stage?
   ready <= mem_request and mem_ready and ready_i and not rst_i;


   -- To register file (combinatorial)
   pc_o <= pc_i + 1 when ready = '1' and count_r = 0 else
           pc_i;

   -- To register file (combinatorial)
   reg_rd_reg_o <= mem_data_i(R_SRC_REG);   -- Instruction decoding

   -- Register value before increment/decrement
   reg_data <= pc_i + 1 when mem_data_i(R_SRC_REG) = C_REG_PC else -- Instruction decoding
               reg_data_i;

   -- To memory subsystem (combinatorial)
   mem_address_o <= pc_i;
   mem_valid_o   <= mem_request and not rst_i;

   -- To next pipeline stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         dbg_cycle_counter_r <= dbg_cycle_counter_r + 1;

         -- Has next stage consumed the output?
         if ready_i = '1' then
            valid_r <= '0';
         end if;

         case count_r is
            when 0 =>
               if ready = '1' then
                  dbg_inst_counter_r <= dbg_inst_counter_r + 1;
                  valid_r         <= '1';
                  pc_inst_r       <= pc_i;
                  src_reg_value_r <= reg_data;
                  instruction_r   <= mem_data_i;
                  if mem_data_i(R_OPCODE) = C_OP_BRA then
                     count_r <= 4;
                  end if;
                  if mem_data_i(R_DEST_REG) = C_REG_PC then
                     count_r <= 4;
                  end if;
                  if mem_data_i(R_OPCODE) = C_OP_CTRL then
                     report "CONTROL instruction"
                     severity failure;
                  end if;
               end if;
            when 1 => count_r <= 0;
            when 2 => count_r <= 1;
            when 3 => count_r <= 2;
            when 4 => count_r <= 3;
            when others => null;
         end case;

         if rst_i = '1' then
            count_r       <= 0;
            valid_r       <= '0';
            instruction_r <= (others => '0');
            dbg_cycle_counter_r <= (others => '0');
            dbg_inst_counter_r  <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

   valid_o         <= valid_r;
   pc_inst_o       <= pc_inst_r;
   src_reg_value_o <= src_reg_value_r;
   instruction_o   <= instruction_r;

end architecture synthesis;

