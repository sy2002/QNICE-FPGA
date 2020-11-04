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
      instruction_o : out std_logic_vector(15 downto 0)
   );
end entity read_instruction;

architecture synthesis of read_instruction is

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal ready       : std_logic;

   signal valid       : std_logic;
   signal instruction : std_logic_vector(15 downto 0);

begin

   -- Do we want to read from memory?
   mem_request <= ready_i or not valid;

   -- Are we waiting for memory read access?
   mem_ready <= (not mem_request) or mem_ready_i;

   -- Are we ready to complete this stage?
   ready <= mem_ready and ready_i;


   -- To register file (combinatorial)
   pc_o <= pc_i + 1 when ready = '1' else
           pc_i;

   -- To memory subsystem (combinatorial)
   mem_address_o <= pc_i;
   mem_valid_o   <= mem_request and not rst_i;

   -- To next pipeline stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Has next stage consumed the output?
         if ready_i = '1' then
            valid       <= '0';
            instruction <= (others => '0');
         end if;

         if ready = '1' then
            valid       <= '1';
            instruction <= mem_data_i;
         end if;

         if rst_i = '1' then
            valid       <= '0';
            instruction <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

   valid_o       <= valid;
   instruction_o <= instruction;

end architecture synthesis;

