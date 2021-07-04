-- Basic UART implementation
-- 8-N-1, no error state handling, no flow control
-- DIVISOR assumes a 100 MHz system clock
-- heavily inspired by http://www.bealto.com/fpga-uart_intro.html
-- done by sy2002 in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.qnice_tools.all;

entity basic_uart is
generic (
   DIVISOR: natural                           -- DIVISOR = 100,000,000 / (16 x BAUD_RATE)
   -- 2400 -> 2604
   -- 9600 -> 651
   -- 115200 -> 54
   -- 1562500 -> 4
   -- 2083333 -> 3
);
port (
   clk: in std_logic;                       
   reset: in std_logic;

   -- client interface: receive data
   rx_data: out std_logic_vector(7 downto 0); -- received byte
   rx_enable: out std_logic;                  -- validates received byte (1 system clock spike)
   
   -- client interface: send data
   tx_data: in std_logic_vector(7 downto 0);  -- byte to send
   tx_enable: in std_logic;                   -- validates byte to send if tx_ready is '1'
   tx_ready: out std_logic;                   -- if '1', we can send a new byte, otherwise we won't take it

   -- physical interface
   rx: in std_logic;
   tx: out std_logic
);
end basic_uart;

architecture beh of basic_uart is
  constant COUNTER_BITS : natural := f_log2(DIVISOR);
  type fsm_state_t is (idle, active);      -- common to both RX and TX FSM
  type rx_state_t is
  record
    fsm_state: fsm_state_t;                -- FSM state
    counter: std_logic_vector(3 downto 0); -- tick count
    bits: std_logic_vector(7 downto 0);    -- received bits
    nbits: std_logic_vector(3 downto 0);   -- number of received bits (includes start bit)
    enable: std_logic;                     -- signal we received a new byte
  end record;
  type tx_state_t is
  record
    fsm_state: fsm_state_t; -- FSM state
    counter: std_logic_vector(3 downto 0); -- tick count
    bits: std_logic_vector(8 downto 0); -- bits to emit, includes start bit
    nbits: std_logic_vector(3 downto 0); -- number of bits left to send
    ready: std_logic; -- signal we are accepting a new byte
  end record;
  
  signal rx_state,rx_state_next: rx_state_t;
  signal tx_state,tx_state_next: tx_state_t;
  signal sample: std_logic; -- 1 clk spike at 16x baud rate
  signal sample_counter: std_logic_vector(COUNTER_BITS-1 downto 0); -- should fit values in 0..DIVISOR-1
  
begin

  -- sample signal at 16x baud rate, 1 CLK spikes
  sample_process: process (clk) is
  begin
    if rising_edge(clk) then
      if sample_counter = DIVISOR-1 then
        sample <= '1';
        sample_counter <= (others => '0');
      else
        sample <= '0';
        sample_counter <= sample_counter + 1;
      end if;

      if reset = '1' then
        sample_counter <= (others => '0');
        sample <= '0';
      end if;
    end if;
  end process;

  -- RX, TX state registers update at each CLK, and RESET
  reg_process: process (clk) is
  begin
    if rising_edge(clk) then
      rx_state <= rx_state_next;
      tx_state <= tx_state_next;

      if reset = '1' then
        rx_state.fsm_state <= idle;
        rx_state.bits <= (others => '0');
        rx_state.nbits <= (others => '0');
        rx_state.enable <= '0';
        tx_state.fsm_state <= idle;
        tx_state.bits <= (others => '1');
        tx_state.nbits <= (others => '0');
        tx_state.ready <= '1';
      end if;
    end if;
  end process;
  
  -- RX FSM
  rx_process: process (rx_state,sample,rx) is
  begin
    case rx_state.fsm_state is
    
    when idle =>
      rx_state_next.counter <= (others => '0');
      rx_state_next.bits <= (others => '0');
      rx_state_next.nbits <= (others => '0');
      rx_state_next.enable <= '0';
      if rx = '0' then
        -- start a new byte
        rx_state_next.fsm_state <= active;
      else
        -- keep idle
        rx_state_next.fsm_state <= idle;
      end if;
      
    when active =>
      rx_state_next <= rx_state;
      if sample = '1' then
        if rx_state.counter = 8 then
          -- sample next RX bit (at the middle of the counter cycle)
          if rx_state.nbits = 9 then
            rx_state_next.fsm_state <= idle; -- back to idle state to wait for next start bit
            rx_state_next.enable <= rx; -- OK if stop bit is '1'
          else
            rx_state_next.bits <= rx & rx_state.bits(7 downto 1);
            rx_state_next.nbits <= rx_state.nbits + 1;
          end if;
        end if;
        rx_state_next.counter <= rx_state.counter + 1;
      end if;
      
    end case;
  end process;
  
  -- RX output
  rx_output: process (rx_state) is
  begin
    rx_enable <= rx_state.enable;
    rx_data <= rx_state.bits;
  end process;
  
  -- TX FSM
  tx_process: process (tx_state,sample,tx_enable,tx_data) is
  begin
    case tx_state.fsm_state is
    
    when idle =>
      if tx_enable = '1' then
        -- start a new bit
        tx_state_next.bits <= tx_data & '0';  -- data & start
        tx_state_next.nbits <= "0000" + 10; -- send 10 bits (includes '1' stop bit)
        tx_state_next.counter <= (others => '0');
        tx_state_next.fsm_state <= active;
        tx_state_next.ready <= '0';
      else
        -- keep idle
        tx_state_next.bits <= (others => '1');
        tx_state_next.nbits <= (others => '0');
        tx_state_next.counter <= (others => '0');
        tx_state_next.fsm_state <= idle;
        tx_state_next.ready <= '1';
      end if;
      
    when active =>
      tx_state_next <= tx_state;
      if sample = '1' then
        if tx_state.counter = 15 then
          -- send next bit
          if tx_state.nbits = 0 then
            -- turn idle
            tx_state_next.bits <= (others => '1');
            tx_state_next.nbits <= (others => '0');
            tx_state_next.counter <= (others => '0');
            tx_state_next.fsm_state <= idle;
            tx_state_next.ready <= '1';
          else
            tx_state_next.bits <= '1' & tx_state.bits(8 downto 1);
            tx_state_next.nbits <= tx_state.nbits - 1;
          end if;
        end if;
        tx_state_next.counter <= tx_state.counter + 1;
      end if;
      
    end case;
  end process;

  -- TX output
  tx_output: process (tx_state) is
  begin
    tx_ready <= tx_state.ready;
    tx <= tx_state.bits(0);
  end process;

end beh;

