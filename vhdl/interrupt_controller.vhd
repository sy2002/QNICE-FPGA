library ieee;
use ieee.std_logic_1164.all;

-- This is a very simple interrupt controller.
-- It is meant to be connected directly to the CPU, before the interrupt daisy
-- chain.
-- The purpose is to be able to globally enable and disable all interrupts.

entity interrupt_controller is
   port (
      -- Connected to CPU
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      en_i      : in  std_logic;
      we_i      : in  std_logic;
      reg_i     : in  std_logic_vector(2 downto 0);
      data_i    : in  std_logic_vector(15 downto 0);
      data_o    : out std_logic_vector(15 downto 0);
      int_n_o   : out std_logic;
      grant_n_i : in  std_logic;

      -- Connected to interrupt daisy chain
      int_n_i   : in  std_logic;
      grant_n_o : out std_logic
   );
end interrupt_controller;

architecture synthesis of interrupt_controller is

   signal enable : std_logic;

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if en_i = '1' and we_i = '1' and reg_i = "000" then
            enable <= data_i(0);
         end if;

         if rst_i = '1' then
            enable <= '0';
         end if;
      end if;
   end process p_write;

   data_o <= X"000" & "000" & enable when en_i = '1' and we_i = '0' and reg_i = "000" else
             (others => '0');

   int_n_o <= int_n_i or not enable;
   grant_n_o <= grant_n_i;

end synthesis;
