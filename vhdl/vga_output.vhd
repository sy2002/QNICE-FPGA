library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_output is
   port (
      clk_i       : in  std_logic;

      scroll_en_i : in  std_logic;
      offset_en_i : in  std_logic;
      busy_o      : out std_logic;
      clrscr_i    : in  std_logic;
      vga_en_i    : in  std_logic;
      curs_en_i   : in  std_logic;
      blink_en_i  : in  std_logic;
      curs_mode_i : in  std_logic;

      vram_addr_o : out std_logic_vector(14 downto 0);
      vram_data_i : in  std_logic_vector(15 downto 0);

      hsync_o     : out std_logic;
      vsync_o     : out std_logic;
      colour_o    : out std_logic_vector(11 downto 0);
      data_en_o   : out std_logic
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
         scroll_en_i => scroll_en_i,
         offset_en_i => offset_en_i,
         busy_o      => busy_o,
         clrscr_i    => clrscr_i,
         vga_en_i    => vga_en_i,
         curs_en_i   => curs_en_i,
         blink_en_i  => blink_en_i,
         curs_mode_i => curs_mode_i,
         -- Pixel Counters
         pixel_x_i   => pixel_x,
         pixel_y_i   => pixel_y,
         -- Interface to Video RAM
         vram_addr_o => vram_addr_o,
         vram_data_i => vram_data_i,
         -- Current pixel colour
         colour_o    => colour,
         delay_o     => delay
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

