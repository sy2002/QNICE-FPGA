-- 80x40 Textmode VGA
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015

-- this is mainly a wrapper around Javier Valcarce's component
-- http://www.javiervalcarce.eu/wiki/VHDL_Macro:_VGA80x40

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_textmode is
port (
   reset    : in  std_logic;     -- async reset
   clk50MHz : in  std_logic;     -- needs to be a 50 MHz clock
   
   -- VGA signals, monochrome only
   R        : out std_logic;
   G        : out std_logic;
   B        : out std_logic;
   hsync    : out std_logic;
   vsync    : out std_logic
);
end vga_textmode;

architecture beh of vga_textmode is

component vga80x40
port (
   reset       : in  std_logic;
   clk25MHz    : in  std_logic;

   -- VGA signals, monochrome only   
   R           : out std_logic;
   G           : out std_logic;
   B           : out std_logic;
   hsync       : out std_logic;
   vsync       : out std_logic;
   
   -- address and data lines of video ram for text
   TEXT_A           : out std_logic_vector(11 downto 0);
   TEXT_D           : in  std_logic_vector(07 downto 0);
   
   -- address and data lines of font rom
   FONT_A           : out std_logic_vector(11 downto 0);
   FONT_D           : in  std_logic_vector(07 downto 0);
   
   -- hardware cursor x and y positions
   ocrx    : in  std_logic_vector(7 downto 0);
   ocry    : in  std_logic_vector(7 downto 0);
   
   -- control register
   -- Control of the peripheral. Bit 7 (MSB) is VGA enable signal. Bit 6 is HW cursor enable bit. Bit 5 is Blink HW cursor enable bit. Bit 4 is HW cursor mode (0 = big; 1 = small). Bits(2:0) is the output color. 
   octl    : in  std_logic_vector(7 downto 0)
);   
end component;



begin


end beh;

