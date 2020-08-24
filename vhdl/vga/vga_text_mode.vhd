library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module generates the tile-based output.
-- The tiles are 8 pixels wide and 12 pixels high.  The entire screen contains
-- 80 tiles horizontally and 40 tiles vertically.
--
-- The design works by having a state machine performing two reads from Video
-- RAM for every 8 pixels (i.e. one tile horizontally).
-- Simultaneously, another process continuously (i.e. every clock cycle) reads
-- from Palette RAM.

-- Stage 1 : Read colour and tile from Video RAM (ready in stage 3).
-- Stage 2 : Wait for Video RAM.
-- Stage 3 : Store colour.
--           Read tile bitmap from Video RAM (ready in stage 5).
-- Stage 4 : Wait for Video RAM.
-- Stage 5 : Store font data.

entity vga_text_mode is
   port (
      clk_i            : in  std_logic;

      -- Interface to Register Map
      display_offset_i : in std_logic_vector(15 downto 0);
      tile_offset_i    : in std_logic_vector(15 downto 0);
      -- Pixel Counters
      pixel_x_i        : in  std_logic_vector(9 downto 0);
      pixel_y_i        : in  std_logic_vector(9 downto 0);
      -- Interface to Video RAM
      display_addr_o   : out std_logic_vector(15 downto 0);
      display_data_i   : in  std_logic_vector(15 downto 0);
      font_addr_o      : out std_logic_vector(9 downto 0);
      font_data_i      : in  std_logic_vector(7 downto 0);
      palette_addr_o   : out std_logic_vector(4 downto 0);
      palette_data_i   : in  std_logic_vector(11 downto 0);
      -- Current pixel colour
      colour_o         : out std_logic_vector(11 downto 0);
      delay_o          : out std_logic_vector(9 downto 0)
   );
end vga_text_mode;

architecture synthesis of vga_text_mode is

   -- Size of the font.
   constant C_CHAR_WIDTH  : natural := 8;
   constant C_CHAR_HEIGHT : natural := 12;

   signal offset_x    : natural range 0 to C_CHAR_WIDTH-1;
   signal offset_y    : natural range 0 to C_CHAR_HEIGHT-1;
   signal char_row    : std_logic_vector(9 downto 0);
   signal char_column : std_logic_vector(9 downto 0);

   signal colour_bg_3 : std_logic_vector(3 downto 0);
   signal colour_fg_3 : std_logic_vector(3 downto 0);
   signal tile_3      : std_logic_vector(7 downto 0);

   signal colour_bg_4 : std_logic_vector(3 downto 0);
   signal colour_fg_4 : std_logic_vector(3 downto 0);

   signal colour_bg_5 : std_logic_vector(3 downto 0);
   signal colour_fg_5 : std_logic_vector(3 downto 0);
   signal bitmap_5    : std_logic_vector(C_CHAR_WIDTH-1 downto 0);
   signal column_5    : natural range 0 to C_CHAR_WIDTH-1;
   signal pixel_5     : std_logic;

begin

   -- Calculate character coordinate.
   char_column   <= std_logic_vector(unsigned(pixel_x_i) / C_CHAR_WIDTH);
   char_row      <= std_logic_vector(unsigned(pixel_y_i) / C_CHAR_HEIGHT);

   -- Calculate relative pixel offsets in current character.
   offset_x <= conv_integer(pixel_x_i) mod C_CHAR_WIDTH;
   offset_y <= conv_integer(pixel_y_i) mod C_CHAR_HEIGHT;

   -- Invert column, because the MSB of the bitmap
   -- data corresponds to the lowest pixel coordinate.
   column_5 <= (5 + C_CHAR_WIDTH-1 - offset_x) mod C_CHAR_WIDTH;
   pixel_5  <= bitmap_5(column_5);

   -----------------------
   -- Read from Video RAM
   -----------------------

   p_video_ram : process (clk_i)
      variable address : std_logic_vector(19 downto 0);
   begin
      if rising_edge(clk_i) then

         -- The stage number is determined by the horizontal pixel offset in
         -- the current character.
         case offset_x is

            -- Stage 1 : Read colour and tile from Display RAM.
            --           Ready in stage 3.
            when 0 =>
               address := std_logic_vector(unsigned(char_row)*80) + char_column + display_offset_i;
               display_addr_o <= address(15 downto 0);

            -- Stage 2 : Wait for Display RAM.
            when 1 =>
               null;

            -- Stage 3 : Store colour.
            --           Read bitmap from Font RAM.
            --           Ready in stage 5.
            when 2 =>
               colour_bg_3 <= display_data_i(15 downto 12);
               colour_fg_3 <= display_data_i(11 downto 8);
               tile_3      <= display_data_i(7 downto 0);
               address(15 downto 0) := std_logic_vector(unsigned(tile_3)*12) + offset_y + tile_offset_i;
               font_addr_o <= address(9 downto 0);

            -- Stage 4 : Wait for Font RAM.
            when 3 =>
               colour_bg_4 <= colour_bg_3;
               colour_fg_4 <= colour_fg_3;

            -- Stage 5 : Store bitmap data.
            when 4 =>
               colour_bg_5 <= colour_bg_4;
               colour_fg_5 <= colour_fg_4;
               bitmap_5    <= font_data_i;

            when others => null;
         end case;

      end if;
   end process p_video_ram;


   -------------------------
   -- Read from Palette RAM
   -------------------------

   p_palette_ram : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Stage 6 : Read from palette
         case pixel_5 is
            when '0' => palette_addr_o <= "1" & colour_bg_5;   -- Background colour
            when '1' => palette_addr_o <= "0" & colour_fg_5;   -- Foreground colour
            when others => null;
         end case;
      end if;
   end process p_palette_ram;

   -- Stage 7 : Generate output
   colour_o <= palette_data_i;
   delay_o  <= std_logic_vector(to_unsigned(7, 10));

end architecture synthesis;

