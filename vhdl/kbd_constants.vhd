----------------------------------------------------------------------------------
-- QNICE FPGA Keyboard Constants
-- 
-- done in January 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package kbd_constants is

-- locales

constant loc_US         : std_logic_vector(2 downto 0) := "000";
constant loc_DE         : std_logic_vector(2 downto 0) := "001";

-- special keys (transmitted via 15 downto 8 of $FF14)

constant key_f1         : std_logic_vector(7 downto 0) := x"01";
constant key_f2         : std_logic_vector(7 downto 0) := x"02";
constant key_f3         : std_logic_vector(7 downto 0) := x"03";
constant key_f4         : std_logic_vector(7 downto 0) := x"04";
constant key_f5         : std_logic_vector(7 downto 0) := x"05";
constant key_f6         : std_logic_vector(7 downto 0) := x"06";
constant key_f7         : std_logic_vector(7 downto 0) := x"07";
constant key_f8         : std_logic_vector(7 downto 0) := x"08";
constant key_f9         : std_logic_vector(7 downto 0) := x"09";
constant key_f10        : std_logic_vector(7 downto 0) := x"0A";
constant key_f11        : std_logic_vector(7 downto 0) := x"0B";
constant key_f12        : std_logic_vector(7 downto 0) := x"0C";

constant key_cur_up     : std_logic_vector(7 downto 0) := x"10";
constant key_cur_down   : std_logic_vector(7 downto 0) := x"11";
constant key_cur_left   : std_logic_vector(7 downto 0) := x"12";
constant key_cur_right  : std_logic_vector(7 downto 0) := x"13";
constant key_pg_up      : std_logic_vector(7 downto 0) := x"14";
constant key_pg_down    : std_logic_vector(7 downto 0) := x"15";
constant key_pos1       : std_logic_vector(7 downto 0) := x"16";
constant key_end        : std_logic_vector(7 downto 0) := x"17";
constant key_ins        : std_logic_vector(7 downto 0) := x"18";
constant key_del        : std_logic_vector(7 downto 0) := x"19";

-- bits for modifiers (in keyboard.vhd's output these are mapped in this ordering to 5 upto 7)
constant mod_shift_bit  : natural := 0;
constant mod_alt_bit    : natural := 1;
constant mod_ctrl_bit   : natural := 2;

end kbd_constants;

package body kbd_constants is
end kbd_constants;
