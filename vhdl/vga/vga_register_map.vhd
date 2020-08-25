library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
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

entity vga_register_map is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;
      en_i            : in  std_logic;
      we_i            : in  std_logic;
      reg_i           : in  std_logic_vector(3 downto 0);
      data_i          : in  std_logic_vector(15 downto 0);
      data_o          : out std_logic_vector(15 downto 0);

      vram_wr_addr_o  : out std_logic_vector(17 downto 0);
      vram_wr_en_o    : out std_logic;
      vram_wr_data_o  : out std_logic_vector(15 downto 0);
      vram_rd_addr_o  : out std_logic_vector(17 downto 0);
      vram_rd_data_i  : in  std_logic_vector(15 downto 0);

      scroll_en_o     : out std_logic;
      offset_en_o     : out std_logic;
      busy_i          : in  std_logic;
      clrscr_o        : out std_logic;
      vga_en_o        : out std_logic;
      cursor_enable_o : out std_logic;
      cursor_blink_o  : out std_logic;
      cursor_size_o   : out std_logic;
      cursor_x_o      : buffer std_logic_vector(6 downto 0);
      cursor_y_o      : buffer std_logic_vector(5 downto 0)
   );
end vga_register_map;

architecture synthesis of vga_register_map is

   type mem_t is array (0 to 15) of std_logic_vector(15 downto 0);

   signal mem : mem_t;

   signal clrscr_addr : std_logic_vector(17 downto 0);
   signal clrscr_old  : std_logic;
   signal clrscr_new  : std_logic;

   attribute mark_debug                    : boolean;
   attribute mark_debug of rst_i           : signal is true;
   attribute mark_debug of en_i            : signal is true;
   attribute mark_debug of we_i            : signal is true;
   attribute mark_debug of reg_i           : signal is true;
   attribute mark_debug of data_i          : signal is true;
   attribute mark_debug of data_o          : signal is true;
   attribute mark_debug of vram_wr_addr_o  : signal is true;
   attribute mark_debug of vram_wr_en_o    : signal is true;
   attribute mark_debug of vram_wr_data_o  : signal is true;
   attribute mark_debug of vram_rd_addr_o  : signal is true;
   attribute mark_debug of vram_rd_data_i  : signal is true;
   attribute mark_debug of scroll_en_o     : signal is true;
   attribute mark_debug of offset_en_o     : signal is true;
   attribute mark_debug of busy_i          : signal is true;
   attribute mark_debug of clrscr_o        : signal is true;
   attribute mark_debug of vga_en_o        : signal is true;
   attribute mark_debug of cursor_enable_o : signal is true;
   attribute mark_debug of cursor_blink_o  : signal is true;
   attribute mark_debug of cursor_size_o   : signal is true;
   attribute mark_debug of cursor_x_o      : signal is true;
   attribute mark_debug of cursor_y_o      : signal is true;
   attribute mark_debug of clrscr_addr     : signal is true;
   attribute mark_debug of clrscr_old      : signal is true;
   attribute mark_debug of clrscr_new      : signal is true;

begin

   clrscr_old <= mem(0)(8);
   clrscr_new <= '1' when en_i = '1' and we_i = '1' and conv_integer(reg_i) = 0 and data_i(8) = '1'
            else '0';

   p_map : process (clk_i)
   begin
      if falling_edge(clk_i) then
         if en_i = '1' and we_i = '1' then
            mem(conv_integer(reg_i)) <= data_i;
         end if;

         if clrscr_old = '0' and clrscr_new = '1' then
            clrscr_addr <= (others => '0');
            mem(0)(9) <= '1'; -- Set busy
         elsif clrscr_old = '1' then
            clrscr_addr <= std_logic_vector(unsigned(clrscr_addr)+1);
            if conv_integer(clrscr_addr) = 63999 then
               mem(0)(8) <= '0';
               mem(0)(9) <= '0'; -- Clear busy
            end if;
         end if;
      end if;
   end process p_map;


   data_o <= vram_rd_data_i           when en_i = '1' and we_i = '0' and reg_i = "0011" else
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

   vram_wr_addr_o  <= clrscr_addr when clrscr_old = '1'
                 else "000000" & (std_logic_vector(unsigned(cursor_y_o)*80) + cursor_x_o);

   vram_wr_en_o    <= '1' when clrscr_old = '1'
                 else '1' when en_i = '1' and we_i = '1' and reg_i = "0011";
                 else '0';

   vram_wr_data_o  <= X"0020" when clrscr_old = '1'
                 else data_i;

   vram_rd_addr_o  <= "000000" & (std_logic_vector(unsigned(cursor_y_o)*80) + cursor_x_o);

end synthesis;

