----------------------------------------------------------------------------------
-- QNICE specific 16 bit dual port register file
-- 
-- asynchronous read, syncronous write on falling clock edge (!)
-- registers range from 0 to 15
-- registers 0..7 are a window into 256 x 8 registers, switched by sel_rbank
-- (the QNICE registers 14 (status register, SR) and 15 (program counter, PC)
-- are not implemented in this register bank but directly within the CPU
-- special behaviour when reading the registers 14 and 15: when reading
-- register 13, 14 or 15 then SP (when 13), SR (when 14) or PC (when 15) is output
--
-- to save tons of logic, there is no reset line to set all registers to zero
--
-- done in July 2015 by sy2002
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.env1_globals.all;

entity register_file is
port (
   clk         : in  std_logic;   -- clock: writing occurs at the rising edge
   
   -- input stack pointer (SP) status register (SR) and program counter (PC) so
   -- that they can conveniently be read when adressing 13 (SP), 14 (SR), 15 (PC)
   R8          : in std_logic_vector(15 downto 0);
   R9          : in std_logic_vector(15 downto 0);
   R10         : in std_logic_vector(15 downto 0);
   R11         : in std_logic_vector(15 downto 0);
   R12         : in std_logic_vector(15 downto 0);
   SP          : in std_logic_vector(15 downto 0); -- R13
   SR          : in std_logic_vector(15 downto 0); -- R14
   PC          : in std_logic_vector(15 downto 0); -- R15
   
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
end register_file;

architecture beh of register_file is

type upper_register_array is array(8 to 12) of std_logic_vector(15 downto 0);

-- two dimensional array to model the lower register bank (windowed)
type rega is array (0 to 8*SHADOW_REGFILE_SIZE-1) of std_logic_vector(15 downto 0);

signal LowerRegisterWindow : rega;

-- Copy of CPU registers. Only used for debugging
signal r0  : std_logic_vector(15 downto 0);
signal r1  : std_logic_vector(15 downto 0);
signal r2  : std_logic_vector(15 downto 0);
signal r3  : std_logic_vector(15 downto 0);

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

   -- Copy of CPU registers. Only used for debugging
   r0  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 0);
   r1  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 1);
   r2  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 2);
   r3  <= LowerRegisterWindow(conv_integer(sel_rbank)*8 + 3);

   write_register : process (clk)
   begin
      if falling_edge(clk) then            
         if write_en = '1' then
            if write_addr(3) = '0' then
               LowerRegisterWindow(conv_integer(sel_rbank)*8+conv_integer(write_addr)) <= write_data;
            end if;
         end if;
      end if;
   end process;
   
   read_register1 : process(read_addr1, LowerRegisterWindow, sel_rbank, R8, R9, R10, R11, R12, SP, SR, PC)
   begin
      if read_addr1(3) = '0' then
         read_data1 <= LowerRegisterWindow(conv_integer(sel_rbank)*8+conv_integer(read_addr1));
      else
         case read_addr1 is
            when x"8" =>   read_data1 <= R8;
            when x"9" =>   read_data1 <= R9;
            when x"A" =>   read_data1 <= R10;
            when x"B" =>   read_data1 <= R11;
            when x"C" =>   read_data1 <= R12;
            when x"D" =>   read_data1 <= SP; -- R13
            when x"E" =>   read_data1 <= SR; -- R14
            when others => read_data1 <= PC; -- R15
         end case;
      end if;   
   end process;
   
   read_register2 : process(read_addr2, LowerRegisterWindow, sel_rbank, R8, R9, R10, R11, R12, SP, SR, PC)
   begin
      if read_addr2(3) = '0' then
         read_data2 <= LowerRegisterWindow(conv_integer(sel_rbank)*8+conv_integer(read_addr2));
      else
         case read_addr2 is
            when x"8" =>   read_data2 <= R8;
            when x"9" =>   read_data2 <= R9;
            when x"A" =>   read_data2 <= R10;
            when x"B" =>   read_data2 <= R11;
            when x"C" =>   read_data2 <= R12;
            when x"D" =>   read_data2 <= SP; -- R13
            when x"E" =>   read_data2 <= SR; -- R14
            when others => read_data2 <= PC; -- R15
         end case;
      end if;
   end process;   

end beh;

