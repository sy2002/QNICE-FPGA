----------------------------------------------------------------------------------
-- QNICE CPU private constants (e.g. opcodes, addressing modes, ...)
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package env1_globals is

-- file name and file size (in lines) of the file that is converted to the ROM located at 0x0000
--constant ROM_FILE             : string    := "../test_programs/cpu_bug1.rom";
constant ROM_FILE             : string    := "../monitor/monitor.rom";
constant ROM_SIZE             : integer   := 2355;

-- size of lower register bank: should be 256
-- set to 16 during development for faster synthesis, routing, etc.
--
-- SYNTHESIS OPTIMIZATION 
-- set always:
--    Synthesis: Optimization Goal: Speed
--    Xilinx Specific: Register Balancing: Yes (and the following move register stages should be also ON)
-- set only for a size greater 16, e.g. when using 256
--    Synthesis: Optimization Effort: HIGH (was NORMAL)
--    HDL: Resource Sharing OFF (was ON)
--    Xilinx Specific: LUT Combining NO (was AUTO)
--                     Optimize Privitives ON (was OFF)
constant SHADOW_REGFILE_SIZE  : integer   := 16;

-- size of the block RAM in 16bit words: should be 32768
-- set to 256 during development for tracability during simulation
constant BLOCK_RAM_SIZE       : integer   := 32768;

-- VGA screen memory (should be a multiple of 80x40 = 3.200)
constant VGA_RAM_SIZE         : integer   := 64000;

-- UART is in 8-N-1 mode
-- assuming a 100 MHz system clock, set the baud rate by selecting the following divisors according to this formula:
-- UART_DIVISOR = 100,000,000 / (16 x BAUD_RATE)
--    2400 -> 2604
--    9600 -> 651
--    19200 -> 326
--    115200 -> 54
--    1562500 -> 4
--    2083333 -> 3
constant UART_DIVISOR          : natural  := 326; -- as long as we are using SLOW_CLOCK with 50 MHz
constant UART_FIFO_SIZE        : natural  := 16;

end env1_globals;

package body env1_globals is
end env1_globals;
