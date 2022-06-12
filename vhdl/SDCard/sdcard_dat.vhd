-- This block sends commands to the SDCard and receives responses.
-- Only one outstanding command is allowed at any time.
-- This module checks for timeout, and always generates a response, when a response is expected.
-- CRC generation is performed on all commands.

-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/SDCard).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sdcard_globals.all;

entity sdcard_dat is
   port (
      clk_i          : in  std_logic; -- 50 MHz
      rst_i          : in  std_logic;

      ready_o        : out std_logic;

      -- Command to send to SDCard
      tx_valid_i     : in  std_logic;
      tx_data_i      : in  std_logic_vector(7 downto 0);

      -- Response received from SDCard
      rx_valid_o     : out std_logic;
      rx_data_o      : out std_logic_vector(7 downto 0);
      rx_crc_error_o : out std_logic;

      -- SDCard device interface
      sd_clk_i       : in  std_logic; -- 25 MHz or 400 kHz
      sd_dat_in_i    : in  std_logic_vector(3 downto 0);
      sd_dat_out_o   : out std_logic_vector(3 downto 0);
      sd_dat_oe_o    : out std_logic
   );
end entity sdcard_dat;

architecture synthesis of sdcard_dat is

   constant RX_COUNT_MAX : natural := 1024+16;

   signal sd_clk_d : std_logic;

   signal rx_count : natural range 0 to RX_COUNT_MAX;
   signal crc0     : std_logic_vector(15 downto 0);
   signal crc1     : std_logic_vector(15 downto 0);
   signal crc2     : std_logic_vector(15 downto 0);
   signal crc3     : std_logic_vector(15 downto 0);
   signal rx_crc0  : std_logic_vector(15 downto 0);
   signal rx_crc1  : std_logic_vector(15 downto 0);
   signal rx_crc2  : std_logic_vector(15 downto 0);
   signal rx_crc3  : std_logic_vector(15 downto 0);

   signal rx_msb_data  : std_logic_vector(3 downto 0);
   signal rx_msb_valid : std_logic;

   -- This calculates the 16-bit CRC using the polynomial x^16 + x^12 + x^5 + x^0.
   -- See this link: http://www.ghsi.de/pages/subpages/Online%20CRC%20Calculation/indexDetails.php?Polynom=10001001&Message=7700000000
   function new_crc(cur_crc : std_logic_vector; val : std_logic) return std_logic_vector is
      variable inv : std_logic;
      variable upd : std_logic_vector(15 downto 0);
   begin
      inv := val xor cur_crc(15);
      upd := (0 => inv, 5 => inv, 12 => inv, others => '0');
      return (cur_crc(14 downto 0) & "0") xor upd;
   end function new_crc;

   type state_t is (
      IDLE_ST,
      RX_ST,
      ERROR_ST
   );

   signal state : state_t := IDLE_ST;

begin

   ready_o <= '1' when state = IDLE_ST else '0';

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rx_valid_o <= '0';

         if sd_clk_d = '0' and sd_clk_i = '1' then -- Rising edge of sd_clk_i
            case state is
               when IDLE_ST =>
                  if sd_dat_in_i = "0000" then
                     rx_crc_error_o <= '0';
                     rx_count       <= RX_COUNT_MAX;
                     crc0           <= (others => '0');
                     crc1           <= (others => '0');
                     crc2           <= (others => '0');
                     crc3           <= (others => '0');
                     rx_msb_valid   <= '0';
                     state          <= RX_ST;
                  end if;

               when RX_ST =>
                  if rx_count > 16 then
                     if rx_msb_valid = '0' then
                        rx_msb_data  <= sd_dat_in_i;
                        rx_msb_valid <= '1';
                     else
                        rx_data_o    <= rx_msb_data & sd_dat_in_i;
                        rx_valid_o   <= '1';
                        rx_msb_valid <= '0';
                     end if;
                     crc0 <= new_crc(crc0, sd_dat_in_i(0));
                     crc1 <= new_crc(crc1, sd_dat_in_i(1));
                     crc2 <= new_crc(crc2, sd_dat_in_i(2));
                     crc3 <= new_crc(crc3, sd_dat_in_i(3));
                  end if;

                  if rx_count > 0 then
                     rx_count <= rx_count - 1;
                     rx_crc0  <= rx_crc0(14 downto 0) & sd_dat_in_i(0);
                     rx_crc1  <= rx_crc1(14 downto 0) & sd_dat_in_i(1);
                     rx_crc2  <= rx_crc2(14 downto 0) & sd_dat_in_i(2);
                     rx_crc3  <= rx_crc3(14 downto 0) & sd_dat_in_i(3);
                  else
                     if rx_crc0 /= crc0 or rx_crc1 /= crc1 or rx_crc2 /= crc2 or rx_crc3 /= crc3 then
                        state <= ERROR_ST;
                     else
                        state <= IDLE_ST;
                     end if;
                  end if;

               when ERROR_ST =>
                  rx_crc_error_o <= '1';
                  state <= IDLE_ST;

            end case;
         end if;

         if rst_i = '1' then
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Output is changed on falling edge of clk. The SDCard samples on rising clock edge.
   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sd_clk_d <= sd_clk_i;
         if sd_clk_d = '1' and sd_clk_i = '0' then -- Falling edge of sd_clk_i
            sd_dat_out_o <= "1111";
            sd_dat_oe_o  <= '0';
         end if;
      end if;
   end process p_out;

end architecture synthesis;

