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
-- enhanced in July 2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;
use work.qnice_tools.all;

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

   -- Instruction counter register range $FF2A..$FF2D
   ins_en            : out std_logic;
   ins_we            : out std_logic;
   ins_reg           : out std_logic_vector(1 downto 0);

   -- Extended Arithmetic Element register range $FF1B..$FF1F
   eae_en            : out std_logic;
   eae_we            : out std_logic;
   eae_reg           : out std_logic_vector(2 downto 0);
   
   -- UART register range $FF20..$FF23
   uart_en           : out std_logic;
   uart_we           : out std_logic;
   uart_reg          : out std_logic_vector(1 downto 0);
   uart_cpu_ws       : in std_logic;
   
   -- SD Card register range $FF24..FF29
   sd_en             : out std_logic;
   sd_we             : out std_logic;
   sd_reg            : out std_logic_vector(2 downto 0);
   
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
constant RESET_COUNTER_BTS    : natural := f_log2(RESET_DURATION);

signal global_state           : global_state_type := gsPowerOn;

signal debounced_hw_reset     : std_logic;
signal reset_ctl              : std_logic;
signal boot_msg_char          : std_logic_vector(7 downto 0);
signal reset_counter          : unsigned(RESET_COUNTER_BTS downto 0);

signal fsm_next_global_state  : global_state_type;
signal fsm_reset_counter      : unsigned(RESET_COUNTER_BTS downto 0);

signal vga_offset             : std_logic_vector(15 downto 0);
signal til_offset             : std_logic_vector(15 downto 0);
signal switch_offset          : std_logic_vector(15 downto 0);
signal kbd_offset             : std_logic_vector(15 downto 0);
signal cyc_offset             : std_logic_vector(15 downto 0);
signal eae_offset             : std_logic_vector(15 downto 0);
signal uart_offset            : std_logic_vector(15 downto 0);
signal sd_offset              : std_logic_vector(15 downto 0);
signal ins_offset             : std_logic_vector(15 downto 0);

signal vga_cs                 : std_logic;
signal til_cs                 : std_logic;
signal switch_cs              : std_logic;
signal kbd_cs                 : std_logic;
signal cyc_cs                 : std_logic;
signal eae_cs                 : std_logic;
signal uart_cs                : std_logic;
signal sd_cs                  : std_logic;
signal ins_cs                 : std_logic;

begin   

   vga_offset    <= std_logic_vector(unsigned(addr) - x"FF00");  vga_cs    <= '1' when unsigned(vga_offset)    < 16 else '0';
   til_offset    <= std_logic_vector(unsigned(addr) - x"FF10");  til_cs    <= '1' when unsigned(til_offset)    <  2 else '0';
   switch_offset <= std_logic_vector(unsigned(addr) - x"FF12");  switch_cs <= '1' when unsigned(switch_offset) <  1 else '0';
   kbd_offset    <= std_logic_vector(unsigned(addr) - x"FF13");  kbd_cs    <= '1' when unsigned(kbd_offset)    <  4 else '0';
   cyc_offset    <= std_logic_vector(unsigned(addr) - x"FF17");  cyc_cs    <= '1' when unsigned(cyc_offset)    <  4 else '0';
   eae_offset    <= std_logic_vector(unsigned(addr) - x"FF1B");  eae_cs    <= '1' when unsigned(eae_offset)    <  5 else '0';
   uart_offset   <= std_logic_vector(unsigned(addr) - x"FF20");  uart_cs   <= '1' when unsigned(uart_offset)   <  4 else '0';
   sd_offset     <= std_logic_vector(unsigned(addr) - x"FF24");  sd_cs     <= '1' when unsigned(sd_offset)     <  6 else '0';
   ins_offset    <= std_logic_vector(unsigned(addr) - x"FF2A");  ins_cs    <= '1' when unsigned(ins_offset)    <  4 else '0';

   til_reg0_enable <= til_cs and not til_offset(0) and data_dir and data_valid;
   til_reg1_enable <= til_cs and     til_offset(0) and data_dir and data_valid;

   switch_reg_enable <= switch_cs and not data_dir;

   vga_en  <= vga_cs;
   kbd_en  <= kbd_cs;
   cyc_en  <= cyc_cs;
   eae_en  <= eae_cs;
   uart_en <= uart_cs;
   sd_en   <= sd_cs;
   ins_en  <= ins_cs;

   vga_we  <= vga_cs  and data_dir and data_valid;
   kbd_we  <= kbd_cs  and data_dir and data_valid;
   cyc_we  <= cyc_cs  and data_dir and data_valid;
   eae_we  <= eae_cs  and data_dir and data_valid;
   uart_we <= uart_cs and data_dir and data_valid;
   sd_we   <= sd_cs   and data_dir and data_valid;
   ins_we  <= ins_cs  and data_dir and data_valid;

   vga_reg  <= vga_offset (3 downto 0);
   kbd_reg  <= kbd_offset (1 downto 0);
   cyc_reg  <= cyc_offset (1 downto 0);
   eae_reg  <= eae_offset (2 downto 0);
   uart_reg <= uart_offset(1 downto 0);
   sd_reg   <= sd_offset  (2 downto 0);
   ins_reg  <= ins_offset (1 downto 0);

   -- generate CPU wait signal   
   -- as long as the RAM is the only device on the bus that can make the
   -- CPU wait, this simple implementation is good enough
   -- otherwise, a "req_busy" bus could be built (replacing the ram_busy input)
   -- the block_ram's busy line is already a tri state, so it is ready for such a bus
   cpu_wait_control : process (ram_enable_i, rom_enable_i, pore_rom_enable_i, ram_busy, rom_busy,
                               pore_rom_busy, uart_cpu_ws)
   begin
      if ram_enable_i = '1' and ram_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif rom_enable_i = '1' and rom_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif pore_rom_enable_i = '1' and pore_rom_busy = '1' then
         cpu_wait_for_data <= '1';
      elsif uart_cpu_ws = '1' then
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
--               fsm_next_global_state <= gsRun; -- use for simulation instead of PORE
               fsm_next_global_state <= gsPORE;
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
