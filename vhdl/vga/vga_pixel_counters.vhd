library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module generates a pair of free-running pixel coordinates and a frame
-- counter.
--
-- To enable a 640x480 display, you must choose G_PIXEL_X_COUNT = 800,
-- G_PIXEL_Y_COUNT = 525, and G_FRAME_COUNT = 60 and supply a clock of 25.2
-- MHz.

entity vga_pixel_counters is
   generic (
      G_PIXEL_X_COUNT : integer;
      G_PIXEL_Y_COUNT : integer;
      G_FRAME_COUNT   : integer
   );
   port (
      clk_i             : in  std_logic;
      pixel_scale_x_i   : in  std_logic_vector(15 downto 0);
      pixel_scale_y_i   : in  std_logic_vector(15 downto 0);
      buffer_pixel_x_o  : out std_logic_vector(9 downto 0);
      buffer_pixel_y_o  : out std_logic_vector(9 downto 0);
      monitor_pixel_x_o : out std_logic_vector(9 downto 0);
      monitor_pixel_y_o : out std_logic_vector(9 downto 0);
      monitor_frame_o   : out std_logic_vector(5 downto 0)
   );
end vga_pixel_counters;

architecture synthesis of vga_pixel_counters is

   signal buffer_pixel_x  : std_logic_vector(17 downto 0) := std_logic_vector(to_unsigned(600*256, 18));
   signal buffer_pixel_y  : std_logic_vector(17 downto 0) := std_logic_vector(to_unsigned(524*256, 18));
   signal monitor_pixel_x : std_logic_vector(9 downto 0)  := std_logic_vector(to_unsigned(600, 10));
   signal monitor_pixel_y : std_logic_vector(9 downto 0)  := std_logic_vector(to_unsigned(524, 10));
   signal monitor_frame   : std_logic_vector(5 downto 0)  := (others => '0');

begin
   
   -------------------------------------
   -- Generate horizontal pixel counter
   -------------------------------------

   p_pixel_x : process (clk_i)
      variable sum : std_logic_vector(17 downto 0);
   begin
      if rising_edge(clk_i) then
         if unsigned(monitor_pixel_x) = G_PIXEL_X_COUNT-1 then
            monitor_pixel_x <= (others => '0');
            buffer_pixel_x  <= (others => '0');
         else
            monitor_pixel_x <= std_logic_vector(unsigned(monitor_pixel_x) + 1);

            sum := std_logic_vector(unsigned(buffer_pixel_x) + unsigned("00" & pixel_scale_x_i));
            if sum > buffer_pixel_x then
               buffer_pixel_x <= sum;
            end if;
         end if;
      end if;
   end process p_pixel_x;


   -----------------------------------
   -- Generate vertical pixel counter
   -----------------------------------

   p_pixel_y : process (clk_i)
      variable sum : std_logic_vector(17 downto 0);
   begin
      if rising_edge(clk_i) then
         if unsigned(monitor_pixel_x) = G_PIXEL_X_COUNT-1 then
            if unsigned(monitor_pixel_y) = G_PIXEL_Y_COUNT-1 then
               monitor_pixel_y <= (others => '0');
               buffer_pixel_y  <= (others => '0');
            else
               monitor_pixel_y <= std_logic_vector(unsigned(monitor_pixel_y) + 1);

               sum := std_logic_vector(unsigned(buffer_pixel_y) + unsigned("00" & pixel_scale_y_i));
               if sum > buffer_pixel_y then
                  buffer_pixel_y <= sum;
               end if;
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
         if unsigned(monitor_pixel_x) = G_PIXEL_X_COUNT-1 then
            if unsigned(monitor_pixel_y) = G_PIXEL_Y_COUNT-1 then
               if unsigned(monitor_frame) = G_FRAME_COUNT-1 then
                  monitor_frame <= (others => '0');
               else
                  monitor_frame <= std_logic_vector(unsigned(monitor_frame) + 1);
               end if;
            end if;
         end if;
      end if;
   end process p_frame;


   ------------------------
   -- Drive output signals
   ------------------------

   buffer_pixel_x_o  <= buffer_pixel_x(17 downto 8);
   buffer_pixel_y_o  <= buffer_pixel_y(17 downto 8);
   monitor_pixel_x_o <= monitor_pixel_x;
   monitor_pixel_y_o <= monitor_pixel_y;
   monitor_frame_o   <= monitor_frame;

end architecture synthesis;

