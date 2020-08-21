library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_text_mode is
   port (
      clk_i       : in  std_logic;

      -- Interface to Register Map
      scroll_en_i : in  std_logic;
      offset_en_i : in  std_logic;
      busy_o      : out std_logic;
      clrscr_i    : in  std_logic;
      vga_en_i    : in  std_logic;
      curs_en_i   : in  std_logic;
      blink_en_i  : in  std_logic;
      curs_mode_i : in  std_logic;
      -- Pixel Counters
      pixel_x_i   : in  std_logic_vector(9 downto 0);
      pixel_y_i   : in  std_logic_vector(9 downto 0);
      -- Interface to Video RAM
      vram_addr_o : out std_logic_vector(14 downto 0);
      vram_data_i : in  std_logic_vector(15 downto 0);
      -- Current pixel colour
      colour_o    : out std_logic_vector(11 downto 0);
      delay_o     : out std_logic_vector(9 downto 0)
   );
end vga_text_mode;

architecture synthesis of vga_text_mode is

begin

end architecture synthesis;

