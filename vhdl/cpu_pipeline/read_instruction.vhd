library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_instruction is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To register file (combinatorial)
      pc_i          : in  std_logic_vector(15 downto 0);
      pc_o          : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o   : out std_logic;
      mem_ready_i   : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);
      mem_data_i    : in  std_logic_vector(15 downto 0);

      -- To next pipeline stage (registered)
      valid_o       : out std_logic;
      ready_i       : in  std_logic;
      pc_inst_o     : out std_logic_vector(15 downto 0);
      instruction_o : out std_logic_vector(15 downto 0)
   );
end entity read_instruction;

architecture synthesis of read_instruction is

   signal dbg_cycle_counter : std_logic_vector(15 downto 0);
   signal dbg_inst_counter  : std_logic_vector(15 downto 0);

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal ready       : std_logic;

   signal count       : integer range 0 to 3;
   signal valid       : std_logic;
   signal pc_inst     : std_logic_vector(15 downto 0);
   signal instruction : std_logic_vector(15 downto 0);

begin

   -- Do we want to read from memory?
   mem_request <= ready_i or not valid when count = 0 else
                  '0';

   -- Are we waiting for memory read access?
   mem_ready <= (not mem_request) or mem_ready_i;

   -- Are we ready to complete this stage?
   ready <= mem_ready and ready_i and not rst_i;


   -- To register file (combinatorial)
   pc_o <= pc_i + 1 when ready = '1' and count = 0 else
           pc_i;

   -- To memory subsystem (combinatorial)
   mem_address_o <= pc_i;
   mem_valid_o   <= mem_request and not rst_i;

   -- To next pipeline stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         dbg_cycle_counter <= dbg_cycle_counter + 1;

         -- Has next stage consumed the output?
         if ready_i = '1' then
            valid <= '0';
         end if;

         if ready = '1' then
            case count is
               when 0 =>
                  dbg_inst_counter <= dbg_inst_counter + 1;
                  valid       <= '1';
                  pc_inst     <= pc_i;
                  instruction <= mem_data_i;
                  if mem_data_i(R_OPCODE) = C_OP_BRA then
                     count <= 3;
                  end if;
                  if mem_data_i(R_OPCODE) = C_OP_CTRL then
                     report "CONTROL instruction"
                        severity failure;
                  end if;
               when 1 => count <= 0;
               when 2 => count <= 1;
               when 3 => count <= 2;
               when others => null;
            end case;
         end if;

         if rst_i = '1' then
            count       <= 0;
            valid       <= '0';
            instruction <= (others => '0');
            dbg_cycle_counter <= (others => '0');
            dbg_inst_counter  <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

   valid_o       <= valid;
   pc_inst_o     <= pc_inst;
   instruction_o <= instruction;

end architecture synthesis;

