# VGA Multicolour Design

The VGA Multicolour block connects directly to the CPU and to the VGA output
port on the FPGA.

Since the CPU runs at 50 MHz and the VGA output port runs at 25 MHz we have two
different clock domains. To avoid timing problems it is convenient to split the
VGA multicolour module into separate blocks each using only a single clock
signal.

The file [vga_multicolour.vhd](vga_multicolour.vhd) therefore instantiates three
blocks:
* `vga_register_map`
* `vga_output`
* `vga_video_ram`
The first block (`vga_register_map`) connects to the CPU using only the CPU
clock domain (50 MHx) and the second block (`vga_output`) connects to the VGA
output port using only the VGA clock domain (25 MHz). Only the last block
(`vga_video_ram`) uses both clock domains.

Each of these blocks will be described below.

## `vga_register_map`
This entire block works in the single CPU clock domain.

## `vga_output`

## `vga_video_ram`
This block makes use of True Dual Port (TDP) memory, which is a builtin part of
the FPGA. This is regular RAM with two completely independent ports, each with
their own address and data signals and even clock signals.

This block actually instantiates the block `true_dual_port_ram` three times,
one for each of:
* Display RAM  (64 kW)
* Font RAM     ( 4 kB)
* Palette RAM  (32 words)

