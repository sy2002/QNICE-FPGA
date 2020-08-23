library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.env1_globals.all;                -- VGA_RAM_SIZE

-- This file is the top-level VGA controller. It connects directly to the CPU
-- and to the output ports on the FPGA.
--
-- Register Map:
-- 00 : Control
-- 01 : Cursor X
-- 02 : Cursor Y
-- 03 : Character and Colour at Cursor
-- 04 : Scroll
-- 05 : Offset
-- 06 : hctr_min
-- 07 : hctr_max
-- 08 : vctr_max
--
-- Interpretation of Control Register:
-- bit  4 : R/W : Cursor Size
-- bit  5 : R/W : Cursor Blinking
-- bit  6 : R/W : Cursor Enabled
-- bit  7 : R/W : VGA output enabled
-- bit  8 : R/W : Clear screen
-- bit  9 : R/O : VGA controller busy
-- bit 10 : R/W : Offset enable
-- bit 11 : R/W : Scrolling enable
--
-- Design and Naming Conventions:
-- This design makes use of two independent clock signals: The CPU clock
-- (currently running at 50 MHz) and the VGA clock (always running at 25.175
-- MHz).
-- To avoid any timing problems, I've used a strict naming convention where
-- each signal in this file has its name prefixed with the corresponding clock
-- domain.
-- The design is split into three parts:
-- * The vga_register_map running entirely on the CPU clock domain.
-- * The vga_output running entirely on the VGA clock domain.
-- * The vga_video_ram, which is a True Dual Port RAM using block clock domains.
-- The only communication (so far) between the CPU and VGA clock domains is via
-- the Video RAM.
--
-- The Video RAM actually contains three different RAM blocks:
-- * The Display RAM
-- * The Font RAM
-- * The Palette RAM
--
-- The Display RAM contains 64 kW, i.e. addresses 0x0000 - 0xFFFF.
-- 0x0000 - 0xFFFF : Display (64000 words gives 20 screens).
--
-- The Display RAM is organized as 800 lines of 80 characters. Each word
-- is interpreted as follows:
-- Bits 15-12 : Background colour selected from a palette of 16 colours.
-- Bits 11- 8 : Foreground colour selected from a palette of 16 colours.
-- Bits  7- 0 : Character index (index into Font).
--
-- The Font RAM contains 3kB, i.e. addresses 0x0000 - 0x03FF.
-- 12 bytes for each of the 256 different characters.
--
-- The Palette RAM contains 32 words, i.e. addresses 0x0000 - 0x001F.
-- 16 words for each of the foreground colours, and another 16 words
-- for the background colours.

entity vga_multicolour is
   port (
      cpu_clk_i    : in  std_logic;          -- CPU clock (currently at 50 MHz)
      cpu_rst_i    : in  std_logic;
      cpu_en_i     : in  std_logic;
      cpu_we_i     : in  std_logic;
      cpu_reg_i    : in  std_logic_vector(3 downto 0);
      cpu_data_i   : in  std_logic_vector(15 downto 0);
      cpu_data_o   : out std_logic_vector(15 downto 0);

      vga_clk_i    : in  std_logic;          -- VGA clock (25.175 MHz)
      vga_hsync_o  : out std_logic;
      vga_vsync_o  : out std_logic;
      vga_colour_o : out std_logic_vector(11 downto 0);
      vga_de_o     : out std_logic           -- Data Enable
   );
end vga_multicolour;

architecture synthesis of vga_multicolour is

   -- Size of Video Ram Address
   constant C_VRAM_SIZE    : natural := f_log2(VGA_RAM_SIZE);

   -- Register Map
   signal cpu_scroll_en    : std_logic;
   signal cpu_offset_en    : std_logic;
   signal cpu_busy         : std_logic;
   signal cpu_clrscr       : std_logic;
   signal cpu_vga_en       : std_logic;
   signal cpu_cursor_en    : std_logic;
   signal cpu_blink_en     : std_logic;
   signal cpu_cursor_size  : std_logic;

   signal cpu_vram_wr_addr : std_logic_vector(C_VRAM_SIZE-1 downto 0);
   signal cpu_vram_wr_en   : std_logic;
   signal cpu_vram_wr_data : std_logic_vector(15 downto 0);
   signal cpu_vram_rd_addr : std_logic_vector(C_VRAM_SIZE-1 downto 0);
   signal cpu_vram_rd_data : std_logic_vector(15 downto 0);

   signal vga_display_addr : std_logic_vector(15 downto 0);
   signal vga_display_data : std_logic_vector(15 downto 0);
   signal vga_font_addr    : std_logic_vector(9 downto 0);
   signal vga_font_data    : std_logic_vector(15 downto 0);
   signal vga_palette_addr : std_logic_vector(4 downto 0);
   signal vga_palette_data : std_logic_vector(15 downto 0);

begin

   ------------------------
   -- Interface to the CPU
   ------------------------

   i_vga_register_map : entity work.vga_register_map
      port map (
         clk_i         => cpu_clk_i,
         rst_i         => cpu_rst_i,
         en_i          => cpu_en_i,
         we_i          => cpu_we_i,
         reg_i         => cpu_reg_i,
         data_i        => cpu_data_i,
         data_o        => cpu_data_o,

         scroll_en_o   => cpu_scroll_en,     -- Reg 0 bit 11
         offset_en_o   => cpu_offset_en,     -- Reg 0 bit 10
         busy_i        => cpu_busy,          -- Reg 0 bit 9
         clrscr_o      => cpu_clrscr,        -- Reg 0 bit 8
         vga_en_o      => cpu_vga_en,        -- Reg 0 bit 7
         cursor_en_o   => cpu_cursor_en,     -- Reg 0 bit 6
         blink_en_o    => cpu_blink_en,      -- Reg 0 bit 5
         cursor_size_o => cpu_cursor_size    -- Reg 0 bit 4
      ); -- i_vga_register_map


   -----------------------------------------------
   -- Interface to the Video RAM (True Dual Port)
   -----------------------------------------------

   i_vga_video_ram : entity work.vga_video_ram
      generic map (
         G_ADDR_SIZE => C_VRAM_SIZE,
         G_DATA_SIZE => 16
      )
      port map (
         -- CPU access
         cpu_clk_i          => cpu_clk_i,
         cpu_wr_addr_i      => cpu_vram_wr_addr,
         cpu_wr_en_i        => cpu_vram_wr_en,
         cpu_wr_data_i      => cpu_vram_wr_data,
         cpu_rd_addr_i      => cpu_vram_rd_addr,
         cpu_rd_data_o      => cpu_vram_rd_data,

         -- VGA access
         vga_clk_i          => vga_clk_i,
         vga_display_addr_i => vga_display_addr,
         vga_display_data_o => vga_display_data,
         vga_font_addr_i    => vga_font_addr,
         vga_font_data_o    => vga_font_data,
         vga_palette_addr_i => vga_palette_addr,
         vga_palette_data_o => vga_palette_data
      ); -- i_vga_video_ram


   -----------------------------------------------
   -- Generate VGA output
   -----------------------------------------------

   i_vga_output : entity work.vga_output
      port map (
         clk_i          => vga_clk_i,

         -- Configuration from Register Map
         scroll_en_i    => vga_scroll_en,
         offset_en_i    => vga_offset_en,
         busy_o         => vga_busy,
         clrscr_i       => vga_clrscr,
         vga_en_i       => vga_vga_en,
         curs_en_i      => vga_curs_en,
         blink_en_i     => vga_blink_en,
         curs_mode_i    => vga_curs_mode,

         -- Read from Display RAM
         display_addr_o => vga_display_rd_addr,
         display_data_i => vga_display_rd_data,

         -- Read from Font RAM
         font_addr_o    => vga_font_rd_addr,
         font_data_i    => vga_font_rd_data,

         -- Read from Palette RAM
         palette_addr_o => vga_palette_rd_addr,
         palette_data_i => vga_palette_rd_data,

         -- VGA output signals
         hsync_o        => vga_hsync_o,
         vsync_o        => vga_vsync_o,
         colour_o       => vga_colour_o,
         data_en_o      => vga_data_en_o
      ); -- i_vga_output

end synthesis;

