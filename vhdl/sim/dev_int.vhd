----------------------------------------------------------------------------------
-- QNICE-FPGA development testbed for developing interrupts
-- done July 2020 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

entity dev_int is
end dev_int;

architecture beh of dev_int is

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data_in            : std_logic_vector(15 downto 0);
signal cpu_data_out           : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;
signal cpu_ins_cnt_strobe     : std_logic;
signal cpu_int_n              : std_logic;
signal cpu_igrant_n           : std_logic;

-- MMIO control signals
signal rom_enable             : std_logic;
signal rom_busy               : std_logic;
signal rom_data_out           : std_logic_vector(15 downto 0);
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal ram_data_out           : std_logic_vector(15 downto 0);
signal switch_reg_enable      : std_logic;
signal switch_data_out        : std_logic_vector(15 downto 0);
signal eae_en                 : std_logic;
signal eae_we                 : std_logic;
signal eae_reg                : std_logic_vector(2 downto 0);
signal eae_data_out           : std_logic_vector(15 downto 0);
signal tin_en                 : std_logic;
signal tin_we                 : std_logic;
signal tin_reg                : std_logic_vector(2 downto 0);
signal tin_data_out           : std_logic_vector(15 downto 0);
signal hig_data_out           : std_logic_vector(15 downto 0);
signal reset_ctl              : std_logic;

-- clock for simulation
signal CLK                    : std_logic;


-- emulate the switches on the Nexys4 dev board to toggle VGA and PS/2
signal SWITCHES               : std_logic_vector(15 downto 0);

begin
   
   cpu_data_in <= rom_data_out or
                  ram_data_out or
                  eae_data_out or
                  switch_data_out or
                  tin_data_out or
                  hig_data_out;

   -- QNICE CPU
   cpu : entity work.QNICE_CPU
      port map (
         CLK => CLK,
         RESET => reset_ctl,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA_IN => cpu_data_in,
         DATA_OUT => cpu_data_out,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt,
         INS_CNT_STROBE => cpu_ins_cnt_strobe,
         INT_N => cpu_int_n,
         IGRANT_N => cpu_igrant_n         
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : entity work.BROM
      generic map (
         FILE_NAME   => ROM_FILE
      )
      port map (
         clk         => CLK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => rom_data_out,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : entity work.BRAM
      port map (
         clk         => CLK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data_out,
         data_o      => ram_data_out,
         busy        => ram_busy         
      );
            
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : entity work.eae
      port map (
         clk => CLK,
         reset => reset_ctl,
         en => eae_en,
         we => eae_we,
         reg => eae_reg,
         data_in => cpu_data_out,
         data_out => eae_data_out       
      );
      
   -- memory mapped i/o controller
   mmio_controller : entity work.mmio_mux
      generic map (
         GD_PORE     => false,               -- no PORE system
         GD_TIL      => false,               -- no TIL leds
         GD_SWITCHES => true,                -- support SWITCHES register
         GD_HRAM     => false                -- no support for HyperRAM
      )
      port map (
         -- input from hardware
         CLK => CLK,
         HW_RESET => '0',
      
         -- input from CPU
         addr => cpu_addr,
         data_dir => cpu_data_dir,
         data_valid => cpu_data_valid,
         cpu_halt => cpu_halt,
         cpu_igrant_n => cpu_igrant_n,
      
         -- let the CPU wait for data from the bus
         cpu_wait_for_data => cpu_wait_for_data,
         
         -- ROM is enabled when the address is < $8000 and the CPU is reading
         rom_enable => rom_enable,
         rom_busy => rom_busy,
         
         -- RAM is enabled when the address is in ($8000..$FEFF)
         ram_enable => ram_enable,
         ram_busy => ram_busy,
         
         -- PORE is disabled
         pore_rom_enable => open,
         pore_rom_busy => '0',
         
         -- SWITCHES is $FF00
         switch_reg_enable => switch_reg_enable,
                  
         -- Extended Arithmetic Element register range $FF18..$FF1F
         eae_en => eae_en,
         eae_we => eae_we,
         eae_reg => eae_reg,
         
         -- Timer Interrupt Generator range $FF28 .. $FF2F
         tin_en => tin_en,
         tin_we => tin_we,
         tin_reg => tin_reg,
                  
         -- devices that are not used
         til_reg0_enable => open,
         til_reg1_enable => open,
         kbd_en => open,
         kbd_we => open,
         kbd_reg => open,
         cyc_en => open,
         cyc_we => open,
         cyc_reg => open,
         ins_en => open,
         ins_we => open,
         ins_reg => open,      
         uart_en => open,
         uart_we => open,
         uart_reg => open,
         uart_cpu_ws => '0',
         sd_en => open,
         sd_we => open,
         sd_reg => open,
         vga_en => open,
         vga_we => open,
         vga_reg => open,      
         hram_en => open,
         hram_we => open,
         hram_reg => open, 
         hram_cpu_ws => '0',   
    
         -- global state and reset management
         reset_pre_pore => open,
         reset_post_pore => open,
         reset_ctl => reset_ctl      
      );

   timer_interrupt : entity work.timer_module   
      generic map (
         CLK_FREQ => 50000000,
         IS_SIMULATION => true
      )
      port map (
         clk => CLK,
         reset => reset_ctl,
         int_n_out => cpu_int_n,
         grant_n_in => cpu_igrant_n,
         int_n_in => '1',              -- Daisy Chain: no more devices: 1=never request an interrupt
         grant_n_out => open,          -- ditto: open=never grant any interrupt
         en => tin_en,
         we => tin_we,
         reg => tin_reg,
         data_in => cpu_data_out,
         data_out => tin_data_out
      );
      
   hig_data_out <= (others => '0');      
--   hardcoded_interrupt_generator : entity work.dev_int_source
--      generic map (
--         fire_1 => 17,           -- interrupt in the mid of the execution of MOVE 3, @R12++
--         fire_2 => 23,           -- try to interrupt the interrupt
--         ISR_ADDR => 16#0026#    -- refer to "dev_int.asm" to find out how to calculate 
--      )
--      port map (
--         CLK => CLK,
--         RESET => reset_ctl,
--         DATA_IN => cpu_data_out,
--         DATA_OUT => hig_data_out,
--         INT_N => cpu_int_n,
--         IGRANT_N => cpu_igrant_n
--      );

   generate_clock: process
   begin
      CLK <= '0';
      wait for 10 ns;
      CLK <= '1';
      wait for 10 ns;
   end process;      
               
   -- handle the toggle switches: always zero means STDIN=STDOUT=UART
   switch_data_out <= (others => '0');   
end beh;
