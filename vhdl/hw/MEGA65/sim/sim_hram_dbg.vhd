----------------------------------------------------------------------------------
-- MEGA65 Top Module for simulation: HRAM debugging
-- 
-- done by sy2002 in June and August 2020
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

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data_in            : std_logic_vector(15 downto 0);
signal cpu_data_out           : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;

-- MMIO control signals
signal switch_reg_enable      : std_logic;
signal switch_data_out        : std_logic_vector(15 downto 0);
signal rom_enable             : std_logic;
signal rom_busy               : std_logic;
signal rom_data_out           : std_logic_vector(15 downto 0);
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal ram_data_out           : std_logic_vector(15 downto 0);
signal hram_en                : std_logic;
signal hram_we                : std_logic;
signal hram_reg               : std_logic_vector(3 downto 0); 
signal hram_cpu_ws            : std_logic;
signal hram_data_out          : std_logic_vector(15 downto 0);

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

   cpu_data_in <= switch_data_out or rom_data_out or ram_data_out or hram_data_out;

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
   cpu : entity work.QNICE_CPU
      port map (
         CLK => SLOW_CLOCK,
         RESET => gbl_reset,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA_IN => cpu_data_in,
         DATA_OUT => cpu_data_out,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : entity work.BROM
      generic map (
         FILE_NAME   => ROM_FILE
      )
      port map (
         clk         => SLOW_CLOCK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => rom_data_out,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : entity work.BRAM
      port map (
         clk         => SLOW_CLOCK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data_out,
         data_o      => ram_data_out,
         busy        => ram_busy         
      );
      
   -- HyperRAM
   HRAM : entity work.hyperram_ctl
      port map (
         clk => SLOW_CLOCK,
         clk2x => CLK1x,
         clk4x => CLK2x,
         reset => gbl_reset,
         hram_en => hram_en,
         hram_we => hram_we,
         hram_reg => hram_reg,
         hram_cpu_ws => hram_cpu_ws,
         data_in => cpu_data_out,
         data_out => hram_data_out,
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
   mmio_controller : entity work.mmio_mux
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
   switch_data_out <= x"0000";      
                          
end beh;
