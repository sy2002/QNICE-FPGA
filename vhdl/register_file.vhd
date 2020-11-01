---------------------------------------------------------------------------------------
-- QNICE specific 16 bit dual port register file
-- 
-- * asynchronous read
-- * syncronous write on falling clock edge (!)
-- * registers range from 0 to 15
--
-- registers 13 to 15 are special registers which also receive some special treatment:
-- they are written at the rising clock edge (!)
--    R13 = SP = stack pointer
--    R14 = SR = status register
--    R15 = PC = program counter
--
-- registers 0..7 are a window into 256 x 8 registers, switched by sel_rbank
--
-- done in July 2015 by sy2002
-- refactored in November 2020 by sy2002
---------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.env1_globals.all;
use work.cpu_constants.all;

entity register_file is
port (
   clk            : in  std_logic;   -- clock: writing occurs at the rising edge
   
   -- output stack pointer (SP) status register (SR) and program counter (PC) so
   -- that they can conveniently be read by the CPU
   SP             : out std_logic_vector(15 downto 0);
   SR             : out std_logic_vector(15 downto 0);
   PC             : out std_logic_vector(15 downto 0);
   PC_Org         : out std_logic_vector(15 downto 0);
      
   -- select the appropriate register window for the lower 8 registers
   sel_rbank      : in  std_logic_vector(7 downto 0);
   
   -- read register addresses and read result
   read_addr1     : in  std_logic_vector(3 downto 0);
   read_addr2     : in  std_logic_vector(3 downto 0);
   read_data1     : out std_logic_vector(15 downto 0);
   read_data2     : out std_logic_vector(15 downto 0);
   
   -- write register address & data and write enable
   write_addr     : in  std_logic_vector(3 downto 0);
   write_data     : in  std_logic_vector(15 downto 0);
   write_en       : in  std_logic;
   
   -- shadow register handling:
   -- shadow_en makes sure that each write operation is shadowed
   -- shadow_spr_en in combination with shadow_en makes sure that also special regs (SP, SR, PC) are shadowed
   -- revert_en copies the shadow registers back to the main registers
   shadow_en      : in  std_logic;
   shadow_spr_en  : in  std_logic; 
   revert_en      : in  std_logic;
   
   -- Additionally to the standard way of writing a register via the mechanism
   -- write_addr and write_en (see above) SP, SR and PC are written each
   -- falling clock cycle using these values.
   -- Caution: write_en and revert_en take precedence if set to '1'.
   fsmSP          : in std_logic_vector(15 downto 0);
   fsmSR          : in std_logic_vector(15 downto 0);
   fsmPC          : in std_logic_vector(15 downto 0)   
);
end register_file;

architecture beh of register_file is

type upper_register_array is array(8 to 12) of std_logic_vector(15 downto 0);
type special_register_array is array(13 to 15) of std_logic_vector(15 downto 0);

-- model the lower register bank (windowed)
type rega is array (0 to 8*SHADOW_REGFILE_SIZE-1) of std_logic_vector(15 downto 0);

signal LowerRegisterWindow    : rega;
signal UpperRegisters         : upper_register_array;
signal UpperRegisters_Org     : upper_register_array;
signal SpecialRegisters       : special_register_array;
signal SpecialRegisters_Org   : special_register_array;

signal sel_rbank_mul8         : std_logic_vector(10 downto 0);
signal sel_rbank_i            : integer;
signal write_addr_i           : integer;
signal read_addr1_i           : integer;
signal read_addr2_i           : integer;

signal is_upper_register_wr   : boolean;
signal is_upper_register_rd1  : boolean;
signal is_upper_register_rd2  : boolean;
signal is_special_register_wr : boolean;

-- Copy of CPU registers. Only used for debugging
--signal r0  : std_logic_vector(15 downto 0);
--signal r1  : std_logic_vector(15 downto 0);
--signal r2  : std_logic_vector(15 downto 0);
--signal r3  : std_logic_vector(15 downto 0);
--signal r8  : std_logic_vector(15 downto 0);
--signal r9  : std_logic_vector(15 downto 0);
--signal r10 : std_logic_vector(15 downto 0);
--signal r11 : std_logic_vector(15 downto 0);

--attribute mark_debug        : boolean;
--attribute mark_debug of r0  : signal is true;
--attribute mark_debug of r1  : signal is true;
--attribute mark_debug of r2  : signal is true;
--attribute mark_debug of r3  : signal is true;
--attribute mark_debug of r8  : signal is true;
--attribute mark_debug of r9  : signal is true;
--attribute mark_debug of r10 : signal is true;
--attribute mark_debug of r11 : signal is true;

begin

   SP <= SpecialRegisters(13);
   SR <= SpecialRegisters(14);
   PC <= SpecialRegisters(15);
   PC_Org <= SpecialRegisters_Org(15);
   
   -- performance optimization: re-wiring the signal is the fastest way to multiply by 8
   sel_rbank_mul8(10 downto 3) <= sel_rbank(7 downto 0) & "000";
   
   sel_rbank_i  <= conv_integer(sel_rbank_mul8);
   write_addr_i <= conv_integer(write_addr);
   read_addr1_i <= conv_integer(read_addr1);
   read_addr2_i <= conv_integer(read_addr2);

   -- performance optimization: instead of using "<" and ">" we specify bit patterns
   is_special_register_wr <= true when write_addr(3) = '1' and write_addr(2) = '1' and (write_addr(1) = '1' or write_addr(0) = '1') else false;   
   is_upper_register_wr   <= true when write_addr(3) = '1' and (write_addr(2) = '0' or (write_addr(1) = '0' and write_addr(0) = '0')) else false;
   is_upper_register_rd1  <= true when read_addr1(3) = '1' and (read_addr1(2) = '0' or (read_addr1(1) = '0' and read_addr1(0) = '0')) else false;
   is_upper_register_rd2  <= true when read_addr2(3) = '1' and (read_addr2(2) = '0' or (read_addr2(1) = '0' and read_addr2(0) = '0')) else false;

   -- Copy of CPU registers. Only used for debugging
--   r0  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 0);
--   r1  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 1);
--   r2  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 2);
--   r3  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 3);
--   r8  <= UpperRegisters(8);
--   r9  <= UpperRegisters(9);
--   r10 <= UpperRegisters(10);
--   r11 <= UpperRegisters(11);

   special_write_register : process(clk)
   variable
      data: std_logic_vector(15 downto 0);   
   begin
      if rising_edge(clk) then      
         -- by default, SP, SR and PC are updated and if necessary also shadowed every rising clock edge
         SpecialRegisters(13) <= fsmSP;
         SpecialRegisters(14) <= fsmSR;
         SpecialRegisters(15) <= fsmPC;
         if shadow_en = '1' and shadow_spr_en = '1' then
            SpecialRegisters_Org(13) <= fsmSP;
            SpecialRegisters_Org(14) <= fsmSR;
            SpecialRegisters_Org(15) <= fsmPC;            
         end if;
         
         if write_en = '1' and is_special_register_wr then
            -- make sure that the lowest bit of the SR (R14) is always 1
            if write_addr /= regSR then
               data := write_data;
            else
               data := write_data(15 downto 1) & '1';
            end if;             
         
            SpecialRegisters(write_addr_i) <= data;
            if shadow_en = '1' and shadow_spr_en = '1' then
               SpecialRegisters_Org(write_addr_i) <= data;
            end if;
         elsif revert_en = '1' then
            for regnr in 13 to 15 loop
               SpecialRegisters(regnr) <= SpecialRegisters_Org(regnr); 
            end loop;
         end if;      
      end if;
   end process;

   standard_write_register : process (clk)
   begin
      if falling_edge(clk) then     
                                                                         
         -- write to lower or upper register bank and handle writing to the shadow registers
         if write_en = '1' then
            if write_addr(3) = '0' then
               LowerRegisterWindow(sel_rbank_i + write_addr_i) <= write_data;
            else
               if is_upper_register_wr then
                  UpperRegisters(write_addr_i) <= write_data;
                  if shadow_en = '1' then
                     UpperRegisters_Org(write_addr_i) <= write_data;
                  end if;
               end if;
            end if;
            
         -- revert R8 .. R15 back to the value stored in the shadow registers
         elsif revert_en = '1' then
            for regnr in 8 to 12 loop
               UpperRegisters(regnr) <= UpperRegisters_Org(regnr);
            end loop;
         end if; 
      end if;
   end process;
   
   read_register1 : process(sel_rbank_i, read_addr1, read_addr1_i, is_upper_register_rd1, LowerRegisterWindow, UpperRegisters, SpecialRegisters)
   begin
      if read_addr1(3) = '0' then
         read_data1 <= LowerRegisterWindow(sel_rbank_i + read_addr1_i);
      elsif is_upper_register_rd1 then
         read_data1 <= UpperRegisters(read_addr1_i);
      else
         read_data1 <= SpecialRegisters(read_addr1_i); 
      end if;   
   end process;
   
   read_register2 : process(sel_rbank_i, read_addr2, read_addr2_i, is_upper_register_rd2, LowerRegisterWindow, UpperRegisters, SpecialRegisters)
   begin
      if read_addr2(3) = '0' then
         read_data2 <= LowerRegisterWindow(sel_rbank_i + read_addr2_i);
      elsif is_upper_register_rd2 then
         read_data2 <= UpperRegisters(read_addr2_i);
      else
         read_data2 <= SpecialRegisters(read_addr2_i);
      end if;
   end process;   

end beh;

