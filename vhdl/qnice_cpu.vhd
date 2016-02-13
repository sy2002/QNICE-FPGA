----------------------------------------------------------------------------------
-- FPGA implementation of the QNICE 16 bit CPU architecture version 1.2
-- 
-- done in 2015, 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.cpu_constants.all;

entity QNICE_CPU is
port (
   -- clock
   CLK            : in std_logic;
   RESET          : in std_logic;
   
   WAIT_FOR_DATA  : in std_logic;                           -- 1=CPU adds wait cycles while re-reading from bus
   
   ADDR           : out std_logic_vector(15 downto 0);      -- 16 bit address bus
   
   -- tristate 16 bit data bus
   DATA           : inout std_logic_vector(15 downto 0);    -- send/receive data
   DATA_DIR       : out std_logic;                          -- 1=DATA is sending, 0=DATA is receiving
   DATA_VALID     : out std_logic;                          -- while DATA_DIR = 1: DATA contains valid data
   
   -- signals about the CPU state
   HALT           : out std_logic                           -- 1=CPU halted due to the HALT command, 0=running
);
end QNICE_CPU;

architecture beh of QNICE_CPU is

-- TriState buffer/driver
component TriState_Buffer is
generic (
   DATA_WIDTH           : integer range 1 to 32
);
port (
   I_CLK                : in    std_logic;  -- synchronized with bidir bus
   I_DIR_CTRL           : in    std_logic;  -- 3-state enable input, high=output, low=input
   
   IO_DATA              : inout std_logic_vector(DATA_WIDTH - 1 downto 0);  -- data to/from external pin on bidir bus
   
   I_DATA_TO_EXTERNAL   : in    std_logic_vector(DATA_WIDTH - 1 downto 0);  -- data to send over bidir bus
   O_DATA_FROM_EXTERNAL : out   std_logic_vector(DATA_WIDTH - 1 downto 0)   -- data received over bidir bus 
);
end component;

-- QNICE specific register file
component register_file is
port (
   clk         : in  std_logic;   -- clock: writing occurs at the rising edge
   
   -- input stack pointer (SP) status register (SR) and program counter (PC) so
   -- that they can conveniently be read when adressing 13 (SP), 14 (SR), 15 (PC)
   SP          : in std_logic_vector(15 downto 0);   
   SR          : in std_logic_vector(15 downto 0);
   PC          : in std_logic_vector(15 downto 0);   
   
   -- select the appropriate register window for the lower 8 registers
   sel_rbank   : in  std_logic_vector(7 downto 0);
      
   -- read register addresses and read result
   read_addr1  : in  std_logic_vector(3 downto 0);
   read_addr2  : in  std_logic_vector(3 downto 0);
   read_data1  : out std_logic_vector(15 downto 0);
   read_data2  : out std_logic_vector(15 downto 0);
   
   -- write register address & data and write enable
   write_addr  : in  std_logic_vector(3 downto 0);
   write_data  : in  std_logic_vector(15 downto 0);
   write_en    : in  std_logic 
);
end component;

-- ALU
component alu is
port (
   opcode      : in std_logic_vector(3 downto 0);
   
   -- input1 is meant to be source (Src) and input2 is meant to be destination (Dst)
   -- c_in is carry in
   input1      : in IEEE.NUMERIC_STD.unsigned(15 downto 0);
   input2      : in IEEE.NUMERIC_STD.unsigned(15 downto 0);
   c_in        : in std_logic;
   x_in        : in std_logic;
   
   -- ALU operation result and flags
   result      : out IEEE.NUMERIC_STD.unsigned(15 downto 0);
   X           : out std_logic;
   C           : out std_logic;
   Z           : out std_logic;
   N           : out std_logic;
   V           : out std_logic
);
end component;      


-- CPU's main state machine
type tCPU_States is (cs_reset,
                     
                     cs_fetch,

                     -- depending of adressing modes of the instruction, we
                     -- have a variable length execution that either jumps
                     -- directly from cs_decode to cs_execute (src and dst adressing
                     -- are direct) or run through either one of or both of the
                     -- cs_exeprep_get_* states
                     cs_decode,
                     
                     cs_exeprep_get_src_indirect,
                     cs_exeprep_get_dst_indirect,
                     
                     cs_execute,
                     
                     cs_exepost_store_dst_indirect,

                     cs_exepost_sub,                     
                     cs_exepost_prepfetch,
                     
                     cs_halt,
                     cs_std_seq     -- continue with standard sequence, used by fsmNextCpuState
                    );
signal cpu_state           : tCPU_States := cs_reset;
signal cpu_state_next      : tCPU_States;

-- CPU i/o signals
signal ADDR_Bus            : std_logic_vector(15 downto 0) := (others => '0');
signal DATA_Dir_Ctrl       : std_logic := '0';
signal DATA_To_Bus         : std_logic_vector(15 downto 0) := (others => '0');
signal DATA_From_Bus       : std_logic_vector(15 downto 0) := (others => '0');

-- register bank signals for accessing R0 .. R13
signal reg_read_addr1      : std_logic_vector(3 downto 0) := (others => '0');
signal reg_read_addr2      : std_logic_vector(3 downto 0) := (others => '0');
signal reg_read_data1      : std_logic_vector(15 downto 0);
signal reg_read_data2      : std_logic_vector(15 downto 0);   
signal reg_write_addr      : std_logic_vector(3 downto 0) := (others => '0');
signal reg_write_data      : std_logic_vector(15 downto 0) := (others => '0');
signal reg_write_en        : std_logic := '0';   

-- registers R13 (SP), R14 (SR) and R15 (PC) are directly modeled within the CPU
-- but also read-only accessible via the register file
signal SP                  : std_logic_vector(15 downto 0) := x"0000"; -- stack pointer (R13)
signal SR                  : std_logic_vector(15 downto 0) := x"0001"; -- status register (R14)
signal PC                  : std_logic_vector(15 downto 0) := x"0000"; -- program counter (R15)

-- intstruction related internal CPU registers
signal Instruction         : std_logic_vector(15 downto 0) := (others => '0'); -- current instruction word
signal Opcode              : std_logic_vector(3 downto 0);  -- current opcode, equals bits 15 .. 12
signal Src_RegNo           : std_logic_vector(3 downto 0);  -- current source register, equals bits 11 .. 8
signal Src_Mode            : std_logic_vector(1 downto 0);  -- current source mode, equals bits 7 .. 6
signal Src_Value           : std_logic_vector(15 downto 0) := (others => '0'); -- the value is coming from a register or from memory
signal Dst_RegNo           : std_logic_vector(3 downto 0);  -- current destination register, equals bits 5 .. 2
signal Dst_Mode            : std_logic_vector(1 downto 0);  -- current destination mode, equals bits 1 .. 0
signal Dst_Value           : std_logic_vector(15 downto 0) := (others => '0'); -- the value is coming from a register or from memory
signal Bra_Mode            : std_logic_vector(1 downto 0);  -- branch mode (branch type)
signal Bra_Neg             : std_logic;                     -- branch condition negated
signal Bra_Condition       : std_logic_vector(2 downto 0);  -- flag number within lower 8 bits of SR

-- state machine output buffers
signal fsmDataToBus        : std_logic_vector(15 downto 0);
signal fsmCpuAddr          : std_logic_vector(15 downto 0);
signal fsmCpuDataDirCtrl   : std_logic;
signal fsmCpuDataValid     : std_logic;
signal fsmSP               : std_logic_vector(15 downto 0);
signal fsmSR               : std_logic_vector(15 downto 0);
signal fsmPC               : std_logic_vector(15 downto 0);
signal fsmNextCpuState     : tCPU_States;

signal fsmInstruction      : std_logic_vector(15 downto 0);
signal fsm_reg_read_addr1  : std_logic_vector(3 downto 0);
signal fsm_reg_read_addr2  : std_logic_vector(3 downto 0);
signal fsm_reg_write_addr  : std_logic_vector(3 downto 0);
signal fsm_reg_write_data  : std_logic_vector(15 downto 0);
signal fsm_reg_write_en    : std_logic := '0';

signal fsmSrc_Value        : std_logic_vector(15 downto 0);
signal fsmDst_Value        : std_logic_vector(15 downto 0);

-- ALU signals are purely combinatorical
signal Alu_Result          : IEEE.NUMERIC_STD.unsigned(15 downto 0); -- execution result
signal Alu_X               : std_logic;
signal Alu_C               : std_logic;
signal Alu_Z               : std_logic;
signal Alu_N               : std_logic;
signal Alu_V               : std_logic;


begin

-- @TODO (priority 2): Completely re-do the Tristate buffer topic. The lenghty wait-state and the #0000 situation when
-- writing are not necessary! As we have enough flip-flops, the Tristate handling can be done in "real-time".
-- as this has probably some pretty far reaching impact, the question is when to implement this. On the other hand,
-- the longer we wait, the bigger the impact will be. Some analysis with some MOVE, ADD & Co indirect @memory read/write
-- scenario will for sure help and create a more clear view.

   -- TriState buffer/driver for the 16 bit DATA bus
   DATA_driver : TriState_Buffer
      generic map
      (
         DATA_WIDTH => 16
      )
      port map
      (
         I_CLK       => CLK,
         I_DIR_CTRL  => DATA_Dir_Ctrl,
         IO_DATA     => DATA,
         I_DATA_TO_EXTERNAL => DATA_To_Bus,
         O_DATA_FROM_EXTERNAL => DATA_From_Bus
      );
      
   -- Registers
   Registers : register_file
      port map
      (
         clk         => CLK,
         SP          => SP,
         SR          => SR,
         PC          => PC,
         sel_rbank   => SR(15 downto 8),
         read_addr1  => reg_read_addr1,
         read_addr2  => reg_read_addr2,
         read_data1  => reg_read_data1,
         read_data2  => reg_read_data2,
         write_addr  => reg_write_addr,
         write_data  => reg_write_data,
         write_en    => reg_write_en
      );
      
   -- ALU
   QNICE_ALU : alu
      port map
      (
         opcode      => Opcode,
         input1      => IEEE.NUMERIC_STD.unsigned(Src_Value),
         input2      => IEEE.NUMERIC_STD.unsigned(Dst_Value),
         c_in        => SR(2),
         x_in        => SR(1),
         result      => Alu_Result,
         X           => Alu_X,
         C           => Alu_C,
         Z           => Alu_Z,
         N           => Alu_N,
         V           => Alu_V
      );
             
   -- state machine: advance to next state and transfer output values
   fsm_advance_state : process (CLK)
   begin
      if rising_edge(CLK) then
         if RESET = '1' then
            cpu_state <= cs_reset;
            
            DATA_To_Bus <= (others => '0');
            ADDR_Bus <= x"0000";
            DATA_DIR <= '0';
            DATA_Dir_Ctrl <= '0';
            DATA_VALID <= '0';
            
            SP <= x"0000";
            SR <= x"0001";
            PC <= x"0000";
            
            Instruction <= (others => '0');            
            Src_Value <= (others => '0');
            Dst_Value <= (others => '0');
            
            reg_read_addr1 <= (others => '0');
            reg_read_addr2 <= (others => '0');
            reg_write_addr <= (others => '0');
            reg_write_data <= (others => '0');
            reg_write_en <= '0';           
         else
            if fsmNextCpuState = cs_std_seq then
               cpu_state <= cpu_state_next;
            else
               cpu_state <= fsmNextCpuState;
            end if;
                        
            DATA_To_Bus <= fsmDataToBus;
            ADDR_Bus <= fsmCpuAddr;
            DATA_DIR <= fsmCpuDataDirCtrl;
            DATA_Dir_Ctrl <= fsmCpuDataDirCtrl;
            DATA_VALID <= fsmCpuDataValid;
            
            SP <= fsmSP;
            SR <= fsmSR(15 downto 1) & "1";
            PC <= fsmPC;
            
            Instruction <= fsmInstruction;
            Src_Value <= fsmSrc_Value;
            Dst_Value <= fsmDst_Value;
            
            reg_read_addr1 <= fsm_reg_read_addr1;
            reg_read_addr2 <= fsm_reg_read_addr2;            
            reg_write_addr <= fsm_reg_write_addr;
            reg_write_data <= fsm_reg_write_data;
            reg_write_en <= fsm_reg_write_en;            
         end if;
      end if;
   end process;
   
   fsm_output_decode : process (cpu_state, ADDR_Bus, SP, SR, PC,
                                DATA_To_Bus, DATA_From_Bus, WAIT_FOR_DATA,
                                Instruction, Opcode,
                                Src_RegNo, Src_Mode, Src_Value, Dst_RegNo, Dst_Mode, Dst_Value,
                                Bra_Mode, Bra_Condition, Bra_Neg,
                                reg_read_addr1, reg_read_data1, reg_read_addr2, reg_read_data2,
                                reg_write_addr, reg_write_data, reg_write_en,
                                Alu_Result, Alu_V, Alu_N, Alu_Z, Alu_C, Alu_X)                                                                
   begin
      fsmDataToBus <= (others => '0');
      fsmSP <= SP;
      fsmSR <= SR(15 downto 1) & "1";
      fsmPC <= PC;
      fsmCpuAddr <= ADDR_Bus;
      fsmCpuDataDirCtrl <= '0';
      fsmCpuDataValid <= '0';
      fsmNextCpuState <= cs_std_seq;
      fsmInstruction <= Instruction;
      fsmSrc_Value <= Src_Value;
      fsmDst_Value <= Dst_Value;
      fsm_reg_read_addr1 <= reg_read_addr1;
      fsm_reg_read_addr2 <= reg_read_addr2;
      fsm_reg_write_addr <= reg_write_addr;
      fsm_reg_write_data <= reg_write_data;
      fsm_reg_write_en <= '0';
   
      -- as fsm_advance_state is clocking the values on rising edges,
      -- the below-mentioned output decoding is to be read as:
      -- "what will be the output variables at the NEXT state (after the current state)"
      case cpu_state is
         when cs_reset =>
            fsmSR <= x"0001";
            fsmPC <= x"0000";
            fsmCpuAddr <= x"0000";
            fsmCpuDataDirCtrl <= '0';
            fsmCpuDataValid <= '0';
            fsmNextCpuState <= cs_std_seq;
            fsmInstruction <= (others => '0');
              
         -- as the previous state sets the direction control to read and the address to a meaningful value
         -- (i.e. 0 after cs_reset or current PC afterwards), the DATA_driver will take care, that at the
         -- falling edge of cs_fetch's clock cycle, DATA_From_Bus will contain the next opcode
         when cs_fetch =>
            -- add wait cycles, if necessary (e.g. due to slow RAM)
            if WAIT_FOR_DATA = '1' then
               fsmNextCpuState <= cs_fetch;
               
            -- data from bus is available
            else         
               fsmInstruction <= DATA_From_Bus; -- valid at falling edge
               fsmPC <= PC + 1;
               fsm_reg_read_addr1 <= DATA_From_Bus(11 downto 8); -- read Src register number
               fsm_reg_read_addr2 <= DATA_From_Bus(5 downto 2);  -- rest Dst register number
            end if;
                                    
         when cs_decode =>
            -- source and destination values in case of direct register addressing modes
            -- no special handling of SR and PC needed, as this a a read-only activity
            -- and the registerfile contains a convenience function for that
            fsmSrc_Value <= reg_read_data1;
            fsmDst_Value <= reg_read_data2;
            
            -- decode addressing modes for source and destination
            -- if source is alrady indirect, then ignore destination for now
            -- (will be decoded within cs_exeprep_get_src_indirect)
            if Src_Mode /= amDirect then
               fsmNextCpuState <= cs_exeprep_get_src_indirect;
               
               -- perform pre decrement, if necessary and then put
               -- the address on the data bus for reading
               if Src_Mode = amIndirPreDec then
               
                  -- put pre decremented address on the data bus for reading
                  fsmCpuAddr <= reg_read_data1 - 1;
                  
                  -- write back the decremented values
                  -- special handling of SR and PC as they are not stored in the register file
                  case Src_RegNo is
                     when x"D" => fsmSP <= SP - 1;
                     when x"E" => fsmSR <= SR - 1;
                     when x"F" => fsmPC <= PC - 1;
                     when others =>
                        fsm_reg_write_addr <= Src_RegNo;
                        fsm_reg_write_data <= reg_read_data1 - 1;
                        fsm_reg_write_en <= '1';               
                  end case;                  
               else
                  fsmCpuAddr <= reg_read_data1; -- normal (non decremented) address on the bus for reading
               end if;
           
            -- in case of a branch, Dst_Mode would contain garbage, therefore perform an explicit check
            -- optimization: in case of MOVE the destination value is ignored anyway, so we can skip
            -- the whole indirect parameter fetch in this case
            elsif Opcode /= opcBRA and Dst_Mode /= amDirect and (Opcode /= opcMOVE or Dst_Mode = amIndirPreDec) then
               fsmNextCpuState <= cs_exeprep_get_dst_indirect;
               
               -- pre decrement for destination register
               if Dst_Mode = amIndirPreDec then
                  fsmCpuAddr <= reg_read_data2 - 1;
                  case Dst_RegNo is
                     when x"D" => fsmSP <= SP - 1;
                     when x"E" => fsmSR <= SR - 1;
                     when x"F" => fsmPC <= PC - 1;
                     when others =>
                        fsm_reg_write_addr <= Dst_RegNo;
                        fsm_reg_write_data <= reg_read_data2 - 1;
                        fsm_reg_write_en <= '1';
                  end case;
               
               -- normal (non decremented) address on the bus for reading
               else
                  fsmCpuAddr <= reg_read_data2;
               end if;
            end if;

            -- halt the CPU
            if Opcode = opcHalt then
               fsmNextCpuState <= cs_halt;
            end if;

         when cs_exeprep_get_src_indirect =>
            -- add wait cycles, if necessary (e.g. due to slow RAM)
            if WAIT_FOR_DATA = '1' then
               fsmNextCpuState <= cs_exeprep_get_src_indirect;
               
            -- data from bus is available
            else
               -- read the indirect value from the bus and store it
               fsmSrc_Value <= DATA_FROM_Bus;
                             
               -- perform post increment
               if Src_Mode = amIndirPostInc then
                  -- special handling of SR and PC as they are not stored in the register file
                  case Src_RegNo is
                     when x"D" => fsmSP <= SP + 1;
                     when x"E" => fsmSR <= SR + 1;
                     when x"F" => fsmPC <= PC + 1;
                     when others =>
                        fsm_reg_write_addr <= Src_RegNo;
                        fsm_reg_write_data <= Src_Value + 1;
                        fsm_reg_write_en <= '1';               
                  end case;
               end if;
                                 
               -- decode the destination addressing mode (and avoid garbage due to a branch opcode)
               -- optimization: in case of MOVE the destination value is ignored anyway, so we can skip
               -- the whole indirect parameter fetch in this case               
               if Opcode /= opcBRA and Dst_Mode /= amDirect and (Opcode /= opcMOVE or Dst_Mode = amIndirPreDec) then
                  -- this code is nearly identical to the above-mentioned code
                  -- within "elsif Dst_Mode /= amDirect then"
                  fsmNextCpuState <= cs_exeprep_get_dst_indirect;                  
                  if Dst_Mode = amIndirPreDec then
                     fsmCpuAddr <= reg_read_data2 - 1;
                     case Dst_RegNo is
                        when x"D" => fsmSP <= SP - 1;
                        when x"E" => fsmSR <= SR - 1;
                        when x"F" => fsmPC <= PC - 1;
                        when others =>
                           fsm_reg_write_addr <= Dst_RegNo;
                           fsm_reg_write_data <= Dst_Value - 1; -- here, the code is not identical
                           fsm_reg_write_en <= '1';
                     end case;
                  else
                     fsmCpuAddr <= reg_read_data2;
                  end if;               
               end if;
            end if;

         when cs_exeprep_get_dst_indirect =>
            -- add wait cycles, if necessary (e.g. due to slow RAM)
            if WAIT_FOR_DATA = '1' then
               fsmNextCpuState <= cs_exeprep_get_dst_indirect;
               
            -- data from bus is available
            else         
               -- read the indirect value from the bus and store it
               fsmDst_Value <= DATA_FROM_Bus;
            end if;                        
                        
         when cs_execute =>
         
            -- execute branches
            if Opcode = opcBRA then
               fsmNextCpuState <= cs_fetch;
               fsmSR <= SR(15 downto 8) & "00000001"; -- clear flags
               fsmCpuAddr <= PC;
               
               if SR(conv_integer(Bra_Condition)) = not Bra_Neg then             
                  case Bra_Mode is
                     when bmABRA =>
                        fsmPC <= Src_Value;
                        fsmCpuAddr <= Src_Value;
                  
                     when bmRBRA =>
                        fsmPC <= PC + Src_Value;
                        fsmCpuAddr <= PC + Src_Value;
                        
                     when bmASUB | bmRSUB =>
                        -- decrease stack pointer and store the current program
                        -- counter to the memory address where the decreased
                        -- stack pointer is pointing to
                        fsmSP <= SP - 1;
                        fsmCpuAddr <= SP - 1;
                        fsmDataToBus <= PC;
                        fsmCpuDataDirCtrl <= '1';
                        fsmCpuDataValid <='0';
                        fsmNextCpuState <= cs_exepost_sub;
                                               
                     when others =>
                        fsmNextCpuState <= cs_halt;
                  end case;
               end if;
            
            -- execute all comands other than branches
            else
            
               -- As the ALU is a purely combinatorical circuit, ALU's calculation is
               -- immediatelly done, when cs_execute i entered. We need to make sure,
               -- that all ALU inputs contain valid data at this moment in time
               
               -- store flags
               fsmSR <= SR(15 downto 8) & "00" & Alu_V & Alu_N & Alu_Z & Alu_C & Alu_X & "1";
               
               -- store result: direct
               if Dst_Mode = amDirect then
               
                  -- store result in register
                  case Dst_RegNo is
                     -- R13 aka SP
                     when x"D" =>
                        fsmSP <= std_logic_vector(Alu_Result);
                     
                     -- R14 aka SR
                     when x"E" =>
                        -- not all parts of the SR are writeable: only the upper 8 bit plus
                        -- the M, C and X register are writeable, 
                        fsmSR(15 downto 8) <= std_logic_vector(Alu_Result(15 downto 8));
                        fsmSR(7) <= std_logic(Alu_Result(7)); -- M
                        fsmSR(2) <= std_logic(Alu_Result(2)); -- C
                        fsmSR(1) <= std_logic(Alu_Result(1)); -- X
                        
                     -- R15 aka PC
                     when x"F" =>
                        fsmPC <= std_logic_vector(Alu_Result);
                        fsmCpuAddr <= std_logic_vector(Alu_Result);
                        
                     -- R0 .. R12
                     when others =>
                        fsm_reg_write_addr <= Dst_RegNo;
                        fsm_reg_write_data <= std_logic_vector(Alu_Result);
                        fsm_reg_write_en <= '1';
                  end case;
                  
                  -- prepare next fetch by outputting the next instruction's address
                  -- but only, if the target register of this operation was not the PC (R15)
                  if (Dst_RegNo /= x"F") then
                     fsmCpuAddr <= PC;
                  end if;
                  
               -- store result: indirect
               else
                  fsmNextCpuState <= cs_exepost_store_dst_indirect;
                  fsmCpuAddr <= reg_read_data2;
                  fsmDataToBus <= std_logic_vector(Alu_Result);
                  fsmCpuDataDirCtrl <= '1';
                  fsmCpuDataValid <='0';
               end if;               
            end if;
                               
         when cs_exepost_store_dst_indirect =>
            fsmDataToBus <= DATA_To_Bus;
            fsmCpuDataDirCtrl <= '1';
            fsmCpuDataValid <= '1';
            
            -- add wait cycles if necessary
            if WAIT_FOR_DATA = '1' then
               fsmNextCpuState <= cs_exepost_store_dst_indirect;

            else            
               -- perform post increment
               if Dst_Mode = amIndirPostInc then
                  -- special handling of SP, SR and PC as they are not stored in the register file
                  case Dst_RegNo is
                     when x"D" => fsmSP <= SP + 1;
                     when x"E" => fsmSR <= SR + 1;
                     when x"F" => fsmPC <= PC + 1;
                     when others =>
                        fsm_reg_write_addr <= Dst_RegNo;
                        fsm_reg_write_data <= reg_read_data2 + 1;
                        fsm_reg_write_en <= '1';               
                  end case;
               end if;
            end if;
                  
         when cs_exepost_sub =>
            fsmDataToBus <= DATA_To_Bus;
            fsmCpuDataDirCtrl <= '1';
            fsmCpuDataValid <= '1';
            
            -- absolute or relative?
            if Bra_Mode = bmASUB then
               fsmPC <= Src_Value;
            else
               fsmPC <= PC + Src_Value;
            end if;

         when cs_exepost_prepfetch =>
            fsmCpuAddr <= PC;
        
         when others =>
            fsmPC <= (others => '0');
            fsmCpuAddr <= (others => '0');
            fsmCpuDataDirCtrl <= '0';
            fsmCpuDataValid <= '0';
            
      end case;
   end process;
   
   -- main CPU state machine that runs through the enum cpu_state
   fsm_next_state_decode : process (cpu_state)
   begin
      case cpu_state is
         when cs_reset                       => cpu_state_next <= cs_fetch;         
         when cs_fetch                       => cpu_state_next <= cs_decode;
         when cs_decode                      => cpu_state_next <= cs_execute;
         when cs_exeprep_get_src_indirect    => cpu_state_next <= cs_execute;
         when cs_exeprep_get_dst_indirect    => cpu_state_next <= cs_execute;
         when cs_execute                     => cpu_state_next <= cs_fetch;
         when cs_exepost_store_dst_indirect  => cpu_state_next <= cs_exepost_prepfetch;
         when cs_exepost_sub                 => cpu_state_next <= cs_exepost_prepfetch;
         when cs_exepost_prepfetch           => cpu_state_next <= cs_fetch;
         when cs_halt                        => cpu_state_next <= cs_halt;
         when others                         => cpu_state_next <= cpu_state;
      end case;
   end process;
               
   -- internal signals
   Opcode         <= Instruction(15 downto 12);
   Src_RegNo      <= Instruction(11 downto 8);
   Src_Mode       <= Instruction(7 downto 6);
   Dst_RegNo      <= Instruction(5 downto 2);
   Dst_Mode       <= Instruction(1 downto 0);
   Bra_Mode       <= Instruction(5 downto 4);
   Bra_Neg        <= Instruction(3);
   Bra_Condition  <= Instruction(2 downto 0);
   
   -- external signals
   ADDR           <= ADDR_Bus;
   HALT           <= '1' when cpu_state = cs_halt else '0';
   
end beh;

