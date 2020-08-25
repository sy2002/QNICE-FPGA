library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

entity vga_video_ram is
   port (
      cpu_clk_i          : in  std_logic;
      cpu_wr_addr_i      : in  std_logic_vector(17 downto 0);
      cpu_wr_en_i        : in  std_logic;
      cpu_wr_data_i      : in  std_logic_vector(15 downto 0);
      cpu_rd_addr_i      : in  std_logic_vector(17 downto 0);
      cpu_rd_data_o      : out std_logic_vector(15 downto 0);

      vga_clk_i          : in  std_logic;
      vga_display_addr_i : in  std_logic_vector(15 downto 0);
      vga_display_data_o : out std_logic_vector(15 downto 0);
      vga_font_addr_i    : in  std_logic_vector(11 downto 0);
      vga_font_data_o    : out std_logic_vector(7 downto 0);
      vga_palette_addr_i : in  std_logic_vector(4 downto 0);
      vga_palette_data_o : out std_logic_vector(11 downto 0)
   );
end vga_video_ram;

architecture synthesis of vga_video_ram is

   signal cpu_rd_data_display : std_logic_vector(15 downto 0);
   signal cpu_rd_data_font    : std_logic_vector(7 downto 0);
   signal cpu_rd_data_palette : std_logic_vector(11 downto 0);

begin

   cpu_rd_data_o <= cpu_rd_data_display or
      ("00000000" & cpu_rd_data_font)    or
          ("0000" & cpu_rd_data_palette);

-- The Display RAM contains 64 kW, i.e. addresses 0x0000 - 0xFFFF.
-- 0x0000 - 0xFFFF : Display (64000 words gives 20 screens).
--
-- The Display RAM is organized as 800 lines of 80 characters. Each word
-- is interpreted as follows:
-- Bits 15-12 : Background colour selected from a palette of 16 colours.
-- Bits 11- 8 : Foreground colour selected from a palette of 16 colours.
-- Bits  7- 0 : Character index (index into Font).
   i_display_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 16,
         G_DATA_SIZE => 16
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_wr_addr_i => cpu_wr_addr_i(15 downto 0),
         a_wr_en_i   => cpu_wr_en_i,
         a_wr_data_i => cpu_wr_data_i,
         a_rd_addr_i => cpu_rd_addr_i(15 downto 0),
         a_rd_data_o => cpu_rd_data_display,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_display_addr_i,
         b_rd_data_o => vga_display_data_o
      ); -- i_display_ram


-- The Font RAM contains 3kB, i.e. addresses 0x0000 - 0x03FF.
-- 12 bytes for each of the 256 different characters.
   i_font_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 12,
         G_DATA_SIZE => 8,
         G_FILE_NAME => "lat9w-12_sy2002.rom"
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_wr_addr_i => cpu_wr_addr_i(11 downto 0),
         a_wr_en_i   => cpu_wr_en_i,
         a_wr_data_i => cpu_wr_data_i(7 downto 0),
         a_rd_addr_i => cpu_rd_addr_i(11 downto 0),
         a_rd_data_o => cpu_rd_data_font,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_font_addr_i,
         b_rd_data_o => vga_font_data_o
      ); -- i_font_ram

-- The Palette RAM contains 32 words, i.e. addresses 0x0000 - 0x001F.
-- 16 words for each of the foreground colours, and another 16 words
-- for the background colours.
   i_palette_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 5,
         G_DATA_SIZE => 12,
         G_FILE_NAME => "palette.txt"
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_wr_addr_i => cpu_wr_addr_i(4 downto 0),
         a_wr_en_i   => cpu_wr_en_i,
         a_wr_data_i => cpu_wr_data_i(11 downto 0),
         a_rd_addr_i => cpu_rd_addr_i(4 downto 0),
         a_rd_data_o => cpu_rd_data_palette,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_palette_addr_i,
         b_rd_data_o => vga_palette_data_o
      ); -- i_palette_ram

end architecture synthesis;

