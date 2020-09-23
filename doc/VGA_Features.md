# VGA Features

This file contains the register map for the VGA module and a description of the
features supported by the VGA module.

## Register Map

Address |       Name       | Description
------- |       ----       | ------------
`FF30`  |`VGA_STATE       `| Command and Status (CSR)
`FF31`  |`VGA_CR_X        `| Cursor X
`FF32`  |`VGA_CR_Y        `| Cursor Y
`FF33`  |`VGA_CHAR        `| Character at cursor
`FF34`  |`VGA_OFFS_RW     `| Cursor offset
`FF35`  |`VGA_OFFS_DISPLAY`| Display offset
`FF36`  |`VGA_FONT_OFFS   `| Font offset
`FF37`  |`VGA_FONT_ADDR   `| Address into Font RAM
`FF38`  |`VGA_FONT_DATA   `| Data to/from Font RAM
`FF39`  |`VGA_PALETTE_OFFS`| Palette offset
`FF3A`  |`VGA_PALETTE_ADDR`| Address into Palette RAM
`FF3B`  |`VGA_PALETTE_DATA`| Data to/from Palette RAM
`FF40`  |`VGA_ADJUST_X    `| Pixels to adjust screen in X direction
`FF41`  |`VGA_ADJUST_Y    `| Pixels to adjust screen in Y direction
`FF42`  |`VGA_SCAN_LINE   `| Current scan line
`FF43`  |`VGA_SCAN_INT    `| Scan line to generate interrupt on
`FF44`  |`VGA_SCAN_ISR    `| Interrupt Service Routine Address
`FF45`  |`VGA_SPRITE_ADDR `| Address into Sprite RAM
`FF46`  |`VGA_SPRITE_DATA `| Data to/from Sprite RAM

The Command and Status Register is decoded as follows
* Bit 12 : Global sprite enable
* Bit 11 : Cursor offset enable (`FF34`)
* Bit 10 : Display offset enable (`FF35`)
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
The QNICE supports separate foreground and background palettes each with 16
different colors. The default colors are from
[here](http://alumni.media.mit.edu/~wad/color/palette.html), scaled down to 15
bits.

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
When in text mode, the hardware supports up to 20 screens (= 800 lines) of text.

## Pixel scrolling
The screen contents may be shifted any number of pixels in either direction.
This is controlled by the two registers `VGA_ADJUST_X` and `VGA_ADJUST_Y`.

## Scan line interrupt
The VGA module allows the processor to read the horizontal scan line currently
being displayed. Furthermore, the VGA module can be programmed to generate an
interrupt when a specific scan line is reached.

## Sprites
The QNICE project offers a total of 128 different sprites.

Bit 12 in CSR provides a single bit to globally enable and disable all sprites
simultaneously.

Each sprite can have one of two resolutions:
* 32x32 high-resolution with 4-bit color index. This 4-bit value serves as an
  index into a 16-color palette, individual for each sprite.
* 16x16 low-resolution with 16-bit color depth. This 16-bit value provides
  a direct 15-bit RGB color output.

### Display priority
Lower numbered sprites appear in front of higher numbered sprites.

Each sprite may be configured to be either in front of the foreground, or between
the background and the foreground.

-------------------------

# Video RAM
The VGA module contains its own Video RAM separate from the main memory. This
Video RAM is divided into three different blocks:
* Display RAM: Contains the characters and color (when in text mode) or the
  bitmap (when in graphics mode).
* Font RAM: Contains the bitmaps of the individual characters.
* Palette RAM: Contains the palette used when in 16-color mode.
* Sprite RAM: Contains the bitmap and configuration of all sprites.

All three memory blocks are accessed by first setting up the address and then
reading/writing the data at the specified address.

## Display RAM
The Display RAM has a size of 64 kW. This corresponds to 20 screens (= 800
lines) of text when in 16-color text mode.

The address in the Display RAM is dependent on the display mode. In 16-color
text mode, the address is calculated from the cursor position and the cursor
offset. In other words:

address = 80 * `Cursor Y` + `Cursor X` + `Cursor offset`.

When in 16-color text mode, the data in the Display RAM is interpreted as follows:
* Bits 15-12 : Background color selected from background palette (see Palette RAM).
* Bits 11- 8 : Foreground color selected from foreground palette (see Palette RAM).
* Bits  7- 0 : Character value. Selects one of 256 possible characters (see Font RAM).

Clearing of the entire Display RAM can be done by setting bit 8 of the `Command
and Status Register`. This writes the value 0x0020 to all words in the display
RAM, corresponding to a space character with default foreground and background.

This bit auto-clears when the clearing has completed (in 64000/25.2 MHz =
approximately 3 milliseconds).

## Font RAM
The Font RAM is used when operating in text mode. Each of the 256 characters
has an associated 8x12 bitmap, i.e. 8 pixels wide and 12 pixels high. The font
is represented by 12 words (corresponding to each row of the bitmap) where in
each word only bits 7-0 are used.

The Font RAM has a size of 8 kW, i.e. addresses allowed are in the range
0x0000 - 0x1FFF.

The first half of the Font RAM is read-only. This means it is not possible to
clear/change the contents in the address range 0x0000 - 0x0FFF. If the user
wants to make modifications to the default font, the software must copy the
default font to addresses 0x1000 - 0x1FFF, and then edit the font there.

The current Font used is controlled by the `Font offset` register.

## Palette RAM
The Palette RAM is used when operating in 16-color modes (both text and hi-res
graphics).

The Palette RAM has a size of 64 words, i.e. addresses allowed are in the
range 0x0000 - 0x003F.

The first half of the Palette RAM is read-only. This means it is not possible
to clear/change the contents in the address range 0x0000 - 0x001F. If the user
wants to make modifications to the default palette, the software must copy the
default palette to addresses 0x0020 - 0x003F, and the edit the palette there.

The current Palette used is controlled by the `Palette offset` register.

* The addresses 0x00 - 0x0F are used for the foreground palette (when in text mode
and in hi-res graphics mode).
* The addresses 0x10 - 0x1F are used for the background palette (when in text mode).

## Sprite RAM memory map
The Sprite RAM consists of three independent blocks of RAM, all accessible
within the same 16-bit virtual address space:
* Sprite Config RAM contains 128 entries of 4 words in addresses `0x0000` - `0x01FF`.
* Sprite Palette RAM contains 128 entries of 16 words in addresses `0x4000` - `0x47FF`.
* Sprite Bitmap RAM contains 4k entries of 8 words in addresses `0x8000` - `0xFFFF`.

### Sprite Config RAM
The Sprite Config RAM contains the overall configuration of each sprite. The
address within the Sprite RAM memory map of a given sprite is simply
`VGA_SPRITE_CONFIG + 4*sprite_number`.  The four words have the following
interpretation:

```
offset 0 : X position (of top left-most pixel in sprite bitmap)
offset 1 : Y position (of top left-most pixel in sprite bitmap)
offset 2 : Pointer to bitmap. Must be multiple of 0x0008 (the lower order bits are ignored).
offset 3 : Control and Status Register (CSR)
```
The X- and Y-position is the pixel number. A sprite may be moved off the left
(or top) of the screen by setting a negative value (in two's complement) of the
X- and Y-positions. E.g. setting the X position to `0xFFFF` moves the sprite
one pixel left of the screen, so only the rightmost 31 pixels are visible.

The bits in the Control and Status register have the following function:

```
Bit 0 : Resolution. 0 = high-resolution (32x32x4), 1 = low-resolution (16x16x16).
Bit 1 : Depth. 0 = foreground, 1 = background
Bit 2 : Magnify X
Bit 3 : Magnify Y
Bit 4 : Mirror X
Bit 5 : Mirror Y
Bit 6 : Sprite visible? 0 = no, 1 = yes.
```

### Sprite Palette RAM
The Sprite Palette RAM contains the 16-color palette of each sprite. The
address within the Sprite RAM memory map of a given sprite's palette is
simply `VGA_SPRITE_PALETTE + 16*sprite_number`.

Each of the 16 words contains the 15-bit RGB color of the corresponding index.
Bit 15 of each word indicates transparency: If this bit is set the
corresponding color is completely transparent, i.e. invisible.

### Sprite Bitmap RAM
The sprite bitmap information is layed out row-by-row, with bits 15-12 of each
word being part of the left-most pixel.

In high-resolution (32x32x4) mode this means
```
offset   0 : bits 15-12 is pixel (0, 0)
             bits 11-8 is pixel (1, 0)
             etc.
offset   1 : pixels (4, 0) to (7, 0).
etc.
offset   7 : pixels (28, 0) to (31, 0).
offset   8 : pixels (0, 1) to (3, 1).
etc.
offset 255 : pixels (28, 31) to (31, 31).
```

In low-resolution (16x16x16) mode this instead means
```
offset   0 : pixel (0, 0)
offset   1 : pixel (1, 0)
offset  15 : pixel (15, 0)
offset  16 : pixel (0, 1)
etc.
offset 255 : pixel (15, 15)
```

