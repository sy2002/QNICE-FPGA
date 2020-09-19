library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_sprite is
   port (
      clk_i            : in  std_logic;

      -- Interface to Register Map
      sprite_enable_i  : in  std_logic;
      -- Pixel Counters
      pixel_x_i        : in  std_logic_vector(9 downto 0);
      pixel_y_i        : in  std_logic_vector(9 downto 0);
      color_i          : in  std_logic_vector(15 downto 0);
      -- Interface to Video RAM
      sprite_addr_o    : out std_logic_vector(15 downto 0);
      sprite_data_i    : in  std_logic_vector(15 downto 0);
      -- Current pixel color
      color_o          : out std_logic_vector(15 downto 0);
      delay_o          : out std_logic_vector(9 downto 0)
   );
end vga_sprite;

architecture synthesis of vga_sprite is

--   attribute mark_debug                   : boolean;
--   attribute mark_debug of pixel_x_i      : signal is true;
--   attribute mark_debug of pixel_y_i      : signal is true;
--   attribute mark_debug of color_i        : signal is true;
--   attribute mark_debug of sprite_addr_o  : signal is true;
--   attribute mark_debug of sprite_data_i  : signal is true;
--   attribute mark_debug of color_o        : signal is true;

begin

   color_o <= color_i;

end architecture synthesis;

