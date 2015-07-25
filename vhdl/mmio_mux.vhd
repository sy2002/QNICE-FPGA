----------------------------------------------------------------------------------
-- QNICE Environment 1 (env1) specific implementation of the memory mapped i/o
-- multiplexing; env1.vhdl's header contains the description of the mapping
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
   
   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable        : out std_logic;
   til_reg0_enable   : out std_logic;
   til_reg1_enable   : out std_logic
);
end mmio_mux;

architecture Behavioral of mmio_mux is

begin

   -- TIL register base is FF10
   -- writing to base equals register0 equals the actual value
   -- writing to register1 (FF11) equals the mask
   til_control : process(addr, data_dir, data_valid)
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

   rom_enable <= not addr(15) and not data_dir;
   
end Behavioral;

