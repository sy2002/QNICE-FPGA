library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module generates the tile-based output.
-- The tiles are 8 pixels wide and 12 pixels high.  The entire screen contains
-- 80 tiles horizontally and 40 tiles vertically.
--
-- The design works by having a three-stage pipeline:
-- Stage 0 : Read from Display RAM. Ready in Stage 1.
-- Stage 1 : Read from Font RAM. Ready in Stage 2.
-- Stage 2 : Read from Palette RAM. Ready in Stage 3.
-- Stage 3 : Generate output

entity vga_text_mode is
   port (
      clk_i            : in  std_logic;

      -- Interface to Register Map
      display_offset_i : in  std_logic_vector(15 downto 0);
      font_offset_i    : in  std_logic_vector(15 downto 0);
      palette_offset_i : in  std_logic_vector(15 downto 0);
      cursor_enable_i  : in  std_logic;
      cursor_blink_i   : in  std_logic;
      cursor_size_i    : in  std_logic;
      cursor_x_i       : in  std_logic_vector(6 downto 0); -- 0 to 79
      cursor_y_i       : in  std_logic_vector(5 downto 0); -- 0 to 39
      -- Pixel Counters
      pixel_x_i        : in  std_logic_vector(9 downto 0);
      pixel_y_i        : in  std_logic_vector(9 downto 0);
      frame_i          : in  std_logic_vector(5 downto 0);
      -- Interface to Video RAM
      display_addr_o   : out std_logic_vector(15 downto 0);
      display_data_i   : in  std_logic_vector(15 downto 0);
      font_addr_o      : out std_logic_vector(12 downto 0);
      font_data_i      : in  std_logic_vector(7 downto 0);
      palette_addr_o   : out std_logic_vector(5 downto 0);
      palette_data_i   : in  std_logic_vector(14 downto 0);
      -- Current pixel color
      color_o          : out std_logic_vector(15 downto 0);
      delay_o          : out std_logic_vector(9 downto 0)
   );
end vga_text_mode;

architecture synthesis of vga_text_mode is

   -- Size of the font.
   constant C_CHAR_WIDTH  : natural := 8;
   constant C_CHAR_HEIGHT : natural := 12;

   type t_stage0 is record
      char_column   : std_logic_vector(9 downto 0);
      char_row      : std_logic_vector(9 downto 0);
      char_offset_x : natural range 0 to C_CHAR_WIDTH-1;
      char_offset_y : natural range 0 to C_CHAR_HEIGHT-1;
      display_addr  : std_logic_vector(19 downto 0);
   end record t_stage0;

   type t_stage1 is record
      color_bg      : std_logic_vector(3 downto 0);
      color_fg      : std_logic_vector(3 downto 0);
      tile          : std_logic_vector(7 downto 0);
      char_offset_y : natural range 0 to C_CHAR_HEIGHT-1;
      font_addr     : std_logic_vector(15 downto 0);
   end record t_stage1;

   type t_stage2 is record
      bitmap        : std_logic_vector(C_CHAR_WIDTH-1 downto 0);
      color_bg      : std_logic_vector(3 downto 0);
      color_fg      : std_logic_vector(3 downto 0);
      pixel_x       : std_logic_vector(9 downto 0);
      char_column   : std_logic_vector(9 downto 0);
      char_row      : std_logic_vector(9 downto 0);
      char_offset_x : natural range 0 to C_CHAR_WIDTH-1;
      char_offset_y : natural range 0 to C_CHAR_HEIGHT-1;
      bitmap_index  : natural range 0 to C_CHAR_WIDTH-1;
      font_pixel    : std_logic;
      cursor_blink  : std_logic_vector(5 downto 0);
      cursor_pixel  : std_logic;
      cursor_here   : std_logic;
      pixel         : std_logic;
      palette_addr  : std_logic_vector(4 downto 0);
   end record t_stage2;

   type t_stage3 is record
      pixel         : std_logic;
   end record t_stage3;

   signal stage0 : t_stage0;
   signal stage1 : t_stage1;
   signal stage2 : t_stage2;
   signal stage3 : t_stage3;

--   attribute mark_debug                   : boolean;
--   attribute mark_debug of cursor_x_i     : signal is true;
--   attribute mark_debug of cursor_y_i     : signal is true;
--   attribute mark_debug of pixel_x_i      : signal is true;
--   attribute mark_debug of pixel_y_i      : signal is true;
--   attribute mark_debug of frame_i        : signal is true;
--   attribute mark_debug of display_addr_o : signal is true;
--   attribute mark_debug of display_data_i : signal is true;
--   attribute mark_debug of font_addr_o    : signal is true;
--   attribute mark_debug of font_data_i    : signal is true;
--   attribute mark_debug of palette_addr_o : signal is true;
--   attribute mark_debug of palette_data_i : signal is true;
--   attribute mark_debug of color_o        : signal is true;

begin

   -----------------------------------------------------
   -- Stage 0 : Read from Display RAM. Ready in Stage 1.
   -----------------------------------------------------

   -- Calculate character coordinate.
   stage0.char_column <= std_logic_vector(unsigned(pixel_x_i) / C_CHAR_WIDTH);
   stage0.char_row    <= std_logic_vector(unsigned(pixel_y_i) / C_CHAR_HEIGHT);

   -- Calculate relative pixel offsets in current character.
   stage0.char_offset_x <= conv_integer(pixel_x_i) mod C_CHAR_WIDTH;
   stage0.char_offset_y <= conv_integer(pixel_y_i) mod C_CHAR_HEIGHT;

   -- Calculate address in Display RAM.
   stage0.display_addr <= std_logic_vector(unsigned(stage0.char_row)*80)
                          + stage0.char_column + display_offset_i;
   display_addr_o <= stage0.display_addr(15 downto 0);


   -----------------------------------------------------
   -- Stage 1 : Read from Font RAM. Ready in Stage 2.
   -----------------------------------------------------

   -- Decode value read from Display RAM
   stage1.color_bg <= display_data_i(15 downto 12);
   stage1.color_fg <= display_data_i(11 downto 8);
   stage1.tile      <= display_data_i(7 downto 0);

   -- Just copy char_offset_y because it is constant during a raster line.
   stage1.char_offset_y <= stage0.char_offset_y;

   -- Calculate address in Font RAM
   stage1.font_addr <= std_logic_vector(unsigned(stage1.tile)*C_CHAR_HEIGHT)
                       + stage1.char_offset_y + font_offset_i;
   font_addr_o <= stage1.font_addr(12 downto 0);



   -----------------------------------------------------
   -- Stage 2 : Read from Palette RAM. Ready in Stage 3.
   -----------------------------------------------------

   -- Store bitmap from Font RAM
   stage2.bitmap <= font_data_i;

   -- Color information from Stage 1 must be delayed one clock cycle.
   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2.color_bg <= stage1.color_bg;
         stage2.color_fg <= stage1.color_fg;
      end if;
   end process p_stage2;

   -- Calculate pixel coordinate for Stage 2.
   stage2.pixel_x <= pixel_x_i - 2;

   -- Calculate character coordinate for Stage 2.
   stage2.char_column <= std_logic_vector(unsigned(stage2.pixel_x) / C_CHAR_WIDTH);

   -- Just copy char_row because it is constant during a raster line.
   stage2.char_row <= stage0.char_row;

   -- Calculate relative pixel offset for Stage 2.
   stage2.char_offset_x <= conv_integer(stage2.pixel_x) mod C_CHAR_WIDTH;

   -- Just copy char_offset_y because it is constant during a raster line.
   stage2.char_offset_y <= stage0.char_offset_y;

   -- Calculate index into bitmap
   stage2.bitmap_index <= C_CHAR_WIDTH-1 - stage2.char_offset_x;

   -- Get pixel from font bitmap
   stage2.font_pixel <= stage2.bitmap(stage2.bitmap_index);

   -- Generate cursor blink frequency (2 Hz).
   stage2.cursor_blink <= std_logic_vector(unsigned(frame_i) / 15);

   -- Calculate cursor pixel
   stage2.cursor_pixel <= (not cursor_blink_i) or stage2.cursor_blink(1);

   -- Determine whether the cursor covers this pixel.
   stage2.cursor_here <= '1' when conv_integer(cursor_x_i) = conv_integer(stage2.char_column) and
                                  conv_integer(cursor_y_i) = conv_integer(stage2.char_row) and
                                  (cursor_size_i = '0' or stage2.char_offset_y > 8)
                    else '0';

   -- Read pixel from cursor or from bitmap.
   stage2.pixel <= stage2.font_pixel xor stage2.cursor_pixel when cursor_enable_i = '1' and stage2.cursor_here = '1'
              else stage2.font_pixel;

   -- Read color from Palette RAM
   stage2.palette_addr <= "0" & stage2.color_fg when stage2.pixel = '1'   -- Foreground color
                     else "1" & stage2.color_bg;                          -- Background color

   palette_addr_o <= ("0" & stage2.palette_addr) + palette_offset_i(5 downto 0);


   -----------------------------------------------------
   -- Stage 3 : Generate output
   -----------------------------------------------------

   -- Pixel information from Stage 2 must be delayed one clock cycle.
   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3.pixel <= stage2.pixel;
      end if;
   end process p_stage3;

   color_o <= stage3.pixel & palette_data_i;
   delay_o <= std_logic_vector(to_unsigned(3, 10));

end architecture synthesis;

