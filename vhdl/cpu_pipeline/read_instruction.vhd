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

      -- To next pipeline stage
      instruction_o : out std_logic_vector(15 downto 0)
   );
end entity read_instruction;

architecture synthesis of read_instruction is

   -- Instruction format is as follows
   subtype R_OPCODE    is natural range 15 downto 12;
   subtype R_SRC_REG   is natural range 11 downto  8;
   subtype R_SRC_MODE  is natural range  7 downto  6;
   subtype R_DEST_REG  is natural range  5 downto  2;
   subtype R_DEST_MODE is natural range  1 downto  0;

begin

   p_instruction : process (clk_i)
   begin
      if rising_edge(clk_i) then
         instruction_o <= mem_data_i;
      end if;
   end process p_instruction;

end architecture synthesis;

