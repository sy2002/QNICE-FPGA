library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
-- * The vga_video_ram, which is a True Dual Port RAM using both clock domains.
-- The only communication between the CPU and VGA clock domains is via the
-- Video RAM module.

entity vga_multicolour is
   port (
      cpu_clk_i     : in  std_logic;            -- CPU clock (currently at 50 MHz)
      cpu_rst_i     : in  std_logic;
      cpu_en_i      : in  std_logic;
      cpu_we_i      : in  std_logic;
      cpu_reg_i     : in  std_logic_vector(3 downto 0);
      cpu_data_i    : in  std_logic_vector(15 downto 0);
      cpu_data_o    : out std_logic_vector(15 downto 0);

      vga_clk_i     : in  std_logic;            -- VGA clock (25.175 MHz)
      vga_hsync_o   : out std_logic;
      vga_vsync_o   : out std_logic;
      vga_colour_o  : out std_logic_vector(11 downto 0);
      vga_data_en_o : out std_logic             -- Data Enable
   );
end vga_multicolour;

architecture synthesis of vga_multicolour is

   -- Register Map synchronized to CPU clock.
   signal cpu_scroll_en      : std_logic;
   signal cpu_offset_en      : std_logic;
   signal cpu_busy           : std_logic;
   signal cpu_clrscr         : std_logic;
   signal cpu_vga_en         : std_logic;
   signal cpu_display_offset : std_logic_vector(15 downto 0);
   signal cpu_tile_offset    : std_logic_vector(15 downto 0);
   signal cpu_cursor_enable  : std_logic;
   signal cpu_cursor_blink   : std_logic;
   signal cpu_cursor_size    : std_logic;
   signal cpu_cursor_x       : std_logic_vector(6 downto 0);
   signal cpu_cursor_y       : std_logic_vector(5 downto 0);

   -- CPU Interface to Video RAM.
   signal cpu_vram_wr_addr   : std_logic_vector(17 downto 0);
   signal cpu_vram_wr_en     : std_logic;
   signal cpu_vram_wr_data   : std_logic_vector(15 downto 0);
   signal cpu_vram_rd_addr   : std_logic_vector(17 downto 0);
   signal cpu_vram_rd_data   : std_logic_vector(15 downto 0);

   -- Control signals synchronized to VGA clock.
   signal vga_display_offset : std_logic_vector(15 downto 0);
   signal vga_tile_offset    : std_logic_vector(15 downto 0);
   signal vga_cursor_enable  : std_logic;
   signal vga_cursor_blink   : std_logic;
   signal vga_cursor_size    : std_logic;
   signal vga_cursor_x       : std_logic_vector(6 downto 0);
   signal vga_cursor_y       : std_logic_vector(5 downto 0);

   -- VGA Interface to Video RAM.
   signal vga_display_addr   : std_logic_vector(15 downto 0);
   signal vga_display_data   : std_logic_vector(15 downto 0);
   signal vga_font_addr      : std_logic_vector(9 downto 0);
   signal vga_font_data      : std_logic_vector(7 downto 0);
   signal vga_palette_addr   : std_logic_vector(4 downto 0);
   signal vga_palette_data   : std_logic_vector(11 downto 0);

begin

   ------------------------
   -- Interface to the CPU
   ------------------------

   i_vga_register_map : entity work.vga_register_map
      port map (
         clk_i           => cpu_clk_i,
         rst_i           => cpu_rst_i,
         en_i            => cpu_en_i,
         we_i            => cpu_we_i,
         reg_i           => cpu_reg_i,
         data_i          => cpu_data_i,
         data_o          => cpu_data_o,

         vram_wr_addr_o  => cpu_vram_wr_addr,
         vram_wr_en_o    => cpu_vram_wr_en,
         vram_wr_data_o  => cpu_vram_wr_data,
         vram_rd_addr_o  => cpu_vram_rd_addr,
         vram_rd_data_i  => cpu_vram_rd_data,

         scroll_en_o     => cpu_scroll_en,     -- Reg 0 bit 11
         offset_en_o     => cpu_offset_en,     -- Reg 0 bit 10
         busy_i          => cpu_busy,          -- Reg 0 bit 9
         clrscr_o        => cpu_clrscr,        -- Reg 0 bit 8
         vga_en_o        => cpu_vga_en,        -- Reg 0 bit 7
         cursor_enable_o => cpu_cursor_enable, -- Reg 0 bit 6
         cursor_blink_o  => cpu_cursor_blink,  -- Reg 0 bit 5
         cursor_size_o   => cpu_cursor_size,   -- Reg 0 bit 4
         cursor_x_o      => cpu_cursor_x,      -- Reg 1
         cursor_y_o      => cpu_cursor_y       -- Reg 2
      ); -- i_vga_register_map


   -----------------------------------------------
   -- Interface to the Video RAM (True Dual Port)
   -----------------------------------------------

   i_vga_video_ram : entity work.vga_video_ram
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
   -- Clock Domain Crossing
   -----------------------------------------------

   p_cdc : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_display_offset <= cpu_display_offset;
         vga_tile_offset    <= cpu_tile_offset;
         vga_cursor_enable  <= '1';       -- cpu_cursor_enable;
         vga_cursor_blink   <= '1';       -- cpu_cursor_blink;
         vga_cursor_size    <= '1';       -- cpu_cursor_size;
         vga_cursor_x       <= "0001010"; -- cpu_cursor_x;
         vga_cursor_y       <= "001010";  -- cpu_cursor_y;
      end if;
   end process p_cdc;


   -----------------------------------------------
   -- Generate VGA output
   -----------------------------------------------

   i_vga_output : entity work.vga_output
      port map (
         clk_i            => vga_clk_i,

         -- Configuration from Register Map
         display_offset_i => vga_display_offset,
         tile_offset_i    => vga_tile_offset,
         cursor_enable_i  => vga_cursor_enable,
         cursor_blink_i   => vga_cursor_blink,
         cursor_size_i    => vga_cursor_size,
         cursor_x_i       => vga_cursor_x,
         cursor_y_i       => vga_cursor_y,

         -- Interface to Video RAM
         display_addr_o   => vga_display_addr,
         display_data_i   => vga_display_data,
         font_addr_o      => vga_font_addr,
         font_data_i      => vga_font_data,
         palette_addr_o   => vga_palette_addr,
         palette_data_i   => vga_palette_data,

         -- VGA output signals
         hsync_o          => vga_hsync_o,
         vsync_o          => vga_vsync_o,
         colour_o         => vga_colour_o,
         data_en_o        => vga_data_en_o
      ); -- i_vga_output

end synthesis;

