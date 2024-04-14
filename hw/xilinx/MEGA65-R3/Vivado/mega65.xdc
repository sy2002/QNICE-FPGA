## MEGA65 R3 mapping for QNICE-FPGA
## done by MJoergen in April 2024

## External clock signal (100 MHz)
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports CLK]
create_clock -period 10.000 -name CLK [get_ports CLK]

create_generated_clock -name Slow_Clock_25MHz -source [get_pins {clk_main/CLKOUT2}] -divide_by 2 [get_pins sd_card/Slow_Clock_25MHz_reg/Q]

## Make the general clocks and the pixelclock unrelated to other to avoid erroneous timing
## violations, and hopefully make everything synthesise faster
set_clock_groups -asynchronous \
     -group { CLK CLK1x CLK2x CLKFBIN SLOW_CLOCK } \
     -group [get_clocks -of_objects [get_pins clk_main/CLKOUT0]]

## EAE's combinatorial division networks take longer than
## the regular clock period, so we specify a multicycle path
## see also the comments in EAE.vhd and explanations in UG903/chapter 5/Multicycle Paths as well as ug911/page 25
set_multicycle_path -from [get_cells -include_replicated {{eae_inst/op0_reg[*]} {eae_inst/op1_reg[*]}}] -to [get_cells -include_replicated {eae_inst/res_reg[*]}] -setup 3
set_multicycle_path -from [get_cells -include_replicated {{eae_inst/op0_reg[*]} {eae_inst/op1_reg[*]}}] -to [get_cells -include_replicated {eae_inst/res_reg[*]}] -hold 2

## The following set_max delay works fine, too at 50 MHz main clock and is an alternative to the multicycle path
#set_max_delay -from [get_cells {{eae_inst/op0_reg[*]} {eae_inst/op1_reg[*]}}] -to [get_cells {eae_inst/res_reg[*]}] 34.000

## Reset button
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports RESET_N]

## USB-RS232 Interface (rxd, txd only; rts/cts are not available)
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports UART_RXD]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports UART_TXD]

## MEGA65 smart keyboard controller
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports kb_io0]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports kb_io1]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports kb_io2]

## VGA via VDAC
set_property -dict {PACKAGE_PIN U15  IOSTANDARD LVCMOS33} [get_ports {VGA_RED[0]}]
set_property -dict {PACKAGE_PIN V15  IOSTANDARD LVCMOS33} [get_ports {VGA_RED[1]}]
set_property -dict {PACKAGE_PIN T14  IOSTANDARD LVCMOS33} [get_ports {VGA_RED[2]}]
set_property -dict {PACKAGE_PIN Y17  IOSTANDARD LVCMOS33} [get_ports {VGA_RED[3]}]
set_property -dict {PACKAGE_PIN Y16  IOSTANDARD LVCMOS33} [get_ports {VGA_RED[4]}]
set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS33} [get_ports {VGA_RED[5]}]
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS33} [get_ports {VGA_RED[6]}]
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33} [get_ports {VGA_RED[7]}]

set_property -dict {PACKAGE_PIN Y14  IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[0]}]
set_property -dict {PACKAGE_PIN W14  IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[1]}]
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[2]}]
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[3]}]
set_property -dict {PACKAGE_PIN Y13  IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[4]}]
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[5]}]
set_property -dict {PACKAGE_PIN AA13 IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[6]}]
set_property -dict {PACKAGE_PIN AB13 IOSTANDARD LVCMOS33} [get_ports {VGA_GREEN[7]}]

set_property -dict {PACKAGE_PIN W10  IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[0]}]
set_property -dict {PACKAGE_PIN Y12  IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[1]}]
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[2]}]
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[3]}]
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[4]}]
set_property -dict {PACKAGE_PIN Y11  IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[5]}]
set_property -dict {PACKAGE_PIN AB10 IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[6]}]
set_property -dict {PACKAGE_PIN AA10 IOSTANDARD LVCMOS33} [get_ports {VGA_BLUE[7]}]

set_property -dict {PACKAGE_PIN W12  IOSTANDARD LVCMOS33} [get_ports VGA_HS]
set_property -dict {PACKAGE_PIN V14  IOSTANDARD LVCMOS33} [get_ports VGA_VS]

set_property -dict {PACKAGE_PIN AA9  IOSTANDARD LVCMOS33} [get_ports vdac_clk]
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33} [get_ports vdac_sync_n]
set_property -dict {PACKAGE_PIN W11  IOSTANDARD LVCMOS33} [get_ports vdac_blank_n]

## Micro SD Connector (this is the slot at the bottom side of the case under the cover)
set_property -dict {PACKAGE_PIN B15  IOSTANDARD LVCMOS33} [get_ports SD_RESET]
set_property -dict {PACKAGE_PIN B17  IOSTANDARD LVCMOS33} [get_ports SD_CLK]
set_property -dict {PACKAGE_PIN B16  IOSTANDARD LVCMOS33} [get_ports SD_MOSI]
set_property -dict {PACKAGE_PIN B18  IOSTANDARD LVCMOS33} [get_ports SD_MISO]

## HyperRAM (standard)
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports hr_clk_p]
set_property -dict {PACKAGE_PIN A21 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[0]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[1]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[2]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[3]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[4]}]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[5]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[6]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports {hr_d[7]}]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33 PULLUP FALSE SLEW FAST DRIVE 16} [get_ports hr_rwds]
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr_reset]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr_cs0]

## Additional HyperRAM on trap-door PMOD
## Pinout is for one of these: https://github.com/blackmesalabs/hyperram
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr2_clk_p]
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[0]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[1]}]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[2]}]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[3]}]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[4]}]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[5]}]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[6]}]
set_property -dict {PACKAGE_PIN D1 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports {hr2_d[7]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr2_rwds]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr2_reset]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr_cs1]

## Configuration and bitstream properties
set_property CONFIG_VOLTAGE                  3.3   [current_design]
set_property CFGBVS                          VCCO  [current_design]
set_property BITSTREAM.GENERAL.COMPRESS      TRUE  [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE     66    [current_design]
set_property CONFIG_MODE                     SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES   [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH   4     [current_design]

