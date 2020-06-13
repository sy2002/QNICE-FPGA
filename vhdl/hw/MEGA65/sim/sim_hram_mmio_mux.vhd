----------------------------------------------------------------------------------
-- MEGA65 simulation version of QNICE's MMIO controller
-- enhanced by sy2002 in April to June 2020
--
-- Changes to the standard controller:
-- * Added HyperRAM handling ($FF60 .. $FF62) including CPU wait states
-- * Removed PORE system
-- * Removed TIL, VGA, UART, Keyboard, Cycle Counter, EAE, SD Card
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity mmio_mux is
port (
   -- input from hardware
   HW_RESET          : in std_logic;
   CLK               : in std_logic;

   -- input from CPU
   addr              : in std_logic_vector(15 downto 0);
   data_dir          : in std_logic;
   data_valid        : in std_logic;
   cpu_halt          : in std_logic;
   
   -- let the CPU wait for data from the bus
   cpu_wait_for_data : out std_logic;
   
   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable        : out std_logic;
   rom_busy          : in std_logic;
   
   -- RAM is enabled when the address is in ($8000..$FEFF)
   ram_enable        : out std_logic;
   ram_busy          : in std_logic;
   
   -- SWITCHES is $FF12
   switch_reg_enable : out std_logic;
      
   -- HyerRAM register range $FF60 .. $FF62
   hram_en           : out std_logic;
   hram_we           : out std_logic;
   hram_reg          : out std_logic_vector(3 downto 0); 
   hram_cpu_ws       : in std_logic  -- insert CPU wait states (aka WAIT_FOR_DATA)      
);
end mmio_mux;

architecture Behavioral of mmio_mux is

signal ram_enable_i : std_logic;
signal rom_enable_i : std_logic;

begin   
   
   -- SWITCH register is FF12
   switch_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 0) = x"FF12" and data_dir = '0' then
         switch_reg_enable <= '1';
      else
         switch_reg_enable <= '0';
      end if;
   end process;
 
   -- HyperRAM starts at FF60
   hram_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 4) = x"FF6" then
         hram_en <= '1';
         hram_we <= data_dir and data_valid;
         hram_reg <= addr(3 downto 0);
      else
         hram_en <= '0';
         hram_we <= '0';
         hram_reg <= (others => '0');
      end if;
   end process;   
      
   -- generate CPU wait signal   
   -- as long as the RAM is the only device on the bus that can make the
   -- CPU wait, this simple implementation is good enough
   -- otherwise, a "req_busy" bus could be built (replacing the ram_busy input)
   -- the block_ram's busy line is already a tri state, so it is ready for such a bus
   cpu_wait_control : process (ram_enable_i, rom_enable_i, ram_busy, rom_busy, hram_cpu_ws)
   begin
      if ram_enable_i = '1' and ram_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif rom_enable_i = '1' and rom_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif hram_cpu_ws = '1' then
         cpu_wait_for_data <= '1';
      else
         cpu_wait_for_data <= '0';
      end if;
   end process;

   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable_i <= not addr(15) and not data_dir;
   
   -- RAM is enabled when the address is in ($8000..$FEFF)
   ram_enable_i <= addr(15)
                   and not (addr(14) and addr(13) and addr(12) and addr(11) and addr(10) and addr(9) and addr(8));
               
   -- generate external RAM/ROM/PORE enable signals
   ram_enable <= ram_enable_i;
   rom_enable <= rom_enable_i;
      
end Behavioral;
