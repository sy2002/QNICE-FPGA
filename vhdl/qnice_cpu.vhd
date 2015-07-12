----------------------------------------------------------------------------------
-- FPGA implementation of the QNICE 16 bit CPU architecture version 1.2
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

entity QNICE_CPU is
port (
	-- clock
	CLK				: in std_logic;
	RESET				: in std_logic;
	
	ADDR				: out std_logic_vector(15 downto 0);		-- 16 bit address bus
	
	-- tristate 16 bit data bus
	DATA  			: inout std_logic_vector(15 downto 0);		-- send/receive data
	DATA_DIR			: out std_logic;									-- 1=DATA is sending, 0=DATA is receiving
	DATA_VALID		: out std_logic;									-- while DATA_DIR = 1: DATA contains valid data
	
	-- debug output
	dbg_cpustate	: out std_logic_vector(2 downto 0)
);
end QNICE_CPU;

architecture beh of QNICE_CPU is

-- TriState buffer/driver
component TriState_Buffer is
generic (
	DATA_WIDTH				: integer range 1 to 32
);
port (
	I_CLK                : in    std_logic;  -- synchronized with bidir bus
	I_DIR_CTRL           : in    std_logic;  -- 3-state enable input, high=output, low=input
	
	IO_DATA              : inout std_logic_vector(DATA_WIDTH - 1 downto 0);  -- data to/from external pin on bidir bus
	
	I_DATA_TO_EXTERNAL   : in    std_logic_vector(DATA_WIDTH - 1 downto 0);  -- data to send over bidir bus
	O_DATA_FROM_EXTERNAL : out   std_logic_vector(DATA_WIDTH - 1 downto 0)   -- data received over bidir bus	
);
end component;


type tCPU_States is (cs_poweron,
							cs_reset,

							cs_fetch_start,
							cs_fetch_dbg,
							cs_fetch_dbg2,
							
							cs_decode,
							cs_execute,
							cs_halt);

signal cpu_state				: tCPU_States := cs_reset;
signal cpu_state_next		: tCPU_States;

signal DATA_Dir_Ctrl			: std_logic;
signal DATA_To_Bus		 	: std_logic_vector(15 downto 0);
signal DATA_From_Bus			: std_logic_vector(15 downto 0);

signal PC						: std_logic_vector(15 downto 0); -- program counter

-- state machine output buffers

signal fsmDataToBus			: std_logic_vector(15 downto 0);
signal fsmPC					: std_logic_vector(15 downto 0);
signal fsmCpuAddr				: std_logic_vector(15 downto 0);
signal fsmCpuDataDirCtrl	: std_logic;
signal fsmCpuDataValid		: std_logic;

begin

	-- TriState buffer/driver for the 16 bit DATA bus
	DATA_driver : TriState_Buffer
		generic map
		(
			DATA_WIDTH => 16
		)
		port map
		(
			I_CLK => CLK,
			I_DIR_CTRL => DATA_Dir_Ctrl,
			IO_DATA => DATA,
			I_DATA_TO_EXTERNAL => DATA_To_Bus,
			O_DATA_FROM_EXTERNAL => DATA_From_Bus
		);
	
	-- state machine: advance to next state and transfer output values
	fsm_advance_state : process (CLK)
	begin
		if rising_edge(CLK) then
			if RESET = '1' then
				cpu_state <= cs_reset;
				
				DATA_To_Bus <= (others => 'U');
				PC <= (others => '0');
				ADDR <= (others => '0');
				DATA_DIR <= '0';
				DATA_Dir_Ctrl <= '0';
				DATA_VALID <= '0';				
			else
				cpu_state <= cpu_state_next;
				
				DATA_To_Bus <= fsmDataToBus;
				PC <= fsmPC;
				ADDR <= fsmCpuAddr;
				DATA_DIR <= fsmCpuDataDirCtrl;
				DATA_Dir_Ctrl <= fsmCpuDataDirCtrl;
				DATA_VALID <= fsmCpuDataValid;
			end if;
		end if;
	end process;
	
	fsm_output_decode : process (cpu_state, PC, DATA_From_Bus)
	begin
		-- as fsm_advance_state is clocking the values on rising edges,
		-- the below-mentioned output decoding is to be read as:
		-- "what will be the output variables at the NEXT state (after the current state)"
		case cpu_state is
			when cs_reset =>
				fsmDataToBus <= (others => 'U');
				fsmPC <= (others => '0');
				fsmCpuAddr <= (others => '0');
				fsmCpuDataDirCtrl <= '0';
				fsmCpuDataValid <= '0';
										
			-- as the previous state cs_reset sets the direction control to read and the address to 0,
			-- the DATA_driver will take care, that at the falling edge of cs_fetch_start's
			-- clock cycle, DATA_From_Bus will be valid to be read at the next state (cs_fetch_dbg)
			when cs_fetch_start =>
				fsmDataToBus <= DATA_From_Bus; -- will be valid from the falling edge on
				fsmPC <= PC;						 
				fsmCpuAddr <= x"8000";
				fsmCpuDataDirCtrl <= '1';
				fsmCpuDataValid <= '0';
				
			-- DATA_driver is writing on rising edge, i.e. we need to hold the data to be
			-- written for one more cycle after cs_fetch_dbg
			when cs_fetch_dbg =>
				fsmDataToBus <= DATA_From_Bus;
				fsmPC <= PC;
				fsmCpuAddr <= x"8000";
				fsmCpuDataDirCtrl <= '1';
				fsmCpuDataValid <= '1';
			
			when cs_fetch_dbg2 =>
				fsmDataToBus <= (others => 'U');
				fsmPC <= std_logic_vector(unsigned(PC) + 1);
				fsmCpuAddr <= fsmPC;
				fsmCpuDataDirCtrl <= '0';
				fsmCpuDataValid <= '0';
			
			when others =>
				fsmDataToBus <= (others => 'U');
				fsmPC <= (others => 'U');
				fsmCpuAddr <= (others => 'U');
				fsmCpuDataDirCtrl <= 'U';
				fsmCpuDataValid <= 'U';
				
		end case;
	end process;
	
	-- main CPU state machine that runs through the enum cpu_state
	fsm_next_state_decode : process (cpu_state)
	begin
		case cpu_state is
			when cs_reset 			=> cpu_state_next <= cs_fetch_start;						
			when cs_fetch_start 	=> cpu_state_next <= cs_fetch_dbg;
			when cs_fetch_dbg 	=> cpu_state_next <= cs_fetch_dbg2;
			when cs_fetch_dbg2	=> cpu_state_next <= cs_fetch_start;
			when others 			=> cpu_state_next <= cpu_state;
		end case;
	end process;
						
	with cpu_state select
		dbg_cpustate <= "000" when cs_reset,
							 "001" when cs_fetch_start,
							 "010" when cs_fetch_dbg,
							 "011" when cs_fetch_dbg2,
							 "111" when others;	
end beh;

