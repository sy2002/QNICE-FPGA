-- PS2 keyboard component that outputs ASCII
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015

-- this is mainly a wrapper around Scott Larson's component
-- https://eewiki.net/pages/viewpage.action?pageId=28279002

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
generic (
   clk_freq      : integer
);
port (
   clk           : in std_logic;               -- system clock input
   reset         : in std_logic;               -- system reset
   
   -- PS/2
   ps2_clk       : in std_logic;               -- clock signal from PS/2 keyboard
   ps2_data      : in std_logic;               -- data signal from PS/2 keyboard
   
   -- conntect to CPU's data bus (data high impedance when all reg_* are 0)
   cpu_data      : inout std_logic_vector(15 downto 0);
   reg_state     : in std_logic;
   reg_data      : in std_logic;
   
   -- debug leds
   leds          : out std_logic_vector(7 downto 0)
);
end keyboard;

architecture beh of keyboard is

component ps2_keyboard_to_ascii is
generic (
   clk_freq      : integer;                    -- system clock frequency in Hz
   ps2_debounce_counter_size : integer         -- set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
);
port (
   clk           : in std_logic;               -- system clock input   
   ps2_clk       : in std_logic;               -- clock signal from PS2 keyboard
   ps2_data      : in std_logic;               -- data signal from PS2 keyboard
   ascii_new     : out std_logic;              -- output flag indicating new ASCII value
   ascii_code    : out std_logic_vector(6 downto 0);  -- ASCII value
   
   leds          : out std_logic_vector(7 downto 0)
);
end component;

signal ascii_new     : std_logic;
signal ascii_code    : std_logic_vector(6 downto 0);

signal latched_new   : std_logic;
signal reset_new     : std_logic;

begin

   kbd : ps2_keyboard_to_ascii
      generic map (
         clk_freq => clk_freq,
         ps2_debounce_counter_size => 19       -- @TODO implement as formula: set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
      )
      port map (
         clk => clk,
         ps2_clk => ps2_clk,
         ps2_data => ps2_data,
         ascii_new => ascii_new,
         ascii_code => ascii_code,
         leds => leds
      );
      
   latch_ctrl : process(ascii_new, reset, reset_new)
   begin
      if reset = '1' or reset_new = '1' then
         latched_new <= '0';
      else
         if rising_edge(ascii_new) then
            latched_new <= '1';
         end if;
      end if;
   end process;
      
   bus_driver : process(reg_state, reg_data)
   begin
      reset_new <= '0';
   
      -- read status register
      if reg_state = '1' and reg_data = '0' then
         cpu_data <= "000000000000000" & latched_new;
         
      -- read data and clear status register
      elsif reg_state = '0' and reg_data = '1' then
         cpu_data <= "000000000" & ascii_code;
         reset_new <= '1';
         
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;

end beh;
 