----------------------------------------------------------------------------------
-- FPGA implementation of the QNICE sysinfo block
--
-- done in 2020 by MJoergen
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.env1_globals.all;

entity sysinfo is
   port (
      clk      : in  std_logic;
      reset    : in  std_logic;
      en       : in  std_logic;
      we       : in  std_logic;
      reg      : in  std_logic_vector(0 downto 0);
      data_in  : in  std_logic_vector(15 downto 0);
      data_out : out std_logic_vector(15 downto 0)
   );
end entity sysinfo;

architecture synthesis of sysinfo is

   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(15 downto 0);

begin

   write_registers : process (clk)
   begin
      if rising_edge(clk) then
         -- register 0: SYSINFO address
         if en = '1' and we = '1' and reg = "0" then
            addr <= data_in;
         end if;
      end if;
   end process write_registers;

   data_out <= addr when en = '1' and we = '0' and reg = "0" else
               data when en = '1' and we = '0' and reg = "1" else
               (others => '0');

   p_data : process (addr)
   begin
      case addr is
         when X"0000" => data <= SYSINFO_HW_PLATFORM;
         when X"0001" => data <= std_logic_vector(to_unsigned(SYSTEM_SPEED / 1000000, 16));
         when X"0002" => data <= std_logic_vector(to_unsigned(SHADOW_REGFILE_SIZE, 16));
         when X"0003" => data <= BLOCK_RAM_START;
         when X"0004" => data <= std_logic_vector(to_unsigned(BLOCK_RAM_SIZE/1024, 16));
         when X"0005" => data <= std_logic_vector(to_unsigned(VGA_NUM_SPRITES, 16));
         when X"0006" => data <= std_logic_vector(to_unsigned(VGA_RAM_SIZE/80, 16));
         when X"0007" => data <= std_logic_vector(to_unsigned(UART_BAUDRATE_MAX/1000, 16));
         when X"0008" => data <= X"0170";
         when X"0100" => data <= std_logic_vector(to_unsigned(SYSINFO_MMU_PRESENT, 16));
         when X"0101" => data <= std_logic_vector(to_unsigned(SYSINFO_EAE_PRESENT, 16));
         when X"0102" => data <= std_logic_vector(to_unsigned(SYSINFO_FPU_PRESENT, 16));
         when X"0103" => data <= std_logic_vector(to_unsigned(SYSINFO_GPU_PRESENT, 16));
         when X"0104" => data <= std_logic_vector(to_unsigned(SYSINFO_KBD_PRESENT, 16));
         when others  => data <= (others => '0');
      end case;
   end process p_data;

end synthesis;

