-- Basic UART implementation
-- 8-N-1, no error state handling, no flow control
-- DIVISOR assumes a 100 MHz system clock
-- heavily inspired by http://www.bealto.com/fpga-uart_intro.html
-- done by sy2002 in August 2015

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.qnice_tools.all;

entity basic_uart is
   generic (
      DIVISOR : natural                          -- DIVISOR = 100,000,000 / (16 x BAUD_RATE)
                                                 -- 2400 -> 2604
                                                 -- 9600 -> 651
                                                 -- 115200 -> 54
                                                 -- 1562500 -> 4
                                                 -- 2083333 -> 3
   );
   port (
      clk_i       : in  std_logic;
      reset_i     : in  std_logic;

      -- client interface: receive data
      rx_data_o   : out std_logic_vector(7 downto 0); -- received byte
      rx_enable_o : out std_logic;                    -- validates received byte (1 system clock spike)

      -- client interface: send data
      tx_data_i   : in  std_logic_vector(7 downto 0); -- byte to send
      tx_enable_i : in  std_logic;                    -- validates byte to send if tx_ready is '1'
      tx_ready_o  : out std_logic;                    -- if '1', we can send a new byte, otherwise we won't take it

      -- physical interface
      uart_rx_i   : in  std_logic;
      uart_tx_o   : out std_logic
   );
end basic_uart;

architecture rtl of basic_uart is
   constant COUNTER_BITS : natural := f_log2(DIVISOR);
   type fsm_state_t is (IDLE_ST, ACTIVE_ST);      -- common to both RX and TX FSM

   type rx_state_t is
      record
         fsm_state : fsm_state_t;                  -- FSM state
         counter   : std_logic_vector(4+COUNTER_BITS-1 downto 0); -- tick count
         bits      : std_logic_vector(7 downto 0); -- received bits
         nbits     : std_logic_vector(3 downto 0); -- number of received bits (includes start bit)
         enable    : std_logic;                    -- signal we received a new byte
      end record;

   type tx_state_t is
      record
         fsm_state : fsm_state_t;                  -- FSM state
         counter   : std_logic_vector(4+COUNTER_BITS-1 downto 0); -- tick count
         bits      : std_logic_vector(8 downto 0); -- bits to emit, includes start bit
         nbits     : std_logic_vector(3 downto 0); -- number of bits left to send
         ready     : std_logic;                    -- signal we are accepting a new byte
      end record;

   signal rx_state,rx_state_next : rx_state_t;
   signal tx_state,tx_state_next : tx_state_t;

--   attribute mark_debug             : boolean;
--   attribute mark_debug of rx_state : signal is true;
--   attribute mark_debug of tx_state : signal is true;

begin

   -- RX, TX state registers update at each CLK, and RESET
   reg_process: process (clk_i) is
   begin
      if rising_edge(clk_i) then
         rx_state <= rx_state_next;
         tx_state <= tx_state_next;

         if reset_i = '1' then
            rx_state.fsm_state <= IDLE_ST;
            rx_state.bits      <= (others => '0');
            rx_state.nbits     <= (others => '0');
            rx_state.enable    <= '0';

            tx_state.fsm_state <= IDLE_ST;
            tx_state.bits      <= (others => '1');
            tx_state.nbits     <= (others => '0');
            tx_state.ready     <= '1';
         end if;
      end if;
   end process reg_process;


   -- RX FSM
   rx_process: process (rx_state, uart_rx_i) is
   begin
      case rx_state.fsm_state is

         when IDLE_ST =>
            rx_state_next.counter <= (others => '0');
            rx_state_next.bits    <= (others => '0');
            rx_state_next.nbits   <= (others => '0');
            rx_state_next.enable  <= '0';
            if uart_rx_i = '0' then
               -- start a new byte
               rx_state_next.fsm_state <= ACTIVE_ST;
            else
               -- keep idle
               rx_state_next.fsm_state <= IDLE_ST;
            end if;

         when ACTIVE_ST =>
            rx_state_next <= rx_state;
            if rx_state.counter = 8*DIVISOR then
               -- sample next RX bit (at the middle of the counter cycle)
               if rx_state.nbits = 9 then
                  rx_state_next.fsm_state <= IDLE_ST;    -- back to idle state to wait for next start bit
                  rx_state_next.enable    <= uart_rx_i;  -- OK if stop bit is '1'
               else
                  rx_state_next.bits  <= uart_rx_i & rx_state.bits(7 downto 1);
                  rx_state_next.nbits <= rx_state.nbits + 1;
               end if;
            end if;

            rx_state_next.counter <= rx_state.counter + 1;
            if rx_state.counter = 16*DIVISOR-1 then
               rx_state_next.counter <= (others => '0');
            end if;

      end case;
   end process rx_process;


   -- RX output
   rx_output: process (rx_state) is
   begin
      rx_enable_o <= rx_state.enable;
      rx_data_o   <= rx_state.bits;
   end process rx_output;


   -- TX FSM
   tx_process: process (tx_state, tx_enable_i, tx_data_i) is
   begin
      case tx_state.fsm_state is

         when IDLE_ST =>
            if tx_enable_i = '1' then
               -- start a new bit
               tx_state_next.bits      <= tx_data_i & '0';  -- data & start
               tx_state_next.nbits     <= "0000" + 10;      -- send 10 bits (includes '1' stop bit)
               tx_state_next.counter   <= (others => '0');
               tx_state_next.fsm_state <= ACTIVE_ST;
               tx_state_next.ready     <= '0';
            else
               -- keep idle
               tx_state_next.bits      <= (others => '1');
               tx_state_next.nbits     <= (others => '0');
               tx_state_next.counter   <= (others => '0');
               tx_state_next.fsm_state <= IDLE_ST;
               tx_state_next.ready     <= '1';
            end if;

         when ACTIVE_ST =>
            tx_state_next <= tx_state;
            if tx_state.counter = 16*DIVISOR-1 then
               -- send next bit
               if tx_state.nbits = 0 then
                  -- turn idle
                  tx_state_next.bits      <= (others => '1');
                  tx_state_next.nbits     <= (others => '0');
                  tx_state_next.counter   <= (others => '0');
                  tx_state_next.fsm_state <= IDLE_ST;
                  tx_state_next.ready     <= '1';
               else
                  tx_state_next.bits  <= '1' & tx_state.bits(8 downto 1);
                  tx_state_next.nbits <= tx_state.nbits - 1;
               end if;
            end if;
            tx_state_next.counter <= tx_state.counter + 1;
            if tx_state.counter = 16*DIVISOR-1 then
               tx_state_next.counter <= (others => '0');
            end if;

      end case;
   end process tx_process;


   -- TX output
   tx_output: process (tx_state) is
   begin
      tx_ready_o <= tx_state.ready;
      uart_tx_o  <= tx_state.bits(0);
   end process tx_output;

end architecture rtl;

