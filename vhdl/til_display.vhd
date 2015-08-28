-- TIL display emulator that uses a 7-segment display
-- assumes an 100 MHz system clock (CLOCK_DIVIDER = 200000 for 2ms refresh rate)
-- done by sy2002 in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity til_display is
port (
   clk               : in std_logic;
   reset             : in std_logic;
   
   til_reg0_enable   : in std_logic;      -- data register
   til_reg1_enable   : in std_logic;      -- mask register (each bit equals one digit)
   
   data_in           : in std_logic_vector(15 downto 0);
   
   -- 7 segment display needs multiplexed approach due to common anode
   SSEG_AN           : out std_logic_vector(7 downto 0); -- common anode: selects digit
   SSEG_CA           : out std_logic_vector(7 downto 0) -- cathode: selects segment within a digit 
);
end til_display;

architecture beh of til_display is

-- Nexys 4 DDR specific 7 segment display driver
component drive_7digits
generic (
   CLOCK_DIVIDER        : integer                  -- clock divider: clock cycles per digit cycle
);
port (
   clk    : in std_logic;                          -- clock signal divided by above mentioned divider
   
   digits : in std_logic_vector(31 downto 0);      -- the actual information to be shown on the display
   mask   : in std_logic_vector(7 downto 0);       -- control individual digits ('1' = digit is lit)  
   
   -- 7 segment display needs multiplexed approach due to common anode
   SSEG_AN     : out std_logic_vector(7 downto 0); -- common anode: selects digit
   SSEG_CA     : out std_logic_vector(7 downto 0) -- cathode: selects segment within a digit 
);
end component;

-- TIL display control signals
signal TIL_311_buffer         : std_logic_vector(15 downto 0) := x"0000";
signal TIL_311_mask           : std_logic_vector(3 downto 0)  := "1111";

begin

   -- 7 segment display: Nexys 4 DDR specific component
   disp_7seg : drive_7digits
      generic map
      (
         CLOCK_DIVIDER => 200000 -- 200.000 clock cycles @ 100 MHz = 2ms per digit
      )
      port map
      (
         clk => clk,
         digits => x"0000" & TIL_311_buffer,
         mask => "0000" & TIL_311_mask,
         SSEG_AN => SSEG_AN,
         SSEG_CA => SSEG_CA
      );

   -- clock-in the current to-be-displayed value and mask into a FF for the TIL
   til_driver : process(clk, reset)
   begin
      if reset = '1' then
         TIL_311_buffer <= x"0000";
         TIL_311_mask <= "1111";
      else
         if falling_edge(clk) then
            if til_reg0_enable = '1' then
               TIL_311_buffer <= data_in;            
            end if;
            
            if til_reg1_enable = '1' then
               TIL_311_mask <= data_in(3 downto 0);
            end if;
         end if;
      end if;
   end process;
 
end beh;

