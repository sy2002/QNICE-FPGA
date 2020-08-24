library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

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

entity vga_register_map is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;
      en_i            : in  std_logic;
      we_i            : in  std_logic;
      reg_i           : in  std_logic_vector(3 downto 0);
      data_i          : in  std_logic_vector(15 downto 0);
      data_o          : out std_logic_vector(15 downto 0);

      vram_wr_addr_o  : out std_logic_vector(15 downto 0);
      vram_wr_en_o    : out std_logic;
      vram_wr_data_o  : out std_logic_vector(15 downto 0);
      vram_rd_addr_o  : out std_logic_vector(15 downto 0);
      vram_rd_data_i  : in  std_logic_vector(15 downto 0);

      scroll_en_o     : out std_logic;
      offset_en_o     : out std_logic;
      busy_i          : in  std_logic;
      clrscr_o        : out std_logic;
      vga_en_o        : out std_logic;
      cursor_enable_o : out std_logic;
      cursor_blink_o  : out std_logic;
      cursor_size_o   : out std_logic;
      cursor_x_o      : out std_logic_vector(6 downto 0);
      cursor_y_o      : out std_logic_vector(5 downto 0)
   );
end vga_register_map;

architecture synthesis of vga_register_map is

   type mem_t is array (0 to 15) of std_logic_vector(15 downto 0);

   signal mem : mem_t;

begin

   p_map : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if en_i = '1' and we_i = '1' then
            mem(conv_integer(reg_i)) <= data_i;
         end if;
      end if;
   end process p_map;

   data_o <= vram_rd_data_i when en_i = '1' and we_i = '0' and reg_i = "0011" else
             mem(conv_integer(reg_i)) when en_i = '1' and we_i = '0' else
             (others => '0');

   scroll_en_o     <= mem(0)(11);
   offset_en_o     <= mem(0)(10);
   clrscr_o        <= mem(0)( 8);
   vga_en_o        <= mem(0)( 7);
   cursor_enable_o <= mem(0)( 6);
   cursor_blink_o  <= mem(0)( 5);
   cursor_size_o   <= mem(0)( 4);
   cursor_x_o      <= mem(1)(6 downto 0);
   cursor_y_o      <= mem(2)(5 downto 0);

   vram_wr_addr_o  <= cursor_y_o*80 + cursor_x_o;
   vram_wr_en_o    <= '1' when en_i = '1' and we_i = '1' and reg_i = "0011";
   vram_wr_data_o  <= data_i;
   vram_rd_addr_o  <= cursor_y_o*80 + cursor_x_o;

end synthesis;

