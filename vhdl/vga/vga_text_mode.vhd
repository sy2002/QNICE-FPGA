library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module generates the tile-based output.
-- The tiles are 8 pixels wide and 12 pixels high.  The entire screen contains
-- 80 tiles horizontally and 40 tiles vertically.
--
-- The design works by having a state machine performing two reads from Video
-- RAM for every 8 pixels (i.e. one tile gorizaontally).
-- Simultaneously, another process continuously (i.e. every clock cycle) reads
-- from Palette RAM.

-- Stage 0 : Read colour and tile from Video RAM (ready in stage 2).
-- Stage 1 : Wait for Video RAM.
-- Stage 2 : Store colour and tile.
--           Read tile bitmap from Video RAM (ready in stage 4).
-- Stage 3 : Wait for Video RAM.
-- Stage 4 : Store font data.

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
      vram_addr_o      : out std_logic_vector(14 downto 0);
      vram_data_i      : in  std_logic_vector(15 downto 0);
      -- Interface to Palette RAM
      palette_addr_o   : out std_logic_vector(4 downto 0);
      palette_data_i   : in  std_logic_vector(15 downto 0);
      -- Current pixel colour
      colour_o         : out std_logic_vector(11 downto 0);
      delay_o          : out std_logic_vector(9 downto 0)
   );
end vga_text_mode;

architecture synthesis of vga_text_mode is

   -- Size of the font.
   constant C_CHAR_WIDTH  : natural := 8;
   constant C_CHAR_HEIGHT : natural := 12;

   signal offset_x : natural range 0 to C_CHAR_WIDTH-1;
   signal offset_y : natural range 0 to C_CHAR_HEIGHT-1;
   signal row      : std_logic_vector(9 downto 0);
   signal column   : std_logic_vector(9 downto 0);

   signal colour_bg : std_logic_vector(3 downto 0);
   signal colour_fg : std_logic_vector(3 downto 0);
   signal tile      : std_logic_vector(7 downto 0);
   signal bitmap    : std_logic_vector(15 downto 0);

begin

   -- Calculate character coordinate.
   column   <= std_logic_vector(unsigned(pixel_x_i) / C_CHAR_WIDTH);
   row      <= std_logic_vector(unsigned(pixel_y_i) / C_CHAR_HEIGHT);

   -- Calculate relative pixel offsets in current character.
   offset_x <= conv_integer(pixel_x_i) mod C_CHAR_WIDTH;
   offset_y <= conv_integer(pixel_y_i) mod C_CHAR_HEIGHT;


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

            -- Stage 0 : Read colour and tile from Video RAM.
            --           Ready in stage 2.
            when 0 =>
               address := std_logic_vector(unsigned(row)*80) + column + display_offset_i;
               vram_addr_o <= address(14 downto 0);

            -- Stage 1 : Wait for Video RAM.
            when 1 =>
               null;

            -- Stage 2 : Store colour and tile.
            --           Read tile bitmap from Video RAM.
            --           Ready in stage 4.
            when 2 =>
               colour_bg   <= vram_data_i(15 downto 12);
               colour_fg   <= vram_data_i(11 downto 8);
               tile        <= vram_data_i(7 downto 0);
               address(15 downto 0) := std_logic_vector(unsigned(tile)*12) + offset_y + tile_offset_i;
               vram_addr_o <= address(14 downto 0);

            -- Stage 3 : Wait for Video RAM.
            when 3 =>
               null;

            -- Stage 4 : Store font data.
            when 4 =>
               bitmap <= vram_data_i;

            when others => null;
         end case;

      end if;
   end process p_video_ram;


   -------------------------
   -- Read from Palette RAM
   -------------------------

   p_palette_ram : process (clk_i)
      variable column : natural range 0 to C_CHAR_WIDTH-1;
      variable pixel  : std_logic;
   begin
      if rising_edge(clk_i) then
         -- Invert column, because the MSB of the bitmap
         -- data corresponds to the lowest pixel coordinate.
         column := C_CHAR_WIDTH-1 - offset_x;

         pixel  := bitmap(column);

         case pixel is
            when '0' => palette_addr_o <= "1" & colour_bg;   -- Background colour
            when '1' => palette_addr_o <= "0" & colour_fg;   -- Foreground colour
            when others => null;
         end case;
      end if;
   end process p_palette_ram;

end architecture synthesis;

