library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity read_dst_operand is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To memory subsystem
      mem_valid_o   : out std_logic;
      mem_ready_i   : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);
      mem_data_i    : out std_logic_vector(15 downto 0)
   );
end entity read_dst_operand;

architecture synthesis of read_dst_operand is

begin

end architecture synthesis;

