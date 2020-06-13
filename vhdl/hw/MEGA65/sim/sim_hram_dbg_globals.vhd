----------------------------------------------------------------------------------
-- QNICE CPU private constants (e.g. opcodes, addressing modes, ...)
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package env1_globals is

-- file name and file size (in lines) of the file that is converted to the ROM located at 0x0000
constant ROM_FILE             : string    := "hw/MEGA65/sim/sim_hram_dbg.rom";
constant ROM_SIZE             : natural   := 18;

-- amount of register banks; should be 256
constant SHADOW_REGFILE_SIZE  : natural   := 256;

-- size of the block RAM in 16bit words: should be 32768
-- set to 256 during development for tracability during simulation
constant BLOCK_RAM_SIZE       : natural   := 32768;


end env1_globals;

package body env1_globals is
end env1_globals;
