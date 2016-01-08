-- PS2 keyboard component that outputs ASCII
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015 and January 2016

-- heavily inspired by Scott Larson's component
-- https://eewiki.net/pages/viewpage.action?pageId=28279002
-- which has been enhanced by sy2002 to support special keys and locales
--
-- Registers:
--
-- Register $FF13: State register
--    Bit  0 (read only): New ASCII character avaiable for reading
--                        (bits 7 downto 0 of Read register)
--    Bit  1 (read only): New special key available for reading
--                        (bits 15 downto 8 of Read register)
--    Bits 2..4 (read/write): Locales: 000 = US English keyboard layout,
--                            001 = German layout, others: reserved for more locales
-- Register $FF14: Read register
--    Contains the ASCII character in bits 7 downto 0  or the special key code
--    in 15 downto 0. The "or" is meant exclusive, i.e. it cannot happen that
--    one transmission contains an ASCII character PLUS a special character.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
generic (
   clk_freq      : integer                     -- system clock frequency
);
port (
   clk           : in std_logic;               -- system clock
   reset         : in std_logic;               -- system reset
   
   -- PS/2
   ps2_clk       : in std_logic;               -- clock signal from PS/2 keyboard
   ps2_data      : in std_logic;               -- data signal from PS/2 keyboard
   
   -- conntect to CPU's data bus (data high impedance when all reg_* are 0)
   kbd_en        : in std_logic;
   kbd_we        : in std_logic;
   kbd_reg       : in std_logic_vector(1 downto 0);   
   cpu_data      : inout std_logic_vector(15 downto 0)
);
end keyboard;

architecture beh of keyboard is

component ps2_keyboard_to_ascii is
generic (
   clk_freq      : integer;                           -- system clock frequency in Hz
   ps2_debounce_counter_size : integer                -- set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
);
port (
   clk           : in std_logic;                      -- system clock input   
   ps2_clk       : in std_logic;                      -- clock signal from PS2 keyboard
   ps2_data      : in std_logic;                      -- data signal from PS2 keyboard
   ascii_new     : out std_logic;                     -- output flag indicating new ASCII value
   ascii_code    : out std_logic_vector(6 downto 0);  -- ASCII value
   spec_new      : out std_logic;                     -- output flag indicating new special key value
   spec_code     : out std_logic_vector(4 downto 0);  -- special key value
   locale        : in std_logic_vector(2 downto 0)    -- locale will not be latched but eval. in real time
);
end component;

-- signals for communicating with the ps2_keyboard_to_ascii component
signal ascii_new           : std_logic;
signal ascii_code          : std_logic_vector(6 downto 0);
signal spec_new            : std_logic;
signal spec_code           : std_logic_vector(4 downto 0);

-- signals that together form the status register
signal ff_ascii_new        : std_logic;
signal reset_ff_ascii_new  : std_logic;
signal ff_spec_new         : std_logic;
signal reset_ff_spec_new   : std_logic;
signal ff_locale           : std_logic_vector(2 downto 0);

begin

   kbd : ps2_keyboard_to_ascii
      generic map (
         clk_freq => clk_freq,
         ps2_debounce_counter_size => 8       -- set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
      )
      port map (
         clk => clk,
         ps2_clk => ps2_clk,
         ps2_data => ps2_data,
         ascii_new => ascii_new,
         ascii_code => ascii_code,
         spec_new => spec_new,
         spec_code => spec_code,
         locale => ff_locale
      );
      
   ff_ascii_new_handler : process(ascii_new, reset, reset_ff_ascii_new)
   begin
      if reset = '1' or reset_ff_ascii_new = '1' then
         ff_ascii_new <= '0';
      else
         if rising_edge(ascii_new) then
            ff_ascii_new <= '1';
         end if;
      end if;
   end process;
   
   ff_spec_new_handler : process(spec_new, reset, reset_ff_spec_new)
   begin
      if reset = '1' or reset_ff_spec_new = '1' then
         ff_spec_new <= '0';
      else
         if rising_edge(spec_new) then
            ff_spec_new <= '1';
         end if;
      end if;
   end process;
   
   write_ff_locale: process(clk, kbd_en, kbd_we, kbd_reg, reset)
   begin
      if reset = '1' then
         ff_locale <= (others => '0');
      else
         if kbd_en = '1' and kbd_we = '1' and kbd_reg = x"0" then
            if rising_edge(clk) then
               ff_locale <= cpu_data(4 downto 2);
            end if;
         end if;      
      end if;
   end process;
      
   read_registers : process(kbd_en, kbd_we, kbd_reg, ff_locale, ff_spec_new, ff_ascii_new, ascii_code, spec_code)
   begin
      reset_ff_ascii_new <= '0';
      reset_ff_spec_new <= '0';
      
      if kbd_en = '1' and kbd_we = '0' then
         case kbd_reg is
         
            -- read status register
            when "00" =>
               cpu_data <= "00000000000" & ff_locale & ff_spec_new & ff_ascii_new;
               
            -- read data register
            when "01" =>
               cpu_data <= "000" & spec_code & "0" & ascii_code;
               reset_ff_ascii_new <= '1';
               reset_ff_spec_new <= '1';
               
            when others =>
               cpu_data <= (others => '0');
         
         end case;
      else
         cpu_data <= (others => 'Z');
      end if;   
   end process;

end beh;
 