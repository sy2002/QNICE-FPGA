library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This block receives configuration signals from the `vga_register_map` block
-- as well as reads from the three parts of the Video RAM (Display RAM, Font
-- RAM, and Palette RAM). From these, this block generates the VGA output
-- signals.

entity vga_output is
   port (
      clk_i            : in  std_logic;

      -- Configuration from Register Map
      output_enable_i  : in  std_logic;
      display_offset_i : in  std_logic_vector(15 downto 0);
      font_offset_i    : in  std_logic_vector(15 downto 0);
      cursor_enable_i  : in  std_logic;
      cursor_blink_i   : in  std_logic;
      cursor_size_i    : in  std_logic;
      cursor_x_i       : in  std_logic_vector(6 downto 0); -- 0 to 79
      cursor_y_i       : in  std_logic_vector(5 downto 0); -- 0 to 39
      pixel_y_o        : out std_logic_vector(9 downto 0); -- 0 to 524
      adjust_x_i       : in  std_logic_vector(9 downto 0);
      adjust_y_i       : in  std_logic_vector(9 downto 0);

      -- Interface to Video RAM
      display_addr_o   : out std_logic_vector(15 downto 0);
      display_data_i   : in  std_logic_vector(15 downto 0);
      font_addr_o      : out std_logic_vector(12 downto 0);
      font_data_i      : in  std_logic_vector(7 downto 0);
      palette_addr_o   : out std_logic_vector(4 downto 0);
      palette_data_i   : in  std_logic_vector(14 downto 0);

      -- VGA output
      hsync_o          : out std_logic;
      vsync_o          : out std_logic;
      colour_o         : out std_logic_vector(14 downto 0);
      data_en_o        : out std_logic
   );
end vga_output;

architecture synthesis of vga_output is

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   signal pixel_x : std_logic_vector(9 downto 0);  -- 0 to 799
   signal pixel_y : std_logic_vector(9 downto 0);  -- 0 to 524
   signal frame   : std_logic_vector(5 downto 0);  -- 0 to 59
   signal colour  : std_logic_vector(14 downto 0);
   signal delay   : std_logic_vector(9 downto 0);
   signal pixel_adj_x : std_logic_vector(9 downto 0);
   signal pixel_adj_y : std_logic_vector(9 downto 0);

begin

   ------------------------------
   -- Instantiate pixel counters
   ------------------------------

   i_vga_pixel_counters : entity work.vga_pixel_counters
      generic map (
         G_PIXEL_X_COUNT => 800,
         G_PIXEL_Y_COUNT => 525,
         G_FRAME_COUNT   => 60
      )
      port map (
         clk_i     => clk_i,
         pixel_x_o => pixel_x,
         pixel_y_o => pixel_y,
         frame_o   => frame
      ); -- i_vga_pixel_counters

   pixel_adj_x <= pixel_x + adjust_x_i;
   pixel_adj_y <= pixel_y + adjust_y_i;

   -------------------------
   -- Instantiate Text Mode
   -------------------------

   i_vga_text_mode : entity work.vga_text_mode
      port map (
         clk_i            => clk_i,
         -- Configuration from Register Map
         display_offset_i => display_offset_i,
         font_offset_i    => font_offset_i,
         cursor_enable_i  => cursor_enable_i,
         cursor_blink_i   => cursor_blink_i,
         cursor_size_i    => cursor_size_i,
         cursor_x_i       => cursor_x_i,
         cursor_y_i       => cursor_y_i,
         -- Pixel Counters
         pixel_x_i        => pixel_adj_x,
         pixel_y_i        => pixel_adj_y,
         frame_i          => frame,
         -- Interface to Video RAM
         display_addr_o   => display_addr_o,
         display_data_i   => display_data_i,
         font_addr_o      => font_addr_o,
         font_data_i      => font_data_i,
         palette_addr_o   => palette_addr_o,
         palette_data_i   => palette_data_i,
         -- Current pixel colour
         colour_o         => colour,
         delay_o          => delay
      ); -- i_vga_text_mode


   -----------------------------------
   -- Instantiate VGA synchronization
   -----------------------------------

   i_vga_sync : entity work.vga_sync
      port map (
         clk_i       => clk_i,
         output_en_i => output_enable_i,
         pixel_x_i   => pixel_x,
         pixel_y_i   => pixel_y,
         colour_i    => colour,
         delay_i     => delay,
         hsync_o     => hsync_o,
         vsync_o     => vsync_o,
         colour_o    => colour_o,
         data_en_o   => data_en_o
      ); -- i_vga_sync

   pixel_y_o <= pixel_y+1 when conv_integer(pixel_x) >= H_PIXELS else
                pixel_y;

end architecture synthesis;

