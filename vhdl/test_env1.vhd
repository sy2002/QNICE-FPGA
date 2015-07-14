--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   12:10:02 07/10/2015
-- Design Name:   
-- Module Name:   Z:/Documents/Privat/GNR/dev/QNICE-FPGA/vhdl/test_env1.vhd
-- Project Name:  env1
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: env1
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY test_env1 IS
END test_env1;
 
ARCHITECTURE behavior OF test_env1 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT env1
    PORT(
         CLK : IN  std_logic;
         RESET_N : IN std_logic;
         SSEG_AN : OUT  std_logic_vector(7 downto 0);
         SSEG_CA : OUT  std_logic_vector(7 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';

   --Outputs
   signal SSEG_AN : std_logic_vector(7 downto 0);
   signal SSEG_CA : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
   -- Instantiate the Unit Under Test (UUT)
   uut: env1 PORT MAP (
          CLK => CLK,
          RESET_N => '1',
          SSEG_AN => SSEG_AN,
          SSEG_CA => SSEG_CA
        );

   -- Clock process definitions
   CLK_process :process
   begin
      CLK <= '0';
      wait for CLK_period/2;
      CLK <= '1';
      wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin    
      -- hold reset state for 100 ns.
      wait for 100 ns;  

      wait for CLK_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
