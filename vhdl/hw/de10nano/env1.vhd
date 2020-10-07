library ieee;
use ieee.std_logic_1164.all;

entity env1 is
   port (
      ------------ ADC ----------
      adc_convst        : out   std_logic;
      adc_sck           : out   std_logic:
      adc_sdi           : out   std_logic;
      adc_sdo           : in    std_logic;

      ------------ ARDUINO ----------
      arduino_io        : inout std_logic_vector(15 downto 0);
      arduino_reset_n   : inout std_logic;

      ------------ CLOCK ----------
      fpga_clk1_50      : in    std_logic;
      fpga_clk2_50      : in    std_logic;
      fpga_clk3_50      : in    std_logic;

      ------------ HDMI ----------
      hdmi_i2c_scl      : inout std_logic;
      hdmi_i2c_sda      : inout std_logic;
      hdmi_i2s          : inout std_logic;
      hdmi_lrclk        : inout std_logic;
      hdmi_mclk         : inout std_logic;
      hdmi_sclk         : inout std_logic;
      hdmi_tx_clk       : out   std_logic;
      hdmi_tx_de        : out   std_logic;
      hdmi_tx_d         : out   std_logic_vector(23 downto 0);
      hdmi_tx_hs        : out   std_logic;
      hdmi_tx_int       : in    std_logic;
      hdmi_tx_vs        : out   std_logic;

      ------------ HPS ----------
      hps_conv_usb_n    : inout std_logic;
      hps_ddr3_addr     : out   std_logic_vector(14 downto 0);
      hps_ddr3_ba       : out   std_logic_vector(2 downto 0);
      hps_ddr3_cas_n    : out   std_logic;
      hps_ddr3_cke      : out   std_logic;
      hps_ddr3_ck_n     : out   std_logic;
      hps_ddr3_ck_p     : out   std_logic;
      hps_ddr3_cs_n     : out   std_logic;
      hps_ddr3_dm       : out   std_logic_vector(3 downto 0);
      hps_ddr3_dq       : inout std_logic_vector(31 downto 0);
      hps_ddr3_dqs_n    : inout std_logic_vector(3 downto 0);
      hps_ddr3_dqs_p    : inout std_logic_vector(3 downto 0);
      hps_ddr3_odt      : out   std_logic;
      hps_ddr3_ras_n    : out   std_logic;
      hps_ddr3_reset_n  : out   std_logic;
      hps_ddr3_rzq      : in    std_logic;
      hps_ddr3_we_n     : out   std_logic;
      hps_enet_gtx_clk  : out   std_logic;
      hps_enet_int_n    : inout std_logic;
      hps_enet_mdc      : out   std_logic;
      hps_enet_mdio     : inout std_logic;
      hps_enet_rx_clk   : in    std_logic;
      hps_enet_rx_data  : in    std_logic_vector(3 downto 0);
      hps_enet_rx_dv    : in    std_logic;
      hps_enet_tx_data  : out   std_logic_vector(3 downto 0);
      hps_enet_tx_en    : out   std_logic;
      hps_gsensor_int   : inout std_logic;
      hps_i2c0_sclk     : inout std_logic;
      hps_i2c0_sdat     : inout std_logic;
      hps_i2c1_sclk     : inout std_logic;
      hps_i2c1_sdat     : inout std_logic;
      hps_key           : inout std_logic;
      hps_led           : inout std_logic;
      hps_ltc_gpio      : inout std_logic;
      hps_sd_clk        : out   std_logic;
      hps_sd_cmd        : inout std_logic;
      hps_sd_data       : inout std_logic_vector(3 downto 0);
      hps_spim_clk      : out   std_logic;
      hps_spim_miso     : in    std_logic;
      hps_spim_mosi     : out   std_logic;
      hps_spim_ss       : inout std_logic;
      hps_uart_rx       : in    std_logic;
      hps_uart_tx       : out   std_logic;
      hps_usb_clkout    : in    std_logic;
      hps_usb_data      : inout std_logic_vector(7 downto 0);
      hps_usb_dir       : in    std_logic;
      hps_usb_nxt       : in    std_logic;
      hps_usb_stp       : out   std_logic;

      ------------ KEY ----------
      key               : in    std_logic_vector(1 downto 0);

      ------------ LED ----------
      led               : out   std_logic_vector(7 downto 0);

      ------------ SW ----------
      sw                : in    std_logic_vector(3 downto 0);

      ------------ GPIO_0  GPIO connect to GPIO Default ----------
      gpio_0            : inout std_logic_vector(35 downto 0);

      ------------ GPIO_1  GPIO connect to GPIO Default ----------
      gpio_1            : inout std_logic_vector(35 downto 0)
   );
end entity env1;

architecture synthesis of env1 is

begin

end architecture synthesis;

