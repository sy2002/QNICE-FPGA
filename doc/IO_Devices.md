# Detailed description of I/O devices

## Fundamental I/O (switches, TIL, keyboard)

Address | Description
------- | -----------
`FF00`  | 16 binary on-board switches
`FF01`  | TIL display
`FF02`  | Mask register for TIL display
`FF04`  | Status register of USB keyboard
`FF05`  | Data register of USB keyboard

The on-board switches (`FF00`) are used as follows:
* Bit 0 (R/O) : Select STDIN (0 = UART, 1 = Keyboard)
* Bit 1 (R/O) : Select STDOUT (0 = UART, 1 = VGA)
* Bit 2 (R/O) : Enable CPU debug mode
* Bit 3 (R/O) : Select default UART baudrate (0 = 115 kbit/s, 1 = 1 Mbit/s)

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
`FF10`  | Baudrate\_divisor
`FF11`  | Status register
`FF12`  | Rx register
`FF13`  | Tx register

The value written into the `baudrate_divisor` is dependent on the system clock
frequency. The baudrate is calculated from the equation:
```
baudrate = system_clock_speed / baudrate_divisor
```
The `baudrate_divisor` is writeable by software, and upon system reset is set to
default value determined from bit 3 of the switch input, see address `FF00` above.

The `system_clock_speed` is 50 MHz.


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

As VGA is a very capable and thus complex device, the documentation for this
device is in a separate document: [doc/VGA_Features.md](VGA_Features.md)


## HyperRAM

The HyperRAM is specific for the MEGA65 platform

Address | Description
------- | ------------
`FFF0`  | Low word of address
`FFF1`  | High word of address
`FFF2`  | 8-bit data to/from HyperRAM
`FFF3`  | 16-bit data to/from HyperRAM

