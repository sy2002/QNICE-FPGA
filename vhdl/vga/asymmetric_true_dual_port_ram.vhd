library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; -- conv_integer
use ieee.std_logic_textio.all;
use std.textio.all;

-- This emulates a True Dual Port RAM, and will be inferred to BRAMs.

entity asymmetric_true_dual_port_ram is
   generic (
      G_A_ADDR_SIZE : natural;
      G_A_DATA_SIZE : natural;
      G_B_ADDR_SIZE : natural;
      G_B_DATA_SIZE : natural
   );
   port (
      -- Port A (R/W)
      a_clk_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(G_A_ADDR_SIZE-1 downto 0);
      a_wr_en_i   : in  std_logic;
      a_wr_data_i : in  std_logic_vector(G_A_DATA_SIZE-1 downto 0);
      a_rd_data_o : out std_logic_vector(G_A_DATA_SIZE-1 downto 0);

      -- Port B (RO)
      b_clk_i     : in  std_logic;
      b_rd_addr_i : in  std_logic_vector(G_B_ADDR_SIZE-1 downto 0);
      b_rd_data_o : out std_logic_vector(G_B_DATA_SIZE-1 downto 0)
   );
end asymmetric_true_dual_port_ram;

architecture synthesis of asymmetric_true_dual_port_ram is

   constant C_NUM_COLUMNS : integer := G_B_DATA_SIZE / G_A_DATA_SIZE;
   constant C_COLUMN_SIZE : integer := G_A_ADDR_SIZE - G_B_ADDR_SIZE;

   signal a_column  : std_logic_vector(C_COLUMN_SIZE-1 downto 0);
   signal a_addr    : std_logic_vector(G_B_ADDR_SIZE-1 downto 0);
   signal a_wr_en   : std_logic_vector(C_NUM_COLUMNS-1 downto 0);
   signal a_wr_data : std_logic_vector(G_B_DATA_SIZE-1 downto 0);
   signal a_rd_data : std_logic_vector(G_B_DATA_SIZE-1 downto 0);

begin

   assert 2**C_COLUMN_SIZE = C_NUM_COLUMNS;

   a_column <= a_addr_i(C_COLUMN_SIZE-1 downto 0);

   a_addr   <= a_addr_i(G_A_ADDR_SIZE-1 downto C_COLUMN_SIZE);

   gen_a_wr_data : for i in 0 to C_NUM_COLUMNS-1 generate
      a_wr_data(G_A_DATA_SIZE-1 + G_A_DATA_SIZE*i downto G_A_DATA_SIZE*i) <= a_wr_data_i;
   end generate gen_a_wr_data;

   p_a_wr_en : process (a_column, a_wr_en_i)
   begin
      a_wr_en <= (others => '0');
      a_wr_en(conv_integer(a_column)) <= a_wr_en_i;
   end process p_a_wr_en;

   i_vga_blockram_with_byte_enable : entity work.vga_blockram_with_byte_enable
      generic map (
         G_ADDR_SIZE   => G_B_ADDR_SIZE,
         G_COLUMN_SIZE => G_A_DATA_SIZE,
         G_NUM_COLUMNS => C_NUM_COLUMNS
      )
      port map (
         a_clk_i     => a_clk_i,
         a_addr_i    => a_addr,
         a_wr_data_i => a_wr_data,
         a_wr_en_i   => a_wr_en,
         a_rd_data_o => a_rd_data,
         --
         b_clk_i     => b_clk_i,
         b_addr_i    => b_rd_addr_i,
         b_wr_data_i => (others => '0'),
         b_wr_en_i   => (others => '0'),
         b_rd_data_o => b_rd_data_o
      ); -- i_vga_blockram_with_byte_enable

   a_rd_data_o <= a_rd_data(G_A_DATA_SIZE-1 + conv_integer(a_column)*G_A_DATA_SIZE downto
                                              conv_integer(a_column)*G_A_DATA_SIZE);

--   ----------
--   -- Port A
--   ----------
--
--
--   p_a : process (a_clk_i)
--   begin
--      if rising_edge(a_clk_i) then
--         if a_wr_en_i = '1' then
--            for i in 0 to C_NUM_COLUMNS-1 loop
--               if i = a_column then
--                  mem(conv_integer(a_row))((i + 1)*G_A_DATA_SIZE-1 downto i*G_A_DATA_SIZE) <= a_wr_data_i;
--               end if;
--            end loop;
--         end if;
--
--         a_rd_data_o <= mem(conv_integer(a_row))(a_column*G_A_DATA_SIZE + G_A_DATA_SIZE-1 downto a_column*G_A_DATA_SIZE);
--      end if;
--   end process p_a;
--
--
--   ----------
--   -- Port B
--   ----------
--
--   -- Use a generate statement to make it easier to reference
--   -- from the constraint file.
--   -- Since the Palette RAM gets implemented as Distributed RAM instead
--   -- of Block RAM, there will be an explicit output register, which
--   -- needs to be covered by the timing constraint.
--   gen_cdc : if true generate
--
--      p_b : process (b_clk_i)
--      begin
--         if rising_edge(b_clk_i) then
--            b_rd_data_o <= mem(conv_integer(b_rd_addr_i));
--         end if;
--      end process p_b;
--
--   end generate gen_cdc;

end architecture synthesis;

