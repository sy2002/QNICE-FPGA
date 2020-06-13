----------------------------------------------------------------------------------
-- MEGA65 Top Module for simulation: HRAM debugging
-- 
-- done by sy2002 in June 2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

use work.env1_globals.all;

entity MEGA65_HRAM_SIM is
end MEGA65_HRAM_SIM;

architecture beh of MEGA65_HRAM_SIM is

-- QNICE CPU
component QNICE_CPU
port (
   -- clock
   CLK            : in std_logic;
   RESET          : in std_logic;
   
   WAIT_FOR_DATA  : in std_logic;                            -- 1=CPU adds wait cycles while re-reading from bus
      
   ADDR           : out std_logic_vector(15 downto 0);      -- 16 bit address bus
   
   --tristate 16 bit data bus
   DATA           : inout std_logic_vector(15 downto 0);    -- send/receive data
   DATA_DIR       : out std_logic;                          -- 1=DATA is sending, 0=DATA is receiving
   DATA_VALID     : out std_logic;                          -- while DATA_DIR = 1: DATA contains valid data
   
   -- signals about the CPU state
   HALT           : out std_logic                           -- 1=CPU halted due to the HALT command, 0=running   
);
end component;

-- ROM
component BROM is
generic (
   FILE_NAME   : string;
   ROM_LINES   : integer
);
port (
   clk         : in std_logic;                        -- read and write on rising clock edge
   ce          : in std_logic;                        -- chip enable, when low then high impedance on output
   
   address     : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   data        : out std_logic_vector(15 downto 0);   -- read data
   
   busy        : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA               
);
end component;

-- BLOCK RAM
component BRAM is
port (
   clk      : in std_logic;                        -- read and write on rising clock edge
   ce       : in std_logic;                        -- chip enable, when low then high impedance
   
   address  : in std_logic_vector(14 downto 0);    -- address is for now 16 bit hard coded
   we       : in std_logic;                        -- write enable
   data_i   : in std_logic_vector(15 downto 0);    -- write data
   data_o   : out std_logic_vector(15 downto 0);   -- read data
   
   busy     : out std_logic                        -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA   
);
end component;

-- HyperRAM
component hyperram_ctl is
port(
   -- HyperRAM needs a base clock and then one with 2x speed and one with 4x speed
   clk         : in std_logic;               -- currently 50 MHz QNICE system clock
   clk2x       : in std_logic;
   clk4x       : in std_logic;
   
   reset       : in std_logic;
   
   -- connect to CPU's data bus (data high impedance when all reg_* are 0)
   hram_en     : in std_logic;
   hram_we     : in std_logic;
   hram_reg    : in std_logic_vector(3 downto 0); 
   hram_cpu_ws : out std_logic;              -- insert CPU wait states (aka WAIT_FOR_DATA)
   cpu_data    : inout std_logic_vector(15 downto 0);
   
   -- hardware connections
   hr_d        : inout unsigned(7 downto 0); -- Data/Address
   hr_rwds     : inout std_logic;            -- RW Data strobe
   hr_reset    : out std_logic;              -- Active low RESET line to HyperRAM
   hr_clk_p    : out std_logic;
   hr2_d       : inout unsigned(7 downto 0); -- Data/Address
   hr2_rwds    : inout std_logic;            -- RW Data strobe
   hr2_reset   : out std_logic;              -- Active low RESET line to HyperRAM
   hr2_clk_p   : out std_logic;
   hr_cs0      : out std_logic;
   hr_cs1      : out std_logic
);
end component;

-- multiplexer to control the data bus (enable/disable the different parties)
component mmio_mux is
port (
   -- input from hardware
   HW_RESET          : in std_logic;
   CLK               : in std_logic;

   -- input from CPU
   addr              : in std_logic_vector(15 downto 0);
   data_dir          : in std_logic;
   data_valid        : in std_logic;
   cpu_halt          : in std_logic;
   
   -- let the CPU wait for data from the bus
   cpu_wait_for_data : out std_logic;
   
   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable        : out std_logic;
   rom_busy          : in std_logic;
   
   -- RAM is enabled when the address is in ($8000..$FEFF)
   ram_enable        : out std_logic;
   ram_busy          : in std_logic;
   
   -- SWITCHES is $FF12
   switch_reg_enable : out std_logic;
      
   -- HyerRAM register range $FF60 .. $FF62
   hram_en           : out std_logic;
   hram_we           : out std_logic;
   hram_reg          : out std_logic_vector(3 downto 0); 
   hram_cpu_ws       : in std_logic  -- insert CPU wait states (aka WAIT_FOR_DATA)      
);
end component;

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data               : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;

-- MMIO control signals
signal switch_reg_enable      : std_logic;
signal rom_enable             : std_logic;
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal rom_busy               : std_logic;
signal hram_en                : std_logic;
signal hram_we                : std_logic;
signal hram_reg               : std_logic_vector(3 downto 0); 
signal hram_cpu_ws            : std_logic;

-- Main clock: 50 MHz as long as we did not solve the timing issues of the register file
signal SLOW_CLOCK             : std_logic;

-- Pixelclock and fast clock for HRAM
signal CLK1x                  : std_logic;   -- 100 MHz clock created by mmcme2 for congruent phase
signal CLK2x                  : std_logic;   -- 4x SLOW_CLOCK = 200 MHz

-- emulate the switches on the Nexys4 dev board to toggle VGA and PS/2
signal SWITCHES               : std_logic_vector(15 downto 0);

-- HRAM simulation signals
signal hr_d                   : unsigned(7 downto 0);       -- Data/Address
signal hr_rwds                : std_logic;                  -- RW Data strobe
signal hr_reset               : std_logic;                  -- Active low RESET line to HyperRAM
signal hr_clk_p               : std_logic;
signal hr2_d                  : unsigned(7 downto 0);       -- Data/Address
signal hr2_rwds               : std_logic;                  -- RW Data strobe
signal hr2_reset              : std_logic;                  -- Active low RESET line to HyperRAM
signal hr2_clk_p              : std_logic;
signal hr_cs0                 : std_logic;
signal hr_cs1                 : std_logic;

signal gbl_reset              : std_logic;
signal reset_counter          : unsigned(15 downto 0) := x"0000";

begin

  fakehyper0: entity work.s27kl0641
    generic map (
      id => "$8000000",
      tdevice_vcs => 5 ns,
      timingmodel => "S27KL0641DABHI000"
      )
    port map (
      DQ7 => hr_d(7),
      DQ6 => hr_d(6),
      DQ5 => hr_d(5),
      DQ4 => hr_d(4),
      DQ3 => hr_d(3),
      DQ2 => hr_d(2),
      DQ1 => hr_d(1),
      DQ0 => hr_d(0),

      CSNeg => hr_cs0,
      CK => hr_clk_p,
      RESETneg => hr_reset,
      RWDS => hr_rwds
      );
            
  fakehyper1: entity work.s27kl0641
    generic map (
      id => "$8800000",
      tdevice_vcs => 5 ns,
      timingmodel => "S27KL0641DABHI000"
      )
    port map (
      DQ7 => hr2_d(7),
      DQ6 => hr2_d(6),
      DQ5 => hr2_d(5),
      DQ4 => hr2_d(4),
      DQ3 => hr2_d(3),
      DQ2 => hr2_d(2),
      DQ1 => hr2_d(1),
      DQ0 => hr2_d(0),

      CSNeg => hr_cs1,
      CK => hr2_clk_p,
      RESETneg => hr2_reset,
      RWDS => hr2_rwds
      );

   -- QNICE CPU
   cpu : QNICE_CPU
      port map (
         CLK => SLOW_CLOCK,
         RESET => gbl_reset,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA => cpu_data,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : BROM
      generic map (
         FILE_NAME   => ROM_FILE,
         ROM_LINES   => ROM_SIZE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => cpu_data,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : BRAM
      port map (
         clk         => SLOW_CLOCK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data,
         data_o      => cpu_data,
         busy        => ram_busy         
      );
      
   -- HyperRAM
   HRAM : hyperram_ctl
      port map (
         clk => SLOW_CLOCK,
         clk2x => CLK1x,
         clk4x => CLK2x,
         reset => gbl_reset,
         hram_en => hram_en,
         hram_we => hram_we,
         hram_reg => hram_reg,
         hram_cpu_ws => hram_cpu_ws,
         cpu_data => cpu_data,
         hr_d => hr_d,
         hr_rwds => hr_rwds,
         hr_reset => hr_reset,
         hr_clk_p => hr_clk_p,
         hr2_d => hr2_d,
         hr2_rwds => hr2_rwds,
         hr2_reset => hr2_reset,
         hr2_clk_p => hr2_clk_p,
         hr_cs0 => hr_cs0,
         hr_cs1 => hr_cs1
      );
                        
   -- memory mapped i/o controller
   mmio_controller : mmio_mux
      port map (
         HW_RESET => gbl_reset,
         CLK => SLOW_CLOCK,
         addr => cpu_addr,
         data_dir => cpu_data_dir,
         data_valid => cpu_data_valid,
         cpu_wait_for_data => cpu_wait_for_data,
         cpu_halt => cpu_halt,
         rom_enable => rom_enable,
         rom_busy => rom_busy,
         ram_enable => ram_enable,
         ram_busy => ram_busy,
         switch_reg_enable => switch_reg_enable,
         hram_en => hram_en,
         hram_we => hram_we,
         hram_reg => hram_reg,
         hram_cpu_ws => hram_cpu_ws       
      );
                              
   generate_clocks: process
   begin
      SLOW_CLOCK <= '0';
      CLK1x <= '0';
      CLK2x <= '0';
 
      wait for 2.5 ns;
      CLK2x <= '1';
      
      wait for 2.5 ns;
      CLK2x <= '0';
      CLK1x <= '1';

      wait for 2.5 ns;
      CLK2x <= '1';
      
      wait for 2.5 ns;
      CLK2x <= '0';
      CLK1x <= '0';
      SLOW_CLOCK <= '1';            
      
      wait for 2.5 ns;
      CLK2x <= '1';      

      wait for 2.5 ns;
      CLK2x <= '0';
      CLK1x <= '1';                  
      
      wait for 2.5 ns;
      CLK2x <= '1';
      
      wait for 2.5 ns;     
   end process;
   
   startup_reset_handler : process(CLK1x)
   begin
      if rising_edge(CLK1x) then
         if reset_counter < x"3B1" then
            reset_counter <= reset_counter + 1;
         end if;
      end if;
   end process;
  
   -- HRAM needs *very* long to initialize ("busy=1" at the beginning)
   gbl_reset <= '1' when reset_counter < x"3B1" else '0';    
      
   -- handle the toggle switches
   switch_driver : process(switch_reg_enable, SWITCHES)
   begin
      if switch_reg_enable = '1' then
         cpu_data <= x"0000";
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;
                          
end beh;
