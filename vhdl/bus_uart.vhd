-- BUS UART
-- meant to be connected with the QNICE CPU as data I/O is through MMIO
-- output goes zero when not enabled
-- 8-N-1, no error state handling, CTS flow control
-- DIVISOR assumes a 100 MHz system clock
-- done by sy2002 and vaxman in August 2015
-- improved by sy2002 in May 2020: Added a FIFO

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.env1_globals.all;

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
   
   -- conntect to CPU's address and data bus (data output zero when en=0)
   -- since reading takes more than one clock cycle, CPU needs wait on uart_cpu_ws
   uart_en        : in std_logic;
   uart_we        : in std_logic;
   uart_reg       : in std_logic_vector(1 downto 0);
   uart_cpu_ws    : out std_logic;
   cpu_data_in    : in std_logic_vector(15 downto 0);
   cpu_data_out   : out std_logic_vector(15 downto 0)
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

component ring_buffer is
  generic (
    RAM_WIDTH : natural;
    RAM_DEPTH : natural
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
 
    -- Write port
    wr_en : in std_logic;
    wr_data : in std_logic_vector(RAM_WIDTH - 1 downto 0);
 
    -- Read port
    rd_en : in std_logic;
    rd_valid : out std_logic;
    rd_data : out std_logic_vector(RAM_WIDTH - 1 downto 0);
 
    -- Flags
    empty : out std_logic;
    empty_next : out std_logic;
    full : out std_logic;
    full_next : out std_logic;
 
    -- The number of elements in the FIFO
    fill_count : out integer range RAM_DEPTH - 1 downto 0
  );
end component;

-- UART control signals
signal uart_rx_data           : std_logic_vector(7 downto 0);
signal uart_rx_enable         : std_logic;
signal uart_tx_data           : std_logic_vector(7 downto 0);
signal uart_tx_enable         : std_logic;
signal uart_tx_ready          : std_logic;

-- FIFO control signals
signal fifo_rd_en             : std_logic;
signal fifo_rd_valid          : std_logic;
signal fifo_rd_data           : std_logic_vector(7 downto 0);
signal fifo_empty             : std_logic;
signal fifo_full              : std_logic;

signal reading                : std_logic := '0';
signal reset_reading          : std_logic;

-- registers
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
      
   -- FIFO
   fifo : ring_buffer
      generic map
      (
         RAM_WIDTH => 8,
         RAM_DEPTH => UART_FIFO_SIZE
      )
      port map
      (
         clk => CLK,
         rst => reset,         
         wr_en => uart_rx_enable,
         wr_data => uart_rx_data,
         rd_en => fifo_rd_en,
         rd_valid => fifo_rd_valid,
         rd_data => fifo_rd_data,
         empty => fifo_empty,
         full => fifo_full
      );
         
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
   
   handle_reading : process(clk)
   begin
      if rising_edge(clk) then
         if uart_en = '1' and uart_we = '0' and uart_reg = "10" then
            reading <= '1';
         end if;

         if reset = '1' or reset_reading = '1' then
            reading <= '0';
         end if;
      end if;
   end process;
   
   read_registers : process(uart_en, uart_we, uart_reg, uart_tx_ready, fifo_empty, fifo_rd_data)
   begin 
      if uart_en = '1' and uart_we = '0' then
         case uart_reg is
         
            -- register 1: status register
            when "01" => cpu_data_out <= x"000" & "00" & uart_tx_ready & (not fifo_empty);

            -- register 2: receive (aka read) register
            when "10" =>
               cpu_data_out <= x"00" & fifo_rd_data;
            
            when others => cpu_data_out <= (others => '0');
         end case;
      else
         cpu_data_out <= (others => '0');
      end if;
   end process;
   
   write_registers : process(clk)
   begin
      if rising_edge(clk) then
         -- register 3: send (aka write) register
         if uart_en = '1' and uart_we = '1' and uart_reg = "11" then
            byte_tx_data <= cpu_data_in(7 downto 0);
         end if;

         if reset = '1' then
            byte_tx_data <= (others => '0');
         end if;
      end if;
   end process;

   handle_tx_ready : process(clk)
   begin
      if rising_edge(clk) then
         -- tx_ready listens to write operations to register 3
         if uart_en = '1' and uart_we = '1' and uart_reg = "11" then
            byte_tx_ready <= '1';
         end if;

         if reset = '1' or reset_byte_tx_ready = '1' then
            byte_tx_ready <= '0';
         end if;
      end if;
   end process;
   
   
   uart_cpu_ws <= reading;
   fifo_rd_en <= reading;
   reset_reading <= fifo_rd_valid;
   cts <= fifo_full;
end beh;
