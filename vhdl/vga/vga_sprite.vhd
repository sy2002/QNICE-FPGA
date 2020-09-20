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
      config_addr_o   : out std_logic_vector(G_INDEX_SIZE-1 downto 0);
      config_data_i   : in  std_logic_vector(63 downto 0);    -- 4 words
      -- Interface to Sprite Palette RAM
      palette_addr_o  : out std_logic_vector(G_INDEX_SIZE-1 downto 0);
      palette_data_i  : in  std_logic_vector(255 downto 0);   -- 16 words
      -- Interface to Sprite Bitmap RAM
      bitmap_addr_o   : out std_logic_vector(G_INDEX_SIZE+4 downto 0);
      bitmap_data_i   : in  std_logic_vector(127 downto 0);   -- 8 words
      -- Current pixel color
      color_o         : out std_logic_vector(15 downto 0);
      delay_o         : out std_logic_vector(9 downto 0)
   );
end vga_sprite;

architecture synthesis of vga_sprite is

   type t_stage0 is record
      pixel_x_offset : std_logic_vector(9 downto 0);
   end record t_stage0;

   type t_stage1 is record
      pos_x      : std_logic_vector(9 downto 0);
      pos_y      : std_logic_vector(9 downto 0);
      bitmap_ptr : std_logic_vector(15 downto 0);
      config     : std_logic_vector(6 downto 0);
      palette    : std_logic_vector(255 downto 0);
      addr_temp  : std_logic_vector(11 downto 0);
   end record t_stage1;

   type t_stage2 is record
      pos_x      : std_logic_vector(9 downto 0);
      palette    : std_logic_vector(255 downto 0);
      bitmap     : std_logic_vector(127 downto 0);
      pixels     : std_logic_vector(511 downto 0);
   end record t_stage2;

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

   signal scanline_wr_addr : std_logic_vector(9 downto 0);
   signal scanline_wr_data : std_logic_vector(511 downto 0);
   signal scanline_wr_en   : std_logic;
   signal scanline_rd_addr : std_logic_vector(9 downto 0);
   signal scanline_rd_data : std_logic_vector(15 downto 0);

--   attribute mark_debug                     : boolean;
--   attribute mark_debug of pixel_x_i        : signal is true;
--   attribute mark_debug of pixel_y_i        : signal is true;
--   attribute mark_debug of color_i          : signal is true;
--   attribute mark_debug of config_addr_o    : signal is true;
--   attribute mark_debug of config_data_i    : signal is true;
--   attribute mark_debug of palette_addr_o   : signal is true;
--   attribute mark_debug of palette_data_i   : signal is true;
--   attribute mark_debug of bitmap_addr_o    : signal is true;
--   attribute mark_debug of bitmap_data_i    : signal is true;
--   attribute mark_debug of color_o          : signal is true;
--   attribute mark_debug of scanline_wr_addr : signal is true;
--   attribute mark_debug of scanline_wr_data : signal is true;
--   attribute mark_debug of scanline_wr_en   : signal is true;
--   attribute mark_debug of scanline_rd_addr : signal is true;
--   attribute mark_debug of scanline_rd_data : signal is true;

begin

   -- For now assume sprites are 32x32x4 bits.

   -- Pipelined approach (one clock cycle per sprite):
   stage0.pixel_x_offset <= pixel_x_i - std_logic_vector(to_unsigned(640, 10));

   -- Stage 0 : Read configuration (4 words) and palette (16 words)
   config_addr_o     <= stage0.pixel_x_offset(G_INDEX_SIZE-1 downto 0);
   palette_addr_o    <= stage0.pixel_x_offset(G_INDEX_SIZE-1 downto 0);


   -- Stage 1 : Store configuration and palette
   stage1.pos_x      <= config_data_i(9     downto 0);
   stage1.pos_y      <= config_data_i(16+9  downto 16);
   stage1.bitmap_ptr <= config_data_i(32+15 downto 32);
   stage1.config     <= config_data_i(48+6  downto 48);
   stage1.palette    <= palette_data_i;

   -- Stage 1 : Read sprite bitmap
   stage1.addr_temp  <= (pixel_y_i - stage1.pos_y) & "00" + stage1.bitmap_ptr(11 downto 0);
   bitmap_addr_o     <= stage1.addr_temp(G_INDEX_SIZE+4 downto 0);


   -- Stage 2 : Copy palette from Stage 1
   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2.palette <= stage1.palette;
         stage2.pos_x   <= stage1.pos_x;
      end if;
   end process p_stage2;

   -- Stage 2 : Store bitmap
   stage2.bitmap <= bitmap_data_i;

   -- Stage 2 : Palette lookup
   gen_palette_lookup:
   for i in 0 to 31 generate  -- Loop over each pixel
      process (stage2.bitmap, stage2.palette)
         variable color_index : integer range 0 to 15;
      begin
         color_index := conv_integer(stage2.bitmap(3+4*i downto 4*i));
         stage2.pixels(15+16*i downto 16*i) <=
            palette_data_i(15+16*color_index downto 16*color_index);
      end process;
   end generate gen_palette_lookup;

   -- Stage 2 : Write to scanline
   scanline_wr_addr <= stage2.pos_x;
   scanline_wr_en   <= '1' when conv_integer(pixel_x_i) >= 640 else '0';
   scanline_wr_data <= stage2.pixels;


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
   scanline_rd_addr <= pixel_x_i;
   color_o <= scanline_rd_data;

end architecture synthesis;

