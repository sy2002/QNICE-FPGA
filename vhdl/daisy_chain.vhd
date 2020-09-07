library ieee;
use ieee.std_logic_1164.all;

-- This module implements the Interupt Daisy Chaining.
-- It connects to the 'left' device (which could be the CPU),
-- and to the 'right' device (which could be a termination).
-- Terminating the daisy chain is done by tying right_int_n_i to '1'.
--
-- And the module connects to the 'this' device, which wants
-- to be a part of the daisy chain.
--
-- The interrupt signal from the 'this' device (this_int_n_i)
-- is edge sensitive. So a falling edge (from '1' to '0') is
-- counted as a single interrupt request, regardless of how
-- long the signal is kept low. A new interrupt request is not
-- accepted until this_int_n_i has gone high again for at least
-- one clock cycle.
--
-- The 'this' device is expected to drive its data bus with
-- the ISR address for as long as 'this_grant_n_o' is low.
-- This must be done combinatorially in the 'this' device.

entity daisy_chain is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
      this_int_n_i     : in  std_logic;
      this_grant_n_o   : out std_logic;
      left_int_n_o     : out std_logic;
      left_grant_n_i   : in  std_logic;
      right_int_n_i    : in  std_logic;
      right_grant_n_o  : out std_logic
   );
end daisy_chain;

architecture synthesis of daisy_chain is

   -- These signals are used for the edge detection of this_int_n_i.
   signal this_int_n_d     : std_logic := '1';
   signal this_int_n       : std_logic;
   signal this_int_n_latch : std_logic := '1';

   type t_state is (IDLE_ST, RIGHT_REQ_ST, RIGHT_GRANT_ST, THIS_REQ_ST, THIS_GRANT_ST);
   signal state  : t_state := IDLE_ST;

   -- These are copies of the output signals.
   signal this_grant_n  : std_logic;
   signal left_int_n    : std_logic;
   signal right_grant_n : std_logic;

   attribute mark_debug                     : boolean;
   attribute mark_debug of this_int_n_i     : signal is true;
   attribute mark_debug of this_grant_n_o   : signal is true;
   attribute mark_debug of left_int_n_o     : signal is true;
   attribute mark_debug of left_grant_n_i   : signal is true;
   attribute mark_debug of right_int_n_i    : signal is true;
   attribute mark_debug of right_grant_n_o  : signal is true;
   attribute mark_debug of this_int_n_d     : signal is true;
   attribute mark_debug of this_int_n       : signal is true;
   attribute mark_debug of this_int_n_latch : signal is true;
   attribute mark_debug of state            : signal is true;

begin

   p_edge : process (clk_i)
   begin
      if rising_edge(clk_i) then
         this_int_n_d <= this_int_n_i;
      end if;
   end process p_edge;

   -- Generate a single-cycle pulse on the falling edge of this_int_n_i.
   this_int_n <= this_int_n_i or not this_int_n_d;


   p_int_latch : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Remember interrupt request, until it can be serviced.
         if this_int_n = '0' then
            this_int_n_latch <= '0';
         end if;

         -- Clear latch, when we start to process the interrupt.
         if state = THIS_GRANT_ST and this_grant_n = '1' then
            this_int_n_latch <= '1';
         end if;

         -- On reset, the latch must be cleared.
         if rst_i = '1' then
            this_int_n_latch <= '1';
         end if;
      end if;
   end process p_int_latch;


   -- There is a one-cycle delay when requesting interrupt.
   left_int_n <= '0' when state = THIS_REQ_ST or state = RIGHT_REQ_ST else '1';
   -- TBD. Perhaps this delay can be removed by something like this (not tried yet):
   -- left_int_n <= this_int_n and this_int_n_latch and right_int_n_i when state = IDLE_ST else
   --               '0' when state = THIS_REQ_ST or state = RIGHT_REQ_ST else
   --               '1';


   -- Make sure grant signal is connected combinatorially through the daisy chain.
   right_grant_n <= left_grant_n_i when state = RIGHT_REQ_ST or state = RIGHT_GRANT_ST else '1';
   this_grant_n  <= left_grant_n_i when state = THIS_REQ_ST  or state = THIS_GRANT_ST  else '1';


   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               -- Are we requesting an interrupt?
               if this_int_n = '0' or this_int_n_latch = '0' then
                  state <= THIS_REQ_ST;
               end if;

               -- Is the next in chain requesting an interrupt?
               if right_int_n_i = '0' then
                  state <= RIGHT_REQ_ST;
               end if;

            when THIS_REQ_ST =>
               -- Wait until we get a grant.
               if left_grant_n_i = '0' then
                  state <= THIS_GRANT_ST;
               end if;

            when THIS_GRANT_ST =>
               -- Wait until grant is revoked.
               if left_grant_n_i = '1' then
                  state <= IDLE_ST;
               end if;

            when RIGHT_REQ_ST =>
               -- Wait until we get a grant.
               if left_grant_n_i = '0' then
                  state <= RIGHT_GRANT_ST;
               end if;

            when RIGHT_GRANT_ST =>
               -- Wait until grant is revoked.
               if left_grant_n_i = '1' then
                  state <= IDLE_ST;
               end if;

            when others => null;
         end case;
      end if;
   end process p_fsm;


   -- Connect output signals
   left_int_n_o    <= left_int_n;
   right_grant_n_o <= right_grant_n;
   this_grant_n_o  <= this_grant_n;

end synthesis;

