-- Timer Interrupt Generator (100 kHz internal base clock)
--
-- can be Daisy Chained
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- and meant to be connected with other interrupt capable devices via a Daisy Chain
--
--  output goes zero when not enabled
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
   data_in        : in std_logic_vector(15 downto 0);    -- system's data bus
   data_out       : out std_logic_vector(15 downto 0)    -- system's data bus
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
signal   State             : tTimerState;
signal   fsmState_Next     : tTimerState;

-- For avoiding a Combinatorial Loop, we are latching the interrupt grant for the "right" device
signal   grant_n_reg       : std_logic;
signal   fsm_grant_n_reg   : std_logic;

-- The Actual Counter
signal   counter_pre       : unsigned(15 downto 0);
signal   counter_cnt       : unsigned(15 downto 0); 

signal   is_counting       : boolean;
signal   has_fired         : boolean;
signal   new_timer_vals    : boolean;

-- Registers
signal   reg_pre           : unsigned(15 downto 0);
signal   reg_cnt           : unsigned(15 downto 0);
signal   reg_int           : unsigned(15 downto 0);

-- Internal 100 kHz clock
constant FREQ_INTERNAL        : natural := 100000;       -- internal clock speed
constant FREQ_DIV_SYS_TARGET  : natural := natural(ceil(real(CLK_FREQ) / real(FREQ_INTERNAL)));
constant CNT_WIDTH            : natural := f_log2(FREQ_DIV_SYS_TARGET);
signal   freq_div_cnt         : unsigned(CNT_WIDTH-1 downto 0);

begin

   grant_n_out <= grant_n_reg;

   -- writing anything to any register resets the timer and loads the new value
   new_timer_vals <= true when en = '1' and we = '1' else false;
   
   -- timer is only counting if no register is zero
   is_counting <= true when reg_int /= x"0000" and reg_pre /= x"0000" and reg_cnt /= x"0000" else false;
      
   fsm_advance_state : process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' or new_timer_vals then
            State <= s_idle;
            grant_n_reg <= '1';
         else
            State <= fsmState_Next;
            grant_n_reg <= fsm_grant_n_reg;
         end if;
      end if;
   end process;
   
   fsm_output_decode : process(State, is_counting, has_fired, grant_n_in, int_n_in, reg_int,
                               en, we, reg, reg_pre, reg_cnt, reg_int)
   begin
      int_n_out <= int_n_in;
      fsm_grant_n_reg <= grant_n_in; -- connect the outgoing "right" grant with the incoming "left" grant 
      fsmState_Next <= State;
      data_out <= (others => '0');

      -- read registers
      if en = '1' and we = '0' then
         case reg is
            when REGNO_PRE => data_out <= std_logic_vector(reg_pre);
            when REGNO_CNT => data_out <= std_logic_vector(reg_cnt);
            when REGNO_INT => data_out <= std_logic_vector(reg_int);
            when others => data_out <= (others => '0');
         end case;
      end if;
         
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
               int_n_out <= '0';          -- request interrupt
               fsm_grant_n_reg  <= '1';   -- de-couple the right device
            end if;
            
         when s_signal =>
            fsm_grant_n_reg <= '1'; -- keep the right device de-coupled
            int_n_out <= '0';       -- request interrupt

            -- if interrupt is granted: put ISR address on the data bus          
            if grant_n_in = '0' then
               fsmState_Next <= s_provide_isr;
               data_out <= std_logic_vector(reg_int);
            end if;
            
         when s_provide_isr =>
            fsm_grant_n_reg <= '1'; -- keep the right device de-coupled
            int_n_out <= '1';       -- stop to request interrupt
                                       
            -- keep putting the ISR address on the data bus until the grant is revoked
            if grant_n_in = '0' then            
               fsmState_Next <= s_provide_isr;
               data_out <= std_logic_vector(reg_int);
            else
               fsmState_Next <= s_reset;
            end if;
            
         when s_reset =>
            -- reset the PRE and CNT counters
            fsmState_Next <= s_idle;
      end case;
   end process;

   -- nested counting loop: "count PRE times to CNT" 
   count : process(clk)
   begin
      -- DATA is often only valid at the falling edge of the system clock
      if falling_edge(clk) then     
         -- system reset: stop everything
         if reset = '1' then
            has_fired <= false;
            counter_pre <= (others => '0');
            counter_cnt <= (others => '0');
            freq_div_cnt <= to_unsigned(FREQ_DIV_SYS_TARGET, CNT_WIDTH);
         
         -- new values for the PRE and CNT registers are on the data bus
         elsif new_timer_vals then
            has_fired <= false;
            if reg = REGNO_PRE then
               counter_pre <= unsigned(data_in);
            elsif reg = REGNO_CNT then
               counter_cnt <= unsigned(data_in);
            end if;
            freq_div_cnt <= to_unsigned(FREQ_DIV_SYS_TARGET, CNT_WIDTH);
               
         -- timer elapsed and fired and handled the interrupt, now it is time to reset the values
         elsif State = s_reset then
            has_fired <= false;
            counter_pre <= reg_pre;
            counter_cnt <= reg_cnt;
            freq_div_cnt <= to_unsigned(freq_div_sys_target, CNT_WIDTH);
         
         -- count, but only, if it has not yet fired
         elsif is_counting and State = s_count and not has_fired then
         
            -- create 100 kHz clock from system clock
            if freq_div_cnt = x"0000" or IS_SIMULATION then
               freq_div_cnt <= to_unsigned(FREQ_DIV_SYS_TARGET, CNT_WIDTH);
               -- prescaler divides the 100 kHz clock by the value stored in the PRE register
               if counter_pre = x"0001" then
                  counter_pre <= reg_pre;
                  -- count until zero, then "has_fired" will be true
                  if counter_cnt = x"0000" then
                     has_fired <= true;
                  else
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
   handle_registers : process(clk)
   begin
         -- write registers
      if rising_edge(clk) then
         if en = '1' and we = '1' then
            case reg is
               when REGNO_PRE => reg_pre <= unsigned(data_in);
               when REGNO_CNT => reg_cnt <= unsigned(data_in);
               when REGNO_INT => reg_int <= unsigned(data_in);
               when others => null;
            end case;
         end if;

         if reset = '1' then
            reg_pre <= (others => '0');
            reg_cnt <= (others => '0');
            reg_int <= (others => '0');
         end if;         
      end if;
   end process;   

end beh;
