library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_result is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To memory subsystem
      mem_valid_o   : out std_logic;
      mem_ready_i   : in  std_logic;
      mem_address_o : out std_logic_vector(15 downto 0);
      mem_data_o    : out std_logic_vector(15 downto 0)
   );
end entity write_result;

architecture synthesis of write_result is

begin

end architecture synthesis;

