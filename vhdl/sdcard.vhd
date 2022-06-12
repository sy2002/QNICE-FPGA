-- SD Card Interface
-- uses 512-byte block addressing on all card types, i.e.
-- address #0 is the linear data between 0 .. 511 and
-- address #1 is the linear data between 512 .. 1023, etc.
--
-- This interface wraps Lawrence Wilkinson's awesome "SimpleSDHC" component
-- (that can be found here: https://github.com/ibm2030/SimpleSDHC)
-- into a state machine that supports the MMIO logic and that
-- utilizes an internal 512-byte RAM buffer using the byte_bram component.
-- It is meant to be connected with the QNICE CPU as data I/O controled through MMIO;
-- output goes zero when not enabled.
--
-- registers:
-- 0 : low word of 32bit SD card block address
-- 1 : high word of 32bit SD card block address
-- 2 : "cursor" to navigate the 512-byte data buffer
-- 3 : read/write 1 byte from/to the 512-byte data buffer
-- 4 : error code of last operation (read only)
-- 5 : command and status register (write to execute command)
--     SD-Opcodes (CSR):    0x0000  Reset SD card
--                          0x0001  Read 512 bytes from the linear block address
--                          0x0002  Write 512 bytes to the linear block address
--     bits 0..2 are write-only (reading always returns 0)
--     bits 13 .. 12 return the card type: 00 = no card / unknown card
--                                         01 = SD V1
--                                         10 = SD V2
--                                         11 = SDHC
--     bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
--                                         a case, the error code is in register #4 and
--                                         you need to reset the controller to go on
--     bit 15 of the CSR is the busy bit: 1, if current operation is still running
--
-- done by sy2002 in August 2016

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity sdcard is
   port (
      clk          : in  std_logic;         -- system clock
      reset        : in  std_logic;         -- async reset

      -- registers
      en           : in  std_logic;         -- enable for reading from or writing to the bus
      we           : in  std_logic;         -- write to the registers via system's data bus
      reg          : in  std_logic_vector(2 downto 0);   -- register selector
      data_in      : in  std_logic_vector(15 downto 0);  -- system's data bus
      data_out     : out std_logic_vector(15 downto 0);  -- system's data bus

      -- hardware interface
      sd_clk_o     : out std_logic;
      sd_cmd_in_i  : in  std_logic;
      sd_cmd_out_o : out std_logic;
      sd_cmd_oe_o  : out std_logic;
      sd_dat_in_i  : in  std_logic_vector(3 downto 0);
      sd_dat_out_o : out std_logic_vector(3 downto 0);
      sd_dat_oe_o  : out std_logic
   );
end entity sdcard;

architecture Behavioral of sdcard is

   signal avm_rst           : std_logic;   -- Synchronous reset, active high
   signal avm_write         : std_logic;
   signal avm_read          : std_logic;
   signal avm_address       : std_logic_vector(31 downto 0);
   signal avm_writedata     : std_logic_vector(7 downto 0) := X"00";
   signal avm_burstcount    : std_logic_vector(15 downto 0) := X"0200";
   signal avm_readdata      : std_logic_vector(7 downto 0);
   signal avm_readdatavalid : std_logic;
   signal avm_waitrequest   : std_logic;
   signal avm_init_error    : std_logic;
   signal avm_crc_error     : std_logic;
   signal avm_last_state    : std_logic_vector(7 downto 0);

   -- 8-bit BRAM with a 16-bit address bus
   component byte_bram is
      generic (
         SIZE_BYTES : integer
      );
      port (
         clk        : in  std_logic;
         we         : in  std_logic;
         address_i  : in  std_logic_vector(15 downto 0);
         address_o  : in  std_logic_vector(15 downto 0);
         data_i     : in  std_logic_vector(7 downto 0);
         data_o     : out std_logic_vector(7 downto 0)
      );
   end component byte_bram;

   -- RAM signals (512 byte buffer RAM)
   signal ram_we      : std_logic;
   signal ram_wr_addr : std_logic_vector(15 downto 0);
   signal ram_rd_addr : std_logic_vector(15 downto 0);
   signal ram_wr_data : std_logic_vector(7 downto 0);
   signal ram_rd_data : std_logic_vector(7 downto 0);

begin

   ---------------------------------------------------------
   -- Register interface
   ---------------------------------------------------------

   write_sdcard_registers : process (clk)
   begin
      if falling_edge(clk) then
         avm_rst   <= '0';
         avm_read  <= '0';
         avm_write <= '0';

         if en = '1' and we = '1' then
            case reg is
               when "000" => avm_address(15 downto 0)  <= data_in;
               when "001" => avm_address(31 downto 16) <= data_in;
               when "010" => ram_rd_addr <= data_in;
               when "101" =>
                  case data_in is
                     when X"0000" => avm_rst  <= '1';
                     when X"0001" => avm_read <= '1';
                     when others  => null;
                  end case;
               when others => null;
            end case;
         end if;

         if reset = '1' then
            avm_address <= (others => '0');
            ram_rd_addr <= (others => '0');
            avm_rst     <= '1';
         end if;
      end if;
   end process write_sdcard_registers;

   read_sdcard_registers : process(all)
   begin
      if en = '1' and we = '0' then
         case reg is
            when "000"  => data_out <= avm_address(15 downto 0);
            when "001"  => data_out <= avm_address(31 downto 16);
            when "010"  => data_out <= ram_rd_addr;
            when "011"  => data_out <= X"00" & ram_rd_data;
            when "101"  => data_out <= avm_waitrequest & avm_init_error & avm_crc_error & "00000" & avm_last_state;
            when others => data_out <= (others => '0');
         end case;
      else
         data_out <= (others => '0');
      end if;
   end process read_sdcard_registers;


   ---------------------------------------------------------
   -- Instantiate SD card controller
   ---------------------------------------------------------

   i_sdcard_wrapper : entity work.sdcard_wrapper
      port map (
         avm_clk_i           => clk,
         avm_rst_i           => avm_rst,
         avm_write_i         => avm_write,
         avm_read_i          => avm_read,
         avm_address_i       => avm_address,
         avm_writedata_i     => avm_writedata,
         avm_burstcount_i    => avm_burstcount,
         avm_readdata_o      => avm_readdata,
         avm_readdatavalid_o => avm_readdatavalid,
         avm_waitrequest_o   => avm_waitrequest,
         avm_init_error_o    => avm_init_error,
         avm_crc_error_o     => avm_crc_error,
         avm_last_state_o    => avm_last_state,
         sd_clk_o            => sd_clk_o,
         sd_cmd_in_i         => sd_cmd_in_i,
         sd_cmd_out_o        => sd_cmd_out_o,
         sd_cmd_oe_o         => sd_cmd_oe_o,
         sd_dat_in_i         => sd_dat_in_i,
         sd_dat_out_o        => sd_dat_out_o,
         sd_dat_oe_o         => sd_dat_oe_o
      ); -- i_sdcard_wrapper


   ---------------------------------------------------------
   -- 512 byte buffer RAM (SD card is configured to read/write 512 byte blocks)
   ---------------------------------------------------------

   i_byte_ram : byte_bram
      generic map (
         SIZE_BYTES => 512
      )
      port map
      (
         clk       => clk,
         we        => ram_we,
         address_i => ram_wr_addr,
         address_o => ram_rd_addr,
         data_i    => ram_wr_data,
         data_o    => ram_rd_data
      ); -- i_byte_ram

   ram_wr_data <= avm_readdata;
   ram_we      <= avm_readdatavalid;

   p_ram_wr_addr : process (clk)
   begin
      if rising_edge(clk) then
         if ram_we = '1' then
            ram_wr_addr <= ram_wr_addr + 1;
         end if;
         if reset = '1' or avm_read = '1' then
            ram_wr_addr <= (others => '0');
         end if;
      end if;
   end process p_ram_wr_addr;

end architecture Behavioral;

