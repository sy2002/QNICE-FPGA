--------------------------------------------------------------------------------
--
--   FileName:         ps2_keyboard.vhd
--   Dependencies:     debounce.vhd
--   Design Software:  Quartus II 32-bit Version 12.1 Build 177 SJ Full Version
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 11/25/2013 Scott Larson
--     Initial Public Release
--   Refactored September 2020 by MJoergen
--    
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.env1_globals.all; -- SYSTEM_SPEED
use work.qnice_tools.all;  -- f_log2

entity ps2_keyboard is
   port(
      clk          : in  std_logic;                     --system clock
      ps2_clk      : in  std_logic;                     --clock signal from ps/2 keyboard
      ps2_data     : in  std_logic;                     --data signal from ps/2 keyboard
      ps2_code_new : out std_logic;                     --flag that new ps/2 code is available on ps2_code bus
      ps2_code     : out std_logic_vector(7 downto 0)   --code received from ps/2
   );
end ps2_keyboard;

architecture rtl of ps2_keyboard is

   constant PS2_DEBOUNCE_TIME_US  : natural := 5;                                            -- Value in microseconds
   constant PS2_CLOCK_PERIOD_US   : natural := 110;                                          -- Value in microseconds

   -- The order of the factors is important: It is important to divide by 1 million BEFORE
   -- multiplying by other factors. This is because the calculation SYSTEM_SPEED*PS2_CLOCK_PERIOD_US
   -- leads to integer overflow, because the intermediate result can not fit into a 32 bit integer.
   -- Furthermore, the synthesis tool does not give any warning, and just truncates the result by
   -- discarding higher order bits (above number 32) leading to incorrect result.
   constant DEBOUNCE_COUNTER_SIZE : natural := f_log2(SYSTEM_SPEED/1_000_000*PS2_DEBOUNCE_TIME_US);
   constant IDLE_COUNTER_MAX      : natural := SYSTEM_SPEED/1_000_000*PS2_CLOCK_PERIOD_US/2; -- Half a clock period

   signal sync_ffs     : std_logic_vector(1 downto 0);         --synchronizer flip-flops for ps/2 signals
   signal ps2_clk_int  : std_logic;                            --debounced clock signal from ps/2 keyboard
   signal ps2_clk_int_d: std_logic;                            --delayed clock signal
   signal ps2_data_int : std_logic;                            --debounced data signal from ps/2 keyboard
   signal ps2_word     : std_logic_vector(10 downto 0);        --stores the ps2 data word
   signal error        : std_logic;                            --validate parity, start, and stop bits
   signal count_idle   : integer range 0 to IDLE_COUNTER_MAX;  --counter to determine ps/2 is idle

--   attribute mark_debug                 : boolean;
--   attribute mark_debug of ps2_clk_int  : signal is true;
--   attribute mark_debug of ps2_data_int : signal is true;
--   attribute mark_debug of ps2_code_new : signal is true;

begin

   --synchronizer flip-flops
   p_sync : process (clk)
   begin
      if rising_edge(clk) then
         sync_ffs(0) <= ps2_clk;           --synchronize ps/2 clock signal
         sync_ffs(1) <= ps2_data;          --synchronize ps/2 data signal
      end if;
   end process p_sync;

   --debounce ps2 input signals
   debounce_ps2_clk: entity work.debounce
      generic map(
         COUNTER_SIZE => DEBOUNCE_COUNTER_SIZE
      )
      port map(
         clk    => clk,
         button => sync_ffs(0),
         result => ps2_clk_int
      ); -- debounce_ps2_clk

   debounce_ps2_data: entity work.debounce
      generic map(
         COUNTER_SIZE => DEBOUNCE_COUNTER_SIZE
      )
      port map(
         clk => clk,
         button => sync_ffs(1),
         result => ps2_data_int
      ); -- debounce_ps2_data

   --input ps2 data
   process (clk)
   begin
      if rising_edge(clk) then
         ps2_clk_int_d <= ps2_clk_int;  -- delay signal in order to detect transitions.
         if ps2_clk_int_d ='1' and ps2_clk_int='0' then    --falling edge of ps2 clock
            ps2_word <= ps2_data_int & ps2_word(10 downto 1);   --shift in ps2 data bit
         end if;
      end if;
   end process;

   --verify that parity, start, and stop bits are all correct
   error <= not (not ps2_word(0) and ps2_word(10) and (ps2_word(9) xor ps2_word(8) xor
            ps2_word(7) xor ps2_word(6) xor ps2_word(5) xor ps2_word(4) xor ps2_word(3) xor 
            ps2_word(2) xor ps2_word(1)));

   --determine if ps2 port is idle (i.e. last transaction is finished) and output result
   process (clk)
   begin
      if rising_edge(clk) then

         if ps2_clk_int = '0' then                    --low ps2 clock, ps/2 is active
            count_idle <= 0;                          --reset idle counter
         elsif count_idle /= IDLE_COUNTER_MAX then    --ps2 clock has been high less than a half clock period (<55us)
            count_idle <= count_idle + 1;             --continue counting
         end if;

         if count_idle = IDLE_COUNTER_MAX and error = '0' then --idle threshold reached and no errors detected
            ps2_code_new <= '1';                               --set flag that new ps/2 code is available
            ps2_code <= ps2_word(8 downto 1);                  --output new ps/2 code
         else                                                  --ps/2 port active or error detected
            ps2_code_new <= '0';                               --set flag that ps/2 transaction is in progress
         end if;

      end if;
   end process;

end architecture rtl;

