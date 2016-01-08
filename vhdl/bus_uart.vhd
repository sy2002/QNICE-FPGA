-- BUS UART
-- meant to be connected with the QNICE CPU as data I/O is through MMIO
-- tristate outputs go high impedance when not enabled
-- 8-N-1, no error state handling, CTS flow control
-- DIVISOR assumes a 100 MHz system clock
-- done by sy2002 and vaxman in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bus_uart is
generic (
   DIVISOR: natural              -- DIVISOR = 100,000,000 / (16 x BAUD_RATE)
   -- 2400 -> 2604
   -- 9600 -> 651
   -- 115200 -> 54
   -- 1562500 -> 4
   -- 2083333 -> 3
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
   uart_en        : in std_logic;
   uart_we        : in std_logic;
   uart_reg       : in std_logic_vector(1 downto 0);
   cpu_data       : inout std_logic_vector(15 downto 0) 
);
end bus_uart;

architecture beh of bus_uart is

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

-- UART control signals
signal uart_rx_data           : std_logic_vector(7 downto 0);
signal uart_rx_enable         : std_logic;
signal uart_tx_data           : std_logic_vector(7 downto 0);
signal uart_tx_enable         : std_logic;
signal uart_tx_ready          : std_logic;

-- registers
signal byte_rx_ready          : std_logic := '0';
signal reset_byte_rx_ready    : std_logic;
signal byte_rx_data           : std_logic_vector(7 downto 0);
signal byte_tx_ready          : std_logic := '0';
signal reset_byte_tx_ready    : std_logic;
signal byte_tx_data           : std_logic_vector(7 downto 0);

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
   
   receive_byte : process(uart_rx_enable, uart_rx_data, reset)
   begin
      if reset = '1' then
         byte_rx_data <= (others => '0');
      else
         if rising_edge(uart_rx_enable) then
            byte_rx_data <= uart_rx_data;
         end if;
      end if;
   end process;
   
   handle_byte_rx_ready : process(uart_rx_enable, reset, reset_byte_rx_ready)
   begin
      if reset = '1' or reset_byte_rx_ready = '1' then
         byte_rx_ready <= '0';
      else
         if rising_edge(uart_rx_enable) then
            byte_rx_ready <= '1';
         end if;
      end if;
   end process;

   send_byte : process(uart_tx_ready, byte_tx_ready, byte_tx_data)
   begin
      uart_tx_enable <= '0';
      uart_tx_data <= (others => '0');
      reset_byte_tx_ready <= '0';   
   
      if uart_tx_ready = '1' and byte_tx_ready = '1' then
         uart_tx_enable <= '1';
         uart_tx_data <= byte_tx_data;
      elsif uart_tx_ready = '0' and byte_tx_ready = '1' then
         reset_byte_tx_ready <= '1';
      end if;
   end process;

   read_registers : process(uart_en, uart_we, uart_reg, uart_tx_ready, byte_rx_ready, byte_rx_data)
   begin
      reset_byte_rx_ready <= '0';
   
      if uart_en = '1' and uart_we = '0' then
         case uart_reg is
         
            -- register 1: status register
            when "01" => cpu_data <= x"000" & "00" & uart_tx_ready & byte_rx_ready;

            -- register 2: receive (aka read) register
            when "10" =>
               cpu_data <= x"00" & byte_rx_data;
               reset_byte_rx_ready <= '1';
            
            when others => cpu_data <= (others => '0');
         end case;
      else
         cpu_data <= (others => 'Z');
      end if;
   end process;
   
   write_registers : process(clk, reset)
   begin
      if reset = '1' then
         byte_tx_data <= (others => '0');
      else
         if rising_edge(clk) then
            -- register 3: send (aka write) register
            if uart_en = '1' and uart_we = '1' and uart_reg = "11" then
               byte_tx_data <= cpu_data(7 downto 0);
            end if;
         end if;
      end if;
   end process;

   handle_tx_ready : process(clk, reset, reset_byte_tx_ready)
   begin
      if reset = '1' or reset_byte_tx_ready = '1' then
         byte_tx_ready <= '0';
      else
         if rising_edge(clk) then
            -- tx_ready listens to write operations to register 3
            if uart_en = '1' and uart_we = '1' and uart_reg = "11" then
               byte_tx_ready <= '1';
            end if;
         end if;
      end if;
   end process;
   
   cts <= byte_rx_ready;
end beh;
