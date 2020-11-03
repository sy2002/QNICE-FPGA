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

begin

   -- To register file (combinatorial)
   pc_o          <= pc_i + 1 when mem_ready_i = '1' else
                    pc_i;


   -- To memory subsystem (combinatorial)
   mem_address_o <= pc_i;
   mem_valid_o   <= not rst_i;


   -- To next pipeline stage (registered)
   p_next_stage : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid_o       <= '0';
         instruction_o <= (others => '0');

         if mem_ready_i = '1' then
            valid_o       <= '1';
            instruction_o <= mem_data_i;
         end if;

         if rst_i = '1' then
            valid_o       <= '0';
            instruction_o <= (others => '0');
         end if;
      end if;
   end process p_next_stage;

end architecture synthesis;
