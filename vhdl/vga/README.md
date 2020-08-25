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
This entire block works in the solely in the CPU clock domain.

The core of this block is the signal `register_map` that contains the 16
registers accessible by the CPU.

The outputs from this block are divided into two groups: One group writes to
and reads from the Video RAM and the other group provides control signals
directly to the `vga_output` block.

## `vga_output`
This block receives configuration signals from the `vga_register_map` block as
well as has access to read from the three parts of the Video RAM (Display RAM,
Font RAM, and Palette RAM). From these, this block generates the VGA output
signals.  This block consists of these three sub blocks:
* `vga_pixel_counters`
* `vga_text_mode`
* `vga_sync`
These blocks will be described in the following:

### `vga_pixel_counters`
This small block generates the X and Y pixel coordinates in the intervals 0-799
and 0-524, as well as a frame counter in the interval 0-59. The counters wrap
around after exactly one second. The frame counter is used to control the
blinking cursor.

### `vga_text_mode`
This is the most complex part of the module. This block receives the
configuration signals from the `vga_register_map` and the pixel counters from
the block `vga_pixel_counters` and it reads data from the Display RAM, the Font
RAM, and the Palette RAM. It then generates an output stream of pixel colours
in RGB format.

The operation is divided into three steps:
1.  First it reads a single word from the Display RAM, where the address is
calculated from the current pixel coordinates.
2. Then it reads a single word from the Font RAM, where the address is calculated
from the value read from the Display RAM.
3. Finally it reads a single word from the Palette RAM, where the adress is
calculated from the value read from the Font RAM.

### `vga_sync`
This small module generates the Horizontal and Vertical synchronization signals
needed for the VGA output. Furthermore, it blanks the screen (i.e. sets the
colour output to black), when the current pixel is outside the screen area.

## `vga_video_ram`
This block makes use of True Dual Port (TDP) memory, which is a builtin part of
the FPGA. This is regular RAM with two completely independent ports, each with
their own address and data signals and even clock signals.

This block actually instantiates the block `true_dual_port_ram` three times,
one for each of:
* Display RAM  (64 kW)
* Font RAM     ( 4 kB)
* Palette RAM  (32 words)

