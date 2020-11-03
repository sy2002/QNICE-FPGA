library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity memory is
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      address_i : in  std_logic_vector(15 downto 0);
      wr_data_i : in  std_logic_vector(15 downto 0);
      write_i   : in  std_logic;
      rd_data_o : out std_logic_vector(15 downto 0);
      read_i    : in  std_logic
   );
end entity memory;

architecture synthesis of memory is

   type mem_t is array (0 to 255) of std_logic_vector(15 downto 0);

   -- Initialize memory contents
   signal mem_r : mem_t := (
      16 => X"0F00",    -- MOVE  R15, R0
      17 => X"0F04",    -- MOVE  R15, R1
      18 => X"1045",    -- ADD   @R0, @R1
      19 => X"0F08",    -- MOVE  R15, R2
      20 => X"0F0C",    -- MOVE  R15, R3
      21 => X"0F10",    -- MOVE  R15, R4
      others => (others => '0')
   );

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if write_i = '1' then
            mem_r(conv_integer(address_i)) <= wr_data_i;
         end if;
      end if;
   end process p_write;

   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if read_i = '1' then
            rd_data_o <= mem_r(conv_integer(address_i));
         end if;
      end if;
   end process p_read;

end architecture synthesis;

