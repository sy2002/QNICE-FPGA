library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This file is the top-level VGA controller. It connects directly to the CPU
-- and to the output ports on the FPGA.
--
-- See the file vga_register_map.vhd for the complete Register Map.
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
      vga_colour_o  : out std_logic_vector(14 downto 0);
      vga_data_en_o : out std_logic             -- Data Enable
   );
end vga_multicolour;

architecture synthesis of vga_multicolour is

   signal cpu_clkn            : std_logic;      -- Inverted CPU clock

   -- Configuration signals synchronized to CPU clock.
   signal cpu_output_enable   : std_logic;
   signal cpu_display_offset  : std_logic_vector(15 downto 0);
   signal cpu_font_offset     : std_logic_vector(15 downto 0);
   signal cpu_cursor_enable   : std_logic;
   signal cpu_cursor_blink    : std_logic;
   signal cpu_cursor_size     : std_logic;
   signal cpu_cursor_x        : std_logic_vector(6 downto 0);
   signal cpu_cursor_y        : std_logic_vector(5 downto 0);
   signal cpu_pixel_y         : std_logic_vector(9 downto 0);

   -- CPU Interface to Video RAM.
   signal cpu_vram_display_addr    : std_logic_vector(15 downto 0);
   signal cpu_vram_display_wr_en   : std_logic;
   signal cpu_vram_display_rd_data : std_logic_vector(15 downto 0);
   signal cpu_vram_font_addr       : std_logic_vector(12 downto 0);
   signal cpu_vram_font_wr_en      : std_logic;
   signal cpu_vram_font_rd_data    : std_logic_vector(7 downto 0);
   signal cpu_vram_palette_addr    : std_logic_vector(4 downto 0);
   signal cpu_vram_palette_wr_en   : std_logic;
   signal cpu_vram_palette_rd_data : std_logic_vector(14 downto 0);
   signal cpu_vram_wr_data         : std_logic_vector(15 downto 0);

   -- Clock Domain Crossing
   signal meta_output_enable  : std_logic;
   signal meta_display_offset : std_logic_vector(15 downto 0);
   signal meta_font_offset    : std_logic_vector(15 downto 0);
   signal meta_cursor_enable  : std_logic;
   signal meta_cursor_blink   : std_logic;
   signal meta_cursor_size    : std_logic;
   signal meta_cursor_x       : std_logic_vector(6 downto 0);
   signal meta_cursor_y       : std_logic_vector(5 downto 0);
   signal meta_pixel_y        : std_logic_vector(9 downto 0);

   -- Configuration signals synchronized to VGA clock.
   signal vga_output_enable   : std_logic;
   signal vga_display_offset  : std_logic_vector(15 downto 0);
   signal vga_font_offset     : std_logic_vector(15 downto 0);
   signal vga_cursor_enable   : std_logic;
   signal vga_cursor_blink    : std_logic;
   signal vga_cursor_size     : std_logic;
   signal vga_cursor_x        : std_logic_vector(6 downto 0);
   signal vga_cursor_y        : std_logic_vector(5 downto 0);
   signal vga_pixel_y         : std_logic_vector(9 downto 0);

   -- VGA Interface to Video RAM.
   signal vga_display_addr    : std_logic_vector(15 downto 0);
   signal vga_display_data    : std_logic_vector(15 downto 0);
   signal vga_font_addr       : std_logic_vector(12 downto 0);
   signal vga_font_data       : std_logic_vector(7 downto 0);
   signal vga_palette_addr    : std_logic_vector(4 downto 0);
   signal vga_palette_data    : std_logic_vector(14 downto 0);

   -- Instruct synthesis tool that these registers are used for CDC.
   attribute ASYNC_REG                        : boolean;
   attribute ASYNC_REG of meta_output_enable  : signal is true;
   attribute ASYNC_REG of meta_display_offset : signal is true;
   attribute ASYNC_REG of meta_font_offset    : signal is true;
   attribute ASYNC_REG of meta_cursor_enable  : signal is true;
   attribute ASYNC_REG of meta_cursor_blink   : signal is true;
   attribute ASYNC_REG of meta_cursor_size    : signal is true;
   attribute ASYNC_REG of meta_cursor_x       : signal is true;
   attribute ASYNC_REG of meta_cursor_y       : signal is true;
   attribute ASYNC_REG of meta_pixel_y        : signal is true;
   attribute ASYNC_REG of vga_output_enable   : signal is true;
   attribute ASYNC_REG of vga_display_offset  : signal is true;
   attribute ASYNC_REG of vga_font_offset     : signal is true;
   attribute ASYNC_REG of vga_cursor_enable   : signal is true;
   attribute ASYNC_REG of vga_cursor_blink    : signal is true;
   attribute ASYNC_REG of vga_cursor_size     : signal is true;
   attribute ASYNC_REG of vga_cursor_x        : signal is true;
   attribute ASYNC_REG of vga_cursor_y        : signal is true;
   attribute ASYNC_REG of cpu_pixel_y         : signal is true;

begin

   -- Invert CPU clock. The reason for this is to be able to write
   -- rising_edge(cpu_clkn) instead of falling_edge(cpu_clk_i).
   -- The Vivado tool has a bug when inferring BRAM, see:
   -- https://forums.xilinx.com/t5/Synthesis/falling-edge-not-supported-in-inferred-RAM/m-p/1039276
   cpu_clkn <= not cpu_clk_i;


   ------------------------
   -- Interface to the CPU
   ------------------------

   i_vga_register_map : entity work.vga_register_map
      port map (
         clk_i            => cpu_clkn,
         rst_i            => cpu_rst_i,
         en_i             => cpu_en_i,
         we_i             => cpu_we_i,
         reg_i            => cpu_reg_i,
         data_i           => cpu_data_i,
         data_o           => cpu_data_o,

         vram_display_addr_o    => cpu_vram_display_addr,
         vram_display_wr_en_o   => cpu_vram_display_wr_en,
         vram_display_rd_data_i => cpu_vram_display_rd_data,
         vram_font_addr_o       => cpu_vram_font_addr,
         vram_font_wr_en_o      => cpu_vram_font_wr_en,
         vram_font_rd_data_i    => cpu_vram_font_rd_data,
         vram_palette_addr_o    => cpu_vram_palette_addr,
         vram_palette_wr_en_o   => cpu_vram_palette_wr_en,
         vram_palette_rd_data_i => cpu_vram_palette_rd_data,
         vram_wr_data_o         => cpu_vram_wr_data,

         vga_en_o         => cpu_output_enable,    -- Reg 0 bit 7
         cursor_enable_o  => cpu_cursor_enable,    -- Reg 0 bit 6
         cursor_blink_o   => cpu_cursor_blink,     -- Reg 0 bit 5
         cursor_size_o    => cpu_cursor_size,      -- Reg 0 bit 4
         cursor_x_o       => cpu_cursor_x,         -- Reg 1
         cursor_y_o       => cpu_cursor_y,         -- Reg 2
         display_offset_o => cpu_display_offset,   -- Reg 4
         font_offset_o    => cpu_font_offset,      -- Reg 9
         pixel_y_i        => cpu_pixel_y           -- Reg 11
      ); -- i_vga_register_map


   -----------------------------------------------
   -- Interface to the Video RAM (True Dual Port)
   -----------------------------------------------

   i_vga_video_ram : entity work.vga_video_ram
      port map (
         -- CPU access
         cpu_clk_i             => cpu_clkn,
         cpu_display_addr_i    => cpu_vram_display_addr,
         cpu_display_wr_en_i   => cpu_vram_display_wr_en,
         cpu_display_rd_data_o => cpu_vram_display_rd_data,
         cpu_font_addr_i       => cpu_vram_font_addr,
         cpu_font_wr_en_i      => cpu_vram_font_wr_en,
         cpu_font_rd_data_o    => cpu_vram_font_rd_data,
         cpu_palette_addr_i    => cpu_vram_palette_addr,
         cpu_palette_wr_en_i   => cpu_vram_palette_wr_en,
         cpu_palette_rd_data_o => cpu_vram_palette_rd_data,
         cpu_wr_data_i         => cpu_vram_wr_data,

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

   p_cpu_to_vga : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         meta_output_enable  <= cpu_output_enable;
         meta_display_offset <= cpu_display_offset;
         meta_font_offset    <= cpu_font_offset;
         meta_cursor_enable  <= cpu_cursor_enable;
         meta_cursor_blink   <= cpu_cursor_blink;
         meta_cursor_size    <= cpu_cursor_size;
         meta_cursor_x       <= cpu_cursor_x;
         meta_cursor_y       <= cpu_cursor_y;

         vga_output_enable   <= meta_output_enable;
         vga_display_offset  <= meta_display_offset;
         vga_font_offset     <= meta_font_offset;
         vga_cursor_enable   <= meta_cursor_enable;
         vga_cursor_blink    <= meta_cursor_blink;
         vga_cursor_size     <= meta_cursor_size;
         vga_cursor_x        <= meta_cursor_x;
         vga_cursor_y        <= meta_cursor_y;
      end if;
   end process p_cpu_to_vga;

   p_vga_to_cpu : process (cpu_clk_i)
   begin
      if rising_edge(cpu_clk_i) then
         meta_pixel_y        <= vga_pixel_y;
         cpu_pixel_y         <= meta_pixel_y;
      end if;
   end process p_vga_to_cpu;


   -----------------------------------------------
   -- Generate VGA output
   -----------------------------------------------

   i_vga_output : entity work.vga_output
      port map (
         clk_i            => vga_clk_i,

         -- Configuration from Register Map
         output_enable_i  => vga_output_enable,
         display_offset_i => vga_display_offset,
         font_offset_i    => vga_font_offset,
         cursor_enable_i  => vga_cursor_enable,
         cursor_blink_i   => vga_cursor_blink,
         cursor_size_i    => vga_cursor_size,
         cursor_x_i       => vga_cursor_x,
         cursor_y_i       => vga_cursor_y,
         pixel_y_o        => vga_pixel_y,

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

