library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; -- conv_integer
use ieee.std_logic_textio.all;
--use ieee.numeric_std.all;        -- unsigned
use std.textio.all;

-- This emulates a True Dual Port RAM, and should be inferred to BRAMs.

entity true_dual_port_ram is
   generic (
      G_ADDR_SIZE : natural;
      G_DATA_SIZE : natural;
      G_FILE_NAME : string := "" -- Optionally provide initial data in text file.
   );
   port (
      -- Port A (R/W)
      a_clk_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wr_en_i   : in  std_logic;
      a_wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      a_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0);

      -- Port B (RO)
      b_clk_i     : in  std_logic;
      b_rd_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      b_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end true_dual_port_ram;

architecture synthesis of true_dual_port_ram is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   impure function read_romfile return mem_t is
      file     rom_file : text;
      variable line_v   : line;
      variable rom_v    : mem_t;
   begin
      rom_v := (others => (others => '0'));

      if G_FILE_NAME /= "" then
         file_open(rom_file, G_FILE_NAME, read_mode);
         for i in mem_t'range loop
            if not endfile(rom_file) then
               readline(rom_file, line_v);
               read(line_v, rom_v(i));
            end if;
         end loop;
      end if;

      return rom_v;
   end function;

   signal mem : mem_t := read_romfile;

begin

   ----------
   -- Port A
   ----------

   p_a : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         if a_wr_en_i = '1' then
            mem(conv_integer(a_addr_i)) <= a_wr_data_i;
         end if;
         a_rd_data_o <= mem(conv_integer(a_addr_i));
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

