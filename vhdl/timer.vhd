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
--           in turn is fed to the actual counter. When 0, the timer
--           is disabled.
--  1 = CNT: When the number of output pulses from the prescaler circuit 
--           equals the number stored in this register, an interrupt will
--           be generated (if the interrupt address is 0x0000, the
--           interrupt will be suppressed). When 0, the timer is disabled.
--  2 = INT: This register contains the address of the desired interrupt 
--           service routine. This should always point to a valid ISR,
--           possibly just an RTI.
--
-- done by sy2002 in August & September 2020

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

-- Interrupt and daisy chain protocol handling
signal   int_n_o           : std_logic;
signal   grant_n_i         : std_logic;
signal   int_n_out_i       : std_logic;

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

   -- the daisy chain handler is doing all the heavy lifting
   -- read doc/int-device.md to learn, how it works
   daisy_chain_handler : entity work.daisy_chain
   port map (
      clk_i => clk,
      rst_i => reset,
      this_int_n_i => int_n_o,         -- we need to trigger our interrupt here
      this_grant_n_o => grant_n_i,     -- we need to combinatorially drive the ISR address onto the data bus
      left_int_n_o => int_n_out_i,
      left_grant_n_i => grant_n_in,
      right_int_n_i => int_n_in,
      right_grant_n_o => grant_n_out
   );
   
   int_n_o <= '0' when has_fired and reset = '0' else '1';
   int_n_out <= int_n_out_i;
   
   -- writing anything to any register resets the timer and loads the new value
   new_timer_vals <= true when en = '1' and we = '1' else false;
   
   -- timer is only counting if PRE and CNT are nonzero
   is_counting <= true when reg_pre /= x"0000" and reg_cnt /= x"0000" else false;
      
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
               
         -- timer has elapsed and fired: request the interrupt and reset the values
         elsif has_fired then
            has_fired <= false;
            counter_pre <= reg_pre;
            counter_cnt <= reg_cnt;
            freq_div_cnt <= to_unsigned(freq_div_sys_target, CNT_WIDTH);
         
         -- count, but only, if it has not yet fired and pause during interrupt/daisy handshakes
         elsif is_counting and not has_fired and int_n_out_i = '1' and grant_n_i = '1' then
         
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

   -- MMIO: read/write registers: PRE, CNT, INT and handle grant_n_i and ISR
   handle_register_read : process(en, we, reg, reset, grant_n_i, reg_pre, reg_cnt, reg_int)
   begin
      data_out <= (others => '0');

      -- drive the ISR combinatorially
      if grant_n_i = '0' then
         data_out <= std_logic_vector(reg_int);
          
      -- read registers      
      elsif en = '1' and we = '0' and reset = '0' then
         case reg is
            when REGNO_PRE => data_out <= std_logic_vector(reg_pre);
            when REGNO_CNT => data_out <= std_logic_vector(reg_cnt);
            when REGNO_INT => data_out <= std_logic_vector(reg_int);
            when others => null;
         end case;
      end if;      
   end process;
                          
   handle_register_write : process(clk)
   begin
      -- write registers
      if falling_edge(clk) then
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
