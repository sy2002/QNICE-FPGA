----------------------------------------------------------------------------------
-- QNICE Environment 1 (env1) specific implementation of the memory mapped i/o
-- multiplexing; env1.vhdl's header contains the description of the mapping
--
-- also implements the CPU's WAIT_FOR_DATA bus by setting it to a meaningful
-- value (0) when a device is active, that has no own control facility
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mmio_mux is
port (
   -- input from CPU
   addr              : in std_logic_vector(15 downto 0);
   data_dir          : in std_logic;
   data_valid        : in std_logic;
   
   -- let the CPU wait for data from the bus
   cpu_wait_for_data : out std_logic;
   
   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable        : out std_logic;
   rom_busy          : in std_logic;
   
   -- RAM is enabled when the address is in ($8000..$FEFF)
   ram_enable        : out std_logic;
   ram_busy          : in std_logic;
   
   -- MMIO starts at $FF00
   
   -- TIL base is $FF10
   til_reg0_enable   : out std_logic;
   til_reg1_enable   : out std_logic
);
end mmio_mux;

architecture Behavioral of mmio_mux is

signal ram_enable_i : std_logic;
signal rom_enable_i : std_logic;

begin

   -- TIL register base is FF10
   -- writing to base equals register0 equals the actual value
   -- writing to register1 (FF11) equals the mask
   til_control : process (addr, data_dir, data_valid)
   begin
      if addr(15 downto 4) = x"FF1" and data_dir = '1' and data_valid = '1' then
      
         if addr(3 downto 0) = x"0" then
            til_reg0_enable <= '1';
         else
            til_reg0_enable <= '0';
         end if;
         
         if addr(3 downto 0) = x"1" then
            til_reg1_enable <= '1';
         else
            til_reg1_enable <= '0';
         end if;
         
      else
         til_reg0_enable <= '0';
         til_reg1_enable <= '0';
      end if;
   end process;
   
   -- as long as the RAM is the only device on the bus that can make the
   -- CPU wait, this simple implementation is good enough
   -- otherwise, a "req_busy" bus could be built (replacing the ram_busy input)
   -- the block_ram's busy line is already a tri state, so it is ready for such a bus
   cpu_wait_control : process (ram_enable_i, ram_busy, rom_busy)
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
   
   -- RAM is enabled when the address is in ($8000..$FEFF) and
   -- when a write attempt only occurs while the data is valid
   ram_enable_i <= addr(15)
                   and not (addr(14) and addr(13) and addr(12) and addr(11) and addr(10) and addr(9) and addr(8));
                   -- and not (data_dir and not data_valid);                                      
                   
   ram_enable <= ram_enable_i;
   rom_enable <= rom_enable_i;
                    
end Behavioral;

