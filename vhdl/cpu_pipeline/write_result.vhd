library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity write_result is
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      -- From previous stage
      instruction_i  : in  std_logic_vector(15 downto 0);
      src_data_i     : in  std_logic_vector(15 downto 0);
      dst_data_i     : in  std_logic_vector(15 downto 0);

      -- From register file
      sr_i           : in  std_logic_vector(7 downto 0);

      -- To memory subsystem
      mem_valid_o    : out std_logic;
      mem_ready_i    : in  std_logic;
      mem_address_o  : out std_logic_vector(15 downto 0);
      mem_data_o     : out std_logic_vector(15 downto 0);

      -- To register file
      reg_res_reg_o  : out std_logic_vector(3 downto 0);
      reg_res_wr_o   : out std_logic;
      reg_res_data_o : out std_logic_vector(15 downto 0)
   );
end entity write_result;

architecture synthesis of write_result is

   signal res_data : std_logic_vector(15 downto 0);
   signal sr       : std_logic_vector(7 downto 0);

begin

   i_alu : entity work.alu
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         src_data_i => src_data_i,
         dst_data_i => dst_data_i,
         sr_i       => sr_i,
         opcode_i   => instruction_i(R_OPCODE),
         res_data_o => res_data,
         sr_o       => sr
      ); -- i_alu

end architecture synthesis;

