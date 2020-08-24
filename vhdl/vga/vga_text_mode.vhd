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
      display_offset_i : in  std_logic_vector(15 downto 0);
      tile_offset_i    : in  std_logic_vector(15 downto 0);
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

   signal offset_x_0    : natural range 0 to C_CHAR_WIDTH-1;
   signal offset_y_0    : natural range 0 to C_CHAR_HEIGHT-1;
   signal char_row_0    : std_logic_vector(9 downto 0);
   signal char_column_0 : std_logic_vector(9 downto 0);
   signal cursor_here_0 : std_logic;

   signal cursor_here_1 : std_logic;

   signal cursor_here_2 : std_logic;

   signal colour_bg_3   : std_logic_vector(3 downto 0);
   signal colour_fg_3   : std_logic_vector(3 downto 0);
   signal tile_3        : std_logic_vector(7 downto 0);
   signal cursor_here_3 : std_logic;

   signal colour_bg_4   : std_logic_vector(3 downto 0);
   signal colour_fg_4   : std_logic_vector(3 downto 0);
   signal cursor_here_4 : std_logic;

   signal colour_bg_5   : std_logic_vector(3 downto 0);
   signal colour_fg_5   : std_logic_vector(3 downto 0);
   signal bitmap_5      : std_logic_vector(C_CHAR_WIDTH-1 downto 0);
   signal column_5      : natural range 0 to C_CHAR_WIDTH-1;
   signal pixel_5       : std_logic;
   signal cursor_here_5 : std_logic;

   attribute mark_debug                   : boolean;
   attribute mark_debug of pixel_x_i      : signal is true;
   attribute mark_debug of pixel_y_i      : signal is true;
   attribute mark_debug of display_addr_o : signal is true;
   attribute mark_debug of display_data_i : signal is true;
   attribute mark_debug of font_addr_o    : signal is true;
   attribute mark_debug of font_data_i    : signal is true;
   attribute mark_debug of palette_addr_o : signal is true;
   attribute mark_debug of palette_data_i : signal is true;
   attribute mark_debug of colour_o       : signal is true;

begin

   -- Calculate character coordinate.
   char_column_0   <= std_logic_vector(unsigned(pixel_x_i) / C_CHAR_WIDTH);
   char_row_0      <= std_logic_vector(unsigned(pixel_y_i) / C_CHAR_HEIGHT);

   cursor_here_0 <= '1' when  ("000" & cursor_x_i) = char_column_0 and
                             ("0000" & cursor_y_i) = char_row_0
               else '0';

   -- Calculate relative pixel offsets in current character.
   offset_x_0 <= conv_integer(pixel_x_i) mod C_CHAR_WIDTH;
   offset_y_0 <= conv_integer(pixel_y_i) mod C_CHAR_HEIGHT;

   -- Invert column, because the MSB of the bitmap
   -- data corresponds to the lowest pixel coordinate.
   column_5 <= (5 + C_CHAR_WIDTH-1 - offset_x_0) mod C_CHAR_WIDTH;
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
         case offset_x_0 is

            -- Stage 1 : Read colour and tile from Display RAM.
            --           Ready in stage 3.
            when 0 =>
               address := std_logic_vector(unsigned(char_row_0)*80) + char_column_0 + display_offset_i;
               display_addr_o <= address(15 downto 0);
               cursor_here_1  <= cursor_here_0;

            -- Stage 2 : Wait for Display RAM.
            when 1 =>
               cursor_here_2  <= cursor_here_1;

            -- Stage 3 : Store colour.
            --           Read bitmap from Font RAM.
            --           Ready in stage 5.
            when 2 =>
               colour_bg_3   <= display_data_i(15 downto 12);
               colour_fg_3   <= display_data_i(11 downto 8);
               tile_3        <= display_data_i(7 downto 0);
               address(15 downto 0) := std_logic_vector(unsigned(tile_3)*12) + offset_y_0 + tile_offset_i;
               font_addr_o   <= address(9 downto 0);
               cursor_here_3 <= cursor_here_2;

            -- Stage 4 : Wait for Font RAM.
            when 3 =>
               colour_bg_4   <= colour_bg_3;
               colour_fg_4   <= colour_fg_3;
               cursor_here_4 <= cursor_here_3;

            -- Stage 5 : Store bitmap data.
            when 4 =>
               colour_bg_5   <= colour_bg_4;
               colour_fg_5   <= colour_fg_4;
               bitmap_5      <= font_data_i;
               cursor_here_5 <= cursor_here_4;

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

         if cursor_enable_i = '1' and cursor_here_5 = '1' then
            palette_addr_o <= "0" & colour_fg_5;   -- Foreground colour
         end if;

      end if;
   end process p_palette_ram;

   -- Stage 7 : Generate output
   colour_o <= palette_data_i;
   delay_o  <= std_logic_vector(to_unsigned(7, 10));

end architecture synthesis;

