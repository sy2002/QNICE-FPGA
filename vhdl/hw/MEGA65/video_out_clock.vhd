--------------------------------------------------------------------------------
-- video_out_clock.vhd                                                        --
-- Pixel and serialiser clock synthesiser (dynamically configured MMCM).      --
--------------------------------------------------------------------------------
-- (C) Copyright 2022 Adam Barnes <ambarnes@gmail.com>                        --
-- This file is part of The Tyto Project. The Tyto Project is free software:  --
-- you can redistribute it and/or modify it under the terms of the GNU Lesser --
-- General Public License as published by the Free Software Foundation,       --
-- either version 3 of the License, or (at your option) any later version.    --
-- The Tyto Project is distributed in the hope that it will be useful, but    --
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public     --
-- License for more details. You should have received a copy of the GNU       --
-- Lesser General Public License along with The Tyto Project. If not, see     --
-- https://www.gnu.org/licenses/.                                             --
--------------------------------------------------------------------------------

-- Modified by MFJ in October 2023
-- When programming the MMCM, the "locked" signal is de-asserted and the clock output is
-- invalid and contains glitches. Usually, the system is held in reset until "locked"
-- is asserted again. Instead, we here switch over to a "backup" clock of 50 MHz
-- until the MMCM is ready. This switch-over is done using a glitch-free clock
-- multiplexer, but since the latter is stateful, the switch-over has to be timed
-- carefully, so that the active clock is always valid.

-- To generate the entries in these tables:
-- 1. Download the MMCM and PLL Dynamic Reconfiguration Application Note (XAPP888)
--    reference files.
-- 2. Use the Vivado Clock Wizard to generate the values of CLKFBOUT_MULT_F,
--    DIVCLK_DIVIDE, CLKOUT0_DIVIDE_F, and CLKOUT1_DIVIDE. Note them down on a piece of paper.
-- 3. Start Vivado, and run the xapp888 setup file: MMCME2_DRP/top_mmcme2.tcl
-- 4. Use the spreadsheet https://github.com/amb5l/tyto2/blob/main/src/common/video/xilinx_7series/video_out_clock.xls
--    type in the Clock Wizard values, and generate the tcl command.
-- 5. In Vivado, run the tcl command. This outputs the values for the table below.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library unisim;
  use unisim.vcomponents.all;

entity video_out_clock is
  generic (
    fref    : real                                -- reference clock frequency (MHz) (typically 100.0)
  );
  port (

    rsti    : in    std_logic;                    -- input (reference) clock synchronous reset
    clki    : in    std_logic;                    -- input (reference) clock
    sel     : in    std_logic_vector(2 downto 0); -- output clock select:
          -- 000 =  25.200 MHz. E.g.  640x480 @ 60.00 Hz
          -- 001 =  27.000 MHz. E.g.  720x480 @ 59.94 Hz
          -- 010 =  74.250 MHz. E.g. 1280x720 @ 60.00 Hz
          -- 011 = 148.500 MHz.
          -- 100 =  25.175 MHz. E.g.  640x480 @ 59.94 Hz
          -- 101 =  27.027 MHz. E.g.  720x480 @ 60.00 Hz
          -- 110 =  74.176 MHz. E.g. 1280x720 @ 59.94 Hz
          -- 111 = undefined
    rsto    : out   std_logic;                    -- output clock synchronous reset
    clko    : out   std_logic;                    -- pixel clock
    clko_x5 : out   std_logic                     -- serialiser clock (5x pixel clock)

  );
end entity video_out_clock;

architecture synth of video_out_clock is

  signal sel_s        : std_logic_vector(2 downto 0);  -- sel, synchronised to clki

  signal rsto_req     : std_logic;                     -- rsto request, synchronous to clki

  signal mmcm_rst     : std_logic;                     -- MMCM reset
  signal locked       : std_logic;                     -- MMCM locked output
  signal locked_s     : std_logic;                     -- above, synchronised to clki

  signal sel_prev     : std_logic_vector(3 downto 0);  -- to detect changes
  signal clk_fb       : std_logic;                     -- feedback clock
  signal clku_fb      : std_logic;                     -- unbuffered feedback clock
  signal clko_u       : std_logic;                     -- unbuffered pixel clock
  signal clko_b       : std_logic;                     -- buffered pixel clock
  signal clko_u_x5    : std_logic;                     -- unbuffered serializer clock

  signal clki_div     : std_logic;                     -- Input clock divided by 2

  signal cfg_tbl_addr : std_logic_vector(7 downto 0);  -- 8 x 32 entries
  signal cfg_tbl_data : std_logic_vector(39 downto 0); -- 8 bit address + 16 bit write data + 16 bit read mask

  signal cfg_cnt      : std_logic_vector(1 downto 0);  -- Delay reset
  signal cfg_rst      : std_logic;                     -- DRP reset
  signal cfg_daddr    : std_logic_vector(6 downto 0);  -- DRP register address
  signal cfg_den      : std_logic;                     -- DRP enable (pulse)
  signal cfg_dwe      : std_logic;                     -- DRP write enable
  signal cfg_di       : std_logic_vector(15 downto 0); -- DRP write data
  signal cfg_do       : std_logic_vector(15 downto 0); -- DRP read data
  signal cfg_drdy     : std_logic;                     -- DRP access complete

  type   cfg_state_t is (                              -- state machine states
    idle,                                              -- waiting for fsel change
    reset_wait,                                        -- put MMCM into reset
    reset,                                             -- put MMCM into reset
    tbl,                                               -- get first/next table value
    rd,                                                -- start read
    rd_wait,                                           -- wait for read to complete
    wr,                                                -- start write
    wr_wait,                                           -- wait for write to complete
    lock_wait                                          -- wait for reconfig to complete
  );
  signal cfg_state    : cfg_state_t;
  signal clk_mux      : std_logic;


begin

  MAIN: process (clki) is

    -- Contents of synchronous ROM table.
    -- See MMCM and PLL Dynamic Reconfiguration Application Note (XAPP888)
    -- for details of register map.
    function cfg_tbl (addr : std_logic_vector) return std_logic_vector is
      -- bits 39..32 = cfg_daddr (MSB = 1 for last entry)
      -- bits 31..16 = cfg write data
      -- bits 15..0 = cfg read mask
      variable data : std_logic_vector(39 downto 0);
    begin
      data := x"0000000000";
      -- values below pasted in from video_out_clk.xls
      if fref = 100.0 then
        case addr is
          -- Desired frequency = 25.200 MHz
          -- CLKFBOUT_MULT_F   = 31.500
          -- DIVCLK_DIVIDE     = 5
          -- CLKOUT0_DIVIDE_F  = 5.000
          -- CLKOUT1_DIVIDE    = 25
          -- Actual frequency  = 25.200 MHz
          when x"00" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"01" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"02" => data := x"08" & x"1083" & x"1000";  -- CLKOUT0 Register 1
          when x"03" => data := x"09" & x"0080" & x"8000";  -- CLKOUT0 Register 2
          when x"04" => data := x"0A" & x"130d" & x"1000";  -- CLKOUT1 Register 1
          when x"05" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"06" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"07" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"08" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"09" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"0A" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"0B" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"0C" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"0D" => data := x"13" & x"3000" & x"8000";  -- CLKOUT6 Register 2
          when x"0E" => data := x"14" & x"13CF" & x"1000";  -- CLKFBOUT Register 1
          when x"0F" => data := x"15" & x"4800" & x"8000";  -- CLKFBOUT Register 2
          when x"10" => data := x"16" & x"0083" & x"C000";  -- DIVCLK Register
          when x"11" => data := x"18" & x"002C" & x"FC00";  -- Lock Register 1
          when x"12" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"13" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"14" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"15" => data := x"4E" & x"0900" & x"66FF";  -- Filter Register 1
          when x"16" => data := x"CF" & x"1000" & x"666F";  -- Filter Register 2

          -- Desired frequency = 27.000 MHz
          -- CLKFBOUT_MULT_F   = 47.250
          -- DIVCLK_DIVIDE     = 5
          -- CLKOUT0_DIVIDE_F  = 7.000
          -- CLKOUT1_DIVIDE    = 35
          -- Actual frequency  = 74.250 MHz
          when x"20" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"21" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"22" => data := x"08" & x"10C4" & x"1000";  -- CLKOUT0 Register 1
          when x"23" => data := x"09" & x"0080" & x"8000";  -- CLKOUT0 Register 2
          when x"24" => data := x"0A" & x"1452" & x"1000";  -- CLKOUT1 Register 1
          when x"25" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"26" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"27" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"28" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"29" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"2A" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"2B" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"2C" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"2D" => data := x"13" & x"2800" & x"8000";  -- CLKOUT6 Register 2
          when x"2E" => data := x"14" & x"15D7" & x"1000";  -- CLKFBOUT Register 1
          when x"2F" => data := x"15" & x"2800" & x"8000";  -- CLKFBOUT Register 2
          when x"30" => data := x"16" & x"0083" & x"C000";  -- DIVCLK Register
          when x"31" => data := x"18" & x"00FA" & x"FC00";  -- Lock Register 1
          when x"32" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"33" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"34" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"35" => data := x"4E" & x"1900" & x"66FF";  -- Filter Register 1
          when x"36" => data := x"CF" & x"0100" & x"666F";  -- Filter Register 2

          -- Desired frequency = 74.250 MHz
          -- CLKFBOUT_MULT_F   = 37.125
          -- DIVCLK_DIVIDE     = 5
          -- CLKOUT0_DIVIDE_F  = 2.000
          -- CLKOUT1_DIVIDE    = 10
          -- Actual frequency  = 74.250 MHz
          when x"40" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"41" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"42" => data := x"08" & x"1041" & x"1000";  -- CLKOUT0 Register 1
          when x"43" => data := x"09" & x"0000" & x"8000";  -- CLKOUT0 Register 2
          when x"44" => data := x"0A" & x"1145" & x"1000";  -- CLKOUT1 Register 1
          when x"45" => data := x"0B" & x"0000" & x"8000";  -- CLKOUT1 Register 2
          when x"46" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"47" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"48" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"49" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"4A" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"4B" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"4C" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"4D" => data := x"13" & x"2400" & x"8000";  -- CLKOUT6 Register 2
          when x"4E" => data := x"14" & x"1491" & x"1000";  -- CLKFBOUT Register 1
          when x"4F" => data := x"15" & x"1800" & x"8000";  -- CLKFBOUT Register 2
          when x"50" => data := x"16" & x"0083" & x"C000";  -- DIVCLK Register
          when x"51" => data := x"18" & x"00FA" & x"FC00";  -- Lock Register 1
          when x"52" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"53" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"54" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"55" => data := x"4E" & x"0900" & x"66FF";  -- Filter Register 1
          when x"56" => data := x"CF" & x"1000" & x"666F";  -- Filter Register 2

          -- Desired frequency = 148.500 MHz
          -- CLKFBOUT_MULT_F   = 37.125
          -- DIVCLK_DIVIDE     = 5
          -- CLKOUT0_DIVIDE_F  = 1.000
          -- CLKOUT1_DIVIDE    = 5
          -- Actual frequency  = 148.500 MHz
          when x"60" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"61" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"62" => data := x"08" & x"1041" & x"1000";  -- CLKOUT0 Register 1
          when x"63" => data := x"09" & x"00C0" & x"8000";  -- CLKOUT0 Register 2
          when x"64" => data := x"0A" & x"1083" & x"1000";  -- CLKOUT1 Register 1
          when x"65" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"66" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"67" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"68" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"69" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"6A" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"6B" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"6C" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"6D" => data := x"13" & x"2400" & x"8000";  -- CLKOUT6 Register 2
          when x"6E" => data := x"14" & x"1491" & x"1000";  -- CLKFBOUT Register 1
          when x"6F" => data := x"15" & x"1800" & x"8000";  -- CLKFBOUT Register 2
          when x"70" => data := x"16" & x"0083" & x"C000";  -- DIVCLK Register
          when x"71" => data := x"18" & x"00FA" & x"FC00";  -- Lock Register 1
          when x"72" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"73" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"74" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"75" => data := x"4E" & x"0900" & x"66FF";  -- Filter Register 1
          when x"76" => data := x"CF" & x"1000" & x"666F";  -- Filter Register 2

          -- Desired frequency = 25.175 MHz
          -- CLKFBOUT_MULT_F   = 17.625
          -- DIVCLK_DIVIDE     = 2
          -- CLKOUT0_DIVIDE_F  = 7.000
          -- CLKOUT1_DIVIDE    = 35
          -- Actual frequency  = 25.179 MHz
          when x"80" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"81" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"82" => data := x"08" & x"10C4" & x"1000";  -- CLKOUT0 Register 1
          when x"83" => data := x"09" & x"00C0" & x"8000";  -- CLKOUT0 Register 2
          when x"84" => data := x"0A" & x"1452" & x"1000";  -- CLKOUT1 Register 1
          when x"85" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"86" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"87" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"88" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"89" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"8A" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"8B" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"8C" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"8D" => data := x"13" & x"3000" & x"8000";  -- CLKOUT6 Register 2
          when x"8E" => data := x"14" & x"1208" & x"1000";  -- CLKFBOUT Register 1
          when x"8F" => data := x"15" & x"5800" & x"8000";  -- CLKFBOUT Register 2
          when x"90" => data := x"16" & x"0041" & x"C000";  -- DIVCLK Register
          when x"91" => data := x"18" & x"013F" & x"FC00";  -- Lock Register 1
          when x"92" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"93" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"94" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"95" => data := x"4E" & x"9900" & x"66FF";  -- Filter Register 1
          when x"96" => data := x"CF" & x"1100" & x"666F";  -- Filter Register 2

          -- Desired frequency = 27.027 MHz
          -- CLKFBOUT_MULT_F   = 21.625
          -- DIVCLK_DIVIDE     = 2
          -- CLKOUT0_DIVIDE_F  = 8.000
          -- CLKOUT1_DIVIDE    = 40
          -- Actual frequency  = 27.031 MHz
          when x"A0" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"A1" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"A2" => data := x"08" & x"1104" & x"1000";  -- CLKOUT0 Register 1
          when x"A3" => data := x"09" & x"00C0" & x"8000";  -- CLKOUT0 Register 2
          when x"A4" => data := x"0A" & x"1514" & x"1000";  -- CLKOUT1 Register 1
          when x"A5" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"A6" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"A7" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"A8" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"A9" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"AA" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"AB" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"AC" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"AD" => data := x"13" & x"3000" & x"8000";  -- CLKOUT6 Register 2
          when x"AE" => data := x"14" & x"128A" & x"1000";  -- CLKFBOUT Register 1
          when x"AF" => data := x"15" & x"5800" & x"8000";  -- CLKFBOUT Register 2
          when x"B0" => data := x"16" & x"0041" & x"C000";  -- DIVCLK Register
          when x"B1" => data := x"18" & x"00DB" & x"FC00";  -- Lock Register 1
          when x"B2" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"B3" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"B4" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"B5" => data := x"4E" & x"9000" & x"66FF";  -- Filter Register 1
          when x"B6" => data := x"CF" & x"0100" & x"666F";  -- Filter Register 2

          -- Desired frequency = 74.176 MHz
          -- CLKFBOUT_MULT_F   = 22.250
          -- DIVCLK_DIVIDE     = 3
          -- CLKOUT0_DIVIDE_F  = 2.000
          -- CLKOUT1_DIVIDE    = 10
          -- Actual frequency  = 74.167 MHz
          when x"C0" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"C1" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"C2" => data := x"08" & x"1041" & x"1000";  -- CLKOUT0 Register 1
          when x"C3" => data := x"09" & x"00C0" & x"8000";  -- CLKOUT0 Register 2
          when x"C4" => data := x"0A" & x"1145" & x"1000";  -- CLKOUT1 Register 1
          when x"C5" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"C6" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"C7" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"C8" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"C9" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"CA" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"CB" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"CC" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"CD" => data := x"13" & x"0C00" & x"8000";  -- CLKOUT6 Register 2
          when x"CE" => data := x"14" & x"128A" & x"1000";  -- CLKFBOUT Register 1
          when x"CF" => data := x"15" & x"2C00" & x"8000";  -- CLKFBOUT Register 2
          when x"D0" => data := x"16" & x"0042" & x"C000";  -- DIVCLK Register
          when x"D1" => data := x"18" & x"00C2" & x"FC00";  -- Lock Register 1
          when x"D2" => data := x"19" & x"7C01" & x"8000";  -- Lock Register 2
          when x"D3" => data := x"1A" & x"7DE9" & x"8000";  -- Lock Register 3
          when x"D4" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"D5" => data := x"4E" & x"1100" & x"66FF";  -- Filter Register 1
          when x"D6" => data := x"CF" & x"9000" & x"666F";  -- Filter Register 2

          -- Desired frequency = 40.000 MHz
          -- CLKFBOUT_MULT_F   = 10
          -- DIVCLK_DIVIDE     = 1
          -- CLKOUT0_DIVIDE_F  = 5.000
          -- CLKOUT1_DIVIDE    = 25
          -- Actual frequency  = 40.000 MHz
          when x"E0" => data := x"06" & x"1145" & x"1000";  -- CLKOUT5 Register 1
          when x"E1" => data := x"07" & x"0000" & x"8000";  -- CLKOUT5 Register 2
          when x"E2" => data := x"08" & x"1083" & x"1000";  -- CLKOUT0 Register 1
          when x"E3" => data := x"09" & x"0080" & x"8000";  -- CLKOUT0 Register 2
          when x"E4" => data := x"0A" & x"130D" & x"1000";  -- CLKOUT1 Register 1
          when x"E5" => data := x"0B" & x"0080" & x"8000";  -- CLKOUT1 Register 2
          when x"E6" => data := x"0C" & x"1145" & x"1000";  -- CLKOUT2 Register 1
          when x"E7" => data := x"0D" & x"0000" & x"8000";  -- CLKOUT2 Register 2
          when x"E8" => data := x"0E" & x"1145" & x"1000";  -- CLKOUT3 Register 1
          when x"E9" => data := x"0F" & x"0000" & x"8000";  -- CLKOUT3 Register 2
          when x"EA" => data := x"10" & x"1145" & x"1000";  -- CLKOUT4 Register 1
          when x"EB" => data := x"11" & x"0000" & x"8000";  -- CLKOUT4 Register 2
          when x"EC" => data := x"12" & x"1145" & x"1000";  -- CLKOUT6 Register 1
          when x"ED" => data := x"13" & x"0000" & x"8000";  -- CLKOUT6 Register 2
          when x"EE" => data := x"14" & x"1145" & x"1000";  -- CLKFBOUT Register 1
          when x"EF" => data := x"15" & x"0000" & x"8000";  -- CLKFBOUT Register 2
          when x"F0" => data := x"16" & x"1041" & x"C000";  -- DIVCLK Register
          when x"F1" => data := x"18" & x"01E8" & x"FC00";  -- Lock Register 1
          when x"F2" => data := x"19" & x"7001" & x"8000";  -- Lock Register 2
          when x"F3" => data := x"1A" & x"71E9" & x"8000";  -- Lock Register 3
          when x"F4" => data := x"28" & x"FFFF" & x"0000";  -- Power Register
          when x"F5" => data := x"4E" & x"9900" & x"66FF";  -- Filter Register 1
          when x"F6" => data := x"CF" & x"1100" & x"666F";  -- Filter Register 2

          when others => data := (others => '0');
        end case;
      end if;
      return data;
    end function cfg_tbl;

  begin
    if rising_edge(clki) then

      cfg_tbl_data <= cfg_tbl(cfg_tbl_addr);               -- synchronous ROM

      -- defaults
      cfg_den <= '0';
      cfg_dwe <= '0';

      -- state machine
      case cfg_state is
        when IDLE =>
          if '0' & sel /= sel_prev                         -- frequency selection has changed (or initial startup)
             or locked_s = '0'                             -- lock lost
             then
            clk_mux   <= '0';                              -- Switch to alternate clock
            cfg_cnt   <= "11";
            cfg_state <= RESET_WAIT;
          end if;
        when RESET_WAIT =>                                 -- Wait for clock switching to take effect
          if cfg_cnt /= "00" then
            cfg_cnt <= std_logic_vector(unsigned(cfg_cnt) - 1);
          else
            rsto_req  <= '1';
            cfg_rst   <= '1';
            cfg_state <= RESET;
          end if;
        when RESET =>                                      -- put MMCM into reset
          sel_prev     <= '0' & sel;
          cfg_tbl_addr <= sel & "00000";
          cfg_state    <= TBL;
        when TBL =>                                        -- get table entry from sychronous ROM
          cfg_state <= RD;
        when RD =>                                         -- read specified register
          cfg_daddr <= cfg_tbl_data(38 downto 32);
          cfg_den   <= '1';
          cfg_state <= RD_WAIT;
        when RD_WAIT =>                                    -- wait for read to complete
          if cfg_drdy = '1' then
            cfg_di    <= (cfg_do and cfg_tbl_data(15 downto 0)) or (cfg_tbl_data(31 downto 16) and not cfg_tbl_data(15 downto 0));
            cfg_den   <= '1';
            cfg_dwe   <= '1';
            cfg_state <= WR;
          end if;
        when WR =>                                         -- write modified contents back to same register
          cfg_state <= WR_WAIT;
        when WR_WAIT =>                                    -- wait for write to complete
          if cfg_drdy = '1' then
            if cfg_tbl_data(39) = '1' then                 -- last entry in table
              cfg_tbl_addr <= (others => '0');
              cfg_state    <= LOCK_WAIT;
            else                                           -- do next entry in table
              cfg_tbl_addr(4 downto 0) <= std_logic_vector(unsigned(cfg_tbl_addr(4 downto 0)) + 1);
              cfg_state                <= TBL;
            end if;
          end if;
        when LOCK_WAIT =>                                  -- wait for MMCM to lock
          cfg_rst <= '0';
          if locked_s = '1' then                           -- all done
            cfg_state <= IDLE;
            rsto_req  <= '0';
            clk_mux   <= '1';                              -- Switch to new clock
          end if;
      end case;

      if rsti = '1' then                                   -- full reset

        sel_prev  <= (others => '1');                      -- force reconfig
        cfg_rst   <= '1';
        cfg_daddr <= (others => '0');
        cfg_den   <= '0';
        cfg_dwe   <= '0';
        cfg_di    <= (others => '0');
        cfg_state <= RESET;

        rsto_req <= '1';

      end if;

    end if;
  end process MAIN;

  -- clock domain crossing

  SYNC1 : entity work.cdc_stable
    generic map (
      G_DATA_SIZE => 4
    )
    port map (
      dst_clk_i     => clki,
      src_data_i(0) => locked,
      src_data_i(1) => sel(0),
      src_data_i(2) => sel(1),
      src_data_i(3) => sel(2),
      dst_data_o(0) => locked_s,
      dst_data_o(1) => sel_s(0),
      dst_data_o(2) => sel_s(1),
      dst_data_o(3) => sel_s(2)
    );

  SYNC2 : entity work.cdc_stable
    generic map (
      G_DATA_SIZE => 1
    )
    port map (
      dst_clk_i     => clko_b,
      src_data_i(0) => rsto_req or not locked or mmcm_rst,
      dst_data_o(0) => rsto
    );

  mmcm_rst <= cfg_rst or rsti;

  -- For Static Timing Analysis it is necessary
  -- that the default configuration corresponds to the fastest clock speed.
  MMCM: component mmcme2_adv
    generic map (
      bandwidth            => "OPTIMIZED",
      clkfbout_mult_f      => 37.125, -- f_VCO = (100 MHz / 5) x 37.125 = 742.5 MHz
      clkfbout_phase       => 0.0,
      clkfbout_use_fine_ps => false,
      clkin1_period        => 10.0,   -- INPUT @ 100 MHz
      clkin2_period        => 0.0,
      clkout0_divide_f     => 2.0,    -- TMDS @ 371.25 MHz
      clkout0_duty_cycle   => 0.5,
      clkout0_phase        => 0.0,
      clkout0_use_fine_ps  => false,
      clkout1_divide       => 10,     -- HDMI @ 74.25 MHz
      clkout1_duty_cycle   => 0.5,
      clkout1_phase        => 0.0,
      clkout1_use_fine_ps  => false,
      clkout2_divide       => 1,
      clkout2_duty_cycle   => 0.5,
      clkout2_phase        => 0.0,
      clkout2_use_fine_ps  => false,
      clkout3_divide       => 1,
      clkout3_duty_cycle   => 0.5,
      clkout3_phase        => 0.0,
      clkout3_use_fine_ps  => false,
      clkout4_cascade      => false,
      clkout4_divide       => 1,
      clkout4_duty_cycle   => 0.5,
      clkout4_phase        => 0.0,
      clkout4_use_fine_ps  => false,
      clkout5_divide       => 1,
      clkout5_duty_cycle   => 0.5,
      clkout5_phase        => 0.0,
      clkout5_use_fine_ps  => false,
      clkout6_divide       => 1,
      clkout6_duty_cycle   => 0.5,
      clkout6_phase        => 0.0,
      clkout6_use_fine_ps  => false,
      compensation         => "ZHOLD",
      divclk_divide        => 5,
      is_clkinsel_inverted => '0',
      is_psen_inverted     => '0',
      is_psincdec_inverted => '0',
      is_pwrdwn_inverted   => '0',
      is_rst_inverted      => '0',
      ref_jitter1          => 0.01,
      ref_jitter2          => 0.01,
      ss_en                => "FALSE",
      ss_mode              => "CENTER_HIGH",
      ss_mod_period        => 10000,
      startup_wait         => false
    )
    port map (
      pwrdwn               => '0',
      rst                  => mmcm_rst,
      locked               => locked,
      clkin1               => clki,
      clkin2               => '0',
      clkinsel             => '1',
      clkinstopped         => open,
      clkfbin              => clk_fb,
      clkfbout             => clku_fb,
      clkfboutb            => open,
      clkfbstopped         => open,
      clkout0              => clko_u_x5,
      clkout0b             => open,
      clkout1              => clko_u,
      clkout1b             => open,
      clkout2              => open,
      clkout2b             => open,
      clkout3              => open,
      clkout3b             => open,
      clkout4              => open,
      clkout5              => open,
      clkout6              => open,
      dclk                 => clki,
      daddr                => cfg_daddr,
      den                  => cfg_den,
      dwe                  => cfg_dwe,
      di                   => cfg_di,
      do                   => cfg_do,
      drdy                 => cfg_drdy,
      psclk                => '0',
      psdone               => open,
      psen                 => '0',
      psincdec             => '0'
    );

  U_BUFG_0: component bufg
    port map (
      i => clko_u_x5,
      o => clko_x5
    );

  p_clki_div : process (clki)
  begin
     if rising_edge(clki) then
        clki_div <= not clki_div;
     end if;
  end process p_clki_div;

  -- Force clock to '0' when MMCM is not locked. This avoids
  -- any glitches during reconfiguration
  U_BUFG_1: component bufgmux_ctrl
    port map (
      s  => clk_mux,
      i0 => clki_div,
      i1 => clko_u,
      o  => clko_b
    );

  U_BUFG_F: component bufg
    port map (
      i => clku_fb,
      o => clk_fb
    );

  clko <= clko_b;

end architecture synth;

