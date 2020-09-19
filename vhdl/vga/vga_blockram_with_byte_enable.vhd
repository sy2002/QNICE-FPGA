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
      clk_i        : in  std_logic;
      p1_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      p1_wr_data_i : in  std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      p1_wr_en_i   : in  std_logic_vector(G_NUM_COLUMNS-1 downto 0);
      p1_rd_data_o : out std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      p2_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      p2_wr_data_i : in  std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);
      p2_wr_en_i   : in  std_logic_vector(G_NUM_COLUMNS-1 downto 0);
      p2_rd_data_o : out std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0)
   );
end vga_blockram_with_byte_enable;

architecture synthesis of vga_blockram_with_byte_enable is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of
      std_logic_vector(G_NUM_COLUMNS*G_COLUMN_SIZE-1 downto 0);

   signal mem : mem_t;

begin

   p1 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for i in 0 to G_NUM_COLUMNS-1 loop
            if p1_wr_en_i(i) = '1' then
               mem(conv_integer(p1_addr_i))((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE) <=
                               p1_wr_data_i((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE);
            end if;
         end loop;

         p1_rd_data_o <= mem(conv_integer(p1_addr_i));
      end if;
   end process p1;

   p2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for i in 0 to G_NUM_COLUMNS-1 loop
            if p2_wr_en_i(i) = '1' then
               mem(conv_integer(p2_addr_i))((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE) <=
                               p2_wr_data_i((i + 1)*G_COLUMN_SIZE-1 downto i*G_COLUMN_SIZE);
            end if;
         end loop;

         p2_rd_data_o <= mem(conv_integer(p2_addr_i));
      end if;
   end process p2;

end architecture synthesis;

