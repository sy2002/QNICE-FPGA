library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_bus_test is
   port (
      clk      : in std_logic;                        -- system clock
      reset    : in std_logic;                        -- system reset

      -- registers
      en       : in std_logic;                        -- chip enable
      we       : in std_logic;                        -- write enable
      reg      : in std_logic_vector(2 downto 0);     -- register selector
      data_in  : in std_logic_vector(15 downto 0);    -- CPU write data
      data_out : out std_logic_vector(15 downto 0)    -- CPU read data
   );
end cpu_bus_test;

architecture synthesis of cpu_bus_test is

   signal scratch_0      : std_logic_vector(15 downto 0);
   signal scratch_1      : std_logic_vector(15 downto 0);
   signal count_reads_0  : std_logic_vector(15 downto 0);
   signal count_reads_1  : std_logic_vector(15 downto 0);
   signal count_writes_0 : std_logic_vector(15 downto 0);
   signal count_writes_1 : std_logic_vector(15 downto 0);

begin

   write_registers : process(clk, reset)
   begin
      if falling_edge(clk) then
         if en = '1' and we = '1' then
            case reg is
               when "000" => scratch_0 <= data_in;
               when "001" => scratch_1 <= data_in;
               when "010" => null;
               when "011" => null;
               when "100" => count_reads_0 <= data_in;
               when "101" => count_reads_1 <= data_in;
               when "110" => count_writes_0 <= data_in;
               when "111" => count_writes_1 <= data_in;
               when others => null;
            end case;
         end if;

         if en = '1' and we = '1' then
            case reg is
               when "000" => count_writes_0 <= std_logic_vector(unsigned(count_writes_0) + 1);
               when "001" => count_writes_1 <= std_logic_vector(unsigned(count_writes_1) + 1);
               when others => null;
            end case;
         end if;

         if en = '1' and we = '0' then
            case reg is
               when "000" => count_reads_0 <= std_logic_vector(unsigned(count_reads_0) + 1);
               when "001" => count_reads_1 <= std_logic_vector(unsigned(count_reads_1) + 1);
               when others => null;
            end case;
         end if;

         if reset = '1' then
            scratch_0      <= (others => '0');
            scratch_1      <= (others => '0');
            count_reads_0  <= (others => '0');
            count_reads_1  <= (others => '0');
            count_writes_0 <= (others => '0');
            count_writes_1 <= (others => '0');
         end if;
      end if;
   end process;

   read_registers : process(en, we, reg, scratch_0, scratch_1,
      count_reads_0, count_reads_1, count_writes_0, count_writes_1)
   begin
      if en = '1' and we = '0' then
         case reg is
            when "000" => data_out <= scratch_0;
            when "001" => data_out <= scratch_1;
            when "010" => data_out <= (others => '0');
            when "011" => data_out <= (others => '0');
            when "100" => data_out <= count_reads_0;
            when "101" => data_out <= count_reads_1;
            when "110" => data_out <= count_writes_0;
            when "111" => data_out <= count_writes_1;
            when others => data_out <= (others => '0');
         end case;
      else
         data_out <= (others => '0');
      end if;
   end process;

end synthesis;

