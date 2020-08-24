library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This file is the top-level VGA controller. It connects directly to the CPU
-- and to the output ports on the FPGA.
--
-- Register Map:
-- 00 : Control
-- 01 : Cursor X
-- 02 : Cursor Y
-- 03 : Character and Colour at Cursor
-- 04 : Scroll
-- 05 : Offset
-- 06 : hctr_min
-- 07 : hctr_max
-- 08 : vctr_max
--
-- Interpretation of Control Register:
-- bit  4 : R/W : Cursor Size
-- bit  5 : R/W : Cursor Blinking
-- bit  6 : R/W : Cursor Enabled
-- bit  7 : R/W : VGA output enabled
-- bit  8 : R/W : Clear screen
-- bit  9 : R/O : VGA controller busy
-- bit 10 : R/W : Offset enable
-- bit 11 : R/W : Scrolling enable

entity vga_register_map is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      en_i          : in  std_logic;
      we_i          : in  std_logic;
      reg_i         : in  std_logic_vector(3 downto 0);
      data_i        : in  std_logic_vector(15 downto 0);
      data_o        : out std_logic_vector(15 downto 0);

      scroll_en_o   : out std_logic;
      offset_en_o   : out std_logic;
      busy_i        : in  std_logic;
      clrscr_o      : out std_logic;
      vga_en_o      : out std_logic;
      cursor_en_o   : out std_logic;
      blink_en_o    : out std_logic;
      cursor_size_o : out std_logic
   );
end vga_register_map;

architecture synthesis of vga_register_map is

   signal reg0 : std_logic_vector(15 downto 0);
   signal reg1 : std_logic_vector(15 downto 0);
   signal reg2 : std_logic_vector(15 downto 0);
   signal reg3 : std_logic_vector(15 downto 0);
   signal reg4 : std_logic_vector(15 downto 0);
   signal reg5 : std_logic_vector(15 downto 0);
   signal reg6 : std_logic_vector(15 downto 0);
   signal reg7 : std_logic_vector(15 downto 0);
   signal reg8 : std_logic_vector(15 downto 0);

begin

   data_o <= (others => '0');
   reg0 <= (others => '0');

   scroll_en_o   <= reg0(11);
   offset_en_o   <= reg0(10);
   clrscr_o      <= reg0( 8);
   vga_en_o      <= reg0( 7);
   cursor_en_o   <= reg0( 6);
   blink_en_o    <= reg0( 5);
   cursor_size_o <= reg0( 4);

end synthesis;

