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
end component;

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

   t0_en <= '1' when en = '1' and unsigned(reg) < x"3" else '0';
   t1_en <= '1' when en = '1' and t0_en = '0' else '0';
   
   t0_we <= t0_en and we;
   t1_we <= t1_en and we;
   
   t0_reg <= reg(1 downto 0);
   t1_reg_tmp <= std_logic_vector(unsigned(reg) - x"3");
   t1_reg <= t1_reg_tmp(1 downto 0);

   timer0 : timer
   generic map
   (
      CLK_FREQ => CLK_FREQ,
      IS_SIMULATION => IS_SIMULATION
   )
   port map
   (
      clk => clk,
      reset => reset,
      
      int_n_out => int_n_out,          -- connect with "left" device (e.g. CPU)
      grant_n_in => grant_n_in,        -- ditto
      int_n_in => '1', --t1_int_n_out,        -- build Daisy Chain between timer0 and timer 1
      grant_n_out => open, --t1_grant_n_in,    -- ditto
         
      en => t0_en,
      we => t0_we,
      reg => t0_reg,
      data => data
   );
   
   timer1 : timer
   generic map
   (
      CLK_FREQ => CLK_FREQ,
      IS_SIMULATION => IS_SIMULATION
   )   
   port map
   (
      clk => clk,
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
   
end beh;
