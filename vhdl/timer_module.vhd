-- Timer Interrupt Generator Module (100 kHz internal base clock)
-- Contains two Daisy Chained timers
--
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- and meant to be connected with other interrupt capable devices via a Daisy Chain
--
-- tristate outputs go high impedance when not enabled
-- 
-- Registers: refer to ../monitor/sysdef.asm for the MMIO addresses
--
--  IO$TIMER_x_PRE: The 100 kHz timer clock is divided by the value stored in
--                  this device register. 100 (which corresponds to 0x0064 in
--                  the prescaler register) yields a 1 millisecond pulse which
--                  in turn is fed to the actual counter.
--  IO$TIMER_x_CNT: When the number of output pulses from the prescaler circuit 
--                  equals the number stored in this register, an interrupt will
--                  be generated (if the interrupt address is 0x0000, the
--                  interrupt will be suppressed).
--  IO$TIMER_x_INT: This register contains the address of the desired interrupt 
--                  service routine.
--
--  TIMER0 uses registers 0, 1 and 2 for PRE, CNT and INT
--  and TIMER1 uses registers 3, 4 and 5
--
-- If the generic IS_SIMULATION is true, then we do not generate a 100 KHz timer clock.
-- Instead, the timer clock is equal to the system clock
--
-- done by sy2002 in August 2020

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.qnice_tools.all;

entity timer_module is
generic (
   CLK_FREQ       : natural;                             -- system clock in Hertz
   IS_SIMULATION  : boolean := false                     -- is the module running in simulation?
);
port (
   clk            : in std_logic;                        -- system clock
   reset          : in std_logic;                        -- async reset
   
   -- Daisy Chaining: "left/right" comments are meant to describe a situation, where the CPU is the leftmost device
   int_n_out     : out std_logic;                        -- left device's interrupt signal input
   grant_n_in    : in std_logic;                         -- left device's grant signal output
   int_n_in      : in std_logic;                         -- right device's interrupt signal output
   grant_n_out   : out std_logic;                        -- right device's grant signal input
   
   -- Registers
   en             : in std_logic;                        -- enable for reading from or writing to the bus
   we             : in std_logic;                        -- write to the registers via system's data bus
   reg            : in std_logic_vector(2 downto 0);     -- register selector
   data           : inout std_logic_vector(15 downto 0)  -- system's data bus
);
end timer_module;

architecture beh of timer_module is

component timer is
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
end component;

-- timer internal clock
constant freq_internal        : natural := 100000;       -- internal clock speed
signal   freq_div_sys_target  : natural := natural(ceil(real(CLK_FREQ) / real(freq_internal) / real(2)));
--signal   CNT_WIDTH            : natural := f_log2(freq_div_sys_target); 
signal   freq_div_cnt         : unsigned(15 downto 0);   -- CNT_WIDTH does not work with Vivado 2019.2
signal   freq_div_clk         : std_logic;
signal   timer_clk            : std_logic;

signal   t0_en                : std_logic;
signal   t0_we                : std_logic;
signal   t0_reg               : std_logic_vector(1 downto 0);
signal   t1_int_n_out         : std_logic;
signal   t1_grant_n_in        : std_logic;
signal   t1_en                : std_logic;
signal   t1_we                : std_logic;
signal   t1_reg               : std_logic_vector(1 downto 0);
signal   t1_reg_tmp           : std_logic_vector(3 downto 0);

begin

   timer_clk <= clk when IS_SIMULATION else freq_div_clk;

   t0_en <= '1' when en = '1' and unsigned(reg) < x"3" else '0';
   t1_en <= '1' when en = '1' and t0_en = '0' else '0';
   
   t0_we <= t0_en and we;
   t1_we <= t1_en and we;
   
   t0_reg <= reg(1 downto 0);
   t1_reg_tmp <= std_logic_vector(unsigned(reg) - x"3");
   t1_reg <= t1_reg_tmp(1 downto 0);

   timer0 : timer
   port map
   (
      clk => clk,
      clk_100kHz => timer_clk,
      reset => reset,
      
      int_n_out => int_n_out,          -- connect with "left" device (e.g. CPU)
      grant_n_in => grant_n_in,        -- ditto
      int_n_in => t1_int_n_out,        -- build Daisy Chain between timer0 and timer 1
      grant_n_out => t1_grant_n_in,    -- ditto
         
      en => t0_en,
      we => t0_we,
      reg => t0_reg,
      data => data
   );
   
   timer1 : timer
   port map
   (
      clk => clk,
      clk_100kHz => timer_clk,
      reset => reset,

      int_n_out => t1_int_n_out,       -- build Daisy Chain between timer0 and timer 1
      grant_n_in => t1_grant_n_in,     -- ditto
      int_n_in => int_n_in,            -- next device in chain
      grant_n_out => grant_n_out,      -- ditto
         
      en => t1_en,
      we => t1_we,
      reg => t1_reg,
      data => data
   );
   
   -- generate timer internal clock
   generate_clk : process(clk, reset) 
   begin
      if reset = '1' then
         freq_div_cnt <= (others => '0');
         freq_div_clk <= '0';
      else
         if rising_edge(clk) then
            if freq_div_cnt < freq_div_sys_target then
               freq_div_cnt <= freq_div_cnt + 1;
            else
               freq_div_cnt <= (others => '0');
               freq_div_clk <= not freq_div_clk;
            end if;               
         end if;
      end if;
   end process;      
end beh;
