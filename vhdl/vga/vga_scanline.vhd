library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module is used to store a temporary rendering of the next scanline.
-- It stores 16-bit words for each of the 640 pixels.
--
-- Signals:
-- * addr_i    : Left-most X-coordinate of data
-- * wr_data_i : 32 words for consecutive pixels
-- * wr_en_i   : Update each of the next 32 pixels
-- * rd_data_o : Word corresponding to this pixel

entity vga_scanline is
   port (
      clk_i     : in  std_logic;
      addr_i    : in  std_logic_vector(9 downto 0);
      wr_data_i : in  std_logic_vector(543 downto 0);
      wr_en_i   : in  std_logic_vector(31 downto 0);
      rd_data_o : out std_logic_vector(16 downto 0)
   );
end vga_scanline;

architecture synthesis of vga_scanline is

   constant C_ONES      : std_logic_vector(31 downto 0) := (others => '1');
   constant C_ZEROES    : std_logic_vector(31 downto 0) := (others => '0');

   signal wr_offset       : integer range 0 to 31;
   signal rd_offset       : integer range 0 to 31;
   signal data_concat     : std_logic_vector(1087 downto 0);
   signal data_rot        : std_logic_vector(543 downto 0);
   signal a_enable_concat : std_logic_vector(63 downto 0);
   signal a_enable_rot    : std_logic_vector(31 downto 0);
   signal b_enable_concat : std_logic_vector(63 downto 0);
   signal b_enable_rot    : std_logic_vector(31 downto 0);

   signal a_addr          : std_logic_vector(4 downto 0);
   signal a_wr_data       : std_logic_vector(543 downto 0);
   signal a_wr_en         : std_logic_vector(31 downto 0);
   signal a_rd_data       : std_logic_vector(543 downto 0);
   signal b_addr          : std_logic_vector(4 downto 0);
   signal b_wr_data       : std_logic_vector(543 downto 0);
   signal b_wr_en         : std_logic_vector(31 downto 0);
   signal b_rd_data       : std_logic_vector(543 downto 0);

--   attribute mark_debug              : boolean;
--   attribute mark_debug of addr_i    : signal is true;
--   attribute mark_debug of wr_data_i : signal is true;
--   attribute mark_debug of wr_en_i   : signal is true;
--   attribute mark_debug of rd_data_o : signal is true;

begin

   wr_offset       <= conv_integer(addr_i(4 downto 0));

   data_concat     <= wr_data_i & wr_data_i;
   data_rot        <= data_concat(1087 - wr_offset*17 downto 544 - wr_offset*17);

   a_enable_concat <= wr_en_i & C_ZEROES;
   a_enable_rot    <= a_enable_concat(63 - wr_offset downto 32 - wr_offset);

   b_enable_concat <= C_ZEROES & wr_en_i;
   b_enable_rot    <= b_enable_concat(63 - wr_offset downto 32 - wr_offset);

   a_addr          <= addr_i(9 downto 5);
   a_wr_data       <= data_rot;
   a_wr_en         <= a_enable_rot;

   b_addr          <= std_logic_vector(unsigned(a_addr) + 1);
   b_wr_data       <= data_rot;
   b_wr_en         <= b_enable_rot;


   ----------------------------
   -- Instantiate memory block
   ----------------------------

   i_vga_blockram_with_byte_enable : entity work.vga_blockram_with_byte_enable
      generic map (
         G_ADDR_SIZE   => 5,     -- 32 blocks of 32 pixels
         G_COLUMN_SIZE => 17,    -- word size
         G_NUM_COLUMNS => 32     -- 32 pixels
      )
      port map (
         a_clk_i     => clk_i,
         a_addr_i    => a_addr,
         a_wr_data_i => a_wr_data,
         a_wr_en_i   => a_wr_en,
         a_rd_data_o => a_rd_data,

         b_clk_i     => clk_i,
         b_addr_i    => b_addr,
         b_wr_data_i => b_wr_data,
         b_wr_en_i   => b_wr_en,
         b_rd_data_o => open
      ); -- i_vga_blockram_with_byte_enable


   -- rd_offset must be delayed one clock cycle, so it lines up with the value
   -- read from the BRAM.
   p_rd_offset : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_offset <= conv_integer(addr_i(4 downto 0));
      end if;
   end process p_rd_offset;

   rd_data_o <= a_rd_data(16 + rd_offset*17 downto rd_offset*17);

end architecture synthesis;

