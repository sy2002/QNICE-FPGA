library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This file contains the Register Map as seen by the CPU.
--
-- Register Map:
-- 00 : Control
-- 01 : Cursor X
-- 02 : Cursor Y
-- 03 : Character and Colour at Cursor
-- 04 : Display offset
-- 05 : Cursor offset
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
-- bit 10 : R/W : Display offset enable
-- bit 11 : R/W : Cursor offset enable

entity vga_register_map is
   port (
      -- Connected to CPU
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
      en_i             : in  std_logic;
      we_i             : in  std_logic;
      reg_i            : in  std_logic_vector(3 downto 0);
      data_i           : in  std_logic_vector(15 downto 0);
      data_o           : out std_logic_vector(15 downto 0);

      -- Connected to Video RAM
      vram_addr_o      : out std_logic_vector(17 downto 0);
      vram_wr_en_o     : out std_logic;
      vram_wr_data_o   : out std_logic_vector(15 downto 0);
      vram_rd_data_i   : in  std_logic_vector(15 downto 0);

      -- Connected to VGA output
      vga_en_o         : out std_logic;
      cursor_enable_o  : out std_logic;
      cursor_blink_o   : out std_logic;
      cursor_size_o    : out std_logic;
      cursor_x_o       : buffer std_logic_vector(6 downto 0);
      cursor_y_o       : buffer std_logic_vector(5 downto 0);
      display_offset_o : out std_logic_vector(15 downto 0)
   );
end vga_register_map;

architecture synthesis of vga_register_map is

   type register_map_t is array (0 to 15) of std_logic_vector(15 downto 0);

   signal register_map : register_map_t;

   signal clrscr_addr : std_logic_vector(17 downto 0);
   signal clrscr_old  : std_logic;
   signal clrscr_new  : std_logic;
   signal vram_offset : std_logic_vector(15 downto 0);

--   attribute mark_debug                     : boolean;
--   attribute mark_debug of rst_i            : signal is true;
--   attribute mark_debug of en_i             : signal is true;
--   attribute mark_debug of we_i             : signal is true;
--   attribute mark_debug of reg_i            : signal is true;
--   attribute mark_debug of data_i           : signal is true;
--   attribute mark_debug of data_o           : signal is true;
--   attribute mark_debug of vram_addr_o      : signal is true;
--   attribute mark_debug of vram_wr_en_o     : signal is true;
--   attribute mark_debug of vram_wr_data_o   : signal is true;
--   attribute mark_debug of vram_rd_data_i   : signal is true;
--   attribute mark_debug of vga_en_o         : signal is true;
--   attribute mark_debug of cursor_enable_o  : signal is true;
--   attribute mark_debug of cursor_blink_o   : signal is true;
--   attribute mark_debug of cursor_size_o    : signal is true;
--   attribute mark_debug of cursor_x_o       : signal is true;
--   attribute mark_debug of cursor_y_o       : signal is true;
--   attribute mark_debug of clrscr_addr      : signal is true;
--   attribute mark_debug of clrscr_old       : signal is true;
--   attribute mark_debug of clrscr_new       : signal is true;
--   attribute mark_debug of display_offset_o : signal is true;
--   attribute mark_debug of vram_offset      : signal is true;

begin

   clrscr_old <= register_map(0)(8);
   clrscr_new <= data_i(8) when en_i = '1' and we_i = '1' and conv_integer(reg_i) = 0
            else clrscr_old;

   p_register_map : process (clk_i)
   begin
      if falling_edge(clk_i) then
         if en_i = '1' and we_i = '1' then
            register_map(conv_integer(reg_i)) <= data_i;
         end if;

         -- Special handling for reg 0 bits 8 and 9.
         -- Bit 8 is the CLRSCR bit, and it autoclears.
         -- Bit 9 is the BUSY bit.
         if clrscr_old = '0' and clrscr_new = '1' then
            clrscr_addr <= (others => '0');
            register_map(0)(9) <= '1'; -- Set BUSY bit
         elsif clrscr_old = '1' then
            clrscr_addr <= std_logic_vector(unsigned(clrscr_addr)+1);
            if conv_integer(clrscr_addr) = 63999 then
               register_map(0)(8) <= '0'; -- Clear CLRSCR bit
               register_map(0)(9) <= '0'; -- Clear BUSY bit
            end if;
         end if;
      end if;
   end process p_register_map;

   data_o <= vram_rd_data_i                    when en_i = '1' and we_i = '0' and reg_i = "0011" else
             register_map(conv_integer(reg_i)) when en_i = '1' and we_i = '0'                    else
             (others => '0');

   p_output : process (clk_i)
   begin
      if falling_edge(clk_i) then
         vga_en_o         <= register_map(0)(7);
         cursor_enable_o  <= register_map(0)(6);
         cursor_blink_o   <= register_map(0)(5);
         cursor_size_o    <= register_map(0)(4);
         cursor_x_o       <= register_map(1)(6 downto 0);
         cursor_y_o       <= register_map(2)(5 downto 0);

         display_offset_o <= (others => '0');
         if register_map(0)(10) = '1' then
            display_offset_o <= register_map(4);
         end if;

         vram_offset <= (others => '0');
         if register_map(0)(11) = '1' then
            vram_offset <= register_map(5);
         end if;

         vram_addr_o    <= (others => '0');
         vram_wr_en_o   <= '0';
         vram_wr_data_o <= (others => '0');
         if en_i = '1' and we_i = '1' and reg_i = "0011" then
            vram_addr_o    <= ("000000" & std_logic_vector(unsigned(cursor_y_o)*80 + unsigned(cursor_x_o)))
                              + vram_offset;
            vram_wr_en_o   <= '1';
            vram_wr_data_o <= data_i;
         end if;
         if clrscr_old = '1' then
            vram_addr_o    <= clrscr_addr;
            vram_wr_en_o   <= '1';
            vram_wr_data_o <= X"0020";
         end if;
      end if;
   end process p_output;

end synthesis;

