----------------------------------------------------------------------------------------------------
--
-- Monocrome Text Mode Video Controller VHDL Macro
-- 80x40 characters. Pixel resolution is 640x480/60Hz
-- 
-- Copyright (c) 2007 Javier Valcarce Garc�a, javier.valcarce@gmail.com
--
-- Bugfixed by Proboscide99 at 31/08/08
-- Enhanced and bugfixed by sy2002 in 2015/2016
-- Support for ADV7511 HDMI Data Enable signal by sy2002 in June 2020 
--
----------------------------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity vga80x40 is
  port (
    reset       : in  std_logic;
    clk25MHz    : in  std_logic;
    TEXT_A      : out std_logic_vector(11 downto 0); -- text buffer
    TEXT_D      : in  std_logic_vector(07 downto 0);
	 FONT_A      : out std_logic_vector(11 downto 0); -- font buffer
	 FONT_D      : in  std_logic_vector(07 downto 0);
	 --
	 ocrx        : in  std_logic_vector(07 downto 0); -- OUTPUT regs
    ocry        : in  std_logic_vector(07 downto 0);
    octl        : in  std_logic_vector(07 downto 0);
    --
    R           : out std_logic;
    G           : out std_logic;
    B           : out std_logic;
    hsync       : out std_logic;
    vsync       : out std_logic;
    
    -- ADV7511: HDMI Data Enable: high when valid pixels being output
    hdmi_de     : out std_logic;
    de_hctr_min : integer range 793 downto 0 := 9;
    de_hctr_max : integer range 793 downto 0 := 650;
    de_vctr_max : integer range 524 downto 0 := 480
  ); 
end vga80x40;



architecture rtl of vga80x40 is

  signal R_int : std_logic;
  signal G_int : std_logic;
  signal B_int : std_logic;
  signal hsync_int : std_logic;
  signal vsync_int : std_logic;
  
  signal blank : std_logic;
  signal hctr  : integer range 793 downto 0;
  signal vctr  : integer range 524 downto 0;
  -- character/pixel position on the screen
  signal scry  : integer range 039 downto 0;  -- chr row   < 40 (6 bits)
  signal scrx  : integer range 079 downto 0;  -- chr col   < 80 (7 bits)
  signal chry  : integer range 011 downto 0;  -- chr high  < 12 (4 bits)
  signal chrx  : integer range 007 downto 0;  -- chr width < 08 (3 bits)
  
  signal losr_ce : std_logic;
  signal losr_ld : std_logic;
  signal losr_do : std_logic;
  signal y       : std_logic;  -- character luminance pixel value (0 or 1)

  -- control io register
  signal ctl       : std_logic_vector(7 downto 0);
  signal vga_en    : std_logic;
  signal cur_en    : std_logic;
  signal cur_mode  : std_logic;
  signal cur_blink : std_logic;
  signal ctl_r     : std_logic;
  signal ctl_g     : std_logic;
  signal ctl_b     : std_logic;

begin

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------  
-- hsync generator, initialized with '1'
  process (clk25MHz)
  begin
     if rising_edge(clk25MHz) then
        if (hctr > 663) and (hctr < 757) then
           hsync_int <= '0';
        else
           hsync_int <= '1';
        end if;

        if reset = '1' then
           hsync_int <= '1';
        end if;
     end if;
  end process;


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- vsync generator, initialized with '1'
  process (clk25MHz)
  begin
     if rising_edge(clk25MHz) then
        if (vctr > 499) and (vctr < 502) then
           vsync_int <= '0';
        else
           vsync_int <= '1';
        end if;

        if reset = '1' then
           vsync_int <= '1';
        end if;
     end if;
  end process;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------  
-- Blank signal, 0 = no draw, 1 = visible/draw zone   

-- Proboscide99 31/08/08
--  blank <= '0' when (hctr > 639) or (vctr > 479) else '1';
  blank <= '0' when (hctr < 8) or (hctr > 647) or (vctr > 479) else '1';

  -- ADV7511 Data Enable
  hdmi_de <= '1' when (hctr > de_hctr_min and hctr < de_hctr_max and vctr < de_vctr_max) else '0'; 

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------  
-- flip-flips for sync of R, G y B signal, initialized with '0'
  process (clk25MHz)
  begin
     if rising_edge(clk25MHz) then
        R <= R_int;
        G <= G_int;
        B <= B_int;

        if reset = '1' then
           R <= '0';
           G <= '0';
           B <= '0';
        end if;
     end if;
  end process;


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------  
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
  -- Control register. Individual control signal
  cur_mode  <= octl(4); 
  cur_blink <= octl(5); 
  cur_en    <= octl(6); 
  vga_en    <= octl(7); 
  ctl_r     <= octl(2);
  ctl_g     <= octl(1);
  ctl_b     <= octl(0);

	-- counters, hctr, vctr, srcx, srcy, chrx, chry
	-- TODO: OPTIMIZE THIS
  counters : block
    signal hctr_ce : std_logic;
    signal hctr_rs : std_logic;
    signal vctr_ce : std_logic;
    signal vctr_rs : std_logic;

    signal chrx_ce : std_logic;
    signal chrx_rs : std_logic;
    signal chry_ce : std_logic;
    signal chry_rs : std_logic;
    signal scrx_ce : std_logic;
    signal scrx_rs : std_logic;
    signal scry_ce : std_logic;
    signal scry_rs : std_logic;

    signal hctr_639 : std_logic;
    signal vctr_479 : std_logic;
    signal chrx_007 : std_logic;
    signal chry_011 : std_logic;
    signal scrx_079 : std_logic;

    -- RAM read, ROM read
    signal ram_tmp : integer range 3200 downto 0;  --12 bits
    signal rom_tmp : integer range 3070 downto 0;

  begin
    
    U_HCTR : entity work.ctrm generic map (M => 794) port map (
	 clk=>clk25MHz, ce =>hctr_ce, rs =>hctr_rs, do => hctr);
	 
    U_VCTR : entity work.ctrm generic map (M => 525) port map (clk25MHz, vctr_ce, vctr_rs, vctr);

    hctr_ce <= '1';
    hctr_rs <= '1' when hctr = 793 else reset;
    vctr_ce <= '1' when hctr = 663 else '0';
    vctr_rs <= '1' when vctr = 524 else reset;

    U_CHRX: entity work.ctrm generic map (M => 008) port map (clk25MHz, chrx_ce, chrx_rs, chrx);
    U_CHRY: entity work.ctrm generic map (M => 012) port map (clk25MHz, chry_ce, chry_rs, chry);
    U_SCRX: entity work.ctrm generic map (M => 080) port map (clk25MHz, scrx_ce, scrx_rs, scrx);
    U_SCRY: entity work.ctrm generic map (M => 040) port map (clk25MHz, scry_ce, scry_rs, scry);

    hctr_639 <= '1' when hctr = 639 else '0';
    vctr_479 <= '1' when vctr = 479 else '0';
    chrx_007 <= '1' when chrx = 007 else '0';
    chry_011 <= '1' when chry = 011 else '0';
--    scrx_079 <= '1' when scrx = 079 else '0'; -- removed by sy2002

    chrx_rs <= chrx_007 or hctr_639 or reset;
    chry_rs <= chry_011 or vctr_479 or reset;
    scrx_rs <= hctr_639 or reset;
    scry_rs <= vctr_479 or reset;

    chrx_ce <= '1' and blank;
    scrx_ce <= chrx_007;
    chry_ce <= hctr_639 and blank;
    scry_ce <= chry_011 and hctr_639;


-- Proboscide99 31/08/08
--    ram_tmp <= scry * 80 + scrx + 1 when ((scrx_079 = '0')) else
--               scry * 80 when ((chry_011 = '0') and (scrx_079 = '1')) else
--               0         when ((chry_011 = '1') and (scrx_079 = '1'));
    ram_tmp <= scry * 80 + scrx;

    TEXT_A <= std_logic_vector(TO_UNSIGNED(ram_tmp, 12));

    rom_tmp <= TO_INTEGER(unsigned(TEXT_D)) * 12 + chry;
    FONT_A <= std_logic_vector(TO_UNSIGNED(rom_tmp, 12));

  end block;
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

  U_LOSR : entity work.losr generic map (N => 8)
    port map (reset, clk25MHz, losr_ld, losr_ce, losr_do, FONT_D);
  
  losr_ce <= blank;
  losr_ld <= '1' when (chrx = 007) else '0';

  -- video out, vga_en control signal enable/disable vga signal
  R_int <= (ctl_r and y) and blank;
  G_int <= (ctl_g and y) and blank;
  B_int <= (ctl_b and y) and blank;
  
  hsync <= hsync_int and vga_en;
  vsync <= vsync_int and vga_en;  
  
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

  -- Hardware Cursor
  hw_cursor : block
    signal small   : std_logic;
    signal curen2  : std_logic;
    signal slowclk : std_logic;
    signal curpos  : std_logic;
    signal yint    : std_logic;
    signal crx_tmp : integer range 79 downto 0;
    signal cry_tmp : integer range 39 downto 0;
    signal crx     : integer range 79 downto 0;
    signal cry     : integer range 39 downto 0;
    signal counter : unsigned(22 downto 0);  
  begin

    -- slowclk for blink hardware cursor
    counter <= counter + 1 when rising_edge(clk25MHz);
	 slowclk <= counter(22); --2.98Hz

-- sy2002 30/12/15 cursor position fix
--    crx <= TO_INTEGER(unsigned(ocrx(6 downto 0)));
    crx <= TO_INTEGER(unsigned(ocrx(6 downto 0))) + 1 when (TO_INTEGER(unsigned(ocrx)) < 79) else 0;
    cry <= TO_INTEGER(unsigned(ocry(5 downto 0)));

    --
    curpos <= '1' when (scry = cry) and (scrx = crx) else '0';
    small  <= '1' when (chry > 8)                    else '0';
    curen2 <= (slowclk or (not cur_blink)) and cur_en;
    yint   <= '1' when cur_mode = '0'                else small;
    y      <= (yint and curpos and curen2) xor losr_do;
    
  end block;
  
end rtl;
