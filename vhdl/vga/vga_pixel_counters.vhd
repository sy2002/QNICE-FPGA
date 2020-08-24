library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module generates a pair of free-running pixel coordinates.
-- To enable a 640x480 display, you must
-- choose G_PIXEL_X_COUNT = 800 amd G_PIXEL_Y_COUNT = 525
-- and supply a clock of 25.175 MHz.

entity vga_pixel_counters is
   generic (
      G_PIXEL_X_COUNT : integer;
      G_PIXEL_Y_COUNT : integer;
      G_FRAME_COUNT   : integer
   );
   port (
      clk_i     : in  std_logic;
      pixel_x_o : out std_logic_vector(9 downto 0);
      pixel_y_o : out std_logic_vector(9 downto 0);
      frame_o   : out std_logic_vector(5 downto 0)
   );
end vga_pixel_counters;

architecture synthesis of vga_pixel_counters is

   signal pixel_x : std_logic_vector(9 downto 0) := (others => '0');
   signal pixel_y : std_logic_vector(9 downto 0) := (others => '0');
   signal frame   : std_logic_vector(5 downto 0) := (others => '0');

begin
   
   -------------------------------------
   -- Generate horizontal pixel counter
   -------------------------------------

   p_pixel_x : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if unsigned(pixel_x) = G_PIXEL_X_COUNT-1 then
            pixel_x <= (others => '0');
         else
            pixel_x <= std_logic_vector(unsigned(pixel_x) + 1);
         end if;
      end if;
   end process p_pixel_x;


   -----------------------------------
   -- Generate vertical pixel counter
   -----------------------------------

   p_pixel_y : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if unsigned(pixel_x) = G_PIXEL_X_COUNT-1 then
            if unsigned(pixel_y) = G_PIXEL_Y_COUNT-1 then
               pixel_y <= (others => '0');
            else
               pixel_y <= std_logic_vector(unsigned(pixel_y) + 1);
            end if;
         end if;
      end if;
   end process p_pixel_y;


   -----------------------------------
   -- Generate frame counter
   -----------------------------------

   p_frame : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if unsigned(pixel_x) = G_PIXEL_X_COUNT-1 then
            if unsigned(pixel_y) = G_PIXEL_Y_COUNT-1 then
               if unsigned(frame) = G_FRAME_COUNT-1 then
                  frame <= (others => '0');
               else
                  frame <= std_logic_vector(unsigned(frame) + 1);
               end if;
            end if;
         end if;
      end if;
   end process p_frame;


   ------------------------
   -- Drive output signals
   ------------------------

   pixel_x_o <= pixel_x;
   pixel_y_o <= pixel_y;
   frame_o   <= frame;

end architecture synthesis;

