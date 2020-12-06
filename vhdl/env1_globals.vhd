----------------------------------------------------------------------------------
-- QNICE CPU private constants (e.g. opcodes, addressing modes, ...)
-- 
-- done in 2015 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.qnice_tools.all;

package env1_globals is

-- Clock frequency of CPU (in Hz)
constant SYSTEM_SPEED          : natural  := 50_000_000;

-- file name and file size (in lines) of the file that is converted to the ROM located at 0x0000
constant ROM_FILE              : string   := "../monitor/monitor.rom";
--constant ROM_FILE              : string   := "../demos/q-tris.rom";

-- file name of file and file size (in lines) of the file containing the Power On & Reset Execution (PORE) ROM
constant PORE_ROM_FILE         : string   := "../pore/pore.rom";

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
constant SHADOW_REGFILE_SIZE   : natural  := 256;

-- size of the block RAM in 16bit words: should be 32768
-- set to 256 during development for tracability during simulation
constant BLOCK_RAM_SIZE        : natural  := 32768;

-- Address of first word of RAM
constant BLOCK_RAM_START       : std_logic_vector(15 downto 0) := X"8000";

-- VGA screen memory (should be a multiple of 80x40 = 3.200)
constant VGA_RAM_SIZE          : natural  := 64000;

-- UART is in 8-N-1 mode
constant UART_FIFO_SIZE        : natural  := 32; -- size of the UART's FIFO buffer in bytes
constant UART_BAUDRATE_DEFAULT : natural  := 115200;  -- Set upon reset when switch(3) = OFF
constant UART_BAUDRATE_FAST    : natural  := 1000000; -- Set upon reset when switch(3) = ON
constant UART_BAUDRATE_MAX     : natural  := SYSTEM_SPEED/16; -- Maximum baudrate that the system can handle

-- Amount of CPU cycles, that the reset signal shall be active
constant RESET_DURATION        : natural  := 16;

-- Number of sprites supported by the VGA module.
-- Reduce this number to save on resources.
constant VGA_NUM_SPRITES       : natural  := 128;

constant SYSINFO_MMU_PRESENT   : natural  := 0;
constant SYSINFO_EAE_PRESENT   : natural  := 1;
constant SYSINFO_FPU_PRESENT   : natural  := 0;
constant SYSINFO_GPU_PRESENT   : natural  := 1;
constant SYSINFO_KBD_PRESENT   : natural  := 1;

constant SYSINFO_HW_EMU_CONSOLE  : std_logic_vector(15 downto 0) := X"0000"; -- Emulator (no VGA)
constant SYSINFO_HW_EMU_VGA      : std_logic_vector(15 downto 0) := X"0001"; -- Emulator with VGA
constant SYSINFO_HW_EMU_WASM     : std_logic_vector(15 downto 0) := X"0002"; -- Emulator on Web Assembly
constant SYSINFO_HW_NEXYS        : std_logic_vector(15 downto 0) := X"0010"; -- Digilent Nexys board
constant SYSINFO_HW_NEXYS_4DDR   : std_logic_vector(15 downto 0) := X"0011"; -- Digilent Nexys 4 DDR
constant SYSINFO_HW_NEXYS_A7100T : std_logic_vector(15 downto 0) := X"0012"; -- Digilent Nexys A7-100T
constant SYSINFO_HW_MEGA65       : std_logic_vector(15 downto 0) := X"0020"; -- MEGA65 board
constant SYSINFO_HW_MEGA65_R2    : std_logic_vector(15 downto 0) := X"0021"; -- MEGA65 Revision 2
constant SYSINFO_HW_MEGA65_R3    : std_logic_vector(15 downto 0) := X"0022"; -- MEGA65 Revision 3
constant SYSINFO_HW_DE10NANO     : std_logic_vector(15 downto 0) := X"0030"; -- DE 10 Nano board

constant SYSINFO_HW_PLATFORM     : std_logic_vector(15 downto 0) := SYSINFO_HW_NEXYS_4DDR;

end env1_globals;

package body env1_globals is
end env1_globals;

