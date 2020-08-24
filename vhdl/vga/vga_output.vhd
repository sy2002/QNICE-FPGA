library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_output is
   port (
      clk_i            : in  std_logic;

      -- Interface to Register Map
      display_offset_i : in std_logic_vector(15 downto 0);
      tile_offset_i    : in std_logic_vector(15 downto 0);

      -- Interface to Video RAM
      display_addr_o   : out std_logic_vector(15 downto 0);
      display_data_i   : in  std_logic_vector(15 downto 0);
      font_addr_o      : out std_logic_vector(9 downto 0);
      font_data_i      : in  std_logic_vector(15 downto 0);
      palette_addr_o   : out std_logic_vector(4 downto 0);
      palette_data_i   : in  std_logic_vector(15 downto 0);

      hsync_o          : out std_logic;
      vsync_o          : out std_logic;
      colour_o         : out std_logic_vector(11 downto 0);
      data_en_o        : out std_logic
   );
end vga_output;

architecture synthesis of vga_output is

   signal pixel_x : std_logic_vector(9 downto 0);  -- 0 to 799
   signal pixel_y : std_logic_vector(9 downto 0);  -- 0 to 524
   signal colour  : std_logic_vector(11 downto 0);
   signal delay   : std_logic_vector(9 downto 0);

begin

   ------------------------------
   -- Instantiate pixel counters
   ------------------------------

   i_vga_pixel_counters : entity work.vga_pixel_counters
      generic map (
         G_PIXEL_X_COUNT => 800,
         G_PIXEL_Y_COUNT => 525
      )
      port map (
         clk_i     => clk_i,
         pixel_x_o => pixel_x,
         pixel_y_o => pixel_y
      ); -- i_vga_pixel_counters


   -------------------------
   -- Instantiate Text Mode
   -------------------------

   i_vga_text_mode : entity work.vga_text_mode
      port map (
         clk_i       => clk_i,
         -- Interface to Register Map
         display_offset_i => display_offset_i,
         tile_offset_i    => tile_offset_i,
         -- Pixel Counters
         pixel_x_i        => pixel_x,
         pixel_y_i        => pixel_y,
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
         clk_i     => clk_i,
         pixel_x_i => pixel_x,
         pixel_y_i => pixel_y,
         colour_i  => colour,
         delay_i   => delay,
         hsync_o   => hsync_o,    
         vsync_o   => vsync_o,   
         colour_o  => colour_o, 
         data_en_o => data_en_o
      ); -- i_vga_sync

end architecture synthesis;

