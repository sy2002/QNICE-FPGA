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
   HALT           : out std_logic;                          -- 1=CPU halted due to the HALT command, 0=running
   INS_CNT_STROBE : out std_logic;                          -- goes high for one clock cycle for each new instruction
   
   -- interrupt system                                      -- refer to doc/intro/qnice_intro.pdf to learn how this works
   INT_N          : in std_logic;
   IGRANT_N       : out std_logic    
);
end component;

component dev_int_source is
generic (
   fire_1         : natural;
   fire_2         : natural;
   ISR_ADDR       : natural   
);
port (
   CLK            : in std_logic;
   RESET          : in std_logic;
   DATA           : inout std_logic_vector(15 downto 0);   
  
   INT_N          : out std_logic;
   IGRANT_N       : in std_logic   
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

-- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
component EAE is
port (
   clk      : in std_logic;                        -- system clock
   reset    : in std_logic;                        -- system reset
   
   -- EAE registers
   en       : in std_logic;                        -- chip enable
   we       : in std_logic;                        -- write enable
   reg      : in std_logic_vector(2 downto 0);     -- register selector
   data     : inout std_logic_vector(15 downto 0)  -- system's data bus
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
   cpu_igrant_n      : in std_logic;
   
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
   
   -- Extended Arithmetic Element register range $FF1B..$FF1F
   eae_en            : out std_logic;
   eae_we            : out std_logic;
   eae_reg           : out std_logic_vector(2 downto 0)   
);
end component;

-- CPU control signals
signal cpu_addr               : std_logic_vector(15 downto 0);
signal cpu_data               : std_logic_vector(15 downto 0);
signal cpu_data_dir           : std_logic;
signal cpu_data_valid         : std_logic;
signal cpu_wait_for_data      : std_logic;
signal cpu_halt               : std_logic;
signal cpu_ins_cnt_strobe     : std_logic;
signal cpu_int_n              : std_logic;
signal cpu_igrant_n           : std_logic;

-- MMIO control signals
signal rom_enable             : std_logic;
signal ram_enable             : std_logic;
signal ram_busy               : std_logic;
signal rom_busy               : std_logic;
signal switch_reg_enable      : std_logic;
signal eae_en                 : std_logic;
signal eae_we                 : std_logic;
signal eae_reg                : std_logic_vector(2 downto 0);

-- clock for simulation
signal CLK                    : std_logic;

-- reset signal and reset counter for simulation
signal reset_counter          : unsigned(5 downto 0) := (others => '0');
signal gbl_reset              : std_logic;

-- emulate the switches on the Nexys4 dev board to toggle VGA and PS/2
signal SWITCHES               : std_logic_vector(15 downto 0);

begin

   -- QNICE CPU
   cpu : QNICE_CPU
      port map (
         CLK => CLK,
         RESET => gbl_reset,
         WAIT_FOR_DATA => cpu_wait_for_data,
         ADDR => cpu_addr,
         DATA => cpu_data,
         DATA_DIR => cpu_data_dir,
         DATA_VALID => cpu_data_valid,
         HALT => cpu_halt,
         INS_CNT_STROBE => cpu_ins_cnt_strobe,
         INT_N => cpu_int_n,
         IGRANT_N => cpu_igrant_n         
      );

   -- ROM: up to 64kB consisting of up to 32.000 16 bit words
   rom : BROM
      generic map (
         FILE_NAME   => ROM_FILE,
         ROM_LINES   => ROM_SIZE
      )
      port map (
         clk         => CLK,
         ce          => rom_enable,
         address     => cpu_addr(14 downto 0),
         data        => cpu_data,
         busy        => rom_busy
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : BRAM
      port map (
         clk         => CLK,
         ce          => ram_enable,
         address     => cpu_addr(14 downto 0),
         we          => cpu_data_dir,         
         data_i      => cpu_data,
         data_o      => cpu_data,
         busy        => ram_busy         
      );
            
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : eae
      port map (
         clk => CLK,
         reset => gbl_reset,
         en => eae_en,
         we => eae_we,
         reg => eae_reg,
         data => cpu_data         
      );

   -- memory mapped i/o controller
   mmio_controller : mmio_mux
      port map (
         CLK => CLK,
         HW_RESET => gbl_reset,          
         addr => cpu_addr,
         data_dir => cpu_data_dir,
         data_valid => cpu_data_valid,
         cpu_wait_for_data => cpu_wait_for_data,
         cpu_halt => cpu_halt,
         cpu_igrant_n => cpu_igrant_n,
         rom_enable => rom_enable,
         rom_busy => rom_busy,
         ram_enable => ram_enable,
         ram_busy => ram_busy,
         switch_reg_enable => switch_reg_enable,
         eae_en => eae_en,
         eae_we => eae_we,
         eae_reg => eae_reg
      );

   interrupt_generator : dev_int_source
      generic map (
         fire_1 => 17,
         fire_2 => 28,
         ISR_ADDR => 16#000D#
      )
      port map (
         CLK => CLK,
         RESET => gbl_reset,
         DATA => cpu_data,
         INT_N => cpu_int_n,
         IGRANT_N => cpu_igrant_n
      );

   generate_clock: process
   begin
      CLK <= '0';
      wait for 10 ns;
      CLK <= '1';
      wait for 10 ns;
   end process;      
      
   startup_reset_handler : process(CLK)
   begin
      if rising_edge(CLK) then
         if reset_counter < x"20" then
            reset_counter <= reset_counter + 1;
         end if;
      end if;
   end process;
  
   -- HRAM needs *very* long to initialize ("busy=1" at the beginning)
   gbl_reset <= '1' when reset_counter < x"20" else '0';    
         
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
