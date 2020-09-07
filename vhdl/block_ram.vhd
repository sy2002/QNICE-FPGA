-- Block RAM (synchronous)
-- * read and write on falling clock edge; falling edge is chosen, because QNICE CPU's FSM
--   is generating control signals on rising edges; so there is enough time for the signals to settle
--   and therefore we do not need to waste a cycle
-- * the RAM is initialized to zero on system start
-- * on writing can directly control the CPU's (or any bus arbiter's) WAIT_FOR_DATA line
-- inspired by http://vhdlguru.blogspot.de/2011/01/block-and-distributed-rams-on-xilinx.html
-- done by sy2002 in August 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.env1_globals.all;

entity BRAM is
port (
   clk      : in std_logic;                        -- read and write on rising clock edge
   ce       : in std_logic;                        -- chip enable, when low then zeros on output
   
   address  : in std_logic_vector(14 downto 0);    -- address is for now 15 bit hard coded
   we       : in std_logic;                        -- write enable
   data_i   : in std_logic_vector(15 downto 0);    -- write data
   data_o   : out std_logic_vector(15 downto 0);   -- read data
   
   -- 1=still executing, i.e. can drive CPU's WAIT_FOR_DATA, goes zero
   -- if not needed (ce = 0)
   busy     : out std_logic                       
);
end BRAM;

architecture beh of BRAM is

type bram_t is array (0 to BLOCK_RAM_SIZE - 1) of std_logic_vector(15 downto 0);
signal bram : bram_t := (others => x"0000");

signal output : std_logic_vector(15 downto 0);

signal counter : std_logic := '1'; -- important to be initialized to one
signal address_old : std_logic_vector(14 downto 0) := (others => 'U');
signal we_old : std_logic := '0';
signal async_reset : std_logic;

begin

   -- process for read and write operation on the falling clock edge
   ram_readwrite : process (clk)
   begin
      if falling_edge(clk) then
         if we = '1' and ce = '1' then
            bram(conv_integer(address)) <= data_i;
         end if;
         
         if ce = '1' then
            output <= bram(conv_integer(address));
         else
            output <= (others => 'U');
         end if;
         
         address_old <= address;
         we_old <= we;
      end if;
   end process;
   
   -- zero while not ce OR while writing
   manage_output : process (we, ce, output)
   begin
      if (ce = '0') or (ce = '1' and we = '1') then
         data_o <= (others => '0');
      else
         data_o <= output;
      end if;
   end process;
   
   -- generate a busy signal for one clock cycle, because this is
   -- the read delay that this block RAM is having
   manage_busy : process (clk, async_reset)
   begin
      if rising_edge(clk) then
         if ce = '1' then
            counter <= not counter;
         else
            counter <= '1'; -- reverse logic because busy needs to be "immediatelly" one when needed
         end if;
      end if;

      if async_reset = '1' then
         counter <= '1';
      end if;
   end process;
   
   -- address changes or changes between reading and writing are
   -- re-triggering the busy-cycle as this means a new operation for the BRAM
   manage_busy_on_changes : process (ce, we, we_old, address, address_old)
   begin
      if ce = '1' then
         if we /= we_old then
            async_reset <= '1';
         elsif address /= address_old then
            async_reset <= '1';
         else
            async_reset <= '0';
         end if;
      else
         async_reset <= '0';
      end if;      
   end process;

   busy <= '0';
   
end beh;
