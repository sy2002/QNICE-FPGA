-- Simulated timer device that generates and handles an interrupt
-- done by sy2002 in July 2020

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dev_int_source is
generic (
   fire_1         : natural;
   fire_2         : natural;
   ISR_ADDR       : natural
);
port (
   CLK            : in std_logic;
   RESET          : in std_logic;
   DATA           : inout std_logic_vector(15 downto 0);   
  
   INT_N          : out std_logic;
   IGRANT_N       : in std_logic   
);
end dev_int_source;

architecture beh of dev_int_source is
                     
type tStates is (s_idle,
                 s_f1_signal,
                 s_f1_provide_isr
                );
                
signal State : tStates := s_idle;
signal fsmNextState : tStates;

signal counter : unsigned(15 downto 0);

begin
   
   fsm_advance_state : process(CLK)
   begin
      if rising_edge(CLK) then
         if RESET = '1' then
            State <= s_idle;
         else
            State <= fsmNextState;
         end if;
      end if;
   end process;
   
   fsm_output_decode : process(State, counter, IGRANT_N)
   begin
      fsmNextState <= State;
      DATA <= (others => 'Z');
      INT_N <= '1';
   
      case State is
         when s_idle =>
            if counter = fire_1 then
               fsmNextState <= s_f1_signal;
               INT_N <= '0';
            else
               fsmNextState <= s_idle;
            end if;
                                    
         when s_f1_signal =>
            if IGRANT_N = '0' then
               fsmNextState <= s_f1_provide_isr;
               DATA <= std_logic_vector(to_unsigned(ISR_ADDR, 16));                      
            else
               INT_N <= '0';         
               fsmNextState <= s_f1_signal;
            end if;
            
         when s_f1_provide_isr =>
            if IGRANT_N = '0' then            
               fsmNextState <= s_f1_provide_isr;
               DATA <= std_logic_vector(to_unsigned(ISR_ADDR, 16));
            else
               fsmNextState <= s_idle;
            end if;            
      end case;
   end process;

   handle_counter : process(CLK, RESET)
   begin
      if RESET = '1' then
         counter <= (others => '0');
      else
         if rising_edge(CLK) then
            if counter < x"FFFF" then
               counter <= counter + 1;
            end if;
         end if;
      end if;
   end process;
   
end beh;
