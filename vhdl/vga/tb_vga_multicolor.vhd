library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity tb_vga_multicolor is
end tb_vga_multicolor;

architecture simulation of tb_vga_multicolor is

   signal cpu_clk      : std_logic := '0';
   signal cpu_rst      : std_logic;
   signal cpu_en       : std_logic;
   signal cpu_we       : std_logic;
   signal cpu_reg      : std_logic_vector(4 downto 0);
   signal cpu_data_in  : std_logic_vector(15 downto 0);
   signal cpu_data_out : std_logic_vector(15 downto 0);

   signal vga_clk      : std_logic := '0';
   signal vga_hsync    : std_logic;
   signal vga_vsync    : std_logic;
   signal vga_color    : std_logic_vector(14 downto 0);

begin

   --------------------------------
   -- Generate CPU clock (100 MHz)
   -- In simulation the actual clock speed is irrelevant.
   --------------------------------

   p_cpu_clk : process
   begin
      cpu_clk <= '1', '0' after 5 ns;
      wait for 10 ns;
   end process p_cpu_clk;

   p_cpu_rst : process
   begin
      cpu_rst <= '1';
      wait for 50 ns;
      wait until cpu_clk = '1';
      cpu_rst <= '0';
      wait;
   end process p_cpu_rst;


   -------------------------------
   -- Generate VGA clock (25 MHz)
   -- In simulation the actual clock speed is irrelevant.
   -------------------------------

   p_vga_clk : process
   begin
      vga_clk <= '1', '0' after 20 ns;
      wait for 40 ns;
   end process p_vga_clk;


   ------------------------------
   -- Generate stimuli
   ------------------------------

   p_cpu : process (cpu_clk)
      type stimuli_t is array (natural range <>) of std_logic_vector(31 downto 0);
      constant C_STIMULI : stimuli_t := (
         -- Enable sprites
         X"FF30_1CE0",

         -- Sprite 0 bitmap top row
         X"FF45_8000", X"FF46_FFFF",
         X"FF45_8001", X"FF46_FFFF",
         X"FF45_8002", X"FF46_FFFF",
         X"FF45_8003", X"FF46_FFFF",
         X"FF45_8004", X"FF46_FFFF",
         X"FF45_8005", X"FF46_FFFF",
         X"FF45_8006", X"FF46_FFFF",
         X"FF45_8007", X"FF46_FFFF",
         X"FF45_8008", X"FF46_E000",

         -- Sprite 0 palette
         X"FF45_4000", X"FF46_0000",
         X"FF45_4001", X"FF46_1111",
         X"FF45_4002", X"FF46_2222",
         X"FF45_4003", X"FF46_3333",
         X"FF45_4004", X"FF46_4444",
         X"FF45_4005", X"FF46_5555",
         X"FF45_4006", X"FF46_6666",
         X"FF45_4007", X"FF46_7777",
         X"FF45_4008", X"FF46_8888",
         X"FF45_4009", X"FF46_9999",
         X"FF45_400A", X"FF46_AAAA",
         X"FF45_400B", X"FF46_BBBB",
         X"FF45_400C", X"FF46_CCCC",
         X"FF45_400D", X"FF46_DDDD",
         X"FF45_400E", X"FF46_EEEE",
         X"FF45_400F", X"FF46_FFFF",

         -- Sprite 0 configuration
         X"FF45_0000", X"FF46_0128",   -- pos x
         X"FF45_0001", X"FF46_0000",   -- pos y
         X"FF45_0002", X"FF46_8000",   -- bitmap ptr
         X"FF45_0003", X"FF46_0040"    -- csr
      );
      variable index : natural;
   begin
      if rising_edge(cpu_clk) then
         -- Set default values
         cpu_en      <= '0';
         cpu_we      <= '0';
         cpu_reg     <= (others => '0');
         cpu_data_in <= (others => '0');

         if cpu_rst = '1' then
            index := 0;
         elsif index < C_STIMULI'length then
            cpu_en      <= '1';
            cpu_we      <= '1';
            cpu_reg     <= C_STIMULI(index)(20 downto 16) xor "10000";
            cpu_data_in <= C_STIMULI(index)(15 downto 0);
            index := index + 1;
         end if;

      end if;
   end process p_cpu;


   ------------------------------
   -- Instantiate DUT
   ------------------------------

   i_vga_multicolor : entity work.vga_multicolor
      port map (
         cpu_clk_i     => cpu_clk,
         cpu_rst_i     => cpu_rst,
         cpu_en_i      => cpu_en,
         cpu_we_i      => cpu_we,
         cpu_reg_i     => cpu_reg,
         cpu_data_i    => cpu_data_in,
         cpu_data_o    => cpu_data_out,
         cpu_int_n_o   => open,
         cpu_grant_n_i => '1',
         cpu_int_n_i   => '1',
         cpu_grant_n_o => open,

         vga_clk_i     => vga_clk,
         vga_hsync_o   => vga_hsync,
         vga_vsync_o   => vga_vsync,
         vga_color_o   => vga_color,
         vga_data_en_o => open
      ); -- i_vga_multicolor

end architecture simulation;

