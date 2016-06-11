-- SD Card Interface
-- wraps XESS Corp's SdCardCtrl into a state machine that makes it compatible to the QNICE-FPGA architecture
-- utilizes an internal 512-byte RAM buffer using the byte_bram component
-- meant to be connected with the QNICE CPU as data I/O controled through MMIO
-- tristate outputs go high impedance when not enabled
--
-- registers:
-- 0 : low word of 32bit linear SD card block address
-- 1 : high word of 32bit linear SD card block address
-- 2 : "cursor" to navigate the 512-byte data buffer
-- 3 : read/write 1 byte from/to the 512-byte data buffer
-- 4 : error code of last operation (read only)
-- 5 : command and status register (write to execute command)
--     SD-Opcodes (CSR):    0x0000  Reset SD card
--                          0x0001  Read 512 bytes from the linear block address
--                          0x0002  Write 512 bytes to the linear block address
--     bits 0..2 are write-only (reading always returns 0)
--     bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
--                                         a case, the error code is in IO$SD_ERROR and
--                                          you need to reset the controller to go on
--     bit 15 of the CSR is the busy bit: 1, if current operation is still running
--
-- done by sy2002 in June 2016

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdcard is
port (
   clk      : in std_logic;         -- system clock
   reset    : in std_logic;         -- async reset
   
   -- registers
   en       : in std_logic;         -- enable for reading from or writing to the bus
   we       : in std_logic;         -- write to the registers via system's data bus
   reg      : in std_logic_vector(2 downto 0);      -- register selector
   data     : inout std_logic_vector(15 downto 0);  -- system's data bus
   
   -- hardware interface
   sd_reset : out std_logic;
   sd_clk   : out std_logic;
   sd_mosi  : out std_logic;
   sd_miso  : in std_logic
);
end sdcard;

architecture Behavioral of sdcard is

-- SD Card controller
component SdCardCtrl is
generic (
    FREQ_G          : real                            -- Master clock frequency (MHz).
);
port (
    -- Host-side interface signals.
    clk_i      : in  std_logic;                       -- Master clock.
    reset_i    : in  std_logic;                       -- active-high, synchronous reset.
    rd_i       : in  std_logic;                       -- active-high read block request.
    wr_i       : in  std_logic;                       -- active-high write block request.
    continue_i : in  std_logic;                       -- If true, inc address and continue R/W.
    addr_i     : in  std_logic_vector(31 downto 0);   -- Block address.
    data_i     : in  std_logic_vector(7 downto 0);    -- Data to write to block.
    data_o     : out std_logic_vector(7 downto 0);    -- Data read from block.
    busy_o     : out std_logic;                       -- High when controller is busy performing some operation.
    hndShk_i   : in  std_logic;                       -- High when host has data to give or has taken data.
    hndShk_o   : out std_logic;                       -- High when controller has taken data or has data to give.
    error_o    : out std_logic_vector(15 downto 0);
    
    -- I/O signals to the external SD card.
    cs_bo      : out std_logic;                       -- Active-low chip-select.
    sclk_o     : out std_logic;                       -- Serial clock to SD card.
    mosi_o     : out std_logic;                       -- Serial data output to SD card.
    miso_i     : in  std_logic                        -- Serial data input from SD card.
);
end component;

-- 8-bit BRAM with a 16-bit address bus
component byte_bram is
generic (
   SIZE_BYTES     : integer
);
port (
   clk            : in std_logic;

   we             : in std_logic;
   
   address_i      : in std_logic_vector(15 downto 0);
   address_o      : in std_logic_vector(15 downto 0);
   data_i         : in std_logic_vector(7 downto 0);
   data_o         : out std_logic_vector(7 downto 0)
);
end component;

-- RAM signals (512 byte buffer RAM)
signal ram_we           : std_logic;
signal ram_addr_i       : std_logic_vector(15 downto 0);
signal ram_addr_o       : std_logic_vector(15 downto 0);
signal ram_data_i       : std_logic_vector(7 downto 0);
signal ram_data_o       : std_logic_vector(7 downto 0);

signal buffer_ptr       : unsigned(15 downto 0);         -- pointer to 512 byte buffer
signal reset_buffer_ptr : std_logic;
signal current_byte     : std_logic_vector(7 downto 0);  -- byte read in the last read operation

signal ram_we_duetosdc : std_logic;                      -- write ram due to SD card reading
signal ram_we_duetowrrg : std_logic;                     -- write to ram due to a write to register 3
signal ram_di_duetosdc : std_logic_vector(7 downto 0);   -- ram data in due to SD card reading
signal ram_di_duetowrrg : std_logic_vector(7 downto 0);  -- ram data in due to a write to register 3
signal ram_ai_duetosdc : std_logic_vector(15 downto 0);  -- ram write address due to SD card access
signal ram_ai_duetowrrg : std_logic_vector(15 downto 0); -- ram write address due to write to register 3

-- SD Card controller signals
signal sd_sync_reset    : std_logic;
signal sd_block_read    : std_logic;
signal sd_block_write   : std_logic;
signal sd_block_address : std_logic_vector(31 downto 0);
signal sd_byte_write    : std_logic_vector(7 downto 0);
signal sd_byte_read     : std_logic_vector(7 downto 0);
signal sd_busy          : std_logic;
signal sd_hndshk_i      : std_logic;
signal sd_hndshk_o      : std_logic;
signal sd_error         : std_logic_vector(15 downto 0);

-- fsm control signals
signal fsm_sync_reset   : std_logic;
signal fsm_block_read   : std_logic;
signal fsm_block_write  : std_logic;
signal fsm_block_addr   : std_logic_vector(31 downto 0);
signal fsm_byte_write   : std_logic_vector(7 downto 0);
signal fsm_hndshk_i     : std_logic;
signal fsm_current_byte : std_logic_vector(7 downto 0);

-- flip/flops to save register values
signal reg_addr_lo      : std_logic_vector(15 downto 0);
signal reg_addr_hi      : std_logic_vector(15 downto 0);
signal reg_data_pos     : std_logic_vector(15 downto 0);
signal reg_data         : std_logic_vector(7 downto 0);
signal write_data       : std_logic_vector(1 downto 0);   -- mini "fsm" to store "reg_data" to RAM
signal cmd_reset        : std_logic;   -- CSR opcode 0x0000
signal cmd_read         : std_logic;   -- CSR opcode 0x0001
signal cmd_write        : std_logic;   -- CSR opcode 0x0002


signal reset_cmd_reset  : std_logic;
signal reset_cmd_read   : std_logic;
signal reset_cmd_write  : std_logic;

type sd_fsm_type is (

   sds_idle,
   
   sds_busy,
   sds_error,

   sds_reset1,
   sds_reset2,
   
   sds_read_start,
   sds_read_wait_for_byte,
   sds_read_store_byte,
   sds_read_handshake,
   sds_read_inc_ptr,   
   
   sds_write,
   
   sds_std_seq
);

signal sd_state         : sd_fsm_type;
signal sd_state_next    : sd_fsm_type;
signal fsm_state_next   : sd_fsm_type;

begin

   -- 512 byte buffer RAM (SD card is configured to read/write 512 byte blocks)
   buffer_ram : byte_bram
      generic map (
         SIZE_BYTES => 512
      )
      port map
      (
         clk => clk,
         we => ram_we,
         address_i => ram_addr_i,
         address_o => ram_addr_o,
         data_i => ram_data_i,
         data_o => ram_data_o
      );
      
   -- SD Carc Controller
   sdctl : SdCardCtrl
      generic map (
         FREQ_G => 50.0                   -- @TODO should not be hardcoded here (TODO.txt)
      )
      port map (
         clk_i => clk,
         reset_i => sd_sync_reset,
         rd_i => sd_block_read,
         wr_i => sd_block_write,
         continue_i => '0',
         addr_i => sd_block_address,
         data_i => sd_byte_write,
         data_o => sd_byte_read,
         busy_o => sd_busy,
         hndShk_i => sd_hndshk_i,
         hndShk_o => sd_hndshk_o,
         error_o => sd_error,
         cs_bo => sd_reset,
         sclk_o => sd_clk,
         mosi_o => sd_mosi,
         miso_i => sd_miso
      );
      
   fsm_advance_state : process(clk, reset)
   begin
      if reset = '1' then
         sd_state <= sds_reset1;
         
         sd_sync_reset <= '0';
         sd_block_read <= '0';
         sd_block_write <= '0';
         sd_block_address <= (others => '0');
         sd_byte_write <= (others => '0');
         sd_hndshk_i <= '0';
         
         current_byte <= (others => '0');
      else
         if rising_edge(clk) then
            if fsm_state_next = sds_std_seq then
               sd_state <= sd_state_next;
            else
               sd_state <= fsm_state_next;
            end if;
            
            sd_sync_reset <= fsm_sync_reset;
            sd_block_read <= fsm_block_read;
            sd_block_write <= fsm_block_write;
            sd_block_address <= fsm_block_addr;
            sd_byte_write <= fsm_byte_write;
            sd_hndshk_i <= fsm_hndshk_i;
            
            current_byte <= fsm_current_byte;
         end if;
      end if;
   end process;
   
   fsm_output_decode : process(sd_state, sd_busy, sd_error, sd_sync_reset, sd_block_read, sd_block_write,
                               sd_block_address, sd_byte_read, sd_byte_write, sd_hndshk_i, sd_hndshk_o,
                               current_byte, cmd_read, reg_addr_hi, reg_addr_lo)
   begin
      fsm_sync_reset <= '0';
      fsm_block_read <= sd_block_read;
      fsm_block_write <= sd_block_write;
      fsm_block_addr <= sd_block_address;
      fsm_byte_write <= sd_byte_write;
      fsm_hndshk_i <= sd_hndshk_i;
      fsm_state_next <= sds_std_seq;
      fsm_current_byte <= current_byte;
      
      reset_cmd_reset <= '0';
      reset_cmd_read <= '0';
      reset_cmd_write <= '0';
      reset_buffer_ptr <= '0';
      
      ram_we_duetosdc <= '0';
      ram_di_duetosdc <= (others => '0');
      
      case sd_state is
      
         when sds_idle =>
            if cmd_reset = '1' then
               fsm_state_next <= sds_reset1;
            elsif cmd_read = '1' then
               fsm_state_next <= sds_read_start;
            end if;
            
         when sds_error =>
            if cmd_reset = '1' then
               fsm_state_next <= sds_reset1;
            end if;
            
         when sds_read_start =>
            reset_cmd_read <= '1';
            
            -- address and read strobe needs to stay until
            -- the controller signals busy
            if sd_busy = '0' then
               fsm_state_next <= sds_read_start;
               
               -- strobe address and read request
               fsm_block_addr <= reg_addr_hi & reg_addr_lo;
               fsm_block_read <= '1';
               reset_buffer_ptr <= '1';
            else
               fsm_block_read <= '0';
               fsm_block_addr <= (others => '0');
            end if;         
            
         when sds_read_wait_for_byte =>
            -- wait, until the byte arrived
            if sd_hndshk_o = '0' or sd_busy = '0' then
            
               -- all bytes read or error
               if sd_busy = '0' then
                  fsm_state_next <= sds_busy; -- error handling or fall back to idle
               else
                  fsm_state_next <= sds_read_wait_for_byte;
               end if;
            else
               -- prepare to store the arrived byte
               fsm_current_byte <= sd_byte_read;
               ram_we_duetosdc <= '1';
               ram_di_duetosdc <= sd_byte_read;
            end if;
            
         when sds_read_store_byte =>
            ram_we_duetosdc <= '1';
            ram_di_duetosdc <= current_byte;
            
         when sds_read_handshake =>
            -- signal to controller that we stored the byte
            fsm_hndshk_i <= '1';
            
         when sds_read_inc_ptr =>
            -- check for error condition
            if sd_busy = '0' then
               fsm_state_next <= sds_busy;
            -- wait for the controller to acknowledge
            elsif sd_hndshk_o = '1' then
               fsm_state_next <= sds_read_inc_ptr;
            else
               fsm_hndshk_i <= '0';
               
               -- error handling (if busy goes down here, there must be an error)
               if sd_busy = '0' then
                  fsm_state_next <= sds_busy; -- the sds_busy state does error handling
               end if;
            end if;
                  
         when sds_busy =>
            if cmd_reset = '1' then
               fsm_state_next <= sds_reset1;
            elsif sd_busy = '0' then
               if sd_error = x"0000" then
                  fsm_state_next <= sds_idle;
               else
                  fsm_state_next <= sds_error;
               end if;
            end if;
      
         when sds_reset1 =>
            reset_cmd_reset <= '1';
            fsm_sync_reset <= '1';
            
         when sds_reset2 =>
            fsm_sync_reset <= '1';
            
         when others => null;
      
      end case;
   end process;
   
   fsm_next_state_decode : process(sd_state, sd_busy)
   begin
      case sd_state is           
         when sds_reset1               => sd_state_next <= sds_reset2;
         when sds_reset2               => sd_state_next <= sds_busy;
         when sds_read_start           => sd_state_next <= sds_read_wait_for_byte;
         when sds_read_wait_for_byte   => sd_state_next <= sds_read_store_byte;
         when sds_read_store_byte      => sd_state_next <= sds_read_handshake;
         when sds_read_handshake       => sd_state_next <= sds_read_inc_ptr;
         when sds_read_inc_ptr         => sd_state_next <= sds_read_wait_for_byte;
         when others                   => sd_state_next <= sd_state;
      end case;
   end process;
   
   inc_buffer_pointer_while_reading : process(sd_hndshk_i, reset, reset_buffer_ptr)
   begin
      if reset = '1' or reset_buffer_ptr = '1' then
         buffer_ptr <= (others => '0');
      else
         if rising_edge(sd_hndshk_i) then
            if sd_state = sds_read_handshake or sd_state = sds_read_inc_ptr then
               buffer_ptr <= buffer_ptr + 1;
            end if;
         end if;
      end if;
   end process;
   
   read_sdcard_registers : process(en, we, reg, reg_addr_lo, reg_addr_hi, reg_data_pos, reg_data, 
                                   sd_state, sd_error, ram_data_o)
   variable is_busy : std_logic;
   variable is_error : std_logic;
   --variable state_number : std_logic_vector(15 downto 0);
   begin
      if sd_state = sds_error or sd_error /= x"0000" then
         is_error := '1';
         is_busy  := '0';
      else
         is_error := '0';
         if sd_state /= sds_idle then
            is_busy := '1';
         else
            is_busy := '0';
         end if;         
      end if;
      
--      case sd_state is
--         when sds_idle => state_number := x"F001";
--         when sds_busy => state_number := x"F002";
--         when sds_error => state_number := x"F003";
--         when sds_reset1 => state_number := x"F004";
--         when sds_reset2 => state_number := x"F005";
--         when sds_read_start => state_number := x"F006";
--         when sds_read_wait_for_byte => state_number := x"F007";
--         when sds_read_store_byte => state_number := x"F008";
--         when sds_read_handshake => state_number := x"F009";
--         when sds_read_inc_ptr => state_number := x"F010";
--         when sds_write => state_number := x"F011";
--         when sds_std_seq => state_number := x"F012";
--         when others => state_number := x"FFFF";
--      end case;
     
      if en = '1' and we = '0' then
         case reg is
            when "000" => data <= reg_addr_lo;
            when "001" => data <= reg_addr_hi;
            when "010" => data <= reg_data_pos;            
            when "011" => data <= "00000000" & ram_data_o;
            when "100" => data <= sd_error;
            when "101" => data <= is_busy & is_error & "00000000000000";
            when others => data <= (others => '0');
         end case;
      else
         data <= (others => 'Z');
      end if;
   end process;
   
   write_sdcard_registers : process(clk, reset)
   begin
      if reset = '1' then
         reg_addr_lo <= (others => '0');
         reg_addr_hi <= (others => '0');
         reg_data_pos <= (others => '0');
         reg_data <= (others => '0');
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' then
               case reg is               
                  when "000" => reg_addr_lo <= data;
                  when "001" => reg_addr_hi <= data;
                  when "010" => reg_data_pos <= data;
                  when "011" => reg_data <= data(7 downto 0);
                  when others => null;               
               end case;
            end if;
         end if;
      end if;
   end process;
   
   detect_write_data : process(clk, reset, write_data)
   begin
      if reset = '1' then
         write_data <= "00";
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' and reg = "011" then
               write_data <= "01";
            else
               if write_data = "01" then
                  write_data <= "10";
               elsif write_data = "10" then
                  write_data <= "00";
               end if;
            end if;
         end if;
      end if;
   end process;
   
   detect_cmd_reset : process(clk, reset, reset_cmd_reset)
   begin
      if reset = '1' or reset_cmd_reset = '1' then
         cmd_reset <= '0';
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' then
               if reg = "101" and data = x"0000" then
                  cmd_reset <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;
   
   detect_cmd_read : process(clk, reset, reset_cmd_read)
   begin
      if reset = '1' or reset_cmd_read = '1' then
         cmd_read <= '0';
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' then
               if reg = "101" and data = x"0001" then
                  cmd_read <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;
      
   decide_ram_data_i_and_ram_we : process(sd_state, ram_we_duetosdc, ram_we_duetowrrg,
                                          ram_di_duetosdc, ram_di_duetowrrg, ram_ai_duetosdc, ram_ai_duetowrrg)
   begin
      if sd_state = sds_idle then
         ram_we <= ram_we_duetowrrg;
         ram_addr_i <= ram_ai_duetowrrg;
         ram_data_i <= ram_di_duetowrrg;
      else
         ram_we <= ram_we_duetosdc;
         ram_addr_i <= ram_ai_duetosdc;
         ram_data_i <= ram_di_duetosdc;
      end if;
   end process;
   
   ram_we_duetowrrg <= write_data(0) or write_data(1);
   ram_ai_duetowrrg <= reg_data_pos;
   ram_di_duetowrrg <= reg_data;
   ram_ai_duetosdc <= std_logic_vector(buffer_ptr);
   ram_addr_o <= std_logic_vector(reg_data_pos);   
   
end Behavioral;
