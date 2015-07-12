----------------------------------------------------------------------------------
-- TriState buffer/driver for inout ports
-- inspired by
-- http://stackoverflow.com/questions/11969826/bidirectional-databus-design
-- 
-- sending data happens on rising edge, receiving on falling edge
-- direction control via I_DIR_CTRL
--
-- done in July 2015 by sy2002
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all; 


entity TriState_Buffer is
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
end entity TriState_Buffer;

architecture beh of TriState_Buffer is

signal data_in : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal data_out : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

   Register_Input : process (I_CLK) is
   begin
      if falling_edge(I_CLK) then
         O_DATA_FROM_EXTERNAL <= data_in;
      end if;
   end process Register_Input;

   Register_Output : process (I_CLK) is
   begin
      if rising_edge(I_CLK) then
         data_out <= I_DATA_TO_EXTERNAL;
      end if;
   end process Register_Output;
	
	Handle_Direction : process (I_DIR_CTRL, IO_DATA, data_out)
   begin 
      if I_DIR_CTRL = '0' then 
         IO_DATA <= (others => 'Z'); 
      else 
         IO_DATA <= data_out; 
      end if; 
      data_in <= IO_DATA;
	end process;

end architecture beh;