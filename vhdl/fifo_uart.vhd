-- UART with FIFO
-- meant to be connected with the QNICE CPU as data I/O is through MMIO
-- tristate outputs go high impedance when not enabled
-- 8-N-1, no error state handling, no flow control
-- DIVISOR assumes a 100 MHz system clock
-- done by sy2002 and vaxman in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity fifo_uart is
generic (
   DIVISOR: natural;             -- DIVISOR = 100,000,000 / (16 x BAUD_RATE)
   -- 2400 -> 2604
   -- 9600 -> 651
   -- 115200 -> 54
   -- 1562500 -> 4
   -- 2083333 -> 3
   FIFO_SIZE: natural            -- choose one of these values: 8, 16, 32, 64, ...
);
port (
   clk            : in std_logic;                       
   reset          : in std_logic;

   -- physical interface
   rx             : in std_logic;
   tx             : out std_logic;
   rts            : in std_logic;
   cts            : out std_logic;
   
   -- conntect to CPU's address and data bus (data high impedance when en=0)
   cpu_addr       : in std_logic_vector(15 downto 0);
   cpu_data_dir   : in std_logic;
   cpu_data_valid : in std_logic;  
   cpu_data       : inout std_logic_vector(15 downto 0) 
);
end fifo_uart;

architecture beh of fifo_uart is

component basic_uart is
generic (
   DIVISOR: natural
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
end component;

-- FIFO
type FIFO_RAM is array(0 to FIFO_SIZE - 1) of std_logic_vector(8 downto 0);
signal FIFO : FIFO_RAM := (others => "000000000");
signal FIFO_WP : unsigned(integer(ceil(log2(real(FIFO_SIZE)))) - 1 downto 0) := (others => '0');
signal FIFO_RP : unsigned(integer(ceil(log2(real(FIFO_SIZE)))) - 1 downto 0) := (others => '0');

-- UART control signals
signal uart_rx_data           : std_logic_vector(7 downto 0);
signal uart_rx_enable         : std_logic;
signal uart_tx_data           : std_logic_vector(7 downto 0);
signal uart_tx_enable         : std_logic;
signal uart_tx_ready          : std_logic;

signal rx_resetvalid          : std_logic := '0';

begin

   -- UART
   uart : basic_uart
      generic map
      (
         DIVISOR => DIVISOR
      )
      port map
      (
         clk => CLK,
         reset => reset,
         rx_data => uart_rx_data,
         rx_enable => uart_rx_enable,
         tx_data => uart_tx_data,
         tx_enable => uart_tx_enable,
         tx_ready => uart_tx_ready,
         rx => rx,
         tx => tx
      );
   
   uart_rx : process(uart_rx_enable, uart_rx_data, rx_resetvalid, FIFO_RP, FIFO_WP, reset)
   begin
      if rx_resetvalid = '1' or reset = '1' then
         if reset = '1' then
            FIFO(0)(8) <= '0';
         else
            FIFO(to_integer(FIFO_RP))(8) <= '0';
         end if;
      else
         if rising_edge(uart_rx_enable) then
            FIFO(to_integer(FIFO_WP))(7 downto 0) <= uart_rx_data;
            FIFO(to_integer(FIFO_WP))(8) <= '1';
         end if;
      end if;
   end process;
         
   uart_inc_wp : process(uart_rx_enable, FIFO_WP, reset)
   begin
      if reset = '1' then
         FIFO_WP <= (others => '0');
      else
         if falling_edge(uart_rx_enable) then
            FIFO_WP <= FIFO_WP + 1;
         end if;
      end if;
   end process;
      
   uart_inc_rp : process(rx_resetvalid, FIFO_RP, reset)
   begin
      if reset = '1' then
         FIFO_RP <= (others => '0');
      else
         if falling_edge(rx_resetvalid) then
            FIFO_RP <= FIFO_RP + 1;
         end if;
      end if;
   end process;
   
   uart_cts_controller : process (FIFO_RP, FIFO_WP)
   begin
      if abs(signed(FIFO_RP) - signed(FIFO_WP)) > (FIFO_SIZE / 4) then
         cts <= '1';
      else
         cts <= '0';
      end if;
   end process;
               
   uart_mmio : process(cpu_addr, cpu_data, cpu_data_dir, cpu_data_valid, uart_tx_ready, FIFO, FIFO_RP, FIFO_WP)
   begin
      cpu_data <= (others => 'Z');
      uart_tx_data <= (others => 'Z');
      rx_resetvalid <= '0';
      uart_tx_enable <= '0';
      
      if cpu_addr(15 downto 4) = x"FF2" then
         case cpu_addr(3 downto 0) is
         
            -- register 1: status register
            when x"1" =>
               if cpu_data_dir = '0' then
                  cpu_data <= x"000" & "00" & uart_tx_ready & FIFO(to_integer(FIFO_RP))(8);
               end if;
               
            -- register 2: read register
            when x"2" =>
               if cpu_data_dir = '0' then
                  cpu_data <= x"00" & FIFO(to_integer(FIFO_RP))(7 downto 0);
                  rx_resetvalid <= '1';
               end if;
               
            -- register 3: write register
            when x"3" =>
               if cpu_data_dir = '1' and cpu_data_valid = '1' then
                  uart_tx_data <= cpu_data(7 downto 0);
                  uart_tx_enable <= '1';
               end if;
               
            when others =>
               cpu_data <= (others => 'Z');
               uart_tx_data <= (others => 'Z');
               rx_resetvalid <= '0';
               uart_tx_enable <= '0';                                          
         end case;
      end if;
   end process;
   
   
   
end beh;

