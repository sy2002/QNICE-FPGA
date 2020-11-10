library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity tb_vga_sprite is
end tb_vga_sprite;

architecture simulation of tb_vga_sprite is

   constant C_INDEX_SIZE : integer := 3;

   signal clk            : std_logic := '0';

   signal sprite_enable  : std_logic;
   signal pixel_x        : std_logic_vector(9 downto 0);
   signal pixel_y        : std_logic_vector(9 downto 0);
   signal config_addr    : std_logic_vector(C_INDEX_SIZE-1 downto 0);
   signal config_data    : std_logic_vector(63 downto 0);      -- 4 words
   signal palette_addr   : std_logic_vector(C_INDEX_SIZE-1 downto 0);
   signal palette_data   : std_logic_vector(255 downto 0);     -- 16 words
   signal bitmap_addr    : std_logic_vector(C_INDEX_SIZE+3 downto 0);
   signal bitmap_data    : std_logic_vector(255 downto 0);     -- 16 words
   signal color          : std_logic_vector(15 downto 0);
   signal delay          : std_logic_vector(9 downto 0);
   signal color_blanked  : std_logic_vector(15 downto 0);

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
         clk_i             => clk,
         pixel_scale_x_i   => X"0100",
         pixel_scale_y_i   => X"0100",
         buffer_pixel_x_o  => pixel_x,
         buffer_pixel_y_o  => pixel_y,
         monitor_pixel_x_o => pixel_x,
         monitor_pixel_y_o => pixel_y,
         monitor_frame_o   => open
      ); -- i_vga_pixel_counters


   ------------------------------
   -- Fake Config RAM
   ------------------------------

   p_config_data : process (clk)
   begin
      if rising_edge(clk) then
         case config_addr is          -- config    bitmap    pos_y     pos_x
            when "000" => config_data <= X"0040" & X"0020" & X"0000" & X"0004";
            when "001" => config_data <= X"0040" & X"0040" & X"0000" & X"0002";
            when others => config_data <= (others => '0');
         end case;
      end if;
   end process p_config_data;


   ------------------------------
   -- Fake Palette RAM
   ------------------------------

   p_palette_data : process (clk)
   begin
      if rising_edge(clk) then
         case palette_addr is
            -- Both sprites use same palette.
            when "000" => palette_data <= X"0FFF0EEE0DDD0CCC0BBB0AAA09990888" &
                                          X"07770666055504440333022201118000";
            when "001" => palette_data <= X"0FFF0EEE0DDD0CCC0BBB0AAA09990888" &
                                          X"07770666055504440333022201118000";
            when others => palette_data <= (others => '0');
         end case;
      end if;
   end process p_palette_data;


   ------------------------------
   -- Fake Bitmap RAM
   ------------------------------

   p_bitmap_data : process (clk)
   begin
      if rising_edge(clk) then
         case conv_integer(bitmap_addr) is
            when 0 => bitmap_data <= X"0000" & X"0000" & X"0000" & X"0000" &
                                     X"0000" & X"0000" & X"0000" & X"0000" &
                                     X"FEDC" & X"3210" & X"7654" & X"BA98" &
                                     X"FEDC" & X"3210" & X"7654" & X"BA98";
            when 1 => bitmap_data <= X"3210" & X"7654" & X"BA98" & X"FEDC" &
                                     X"3210" & X"7654" & X"BA98" & X"FEDC" &
                                     X"0000" & X"0000" & X"0000" & X"0000" &
                                     X"0000" & X"0000" & X"0000" & X"0000";
            when others => bitmap_data <= (others => '0');
         end case;
      end if;
   end process p_bitmap_data;


   ------------------------------
   -- Instantiate DUT
   ------------------------------

   i_vga_sprite : entity work.vga_sprite
      generic map (
         G_INDEX_SIZE    => C_INDEX_SIZE
      )
      port map (
         clk_i           => clk,
         sprite_enable_i => '1',
         pixel_x_i       => pixel_x,
         pixel_y_i       => pixel_y,
         color_i         => X"1234",   -- background color
         config_addr_o   => config_addr,
         config_data_i   => config_data,
         palette_addr_o  => palette_addr,
         palette_data_i  => palette_data,
         bitmap_addr_o   => bitmap_addr,
         bitmap_data_i   => bitmap_data,
         color_o         => color,
         delay_o         => delay
      ); -- i_vga_sprite

   color_blanked <= color when conv_integer(pixel_x) >= conv_integer(delay) and
                               conv_integer(pixel_x) < conv_integer(delay) + 640 and
                               conv_integer(pixel_y) < 480 else 
                    (others => '0');

end architecture simulation;

