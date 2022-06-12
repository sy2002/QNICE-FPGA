-- This is the wrapper file for the complete SDCard controller.

-- The SD Card is powered up in the SD mode. It will enter SPI mode if the
-- CS (DAT3) signal is asserted (negative) during the reception of the reset
-- command (CMD0). If the card recognizes that the SD mode is required it
-- will not respond to the command and remain in the SD mode. If SPI mode is
-- required, the card will switch to SPI and respond with the SPI mode R1
-- response.

-- List of used commands:
-- CMD0  : GO_IDLE_STATE: Resets the SD Card.
-- CMD3  : SEND_RCA
-- CMD8  : SEND_IF_COND: Sends SD Memory Card interface condition that includes host supply voltage.
-- ACMD41: SD_SEND_OP_COND: Sends host capacity support information and activated the card's initialization process.
-- CMD13 : SEND_STATUS: Asks the selected card to send its status register.
-- CMD16 : SET_BLOCKLEN: In case of non-SDHC card, this sets the block length. Block length of SDHC/SDXC cards are fixed to 512 bytes
-- CMD17 : READ_SINGLE_BLOCK
-- CMD24 : WRITE_BLOCK
-- CMD55 : APP_CMD: Next command is an application specific command.
-- CMD58 : READ_OCR: Read the OCR register of the card.

-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/SDCard).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sdcard_globals.all;

entity sdcard_wrapper is
   port (
      -- Avalon Memory Map
      avm_clk_i           : in  std_logic;   -- 50 Mhz
      avm_rst_i           : in  std_logic;   -- Synchronous reset, active high
      avm_write_i         : in  std_logic;
      avm_read_i          : in  std_logic;
      avm_address_i       : in  std_logic_vector(31 downto 0);
      avm_writedata_i     : in  std_logic_vector(7 downto 0);
      avm_burstcount_i    : in  std_logic_vector(15 downto 0);
      avm_readdata_o      : out std_logic_vector(7 downto 0);
      avm_readdatavalid_o : out std_logic;
      avm_waitrequest_o   : out std_logic;
      avm_init_error_o    : out std_logic;
      avm_crc_error_o     : out std_logic;
      avm_last_state_o    : out std_logic_vector(7 downto 0);

      -- SDCard device interface
      sd_clk_o            : out std_logic;   -- 25 MHz or 400 kHz
      sd_cmd_in_i         : in  std_logic;
      sd_cmd_out_o        : out std_logic;
      sd_cmd_oe_o         : out std_logic;
      sd_dat_in_i         : in  std_logic_vector(3 downto 0);
      sd_dat_out_o        : out std_logic_vector(3 downto 0);
      sd_dat_oe_o         : out std_logic
   );
end entity sdcard_wrapper;

architecture synthesis of sdcard_wrapper is

   signal cmd_valid    : std_logic;
   signal cmd_ready    : std_logic;
   signal cmd_index    : natural range 0 to 63;
   signal cmd_data     : std_logic_vector(31 downto 0);
   signal cmd_resp     : natural range 0 to 255;
   signal cmd_timeout  : natural range 0 to 2**24-1;
   signal resp_valid   : std_logic;
   signal resp_ready   : std_logic;
   signal resp_data    : std_logic_vector(135 downto 0);
   signal resp_timeout : std_logic;
   signal resp_error   : std_logic;
   signal dat_ready    : std_logic;

begin

   ----------------------------------
   -- Instantiate main state machine
   ----------------------------------

   i_sdcard_ctrl : entity work.sdcard_ctrl
      port map (
         avm_clk_i           => avm_clk_i,
         avm_rst_i           => avm_rst_i,
         avm_write_i         => avm_write_i,
         avm_read_i          => avm_read_i,
         avm_address_i       => avm_address_i,
         avm_writedata_i     => avm_writedata_i,
         avm_burstcount_i    => avm_burstcount_i,
         avm_waitrequest_o   => avm_waitrequest_o,
         avm_init_error_o    => avm_init_error_o,
         avm_last_state_o    => avm_last_state_o,
         sd_clk_o            => sd_clk_o,
         cmd_valid_o         => cmd_valid,
         cmd_ready_i         => cmd_ready,
         cmd_index_o         => cmd_index,
         cmd_data_o          => cmd_data,
         cmd_resp_o          => cmd_resp,
         cmd_timeout_o       => cmd_timeout,
         resp_valid_i        => resp_valid,
         resp_ready_o        => resp_ready,
         resp_data_i         => resp_data,
         resp_timeout_i      => resp_timeout,
         resp_error_i        => resp_error,
         dat_ready_i         => dat_ready
      ); -- i_sdcard_ctrl


   ----------------------------------
   -- Instantiate CMD controller
   ----------------------------------

   i_sdcard_cmd : entity work.sdcard_cmd
      port map (
         clk_i          => avm_clk_i,
         rst_i          => avm_rst_i,
         cmd_valid_i    => cmd_valid,
         cmd_ready_o    => cmd_ready,
         cmd_index_i    => cmd_index,
         cmd_data_i     => cmd_data,
         cmd_resp_i     => cmd_resp,
         cmd_timeout_i  => cmd_timeout,
         resp_valid_o   => resp_valid,
         resp_ready_i   => resp_ready,
         resp_data_o    => resp_data,
         resp_timeout_o => resp_timeout,
         resp_error_o   => resp_error,
         sd_clk_i       => sd_clk_o,
         sd_cmd_in_i    => sd_cmd_in_i,
         sd_cmd_out_o   => sd_cmd_out_o,
         sd_cmd_oe_o    => sd_cmd_oe_o
      ); -- i_sdcard_cmd


   ----------------------------------
   -- Instantiate DAT controller
   ----------------------------------

   i_sdcard_dat : entity work.sdcard_dat
      port map (
         clk_i          => avm_clk_i,
         rst_i          => avm_rst_i,
         ready_o        => dat_ready,
         tx_valid_i     => '0',
         tx_data_i      => (others => '0'),
         rx_valid_o     => avm_readdatavalid_o,
         rx_data_o      => avm_readdata_o,
         rx_crc_error_o => avm_crc_error_o,
         sd_clk_i       => sd_clk_o,
         sd_dat_in_i    => sd_dat_in_i,
         sd_dat_out_o   => sd_dat_out_o,
         sd_dat_oe_o    => sd_dat_oe_o
      ); -- i_sdcard_dat

end architecture synthesis;

