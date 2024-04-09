-- Created by Michael Jørgensen in 2024 (mjoergen.github.io/SDCard).

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

library work;
   use work.sdcard_globals.all;

entity sdcard_dat is
   port (
      clk_i          : in    std_logic; -- 50 MHz
      rst_i          : in    std_logic;

      dat_wr_data_i  : in    std_logic_vector(7 downto 0);
      dat_wr_valid_i : in    std_logic;
      dat_wr_ready_o : out   std_logic;
      dat_wr_en_i    : in    std_logic;
      dat_wr_done_o  : out   std_logic;

      dat_rd_data_o  : out   std_logic_vector(7 downto 0);
      dat_rd_valid_o : out   std_logic;
      dat_rd_ready_i : in    std_logic;
      dat_rd_done_o  : out   std_logic;
      dat_rd_error_o : out   std_logic;

      -- SDCard device interface
      sd_clk_i       : in    std_logic; -- 25 MHz or 400 kHz
      sd_dat_in_i    : in    std_logic_vector(3 downto 0);
      sd_dat_out_o   : out   std_logic_vector(3 downto 0);
      sd_dat_oe_n_o  : out   std_logic
   );
end entity sdcard_dat;

architecture synthesis of sdcard_dat is

   constant C_COUNT_MAX : natural          := 1024 + 16;

   signal   sd_clk_d : std_logic;

   signal   rx_count : natural range 0 to C_COUNT_MAX;
   signal   crc0     : std_logic_vector(15 downto 0);
   signal   crc1     : std_logic_vector(15 downto 0);
   signal   crc2     : std_logic_vector(15 downto 0);
   signal   crc3     : std_logic_vector(15 downto 0);
   signal   rx_crc0  : std_logic_vector(15 downto 0);
   signal   rx_crc1  : std_logic_vector(15 downto 0);
   signal   rx_crc2  : std_logic_vector(15 downto 0);
   signal   rx_crc3  : std_logic_vector(15 downto 0);

   signal   rx_msb_data  : std_logic_vector(3 downto 0);
   signal   rx_msb_valid : std_logic;

   signal   tx_count : natural range 0 to C_COUNT_MAX;
   signal   tx_crc0  : std_logic_vector(15 downto 0);
   signal   tx_crc1  : std_logic_vector(15 downto 0);
   signal   tx_crc2  : std_logic_vector(15 downto 0);
   signal   tx_crc3  : std_logic_vector(15 downto 0);

   signal   tx_lsb_data  : std_logic_vector(3 downto 0);
   signal   tx_lsb_valid : std_logic;

   -- This calculates the 16-bit CRC using the polynomial x^16 + x^12 + x^5 + x^0.
   -- See this link: http://www.ghsi.de/pages/subpages/Online%20CRC%20Calculation/indexDetails.php?Polynom=10001000000100001&Message=AB

   pure function new_crc (
      cur_crc : std_logic_vector;
      val : std_logic
   ) return std_logic_vector is
      variable inv_v : std_logic;
      variable upd_v : std_logic_vector(15 downto 0);
   begin
      inv_v := val xor cur_crc(15);
      upd_v := (0 => inv_v, 5 => inv_v, 12 => inv_v, others => '0');
      return (cur_crc(14 downto 0) & "0") xor upd_v;
   end function new_crc;

   type     read_state_type is (
      IDLE_ST,
      RX_ST,
      FORWARD_ST
   );
   signal   read_state : read_state_type   := IDLE_ST;

   type     sector_type is array (0 to 511) of std_logic_vector(7 downto 0);
   signal   sector : sector_type;
   signal   addr   : natural range 0 to 511;

   type     write_state_type is (
      IDLE_ST,
      TX_ST,
      WAIT_ST
   );
   signal   write_state : write_state_type := IDLE_ST;
   constant C_WRITE_DELAY_MAX : natural := 31;
   signal   write_delay : natural range 0 to C_WRITE_DELAY_MAX;

begin

   dat_rd_data_o  <= sector(addr) when read_state = FORWARD_ST else
                     (others => '0');

   read_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         dat_rd_done_o  <= '0';
         dat_rd_error_o <= '0';

         if dat_rd_ready_i = '1' then
            dat_rd_valid_o <= '0';
         end if;

         case read_state is

            when IDLE_ST =>
               if sd_clk_d = '0' and sd_clk_i = '1' and sd_dat_oe_n_o = '1' then
                  -- Rising edge of sd_clk_i
                  if sd_dat_in_i = "0000" then
                     rx_count     <= C_COUNT_MAX;
                     crc0         <= (others => '0');
                     crc1         <= (others => '0');
                     crc2         <= (others => '0');
                     crc3         <= (others => '0');
                     rx_msb_valid <= '0';
                     read_state   <= RX_ST;
                     addr         <= 0;
                  end if;
               end if;

            when RX_ST =>
               if sd_clk_d = '0' and sd_clk_i = '1' then
                  -- Rising edge of sd_clk_i
                  if rx_count > 16 then
                     if rx_msb_valid = '0' then
                        rx_msb_data  <= sd_dat_in_i;
                        rx_msb_valid <= '1';
                     else
                        sector(addr) <= rx_msb_data & sd_dat_in_i;
                        if addr < 511 then
                           addr <= addr + 1;
                        else
                           addr <= 0;
                        end if;
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
                        dat_rd_error_o <= '1';
                        read_state     <= IDLE_ST;
                     else
                        addr           <= 0;
                        dat_rd_valid_o <= '1';
                        read_state     <= FORWARD_ST;
                     end if;
                  end if;
               end if;

            when FORWARD_ST =>
               if dat_rd_ready_i = '1' then
                  if addr < 511 then
                     addr           <= addr + 1;
                     dat_rd_valid_o <= '1';
                  else
                     dat_rd_done_o <= '1';
                     read_state    <= IDLE_ST;
                  end if;
               end if;

         end case;

         if rst_i = '1' then
            read_state <= IDLE_ST;
         end if;
      end if;
   end process read_proc;

   dat_wr_ready_o <= '1' when sd_clk_d = '0' and sd_clk_i = '1' and write_state = TX_ST
                              and tx_lsb_valid = '0' and tx_count >= 16 else
                     '0';

   -- Output is changed on falling edge of clk. The SDCard samples on rising clock edge.
   write_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         dat_wr_done_o <= '0';
         sd_clk_d      <= sd_clk_i;

         case write_state is

            when IDLE_ST =>
               if dat_wr_en_i = '1' and dat_wr_done_o = '0' then
                  tx_count     <= C_COUNT_MAX;
                  tx_lsb_data  <= "0000";
                  tx_lsb_valid <= '1';
                  tx_crc0      <= X"0000";
                  tx_crc1      <= X"0000";
                  tx_crc2      <= X"0000";
                  tx_crc3      <= X"0000";
                  write_state  <= TX_ST;
               end if;

            when TX_ST =>
               null;

            when WAIT_ST =>
               if sd_clk_d = '0' and sd_clk_i = '1' then
                  sd_dat_out_o  <= "1111";
                  sd_dat_oe_n_o <= '1';
                  if write_delay = 0 then
                     if to_01(sd_dat_in_i(0)) = '1' then
                        dat_wr_done_o <= '1';
                        write_state   <= IDLE_ST;
                     end if;
                  else
                     write_delay <= write_delay - 1;
                  end if;
               end if;

         end case;

         if sd_clk_d = '0' and sd_clk_i = '1' then
            sd_dat_out_o  <= "1111";
            sd_dat_oe_n_o <= '1';
            if write_state = TX_ST then
               if tx_lsb_valid = '0' and dat_wr_valid_i = '1' then
                  sd_dat_out_o  <= dat_wr_data_i(7 downto 4);
                  sd_dat_oe_n_o <= '0';
                  tx_lsb_data   <= dat_wr_data_i(3 downto 0);
                  tx_lsb_valid  <= '1';
                  tx_crc0       <= new_crc(tx_crc0, dat_wr_data_i(4));
                  tx_crc1       <= new_crc(tx_crc1, dat_wr_data_i(5));
                  tx_crc2       <= new_crc(tx_crc2, dat_wr_data_i(6));
                  tx_crc3       <= new_crc(tx_crc3, dat_wr_data_i(7));
                  tx_count      <= tx_count - 1;
               end if;

               if tx_lsb_valid = '1' then
                  sd_dat_out_o  <= tx_lsb_data;
                  sd_dat_oe_n_o <= '0';
                  tx_lsb_valid  <= '0';
                  tx_crc0       <= new_crc(tx_crc0, tx_lsb_data(0));
                  tx_crc1       <= new_crc(tx_crc1, tx_lsb_data(1));
                  tx_crc2       <= new_crc(tx_crc2, tx_lsb_data(2));
                  tx_crc3       <= new_crc(tx_crc3, tx_lsb_data(3));
                  tx_count      <= tx_count - 1;
               end if;

               if tx_count < 16 then
                  sd_dat_out_o  <= tx_crc3(15) & tx_crc2(15) & tx_crc1(15) & tx_crc0(15);
                  sd_dat_oe_n_o <= '0';
                  tx_crc0       <= tx_crc0(14 downto 0) & "0";
                  tx_crc1       <= tx_crc1(14 downto 0) & "0";
                  tx_crc2       <= tx_crc2(14 downto 0) & "0";
                  tx_crc3       <= tx_crc3(14 downto 0) & "0";
                  if tx_count = 0 then
                     write_delay <= C_WRITE_DELAY_MAX;
                     write_state <= WAIT_ST;
                  else
                     tx_count <= tx_count - 1;
                  end if;
               end if;
            end if;
         end if;

         if rst_i = '1' then
            tx_lsb_valid  <= '0';
            write_state   <= IDLE_ST;
            sd_dat_out_o  <= "1111";
            sd_dat_oe_n_o <= '1';
         end if;
      end if;
   end process write_proc;

end architecture synthesis;

