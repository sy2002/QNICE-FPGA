-- Timer Interrupt Generator (100 kHz internal base clock)
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
use IEEE.MATH_REAL.ALL;
use work.qnice_tools.all;

entity timer is
generic (
   CLK_FREQ       : natural;                             -- system clock in Hertz
   IS_SIMULATION  : boolean := false                     -- is the module running in simulation?
);
port (
   clk            : in std_logic;                        -- system clock
   reset          : in std_logic;                        -- async reset
   
   -- Daisy Chaining: "left/right" comments are meant to describe a situation, where the CPU is the leftmost device
   int_n_out      : out std_logic;                        -- left device's interrupt signal input
   grant_n_in     : in std_logic;                         -- left device's grant signal output
   int_n_in       : in std_logic;                         -- right device's interrupt signal output
   grant_n_out    : out std_logic;                        -- right device's grant signal input
   
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

-- State Machine
type tTimerState is (   s_idle,
                        s_count,
                        s_signal,
                        s_provide_isr,
                        s_reset
                     );
signal   State          : tTimerState;
signal   fsmState_Next  : tTimerState;

-- The Actual Counter
signal   counter_pre    : unsigned(15 downto 0);
signal   counter_cnt    : unsigned(15 downto 0); 

signal   is_counting    : boolean;
signal   has_fired      : boolean;
signal   new_timer_vals : boolean;

-- Registers
signal   reg_pre        : unsigned(15 downto 0);
signal   reg_cnt        : unsigned(15 downto 0);
signal   reg_int        : unsigned(15 downto 0);


-- Internal 100 kHz clock
constant freq_internal        : natural := 100000;       -- internal clock speed
signal   freq_div_sys_target  : natural := natural(ceil(real(CLK_FREQ) / real(freq_internal)));
--signal   CNT_WIDTH            : natural := f_log2(freq_div_sys_target); 
signal   freq_div_cnt         : unsigned(15 downto 0);   -- CNT_WIDTH does not work with Vivado 2019.2

begin

   -- writing anything to any register resets the timer and loads the new value
   new_timer_vals <= true when en = '1' and we = '1' else false;
   
   -- timer is only counting if no register is zero
   is_counting <= true when reg_int /= x"0000" and reg_pre /= x"0000" and reg_cnt /= x"0000" else false;
   
   -- timer has fired   
   has_fired   <= true when counter_cnt = 0 else false;
   
   fsm_advance_state : process(clk, reset)
   begin
      if rising_edge(clk) then
         if reset = '1' or new_timer_vals then
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
            -- If the device "right" of us has fired before us, then the communication
            -- between it and the device "left" of us (e.g. the CPU) needs to finish,
            -- before we can request an interrupt. So: if anything is going on on the
            -- Daisy Chain bus, then we cannot fire or to put it logically equivalent:
            -- only if there is nothing going on (aka '1'), we can fire:           
            if has_fired and int_n_in = '1' and grant_n_in = '1' then
               fsmState_Next <= s_signal;
               int_n_out <= '0';    -- request interrupt
               grant_n_out <= '1';  -- de-couple the right device
            end if;
            
         when s_signal =>
            grant_n_out <= '1'; -- keep the right device de-coupled

            -- if interrupt is granted: put ISR address on the data bus          
            if grant_n_in = '0' then
               fsmState_Next <= s_provide_isr;
               data <= std_logic_vector(reg_int);
               int_n_out <= '1';  -- stop to request interrupt, but keep right device de-coupled
            -- if not yet granted, continue to request interrupt                      
            else
               int_n_out <= '0';  -- continue to request interrupt
            end if;
            
         when s_provide_isr =>
            grant_n_out <= '1'; -- de-couple the right device
            int_n_out <= '1';   -- stop to request interrupt, but keep right device de-coupled
         
            -- keep putting the ISR address on the data bus until the grant is revoked
            if grant_n_in = '0' then            
               fsmState_Next <= s_provide_isr;
               data <= std_logic_vector(reg_int);
            else
               fsmState_Next <= s_reset;
            end if;
            
         when s_reset =>
            -- reset the PRE and CNT counters
            fsmState_Next <= s_idle;
      end case;
   end process;

   -- nested counting loop: "count PRE times to CNT" 
   count : process(clk, reset, State, new_timer_vals, reg, data)
   begin
      -- DATA is often only valid at the falling edge of the system clock
      if falling_edge(clk) then     
         -- system reset: stop everything
         if reset = '1' then
            counter_pre <= (others => '0');
            counter_cnt <= (others => '0');
            freq_div_cnt <= to_unsigned(freq_div_sys_target, 16);
         
         -- new values for the PRE and CNT registers are on the data bus
         elsif new_timer_vals then
            if reg = REGNO_PRE then
               counter_pre <= unsigned(data);               
            elsif reg = REGNO_CNT then
               counter_cnt <= unsigned(data);
            end if;
            freq_div_cnt <= to_unsigned(freq_div_sys_target, 16);
               
         -- timer elapsed and fired and handled the interrupt, now it is time to reset the values
         elsif State = s_reset then
            counter_pre <= reg_pre;
            counter_cnt <= reg_cnt;
            freq_div_cnt <= to_unsigned(freq_div_sys_target, 16);
         
         -- count, but only, if it has not yet fired
         elsif is_counting and not has_fired then
         
            -- create 100 kHz clock from system clock
            if freq_div_cnt = x"0000" or IS_SIMULATION then
               -- prescaler divides the 100 kHz clock by the value stored in the PRE register
               if counter_pre = x"0001" then
                  -- count until zero, then "has_fired" will be true
                  if counter_cnt /= x"0000" then
                     counter_cnt <= counter_cnt - 1;
                  end if;
               else
                  counter_pre <= counter_pre - 1;
               end if;            
            else
               freq_div_cnt <= freq_div_cnt - 1;
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