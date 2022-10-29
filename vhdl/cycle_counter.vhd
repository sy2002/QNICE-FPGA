-- 48-bit clock cycle counter
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- output goes zero when not enabled
-- done by sy2002 in May 2016 and refactored in July 2020 and in October 2022

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cycle_counter is
port (
   clk      : in std_logic;         -- system clock
   impulse  : in std_logic;         -- impulse that is counted
   reset    : in std_logic;         -- async reset
   
   -- cycle counter's registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to the registers via system's data bus
   reg      : in std_logic_vector(1 downto 0);     -- register selector
   data_in  : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out : out std_logic_vector(15 downto 0)    -- system's data bus
);
end cycle_counter;

architecture beh of cycle_counter is

signal counter                : unsigned(47 downto 0) := (others => '0');
signal cycle_is_counting      : std_logic;

begin

   count : process(clk)
   begin
      if falling_edge(clk) then
         if reset = '1' or (en = '1' and we='1' and reg="11" and data_in(0) = '1') then
            counter <= (others => '0');
         else
            if impulse = '1' and cycle_is_counting = '1' then
               counter <= counter + 1;
            end if;         
         end if;
      end if;
   end process;
        
   write_register : process(clk)
   begin
      if falling_edge(clk) then
         if reset = '1' then
            cycle_is_counting <= '1';
         else
            if en = '1' and we = '1' and reg = "11" then
               cycle_is_counting <= data_in(0) or data_in(1);
            end if;
         end if;
      end if;
   end process;
      
   read_registers : process(en, we, reg, counter, cycle_is_counting)
   begin
      data_out <= (others => '0');
      if en = '1' and we = '0' then
         case reg is
            when "00" => data_out <= std_logic_vector(counter(15 downto 0));
            when "01" => data_out <= std_logic_vector(counter(31 downto 16));
            when "10" => data_out <= std_logic_vector(counter(47 downto 32));
            when "11" => data_out <= "00000000000000" & cycle_is_counting & '0';
         end case;
      end if;
   end process;
   
end beh;
