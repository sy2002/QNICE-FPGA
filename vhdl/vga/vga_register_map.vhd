library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This file contains the Register Map as seen by the CPU.

entity vga_register_map is
   port (
      -- Connected to CPU
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
      en_i             : in  std_logic;
      we_i             : in  std_logic;
      reg_i            : in  std_logic_vector(4 downto 0);
      data_i           : in  std_logic_vector(15 downto 0);
      data_o           : out std_logic_vector(15 downto 0);
      int_n_o          : out std_logic;
      grant_n_i        : in  std_logic;

      -- Connected to Video RAM
      vram_display_addr_o    : out std_logic_vector(15 downto 0);
      vram_display_wr_en_o   : out std_logic;
      vram_display_rd_data_i : in  std_logic_vector(15 downto 0);
      vram_font_addr_o       : out std_logic_vector(12 downto 0);
      vram_font_wr_en_o      : out std_logic;
      vram_font_rd_data_i    : in  std_logic_vector(7 downto 0);
      vram_palette_addr_o    : out std_logic_vector(5 downto 0);
      vram_palette_wr_en_o   : out std_logic;
      vram_palette_rd_data_i : in  std_logic_vector(14 downto 0);
      vram_wr_data_o         : out std_logic_vector(15 downto 0);

      -- Connected to VGA output
      vga_en_o         : out std_logic;
      cursor_enable_o  : out std_logic;
      cursor_blink_o   : out std_logic;
      cursor_size_o    : out std_logic;
      cursor_x_o       : out std_logic_vector(6 downto 0);
      cursor_y_o       : out std_logic_vector(5 downto 0);
      display_offset_o : out std_logic_vector(15 downto 0);
      font_offset_o    : out std_logic_vector(15 downto 0);
      palette_offset_o : out std_logic_vector(15 downto 0);
      adjust_x_o       : out std_logic_vector(9 downto 0);
      adjust_y_o       : out std_logic_vector(9 downto 0);
      pixel_y_i        : in  std_logic_vector(9 downto 0)
   );
end vga_register_map;

architecture synthesis of vga_register_map is

   -- Register Map:
   constant C_REG_CONTROL          : integer := 0;
   constant C_REG_CURSOR_X         : integer := 1;
   constant C_REG_CURSOR_Y         : integer := 2;
   constant C_REG_CURSOR_CHAR      : integer := 3;
   constant C_REG_CURSOR_OFFSET    : integer := 4;
   constant C_REG_DISPLAY_OFFSET   : integer := 5;
   constant C_REG_FONT_OFFSET      : integer := 6;
   constant C_REG_FONT_ADDRESS     : integer := 7;
   constant C_REG_FONT_DATA        : integer := 8;
   constant C_REG_PALETTE_OFFSET   : integer := 9;
   constant C_REG_PALETTE_ADDRESS  : integer := 10;
   constant C_REG_PALETTE_DATA     : integer := 11;
   constant C_REG_ADJUST_X         : integer := 16;
   constant C_REG_ADJUST_Y         : integer := 17;
   constant C_REG_SCAN_CURRENT     : integer := 18;
   constant C_REG_SCAN_INTERRUPT   : integer := 19;
   constant C_REG_SCAN_ISR_ADDRESS : integer := 20;

   -- Interpretation of Control Register:
   constant C_CONTROL_CURSOR_SIZE       : integer := 4;
   constant C_CONTROL_CURSOR_BLINK      : integer := 5;
   constant C_CONTROL_CURSOR_ENABLED    : integer := 6;
   constant C_CONTROL_VGA_ENABLED       : integer := 7;
   constant C_CONTROL_CLEAR_SCREEN      : integer := 8;
   constant C_CONTROL_BUSY              : integer := 9;
   constant C_CONTROL_DISPLAY_OFFSET_EN : integer := 10;
   constant C_CONTROL_CURSOR_OFFSET_EN  : integer := 11;

   type register_map_t is array (0 to 31) of std_logic_vector(15 downto 0);

   signal register_map : register_map_t;

   signal clrscr_addr    : std_logic_vector(15 downto 0);
   signal clrscr_old     : std_logic;
   signal clrscr_new     : std_logic;
   signal display_offset : std_logic_vector(15 downto 0);
   signal cursor_offset  : std_logic_vector(15 downto 0);
   signal cursor_x       : std_logic_vector(6 downto 0);
   signal cursor_y       : std_logic_vector(5 downto 0);
   signal cursor_addr    : std_logic_vector(15 downto 0);

--   attribute mark_debug                           : boolean;
--   attribute mark_debug of rst_i                  : signal is true;
--   attribute mark_debug of en_i                   : signal is true;
--   attribute mark_debug of we_i                   : signal is true;
--   attribute mark_debug of reg_i                  : signal is true;
--   attribute mark_debug of data_i                 : signal is true;
--   attribute mark_debug of data_o                 : signal is true;
--   attribute mark_debug of vram_wr_data_o         : signal is true;
--   attribute mark_debug of vram_display_addr_o    : signal is true;
--   attribute mark_debug of vram_display_wr_en_o   : signal is true;
--   attribute mark_debug of vram_display_rd_data_i : signal is true;
--   attribute mark_debug of vram_font_addr_o       : signal is true;
--   attribute mark_debug of vram_font_wr_en_o      : signal is true;
--   attribute mark_debug of vram_font_rd_data_i    : signal is true;
--   attribute mark_debug of vram_palette_addr_o    : signal is true;
--   attribute mark_debug of vram_palette_wr_en_o   : signal is true;
--   attribute mark_debug of vram_palette_rd_data_i : signal is true;
--   attribute mark_debug of vga_en_o               : signal is true;
--   attribute mark_debug of cursor_enable_o        : signal is true;
--   attribute mark_debug of cursor_blink_o         : signal is true;
--   attribute mark_debug of cursor_size_o          : signal is true;
--   attribute mark_debug of cursor_x_o             : signal is true;
--   attribute mark_debug of cursor_y_o             : signal is true;
--   attribute mark_debug of clrscr_addr            : signal is true;
--   attribute mark_debug of clrscr_old             : signal is true;
--   attribute mark_debug of clrscr_new             : signal is true;
--   attribute mark_debug of display_offset         : signal is true;
--   attribute mark_debug of cursor_offset          : signal is true;
--   attribute mark_debug of cursor_addr            : signal is true;

begin

   clrscr_old <= register_map(C_REG_CONTROL)(C_CONTROL_CLEAR_SCREEN);
   clrscr_new <= data_i(C_CONTROL_CLEAR_SCREEN) when
                 en_i = '1' and we_i = '1' and conv_integer(reg_i) = C_REG_CONTROL
            else clrscr_old;

   p_register_map : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if en_i = '1' and we_i = '1' then
            register_map(conv_integer(reg_i)) <= data_i;
         end if;

         -- Special handling for Control register bits CLEAR_SCREEN and BUSY.
         if clrscr_old = '0' and clrscr_new = '1' then
            clrscr_addr <= (others => '0');
            register_map(C_REG_CONTROL)(C_CONTROL_BUSY) <= '1';
         elsif clrscr_old = '1' then
            clrscr_addr <= std_logic_vector(unsigned(clrscr_addr)+1);
            if conv_integer(clrscr_addr) = 63999 then
               register_map(C_REG_CONTROL)(C_CONTROL_CLEAR_SCREEN) <= '0';
               register_map(C_REG_CONTROL)(C_CONTROL_BUSY)         <= '0';
            end if;
         end if;

         if rst_i = '1' then
            register_map <= (others => (others => '0'));
            register_map(C_REG_SCAN_INTERRUPT)(15) <= '1';  -- Disable scanline interrupt
         end if;
      end if;
   end process p_register_map;

   cursor_x    <= register_map(C_REG_CURSOR_X)(6 downto 0);
   cursor_y    <= register_map(C_REG_CURSOR_Y)(5 downto 0);

   -- Manually calculate: addr = y*80 + x.
   -- For some reason, Vivado was unable to correctly synthesize the multiplication.
   cursor_addr <= ("0000" & cursor_y & "000000") +
                  ("000000" & cursor_y & "0000") +
                  ("000000000" & cursor_x);

   display_offset <= register_map(C_REG_DISPLAY_OFFSET) when
                     register_map(C_REG_CONTROL)(C_CONTROL_DISPLAY_OFFSET_EN) = '1' else
                     (others => '0');
   cursor_offset  <= register_map(C_REG_CURSOR_OFFSET) when
                     register_map(C_REG_CONTROL)(C_CONTROL_CURSOR_OFFSET_EN) = '1' else
                     (others => '0');


   -- Put registers on output signals.
   p_output : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_en_o         <= register_map(C_REG_CONTROL)(C_CONTROL_VGA_ENABLED);
         cursor_enable_o  <= register_map(C_REG_CONTROL)(C_CONTROL_CURSOR_ENABLED);
         cursor_blink_o   <= register_map(C_REG_CONTROL)(C_CONTROL_CURSOR_BLINK);
         cursor_size_o    <= register_map(C_REG_CONTROL)(C_CONTROL_CURSOR_SIZE);
         cursor_x_o       <= cursor_x;
         cursor_y_o       <= cursor_y;
         adjust_x_o       <= register_map(C_REG_ADJUST_X)(9 downto 0);
         adjust_y_o       <= register_map(C_REG_ADJUST_Y)(9 downto 0);

         display_offset_o <= display_offset;
         font_offset_o    <= register_map(C_REG_FONT_OFFSET);
         palette_offset_o <= register_map(C_REG_PALETTE_OFFSET);

         vram_display_addr_o  <= cursor_addr + cursor_offset;
         vram_font_addr_o     <= register_map(C_REG_FONT_ADDRESS)(12 downto 0);     -- 8k words
         vram_palette_addr_o  <= register_map(C_REG_PALETTE_ADDRESS)(5 downto 0);   -- 64 words

         vram_display_wr_en_o <= '0';
         vram_font_wr_en_o    <= '0';
         vram_palette_wr_en_o <= '0';
         vram_wr_data_o       <= data_i;

         case conv_integer(reg_i) is
            when C_REG_CURSOR_CHAR  => vram_display_wr_en_o <= en_i and we_i;
            when C_REG_FONT_DATA    => vram_font_wr_en_o    <= en_i and we_i and register_map(C_REG_FONT_ADDRESS)(12);
            when C_REG_PALETTE_DATA => vram_palette_wr_en_o <= en_i and we_i and register_map(C_REG_PALETTE_ADDRESS)(5);
            when others => null;
         end case;

         if clrscr_old = '1' then
            vram_display_addr_o  <= clrscr_addr;
            vram_display_wr_en_o <= '1';
            vram_wr_data_o       <= X"0020";
         end if;
      end if;
   end process p_output;

   int_n_o <= '0' when pixel_y_i = register_map(C_REG_SCAN_INTERRUPT)(9 downto 0)
                   and '0' = register_map(C_REG_SCAN_INTERRUPT)(15)
         else '1';

   -- Data output is combinatorial.
   data_o <= register_map(C_REG_SCAN_ISR_ADDRESS) when grant_n_i = '0'                                                        else
             vram_display_rd_data_i               when en_i = '1' and we_i = '0' and conv_integer(reg_i) = C_REG_CURSOR_CHAR  else
             "000000" & pixel_y_i                 when en_i = '1' and we_i = '0' and conv_integer(reg_i) = C_REG_SCAN_CURRENT else
             X"00" & vram_font_rd_data_i          when en_i = '1' and we_i = '0' and conv_integer(reg_i) = C_REG_FONT_DATA    else
             "0" & vram_palette_rd_data_i         when en_i = '1' and we_i = '0' and conv_integer(reg_i) = C_REG_PALETTE_DATA else
             register_map(conv_integer(reg_i))    when en_i = '1' and we_i = '0'                                              else
             (others => '0');

end synthesis;

