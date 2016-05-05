----------------------------------------------------------------------------------
-- QNICE Environment 1 (env1) specific implementation of the memory mapped i/o
-- multiplexing; env1.vhdl's header contains the description of the mapping
--
-- also implements the CPU's WAIT_FOR_DATA bus by setting it to a meaningful
-- value (0) when a device is active, that has no own control facility
--
-- also implements the global state and reset management
-- 
-- done in 2015, 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

use work.env1_globals.all;

entity mmio_mux is
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
   
   -- PORE ROM (PowerOn & Reset Execution ROM)
   pore_rom_enable   : out std_logic;
   pore_rom_busy     : in std_logic;
   
   -- VGA register range $FF00..$FF0F
   vga_en            : out std_logic;
   vga_we            : out std_logic;
   vga_reg           : out std_logic_vector(3 downto 0);
   
   -- TIL register rage: $FF10..$FF11
   til_reg0_enable   : out std_logic;
   til_reg1_enable   : out std_logic;
   
   -- SWITCHES is $FF12
   switch_reg_enable : out std_logic;
   
   -- Keyboard register range $FF13..$FF16
   kbd_en            : out std_logic;
   kbd_we            : out std_logic;
   kbd_reg           : out std_logic_vector(1 downto 0);
   
   -- Cycle counter regsiter range $FF17..$FF1A
   cyc_en            : out std_logic;
   cyc_we            : out std_logic;
   cyc_reg           : out std_logic_vector(1 downto 0);
   
   -- UART register range $FF20..$FF23
   uart_en           : out std_logic;
   uart_we           : out std_logic;
   uart_reg          : out std_logic_vector(1 downto 0);
   
   -- global state and reset management
   reset_pre_pore    : out std_logic;
   reset_post_pore   : out std_logic
);
end mmio_mux;

architecture Behavioral of mmio_mux is

component debounce is
generic (
   counter_size  : integer
);
port (
   clk           : in std_logic;
   button        : in std_logic;
   result        : out std_logic
);
end component;

signal ram_enable_i : std_logic;
signal rom_enable_i : std_logic;
signal pore_rom_enable_i : std_logic;
signal use_pore_rom_i : std_logic;

-- Reset and Power-On-Reset state machine
type global_state_type is
(
   gsPowerOn,
   gsReset,
   gsReset_execute,
   gsPORE,
   gsPostPoreReset,
   gsPostPoreReset_execute,
   gsRun
);

-- as we check for "= RESET_DURATION", we need one bit more,
-- so RESET_COUNTER_BTS is not decremented by 1
constant RESET_COUNTER_BTS    : natural := integer(ceil(log2(real(RESET_DURATION))));

signal global_state           : global_state_type := gsPowerOn;

signal debounced_hw_reset     : std_logic;
signal reset_ctl              : std_logic;
signal boot_msg_char          : std_logic_vector(7 downto 0);
signal reset_counter          : unsigned(RESET_COUNTER_BTS downto 0);

signal fsm_next_global_state  : global_state_type;
signal fsm_reset_counter      : unsigned(RESET_COUNTER_BTS downto 0);


begin   

   -- TIL register base is FF10
   -- writing to base equals register0 equals the actual value
   -- writing to register1 (FF11) equals the mask
   til_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 4) = x"FF1" and data_dir = '1' and data_valid = '1' then
      
         -- TIL register 0
         if addr(3 downto 0) = x"0" then
            til_reg0_enable <= '1';
         else
            til_reg0_enable <= '0';
         end if;
         
         -- TIL register 1
         if addr(3 downto 0) = x"1" then
            til_reg1_enable <= '1';
         else
            til_reg1_enable <= '0';
         end if;
                  
      else
         til_reg0_enable <= '0';
         til_reg1_enable <= '0';
      end if;
   end process;
   
   -- SWITCH register is FF12
   switch_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 0) = x"FF12" and data_dir = '0' then
         switch_reg_enable <= '1';
      else
         switch_reg_enable <= '0';
      end if;
   end process;
   
   -- Keyboard status register is FF13 and data register is FF14
   keyboard_control : process(addr, data_dir, data_valid)
   begin
      kbd_en <= '0';
      kbd_we <= '0';
      kbd_reg <= "00";
      
      if addr = x"FF13" then
         kbd_en <= '1';
         kbd_we <= data_dir and data_valid;
         kbd_reg <= "00";
      elsif addr = x"FF14" then
         kbd_en <= '1';
         kbd_we <= data_dir and data_valid;
         kbd_reg <= "01";
      end if;      
   end process;
   
   -- Cycle counter starts at FF17
   cyc_control : process(addr, data_dir, data_valid)
   begin
      cyc_en <= '0';
      cyc_we <= '0';
      cyc_reg <= "00";
      
      if addr = x"FF17" then
         cyc_en <= '1';
         cyc_we <= data_dir and data_valid;
         cyc_reg <= "00";
      elsif addr = x"FF18" then
         cyc_en <= '1';
         cyc_we <= data_dir and data_valid;
         cyc_reg <= "01";
      elsif addr = x"FF19" then
         cyc_en <= '1';
         cyc_we <= data_dir and data_valid;
         cyc_reg <= "10";
      elsif addr = x"FF1A" then
         cyc_en <= '1';
         cyc_we <= data_dir and data_valid;
         cyc_reg <= "11";
      end if;
   end process;
   
   -- VGA starts at FF00
   vga_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 4) = x"FF0" then
         vga_en <= '1';
         vga_we <= data_dir and data_valid;
         vga_reg <= addr(3 downto 0);
      else
         vga_en <= '0';
         vga_we <= '0';
         vga_reg <= x"0";
      end if;
   end process;
   
   -- UART starts at FF20
   uart_control : process(addr, data_dir, data_valid)
   begin
      if addr(15 downto 4) = x"FF2" then
         uart_en <= '1';
         uart_we <= data_dir and data_valid;
         uart_reg <= addr(1 downto 0);
      else
         uart_en <= '0';
         uart_we <= '0';
         uart_reg <= "00";
      end if;
   end process;
   
   -- generate CPU wait signal   
   -- as long as the RAM is the only device on the bus that can make the
   -- CPU wait, this simple implementation is good enough
   -- otherwise, a "req_busy" bus could be built (replacing the ram_busy input)
   -- the block_ram's busy line is already a tri state, so it is ready for such a bus
   cpu_wait_control : process (ram_enable_i, rom_enable_i, pore_rom_enable_i, ram_busy, rom_busy, pore_rom_busy)
   begin
      if ram_enable_i = '1' and ram_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif rom_enable_i = '1' and rom_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif pore_rom_enable_i = '1' and pore_rom_busy = '1' then
         cpu_wait_for_data <= '1';
      else
         cpu_wait_for_data <= '0';
      end if;
   end process;

   -- debounce the reset button
   reset_btn_debouncer : debounce
      generic map (
         counter_size => 18            -- @TODO change to 19 when running with 100 MHz
      )
      port map (
         clk => CLK,
         button => HW_RESET,
         result => debounced_hw_reset
      );

   -- PORE state machine: advance state
   fsm_advance_state : process (clk, debounced_hw_reset)
   begin
      if debounced_hw_reset = '1' then
         global_state <= gsReset;
         reset_counter <= (others => '0');
      else
         if rising_edge(clk) then
            global_state      <= fsm_next_global_state;
            reset_counter     <= fsm_reset_counter;
         end if;
      end if;
   end process;
   
   -- PORE state machine: calculate next state
   fsm_calc_state : process(global_state, reset_counter, cpu_halt)
   begin
      fsm_next_global_state   <= global_state;
      fsm_reset_counter       <= reset_counter;
            
      case global_state is
      
         when gsPowerOn =>
            fsm_next_global_state <= gsReset;
            
         when gsReset =>
            fsm_reset_counter <= (others => '0');
            fsm_next_global_state <= gsReset_execute;
            
         when gsReset_execute =>
            if reset_counter = RESET_DURATION then
               fsm_next_global_state <= gsRun; -- use for simulation instead of PORE
--               fsm_next_global_state <= gsPORE;
            else
               fsm_reset_counter <= reset_counter + 1;
               fsm_next_global_state <= gsReset_execute;               
            end if;
            
         when gsPORE =>
            if cpu_halt = '1' then
               fsm_next_global_state <= gsPostPoreReset;
            end if;
         
         when gsPostPoreReset =>
            fsm_reset_counter <= (others => '0');
            fsm_next_global_state <= gsPostPoreReset_execute;
            
         when gsPostPoreReset_execute =>            
            if reset_counter = RESET_DURATION then
               fsm_next_global_state <= gsRun;
            else
               fsm_reset_counter <= reset_counter + 1;
               fsm_next_global_state <= gsPostPoreReset_execute;               
            end if;            

         when gsRun => null;
      end case;
   end process;

   -- PORE ROM is used in all global states other than gsRun
   use_pore_rom_i <= '0' when (global_state = gsPostPoreReset or
                               global_state = gsPostPoreReset_execute or
                               global_state = gsRun)
                         else '1';
   pore_rom_enable_i <= not addr(15) and not data_dir and use_pore_rom_i;

   -- ROM is enabled when the address is < $8000 and the CPU is reading
   rom_enable_i <= not addr(15) and not data_dir and not use_pore_rom_i;
   
   -- RAM is enabled when the address is in ($8000..$FEFF)
   ram_enable_i <= addr(15)
                   and not (addr(14) and addr(13) and addr(12) and addr(11) and addr(10) and addr(9) and addr(8));
               
   -- generate external RAM/ROM/PORE enable signals
   ram_enable <= ram_enable_i;
   rom_enable <= rom_enable_i;
   pore_rom_enable <= pore_rom_enable_i;
   
   -- generate external reset signals
   reset_pre_pore <= '1' when (global_state = gsPowerOn or global_state = gsReset or global_state = gsReset_execute) else '0';
   reset_post_pore <= '1' when (global_state = gsPostPoreReset or global_state = gsPostPoreReset_execute) else '0';
end Behavioral;

