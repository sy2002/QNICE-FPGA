# Detailed description of I/O devices

## Fundamental I/O (switches, TIL, keyboard)

Address | Description
------- | -----------
`FF00`  | 16 binary on-board switches
`FF01`  | TIL display
`FF02`  | Mask register for TIL display
`FF04`  | Status register of USB keyboard
`FF05`  | Data register of USB keyboard

The Status register (`FF04`) is decoded as follows
* Bit 0 (R/O) : New ASCII character available for reading
* Bit 1 (R/O) : New Special Key available for reading
* Bits 2-4 (R/W) : Locale (0 = US, 1 = DE)
* Bits 5-7 (R/O) : Modifiers (5 = shift, 6 = alt, 7 = ctrl)


## System Counters
The QNICE supports two different 48-bit counters: A clock cycle counter,
running at the CPU clock frequency, and an instruction counter that increments
once for every new instruction. Each counter can be started, stopped, and
reset.


### Clock cycle counter
Address | Description
------- | -----------
`FF08`  | low word of 48-bit cycle counter
`FF09`  | middle word of 48-bit cycle counter
`FF0A`  | high word of 48-bit cycle counter
`FF0B`  | Status register

The Status register (`FF0B`) is decoded as follows
* Bit 0 (W/O) : Reset to zero and start cycle counting
* Bit 1 (R/W) : Start/stop cycle counter

### Instruction counter
Address | Description
------- | ------------
`FF0C`  | Low word of 48-bit instruction counter
`FF0D`  | Middle word of 48-bit instruction counter
`FF0E`  | High word of 48-bit instruction counter
`FF0F`  | Status register

The Status register (`FF0F`) is decoded as follows
* Bit 0 (W/O) : Reset to zero and start instruction counting
* Bit 1 (R/W) : Start/stop instruction counter


## UART
The QNICE has a simple onboard UART controller, compatible with a 16550.

Address | Description
------- | ------------
`FF11`  | Status register
`FF12`  | Rx register
`FF13`  | Tx register


## EAE
The QNICE has a built-in hardware acceleration of arithmetic.

Address | Description
------- | ------------
`FF18`  | Operand 0
`FF19`  | Operand 1
`FF1A`  | Low word of 32-bit result (or quotient)
`FF1B`  | High word of 32-bit result (or modulo)
`FF1C`  | Command and Status Register (CSR)

The Command and Status Register is decoded as follows
* 0x0000 : 32-bit unsigned multiplication
* 0x0001 : 32-bit signed multiplication
* 0x0002 : 32-bit unsigned division
* 0x0003 : 32-bit signed division
* Bit 15 (R/O) is set when busy.


## SD Card

Address | Description
------- | ------------
`FF20`  | Low word of 32-bit linear block address (LBA)
`FF21`  | High word of 32-bit linear block address (LBA)
`FF22`  | Offset within the 512-byte data buffer
`FF23`  | Read/Write 1 byte from/to the 512-byte data buffer
`FF24`  | (R/O) Error code of last operation
`FF25`  | Command and Status Register (CSR)

The Command and Status Register is decoded as follows
* 0x0000 : Reset SD card
* 0x0001 : Read 512 bytes from LBA
* 0x0002 : Write 512 bytes to LBA
* Bits 13-12 (R/O) : Card Type (0 = none, 1 = SD V1, 2 = SD V2, 3 = SDHC)
* Bit 14 (R/O) : Error
* Bit 15 (R/O) : Busy


## Timers

The QNICE has two built-in hardware timers, each capable of generating interrupts.
Each timer is controller by three registers.

Address | Description
------- | ------------
`FF28`  | Timer 0 Prescaler (from 100 kHz)
`FF29`  | Timer 0 Counter
`FF2A`  | Timer 0 Interrupt Address
`FF2B`  | Timer 1 Prescaler (from 100 kHz)
`FF2C`  | Timer 1 Counter
`FF2D`  | Timer 1 Interrupt Address


## VGA

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


## HyperRAM

The HyperRAM is specific for the MEGA65 platform

Address | Description
------- | ------------
`FFF0`  | Low word of address
`FFF1`  | High word of address
`FFF2`  | 8-bit data to/from HyperRAM
`FFF3`  | 16-bit data to/from HyperRAM

