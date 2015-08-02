----------------------------------------------------------------------------------
-- QNICE CPU private constants (e.g. opcodes, addressing modes, ...)
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package env1_globals is

-- file name and file size (in lines) of the file that is converted to the ROM located at 0x0000
constant ROM_FILE             : string    := "../test_programs/bram.rom";
constant ROM_SIZE             : integer   := 10;

-- size of lower register bank: should be 256
-- set to 16 during development for faster synthesis, routing, etc.
constant SHADOW_REGFILE_SIZE  : integer   := 16;

-- size of the block RAM in 16bit words: should be 32768
-- set to 256 during development for tracability during simulation
constant BLOCK_RAM_SIZE       : integer   := 256;

end env1_globals;

package body env1_globals is
end env1_globals;
