# VGA Multicolour Design

This file contains a brief description of the features supported by the VGA
module, and now they are implemented.

## Features
### Colours and palettes
The QNICE project uses 15-bit colours, with 5 bits for each colour channel
(RGB).  On some platforms (e.g. the Nexys4DDR) with lower colour resolution,
the LSBs are discarded.

The QNICE supports a palette of 16 different colours. The initial colours are
from [here](http://alumni.media.mit.edu/~wad/color/palette.html), scaled down
to 15 bits.

Index | Colour      | RGB (5,5,5 bits) | 15-bit value
----- | ----------- | ---------------- | ------------
  0   | Black       | 0, 0, 0          | 0x0000
  1   | Dark Gray   | 10, 10, 10       | 0x294A
  2   | Red         | 21, 4, 4         | 0x5484
  3   | Blue        | 5, 9, 26         | 0x153A
  4   | Green       | 3, 13, 2         | 0x0DA2
  5   | Brown       | 16, 9, 3         | 0x4123
  6   | Purple      | 16, 4, 24        | 0x4098
  7   | Light Gray  | 20, 20, 20       | 0x5294
  8   | Light Green | 16, 24, 15       | 0x430F
  9   | Light Blue  | 19, 21, 31       | 0x4EBF
 10   | Cyan        | 5, 26, 26        | 0x175A
 11   | Orange      | 31, 18, 6        | 0x7E46
 12   | Yellow      | 31, 29, 6        | 0x7FA6
 13   | Tan         | 29, 27, 23       | 0x7777
 14   | Pink        | 31, 25, 30       | 0x7F3E
 15   | White       | 31, 31, 31       | 0x7FFF


### VGA resolution
The VGA output has a resolution of 640x480 pixels at 60 frames per second. The
pixel clock freqeuncy is 25.2 MHz.

### Display modes
The QNICE project supports the following display modes:
* Colour text mode: 80x40 characters. Foreground and Background colours selected
individually from two different 16-colour palettes.
* Lo-res graphics mode: 320x200 pixels, with 15-bit colours for each pixel.
* Hi-res graphics mode: 640x400 pixels, with colour selected from a 16-colour palette.

## Implementation
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
This entire block works solely in the CPU clock domain.

The core of this block is the signal `register_map` that contains the 16
registers accessible by the CPU.

The output signals from this block are divided into two groups: One group
writes to and reads from the Video RAM and the other group provides
configuration signals directly to the `vga_output` block.

## `vga_output`
This block receives configuration signals from the `vga_register_map` block as
well as reads from the three parts of the Video RAM (Display RAM, Font RAM, and
Palette RAM). From these, this block generates the VGA output signals.  This
block consists of these three sub blocks:
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
calculated from the values read from the Font RAM and the Display RAM.

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

