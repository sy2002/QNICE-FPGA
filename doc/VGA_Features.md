# VGA Features

This file contains the register map for the VGA module and a description of the
features supported by the VGA module.

## Register Map

Address | Description
------- | ------------
`FF30`  | Command and Status (CSR)
`FF31`  | Cursor X
`FF32`  | Cursor Y
`FF33`  | Character at cursor
`FF34`  | Display offset
`FF35`  | Cursor offset
`FF39`  | Font offset
`FF3C`  | Address into Font RAM
`FF3D`  | Data to/from Font RAM
`FF3E`  | Address into Palette RAM
`FF3F`  | Data to/from Palette RAM
`FF40`  | Pixels to adjust screen in X direction
`FF41`  | Pixels to adjust screen in Y direction
`FF42`  | Current scan line
`FF43`  | Scan line to generate interrupt on
`FF44`  | Interrupt Service Routine Address

The Command and Status Register is decoded as follows
* Bit 11 : Cursor offset enable (`FF35`)
* Bit 10 : Display offset enable (`FF34`)
* Bit  9 (R/O) : Busy
* Bit  8 : Clear screen (this bit autoclears)
* Bit  7 : VGA output enable
* Bit  6 : Hardware cursor enable
* Bit  5 : Hardware cursor blink enable
* Bit  4 : Hardware cursor size

## VGA resolution
The VGA output has a resolution of 640x480 pixels at 60 frames per second. The
pixel clock freqeuncy is 25.2 MHz.

The color depth is board dependent: On the Nexys4DDR board there are 12 color bits,
while on the MEGA65 there are 24 color bits.

## Special QNICE 15-bit color mode

The QNICE project uses 15-bit colors, with 5 bits for each color channel
(RGB).  On some platforms (e.g. the Nexys4DDR) with lower color resolution,
the LSBs are discarded.

The bit pattern of the QNICE 15-bit color format is: `XRRRRRGGGGGBBBBB`,
where `X` is the background/foreground bit and the `R`, `G`, `B` bits are
5-bit versions of the red, green, blue values. Since a conversion from the
more straight forward 24-bit format to the 15-bit format is not something that
many people can perform in their head, you can use the command line tool
`tools/rgb2q`. For example, if you want to convert a straight green
to QNICE 15-bit, then enter

```
tools/rgb2q 0x00FF00
```

and you will receive 

```
24-bit RGB value 00FF00 => 15-bit QNICE value 0x03E0
```

## Display modes
The QNICE project supports the following display modes:
* 16-Color text mode: 80x40 characters. Foreground and Background colors
  selected individually from two different palettes.
* (TBD) Lo-res graphics mode: 320x200 pixels, with 15-bit colors for each pixel.
* (TBD) Hi-res (16-color) graphics mode: 640x400 pixels, with color selected from a
  palette.

## Default palette
The QNICE supports two palettes of 16 different colors. The initial colors are
from [here](http://alumni.media.mit.edu/~wad/color/palette.html), scaled down
to 15 bits.

Index | Color       | RGB (5,5,5 bits) | 15-bit value | 24-bit value
----- | ----------- | ---------------- | ------------ | ------------
  0   | Black       | 0, 0, 0          | 0x0000       | 000000
  1   | Dark Gray   | 10, 10, 10       | 0x294A       | 505050
  2   | Red         | 21, 4, 4         | 0x5484       | A82020
  3   | Blue        | 5, 9, 26         | 0x153A       | 2848D0
  4   | Green       | 3, 13, 2         | 0x0DA2       | 186810
  5   | Brown       | 16, 9, 3         | 0x4123       | 804818
  6   | Purple      | 16, 4, 24        | 0x4098       | 8020C0
  7   | Light Gray  | 20, 20, 20       | 0x5294       | A0A0A0
  8   | Light Green | 16, 24, 15       | 0x430F       | 80C078
  9   | Light Blue  | 19, 21, 31       | 0x4EBF       | 98A8F8
 10   | Cyan        | 5, 26, 26        | 0x175A       | 28D0D0
 11   | Orange      | 31, 18, 6        | 0x7E46       | F89030
 12   | Yellow      | 31, 29, 6        | 0x7FA6       | F8E830
 13   | Tan         | 29, 27, 23       | 0x7777       | E8D8B8
 14   | Pink        | 31, 25, 30       | 0x7F3E       | F8C8F0
 15   | White       | 31, 31, 31       | 0x7FFF       | F8F8F8

## Hardware blinking cursor
When in text mode, the hardware optionally generates a blinking cursor.

## Hardware scrolling
When in text mode, the hardware supports of to 20 screens (= 800 lines) of text.

## Video RAM
The VGA module contains a (separate from the CPU) Video RAM. This memory is
divided into three different blocks:
* Display RAM: Contains the characters and color (when in text mode) or the
  bitmap (when in graphics mode).
* Font RAM: Contains the bitmaps of the individual characters.
* Palette RAM: Contains the palette used when in 16-color mode.

All three memory blocks are accessed by first setting up the address and then
reading/writing the data at the specified address.

### Display RAM
The Display RAM has a size of 64 kW. This corresponds to 20 screens (= 800
lines) of text when in 16-color text mode.

The address in the Display RAM is dependent on the display mode. In 16-color
text mode, the address is calculated from the cursor position and the cursor
offset. In other words:

address = 80 * `Cursor Y` + `Cursor X` + `Cursor offset`.

Clearing of the entire Display RAM can be done by setting bit 8 of the `Command
and Status Register`. This bit auto-clears when the clearing has completed (in
65536/25.2 MHz = approximately 3 milliseconds).

When in 16-color text mode, the data in the Display RAM is interpreted as follows:
* Bits 15-12 : Background color selected from background palette.
* Bits 11- 8 : Foreground color selected from foreground palette.
* Bits  7- 0 : Character value. Selects one of 256 possible characters.

### Font RAM
The Font RAM is used when in 16-color text mode. Each of the 256 characters
has an associated 8x12 bitmap, i.e. 8 pixels wide and 12 pixels high.

The Font RAM has a size of 8 kB, addressed one byte at a time (i.e. 0x0000 -
0x1FFF). The expected use case is to have two different fonts, one located at
address 0x0000 - 0x0BFF, and the other at address 0x1000 - 0x1BFF.

The current Font used is controlled by the `Font offset` register.

The first half of the Font RAM is read-only. This means it is not possible to
clear/change the contents at address 0x0000 - 0x0FFF. If the user wants to make
modifications to the default font, it is necessary to copy the default font to
address 0x1000 - 0x1FFF, and to edit the font there.

### Palette RAM
The Palette RAM is used when in 16-color modes (both text and hi-res graphics).
The Palette RAM has a size of 32 words. This corresponds to two different palettes.

* The addresses 0x00 - 0x0F are used for the foreground palette (when in text mode
and in hi-res graphics mode).
* The addresses 0x10 - 0x1F are used for the background palette (when in text mode).

The Palette RAM must be initialized in software.

## Pixel scrolling
When in text mode the screen contents may be shifted any number of pixels in
either direction.  This is controlled by the two registers `VGA_ADJUST_X` and
`VGA_ADJUST_Y`.

## Scan line interrupt
The VGA module allows the processor to read the horizontal scan line being
currently being displayed. Furthermore, the VGA module can be programmed to
generate an interrupt when a specific scan line is reached.

