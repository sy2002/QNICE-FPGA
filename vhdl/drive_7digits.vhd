----------------------------------------------------------------------------------
-- Nexys 4 DDR specific driver of the built-in 7-segment display
--
-- set CLOCK_DIVIDER to 200000 when working with a 100 MHz clock
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.qnice_tools.all;

entity drive_7digits is
generic (
   CLOCK_DIVIDER        : integer                  -- clock divider: clock cycles per digit cycle
);
port (
   clk    : in std_logic;                          -- clock signal divided by above mentioned divider
   
   digits : in std_logic_vector(31 downto 0);      -- the actual information to be shown on the display
   mask   : in std_logic_vector(7 downto 0);       -- control individual digits ('1' = digit is lit)
   
   -- 7 segment display needs multiplexed approach due to common anode
   SSEG_AN     : out std_logic_vector (7 downto 0); -- common anode: selects digit
   SSEG_CA     : out std_logic_vector (7 downto 0) -- cathode: selects segment within a digit   
);
end drive_7digits;

architecture Behavioral of drive_7digits is

-- signals
signal counter_overflow : std_logic;
signal digit : std_logic_vector(2 downto 0) := "000"; -- 7-segment digit to be shown: 0 = rightmost
signal display : std_logic_vector(3 downto 0) := (others => '0'); -- signal to be sent to the cathode to drive the number to be displayed

begin

   -- slow down the master clock signal
   clockdivider : entity work.SyTargetCounter
      generic map (
         COUNTER_WIDTH => f_log2(CLOCK_DIVIDER),
         COUNTER_FINISH => CLOCK_DIVIDER
      )
      port map (
         clk => CLK,
         reset => '0',
         overflow => counter_overflow
      );

   -- counter to iterate through all 8 digits 0..7
   digit_iterator : process (CLK)
   begin
      if rising_edge(CLK) then
         if counter_overflow = '1' then
            digit <= std_logic_vector(unsigned(digit) + 1);
         end if;
      end if;
   end process digit_iterator;
   
   -- cathode signal for current digit
   cathode_control : entity work.nibble_to_cathode
      port map (
         nibble => display,
         cathode => SSEG_CA
      );

   -- iterate through all 8 digits
   multiplex_7_segment_display : process (digit, digits, mask)
   begin
      if digit = "000" and mask(0) = '1' then
         SSEG_AN <= "11111110";
         display <= digits(3 downto 0);
      elsif digit = "001" and mask(1) = '1' then
         SSEG_AN <= "11111101";
         display <= digits(7 downto 4);
      elsif digit = "010" and mask(2) = '1' then
         SSEG_AN <= "11111011";
         display <= digits(11 downto 8);
      elsif digit = "011" and mask(3) = '1' then
         SSEG_AN <= "11110111";
         display <= digits(15 downto 12);    
      elsif digit = "100" and mask(4) = '1' then
         SSEG_AN <= "11101111";
         display <= digits(19 downto 16);
      elsif digit = "101" and mask(5) = '1' then
         SSEG_AN <= "11011111";
         display <= digits(23 downto 20);
      elsif digit = "110" and mask(6) = '1' then
         SSEG_AN <= "10111111";
         display <= digits(27 downto 24);
      elsif digit = "111" and mask(7) = '1' then
         SSEG_AN <= "01111111";
         display <= digits(31 downto 28);
      else
         SSEG_AN <= "11111111";
         display <= "0000";
      end if;
   end process;
   
end Behavioral;
