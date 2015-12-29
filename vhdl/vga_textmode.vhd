-- 80x40 Textmode VGA
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015

-- this is mainly a wrapper around Javier Valcarce's component
-- http://www.javiervalcarce.eu/wiki/VHDL_Macro:_VGA80x40

-- how to make fonts, see http://nafe.sourceforge.net/
-- then use the psf2coe.rb and then coe2rom.pl toolchain to generate .rom files

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_textmode is
port (
   reset    : in std_logic;     -- async reset
   clk      : in std_logic;     -- system clock
   clk50MHz : in std_logic;     -- needs to be a 50 MHz clock

   -- VGA registers
   en       : in std_logic;     -- enable for reading from or writing to the bus
   we       : in std_logic;     -- write to VGA's registers via system's data bus
   reg      : in std_logic_vector(3 downto 0);     -- register selector
   data     : inout std_logic_vector(15 downto 0); -- system's data bus
   
   -- VGA output signals, monochrome only
   R        : out std_logic;
   G        : out std_logic;
   B        : out std_logic;
   hsync    : out std_logic;
   vsync    : out std_logic
);
end vga_textmode;

architecture beh of vga_textmode is

component vga80x40
port (
   reset       : in  std_logic;
   clk25MHz    : in  std_logic;

   -- VGA signals, monochrome only   
   R           : out std_logic;
   G           : out std_logic;
   B           : out std_logic;
   hsync       : out std_logic;
   vsync       : out std_logic;
   
   -- address and data lines of video ram for text
   TEXT_A           : out std_logic_vector(11 downto 0);
   TEXT_D           : in  std_logic_vector(07 downto 0);
   
   -- address and data lines of font rom
   FONT_A           : out std_logic_vector(11 downto 0);
   FONT_D           : in  std_logic_vector(07 downto 0);
   
   -- hardware cursor x and y positions
   ocrx    : in  std_logic_vector(7 downto 0);
   ocry    : in  std_logic_vector(7 downto 0);
   
   -- control register
   -- Bit 7 VGA enable signal
   -- Bit 6 HW cursor enable bit
   -- Bit 5 is Blink HW cursor enable bit
   -- Bit 4 is HW cursor mode (0 = big; 1 = small)
   -- Bits(2:0) is the output color.
   octl    : in  std_logic_vector(7 downto 0)
);   
end component;

component video_bram
generic (
   SIZE_BYTES     : integer;    -- size of the RAM/ROM in bytes
   CONTENT_FILE   : string;     -- if not empty then a prefilled RAM ("ROM") from a .rom file is generated
   FILE_LINES     : integer;    -- size of the content file in lines (files may be smaller than the RAM/ROM size)   
   DEFAULT_VALUE  : bit_vector  -- default value to fill the memory with
);
port (
   clk            : in std_logic;
   we             : in std_logic;   
   address_i      : in std_logic_vector(15 downto 0);
   address_o      : in std_logic_vector(15 downto 0);
   data_i         : in std_logic_vector(7 downto 0);
   data_o         : out std_logic_vector(7 downto 0)
);
end component;

component SyTargetCounter is
generic (
   COUNTER_FINISH : integer;                 -- target value
   COUNTER_WIDTH  : integer range 2 to 32    -- bit width of target value
);
port (
   clk       : in std_logic;                 -- clock
   reset     : in std_logic;                 -- async reset
   
   cnt       : out std_logic_vector(COUNTER_WIDTH -1 downto 0); -- current value
   overflow  : out std_logic := '0' -- true for one clock cycle when the counter wraps around
);
end component;


-- VGA specific clock, also used for video ram and font rom
signal clk25MHz   : std_logic;

-- signals for wiring video and font ram with the vga80x40 component
signal vga_text_a : std_logic_vector(11 downto 0);
signal vga_text_d : std_logic_vector(7 downto 0);
signal vga_font_a : std_logic_vector(11 downto 0);
signal vga_font_d : std_logic_vector(7 downto 0);

-- signals for write-accessing the video ram
signal vmem_addr  : std_logic_vector(11 downto 0);
signal vmem_data  : std_logic_vector(7 downto 0);
signal vmem_we    : std_logic;
signal reset_vmem_we : std_logic;
signal reset_vmem_cnt : std_logic;

-- VGA control signals
signal vga_x      : std_logic_vector(7 downto 0);
signal vga_y      : std_logic_vector(6 downto 0);
signal vga_ctl    : std_logic_vector(7 downto 0);
signal vga_char   : std_logic_vector(7 downto 0);

begin

   vga : vga80x40
      port map (
         reset => reset,
         clk25MHz => clk25MHz,
         R => R,
         G => G,
         B => B,
         hsync => hsync,
         vsync => vsync,
         TEXT_A => vga_text_a,
         TEXT_D => vga_text_d,
         FONT_A => vga_font_a,
         FONT_D => vga_font_d,
         ocrx => vga_x,
         ocry => "0" & vga_y,
         octl => vga_ctl
      );

   video_ram : video_bram
      generic map (
         SIZE_BYTES => 3200,                             -- 80 columns x 40 lines = 3.200 bytes
         CONTENT_FILE => "testscreen.rom",               -- @TODO remove test image -- don't specify a file, so this is RAM
         FILE_LINES => 163,
         DEFAULT_VALUE => x"20"                          -- ACSII code of the space character
      )
      port map (
         clk => clk25MHz,
         we => vmem_we,
         address_o => "0000" & vga_text_a,
         data_o => vga_text_d,
         address_i => "0000" & vmem_addr,
         data_i => vmem_data
      );
      
   font_rom : video_bram
      generic map (
         SIZE_BYTES => 3072,
         CONTENT_FILE => "lat0-12.rom",
         FILE_LINES => 3072,
         DEFAULT_VALUE => x"00"
      )
      port map (
         clk => clk25MHz,
         we => '0',
         address_o => "0000" & vga_font_a,
         data_o => vga_font_d,
         address_i => (others => '0'),
         data_i => vmem_data -- will be ignored since we is '0'
      );
      
   write_counter : SyTargetCounter
      generic map (
         COUNTER_FINISH => 2,
         COUNTER_WIDTH => 2
      )
      port map (
         clk => clk25MHz,
         reset => reset_vmem_cnt,
         overflow => reset_vmem_we
      );
      
   vga_register_driver : process(clk, reset, reset_vmem_we)
   variable tmp : IEEE.NUMERIC_STD.unsigned(13 downto 0);
   variable tsl : std_logic_vector(13 downto 0);   
   begin
      if reset = '1' or reset_vmem_we = '1' then
         if reset = '1' then
            vga_x <= (others => '0');
            vga_y <= (others => '0');
            vga_ctl <= (others => '0');
            vga_char <= (others => '0');
            vmem_addr <= (others => '0');
         end if;
         if reset_vmem_we = '1' then
            vmem_we <= '0';
         end if;
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' then
               case reg is
                  -- status register
                  when x"0" => vga_ctl <= data(7 downto 0);
                  
                  -- cursor x register
                  when x"1" => vga_x <= data(7 downto 0);                                 
                  
                  -- cursor y register
                  when x"2" => vga_y <= data(6 downto 0);
                  
                  -- character paint register
                  when x"3" =>
                     vga_char <= data(7 downto 0);
                     tmp := IEEE.NUMERIC_STD.unsigned(vga_x) + (IEEE.NUMERIC_STD.unsigned(vga_y) * 80);
                     tsl := std_logic_vector(tmp);
                     vmem_addr <= tsl(11 downto 0);
                     vmem_we <= '1';
                     reset_vmem_cnt <= '1';
                  
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;
   
   
--   -- clock-in the current to-be-displayed value and mask into a FF for the TIL
--   til_driver : process(clk, reset)
--   begin
--      if reset = '1' then
--         TIL_311_buffer <= x"0000";
--         TIL_311_mask <= "1111";
--      else
--         if falling_edge(clk) then
--            if til_reg0_enable = '1' then
--               TIL_311_buffer <= data_in;            
--            end if;
--            
--            if til_reg1_enable = '1' then
--               TIL_311_mask <= data_in(3 downto 0);
--            end if;
--         end if;
--      end if;
--   end process;   

   clk25MHz <= '0' when reset = '1' else
               not clk25MHz when rising_edge(clk50MHz);
               
   vmem_data <= vga_char;
end beh;

