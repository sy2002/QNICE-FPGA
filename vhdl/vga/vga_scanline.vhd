library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_scanline is
   port (
      clk_i     : in  std_logic;
      wr_addr_i : in  std_logic_vector(9 downto 0);
      wr_data_i : in  std_logic_vector(511 downto 0);
      wr_en_i   : in  std_logic;
      rd_addr_i : in  std_logic_vector(9 downto 0);
      rd_data_o : out std_logic_vector(15 downto 0)
   );
end vga_scanline;

architecture synthesis of vga_scanline is

   constant C_ONES      : std_logic_vector(31 downto 0) := (others => '1');
   constant C_ZEROES    : std_logic_vector(31 downto 0) := (others => '0');

   signal wr_offset     : integer range 0 to 31;
   signal rd_offset     : integer range 0 to 31;
   signal data_concat   : std_logic_vector(1023 downto 0);
   signal data_rot      : std_logic_vector(511 downto 0);
   signal enable_concat : std_logic_vector(63 downto 0);
   signal enable_rot    : std_logic_vector(31 downto 0);

   signal p1_addr       : std_logic_vector(4 downto 0);
   signal p1_wr_data    : std_logic_vector(511 downto 0);
   signal p1_wr_en      : std_logic_vector(31 downto 0);
   signal p1_rd_data    : std_logic_vector(511 downto 0);
   signal p2_addr       : std_logic_vector(4 downto 0);
   signal p2_wr_data    : std_logic_vector(511 downto 0);
   signal p2_wr_en      : std_logic_vector(31 downto 0);
   signal p2_rd_data    : std_logic_vector(511 downto 0);

begin

   wr_offset     <= conv_integer(wr_addr_i(4 downto 0));
   rd_offset     <= conv_integer(rd_addr_i(4 downto 0));

   data_concat   <= wr_data_i & wr_data_i;
   data_rot      <= data_concat(511 + wr_offset*16 downto wr_offset*16);

   enable_concat <= C_ZEROES & C_ONES when wr_en_i = '1' else (others => '0');
   enable_rot    <= enable_concat(31 + wr_offset downto wr_offset);

   p1_addr       <= wr_addr_i(9 downto 5) when wr_en_i = '1' else rd_addr_i(9 downto 5);
   p1_wr_data    <= data_rot;
   p1_wr_en      <= enable_rot;

   p2_addr       <= std_logic_vector(unsigned(p1_addr) + 1);
   p2_wr_data    <= data_rot;
   p2_wr_en      <= not enable_rot;

   i_vga_blockram_with_byte_enable : entity work.vga_blockram_with_byte_enable
      generic map (
         G_ADDR_SIZE   => 5,
         G_COLUMN_SIZE => 16,
         G_NUM_COLUMNS => 32
      )
      port map (
         a_clk_i     => clk_i,
         a_addr_i    => p1_addr,
         a_wr_data_i => p1_wr_data,
         a_wr_en_i   => p1_wr_en,
         a_rd_data_o => p1_rd_data,

         b_clk_i     => clk_i,
         b_addr_i    => p2_addr,
         b_wr_data_i => p2_wr_data,
         b_wr_en_i   => p2_wr_en,
         b_rd_data_o => open
      ); -- i_vga_blockram_with_byte_enable

   rd_data_o <= p1_rd_data(15 + rd_offset*16 downto rd_offset*16);

end architecture synthesis;

