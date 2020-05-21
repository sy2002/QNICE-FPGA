-- QNICE-MEGA65 HyperRAM controller
-- done by sy2002 in April and May 2020
--
-- Wraps the MEGA65 HyperRAM controller so that it can be connected
-- to the QNICE CPU's data bus and controled via MMIO. 
-- CPU wait states are automatically inserted by the HyperRAM controller.
-- Goes high impedance when not enabled.
--
-- Registers:
--
-- Register $FF60: Low word of address  (15 downto 0)
-- Register $FF61: High word of address (26 downto 16)
-- Register $FF62: Data in/out

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
  Port ( pixelclock : in std_logic;
         clock163 : in std_logic;
         clock325 : in std_logic;

         -- Simple counter for number of requests received
         request_counter : out std_logic;
         
         read_request : in std_logic;
         write_request : in std_logic;
         address : in unsigned(26 downto 0);
         wdata : in unsigned(7 downto 0);
         
         rdata : out unsigned(7 downto 0);
         data_ready_strobe : out std_logic;
         busy : out std_logic;
         
         -- HyperRAM hardware signals
         hr_d : inout unsigned(7 downto 0);
         hr_rwds : inout std_logic;
         hr_reset : out std_logic;
         hr_clk_p : out std_logic;
         hr2_d : inout unsigned(7 downto 0);
         hr2_rwds : inout std_logic;
         hr2_reset : out std_logic;
         hr2_clk_p : out std_logic;
         hr_cs0 : out std_logic;
         hr_cs1 : out std_logic
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

type tHRAM_FSM_States is ( s_idle,

                           s_read_start,
                           s_read_waitfordata,
                           s_read_waitforcpu,
                           
                           s_write1,
                           s_write2
                          );

signal state_ff               : tHRAM_FSM_States := s_idle;
signal state_next             : tHRAM_FSM_States;

signal fsm_state_next         : tHRAM_FSM_States;
signal fsm_hram_rdata         : unsigned(7 downto 0)  := (others => '0');


signal dbg_chkadd_ff          : unsigned(15 downto 0)  := x"0000";
signal fsm_chkadd             : unsigned(15 downto 0);

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
               
   fsm_advance_state : process(clk, reset)
   begin
      if reset = '1' then
         state_ff <= s_idle;
         hram_rdata_ff <= x"00";
         
         dbg_chkadd_ff <= (others => '0');
      else
         if rising_edge(clk) then
            state_ff <= fsm_state_next;
            hram_rdata_ff <= fsm_hram_rdata;
            
            dbg_chkadd_ff <= dbg_chkadd_ff + fsm_chkadd;
         end if;
      end if;
   end process;
   
   fsm_next_state_decode : process (state_ff)
   begin
      case state_ff is
         when s_idle                => state_next <= s_idle;
         
         when s_read_start          => state_next <= s_read_waitfordata;
         when s_read_waitfordata    => state_next <= s_read_waitforcpu;
         when s_read_waitforcpu     => state_next <= s_idle;
         
         when s_write1              => state_next <= s_write2;
         when s_write2              => state_next <= s_idle;
      end case;
   end process;   
         
   fsm_output_decode : process(state_ff, state_next, hram_rdata_ff, hram_rdata, hram_data_ready_strobe, hram_busy,
                               hram_reg, hram_en, hram_we)
   begin
      hram_cpu_ws <= '0';
      hram_read_request <= '0';
      hram_write_request <= '0';

      fsm_state_next <= state_next;
      fsm_chkadd <= x"0000";
      fsm_hram_rdata <= hram_rdata_ff;
            
      case state_ff is
         when s_idle =>
            if hram_en = '1' and hram_we = '0' and hram_reg = x"2" then
               hram_cpu_ws <= '1';
               if hram_busy = '0' then
                  fsm_state_next <= s_read_start;
               end if;
               
            elsif hram_en = '1' and hram_we = '1' and hram_reg = x"2" then
               hram_cpu_ws <= '1';
               if hram_busy = '0' then
                  fsm_state_next <= s_write1;
               end if;
            end if;
            
         -- READING
            
         when s_read_start =>
            hram_cpu_ws <= '1';
            hram_read_request <= '1';
            fsm_chkadd <= x"0100";            
            if hram_busy = '0' and hram_data_ready_strobe = '0' then
               fsm_state_next <= s_read_start;
            else
               hram_read_request <= '0';            
               if hram_data_ready_strobe = '1' then
                  fsm_hram_rdata <= hram_rdata;
                  fsm_state_next <= s_read_waitforcpu;
               end if;
            end if;
         
         when s_read_waitfordata =>
            hram_cpu_ws <= '1'; 
            fsm_chkadd <= x"0001";
            if hram_data_ready_strobe = '1' then
               fsm_hram_rdata <= hram_rdata;
            else
               fsm_state_next <= s_read_waitfordata;
            end if;
                                   
         when s_read_waitforcpu =>
            -- wait for CPU to deassert reading so that we can synchronously reset start_read_ff
            if hram_en = '1' and hram_we = '0' and hram_reg = x"2" then
               fsm_state_next <= s_read_waitforcpu;
            end if;
            
         -- WRITING
            
         when s_write1 =>
            hram_write_request <= '1';            
         
         -- TODO: Check, if necessary
         when s_write2 =>
            null;
            
      end case;      
   end process;
                      
   read_registers : process(hram_en, hram_we, hram_reg, hram_data_ready_strobe, hram_busy, 
                            hram_address, hram_rdata_ff, dbg_chkadd_ff)
   begin
      if hram_en = '1' and hram_we = '0' then
         case hram_reg is
            
            -- read low word of address
            when x"0" => cpu_data <= std_logic_vector(hram_address(15 downto 0));
            
            -- read (partial) high word of address
            when x"1" => cpu_data <= std_logic_vector("00000" & hram_address(26 downto 16));
            
            -- read data
            when x"2" =>
               cpu_data <= x"00" & std_logic_vector(hram_rdata_ff);
               
            -- debug              
            when x"6" =>
               cpu_data <= std_logic_vector(dbg_chkadd_ff);
                        
            when others =>
               cpu_data <= (others => '0');
         end case;
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;

   write_registers : process(clk, reset)
   begin
      if reset = '1' then
         hram_addr_lo_ff <= (others => '0');
         hram_addr_hi_ff <= (others => '0');
         hram_wdata_ff <= (others => '0');
      else
         if falling_edge(clk) then
            if hram_en = '1' and hram_we = '1' then
               case hram_reg is
               
                  -- write low word of address
                  when x"0" => hram_addr_lo_ff <= unsigned(cpu_data);
                  
                  -- write high word of address
                  when x"1" => hram_addr_hi_ff <= unsigned(cpu_data);
                  
                  -- write data register
                  when x"2" =>
                     hram_wdata_ff <= unsigned(cpu_data(7 downto 0));                     
                     
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;
      
   -- build address signal from two flip-flops
   hram_address <= hram_addr_hi_ff(10 downto 0) & hram_addr_lo_ff(15 downto 0);      
end beh;
