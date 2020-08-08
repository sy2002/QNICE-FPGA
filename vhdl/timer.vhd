-- Timer Interrupt Generator
--
-- can be Daisy Chained
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- and meant to be connected with other interrupt capable devices via a Daisy Chain
--
-- tristate outputs go high impedance when not enabled
-- 
-- Registers:
--
--  0 = PRE: The 100 kHz timer clock is divided by the value stored in
--           this device register. 100 (which corresponds to 0x0064 in
--           the prescaler register) yields a 1 millisecond pulse which
--           in turn is fed to the actual counter.
--  1 = CNT: When the number of output pulses from the prescaler circuit 
--           equals the number stored in this register, an interrupt will
--           be generated (if the interrupt address is 0x0000, the
--           interrupt will be suppressed).
--  2 = INT: This register contains the address of the desired interrupt 
--           service routine. When 0, then the timer stops counting,
--           when being written then the timer is reset and starts counting
--
-- done by sy2002 in August 2020

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity timer is
port (
   clk            : in std_logic;                        -- system clock
   clk_100kHz     : in std_logic;                        -- 100 kHz timer clock
   reset          : in std_logic;                        -- async reset
   
   -- Daisy Chaining: "left/right" comments are meant to describe a situation, where the CPU is the leftmost device
   int_n_out     : out std_logic;                        -- left device's interrupt signal input
   grant_n_in    : in std_logic;                         -- left device's grant signal output
   int_n_in      : in std_logic;                         -- right device's interrupt signal output
   grant_n_out   : out std_logic;                        -- right device's grant signal input
   
   -- Registers
   en             : in std_logic;                        -- enable for reading from or writing to the bus
   we             : in std_logic;                        -- write to the registers via system's data bus
   reg            : in std_logic_vector(1 downto 0);     -- register selector
   data           : inout std_logic_vector(15 downto 0)  -- system's data bus
);
end timer;

architecture beh of timer is

constant REGNO_PRE      : std_logic_vector(1 downto 0) := "00";
constant REGNO_CNT      : std_logic_vector(1 downto 0) := "01";
constant REGNO_INT      : std_logic_vector(1 downto 0) := "10";

type tTimerState is (   s_idle,
                        s_count,
                        s_signal,
                        s_provide_isr,
                        s_reset
                     );
signal   State          : tTimerState;
signal   fsmState_Next  : tTimerState;

signal   counter_pre    : unsigned(15 downto 0);
signal   counter_cnt    : unsigned(15 downto 0); 

-- registers
signal   reg_pre        : unsigned(15 downto 0);
signal   reg_cnt        : unsigned(15 downto 0);
signal   reg_int        : unsigned(15 downto 0);

signal   is_counting    : boolean;
signal   has_fired      : boolean;
signal   reset_timer    : boolean;

begin

   reset_timer <= true when en = '1' and we = '1' and reg = REGNO_INT and data = x"0000" else false;
   is_counting <= true when reg_int /= x"0000" else false;
   has_fired   <= true when counter_pre = reg_pre else false;
   
   fsm_advance_state : process(clk, reset)
   begin
      if rising_edge(clk) then
         if reset = '1' or reset_timer then
            State <= s_idle;
         else
            State <= fsmState_Next;
         end if;
      end if;
   end process;
   
   fsm_output_decode : process(State, is_counting, has_fired, grant_n_in, int_n_in, reg_int)
   begin
      int_n_out <= int_n_in;
      grant_n_out <= grant_n_in;
      fsmState_Next <= State;
      data <= (others => 'Z');
   
      case State is
         when s_idle =>
            if is_counting then
               fsmState_Next <= s_count;
            end if;
            
         when s_count =>
            if has_fired then
               fsmState_Next <= s_signal;
               int_n_out <= '0';    -- request interrupt
               grant_n_out <= '1'; -- de-couple the right device
            end if;
            
         when s_signal =>
            grant_n_out <= '1'; -- de-couple the right device

            -- if interrupt is granted: put ISR address on the data bus          
            if grant_n_in = '0' then
               fsmState_Next <= s_provide_isr;
               data <= std_logic_vector(reg_int);
            -- if not yet granted, continue to request interrupt                      
            else
               int_n_out <= '0';  
            end if;
            
         when s_provide_isr =>
            grant_n_out <= '1'; -- de-couple the right device
         
            -- keep putting the ISR address on the data bus until the grant is revoked
            if grant_n_in = '0' then            
               fsmState_Next <= s_provide_isr;
               data <= std_logic_vector(reg_int);
            else
               fsmState_Next <= s_reset;
            end if;
            
         when s_reset =>
            fsmState_Next <= s_idle;                                    
      end case;
   end process;

   -- nested counting loop: "count PRE times to CNT" 
   count : process(clk_100kHz, reset, State, reset_timer)
   begin
      -- writing a 0 to the INT register resets and stops the counter         
      if reset = '1' or State = s_reset or reset_timer then
         counter_pre <= (others => '0');
         counter_cnt <= (others => '0');
      else
         if rising_edge(clk_100kHz) then
            if is_counting then
               if counter_cnt < reg_cnt and not has_fired then
                  counter_cnt <= counter_cnt + 1;
               else
                  counter_cnt <= (others => '0');               
                  if counter_pre < reg_pre then
                     counter_pre <= counter_pre + 1;          
                  end if;
               end if;
            end if;            
         end if;
      end if;
   end process;

   -- MMIO: read/write registers: PRE, CNT, INT
   handle_registers : process(clk, reset, en, we, reg, reg_pre, reg_cnt, reg_int)
   begin
      if reset = '1' then
         reg_pre <= (others => '0');
         reg_cnt <= (others => '0');
         reg_int <= (others => '0');
      else
         -- write registers
         if rising_edge(clk) then
            if en = '1' and we = '1' then
               case reg is
                  when REGNO_PRE => reg_pre <= unsigned(data);
                  when REGNO_CNT => reg_cnt <= unsigned(data);       
                  when REGNO_INT => reg_int <= unsigned(data);
                  when others => null;
               end case;
            end if;            
         end if;         
      end if;
            
      -- read registers
      if en = '1' and we = '0' then
         case reg is
            when REGNO_PRE => data <= std_logic_vector(reg_pre);
            when REGNO_CNT => data <= std_logic_vector(reg_cnt);
            when REGNO_INT => data <= std_logic_vector(reg_int);
            when others => data <= (others => '0');
         end case;
      else
         data <= (others => 'Z');
      end if;      
   end process;   
end beh;