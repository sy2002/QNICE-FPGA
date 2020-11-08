library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu_constants.all;

entity read_instruction is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      flush_i       : in  std_logic;

      -- Read from register file
      pc_i          : in  std_logic_vector(15 downto 0);

      -- Write to register file (combinatorial)
      pc_o          : out std_logic_vector(15 downto 0);

      -- Read from memory subsystem (combinatorial)
      mem_valid_o   : out std_logic;
      mem_ready_i   : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);

      -- To next pipeline stage (registered)
      valid_o       : out std_logic;
      ready_i       : in  std_logic;
      pc_inst_o     : out std_logic_vector(15 downto 0);
      wait_i        : in  std_logic
   );
end entity read_instruction;

architecture synthesis of read_instruction is

   signal dbg_cycle_counter_r : std_logic_vector(15 downto 0);
   signal dbg_inst_counter_r  : std_logic_vector(15 downto 0);

   signal mem_request : std_logic;
   signal mem_ready   : std_logic;
   signal ready       : std_logic;

   signal valid_r     : std_logic := '0';
   signal pc_inst_r   : std_logic_vector(15 downto 0);

begin

   -- Do we want to read from memory?
   mem_request <= '0' when rst_i = '1' else
                  '0' when valid_r = '1' and ready_i = '0' else
                  '0' when flush_i = '1' else
                  '0' when wait_i = '1' else
                  '1';

   -- Are we waiting for memory read access?
   mem_ready <= not (mem_request and not mem_ready_i);

   -- Are we ready to complete this stage?
   ready <= mem_request and mem_ready and ready_i and not flush_i;


   -- To register file (combinatorial)
   pc_o <= pc_i + 1 when ready = '1' else
           pc_i;

   -- To memory subsystem
   mem_address_o <= pc_i;
   mem_valid_o   <= mem_request;

   -- To next pipeline stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         dbg_cycle_counter_r <= dbg_cycle_counter_r + 1;

         -- Has next stage consumed the output?
         if ready_i = '1' or flush_i = '1' then
            valid_r   <= '0';
            pc_inst_r <= (others => '0');
         end if;

         if ready = '1' then
            dbg_inst_counter_r <= dbg_inst_counter_r + 1;
            valid_r   <= '1';
            pc_inst_r <= pc_i;
         end if;

         if rst_i = '1' then
            valid_r   <= '0';
            pc_inst_r <= (others => '0');
            dbg_cycle_counter_r <= (others => '0');
            dbg_inst_counter_r  <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

   valid_o   <= valid_r;
   pc_inst_o <= pc_inst_r;

end architecture synthesis;

