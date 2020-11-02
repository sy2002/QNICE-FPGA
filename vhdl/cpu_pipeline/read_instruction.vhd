library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity read_instruction is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To memory subsystem
      mem_valid_o   : out std_logic;
      mem_ready_i   : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);
      mem_data_i    : in  std_logic_vector(15 downto 0);

      -- To register file
      pc_i          : in  std_logic_vector(15 downto 0);

      -- To next pipeline stage
      instruction_o : out std_logic_vector(15 downto 0)
   );
end entity read_instruction;

architecture synthesis of read_instruction is

begin

   mem_address_o <= pc_i;
   mem_valid_o   <= '1';

   p_instruction : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if mem_ready_i = '1' then
            instruction_o <= mem_data_i;
         end if;
      end if;
   end process p_instruction;

end architecture synthesis;

