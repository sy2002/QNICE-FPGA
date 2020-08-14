-- 80x40 Textmode VGA
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
-- done by sy2002 in December 2015/January 2016, refactored in Mai/June 2020

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
--
-- this component uses Javier Valcarce's vga core
-- http://www.javiervalcarce.eu/html/vhdl-vga80x40-en.html

-- how to make fonts, see http://nafe.sourceforge.net/
-- then use the psf2coe.rb and then coe2rom.pl toolchain to generate .rom files
-- in case the Source Forge link is not available: nafe-0.1.tar.gz is stored in the 'vga' subfolder
-- alternative: as psf2coe.rb does not seem to work, use
-- xxd -p -c 1 -u lat9w-12.psfu | sed -e '1,4d' > lat9w-12.coe
-- to convert "type 1" psfu's that are made by nafe from the original Linux font files to create the .coe

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.env1_globals.all;

entity vga_textmode is
port (
   reset       : in std_logic;     -- async reset
   clk25MHz    : in std_logic;
   clk50MHz    : in std_logic;

   -- VGA registers
   en          : in std_logic;     -- enable for reading from or writing to the bus
   we          : in std_logic;     -- write to VGA's registers via system's data bus
   reg         : in std_logic_vector(3 downto 0);     -- register selector
   data        : inout std_logic_vector(15 downto 0); -- system's data bus
   
   -- VGA output signals, monochrome only
   R           : out std_logic;
   G           : out std_logic;
   B           : out std_logic;
   hsync       : out std_logic;
   vsync       : out std_logic;
   
   hdmi_de     : out std_logic
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
   TEXT_A      : out std_logic_vector(11 downto 0);
   TEXT_D      : in  std_logic_vector(07 downto 0);
   
   -- address and data lines of font rom
   FONT_A      : out std_logic_vector(11 downto 0);
   FONT_D      : in  std_logic_vector(07 downto 0);
   
   -- hardware cursor x and y positions
   ocrx        : in  std_logic_vector(7 downto 0);
   ocry        : in  std_logic_vector(7 downto 0);
   
   -- control register
   octl        : in  std_logic_vector(7 downto 0);
   
   -- ADV7511: HDMI Data Enable: high when valid pixels being output   
   hdmi_de     : out std_logic;
   de_hctr_min : integer range 793 downto 0;
   de_hctr_max : integer range 793 downto 0;
   de_vctr_max : integer range 524 downto 0   
);   
end component;

component video_bram is
generic (
   SIZE_BYTES     : integer
);
port (
   clk1           : in std_logic;
   we             : in std_logic;   
   address_i      : in std_logic_vector(15 downto 0);
   data_i         : in std_logic_vector(7 downto 0);
   address1_o     : in std_logic_vector(15 downto 0);
   data1_o        : out std_logic_vector(7 downto 0);

   clk2           : in std_logic;
   address2_o     : in std_logic_vector(15 downto 0);
   data2_o        : out std_logic_vector(7 downto 0)
);
end component;

component BROM is
generic (
   FILE_NAME   : string;
   ROM_WIDTH   : integer   
);
port (
   clk         : in std_logic;                        -- read and write on rising clock edge
   ce          : in std_logic;                        -- chip enable, when low then high impedance on output
   
   address     : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   data        : out std_logic_vector(ROM_WIDTH - 1 downto 0);   -- read data
   
   -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA, goes high impedance
   -- if not needed (ce = 0) and can therefore directly be connected to a bus
   busy        : out std_logic                       
);
end component;

-- signals for wiring video and font ram with the vga80x40 component
signal vga_text_a          : std_logic_vector(11 downto 0);
signal vga_text_d          : std_logic_vector(7 downto 0);
signal vga_font_a          : std_logic_vector(11 downto 0);
signal vga_font_d          : std_logic_vector(7 downto 0);

-- VGA control flipflops
signal vga_x               : std_logic_vector(7 downto 0);
signal vga_y               : std_logic_vector(6 downto 0);
signal vga_char            : std_logic_vector(7 downto 0);
signal vga_ctl             : std_logic_vector(7 downto 0);

type vga_command_type is ( vc_idle,          -- idle is not literally idle: the vram is constantly being painted
                           vc_print,         -- print a character aka transfer a byte into vram
                           vc_print_store,   -- make sure we, addr and data are stable long enough for the vram
                           vc_clrscr,        -- clear the screen
                           vc_clrscr_run,
                           vc_clrscr_store,
                           vc_clrscr_inc
                         );
signal vga_cmd             : vga_command_type := vc_idle;
signal vga_busy            : std_logic;
                      
---- memory read functionality
signal vga_read_data       : std_logic_vector(7 downto 0); -- ff: store current read values
                      
-- vram control signals
signal vmem_disp_addr      : std_logic_vector(15 downto 0); -- realtime vga display (the vga80x40 component scans it all the time)
signal vmem_addr           : std_logic_vector(15 downto 0); -- accessing the vram via the cpu
signal vmem_we             : std_logic;
signal vmem_data           : std_logic_vector(7 downto 0);

-- hardware scrolling and whole vram access
signal vmem_offs_rw        : std_logic := '0';
signal vmem_offs_display   : std_logic := '0';
signal offs_display        : std_logic_vector(15 downto 0) := (others => '0');
signal offs_rw             : std_logic_vector(15 downto 0) := (others => '0');
signal print_addr_w_offs   : std_logic_vector(15 downto 0);

-- HDMI data enable
signal reg_hctr_min        : integer range 793 downto 0;
signal reg_hctr_max        : integer range 793 downto 0;
signal reg_vctr_max        : integer range 524 downto 0;

-- command type: print char
signal vga_print           : std_logic := '0';
signal reset_vga_print     : std_logic;
signal print_addr          : std_logic_vector(11 downto 0);

-- command type: clear screen
signal clrscr_cnt          : unsigned(15 downto 0);
signal vga_clrscr          : std_logic := '0';
signal reset_vga_clrscr    : std_logic;

-- state machine signals
signal fsm_next_vga_cmd    : vga_command_type;
signal fsm_clrscr_cnt      : unsigned(15 downto 0);


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
         octl => vga_ctl,
         hdmi_de => hdmi_de,
         de_hctr_min => reg_hctr_min,
         de_hctr_max => reg_hctr_max,
         de_vctr_max => reg_vctr_max
      );
      
   video_ram : video_bram
      generic map (
         SIZE_BYTES => VGA_RAM_SIZE
      )
      port map (
         clk1 => clk50Mhz,
         we => vmem_we,
         address_i => vmem_addr,
         data_i => vmem_data,
         address1_o => print_addr_w_offs,
         data1_o => vga_read_data,
         
         clk2 => clk25Mhz,
         address2_o => vmem_disp_addr,
         data2_o => vga_text_d                  
      );
       
   font_rom : BROM
      generic map (
         FILE_NAME => "vga/lat9w-12_sy2002.rom",
         ROM_WIDTH => 8
      )
      port map (
         clk => clk25MHz,
         ce => '1',
         address => "000" & vga_font_a,
         data => vga_font_d
      );
         
   fsm_advance_state : process(clk50MHz, reset)
   begin
      if reset = '1' then
         vga_cmd <= vc_idle;
         clrscr_cnt <= (others => '0');
      else
         if falling_edge(clk50MHz) then
            vga_cmd <= fsm_next_vga_cmd;
            clrscr_cnt <= fsm_clrscr_cnt;
         end if;
      end if;     
   end process;
   
   fsm_calc_state : process(vga_cmd, vga_print, vga_clrscr, clrscr_cnt)
   variable new_clrscr_cnt : IEEE.NUMERIC_STD.unsigned(15 downto 0);
   begin
      fsm_next_vga_cmd <= vga_cmd;
      fsm_clrscr_cnt <= clrscr_cnt;
      reset_vga_print <= '0';
      reset_vga_clrscr <= '0';
      
      case vga_cmd is
         -- while in idle mode, new commands are recognized
         when vc_idle =>
            -- trigger print command
            if vga_print = '1' then
               fsm_next_vga_cmd <= vc_print;
            end if;

            -- trigger clearscreen command
            if vga_clrscr = '1' then
               fsm_next_vga_cmd <= vc_clrscr;
            end if;
            
         -- command execution: print
         when vc_print =>
            reset_vga_print <= '1';
            fsm_next_vga_cmd <= vc_print_store;
         
         when vc_print_store =>
            fsm_next_vga_cmd <= vc_idle;
                       
         -- command execution: clear screen
         when vc_clrscr =>
            fsm_clrscr_cnt <= (others => '0');
            fsm_next_vga_cmd <= vc_clrscr_run;
            
         when vc_clrscr_run =>
            fsm_next_vga_cmd <= vc_clrscr_store;
         
         when vc_clrscr_store =>
            fsm_next_vga_cmd <= vc_clrscr_inc;
         
         when vc_clrscr_inc =>
            new_clrscr_cnt := clrscr_cnt + 1;
            fsm_clrscr_cnt <= new_clrscr_cnt;
            if new_clrscr_cnt = VGA_RAM_SIZE then
               reset_vga_clrscr <= '1';
               fsm_next_vga_cmd <= vc_idle;
            else
               fsm_next_vga_cmd <= vc_clrscr_run;
            end if;
            
         when others => null;   
      end case;      
   end process;
   
   calc_vmem_signals : process(vga_cmd, print_addr_w_offs, vga_char, clrscr_cnt)
   begin      
      case vga_cmd is
         when vc_print | vc_print_store  =>
            vmem_we <= '1';
            vmem_addr <= print_addr_w_offs;            
            vmem_data <= vga_char;
            
         when vc_clrscr_run | vc_clrscr_store =>
            vmem_we <= '1';
            vmem_addr <= std_logic_vector(clrscr_cnt);
            vmem_data <= x"20"; -- space character
            
         when others =>
            vmem_we <= '0';
            vmem_addr <= (others => '0');            
            vmem_data <= (others => '0');
            
      end case;
   end process;
      
   write_vga_registers : process(clk50MHz, reset)
      variable vx : IEEE.NUMERIC_STD.unsigned(7 downto 0);
      variable vy : IEEE.NUMERIC_STD.unsigned(6 downto 0);
      variable memory_pos : std_logic_vector(13 downto 0); -- x + (80 * y)
   begin  
      if reset = '1' then
         vga_x <= (others => '0');
         vga_y <= (others => '0');
         vga_ctl <= (others => '0');
         vga_char <= (others => '0');
         print_addr <= (others => '0');
         vmem_offs_display <= '0';
         vmem_offs_rw <= '0';         
         offs_display <= (others => '0');
         offs_rw <= (others => '0');
         
         -- default settings so that the whole screen is visible
         reg_hctr_min <= 9;
         reg_hctr_max <= 650;
         reg_vctr_max <= 480;                     
      else                  
         if falling_edge(clk50MHz) then
            if en = '1' and we = '1' then
               case reg is
                  -- status register
                  when x"0" =>
                     vga_ctl <= data(7 downto 0);
                     vmem_offs_display <= data(10);
                     vmem_offs_rw <= data(11);
                     
                  -- cursor x register
                  when x"1" =>
                     vga_x <= data(7 downto 0);
                     vx := unsigned(data(7 downto 0));
                     vy := unsigned(vga_y);
                     memory_pos := std_logic_vector(vx + (vy * 80));                     
                     print_addr <= memory_pos(11 downto 0);
                  
                  -- cursor y register
                  when x"2" =>
                     vga_y <= data(6 downto 0);
                     vx := unsigned(vga_x);
                     vy := unsigned(data(6 downto 0));
                     memory_pos := std_logic_vector(vx + (vy * 80));
                     print_addr <= memory_pos(11 downto 0);

                  -- character print register
                  when x"3" =>
                     vga_char <= data(7 downto 0);                  
                     vx := unsigned(vga_x);
                     vy := unsigned(vga_y);
                     memory_pos := std_logic_vector(vx + (vy * 80));                  
                     print_addr <= memory_pos(11 downto 0);
                     
                  -- offset registers
                  when x"4" => offs_display <= data;
                  when x"5" => offs_rw <= data;
                  
                  -- ADV7511 HDMI DE config registers
                  when x"6" => reg_hctr_min <= to_integer(unsigned(data));
                  when x"7" => reg_hctr_max <= to_integer(unsigned(data));
                  when x"8" => reg_vctr_max <= to_integer(unsigned(data));
                                    
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;
   
   detect_vga_print : process(clk50MHz, reset, reset_vga_print)
   begin
      if reset = '1' or reset_vga_print = '1' then
         vga_print <= '0';
      else
         if falling_edge(clk50MHz) then
            if en = '1' and we = '1' and reg = x"3" then         
               vga_print <= '1';
            end if;
         end if;
      end if;
   end process;
   
   detect_vga_clrscr : process(clk50MHz, reset, reset_vga_clrscr)
   begin
      if reset = '1' or reset_vga_clrscr = '1' then
         vga_clrscr <= '0';
      else
         if falling_edge(clk50MHz) then
            if en = '1' and we = '1' and reg = x"0" then
               vga_clrscr <= data(8);
            end if;
         end if;
      end if;
   end process;
         
   read_vga_registers : process(en, we, reg, vga_ctl, vga_x, vga_y, vga_char, vga_busy, vga_clrscr, vga_read_data,
                                vmem_offs_rw, vmem_offs_display, offs_display, offs_rw,
                                reg_hctr_min, reg_hctr_max, reg_vctr_max)
   begin   
      if en = '1' and we = '0' then
         case reg is            
            when x"0" => data <= "0000" &                               -- status register
                                 vmem_offs_rw &                         --    bit 11
                                 vmem_offs_display &                    --    bit 10
                                 vga_busy &                             --    bit 9
                                 vga_clrscr &                           --    bit 8
                                 vga_ctl;                               --    bits 0..7
            when x"1" => data <= x"00"  & vga_x;                        -- cursor x register
            when x"2" => data <= x"00" & '0' & vga_y;                   -- cursor y register
            when x"3" => data <= x"00"  & vga_read_data;                -- character print/read register
            when x"4" => data <= offs_display;                          -- display offset register
            when x"5" => data <= offs_rw;                               -- memory access (read/write) offset register
            
            -- ADV7511 HDMI DE config registers
            when x"6" => data <= std_logic_vector(to_unsigned(reg_hctr_min, 16));
            when x"7" => data <= std_logic_vector(to_unsigned(reg_hctr_max, 16));
            when x"8" => data <= std_logic_vector(to_unsigned(reg_vctr_max, 16));
      
            when others => data <= (others => '0');
         end case;
      else
         data <= (others => 'Z');
      end if;
   end process;
   
   calc_vmem_disp_addr : process(vmem_offs_display, offs_display, vga_text_a)
      variable disp_addr : unsigned(16 downto 0);
      variable disp_offs : unsigned(16 downto 0);
   begin
      if vmem_offs_display = '1' then
         -- address for display = address generated by the vga80x40 component plus offset
         disp_offs := "0" & unsigned(offs_display);
         disp_addr := disp_offs + unsigned(vga_text_a);
         
         -- manual wrap around due to the (0..VGA_RAM_SIZE-1) memory size
         if disp_addr > (VGA_RAM_SIZE - 1) then
            disp_addr := disp_addr - VGA_RAM_SIZE;
         end if;
         
         vmem_disp_addr <= std_logic_vector(disp_addr(15 downto 0));
      else
         vmem_disp_addr <= "0000" & vga_text_a;      
      end if;
   end process;
   
   calc_print_addr_w_offs : process(vmem_offs_rw, offs_rw, print_addr)
      variable disp_addr : unsigned(16 downto 0);
      variable disp_offs : unsigned(16 downto 0);   
   begin
      if vmem_offs_rw = '1' then
         disp_offs := "0" & unsigned(offs_rw);
         disp_addr := disp_offs + unsigned(print_addr);
         if disp_addr > (VGA_RAM_SIZE - 1) then
            disp_addr := disp_addr - VGA_RAM_SIZE;
         end if;
         
         print_addr_w_offs <= std_logic_vector(disp_addr(15 downto 0));
      else
         print_addr_w_offs <= "0000" & print_addr;
      end if;
   end process;
   
   vga_busy <= '0' when vga_cmd = vc_idle else '1';
end beh;
