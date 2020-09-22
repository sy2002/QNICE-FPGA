library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_sprite is
   generic (
      G_INDEX_SIZE    : integer
   );
   port (
      clk_i           : in  std_logic;

      -- Interface to Register Map
      sprite_enable_i : in  std_logic;
      -- Pixel Counters
      pixel_x_i       : in  std_logic_vector(9 downto 0);
      pixel_y_i       : in  std_logic_vector(9 downto 0);
      color_i         : in  std_logic_vector(15 downto 0);
      -- Interface to Sprite Config RAM
      config_addr_o   : out std_logic_vector(G_INDEX_SIZE-1 downto 0);  -- 1 entry per sprite
      config_data_i   : in  std_logic_vector(63 downto 0);              -- 4 words
      -- Interface to Sprite Palette RAM
      palette_addr_o  : out std_logic_vector(G_INDEX_SIZE-1 downto 0);  -- 1 entry per sprite
      palette_data_i  : in  std_logic_vector(255 downto 0);             -- 16 words
      -- Interface to Sprite Bitmap RAM
      bitmap_addr_o   : out std_logic_vector(G_INDEX_SIZE+4 downto 0);  -- 32 entries per sprite
      bitmap_data_i   : in  std_logic_vector(127 downto 0);             -- 8 words
      -- Current pixel color
      color_o         : out std_logic_vector(15 downto 0);
      delay_o         : out std_logic_vector(9 downto 0)
   );
end vga_sprite;

architecture synthesis of vga_sprite is

   constant C_START_CLEAR  : integer := 640;
   constant C_START_RENDER : integer := 640 + 640/32;

   type t_stage0 is record
      color       : std_logic_vector(15 downto 0);
      pixel_x     : std_logic_vector(9 downto 0);
      num_temp    : std_logic_vector(9 downto 0);
      sprite_num  : std_logic_vector(G_INDEX_SIZE-1 downto 0);
   end record t_stage0;

   type t_stage1 is record
      color       : std_logic_vector(15 downto 0);
      pixel_x     : std_logic_vector(9 downto 0);
      sprite_num  : std_logic_vector(G_INDEX_SIZE-1 downto 0);
      pos_x       : std_logic_vector(9 downto 0);
      pos_y       : std_logic_vector(9 downto 0);
      bitmap_ptr  : std_logic_vector(15 downto 0);
      config      : std_logic_vector(6 downto 0);
      palette     : std_logic_vector(255 downto 0);
      addr_temp   : std_logic_vector(9 downto 0);
      next_y      : std_logic_vector(9 downto 0);
   end record t_stage1;

   type t_stage2 is record
      color       : std_logic_vector(15 downto 0);
      pixel_x     : std_logic_vector(9 downto 0);
      pos_x       : std_logic_vector(9 downto 0);
      pos_y       : std_logic_vector(9 downto 0);
      config      : std_logic_vector(6 downto 0);
      palette     : std_logic_vector(255 downto 0);
      bitmap      : std_logic_vector(127 downto 0);
      pixels      : std_logic_vector(511 downto 0);
      next_y      : std_logic_vector(9 downto 0);
   end record t_stage2;

   type t_stage3 is record
      color       : std_logic_vector(15 downto 0);
   end record t_stage3;

   -- Decoding of the Config register
   constant C_CONFIG_RES_LOW    : integer := 0;
   constant C_CONFIG_BACKGROUND : integer := 1;
   constant C_CONFIG_MAG_X      : integer := 2;
   constant C_CONFIG_MAG_Y      : integer := 3;
   constant C_CONFIG_MIRROR_X   : integer := 4;
   constant C_CONFIG_MIRROR_Y   : integer := 5;
   constant C_CONFIG_VISIBLE    : integer := 6;

   signal stage0 : t_stage0;
   signal stage1 : t_stage1;
   signal stage2 : t_stage2;
   signal stage3 : t_stage3;

   signal scanline_wr_addr : std_logic_vector(9 downto 0);
   signal scanline_wr_data : std_logic_vector(511 downto 0);
   signal scanline_wr_en   : std_logic;
   signal scanline_rd_addr : std_logic_vector(9 downto 0);
   signal scanline_rd_data : std_logic_vector(15 downto 0);

--   attribute mark_debug                     : boolean;
--   attribute mark_debug of sprite_enable_i  : signal is true;
--   attribute mark_debug of pixel_x_i        : signal is true;
--   attribute mark_debug of pixel_y_i        : signal is true;
--   attribute mark_debug of color_i          : signal is true;
--   attribute mark_debug of config_addr_o    : signal is true;
--   attribute mark_debug of config_data_i    : signal is true;
--   attribute mark_debug of palette_addr_o   : signal is true;
--   attribute mark_debug of palette_data_i   : signal is true;
--   attribute mark_debug of bitmap_addr_o    : signal is true;
--   attribute mark_debug of bitmap_data_i    : signal is true;
--   attribute mark_debug of scanline_wr_addr : signal is true;
--   attribute mark_debug of scanline_wr_data : signal is true;
--   attribute mark_debug of scanline_wr_en   : signal is true;
--   attribute mark_debug of scanline_rd_addr : signal is true;
--   attribute mark_debug of scanline_rd_data : signal is true;

begin

   -- For now assume sprites are 32x32x4 bits.

   -- Pipelined approach (one clock cycle per sprite).

   -- Stage 0 : Determine which sprite to process
   stage0.color      <= color_i;
   stage0.pixel_x    <= pixel_x_i;
   stage0.num_temp   <= stage0.pixel_x - std_logic_vector(to_unsigned(C_START_RENDER, 10));
   stage0.sprite_num <= not stage0.num_temp(G_INDEX_SIZE-1 downto 0);   -- Invert to start from sprite number 127

   -- Stage 0 : Read configuration (4 words) and palette (16 words)
   config_addr_o     <= stage0.sprite_num;
   palette_addr_o    <= stage0.sprite_num;


   -- Stage 1 : Copy palette from Stage 0
   p_stage1 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage1.color      <= stage0.color;
         stage1.pixel_x    <= stage0.pixel_x;
         stage1.sprite_num <= stage0.sprite_num;
      end if;
   end process p_stage1;

   -- Stage 1 : Store configuration and palette
   stage1.pos_x      <= config_data_i(9     downto 0);
   stage1.pos_y      <= config_data_i(16+9  downto 16);
   stage1.bitmap_ptr <= config_data_i(32+15 downto 32);
   stage1.config     <= config_data_i(48+6  downto 48);
   stage1.palette    <= palette_data_i;

   -- Stage 1 : Calculate value of next scan line
   stage1.next_y     <= pixel_y_i + 1 when pixel_y_i /= 524 else (others => '0');

   -- Stage 1 : Read sprite bitmap
   stage1.addr_temp  <= stage1.next_y - stage1.pos_y;
   bitmap_addr_o     <= stage1.bitmap_ptr(G_INDEX_SIZE+7 downto 3) +
                        std_logic_vector(to_unsigned(conv_integer(stage1.addr_temp(4 downto 0)), G_INDEX_SIZE+5));


   -- Stage 2 : Copy palette from Stage 1
   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2.color   <= stage1.color;
         stage2.pixel_x <= stage1.pixel_x;
         stage2.palette <= stage1.palette;
         stage2.pos_x   <= stage1.pos_x;
         stage2.pos_y   <= stage1.pos_y;
         stage2.next_y  <= stage1.next_y;
         stage2.config  <= stage1.config;
      end if;
   end process p_stage2;

   -- Stage 2 : Store bitmap
   stage2.bitmap <= bitmap_data_i;

   -- Stage 2 : Palette lookup
   gen_palette_lookup:
   for i in 0 to 31 generate  -- Loop over each pixel
      process (stage2)
         variable color_index : integer range 0 to 15;
         variable j           : integer range 0 to 31;

         function swap(arg : integer) return integer is
            variable j : integer;
            variable k : integer;
         begin
            j := arg/4;
            k := arg mod 4;
            return j*4 + 3-k;
         end function swap;

      begin
         j := swap(i);
         color_index := conv_integer(stage2.bitmap(127-4*j downto 124-4*j));
         stage2.pixels(15+16*i downto 16*i) <=
            stage2.palette(15+16*color_index downto 16*color_index);
      end process;
   end generate gen_palette_lookup;

   -- Stage 2 : Write to scanline
   p_scanline_wr : process (stage2, sprite_enable_i)
   begin
      -- Default is to do nothing!
      scanline_wr_en   <= '0';
      scanline_wr_addr <= (others => '0');
      scanline_wr_data <= (others => '0');

      -- During porch, we first clear the scanline, 32 pixels at a time.
      if conv_integer(stage2.pixel_x) >= C_START_CLEAR and
         conv_integer(stage2.pixel_x) < C_START_RENDER then
         scanline_wr_addr <= stage2.pixel_x(4 downto 0) & "00000";
         scanline_wr_en   <= '1';
         scanline_wr_data <= (others => '0');
         for i in 0 to 31 loop
            scanline_wr_data(15+16*i) <= '1';   -- set transparent bit in all pixels
         end loop;
      end if;

      -- During porch, we render the sprites
      if conv_integer(stage2.pixel_x) >= C_START_RENDER and
         conv_integer(stage2.pixel_x) < C_START_RENDER + 2**G_INDEX_SIZE and
         conv_integer(stage2.next_y) >= conv_integer(stage2.pos_y) and
         conv_integer(stage2.next_y) < conv_integer(stage2.pos_y)+32 and
         stage2.config(C_CONFIG_VISIBLE) = '1' and
         sprite_enable_i = '1' then

         scanline_wr_addr <= stage2.pos_x;
         scanline_wr_en   <= '1';
         scanline_wr_data <= stage2.pixels;
      end if;
   end process p_scanline_wr;


   -- This contains the colors of all pixels in the current scanline.
   -- It is written to during the horizontal porch of the previous scanline.
   i_vga_scanline : entity work.vga_scanline
      port map (
         clk_i     => clk_i,
         wr_addr_i => scanline_wr_addr,
         wr_data_i => scanline_wr_data,
         wr_en_i   => scanline_wr_en,
         rd_addr_i => scanline_rd_addr,
         rd_data_o => scanline_rd_data
      ); -- i_vga_scanline

   -- Output scanline
   scanline_rd_addr <= stage2.pixel_x;

   -- Stage 3 : Copy color from Stage 2
   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3.color   <= stage2.color;
      end if;
   end process p_stage3;

   color_o <= stage3.color when scanline_rd_data(15) = '1' else  -- transparent
              scanline_rd_data;                                  -- visible
   delay_o <= std_logic_vector(to_unsigned(3, 10));

end architecture synthesis;

