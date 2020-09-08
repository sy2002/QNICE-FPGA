library ieee;
use ieee.std_logic_1164.all;

-- This block connects the CPU clock domain with the VGA clock domain.
-- Inside this block are three True Dual Port memories: Display RAM,
-- Font RAM, and Palette RAM.

entity vga_video_ram is
   port (
      cpu_clk_i             : in  std_logic;
      cpu_display_addr_i    : in  std_logic_vector(15 downto 0);
      cpu_display_wr_en_i   : in  std_logic;
      cpu_display_rd_data_o : out std_logic_vector(15 downto 0);
      cpu_font_addr_i       : in  std_logic_vector(12 downto 0);
      cpu_font_wr_en_i      : in  std_logic;
      cpu_font_rd_data_o    : out std_logic_vector(7 downto 0);
      cpu_palette_addr_i    : in  std_logic_vector(5 downto 0);
      cpu_palette_wr_en_i   : in  std_logic;
      cpu_palette_rd_data_o : out std_logic_vector(14 downto 0);
      cpu_wr_data_i         : in  std_logic_vector(15 downto 0);

      vga_clk_i          : in  std_logic;
      vga_display_addr_i : in  std_logic_vector(15 downto 0);
      vga_display_data_o : out std_logic_vector(15 downto 0);
      vga_font_addr_i    : in  std_logic_vector(12 downto 0);
      vga_font_data_o    : out std_logic_vector(7 downto 0);
      vga_palette_addr_i : in  std_logic_vector(5 downto 0);
      vga_palette_data_o : out std_logic_vector(14 downto 0)
   );
end vga_video_ram;

architecture synthesis of vga_video_ram is

begin

   -- The Display RAM contains 64 kW, i.e. addresses 0x0000 - 0xFFFF.
   -- 0x0000 - 0xFFFF : Display (64000 words gives 20 screens).
   --
   -- The Display RAM is organized as 800 lines of 80 characters. Each word
   -- is interpreted as follows:
   -- Bits 15-12 : Background color selected from a palette of 16 colors.
   -- Bits 11- 8 : Foreground color selected from a palette of 16 olours.
   -- Bits  7- 0 : Character index (index into Font).
   i_display_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 16,
         G_DATA_SIZE => 16
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_addr_i    => cpu_display_addr_i,
         a_wr_en_i   => cpu_display_wr_en_i,
         a_wr_data_i => cpu_wr_data_i,
         a_rd_data_o => cpu_display_rd_data_o,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_display_addr_i,
         b_rd_data_o => vga_display_data_o
      ); -- i_display_ram


   -- The Font RAM contains 3kB, i.e. addresses 0x0000 - 0x03FF.
   -- 12 bytes for each of the 256 different characters.
   i_font_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 13,
         G_DATA_SIZE => 8,
         G_FILE_NAME => "lat9w-12_sy2002.rom"
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_addr_i    => cpu_font_addr_i,
         a_wr_en_i   => cpu_font_wr_en_i,
         a_wr_data_i => cpu_wr_data_i(7 downto 0),
         a_rd_data_o => cpu_font_rd_data_o,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_font_addr_i,
         b_rd_data_o => vga_font_data_o
      ); -- i_font_ram


   -- The Palette RAM contains 64 words, i.e. addresses 0x0000 - 0x003F.
   -- 16 words for each of the foreground colors, and another 16 words
   -- for the background colors.
   i_palette_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => 6,
         G_DATA_SIZE => 15,
         G_FILE_NAME => "palette.rom"
      )
      port map (
         a_clk_i     => cpu_clk_i,
         a_addr_i    => cpu_palette_addr_i,
         a_wr_en_i   => cpu_palette_wr_en_i,
         a_wr_data_i => cpu_wr_data_i(14 downto 0),
         a_rd_data_o => cpu_palette_rd_data_o,
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_palette_addr_i,
         b_rd_data_o => vga_palette_data_o
      ); -- i_palette_ram

end architecture synthesis;

