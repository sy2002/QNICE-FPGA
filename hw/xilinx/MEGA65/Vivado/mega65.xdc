## MEGA65 mapping for QNICE-FPGA
## done by sy2002 in April and May 2020

# In xdc, all clocks are related by default. This differs from ucf, where clocks are
# unrelated unless specified otherwise. As a result, you may now see cross-clock paths
# that were previously unconstrained in ucf. Commented out xdc false path constraints
# have been generated and can be uncommented, should you wish to remove these new paths.
# These commands are located after the last clock definition

## External clock signal (100 MHz)
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports CLK]
create_clock -name CLK -period 10.000 [get_ports CLK]

## Internal clock divider SLOW_CLOCK that creates the 50 MHz used throughout the system
create_generated_clock -name SLOW_CLOCK -source [get_ports CLK] -divide_by 2 [get_pins SLOW_CLOCK_reg/Q]

## VGA pixelclock
create_generated_clock -name clk25MHz -source [get_pins SLOW_CLOCK_reg/Q] -divide_by 2 [get_pins vga_screen/clk25MHz_reg/Q]

# The following cross clock domain false path constraints can be uncommented in order to mimic ucf constraints behavior (see message at the beginning of this file)
# set_false_path -from [get_clocks CLK] -to [get_clocks SLOW_CLOCK]
# set_false_path -from [get_clocks SLOW_CLOCK] -to [get_clocks CLK]

## EAE's combinatorial division networks take longer than
## the regular clock period, so we specify a timing constraint
## for them (see also the comments in EAE.vhd)
#set_max_delay 32.000 -from [get_cells eae_inst/op*] -to [get_cells eae_inst/res*]

#set_max_delay 32.000 -from [all_fanout -from [get_nets clk_rx] -flat -endpoints_only] -to [all_fanout -from [get_nets clk_tx] -flat -endpoints_only] 5


## Reset button
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports RESET_N]

## USB-RS232 Interface (rxd, txd only; rts/cts are not available)
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports UART_RXD]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports UART_TXD]

## MEGA65 smart keyboard controller
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports kb_io0]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports kb_io1]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports kb_io2]

## VGA
set_property -dict {PACKAGE_PIN U15  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[0]}]
set_property -dict {PACKAGE_PIN V15  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[1]}]
set_property -dict {PACKAGE_PIN T14  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[2]}]
set_property -dict {PACKAGE_PIN Y17  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[3]}]
set_property -dict {PACKAGE_PIN Y16  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[4]}]
set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[5]}]
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[6]}]
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_RED[7]}]

set_property -dict {PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[0]}]
set_property -dict {PACKAGE_PIN W14  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[1]}]
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[2]}]
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[3]}]
set_property -dict {PACKAGE_PIN Y13  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[4]}]
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[5]}]
set_property -dict {PACKAGE_PIN AA13 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[6]}]
set_property -dict {PACKAGE_PIN AB13 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_GREEN[7]}]

set_property -dict {PACKAGE_PIN W10  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[0]}]
set_property -dict {PACKAGE_PIN Y12  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[1]}]
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[2]}]
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[3]}]
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[4]}]
set_property -dict {PACKAGE_PIN Y11  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[5]}]
set_property -dict {PACKAGE_PIN AB10 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[6]}]
set_property -dict {PACKAGE_PIN AA10 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {VGA_BLUE[7]}]

set_property -dict {PACKAGE_PIN W12  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports VGA_HS]
set_property -dict {PACKAGE_PIN V14  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports VGA_VS]

set_property -dict {PACKAGE_PIN AA9  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports vdac_clk]
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports vdac_sync_n]
set_property -dict {PACKAGE_PIN W11  IOSTANDARD LVCMOS33 SLEW FAST} [get_ports vdac_blank_n]

## Micro SD Connector (this is the slot at the bottom side of the case under the cover)
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33} [get_ports SD_RESET]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports SD_CLK]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports SD_MOSI]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports SD_MISO]

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
#set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33 PULLUP FALSE} [get_ports hr2_clk_n]
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
