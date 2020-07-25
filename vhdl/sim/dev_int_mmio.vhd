----------------------------------------------------------------------------------
-- QNICE Environment 1 (env1) specific implementation of the memory mapped i/o
-- multiplexing; env1.vhdl's header contains the description of the mapping
--
-- also implements the CPU's WAIT_FOR_DATA bus by setting it to a meaningful
-- value (0) when a device is active, that has no own control facility
--
-- also implements the global state and reset management
-- 
-- done in 2015, 2016 by sy2002
-- enhanced in July 2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;
use work.qnice_tools.all;

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
   
   -- Extended Arithmetic Element register range $FF1B..$FF1F
   eae_en            : out std_logic;
   eae_we            : out std_logic;
   eae_reg           : out std_logic_vector(2 downto 0)   
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
         
   eae_control : process(addr, data_dir, data_valid)
   begin
      eae_en <= '0';
      eae_we <= '0';
      eae_reg <= "000";
      
      if addr = x"FF1B" then
         eae_en <= '1';
         eae_we <= data_dir and data_valid;
         eae_reg <= "000";
      elsif addr = x"FF1C" then
         eae_en <= '1';
         eae_we <= data_dir and data_valid;
         eae_reg <= "001";
      elsif addr = x"FF1D" then
         eae_en <= '1';
         eae_we <= data_dir and data_valid;
         eae_reg <= "010";
      elsif addr = x"FF1E" then
         eae_en <= '1';
         eae_we <= data_dir and data_valid;
         eae_reg <= "011";
      elsif addr = x"FF1F" then
         eae_en <= '1';
         eae_we <= data_dir and data_valid;
         eae_reg <= "100";
      end if;      
   end process;
      
   -- generate CPU wait signal   
   -- as long as the RAM is the only device on the bus that can make the
   -- CPU wait, this simple implementation is good enough
   -- otherwise, a "req_busy" bus could be built (replacing the ram_busy input)
   -- the block_ram's busy line is already a tri state, so it is ready for such a bus
   cpu_wait_control : process (ram_enable_i, rom_enable_i, ram_busy, rom_busy)
   begin
      if ram_enable_i = '1' and ram_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif rom_enable_i = '1' and rom_busy = '1' then
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
