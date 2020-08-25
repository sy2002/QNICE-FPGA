library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_vga_text_mode is
end tb_vga_text_mode;

architecture simulation of tb_vga_text_mode is

   signal clk            : std_logic := '0';
   signal display_offset : std_logic_vector(15 downto 0) := (others => '0');
   signal tile_offset    : std_logic_vector(15 downto 0) := (others => '0');
   signal cursor_enable  : std_logic := '0';
   signal cursor_blink   : std_logic := '0';
   signal cursor_size    : std_logic := '0';
   signal cursor_x       : std_logic_vector(6 downto 0) := (others => '0');
   signal cursor_y       : std_logic_vector(5 downto 0) := (others => '0');

   signal pixel_x        : std_logic_vector(9 downto 0);
   signal pixel_y        : std_logic_vector(9 downto 0);
   signal frame          : std_logic_vector(5 downto 0);
   signal display_addr   : std_logic_vector(15 downto 0);
   signal display_data   : std_logic_vector(15 downto 0);
   signal font_addr      : std_logic_vector(11 downto 0);
   signal font_data      : std_logic_vector(7 downto 0);
   signal palette_addr   : std_logic_vector(4 downto 0);
   signal palette_data   : std_logic_vector(11 downto 0);
   signal colour         : std_logic_vector(11 downto 0);
   signal delay          : std_logic_vector(9 downto 0);

begin

   ------------------------------
   -- Generate clock (100 MHz)
   -- In simulation the actual clock speed is irrelevant.
   ------------------------------

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
   end process p_clk;


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
         clk_i     => clk,
         pixel_x_o => pixel_x,
         pixel_y_o => pixel_y,
         frame_o   => frame
      ); -- i_vga_pixel_counters


   ------------------------------
   -- Fake Display RAM
   ------------------------------

   p_display_data : process (clk)
   begin
      if rising_edge(clk) then
         case display_addr(0) is
            when '0' => display_data <= X"1234";
            when '1' => display_data <= X"4321";
            when others => display_data <= X"0000";
         end case;
      end if;
   end process p_display_data;


   ------------------------------
   -- Fake Font RAM
   ------------------------------

   p_font_data : process (clk)
   begin
      if rising_edge(clk) then
         case font_addr(2) is
            when '0' => font_data <= X"45";
            when '1' => font_data <= X"32";
            when others => font_data <= X"00";
         end case;
      end if;
   end process p_font_data;


   ------------------------------
   -- Fake Palette RAM
   ------------------------------

   p_palette_data : process (clk)
   begin
      if rising_edge(clk) then
         case palette_addr(0) is
            when '0' => palette_data <= X"123";
            when '1' => palette_data <= X"321";
            when others => palette_data <= X"000";
         end case;
      end if;
   end process p_palette_data;


   ------------------------------
   -- Instantiate DUT
   ------------------------------

   i_vga_text_mode : entity work.vga_text_mode
   port map (
      clk_i            => clk,
      display_offset_i => display_offset,
      tile_offset_i    => tile_offset,
      cursor_enable_i  => cursor_enable,
      cursor_blink_i   => cursor_blink,
      cursor_size_i    => cursor_size,
      cursor_x_i       => cursor_x,
      cursor_y_i       => cursor_y,
      pixel_x_i        => pixel_x,
      pixel_y_i        => pixel_y,
      frame_i          => frame,
      display_addr_o   => display_addr,
      display_data_i   => display_data,
      font_addr_o      => font_addr,
      font_data_i      => font_data,
      palette_addr_o   => palette_addr,
      palette_data_i   => palette_data,
      colour_o         => colour,
      delay_o          => delay
   ); -- i_vga_text_mode;


end architecture simulation;

