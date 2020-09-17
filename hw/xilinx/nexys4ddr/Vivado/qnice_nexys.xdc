## Nexys4 DDR mapping for QNICE-FPGA
## done by sy2002 in May 2020

## External clock signal (100 MHz)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK]
create_clock -period 10.000 -name CLK [get_ports CLK]

## Handle the Clock Domain Crossing
## Any register wrapped inside a generate statement with the name `gen_cdc`
## will be considered part of a Clock Domain Crossing.
set_false_path -from [get_clocks -of_objects [get_pins i_clk/i_mmcme2_adv/CLKOUT0]] \
               -to [get_pins -hierarchical {*gen_cdc.*/D}]
set_false_path -from [get_clocks -of_objects [get_pins i_clk/i_mmcme2_adv/CLKOUT1]] \
               -to [get_pins -hierarchical {*gen_cdc.*/D}]

## EAE's combinatorial division networks take longer than
## the regular clock period, so we specify a multicycle path
## see also the comments in EAE.vhd and explanations in UG903/chapter 5/Multicycle Paths as well as ug911/page 25
set_multicycle_path -from [get_cells {{eae_inst/op0_reg*} {eae_inst/op1_reg*}}] -to [get_cells {eae_inst/res_reg[*]}] -setup 3
set_multicycle_path -from [get_cells {{eae_inst/op0_reg*} {eae_inst/op1_reg*}}] -to [get_cells {eae_inst/res_reg[*]}] -hold 2

## The following set_max delay works fine, too at 50 MHz main clock and is an alternative to the multicycle path
#set_max_delay -from [get_cells {{eae_inst/op0_reg[*]} {eae_inst/op1_reg[*]}}] -to [get_cells {eae_inst/res_reg[*]}] 34.000

## Reset button
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports RESET_N]

## 7 segment display
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[0]}]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[1]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[2]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[3]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[4]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[5]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[6]}]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {SSEG_CA[7]}]

set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[2]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[3]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[4]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[5]}]
set_property -dict {PACKAGE_PIN K2  IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[6]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {SSEG_AN[7]}]

## USB-RS232 Interface
set_property -dict {PACKAGE_PIN C4  IOSTANDARD LVCMOS33} [get_ports UART_RXD]
set_property -dict {PACKAGE_PIN D4  IOSTANDARD LVCMOS33} [get_ports UART_TXD]
set_property -dict {PACKAGE_PIN D3  IOSTANDARD LVCMOS33} [get_ports UART_CTS]
set_property -dict {PACKAGE_PIN E5  IOSTANDARD LVCMOS33} [get_ports UART_RTS]

## Switches
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[0]}] 
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[1]}] 
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[2]}] 
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[3]}] 
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[4]}] 
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[5]}] 
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[6]}] 
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[7]}] 
set_property -dict {PACKAGE_PIN T8  IOSTANDARD LVCMOS33} [get_ports {SWITCHES[8]}] 
set_property -dict {PACKAGE_PIN U8  IOSTANDARD LVCMOS33} [get_ports {SWITCHES[9]}] 
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[10]}] 
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[11]}] 
set_property -dict {PACKAGE_PIN H6  IOSTANDARD LVCMOS33} [get_ports {SWITCHES[12]}] 
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[13]}] 
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[14]}] 
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[15]}] 

## PS/2 keyboard
set_property -dict {PACKAGE_PIN F4  IOSTANDARD LVCMOS33} [get_ports PS2_CLK]
set_property -dict {PACKAGE_PIN B2  IOSTANDARD LVCMOS33} [get_ports PS2_DAT]

## LEDs
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {LEDs[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {LEDs[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {LEDs[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {LEDs[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {LEDs[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {LEDs[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {LEDs[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {LEDs[7]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {LEDs[8]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {LEDs[9]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {LEDs[10]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {LEDs[11]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {LEDs[12]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {LEDs[13]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {LEDs[14]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {LEDs[15]}]

## VGA
set_property -dict {PACKAGE_PIN A3  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[0]}]
set_property -dict {PACKAGE_PIN B4  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[1]}]
set_property -dict {PACKAGE_PIN C5  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[2]}]
set_property -dict {PACKAGE_PIN A4  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[3]}]
set_property -dict {PACKAGE_PIN C6  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[0]}]
set_property -dict {PACKAGE_PIN A5  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[1]}]
set_property -dict {PACKAGE_PIN B6  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[2]}]
set_property -dict {PACKAGE_PIN A6  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[3]}]
set_property -dict {PACKAGE_PIN B7  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[0]}]
set_property -dict {PACKAGE_PIN C7  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[1]}]
set_property -dict {PACKAGE_PIN D7  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[2]}]
set_property -dict {PACKAGE_PIN D8  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[3]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports VGA_HS]
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports VGA_VS]

##Micro SD Connector
set_property -dict {PACKAGE_PIN E2  IOSTANDARD LVCMOS33} [get_ports SD_RESET]       
set_property -dict {PACKAGE_PIN B1  IOSTANDARD LVCMOS33} [get_ports SD_CLK]         
set_property -dict {PACKAGE_PIN C1  IOSTANDARD LVCMOS33} [get_ports SD_MOSI]        
set_property -dict {PACKAGE_PIN C2  IOSTANDARD LVCMOS33} [get_ports SD_MISO]        
set_property -dict {PACKAGE_PIN E1  IOSTANDARD LVCMOS33} [get_ports {SD_DAT[1]}]
set_property -dict {PACKAGE_PIN F1  IOSTANDARD LVCMOS33} [get_ports {SD_DAT[2]}]
set_property -dict {PACKAGE_PIN D2  IOSTANDARD LVCMOS33} [get_ports {SD_DAT[3]}]
#set_property -dict {PACKAGE_PIN A1  IOSTANDARD LVCMOS33} [get_ports SD_CD]          

## Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

