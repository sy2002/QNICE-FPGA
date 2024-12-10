-- QNICE-MEGA65 HyperRAM controller
-- done by sy2002 in April to August 2020
--
-- Wraps the MEGA65 HyperRAM controller so that it can be connected
-- to the QNICE CPU's data bus and controled via MMIO. 
-- CPU wait states are automatically inserted by the HyperRAM controller.
-- data_out goes to zero, if not enabled
--
-- Registers:
--
-- Register $FFF0: Low word of address  (15 downto 0)
-- Register $FFF1: High word of address (26 downto 16)
-- Register $FFF2: 8-bit data in/out (native mode: HyperRAM is 8-bit)
-- Register $FFF3: 16-bit data in/out (leads to address being multiplied by two)

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
   data_in     : in std_logic_vector(15 downto 0);
   data_out    : out std_logic_vector(15 downto 0);
   
   -- hardware connections
   hr_d        : inout unsigned(7 downto 0); -- Data/Address
   hr_rwds     : inout std_logic;            -- RW Data strobe
   hr_reset    : out std_logic;              -- Active low RESET line to HyperRAM
   hr_clk_p    : out std_logic;
   hr_cs0      : out std_logic
);
end hyperram_ctl;

architecture beh of hyperram_ctl is

component hyperram is
  port ( pixelclock : in std_logic;
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

         -- 16-bit enhancements
         wen_hi : in std_logic;            
         wen_lo : in std_logic;                  
         wdata_hi : in unsigned(7 downto 0);
         rdata_hi : out unsigned(7 downto 0);
         rdata_16en : in std_logic;
         
         -- HyperRAM hardware signals
         hr_d : inout unsigned(7 downto 0);
         hr_rwds : inout std_logic;
         hr_reset : out std_logic;
         hr_clk_p : out std_logic;
         hr_cs0 : out std_logic
         );
end component;

-- HyperRAM control and data signals
signal hram_read_request      : std_logic;
signal hram_write_request     : std_logic;
signal hram_address           : unsigned(26 downto 0);
signal hram_wdata_ff          : unsigned(15 downto 0)  := (others => '0');
signal hram_rdata             : unsigned(15 downto 0);
signal hram_data_ready_strobe : std_logic;
signal hram_busy              : std_logic;
signal hram_wen_hi            : std_logic;            
signal hram_wen_lo            : std_logic;
signal hram_rdata_16en        : std_logic;

-- Controller logic
signal hram_addr_lo_ff        : unsigned(15 downto 0) := (others => '0');
signal hram_addr_hi_ff        : unsigned(15 downto 0) := (others => '0');
signal hram_rdata_ff          : unsigned(15 downto 0)  := (others => '0');
signal hram_16bit_ff          : std_logic := '0';


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
signal fsm_hram_rdata         : unsigned(15 downto 0);
signal fsm_hram_16bit         : std_logic;


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
      wdata => hram_wdata_ff(7 downto 0),
      wdata_hi => hram_wdata_ff(15 downto 8),
      rdata => hram_rdata(7 downto 0),
      rdata_hi => hram_rdata(15 downto 8),
      wen_hi => hram_wen_hi,            
      wen_lo => hram_wen_lo,
      rdata_16en => hram_rdata_16en,      
      data_ready_strobe => hram_data_ready_strobe,
      busy => hram_busy,
      hr_d => hr_d,
      hr_rwds => hr_rwds,
      hr_reset => hr_reset,
      hr_clk_p => hr_clk_p,
      hr_cs0 => hr_cs0
   );
               
   fsm_advance_state : process(clk, reset)
   begin
      if reset = '1' then
         state_ff <= s_idle;
         hram_rdata_ff <= x"0000";
         hram_16bit_ff <= '0';
         
         dbg_chkadd_ff <= (others => '0');
      else
         if rising_edge(clk) then
            state_ff <= fsm_state_next;
            hram_rdata_ff <= fsm_hram_rdata;
            hram_16bit_ff <= fsm_hram_16bit;
            
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
                               hram_16bit_ff, hram_reg, hram_en, hram_we)
   begin
      hram_cpu_ws <= '0';
      hram_read_request <= '0';
      hram_write_request <= '0';
      hram_wen_lo <= '1';
      hram_wen_hi <= '0';      
      hram_rdata_16en <= '0';      

      fsm_state_next <= state_next;
      fsm_chkadd <= x"0000";
      fsm_hram_rdata <= hram_rdata_ff;
      fsm_hram_16bit <= hram_16bit_ff;
                  
      case state_ff is
         when s_idle =>
        
            -- detect 16-bit mode       
            if hram_reg = x"3" then
               fsm_hram_16bit <= '1';
            else
               fsm_hram_16bit <= '0';
            end if;
               
            -- start read process
            if hram_en = '1' and hram_we = '0' and (hram_reg = x"2" or hram_reg = x"3") then
               hram_cpu_ws <= '1';
               if hram_busy = '0' then
                  fsm_state_next <= s_read_start;
               end if;
               
            -- start write process
            elsif hram_en = '1' and hram_we = '1' and (hram_reg = x"2" or hram_reg = x"3") then
               hram_cpu_ws <= '1';
               if hram_busy = '0' then
                  fsm_state_next <= s_write1;
               end if;
            end if;
            
         -- READING
            
         when s_read_start =>
            hram_cpu_ws <= '1';
            hram_read_request <= '1';
            hram_rdata_16en <= hram_16bit_ff;            
            fsm_chkadd <= x"0100";
            if hram_busy = '0' and hram_data_ready_strobe = '0' then
               fsm_state_next <= s_read_start;
            else
               hram_read_request <= '0';
               hram_rdata_16en <= '0'; -- is this correct?            
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
            if hram_en = '1' and hram_we = '0' and (hram_reg = x"2" or hram_reg = x"3") then
               fsm_state_next <= s_read_waitforcpu;
            end if;
            
         -- WRITING
            
         when s_write1 =>
            hram_write_request <= '1';
            hram_wen_hi <= hram_16bit_ff;                        
         
         -- TODO: Check, if necessary
         when s_write2 =>
            null;
            
      end case;      
   end process;
                      
   read_registers : process(hram_en, hram_we, hram_reg, hram_data_ready_strobe, hram_busy, 
                            hram_address, hram_rdata_ff, dbg_chkadd_ff)
   begin
      data_out <= (others => '0');
   
      if hram_en = '1' and hram_we = '0' then
         case hram_reg is
            
            -- read low word of address
            when x"0" => data_out <= std_logic_vector(hram_address(15 downto 0));
            
            -- read (partial) high word of address
            when x"1" => data_out <= std_logic_vector("00000" & hram_address(26 downto 16));
            
            -- read 8-bit data
            when x"2" =>
               data_out <= x"00" & std_logic_vector(hram_rdata_ff(7 downto 0));
               
            -- read 16-bit data
            when x"3" =>
               data_out <= std_logic_vector(hram_rdata_ff);
               
            -- debug              
            when x"6" =>
               data_out <= std_logic_vector(dbg_chkadd_ff);
                        
            when others =>
               data_out <= (others => '0');
         end case;
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
                  when x"0" => hram_addr_lo_ff <= unsigned(data_in);
                  
                  -- write high word of address
                  when x"1" => hram_addr_hi_ff <= unsigned(data_in);
                  
                  -- write 8-bit data register
                  when x"2" =>
                     hram_wdata_ff <= x"00" & unsigned(data_in(7 downto 0));
                     
                  -- write 16-bit data register
                  when x"3" =>
                     hram_wdata_ff <= unsigned(data_in);    
                     
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;
      
   calc_hram_address : process(hram_addr_hi_ff, hram_addr_lo_ff, hram_16bit_ff, fsm_hram_16bit)
   begin
      -- 8-bit mode: address = plain concatenation of hi and low word
      if hram_16bit_ff = '0'  and fsm_hram_16bit = '0' then
         hram_address <= hram_addr_hi_ff(10 downto 0) & hram_addr_lo_ff(15 downto 0);
         
      -- 16-bit mode: address is x2
      -- multiplication is done by a shift left which itself is done by wiring the
      -- two source flip flops appropriately, so that everything happens combinatorically in "no time"
      else
         hram_address(26 downto 17) <= hram_addr_hi_ff(9 downto 0);
         hram_address(16 downto 1)  <= hram_addr_lo_ff(15 downto 0);
         hram_address(0)            <= '0';
      end if;      
   end process;
            
end beh;
