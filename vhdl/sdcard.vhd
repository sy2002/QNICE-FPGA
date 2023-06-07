-- SD Card Interface
-- uses 512-byte block addressing on all card types, i.e.
-- address #0 is the linear data between 0 .. 511 and
-- address #1 is the linear data between 512 .. 1023, etc.
--
-- This interface wraps Lawrence Wilkinson's awesome "SimpleSDHC" component
-- (that can be found here: https://github.com/ibm2030/SimpleSDHC)
-- into a state machine that supports the MMIO logic and that
-- utilizes an internal 512-byte RAM buffer using the byte_bram component.
-- It is meant to be connected with the QNICE CPU as data I/O controled through MMIO;
-- output goes zero when not enabled.
--
-- registers:
-- 0 : low word of 32bit SD card block address
-- 1 : high word of 32bit SD card block address
-- 2 : "cursor" to navigate the 512-byte data buffer
-- 3 : read/write 1 byte from/to the 512-byte data buffer
-- 4 : error code of last operation (read only)
-- 5 : command and status register (write to execute command)
--     SD-Opcodes (CSR):    0x0000  Reset SD card
--                          0x0001  Read 512 bytes from the linear block address
--                          0x0002  Write 512 bytes to the linear block address
--     bits 0..2 are write-only (reading always returns 0)
--     bits 13 .. 12 return the card type: 00 = no card / unknown card
--                                         01 = SD V1
--                                         10 = SD V2
--                                         11 = SDHC                       
--     bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
--                                         a case, the error code is in register #4 and
--                                         you need to reset the controller to go on
--     bit 15 of the CSR is the busy bit: 1, if current operation is still running
--
-- done by sy2002 in August 2016

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
   data_in  : in std_logic_vector(15 downto 0);  -- system's data bus
   data_out : out std_logic_vector(15 downto 0);  -- system's data bus
   
   -- hardware interface
   sd_reset : out std_logic;
   sd_clk   : out std_logic;
   sd_mosi  : out std_logic;
   sd_miso  : in std_logic
);
end sdcard;

architecture beh of sdcard is

-- the actual SD Card controller that is wrapped by this state machine
component sd_controller is
port (
	cs : out std_logic;				   -- To SD card
	mosi : out std_logic;			   -- To SD card
	miso : in std_logic;			      -- From SD card
	sclk : out std_logic;			   -- To SD card
	card_present : in std_logic;	   -- From socket - can be fixed to '1' if no switch is present
	card_write_prot : in std_logic;	-- From socket - can be fixed to '0' if no switch is present, or '1' to make a Read-Only interface

	rd : in std_logic;				   -- Trigger single block read
	rd_multiple : in std_logic;		-- Trigger multiple block read
	dout : out std_logic_vector(7 downto 0);	-- Data from SD card
	dout_avail : out std_logic;		-- Set when dout is valid
	dout_taken : in std_logic;		   -- Acknowledgement for dout
	
	wr : in std_logic;				   -- Trigger single block write
	wr_multiple : in std_logic;		-- Trigger multiple block write
	din : in std_logic_vector(7 downto 0);	-- Data to SD card
	din_valid : in std_logic;		   -- Set when din is valid
	din_taken : out std_logic;		   -- Ackowledgement for din
	
	addr : in std_logic_vector(31 downto 0);	-- Block address
	erase_count : in std_logic_vector(7 downto 0); -- For wr_multiple only

	sd_error : out std_logic;		   -- '1' if an error occurs, reset on next RD or WR
	sd_busy : out std_logic;		   -- '0' if a RD or WR can be accepted
	sd_error_code : out std_logic_vector(7 downto 0); -- See above, 000=No error
	
	
	reset : in std_logic;	         -- System reset
	clk : in std_logic;		         -- twice the SPI clk (max 50MHz)
	
	-- Optional debug outputs
	sd_type : out std_logic_vector(1 downto 0);	-- Card status (see above)
	sd_fsm : out std_logic_vector(7 downto 0) := "11111111" -- FSM state (see block at end of file)
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
signal current_byte     : std_logic_vector(7 downto 0);  -- byte read in the last read operation

-- SD Card controller signals
signal sd_sync_reset    : std_logic;
signal sd_block_addr    : std_logic_vector(31 downto 0);
signal sd_block_read    : std_logic;
signal sd_block_write   : std_logic;
signal sd_din           : std_logic_vector(7 downto 0);
signal sd_dout          : std_logic_vector(7 downto 0);
signal sd_din_valid     : std_logic;
signal sd_din_taken     : std_logic;
signal sd_dout_avail    : std_logic;
signal sd_dout_taken    : std_logic;
signal sd_error_flag    : std_logic;   
signal sd_error_code    : std_logic_vector(7 downto 0);
signal sd_busy_flag     : std_logic;
signal sd_type          : std_logic_vector(1 downto 0);
signal sd_fsm           : std_logic_vector(7 downto 0);

signal ram_we_duetosdc  : std_logic;
signal ram_di_duetosdc  : std_logic_vector(7 downto 0);

-- fsm control signals
signal fsm_sync_reset   : std_logic;
signal fsm_block_read   : std_logic;
signal fsm_block_write  : std_logic;
signal fsm_block_addr   : std_logic_vector(31 downto 0);
signal fsm_current_byte : std_logic_vector(7 downto 0);
signal fsm_buffer_ptr   : unsigned(15 downto 0);
signal fsm_internal_err : std_logic_vector(3 downto 0);

-- flip/flops to save register values
signal reg_addr_lo      : std_logic_vector(15 downto 0);
signal reg_addr_hi      : std_logic_vector(15 downto 0);
signal reg_data_pos     : std_logic_vector(15 downto 0);
signal reg_data         : std_logic_vector(7 downto 0);
signal write_data       : std_logic_vector(1 downto 0);   -- mini "fsm" to store "reg_data" to RAM
signal cmd_reset        : std_logic;   -- CSR opcode 0x0000
signal cmd_read         : std_logic;   -- CSR opcode 0x0001
signal cmd_write        : std_logic;   -- CSR opcode 0x0002
signal internal_err     : std_logic_vector(3 downto 0);

signal reset_cmd_reset  : std_logic;
signal reset_cmd_read   : std_logic;
signal reset_cmd_write  : std_logic;

type sd_fsm_type is (

   sds_idle,
   
   sds_busy,
   sds_error,

   sds_reset,
   
   -- READ state transitions
   sds_read_start,   
   sds_read_wait_for_byte,
   sds_read_store_byte,
   sds_read_handshake,
   sds_read_inc_ram_addr,
   sds_read_check_done,
   
   -- WRITE state transitions
   sds_write_start,
   sds_write_ramwait,
   sds_write_provide_byte,
   
   sds_std_seq
);

signal sd_state         : sd_fsm_type;
signal sd_state_next    : sd_fsm_type;
signal fsm_state_next   : sd_fsm_type;

signal Slow_Clock_25MHz : std_logic;

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
        
   -- SD Card Controller
   sdctl : sd_controller
      port map (
         -- general signals
         clk => Slow_Clock_25MHz,
         reset => sd_sync_reset,
         addr => sd_block_addr,
         sd_busy => sd_busy_flag,
         sd_error => sd_error_flag,
         sd_error_code => sd_error_code,
         sd_type => sd_type,
         sd_fsm => sd_fsm,
      
         -- hardware interface
         cs => sd_reset,
         sclk => sd_clk,
         mosi => sd_mosi,
         miso => sd_miso,
         
         -- hardware socket settings
         card_present => '1',
         card_write_prot => '0',
         
         -- reading
         rd => sd_block_read,
         rd_multiple => '0',
         dout => sd_dout,
         dout_avail => sd_dout_avail,
         dout_taken => sd_dout_taken,
         
         -- writing
         wr => sd_block_write,
         wr_multiple => '0',
         din => sd_din,
         din_valid => sd_din_valid,
         din_taken => sd_din_taken,
         
         erase_count => (others => '0')
      );     
      
   fsm_advance_state : process(clk)
   begin
      if rising_edge(clk) then
         if fsm_state_next = sds_std_seq then
            sd_state <= sd_state_next;
         else
            sd_state <= fsm_state_next;
         end if;
         
         sd_sync_reset  <= fsm_sync_reset;
         sd_block_read  <= fsm_block_read;
         sd_block_write <= fsm_block_write;
         sd_block_addr  <= fsm_block_addr;
         
         current_byte   <= fsm_current_byte;
         buffer_ptr     <= fsm_buffer_ptr;
         internal_err   <= fsm_internal_err;

         if reset = '1' or cmd_reset = '1' then
            sd_state       <= sds_reset;
            
            sd_sync_reset  <= '0';  -- will be set to '1' by state machine, which also handles reset ack
            sd_block_read  <= '0';
            sd_block_write <= '0';
            sd_block_addr  <= (others => '0');
            
            current_byte   <= (others => '0');
            buffer_ptr     <= (others => '0');
            internal_err   <= (others => '0');
         end if;
      end if;
   end process;
   
   fsm_output_decode : process(all)
   begin
      fsm_sync_reset    <= '0';
      fsm_block_read    <= sd_block_read;
      fsm_block_write   <= sd_block_write;
      fsm_block_addr    <= sd_block_addr;
      fsm_state_next    <= sds_std_seq;
      fsm_current_byte  <= current_byte;
      fsm_buffer_ptr    <= buffer_ptr;
      fsm_internal_err  <= internal_err;
      
      reset_cmd_reset   <= '0';
      reset_cmd_read    <= '0';
      reset_cmd_write   <= '0';
      
      sd_din            <= (others => '0');
      sd_din_valid      <= '0';
      sd_dout_taken     <= '0';
      
      ram_we_duetosdc   <= '0';
      ram_di_duetosdc   <= (others => '0');
      
      case sd_state is
      
         when sds_idle =>
            -- read and write in parallel leads to a blocking situation 
            if cmd_read = '1' and cmd_write = '1' then
               fsm_state_next    <= sds_error;
               fsm_internal_err  <= x"1"; -- will turn into x"EE21", i.e. SD$ERR_READWRITEJAM
            elsif cmd_read = '1' or cmd_write = '1' then
               -- provide read/write block address to SD card controller
               fsm_block_addr <= reg_addr_hi & reg_addr_lo;
    
               if cmd_read = '1' then
                  fsm_state_next <= sds_read_start;                 
               else
                  fsm_state_next <= sds_write_start;
               end if;
            end if;
               
         --------------------------------------------------------------------------------
         -- READ state transitions
         --------------------------------------------------------------------------------
                                    
         when sds_read_start =>
            reset_cmd_read <= '1';

            -- issue read command and wait until the controler signals busy
            if sd_busy_flag = '0' then
               fsm_state_next <= sds_read_start;
               
               -- issue read command and reset memory pointer
               fsm_block_read <= '1';
               fsm_buffer_ptr <= (others => '0');
            end if;
            
         when sds_read_wait_for_byte =>              
            -- next byte available
            if sd_dout_avail = '1' then
               -- prepare to store the arrived byte
               fsm_current_byte <= sd_dout;
               ram_we_duetosdc <= '1';
               ram_di_duetosdc <= sd_dout;
                  
            -- wait, until next byte arrives                  
            else
               fsm_state_next <= sds_read_wait_for_byte;
            end if;
                        
         when sds_read_store_byte =>
            ram_we_duetosdc <= '1';
            ram_di_duetosdc <= current_byte;
            
         when sds_read_handshake =>
            -- signal to the controller that we took the byte
            sd_dout_taken <= '1'; 
            -- wait for the controller to acknowledge that
            -- by waiting until it drops sd_dout_avail
            if sd_dout_avail = '1' then 
               fsm_state_next <= sds_read_handshake;
            end if;
            
         when sds_read_inc_ram_addr =>            
            sd_dout_taken <= '1'; -- two cycles due to 50MHz fsm vs. 25 MHz SD Controller
            fsm_buffer_ptr <= buffer_ptr + 1;
         
         when sds_read_check_done =>
            -- reading done
            if buffer_ptr = 512 then
               fsm_block_read <= '0';
               fsm_state_next <= sds_busy;
            end if;
            
         --------------------------------------------------------------------------------
         -- WRITE state transitions
         --------------------------------------------------------------------------------

         when sds_write_start =>
            reset_cmd_write <= '1';

            -- issue write command and wait until the controler signals busy
            if sd_busy_flag = '0' then
               fsm_state_next <= sds_write_start;
               
               -- issue read command and reset memory pointer
               fsm_block_write <= '1';
               fsm_buffer_ptr  <= (others => '0');
            end if;
            
         when sds_write_ramwait =>
            sd_din <= ram_data_o;
            
         when sds_write_provide_byte =>
            sd_din <= ram_data_o;
            sd_din_valid <= '1';  
            
            if sd_din_taken = '0' then
               fsm_state_next <= sds_write_provide_byte;
            else
               sd_din_valid   <= '0';
               fsm_buffer_ptr <= buffer_ptr + 1;
               
               if buffer_ptr = 511 then
                  fsm_block_write <= '0';
                  fsm_state_next  <= sds_busy;
               end if;
            end if;

         --------------------------------------------------------------------------------
         -- Busy, reset and error state transitions
         --------------------------------------------------------------------------------
                                         
         when sds_busy =>
            if sd_busy_flag = '0' then
               fsm_state_next <= sds_idle;
            elsif sd_error_flag = '1' then
               fsm_state_next <= sds_error;
            end if;
      
         when sds_reset =>
            reset_cmd_reset <= '1';
            fsm_sync_reset <= '1';
            
            -- wait until the controller acknowledges reset
            if sd_fsm /= x"00" then
               fsm_state_next <= sds_reset;
            end if;
                        
         when sds_error =>
            fsm_block_read <= '0';
            
         when others => null;
      
      end case;
   end process;
   
   -- define the standard sequence of fsm states 
   fsm_next_state_decode : process(sd_state)
   begin
      case sd_state is
         when sds_reset                => sd_state_next <= sds_busy;
         
         -- READ state transitions
         when sds_read_start           => sd_state_next <= sds_read_wait_for_byte;
         when sds_read_wait_for_byte   => sd_state_next <= sds_read_store_byte;
         when sds_read_store_byte      => sd_state_next <= sds_read_handshake;
         when sds_read_handshake       => sd_state_next <= sds_read_inc_ram_addr;
         when sds_read_inc_ram_addr    => sd_state_next <= sds_read_check_done;
         when sds_read_check_done      => sd_state_next <= sds_read_wait_for_byte;
         
         -- WRITE state transitions
         when sds_write_start          => sd_state_next <= sds_write_ramwait;
         when sds_write_ramwait        => sd_state_next <= sds_write_provide_byte;
         when sds_write_provide_byte   => sd_state_next <= sds_write_ramwait;
          
         when others                   => sd_state_next <= sd_state;
      end case;
   end process;
   
   read_sdcard_registers : process(all)
   variable is_busy : std_logic;
   variable is_error : std_logic;
   begin
      if sd_state = sds_error or sd_error_flag = '1' then
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
         
      if en = '1' and we = '0' then
         case reg is
            when "000" => data_out <= reg_addr_lo;
            when "001" => data_out <= reg_addr_hi;
            when "010" => data_out <= reg_data_pos;
            when "011" => data_out <= "00000000" & ram_data_o;
            
            when "100" =>
               if internal_err = x"0" then
                  data_out <= sd_fsm & sd_error_code;
               else
                  data_out <= x"EE2" & internal_err;
               end if;
            
            when "101" => data_out <= is_busy & is_error & sd_type & "000000000000";
            when others => data_out <= (others => '0');
         end case;
      else
         data_out <= (others => '0');
      end if;
   end process;
   
   write_sdcard_registers : process(clk)
   begin
      if falling_edge(clk) then
         if en = '1' and we = '1' then
            case reg is
               when "000" => reg_addr_lo  <= data_in;
               when "001" => reg_addr_hi  <= data_in;
               when "010" => reg_data_pos <= data_in;
               when "011" => reg_data     <= data_in(7 downto 0);
               when others => null;
            end case;
         end if;

         if reset = '1' then
            reg_addr_lo <= (others => '0');
            reg_addr_hi <= (others => '0');
            reg_data_pos <= (others => '0');
            reg_data <= (others => '0');
         end if;
      end if;
   end process;
   
   detect_write_data : process(clk)
   begin
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

         if reset = '1' then
            write_data <= "00";
         end if;
      end if;
   end process;
   
   detect_cmd_reset : process(clk)
   begin
      if falling_edge(clk) then
         if en = '1' and we = '1' then
            if reg = "101" and data_in = x"0000" then
               cmd_reset <= '1';
            end if;
         end if;

         if reset = '1' or reset_cmd_reset = '1' then
            cmd_reset <= '0';
         end if;
      end if;
   end process;
   
   detect_cmd_read_and_write : process(clk)
   begin
      if falling_edge(clk) then
         if en = '1' and we = '1' and reg = "101" then
            if data_in = x"0001" then
               cmd_read <= '1';
            elsif data_in = x"0002" then
               cmd_write <= '1';
            end if;
         end if;

         if reset = '1' or reset_cmd_read = '1' then
            cmd_read <= '0';
         end if;
         
         if reset = '1' or reset_cmd_write = '1' then
            cmd_write <= '0';
         end if;
      end if;
   end process;
      
   decide_ram_data_i_and_ram_we : process(all)
   begin
      if sd_state = sds_idle then
         ram_we      <= write_data(0) or write_data(1);
         ram_addr_i  <= reg_data_pos;
         ram_addr_o  <= reg_data_pos;
         ram_data_i  <= reg_data;
      else
         ram_we      <= ram_we_duetosdc;
         ram_addr_i  <= std_logic_vector(buffer_ptr);
         ram_addr_o  <= std_logic_vector(buffer_ptr);
         ram_data_i  <= ram_di_duetosdc;
      end if;
   end process;
   
   generate_Slow_Clock_25MHz : process(clk)
   begin
      if rising_edge(clk) then
         Slow_Clock_25MHz <= not Slow_Clock_25MHz;

         if reset = '1' or cmd_reset = '1' then
            Slow_Clock_25MHz <= '0';
         end if;
      end if;
   end process;
      
end beh;
