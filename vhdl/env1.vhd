----------------------------------------------------------------------------------
-- "Environment 1" (aka env1) is inspired by the classic QNICE/A evaluation
-- board environment. Features:
--
--    * the original layout: lower 32kB are ROM, upper 32kB are RAM
--    * memory mapped IO beginning at 0xFFF0
--    * TIL-311 display at 0xFF10
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity env1 is
port (
   CLK         : in std_logic;                      -- 100 MHz clock
   RESET_N     : in std_logic;                      -- CPU reset button (negative, i.e. 0 = reset)
   
   -- 7 segment display: common anode and cathode
   SSEG_AN     : out std_logic_vector(7 downto 0);  -- common anode: selects digit
   SSEG_CA     : out std_logic_vector(7 downto 0)   -- cathode: selects segment within a digit
   
   -- debug
--   RegAddr1    : in std_logic_vector(3 downto 0);
--   RegData1    : out std_logic_vector(15 downto 0)
); 
end env1;

architecture beh of env1 is

-- QNICE CPU
component QNICE_CPU
port (
   -- clock
   CLK         : in std_logic;
   RESET       : in std_logic;
   
   ADDR        : out std_logic_vector(15 downto 0);      -- 16 bit address bus
   
   --tristate 16 bit data bus
   DATA        : inout std_logic_vector(15 downto 0);    -- send/receive data
   DATA_DIR    : out std_logic;                          -- 1=DATA is sending, 0=DATA is receiving
   DATA_VALID  : out std_logic                           -- while DATA_DIR = 1: DATA contains valid data
   
   -- debug output
--   dbg_cpustate   : out std_logic_vector(2 downto 0)
--   dbg_reg_ra1    : in std_logic_vector(3 downto 0);
--   dbg_reg_da1    : out std_logic_vector(15 downto 0)   
);
end component;

-- ROM
component ROM_FROM_FILE is
generic (
   ADDR_WIDTH : integer range 2 to 64;    -- address width
   DATA_WIDTH : integer range 2 to 64;    -- word width of ROM output port (aka DATA)
   SIZE       : integer;                  -- amount of words (aka lines in input file)
   FILE_NAME  : string                    -- name of input file; input file format:
                                          -- DATA_WIDTH bits, written as 0 and 1 in each line
);
port (
   en    : in std_logic;                                 -- new values only if enable is 1
   addr  : in std_logic_vector(ADDR_WIDTH - 1 downto 0); -- address
   data  : out std_logic_vector(DATA_WIDTH - 1 downto 0) -- data located at address
);
end component;


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

-- this component counts to the specified value COUNTER_FINISH,
-- then it fires 'overflow' for one clock cycle and then it restarts at zero
component SyTargetCounter is
generic (
   COUNTER_FINISH : integer;
   COUNTER_WIDTH  : integer range 2 to 32 
);
port (
   clk     : in std_logic;
   reset   : in std_logic;
   
   cnt       :  out std_logic_vector(COUNTER_WIDTH - 1 downto 0);
   overflow  : out std_logic := '0'
);
end component;


signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data               : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;

--signal cpu_dbg_cpustate       : std_logic_vector(2 downto 0);
--signal cpu_dbg_reg_da1        : std_logic_vector(15 downto 0);   

signal slow_clock             : std_logic := '0';
signal slow_clock_trigger     : std_logic := '0';

signal dbg_data               : std_logic_vector(15 downto 0);

begin

   -- Slow Clock: for "single stepping" the CPU
   slowclock : SyTargetCounter
      generic map
      (
         COUNTER_FINISH => 100000000,
--         COUNTER_FINISH => 4,
         COUNTER_WIDTH => 28
      )
      port map
      (
         clk => CLK,
         reset => '0',
         overflow => slow_clock_trigger
      );
      
   slowclock_driver : process(slow_clock_trigger)
   begin
      if slow_clock_trigger'event and slow_clock_trigger = '1' then
         slow_clock <= not slow_clock;
      end if;        
   end process;

   -- QNICE CPU
   cpu : QNICE_CPU
      port map
      (
         CLK => slow_clock,
         RESET => not RESET_N,
         ADDR => cpu_addr,
         DATA => cpu_data,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid
--         dbg_cpustate => cpu_dbg_cpustate
--         dbg_reg_ra1 => RegAddr1,
--         dbg_reg_da1 => cpu_dbg_reg_da1
      );

   debug_out : process (cpu_data, cpu_addr, cpu_data_valid)
   begin
      if cpu_addr = x"8000" and cpu_data_valid = '1' then
         dbg_data <= cpu_data;
      else
         dbg_data <= x"FFFF";
      end if;
   end process;

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : ROM_FROM_FILE
      generic map
      (
         ADDR_WIDTH => 16,
         DATA_WIDTH => 16,
         SIZE       => 16,
         FILE_NAME  => "../test_programs/til_count.rom"                                      
      )
      port map(
         en => (not cpu_addr(15)) and (not cpu_data_dir), -- enable ROM if lower 32k word and CPU in read mode
         addr => "0" & cpu_addr(14 downto 0),
         data => cpu_data
      );

   -- 7 segment display
   disp_7seg : drive_7digits
      generic map
      (
         CLOCK_DIVIDER => 200000 -- 200.000 clock cycles @ 100 MHz = 2ms per digit
      )
      port map
      (
         clk => CLK,
         digits => cpu_addr & dbg_data,
         mask => "11111111",
         SSEG_AN => SSEG_AN,
         SSEG_CA => SSEG_CA
      );

--   RegData1 <= cpu_dbg_reg_da1;
end beh;

