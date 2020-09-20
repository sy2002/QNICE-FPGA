library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- See page 133 of
-- https://www.xilinx.com/support/documentation/sw_manuals/xilinx2019_2/ug901-vivado-synthesis.pdf

entity vga_blockram_with_byte_enable is
   generic (
      G_ADDR_SIZE   : integer;
      G_COLUMN_SIZE : integer;
      G_NUM_COLUMNS : integer
   );
   port (
      a_clk_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wr_data_i : in  std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      a_wr_en_i   : in  std_logic_vector(G_NUM_COLUMNS-1 downto 0);
      a_rd_data_o : out std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      b_clk_i     : in  std_logic;
      b_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      b_wr_data_i : in  std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      b_wr_en_i   : in  std_logic_vector(G_NUM_COLUMNS-1 downto 0);
      b_rd_data_o : out std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0)
   );
end vga_blockram_with_byte_enable;

architecture synthesis of vga_blockram_with_byte_enable is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of
      std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);

   signal mem : mem_t;

begin

   p_a : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         for i in 0 to G_NUM_COLUMNS-1 loop
            if a_wr_en_i(i) = '1' then
               mem(conv_integer(a_addr_i))((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE) <=
                               a_wr_data_i((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE);
            end if;
         end loop;

         a_rd_data_o <= mem(conv_integer(a_addr_i));
      end if;
   end process p_a;

   p_b : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         for i in 0 to G_NUM_COLUMNS-1 loop
            if b_wr_en_i(i) = '1' then
               mem(conv_integer(b_addr_i))((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE) <=
                               b_wr_data_i((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE);
            end if;
         end loop;

         b_rd_data_o <= mem(conv_integer(b_addr_i));
      end if;
   end process p_b;

end architecture synthesis;

