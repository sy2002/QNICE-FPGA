-- Reset Controller
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015/January 2016

-- Features:
-- * 80x40 text mode
-- * one color for the whole screen
-- * hardware cursor
-- * large video memory: 64.000 bytes, stores 20 screens aka "pages" (selectable via global var VGA_RAM_SIZE)
-- * hardware scrolling
--
-- Registers:
--
-- register 0: status and control register
--    bits(11:10) hardware scrolling / offset enable: enables the use of the offset registers 4 and 5 for
--                reading/writing to the vram (bit 11 = 1, register 5) and/or
--                for displaying vram contents (bit 10 = 1, register 4)
--    bit 9       busy: vga is currently busy, e.g. clearing the screen, printing, etc.
--                while busy, vga will ignore commands (they can be still written into the registers though)
--    bit 8       clear screen: write 1, read: 1 = clearscreen still active, 0 = ready
--    bit 7       VGA enable signal (1 = on, 0 switches off the vga signal generation)
--    bit 6       HW cursor enable bit
--    bit 5       blink HW cursor enable bit
--    bit 4       HW cursor mode (0 = big; 1 = small)
--    bits(2:0)   output color for the whole screen (3-bit rgb, 8 colors)
-- register 1: cursor x position read/write (0..79)
-- register 2: cusror y position read/write (0..39)
-- register 3: write: print character written into this register's (7 downto 0) bits at cursor x/y position
--             read: bits (7 downto 0) contains the character in video ram at address (cursor x, y)
-- register 4: vga display offset register used e.g. for hardware scrolling (0..63999)
-- register 5: vga read/write offset register used for accessing the whole vram (0..63999)
--
-- this component uses Javier Valcarce's vga core
-- http://www.javiervalcarce.eu/wiki/VHDL_Macro:_VGA80x40

-- how to make fonts, see http://nafe.sourceforge.net/
-- then use the psf2coe.rb and then coe2rom.pl toolchain to generate .rom files

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.env1_globals.all;

entity reset_controller is
end reset_controller;

architecture Behavioral of reset_controller is

begin


end Behavioral;

