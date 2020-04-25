-- QNICE-MEGA65 HyperRAM controller
-- done by sy2002 in April 2020
--
-- Wraps the MEGA65 HyperRAM controller so that it can be connected
-- to the QNICE CPU's data bus and controled via MMIO. 
-- CPU wait states are automatically inserted by the MMIO controller
-- based on hram_cpu_ws, so that in normal operation, Tristate outputs
-- go high impedance when not enabled.
--
-- Registers:
--
-- Register $FF60: CSR register
--    Bit  0 (write only)      Read request
--    Bit  1 (write only)      Write request
--    Bit  2 (read only)       Data ready strobe: data can be read
--    Bit  3 (read only)       Busy writing data (? @TODO)
-- Register $FF61: Low word of address  (15 downto 0)
-- Register $FF62: High word of address (26 downto 16)
-- Register $FF63: Data in/out
--                 writes to the write-flipflop and reads from
--                 the read flip-flop so you cannot read here
--                 what you have written to the write-flipflop

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hyperram_ctl is
port(
   -- HyperRAM needs a base clock and then one with 2x speed and one with 4x speed
   clk         : in std_logic;      -- currently 50 MHz QNICE system clock
   clk2x       : in std_logic;      -- 100 Mhz
   clk4x       : in std_logic;      -- 200 Mhz
   
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
end hyperram_ctl;

architecture beh of hyperram_ctl is

component hyperram is
  Port ( pixelclock : in STD_LOGIC; -- For slow devices bus interface is
         -- actually on pixelclock to reduce latencies
         -- Also pixelclock is the natural clock speed we apply to the HyperRAM.
         clock163 : in std_logic; -- Used for fast clock for HyperRAM
         clock325 : in std_logic; -- Used for fast clock for HyperRAM SERDES units

         -- Simple counter for number of requests received
         request_counter : out std_logic := '0';
         
         read_request : in std_logic;
         write_request : in std_logic;
         address : in unsigned(26 downto 0);
         wdata : in unsigned(7 downto 0);
         
         rdata : out unsigned(7 downto 0);
         data_ready_strobe : out std_logic;
         busy : out std_logic := '0';
         
         -- HyperRAM hardware signals
         hr_d : inout unsigned(7 downto 0);
         hr_rwds : inout std_logic;
         hr_reset : out std_logic;
         hr_clk_p : out std_logic;
         hr2_d : inout unsigned(7 downto 0);
         hr2_rwds : inout std_logic;
         hr2_reset : out std_logic;
         hr2_clk_p : out std_logic;
         hr_cs0 : out std_logic := '1';
         hr_cs1 : out std_logic := '1'
         );
end component;

-- HyperRAM control and data signals
signal hram_read_request      : std_logic;
signal hram_write_request     : std_logic;
signal hram_address           : unsigned(26 downto 0);
signal hram_wdata_ff          : unsigned(7 downto 0)  := (others => '0');
signal hram_rdata             : unsigned(7 downto 0);
signal hram_data_ready_strobe : std_logic;
signal hram_busy              : std_logic;

-- Controller logic
signal hram_addr_lo_ff        : unsigned(15 downto 0) := (others => '0');
signal hram_addr_hi_ff        : unsigned(15 downto 0) := (others => '0');
signal hram_rdata_ff          : unsigned(7 downto 0)  := (others => '0');
signal reg_status_ff          : std_logic_vector(1 downto 0) := "00";
signal action_cnt             : unsigned(3 downto 0)  := (others => '0');
signal set_action_cnt         : unsigned(3 downto 0);
signal rd_action_cnt          : unsigned(7 downto 0)  := (others => '0');
signal set_rd_action_cnt      : unsigned(7 downto 0);
signal dbg_ever_wrote         : unsigned(7 downto 0) := (others => '0');

begin

   HRAM : hyperram
   port map (
      pixelclock => clk,
      clock163 => clk2x,
      clock325 => clk4x,
      read_request => hram_read_request,
      write_request => hram_write_request,
      address => hram_address,
      wdata => hram_wdata_ff,
      rdata => hram_rdata,
      data_ready_strobe => hram_data_ready_strobe,
      busy => hram_busy,
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
   
   dbg_ever_wrote_handler : process(reset, hram_write_request, hram_wdata_ff)
   begin
      if reset = '1' then
         dbg_ever_wrote <= (others => '0');
      else
         if rising_edge(hram_write_request) then
            dbg_ever_wrote <= hram_wdata_ff;
         end if;
      end if;
   end process;
     
   action_count_handler : process(clk, action_cnt, set_action_cnt)
   begin
      if set_action_cnt /= x"0" then
         action_cnt <= set_action_cnt;
      else
         if rising_edge(clk) then
            if action_cnt /= x"0" then
               action_cnt <= action_cnt - 1;
            end if;
         end if;
      end if;
   end process;
   
   rd_action_count_handler : process(clk, rd_action_cnt, set_rd_action_cnt)
   begin
      if set_rd_action_cnt /= x"0" then
         rd_action_cnt <= set_rd_action_cnt;
      else
         if rising_edge(clk) then
            if rd_action_cnt /= x"0" then
               rd_action_cnt <= rd_action_cnt - 1;
            end if;
         end if;
      end if;
   end process;
   
   read_byte : process(clk, reset, hram_data_ready_strobe, hram_rdata)
   begin
      if reset = '1' then
         hram_rdata_ff <= (others => '0');
      else
         if rising_edge(clk) then
            if hram_data_ready_strobe = '1' then
               hram_rdata_ff <= hram_rdata;
            end if;
         end if;
      end if;
   end process;
     
   read_registers : process(hram_en, hram_we, hram_reg, hram_data_ready_strobe, hram_busy, hram_address, hram_rdata_ff)
   begin
      if hram_en = '1' and hram_we = '0' then
         case hram_reg is
            
            -- read low word of address
            when x"1" => cpu_data <= std_logic_vector(hram_address(15 downto 0));
            
            -- read (partial) high word of address
            when x"2" => cpu_data <= std_logic_vector("00000" & hram_address(26 downto 16));
            
            -- read data
            when x"3" =>
               hram_read_request <= '1';
               cpu_data <= (others => '0');
            when x"4" =>
               cpu_data <= x"00" & std_logic_vector(hram_rdata_ff);
               
            -- debug
            when x"5" =>
               cpu_data <= x"00" & std_logic_vector(dbg_ever_wrote);
                        
            when others =>
               cpu_data <= (others => '0');
         end case;
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;

   write_registers : process(clk, reset, hram_en, hram_we, hram_reg, cpu_data)
   begin
      set_action_cnt <= x"0";
      if reset = '1' then
         hram_addr_lo_ff <= (others => '0');
         hram_addr_hi_ff <= (others => '0');
         hram_wdata_ff <= (others => '0');
      else
         if falling_edge(clk) then
            if hram_en = '1' and hram_we = '1' then
               case hram_reg is
               
                  -- write low word of address
                  when x"1" => hram_addr_lo_ff <= unsigned(cpu_data);
                  
                  -- write high word of address
                  when x"2" => hram_addr_hi_ff <= unsigned(cpu_data);
                  
                  -- write data register
                  when x"3" =>
                     hram_wdata_ff <= unsigned(cpu_data(7 downto 0));
                     set_action_cnt <= x"2";
                  
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;

   -- map status register to HRAM control signals;
   hram_write_request <= '1' when action_cnt = x"1" else '0';
--   hram_read_request <= '1' when rd_action_cnt = x"1" else '0';
   
   -- build address signal from two flip-flops
   hram_address <= hram_addr_hi_ff(10 downto 0) & hram_addr_lo_ff(15 downto 0);   
   
   -- let CPU wait while reading or writing
   hram_cpu_ws <= hram_busy;
end beh;
