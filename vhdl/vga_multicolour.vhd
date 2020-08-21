-- 80x40 Textmode VGA
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- output goes zero when not enabled
-- done by sy2002 in December 2015/January 2016, refactored in Mai/June 2020
-- refactored by MJoergen in August 2020

-- Features:
-- * 80x40 text mode
-- * one color for the whole screen
-- * hardware cursor
-- * large video memory: 64.000 bytes, stores 20 screens aka "pages" (selectable via global var VGA_RAM_SIZE)
-- * hardware scrolling
--
-- Registers:
--
-- register 0: status and control register
--    bits(11:10) hardware scrolling / offset enable: enables the use of the offset registers 4 and 5 for
--                reading/writing to the vram (bit 11 = 1, register 5) and/or
--                for displaying vram contents (bit 10 = 1, register 4)
--    bit 9       busy: vga is currently busy, e.g. clearing the screen, printing, etc.
--                while busy, vga will ignore commands (they can be still written into the registers though)
--    bit 8       clear screen: write 1, read: 1 = clearscreen still active, 0 = ready
--    bit 7       VGA enable signal (1 = on, 0 switches off the vga signal generation)
--    bit 6       HW cursor enable bit
--    bit 5       blink HW cursor enable bit
--    bit 4       HW cursor mode (0 = big; 1 = small)
--    bits(2:0)   output color for the whole screen (3-bit rgb, 8 colors)
-- register 1: cursor x position read/write (0..79)
-- register 2: cusror y position read/write (0..39)
-- register 3: write: print character written into this register's (7 downto 0) bits at cursor x/y position
--             read: bits (7 downto 0) contains the character in video ram at address (cursor x, y)
-- register 4: vga display offset register used e.g. for hardware scrolling (0..63999)
-- register 5: vga read/write offset register used for accessing the whole vram (0..63999)
--
-- The following registers currently only make sense on a MEGA65 R2 board that uses the ADV7511;
-- on other platforms they do not harm though:
-- register 6: hctr_min: HDMI Data Enable: X: minimum valid column
-- register 7: hctr_max: HDMI Data Enable: X: maximum valid column
-- register 8: vctr_max: HDMI Data Enable: Y: maximum valid row (line)

-- how to make fonts, see http://nafe.sourceforge.net/
-- then use the psf2coe.rb and then coe2rom.pl toolchain to generate .rom files
-- in case the Source Forge link is not available: nafe-0.1.tar.gz is stored in the 'vga' subfolder
-- alternative: as psf2coe.rb does not seem to work, use
-- xxd -p -c 1 -u lat9w-12.psfu | sed -e '1,4d' > lat9w-12.coe
-- to convert "type 1" psfu's that are made by nafe from the original Linux font files to create the .coe

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.env1_globals.all;                -- VGA_RAM_SIZE

entity vga_multicolour is
   port (
      cpu_clk_i  : in  std_logic;         -- CPU clock (currently at 50 MHz)
      cpu_rst_i  : in  std_logic;
      cpu_en_i   : in  std_logic;
      cpu_we_i   : in  std_logic;
      cpu_reg_i  : in  std_logic_vector(3 downto 0);
      cpu_data_i : in  std_logic_vector(15 downto 0);
      cpu_data_o : out std_logic_vector(15 downto 0);

      vga_clk_i  : in  std_logic;         -- VGA clock (25.175 MHz)
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0);
      vga_de_o   : out std_logic          -- Data Enable
   );
end vga_multicolour;

architecture synthesis of vga_multicolour is

   -- Size of Video Ram
   constant C_VRAM_SIZE    : natural := 15;  -- 32 kW

   -- Register Map
   signal cpu_scroll_en    : std_logic;
   signal cpu_offset_en    : std_logic;
   signal cpu_busy         : std_logic;
   signal cpu_clrscr       : std_logic;
   signal cpu_vga_en       : std_logic;
   signal cpu_curs_en      : std_logic;
   signal cpu_blink_en     : std_logic;
   signal cpu_curs_mode    : std_logic;

   signal cpu_vram_wr_addr : std_logic_vector(C_VRAM_SIZE-1 downto 0);
   signal cpu_vram_wr_en   : std_logic;
   signal cpu_vram_wr_data : std_logic_vector(15 downto 0);
   signal cpu_vram_rd_addr : std_logic_vector(C_VRAM_SIZE-1 downto 0);
   signal cpu_vram_rd_data : std_logic_vector(15 downto 0);

   signal vga_vram_rd_addr : std_logic_vector(C_VRAM_SIZE-1 downto 0);
   signal vga_vram_rd_data : std_logic_vector(15 downto 0);

begin

   ------------------------
   -- Interface to the CPU
   ------------------------

   i_vga_register_map : entity work.vga_register_map
      port map (
         clk_i       => cpu_clk_i,
         rst_i       => cpu_rst_i,
         en_i        => cpu_en_i,
         we_i        => cpu_we_i,
         reg_i       => cpu_reg_i,
         data_i      => cpu_data_i,
         data_o      => cpu_data_o,

         scroll_en_o => cpu_scroll_en, -- Reg 0 bit 11
         offset_en_o => cpu_offset_en, -- Reg 0 bit 10
         busy_i      => cpu_busy,      -- Reg 0 bit 9
         clrscr_o    => cpu_clrscr,    -- Reg 0 bit 8
         vga_en_o    => cpu_vga_en,    -- Reg 0 bit 7
         curs_en_o   => cpu_curs_en,   -- Reg 0 bit 6
         blink_en_o  => cpu_blink_en,  -- Reg 0 bit 5
         curs_mode_o => cpu_curs_mode  -- Reg 0 bit 4
      ); -- i_vga_register_map


   -----------------------------------------------
   -- Interface to the Video RAM (True Dual Port)
   -----------------------------------------------

   i_vga_video_ram : entity work.true_dual_port_ram
      generic map (
         G_ADDR_SIZE => C_VRAM_SIZE,
         G_DATA_SIZE => 16
      )
      port map (
         -- CPU access
         a_clk_i     => cpu_clk_i,
         a_wr_addr_i => cpu_vram_wr_addr,
         a_wr_en_i   => cpu_vram_wr_en,
         a_wr_data_i => cpu_vram_wr_data,
         a_rd_addr_i => cpu_vram_rd_addr,
         a_rd_data_o => cpu_vram_rd_data,

         -- VGA access
         b_clk_i     => vga_clk_i,
         b_rd_addr_i => vga_vram_rd_addr,
         b_rd_data_o => vga_vram_rd_data
      ); -- i_vga_video_ram


   -----------------------------------------------
   -- Generate VGA output
   -----------------------------------------------

   i_vga_output : entity work.vga_output
      port map (
         clk_i       => vga_clk_i,

         -- Configuration from Register Map
         scroll_en_i => vga_scroll_en,
         offset_en_i => vga_offset_en,
         busy_o      => vga_busy,
         clrscr_i    => vga_clrscr,
         vga_en_i    => vga_vga_en,
         curs_en_i   => vga_curs_en,
         blink_en_i  => vga_blink_en,
         curs_mode_i => vga_curs_mode,

         -- Read from Video RAM
         vram_addr_o => vga_vram_rd_addr,
         vram_data_i => vga_vram_rd_data,

         -- VGA output signals
         hs_o        => vga_hs_o,
         vs_o        => vga_vs_o,
         col_o       => vga_col_o,
         de_o        => vga_de_o
      ); -- i_vga_output

end synthesis;

