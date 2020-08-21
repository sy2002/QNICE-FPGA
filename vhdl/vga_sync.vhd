library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module generates the VGA synchronization signals.

-- The module ensures that the mutual relative timing between the
-- synchronization signals and colour signal adheres to the VESA standard.

entity vga_sync is
   port (
      clk_i     : in  std_logic;

      pixel_x_i : in  std_logic_vector( 9 downto 0);
      pixel_y_i : in  std_logic_vector( 9 downto 0);
      colour_i  : in  std_logic_vector(11 downto 0);
      delay_i   : in  std_logic_vector( 9 downto 0);

      hsync_o   : out std_logic;
      vsync_o   : out std_logic;
      colour_o  : out std_logic_vector(11 downto 0);
      data_en_o : out std_logic
   );
end vga_sync;

architecture synthesis of vga_sync is

   -- The following constants define a resolution of 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

begin

   p_vga_sync : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Generate horizontal sync signal
         if pixel_x_i >= std_logic_vector(HS_START+unsigned(delay_i))
            and pixel_x_i < std_logic_vector(HS_START+HS_TIME+unsigned(delay_i)) then
            hsync_o <= '0';
         else
            hsync_o <= '1';
         end if;

         -- Generate vertical sync signal
         if unsigned(pixel_y_i) >= VS_START and unsigned(pixel_y_i) < VS_START+VS_TIME then
            vsync_o <= '0';
         else
            vsync_o <= '1';
         end if;

         -- Generate pixel colour
         colour_o  <= colour_i;
         data_en_o <= '1';

         -- Make sure colour is black outside visible screen
         if pixel_x_i >= std_logic_vector(H_PIXELS+unsigned(delay_i))
            or pixel_x_i < delay_i or unsigned(pixel_y_i) >= V_PIXELS then
            colour_o  <= (others => '0');    -- Black
            data_en_o <= '0';
         end if;
      end if;
   end process p_vga_sync;

end architecture synthesis;

