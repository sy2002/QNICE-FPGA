library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This emulates a True Dual Port RAM, and should be inferred to BRAMs.

entity true_dual_port_ram is
   generic (
      G_ADDR_SIZE : natural;
      G_DATA_SIZE : natural
   );
   port (
      -- Port A (R/W)
      a_clk_i     : in  std_logic;
      a_wr_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wr_en_i   : in  std_logic;
      a_wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      a_rd_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0);

      -- Port B (RO)
      b_clk_i     : in  std_logic;
      b_rd_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      b_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end true_dual_port_ram;

architecture synthesis of true_dual_port_ram is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal mem : mem_t := (others => (others => '0'));

begin

   ----------
   -- Port A
   ----------

   p_a : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         if a_wr_en_i = '1' then
            mem(conv_integer(a_wr_addr_i)) <= a_wr_data_i;
         end if;
         a_rd_data_o <= mem(conv_integer(a_rd_addr_i));
      end if;
   end process p_a;


   ----------
   -- Port B
   ----------

   p_b : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         b_rd_data_o <= mem(conv_integer(b_rd_addr_i));
      end if;
   end process p_b;

end architecture synthesis;

