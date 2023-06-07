-- SD and SDHC Card controller
--
-- Author: Lawrence Wilkinson in 2013/2014
-- Original Source: https://github.com/ibm2030/SimpleSDHC
--
-- Improved SDHC support by sy2002 in August 2016
-- Detailed description: See below.
-- Enhanced Source: https://github.com/sy2002/QNICE-FPGA/blob/master/vhdl/sd_spi.vhd

-------------------------------------------------------------------------------
--
--    This file is part of LJW2030, a VHDL implementation of the IBM
--    System/360 Model 30.
--
--    LJW2030 is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    LJW2030 is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with LJW2030 .  If not, see <http://www.gnu.org/licenses/>.
--
-------------------------------------------------------------------------------
--
--    File: sd_spi.vhd
--    Creation Date: 2013-02-08
--    Description:
--    Interface to SD/SDHC card via SPI
--
--    Revision History:
--    Revision 1.0 2013-05-03
--    Revision 1.01 2014-09-23 Correct wr_erase_count handling
--		Revision 1.02 2014-09-24 Fix error in read handshaking
--		Revision 1.03 2014-09-28 Improve write handshaking
--		Revision 1.04 2014-09-29 Streamline aborted read transfers
--    Revision 1.10 2016-08-15 Now works with more SDHC cards (done by sy2002)
--    Revision 1.20 2022-09-11 Writing works with more SDHC cards and uses the weird
--                             brute force work-around from 2016 (done by sy2002)
--
--    Initial Release
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- This SD Card interface was based on the one by Steven J Merrifield
-- http://stevenmerrifield.com/tools/sd.vhd or https://github.com/sjm126/vhdl
-- Rewritten for SD V2 and SDHC by Lawrence Wilkinson, Feb 2013
-- to add:
-- * Support for SD V2 and SDHC.
-- * Sector-based addressing only (512 byte blocks.)
-- * CRC computation and checking - CRC is enabled for SPI transfers
-- * Timeouts and status checks where appropriate
-- * Low-speed initialisation
--
-- The FSM is implemented as two processes with a large number of state variables.
-- In the interests of providing glitch-free outputs, the SD card outputs are
-- registered along with the state variables.
--
-- CalcStateVariables asynchronously calculates the updated state values, and the
-- outputs values, from the current state and asynchronous inputs.  The calculated
-- values have names prefixed with new_ .  The default value of the new_X variable
-- is generally X (i.e. the current value) to imply a register.  For state variable
-- that are updated rarely, there is a companion variable prefixed with set_ which
-- is used to gate the calculated value into the state variable.  The theory of this
-- is to make use of the ClockEnable input to the state registers, and when the set_X
-- variable is false then the calculated new_X value is irrelevant (typically 0) to
-- simplify the logic.
--
-- UpdateStateVariables synchronously updates the state and output variables from the
-- values provided by CalcStateVariables.
--
-- The state machine implements subroutines by setting the variable "return_state"
-- before transitioning to the start of the subroutine.
-- Two-level subroutines are handled by the "sr_return_state" variable which allows the top
-- level subroutine to call the SEND_RCV subroutine to transfer a single by to/from the card.
--
-- sd_busy:
-- Inactive when the card can accept a Read or Write command
-- Goes active for the duration of the command, input address is latched at this time
-- Goes inactive when Rd or Wr is dropped, or when command is complete, whichever is later
--
-- sd_error:
-- Goes active immediately when an error is detected
-- Resets when RD or WR is raised for the next command (except for 110 or 111 status)
-- 
-- sd_error_code:
-- 000 No error (operation complete)
-- 001 SD Card R1 error (R1 bit 6-0)
-- 010 Read CRC error or Write Timeout error
-- 011 Data Response Token error (Token bit 3)
-- 100 Data Error Token error (Token bit 3-0)
-- 101 SD Card Write Protect switch
-- 110 Unusable SD card
-- 111 No SD card (no response from CMD0)
--
-- sd_type:
-- 00 No card
-- 01 SD V1
-- 10 SD V2
-- 11 SDHC
--
--
-- Enhancements done by sy2002 in August 2016:
--
-- 1. Made the controller work with more Micro SDHC (**) cards than
-- it did before. This is done by introducing a retry mechanism during
-- command sending: If the state SEND_CMD_5 fails after an amount of
-- retries specified by R1_TIMEOUT, then the SD Card is being reset
-- and after entering IDLE2, the original start state of the last
-- action is being retried ACTION_RETRIES times.
--
-- 2. sd_error is only raised, when there is really an error, and not (in
-- contrast to the original version) as a default value during the reset
-- sequence of the state machine. That means, you can trigger actions
-- on sd_error now without the problem that during reset or init sd_error
-- fluctuates.
--
-- 3. Added stabilization code to better comply with the standard:
-- IDLE2 now pulses the SCLK after issuing the reset and SEND_CMD waits
-- until MISO is 1.
--
-- regarding (**): "most SDHC" cards means: Before the admittedly brute
-- force workaround introduced by above mentioned (1), the controler did
-- not work at all with these Micro SDHC Cards: SanDisk 32GB SDHC Class 4,
-- Transcend 32GB SHD Class 10 and it worked pretty unstable (i.e. 
-- READ_BLOCK randomly failed) on an Elegant 32GB SDHC Class 10 card.
-- Now, after introducing the changes described here, it works fine with
-- all these Micro SDHC cards. Plus it also works fine (as it already did
-- before) with these Micro cards: SanDisk 1GB, Transcend 1GB,
-- Transcend 2GB, Nokia 64 MB, Nokia 128 MB.
--
-- Known Problem: The controller is not working with a
-- SanDisk Ultra 32 GB Micro SDHC Class 10 (but it works with the
-- SanDisk 32GB SDHC Class 4, interesstingly enough).


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sd_controller is
generic (

   -- WARNING: Just changing the clockRate generics does not make this design automatically work
   -- with another clock rate. You also need to adjust "slowClockDivider" and you need to know
   -- what you're doing. For the time being, it is best to supply either 25MHz or 50MHz to this controller
	clockRate : integer := 25000000;		-- Incoming clock is 25MHz (can change this to 2000 to test Write Timeout)
   
	slowClockDivider : integer := 64;	-- For a 25MHz clock, slow clock for startup is 25/64 = 390kHz
	R1_TIMEOUT : integer := 64;         -- Number of bytes to wait before giving up on receiving R1 response
	WRITE_TIMEOUT : integer range 0 to 999 := 500; -- Number of ms to wait before giving up on write completing
   RESET_TICKS : integer := 64;        -- Number of half clock cycles being pulsed before lowing sd_busy in IDLE2
   ACTION_RETRIES : integer := 200;    -- Number of retries when SEND_CMD_5 fails
   READ_TOKEN_TIMEOUT : integer := 1000 -- Number of retries to receive the read start token "FE"
	);
port (
	cs : out std_logic;				-- To SD card
	mosi : out std_logic;			-- To SD card
	miso : in std_logic;			-- From SD card
	sclk : out std_logic;			-- To SD card
	card_present : in std_logic;	-- From socket - can be fixed to '1' if no switch is present
	card_write_prot : in std_logic;	-- From socket - can be fixed to '0' if no switch is present, or '1' to make a Read-Only interface

	rd : in std_logic;				-- Trigger single block read
	rd_multiple : in std_logic;		-- Trigger multiple block read
	dout : out std_logic_vector(7 downto 0);	-- Data from SD card
	dout_avail : out std_logic;		-- Set when dout is valid
	dout_taken : in std_logic;		-- Acknowledgement for dout
	
	wr : in std_logic;				-- Trigger single block write
	wr_multiple : in std_logic;		-- Trigger multiple block write
	din : in std_logic_vector(7 downto 0);	-- Data to SD card
	din_valid : in std_logic;		-- Set when din is valid
	din_taken : out std_logic;		-- Ackowledgement for din
	
	addr : in std_logic_vector(31 downto 0);	-- Block address
	erase_count : in std_logic_vector(7 downto 0); -- For wr_multiple only

	sd_error : out std_logic;		-- '1' if an error occurs, reset on next RD or WR
	sd_busy : out std_logic;		-- '0' if a RD or WR can be accepted
	sd_error_code : out std_logic_vector(7 downto 0); -- See above, 000=No error
	
	
	reset : in std_logic;	-- System reset
	clk : in std_logic;		-- twice the SPI clk (max 50MHz)
	
	-- Optional debug outputs
	sd_type : out std_logic_vector(1 downto 0);	-- Card status (see above)
	sd_fsm : out std_logic_vector(7 downto 0) := "11111111" -- FSM state (see block at end of file)
);

end sd_controller;

architecture rtl of sd_controller is
type states is (
	RST, RST2,						-- Initial FSM resetting
	INIT,								-- Send initial clock pulses
	CMD0,								-- Send CMD0
	CMD8, CMD8R1, CMD8B2, CMD8B3, CMD8B4, CMD8GOTB4,	-- Send CMD8
	CMD55,							-- Send CMD55
	CMD41,							-- Send ACMD41
	POLL_CMD,						-- Wait for card initialised
	CMD58, CMD58R1, CMD58B2, CMD58B3, CMD58B4,	-- Send CMD58
   CMD16, CMD16R1,            -- Send CMD16 (force SD V2 cards to 512 byte blocks)
	CMD59, CMD59R1,				-- Send CMD59
  
	IDLE, IDLE2,					-- wait for read or write pulse
	READ_BLOCK,						-- Initiate Read command
	READ_MULTIPLE_BLOCK,			-- Initiate Read Multiple command
	READ_BLOCK_R1, READ_BLOCK_WAIT_CHECK,	-- Wait for data to appear
	READ_BLOCK_DATA,				-- Receive bytes and output
	READ_BLOCK_SKIP,				-- Skip remaining data if read is aborted
	READ_BLOCK_CRC,				-- Receive CRC bytes
	READ_BLOCK_CHECK_CRC,		-- Check final CRC=0
	READ_BLOCK_FINISH,			-- Wait until RD drops
	READ_MULTIPLE_BLOCK_STOP,
	READ_MULTIPLE_BLOCK_STOP_2,
	
	SEND_RCV,
	SEND_RCV_CLK1,
	SEND_CMD,
	SEND_CMD_1,
	SEND_CMD_2,
	SEND_CMD_3,
	SEND_CMD_4,
	SEND_CMD_5,
	
	SET_ERASE_COUNT_CMD,			-- Send Set Erase Count
	SET_ERASE_COUNT_CMD_2,		-- Send ACMD23
	WRITE_BLOCK_CMD,				-- Initiate Write command
	WRITE_MULTIPLE_BLOCK_CMD,	-- Initiate Write Multiple command
	WRITE_BLOCK_INIT,
	WRITE_BLOCK_DATA_TOKEN,		-- Send data token
	START_WRITE_BLOCK_DATA,		-- Set up for data loop
	WRITE_BLOCK_DATA,				-- Start sending write data
	WRITE_BLOCK_SEND_CRC2,		-- Send second byte of CRC
	WRITE_BLOCK_GET_RESPONSE,	-- Get R1 following data
	WRITE_BLOCK_CHECK_RESPONSE,-- Check response after data sent
	WRITE_BLOCK_WAIT,				-- Wait for write to complete
	WRITE_BLOCK_ABORT,			-- Send dummy data to fill block
	WRITE_BLOCK_TERMINATE,		-- Send Stop for Write Multiple
	WRITE_BLOCK_FINISH			-- Wait until WR drops
);

subtype t_error_code is std_logic_vector(7 downto 0);
constant ec_NoError	      : t_error_code := "00000000";
constant ec_R1Error	      : t_error_code := "00000001";
constant ec_CRCError	      : t_error_code := "00000010";
constant ec_WriteTimeout	: t_error_code := "00000010";
constant ec_DataRespError	: t_error_code := "00000011";
constant ec_DataError	   : t_error_code := "00000100";
constant ec_WPError	      : t_error_code := "00000101";
constant ec_SDError	      : t_error_code := "00000110";
constant ec_NoSDError	   : t_error_code := "00000111";
constant ec_ReadTimeOut    : t_error_code := "00001000";

subtype t_card_type is std_logic_vector(1 downto 0);
constant ct_None : t_card_type := "00";
constant ct_SDV1 : t_card_type := "01";
constant ct_SDV2 : t_card_type := "10";
constant ct_SDHC : t_card_type := "11";

constant R1_IDLE                 : integer := 0;
constant R1_ERASE_RESET          : integer := 1;
constant R1_ILLEGALCOMMAND       : integer := 2;
constant R1_COMMANDCRCERROR      : integer := 3;
constant R1_ERASESEQUENCEERROR   : integer := 4;
constant R1_ADDRESSERROR         : integer := 5;
constant R1_PARAMETERERROR       : integer := 6;
constant R1_ZERO                 : integer := 7;
constant OCR1_CCS                : integer := 6;
constant OCR1_POWERUPSTATUS      : integer := 7;

signal state, new_state, return_state, new_return_state, sr_return_state, new_sr_return_state : states := RST;
signal set_return_state, set_sr_return_state : boolean := false;

-- Output signals to SD Card
signal new_sclk : std_logic := '0';
signal sCs, new_cs : std_logic := '1';

-- Output signals to higher level
signal set_davail : boolean := false;
signal sDavail : std_logic := '0';
signal transfer_data_out, new_transfer_data_out : boolean := false;
signal card_type, new_card_type : t_card_type := ct_None;
signal error, new_error : std_logic := '0';
signal error_code, new_error_code : t_error_code := ec_NoError;
signal new_busy : std_logic := '1';
signal sDin_taken, new_din_taken : std_logic := '0';

-- Shift registers
signal cmd_out, new_cmd_out : std_logic_vector(39 downto 0) := (others=>'1');
signal set_cmd_out : boolean := false;
signal data_in, new_data_in : std_logic_vector(7 downto 0);
signal new_crc7, crc7 : std_logic_vector(6 downto 0);
signal new_in_crc16, in_crc16 : std_logic_vector(15 downto 0);
signal new_out_crc16, out_crc16 : std_logic_vector(15 downto 0);
signal new_crcLow, crcLow : std_logic_vector(7 downto 0);
signal data_out, new_data_out : std_logic_vector(7 downto 0) := x"00";

signal address, new_address : std_logic_vector(31 downto 0);
signal wr_erase_count, new_wr_erase_count : std_logic_vector(7 downto 0);
signal set_address : boolean := false;
signal byte_counter, new_byte_counter : integer range 0 to 512 := 0;
signal set_byte_counter : boolean := false;
signal bit_counter, new_bit_counter : integer range 0 to 160 := 0;
signal slow_clock, new_slow_clock : boolean := true;
signal clock_divider, new_clock_divider : integer range 0 to slowClockDivider := 0;
signal multiple, new_multiple : boolean := false;
signal skipFirstR1Byte, new_skipFirstR1Byte : boolean := false;
signal din_latch : boolean := false;
signal last_din_valid : std_logic := '0';

-- used for "temporary" pulsing the sclk in IDLE2 and SEND_CMD
signal temp_sclk : std_logic; 
signal has_pulsed, new_has_pulsed : unsigned(7 downto 0);

-- used for the action retry mechanism
signal original_state, new_original_state : states;
signal state_retry_count, new_state_retry_count : unsigned(7 downto 0);
signal is_in_reset_cycle, new_is_in_reset_cycle : std_logic;
signal start_token_timeout, new_start_token_timeout: unsigned(15 downto 0);

begin
	-- This process updates all the state variables from the values calculated
	-- by the calcStateVariables process
	updateStateVariables: process(clk)
	begin
		if rising_edge(clk) then
			if (reset='1') then
				state <= RST;
				return_state <= RST;
				sr_return_state <= RST;
				cmd_out <= (others=>'1');
				data_in <= (others=>'0');
				dout <= (others=>'0');
				address <= (others=>'0');
				data_out <= (others=>'1');
				card_type <= ct_None;
				byte_counter <= 0;
				bit_counter <= 0;
				crc7 <= (others => '0');
				in_crc16 <= (others => '0');
				out_crc16 <= (others => '0');
				crcLow <= (others => '0');
				error <= '0';
				error_code <= ec_NoSDError;
				sdAvail <= '0';
				slow_clock <= true;
				clock_divider <= 0;
				transfer_data_out <= false;
				sCs <= '1';
				sDin_taken <= '0';
				wr_erase_count <= "00000001";
				-- SD outputs
				sclk <= '0';
				cs <= '1';
				-- Interface outputs
				sd_type <= "00";
				sd_busy <= '1';
				sd_error <= '0';
				sd_error_code <= ec_NoSDError;
				dout <= "00000000";
				dout_avail <= '0';
				din_taken <= '0';
				multiple <= false;
				skipFirstR1Byte <= false;
            
            temp_sclk <= '0';
            has_pulsed <= (others => '0');
            original_state <= RST;
            state_retry_count <= (others => '0');
            is_in_reset_cycle <= '1';
            start_token_timeout <= (others => '0');
			else
				-- State variables
				state <= new_state;
				if (set_return_state) then return_state <= new_return_state; end if;
				if (set_sr_return_state) then sr_return_state <= new_sr_return_state; end if;
				if (set_cmd_out) then cmd_out <= new_cmd_out; end if;
				data_in <= new_data_in;
				if (set_address) then address <= new_address; end if;
				data_out <= new_data_out;
				if (set_byte_counter) then byte_counter <= new_byte_counter; end if;
				bit_counter <= new_bit_counter;
				error <= new_error;
				error_code <= new_error_code;
				card_type <= new_card_type;
				slow_clock <= new_slow_clock;
				clock_divider <= new_clock_divider;
				crc7 <= new_crc7;
				in_crc16 <= new_in_crc16;
				out_crc16 <= new_out_crc16;
				crcLow <= new_crcLow;
				transfer_data_out <= new_transfer_data_out;
				sCs <= new_cs;
				-- SD outputs
				sclk <= new_sclk;
				cs <= new_cs;
				wr_erase_count <= new_wr_erase_count;
				-- Interface outputs
				sd_type <= new_card_type;
				sd_busy <= new_busy;
				sd_error <= new_error;
				sd_error_code <= new_error_code;
				if set_davail then -- NB can't do this at the same cycle as we set data_in
					sDavail <= '1';
					dout <= data_in;
					dout_avail <= '1';
				elsif sDavail='1' and dout_taken='1' then
					sDavail <= '0';
					dout_avail <= '0';
				end if;
				multiple <= new_multiple;
				skipFirstR1Byte <= new_skipFirstR1Byte;
            
            temp_sclk <= new_sclk;
            has_pulsed <= new_has_pulsed;
            original_state <= new_original_state;
            state_retry_count <= new_state_retry_count;
            is_in_reset_cycle <= new_is_in_reset_cycle;
            start_token_timeout <= new_start_token_timeout;

				-- This latches the din_valid and generates din_latch and din_taken
				if din_valid='0' or (wr='0' and wr_multiple='0') then
					-- Reset din_latch when din_valid is false, or no write in progress
					sDin_taken <= '0';
					din_taken <= '0';
					din_latch <= false;
				elsif din_valid='1' and last_din_valid='0' then
					-- Set din_latch on rising edge of din_valid
					sDin_taken <= '0';
					din_taken <= '0';
					din_latch <= true;
				elsif din_latch and new_din_taken='1' then
					-- Reset din_latch when din_taken rises
					sDin_taken <= '1';
					din_taken <= '1';
					din_latch <= false;
				end if;
				last_din_valid <= din_valid;
			end if;
		end if;
    end process;

	-- This process calculates all of the state variables
	-- It should not generate any latches
	-- Some values are initialised to a fixed value, and overridden later (new_X <= '0')
	-- Some values are initialised to their current values (new_X <= X)
	-- Some values are initialised to Don't Care (new_X <= '-')
	-- Updating of the latter values is under control of the set_X signal
	calcStateVariables: process(miso,rd,rd_multiple,wr,wr_multiple,
		state,bit_counter,card_type,byte_counter,data_in,data_out,
		address,addr,dout_taken,error,cmd_out,return_state,clock_divider,
		error_code,crc7,in_crc16,out_crc16,slow_clock,card_present,
		card_write_prot,SDin_Taken,sCS,transfer_data_out,din_valid,din,din_latch,
		crcLow,sDavail,sr_return_state,multiple,skipFirstR1Byte,wr_erase_count,erase_count,
      temp_sclk, has_pulsed, original_state, state_retry_count, is_in_reset_cycle, start_token_timeout)
	constant WriteTimeoutCount : integer := clockRate/18000 * WRITE_TIMEOUT;
	begin
		assert(WriteTimeoutCount > 0) report "WriteTimeoutCount is 0" severity failure ;
		new_state <= state;
		new_return_state <= RST;
		set_return_state <= false;
		new_sr_return_state <= RST;
		set_sr_return_state <= false;
		new_bit_counter <= bit_counter;
		new_card_type <= card_type;
		new_cmd_out <= (others=>'-');
		set_cmd_out <= false;
		new_byte_counter <= byte_counter;
		set_byte_counter <= false;
		new_data_in <= data_in;
		set_davail <= false;
		new_din_taken <= sDin_taken;
		new_data_out <= data_out;
		new_address <= (others=>'-');
		set_address <= false;
		new_sclk <= '0';
		new_cs <= sCs;
		new_error <= error;
		new_error_code <= error_code;
		new_busy <= '1';
		new_crc7 <= crc7;
		new_in_crc16 <= in_crc16;
		new_out_crc16 <= out_crc16;
		new_crcLow <= crcLow;
		new_slow_clock <= slow_clock;
		new_clock_divider <= clock_divider;
		new_transfer_data_out <= transfer_data_out;
		new_multiple <= multiple;
		new_skipFirstR1Byte <= skipFirstR1Byte;
		new_wr_erase_count <= wr_erase_count;
      
      new_has_pulsed <= has_pulsed;
      new_original_state <= original_state;
      new_state_retry_count <= state_retry_count;
      new_is_in_reset_cycle <= is_in_reset_cycle;
      new_start_token_timeout <= start_token_timeout;
            		
		case state is
		
		when RST =>
			new_error_code <= ec_NoSDError;
			new_error <= '0';
			new_state <= RST2;
         new_is_in_reset_cycle <= '1';
			
		when RST2 =>
         new_card_type <= ct_None;
         new_cs <= '1';
         new_slow_clock <= true;
         new_clock_divider <= slowClockDivider;
         new_byte_counter <= 20; set_byte_counter <= true;
         new_data_out <= "11111111";
         new_transfer_data_out <= false;
         new_sr_return_state <= INIT; set_sr_return_state <= true;
         if card_present='1' then
         -- Wait for card present indication before attempting initialisation
            new_state <= SEND_RCV;
         end if;
			
		when INIT =>
			if byte_counter=0 then
				new_state <= CMD0;
			else
				new_state <= SEND_RCV;
			end if;
			
		when CMD0 =>
			-- Send CMD0
			new_cs <= '0';
			new_address <= (others=>'0'); set_address <= true;
			new_cmd_out <= x"4000000000"; set_cmd_out <= true;
			new_return_state <= CMD8; set_return_state <= true;
			new_state <= SEND_CMD;
			
		when CMD8 =>
			-- Check CMD0 response and send CMD8 or stall on error
			if data_in="00000001" then
				new_cmd_out <= x"48000001AA"; set_cmd_out <= true; -- Voltage is 1, Check pattern is AA
				new_return_state <= CMD8R1; set_return_state <= true;
				new_state <= SEND_CMD;
			else
				new_card_type <= ct_None;
				new_error <= '1';
				new_error_code <= ec_R1Error;
			end if;
			
		when CMD8R1 =>
			-- Check R1 response to CMD8
			if data_in(R1_ILLEGALCOMMAND)='1' then -- Illegal command?
				new_card_type <= ct_SDV1; -- Yes, must be SD1
				new_state <= CMD55;
			else
				new_card_type <= ct_SDV2; -- No, could be SD2 (10) or SDHC (11)
				new_sr_return_state <= CMD8B2; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;
			
		when CMD8B2 =>
			-- Got first byte of CMD8 response
			new_sr_return_state <= CMD8B3; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when CMD8B3 =>
			-- Got second byte of CMD8 response
			new_sr_return_state <= CMD8B4; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when CMD8B4 =>
			-- Got third byte of CMD8 response
			-- Check operating voltage
			if data_in(3 downto 0) /= "0001" then
            new_error <= '1';
				new_error_code <= data_in; --ec_SDError;
			else
            -- Get byte 4 (check pattern)
            new_sr_return_state <= CMD8GOTB4; set_sr_return_state <= true;
            new_state <= SEND_RCV;
         end if;
			
		when CMD8GOTB4 =>
			-- Got fourth byte of CMD8 response
			-- Check pattern
			if data_in = x"AA" then
				new_state <= CMD55;
			else
            new_error <= '1';
				new_error_code <= data_in; --ec_SDError;         
			end if;
			
		when CMD55 =>
			-- Send CMD55
			new_return_state <= CMD41; set_return_state <= true;
			new_cmd_out <= x"7700000000"; set_cmd_out <= true;
			new_state <= SEND_CMD;
			
		when CMD41 =>
			-- Send CMD41
			new_return_state <= POLL_CMD; set_return_state <= true;
			if card_type=ct_SDV1 then
				new_cmd_out <= x"6900000000";
			else
				new_cmd_out <= x"6940000000";
			end if;
			set_cmd_out <= true;
			new_state <= SEND_CMD;
			
		when POLL_CMD =>
			-- Poll until card ready, then send CMD58 or CMD59 depending on type
			if (data_in(R1_IDLE) = '0') then -- In idle state?
				if (card_type=ct_SDV1) then
					new_state <= CMD59; -- SD1 ready now
				else
					new_state <= CMD58; -- SD2, SDHC determine
				end if;
			else
				new_state <= CMD55; -- Still in idle, repeat ACMD41
			end if;
			
		when CMD58 =>
			-- Send CMD58
			new_return_state <= CMD58R1; set_return_state <= true;
			new_cmd_out <= x"7A00000000"; set_cmd_out <= true;
			new_state <= SEND_CMD;
			
		when CMD58R1 =>
			-- Check R1 response to CMD58
			if data_in = "00000001" then
            new_return_state <= CMD58R1; set_return_state <= true;
            new_state <= SEND_RCV;
         elsif data_in /= "00000000" then         
				-- Illegal command - not an SD card: stall
				new_card_type <= ct_None;
				new_error_code <= ec_SDError;
				new_error <= '1';
			else
				-- Go fetch byte 1
				new_sr_return_state <= CMD58B2; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;
			
		when CMD58B2 =>
         -- Check Power Up Status Bit: if it is 0, then something went wrong
         -- stay in this state, so that if this problem ever occurs, we
         -- are able to identify it ready sd_fsm
         -- alternately, what could be done here: retry somehow, e.g. by
         -- "actively waiting" (sending "11111111" and then retry reading, or
         -- by reseding CMD58, etc. would need some more experiments
         if (data_in(OCR1_POWERUPSTATUS)) = '0' then
            new_card_type <= ct_None;
            new_error_code <= ec_SDError;
            new_error <= '1';
         else
            -- Check CCS: 0=SD2 1=SDHC
            -- card_type already set to ct_SDV2 (10) in CMD8R1
            if (data_in(OCR1_CCS)='1') then -- OCR(30) = CCS
               new_card_type <= ct_SDHC; -- SDHC
            end if;
            -- Go fetch byte 2
            new_sr_return_state <= CMD58B3; set_sr_return_state <= true;
            new_state <= SEND_RCV;
         end if;
			
		when CMD58B3 =>
			-- Fetch byte 3
			new_sr_return_state <= CMD58B4; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when CMD58B4 =>
			-- Fetch byte 4
			new_sr_return_state <= CMD16; set_sr_return_state <= true;
			new_state <= SEND_RCV;
         
      when CMD16 =>
         -- For SD V2 cards: Always force 512 byte block sizes
         if card_type = ct_SDV2 then
            new_return_state <= CMD16R1; set_return_state <= true;
            new_cmd_out <= x"5000000200"; set_cmd_out <= true;
            new_state <= SEND_CMD;
         else
            new_state <= CMD59;
         end if;
         
      when CMD16R1 =>
         -- Check reply from CMD16, stall on error
         if data_in /= "00000000" then
            new_error <= '1';
            new_error_code <= ec_SDError;
         else
            new_state <= CMD59;
         end if;
			
		when CMD59 =>
			-- Send CMD59
			new_return_state <= CMD59R1; set_return_state <= true;
			new_cmd_out <= x"7B00000001"; set_cmd_out <= true; -- Enable CRC
			new_state <= SEND_CMD;
			
		when CMD59R1 =>
			-- Check reply from CMD59, stall on error
			if data_in/="00000000" then
				new_error <= '1';
            new_error_code <= ec_SDError;
			end if;
			-- Don't enter IDLE until Rd and Wr are down
         -- except when we are currently in a retry loop
			if (original_state /= RST) or ((rd='0') and (wr='0') and (rd_multiple='0') and (wr_multiple='0')) then
				new_error_code <= ec_NoError;
				new_error <= '0';
				new_state <= IDLE;
         end if;
			
		when IDLE =>
         new_has_pulsed <= (others => '0');
         new_is_in_reset_cycle <= '0';
      
			-- Generate 8 clocks when entering idle
			new_slow_clock <= false;	-- Can run at full speed now
			new_data_out <= "11111111";
			new_bit_counter <= 7;
			new_transfer_data_out <= false;
			new_sr_return_state <= IDLE2; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when IDLE2 =>
			-- Sits in this state when idle
			if card_present='0' then
				-- Card gone!
				new_state <= RST;
			elsif data_in=x"00" then
				-- Card still busy
				new_state <= IDLE;
			elsif rd='1' and original_state = RST then
				-- Initiate Read
				new_cs <= '0';
				new_error <= '0';
				new_error_code <= ec_NoError;
				new_address <= addr; set_address <= true;
				new_multiple <= false;
				new_state <= READ_BLOCK;
			elsif rd_multiple='1' and original_state = RST then
				-- Initiate Read Multiple
				new_cs <= '0';
				new_error <= '0';
				new_error_code <= ec_NoError;
				new_address <= addr; set_address <= true;
				new_multiple <= true;
				new_state <= READ_MULTIPLE_BLOCK;
			elsif (wr='1' or wr_multiple='1') and original_state = RST then
				-- Initiate Write or Write Multiple
				if card_write_prot='0' then
					new_cs <= '0';
					new_error <= '0';
					new_error_code <= ec_NoError;
					new_address <= addr; set_address <= true;
					if wr='1' then
						new_multiple <= false;
						new_wr_erase_count <= "00000001";
					else
						new_multiple <= true;
						new_wr_erase_count <= erase_count;
					end if;
					new_state <= SET_ERASE_COUNT_CMD;
				else
					new_error <= '1';
					new_error_code <= ec_WPError;
				end if;
			else
            new_cs <= '1';
            
            -- No command: pulse reset for a while
            if has_pulsed = RESET_TICKS then
               if original_state = RST then
                  new_busy <= '0';
                  new_state_retry_count <= (others => '0');
               else
                  new_cs <= '0';
                  new_error <= '0';
                  new_error_code <= ec_NoError;
                  new_address <= addr; set_address <= true;
                  new_state <= original_state;
               end if;
            else
               new_sclk <= not temp_sclk;
               new_has_pulsed <= has_pulsed + 1;
            end if;
			end if;
			
		when READ_BLOCK =>
			-- Basic Read command
			if card_type=ct_SDHC then
				-- SDHC: Use block address
				new_cmd_out <= x"51" & address(31 downto 0);
			else
				-- SDV1,2: Use byte address
				new_cmd_out <= x"51" & address(22 downto 0) & "000000000";
			end if;
			set_cmd_out <= true;
			new_return_state <= READ_BLOCK_R1; set_return_state <= true;
			new_state <= SEND_CMD;
         new_original_state <= READ_BLOCK;
         new_start_token_timeout <= (others => '0');
			
		when READ_MULTIPLE_BLOCK =>
			-- Read Multiple command
			if card_type=ct_SDHC then
				-- SDHC: Use block address
				new_cmd_out <= x"52" & address(31 downto 0);
			else
				-- SDV1,2: Use byte address
				new_cmd_out <= x"52" & address(22 downto 0) & "000000000";
			end if;
			set_cmd_out <= true;
			new_return_state <= READ_BLOCK_R1; set_return_state <= true;
			new_state <= SEND_CMD;
         new_original_state <= READ_MULTIPLE_BLOCK;
         new_start_token_timeout <= (others => '0');
			
		when READ_BLOCK_R1 =>
			-- Get R1 response to Read or Read Multiple command
			if data_in/="00000000" then -- Some error
				new_error <= '1';
--				new_error_code <= ec_R1Error;
            new_error_code <= data_in;  -- debug only: output SD Card's error response
				new_state <= READ_BLOCK_FINISH;
			else
				new_sr_return_state <= READ_BLOCK_WAIT_CHECK; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;
			
		when READ_BLOCK_WAIT_CHECK =>
			-- Wait for Read token, or Error token
			new_in_crc16 <= (others=>'0');
			if rd='0' and rd_multiple='0' then
				-- Abort transfer
				new_state <= READ_BLOCK_FINISH; -- And then to IDLE
			elsif (data_in="11111110") then
				new_transfer_data_out <= true;
				new_byte_counter <= 512; set_byte_counter <= true;
				new_sr_return_state <= READ_BLOCK_DATA; set_sr_return_state <= true; -- Wait for dout_taken to drop
				new_state <= SEND_RCV;
			elsif (data_in(7 downto 4)="0000") then
				-- Check for error token 0000XXXX
				-- Flag error and wait for RD to drop
				new_error <= '1';
				new_error_code <= ec_DataError;
				new_state <= READ_BLOCK_FINISH;
			else
            new_state <= SEND_RCV;
--            if start_token_timeout = READ_TOKEN_TIMEOUT then
--               new_error <= '1';
--               new_error_code <= ec_ReadTimeOut;
--            else
--               new_start_token_timeout <= start_token_timeout + 1;
--               new_state <= SEND_RCV;
--            end if;
			end if;
			
		when READ_BLOCK_DATA =>
			-- Read a byte of data from the card
			if rd='0' and rd_multiple='0' then
				-- Abort transfer
				new_state <= READ_BLOCK_SKIP; -- And then to IDLE
			else
				if byte_counter=0 then
					new_transfer_data_out <= false;
					new_sr_return_state <= READ_BLOCK_CRC;
					set_sr_return_state <= true;
				end if;
				new_state <= SEND_RCV;
			end if;
			
		when READ_BLOCK_SKIP =>
			-- Skip all remaining bytes without transferring them
			new_transfer_data_out <= false;
			if multiple then
				-- Special stop mechanism for Read Multiple
				new_state <= READ_MULTIPLE_BLOCK_STOP;
			elsif (byte_counter=0) then
				-- After last byte, read the first CRC byte
				new_sr_return_state <= READ_BLOCK_CRC; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			else
				-- Keep skipping bytes
				new_sr_return_state <= READ_BLOCK_SKIP; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;
			
		when READ_BLOCK_CRC =>
			-- Read second CRC byte
			new_sr_return_state <= READ_BLOCK_CHECK_CRC; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when READ_BLOCK_CHECK_CRC =>
			-- After reading all the data and the two CRC bytes, the result should be zero
			if in_crc16/="0000000000000000" then
				new_error <= '1';
				new_error_code <= ec_CRCError;
				new_state <= READ_BLOCK_FINISH;
			elsif multiple and rd_multiple='1' then
				-- Start looking for a further data block
				new_sr_return_state <= READ_BLOCK_WAIT_CHECK; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			else
				-- Transfer complete
				new_state <= READ_BLOCK_FINISH;
			end if;
			
		when READ_BLOCK_FINISH =>
			new_transfer_data_out <= false;
			-- Wait for RD to fall after last byte has been transferred
			if (rd='0') and (rd_multiple='0') then
				if multiple then
					new_state <= READ_MULTIPLE_BLOCK_STOP;
				else
					new_state <= IDLE;
				end if;
			end if;
			
		when READ_MULTIPLE_BLOCK_STOP =>
			-- Send CMD12
			new_skipFirstR1Byte <= true;
			new_return_state <= READ_MULTIPLE_BLOCK_STOP_2; set_return_state <= true;
			new_cmd_out <= x"4C00000000"; set_cmd_out <= true;
			new_state <= SEND_CMD;
			
		when READ_MULTIPLE_BLOCK_STOP_2 =>
			-- Check R1 and wait for not-busy when we get to IDLE
			if data_in/="00000000" then
				new_state <= RST;
			else
				if rd_multiple='0' then
					new_state <= IDLE;
				end if;
			end if;
			
		when SET_ERASE_COUNT_CMD =>
			-- Send CMD55
			new_return_state <= SET_ERASE_COUNT_CMD_2; set_return_state <= true;
			new_cmd_out <= x"7700000000"; set_cmd_out <= true;
			new_state <= SEND_CMD;
			new_original_state <= SET_ERASE_COUNT_CMD;
			
		when SET_ERASE_COUNT_CMD_2 =>
			-- Send ACMD23
			new_cmd_out <= x"57000000" & wr_erase_count;
			if wr='1' then
				new_return_state <= WRITE_BLOCK_CMD;
			else
				new_return_state <= WRITE_MULTIPLE_BLOCK_CMD;
			end if;
			set_cmd_out <= true;
			set_return_state <= true;
			new_state <= SEND_CMD;
	      new_original_state <= SET_ERASE_COUNT_CMD_2;
		
		when WRITE_BLOCK_CMD =>
			-- Send CMD24 for single block write
			if (card_type=ct_SDHC) then
				new_cmd_out <= x"58" & address(31 downto 0);
			else
				new_cmd_out <= x"58" & address(22 downto 0) & "000000000";
			end if;
			set_cmd_out <= true;
			new_return_state <= WRITE_BLOCK_INIT; set_return_state <= true;
			new_state <= SEND_CMD;
			new_original_state <= WRITE_BLOCK_CMD;
			
		when WRITE_MULTIPLE_BLOCK_CMD =>
			-- Send CMD25 for multiple write
			if (card_type=ct_SDHC) then
				new_cmd_out <= x"59" & address(31 downto 0);
			else
				new_cmd_out <= x"59" & address(22 downto 0) & "000000000";
			end if;
			set_cmd_out <= true;
			new_return_state <= WRITE_BLOCK_INIT; set_return_state <= true;
			new_state <= SEND_CMD;
			new_original_state <= WRITE_MULTIPLE_BLOCK_CMD;
		
		when WRITE_BLOCK_INIT =>
			-- Check for response to write command, then send data token
			if data_in/="00000000" then
				new_error <= '1';
				new_error_code <= ec_R1Error;
				new_state <= WRITE_BLOCK_FINISH;
			else
				new_state <= WRITE_BLOCK_DATA_TOKEN;
			end if;
			
		when WRITE_BLOCK_DATA_TOKEN =>
			-- Send data start token
			if multiple then
				new_data_out <= x"FC"; -- start token, multiple block
			else
				new_data_out <= x"FE"; -- start token, single block
			end if;
			new_sr_return_state <= START_WRITE_BLOCK_DATA; set_sr_return_state <= true;
			new_state <= SEND_RCV;

		when START_WRITE_BLOCK_DATA =>
			-- Reset CRC and start writing data
			new_byte_counter <= 512; set_byte_counter <= true;
			new_out_crc16 <= (others=>'0');
			new_state <= WRITE_BLOCK_DATA;

		when WRITE_BLOCK_DATA =>
			-- Write data, finishing with first CRC byte
			if byte_counter = 0 then
				new_data_out <= out_crc16(15 downto 8);
				new_crcLow <= out_crc16(7 downto 0);
				new_sr_return_state <= WRITE_BLOCK_SEND_CRC2; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			elsif wr='0' and wr_multiple='0' then
				-- Abort writing - send dummy data and bad CRC
				new_state <= WRITE_BLOCK_ABORT;
			elsif din_latch then
				new_data_out <= din;
				new_din_taken <= '1';
				new_sr_return_state <= WRITE_BLOCK_DATA; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;

		when WRITE_BLOCK_SEND_CRC2 =>
			-- Send second CRC byte
			new_data_out <= crcLow;
			new_sr_return_state <= WRITE_BLOCK_GET_RESPONSE; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when WRITE_BLOCK_GET_RESPONSE =>
			-- Get response byte from write
			new_byte_counter <= R1_TIMEOUT; set_byte_counter <= true;
			new_sr_return_state <= WRITE_BLOCK_CHECK_RESPONSE; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when WRITE_BLOCK_CHECK_RESPONSE =>
			-- Check write response for error
			if (data_in(4) /= '0') or (data_in(0) /= '1') then
				if byte_counter=0 then
					new_error <= '1';
					new_error_code <= ec_R1Error;
					new_state <= WRITE_BLOCK_TERMINATE;
				else
					new_byte_counter <= byte_counter - 1; set_byte_counter <= true;
					new_state <= SEND_RCV; -- Wait for Data Response token
				end if;
			elsif data_in(3 downto 1) /= "010" then
				-- Data not accepted
				new_error <= '1';
				new_error_code <= ec_DataRespError;
				new_state <= WRITE_BLOCK_TERMINATE;
			else
				-- Receive a byte and poll for write complete
				-- Use cmd_out to time 2ms (50000 clocks @ 25MHz)
				new_cmd_out <= std_logic_vector(to_unsigned(WriteTimeoutCount,40)); set_cmd_out <= true;
				new_sr_return_state <= WRITE_BLOCK_WAIT; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;

		when WRITE_BLOCK_WAIT =>
			-- Wait for write to complete
			if data_in=x"00" then
				if cmd_out=x"0000000000" then
					new_error <= '1';
					new_error_code <= ec_WriteTimeout;
					new_state <= WRITE_BLOCK_TERMINATE;
				else
					new_cmd_out <= STD_LOGIC_VECTOR(unsigned(cmd_out) - 1); set_cmd_out <= true;
					new_state <= SEND_RCV; -- Will come back here, loop until write complete
				end if;
			else
				if multiple then
					if wr_multiple='1' then
						if din_latch then
							new_state <= WRITE_BLOCK_DATA_TOKEN;
						else
							-- Wait here for din_latch before starting another block
						end if;
					else
						new_state <= WRITE_BLOCK_TERMINATE;
					end if;
				else
					new_state <= WRITE_BLOCK_FINISH;
				end if;
			end if;
			
		when WRITE_BLOCK_ABORT =>
			-- Abort write due to Write command input being dropped - write remaining bytes and force CRC error
			if byte_counter=0 then
				new_data_out <= out_crc16(15 downto 8);
				new_crcLow <= out_crc16(7 downto 0) xor x"01"; -- Force bad CRC
				new_sr_return_state <= WRITE_BLOCK_SEND_CRC2; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			else
				new_data_out <= x"00";
				new_sr_return_state <= WRITE_BLOCK_ABORT; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;

		when WRITE_BLOCK_TERMINATE =>
			-- Terminate multiple block write
			if multiple then
				new_data_out <= x"FD"; -- stop token, multiple block
				new_multiple <= false; -- So that WRITE_BLOCK_WAIT will exit to WRITE_BLOCK_FINISH
				new_sr_return_state <= WRITE_BLOCK_WAIT; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			else
				new_state <= WRITE_BLOCK_FINISH;
			end if;
		
		when WRITE_BLOCK_FINISH =>
			-- Wait for WR to fall after last byte has been transferred
			if (wr='0' and wr_multiple='0') then
				new_state <= IDLE;
			end if;
		
		when SEND_RCV =>
			-- Send the byte in data_out while simultaneously receiving one into data_in
			-- ** Must enter with bit_counter = 7 **
			-- Update CRC7 and CRC16 from output stream
			-- Update CRC16 from input stream
			-- Decrement byte_counter
			-- Leave data_out as 11111111
			-- Leave bit_counter as 7 for next time
			
			-- When we enter SPI Clock should be low, we set the output data, wait half a cycle, raise
			-- the clock, latch the input data, then wait a further half cycle before dropping the clock
			-- The output data (MOSI) follows data_out(7)
			
			-- Clock is low, output data is set
			if slow_clock=false or clock_divider=0 then
				new_clock_divider <= slowClockDivider;
				new_sclk <= '1';
				-- Update output CRCs
				new_crc7 <= crc7(5 downto 3) & (crc7(2) xor crc7(6) xor data_out(7)) & crc7(1 downto 0) & (crc7(6) xor data_out(7));
				new_out_crc16 <= out_crc16(14 downto 12) & (data_out(7) xor out_crc16(15) xor out_crc16(11)) & out_crc16(10 downto 5) &
				(data_out(7) xor out_crc16(15) xor out_crc16(4)) & out_crc16(3 downto 0) & (data_out(7) xor out_crc16(15));
				-- Update input data
				new_data_in <= data_in(6 downto 0) & miso;
				-- Update input CRC
				new_in_crc16 <= in_crc16(14 downto 12) & (miso xor in_crc16(15) xor in_crc16(11)) & in_crc16(10 downto 5) &
					(miso xor in_crc16(15) xor in_crc16(4)) & in_crc16(3 downto 0) & (miso xor in_crc16(15));
				new_state <= SEND_RCV_CLK1;
			else
				new_clock_divider <= clock_divider - 1;
			end if;

		when SEND_RCV_CLK1 =>
			if slow_clock=false or clock_divider=0 then
				new_clock_divider <= slowClockDivider;
				if (bit_counter = 0) then
					-- Reception handling - if DAvail and DTaken are down, transfer new byte into output register and raise DAvail
					if transfer_data_out then
						if (rd='1' or rd_multiple='1') then
							if sDavail='0' and dout_taken='0' then
								-- If we're ok to transfer data, then do it
								-- otherwise wait here until dout_taken rises
								set_davail <= true;
								new_byte_counter <= byte_counter - 1; set_byte_counter <= true;
								-- Next byte
								new_bit_counter <= 7;
								if byte_counter=1 then
									new_transfer_data_out <= false;
									new_sr_return_state <= READ_BLOCK_CRC;
									set_sr_return_state <= true;
								end if;
								new_state <= SEND_RCV;
							end if;
						else
							-- Abort transfer
							new_byte_counter <= byte_counter - 1; set_byte_counter <= true;
							-- Next byte
							new_bit_counter <= 7;
							if byte_counter=1 then
								new_transfer_data_out <= false;
								new_sr_return_state <= READ_BLOCK_CRC;
								set_sr_return_state <= true;
							end if;
							new_state <= SEND_RCV;
						end if;
					else
						new_bit_counter <= 7;
						new_state <= sr_return_state;
						new_byte_counter <= byte_counter - 1; set_byte_counter <= true;
					end if;
				else
					new_bit_counter <= bit_counter - 1;
					new_data_out <= data_out(6 downto 0) & '1';
					new_state <= SEND_RCV;
				end if;
			else
				new_sclk <= '1';
				new_clock_divider <= clock_divider - 1;
			end if;

		when SEND_CMD =>
         -- The card is ready to accept a new command, when MISO is 1
         if miso = '1' then
            -- Send FF byte first
            new_bit_counter <= 7;
            new_data_out <= "11111111";
            new_sr_return_state <= SEND_CMD_1; set_sr_return_state <= true;
            new_state <= SEND_RCV;            
         else
            new_sclk <= not temp_sclk;
            new_data_out <= "11111111";         
            new_state <= SEND_CMD;
         end if;
			
		when SEND_CMD_1 =>
			-- Initialise CRC and byte counter
			new_crc7 <= "0000000";
			new_byte_counter <= 5; set_byte_counter <= true; -- 5 bytes are CC NN NN NN NN
			new_state <= SEND_CMD_2;
         			
		when SEND_CMD_2 =>
			-- Send one byte of the command and parameter
			if byte_counter=0 then
				new_state <= SEND_CMD_3;
			else
				new_data_out <= cmd_out(39 downto 32);
				new_cmd_out <= cmd_out(31 downto 0) & x"FF"; set_cmd_out <= true;
				new_sr_return_state <= SEND_CMD_2; set_sr_return_state <= true;
				new_state <= SEND_RCV;
			end if;
	
		when SEND_CMD_3 =>
			-- Send the CRC
			new_data_out <= crc7 & '1';
			new_sr_return_state <= SEND_CMD_4; set_sr_return_state <= true;
			new_state <= SEND_RCV;

		when SEND_CMD_4 =>
			-- Receive the first byte, maybe R1
			new_byte_counter <= R1_TIMEOUT; set_byte_counter <= true;
			new_sr_return_state <= SEND_CMD_5; set_sr_return_state <= true;
			new_state <= SEND_RCV;
			
		when SEND_CMD_5 =>
			-- Check for R1 response, receive another byte if not
			if skipFirstR1Byte then
				-- If doing a CMD12 then skip a byte before looking for R1
				new_skipFirstR1Byte <= false;
				new_state <= SEND_RCV;
			elsif data_in(R1_ZERO)='0' then
            new_state <= return_state;
            if is_in_reset_cycle = '0' then
               new_original_state <= RST;
            end if;
			else
				if byte_counter=0 then
               -- brute force workaround so that some (most?) SDHC cards work: perform a retry
               if original_state /= RST and state_retry_count < ACTION_RETRIES then                  
                  new_state_retry_count <= state_retry_count + 1;
                  new_state <= RST;
               else
                  new_card_type <= ct_None;
                  new_error <= '1';
                  new_error_code <= ec_NoSDError;
               end if;
				else
					new_state <= SEND_RCV; -- Will come back to SEND_CMD_5
				end if;
			end if;
                       
	   end case;
	end process calcStateVariables;

	-- This calculates a debug output to determine the FSM state
	calcDebugOutputs: block
	begin
		with state select sd_fsm <=
			x"00" when RST,
			x"00" when RST2,
			x"01" when INIT,
			x"02" when CMD0,
			x"03" when CMD8,
			x"04" when CMD8R1,
			x"04" when CMD8B2,
			x"04" when CMD8B3,
			x"04" when CMD8B4,
			x"04" when CMD8GOTB4,
			x"05" when CMD55,
			x"06" when CMD41,
			x"07" when POLL_CMD,
			x"08" when CMD58,
			x"08" when CMD58R1,
			x"08" when CMD58B2,
			x"08" when CMD58B3,
			x"08" when CMD58B4,
         x"12" when CMD16,
         x"13" when CMD16R1,
			x"09" when CMD59,
			x"0A" when CMD59R1,
			x"10" when IDLE,
			x"11" when IDLE2,
			x"20" when READ_BLOCK,
			x"20" when READ_MULTIPLE_BLOCK,
			x"21" when READ_BLOCK_R1,
			x"22" when READ_BLOCK_WAIT_CHECK,
			x"23" when READ_BLOCK_DATA,
			x"24" when READ_BLOCK_SKIP,
			x"25" when READ_BLOCK_CRC,
			x"26" when READ_BLOCK_CHECK_CRC,
			x"27" when READ_BLOCK_FINISH,
			x"28" when READ_MULTIPLE_BLOCK_STOP,
			x"29" when READ_MULTIPLE_BLOCK_STOP_2,
			x"30" when SEND_RCV,
			x"31" when SEND_RCV_CLK1,
			x"32" when SEND_CMD,
			x"33" when SEND_CMD_1,
			x"34" when SEND_CMD_2,
			x"35" when SEND_CMD_3,
			x"36" when SEND_CMD_4,
			x"37" when SEND_CMD_5,
			x"40" when SET_ERASE_COUNT_CMD,
			x"41" when SET_ERASE_COUNT_CMD_2,
			x"42" when WRITE_BLOCK_CMD,
			x"43" when WRITE_MULTIPLE_BLOCK_CMD,
			x"44" when WRITE_BLOCK_INIT,
			x"45" when WRITE_BLOCK_DATA,
			x"46" when WRITE_BLOCK_DATA_TOKEN,
			x"47" when START_WRITE_BLOCK_DATA,
			x"48" when WRITE_BLOCK_SEND_CRC2,
			x"49" when WRITE_BLOCK_GET_RESPONSE,
			x"4A" when WRITE_BLOCK_CHECK_RESPONSE,
			x"4B" when WRITE_BLOCK_WAIT,
			x"4C" when WRITE_BLOCK_ABORT,
			x"4D" when WRITE_BLOCK_TERMINATE,
			x"4E" when WRITE_BLOCK_FINISH,
         x"FF" when others
         ;
	end block calcDebugOutputs;
   
   mosi <= data_out(7);   
end rtl;

