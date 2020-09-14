QNICE-FPGA Documentation
========================

Quickstart
----------

Follow this path in exactly this order is the fastest, most convenient and
didactically most reasonable way to get started with QNICE-FPGA.

### Step 1: Work through the following sections of the main README.md:

1. [Getting Started](../README.md#getting-started)
2. [Using the File System](../README.md#using-the-file-system)
3. [Q-TRIS](../README.md#q-tris)
4. [Memory map](../README.md#memory-map)
5. [I/O devices](../README.md#io-devices)
6. [Programming in Assembler](../README.md#programming-in-assembler)
7. [Programming in C](../README.md#programming-in-c)

### Step 2: Read the following background information:

1. [QNICE Instruction Set Architecture](intro/qnice_intro.pdf)
2. Learn about [constraints](constraints.txt): What kind of SD card types can
   you use? Which USB keyboards are known to work? What do you need to
   consider, when choosing a serial terminal program? What C features are
   not working, yet?
3. [Programming Best Practices](best-practices.md)

Full documentation in alphabetical order
----------------------------------------

* [Assembler (how-to)](../README.md#programming-in-assembler)
* [Assembler programming best practiecs](best-practices.md#native-qnice-assembler)
* [Basics](#basics)
* [C (how-to)](../README.md#programming-in-c)
* [C programming best practices](best-practices.md#c)
* [C specifics](vbcc.md)
* [Constraints](constraints.txt)
* [Contributing (how-to)](../CONTRIBUTING.md)
* [Contributing (ideas)](../TODO.txt)
* [CPU debug mode](#switch-register-bit-2-cpu-debug-mode)
* [CPU speed in MIPS](MIPS.md)
* [Distribution kit](../dist_kit/README.md)
* [Emulator](../emulator/README.md)
* [FAT 32 disk images (how-to)](emumount.txt)
* [File System (how-to)](../README.md#using-the-file-system)
* [Folder structure explained](folders.md)
* [Getting Started](../README.md#getting-started)
* [Interrupt capable devices (requirements & how-to)](int-device.md)
* [Instruction Set Architecture (ISA)](intro/qnice_intro.pdf)
* [I/O devices](../README.md#io-devices)
* [Hardware platforms](../hw/README.md)
* [License](../LICENSE.md)
* [MEGA 65 Drivers](../vhdl/hw/MEGA65/README.md)
* [MEGA 65 Hardware](../hw/README.md#mega65)
* [MEGA 65 Specifics](#specifics-of-the-mega65-hardware)
* [Memory map](../README.md#memory-map)
* [Monitor as QNICE-FPGA operating system (OS)](monitor-os.md)
* [Monitor functions](monitor/doc.pdf)
* [Mounting FAT32 devices in the emulator (how-to)](emumount.txt)
* [Nexys 4 DDR Hardware](../hw/README.md#nexys-4-ddr-and-nexys-a7)
* [Nexys 4 DDR Specifics](#specifics-of-the-nexys-4-ddr-and-nexys-a7-hardware)
* [Nexys A7 Hardware](../hw/README.md#nexys-4-ddr-and-nexys-a7)
* [Nexys A7 Specifics](#specifics-of-the-nexys-4-ddr-and-nexys-a7-hardware)
* [Programming Best Practices](best-practices.md)
* [Programming Card](programming_card/programming_card_screen.pdf)
* [Q-TRIS](../README.md#q-tris)
* [Releasing (how-to)](how-to-release.md)
* [Revision history](../VERSIONS.txt)
* [Software requirements](requirements.txt)
* [STDIN/STDOUT](#details-on-the-switch-register-that-controls-stdinstdout)
* [Transferring software to QNICE-FPGA](#transferring-software-to-qnice-fpga)
* [Website (how-to update)](how-to-release.md#step-7-update-the-website-qnice-fpgacom)
* [Website via GitHub Pages](https://github.com/sy2002/QNICE-FPGA/blob/gh-pages/README.md)
* [Version history](../VERSIONS.txt)
* [VGA architecture](../vhdl/vga/README.md)
* [VGA display calibration](#calibrating-your-vga-monitor)
* [VGA features and registers](VGA_Features.md)
* [VGA fonts (how-to make own)](../vhdl/vga/font-howto.txt)

Basics
------

* Background info on the QNICE architecture and ISA can be found
  [here](http://qnice.sourceforge.net/). There is also an
  [introductory presentation](intro/qnice_intro.pdf) available.

* It makes sense to walk through the whole main [README.md](../README.md)
  of the repository including the "Getting Started" section, before reading
  on here.

* If you want to get started on a specific hardware that QNICE-FPGA supports
  or learn more about porting, then have a look at
  [hw/README.md](../hw/README.md).

* The "Monitor" is QNICE-FPGA's operating system. It provides the user
  interface as well as library functions that can be used by Assembler and C
  programs. Have a look at the various examples in the folder `test_programs`
  to learn more about how to use library functions in your own programs using
  the `SYSCALL` macro. [hello.asm](../test_programs/hello.asm) might be a good
  starting point. [dist_kit/monitor.def](../dist_kit/monitor.def) contains
  the call table to all available library functions and
  [here is a PDF file](monitor/doc.pdf) that contains a brief documentation of
  the Monitor's library functions.

* QNICE-FPGA uses Memory Mapped I/O (MMIO) to communicate with all hardware
  components. [dist_kit/sysdef.asm](../dist_kit/sysdef.asm) contains the
  MMIO addresses of the hardware registers as well as constant definitions
  for convenient access.

* QNICE-FPGA supports the concept of routable STDIN and STDOUT. All Monitor I/O
  functions as well as the C runtime are written to support this. Currently,
  serial in and keyboards are supported for STDIN and serial out and
  VGA are supported for STDOUT. Currently, STDIN and STDOUT can be only routed
  using hardware mechanisms such as switches and key combinations; you cannot
  route them using software.

### Details on the "Switch Register" that controls STDIN/STDOUT

The initial Nexys 4 DDR version of QNICE-FPGA supports 16 switches that are
directly linked with the "Switch Register" `0xFF00`
(see also `IO$SWITCH_REG` in the file `dist_kit/sysdef.asm`). The rightmost
switch is Bit #0.

|Switch Register| Value | Meaning                 |
|-------------- |-------|-------------------------|
|Bit #0         | 0     |STDIN  = UART            |
|Bit #0         | 1     |STDIN  = Keyboard        |
|Bit #1         | 0     |STDOUT = UART            |
|Bit #1         | 1     |STDOUT = VGA/HDMI out    |

The below-mentioned `RESTORE` key combinations of the MEGA65 are toggling
the bits #0 and #1 of the Switch Register.

### "Switch Register" Bit #2: CPU Debug Mode

On the Nexys 4 DDR board, the third switch (counted from the right) aka `SW2`
triggers bit #2 of the "Switch Register". There is no equivalent of this
key on the MEGA65. If bit #2 is `1`, then the CPU Debug Mode is activated.

When in CPU Debug Mode the 7-segment display of the Nexys 4 DDR board will show the
CPU address (program counter) when a `HALT` command was executed. This
is very valuable when running a CPU test such as `test_programs/cpu_test.asm`.

Transferring software to QNICE-FPGA
-----------------------------------

When cross-compiling software for the QNICE-FPGA, there are three ways to
transfer it:

1. Put the `.out` file on a SD Card and load it using the Monitor's
   "File/Run" command: Press `F` and `R` and enter the file name or the
   full path including the file name of the `.out` file.

2. Use the Monitor's "Memory/Load" command: Route STDIN to serial in and
   connect to QNICE-FPGA via your terminal program (see hardware specific
   serial settings below). Use the keystrokes `M` and then `L` to enter
   Monitor's "Memory/Load" mode. Copy/Paste the content of the `.out` file
   that you want to transfer into the terminal window of your host computer.
   Press `CTRL+E` when done to return to the Monitor. Hint: The script
   `assembler/asm` automatically copies the `.out` file to the clipboard:
   On macOS using `pbcopy` and on Linux using `xclip` (if available).

3. Use `tools/qtransfer`: Open the qtransfer client on QNICE-FPGA by
   entering the Monitor commands `M` `Q`. On the host computer, run
   `tools/qtransfer` to send the data. `qtransfer` checks the data integrity
   using CRC16, so you should prefer it over the `M` `L` method described
   in step (2). It is also more convenient for VGA/keyboard users, because
   you do not need to switch STDIN back to serial for transferring data.

Calibrating your VGA monitor
----------------------------

For making sure that the whole QNICE-FPGA screen is actually visible on your
VGA monitor, make sure to calibrate your monitor following these steps:

1. Run `qbin/vga_calibration.out` either directly from your SD Card or by using
   the software transfer mechanisms described above.

2. The program is drawing a frame that consists of "X" characters, as this is
   the widest and highest char. The frame ranges from the lowest (x|y)
   coordinates to the highest ones. If you cannot see the full frame, either
   run your monitor's auto-calibration or calibrate manually.

The source code of the tool is in
[c/test_programs/vga_calibration.c](../c/test_programs/vga_calibration.c).

Specifics of the Nexys 4 DDR and Nexys A7 hardware
--------------------------------------------------

* The CPU Reset button works as expected.

* STDIN: You can use serial in or an USB keyboard. Use the rightmost switch
  `SW0` to toggle: `off` equals serial in and `on` means keyboard. Have a look
  at [constraints.txt](constraints.txt) to learn which keyboards are working.
  When switching between one STDIN to another STDIN you need to press a key
  one more time on the "old" STDIN after you switch, before the new STDIN
  starts working.

* STDOUT: You can use serial out or a VGA monitor. Use the second switch
  counted from right `SW1` to toggle: `off` equals serial out and `on` means
  VGA.

* Serial communication: `115,200 baud, 8-N-1, RTS/CTS ON`

* Debug mode: If switch `SW2` is on, then the value of the CPU's address lines
  is shown in real-time on the 7-segment-display. This means, that on `HALT`
  you will see the program counter (PC) of the `HALT` command.

* The SD Card slot is supported. Use FAT32 formatted cards and have a look at
  [constraints.txt](constraints.txt) to learn which SD Cards are working.
  Use the Monitor's `F` command group to access the SD Card, e.g. use
  `F` and then `D` to show the contents of the current directory.

* Not used/supported: Pushbuttons other than the CPU Reset button; ethernet
  connector; Pmod connectors; audio out

Specifics of the MEGA65 hardware
--------------------------------

### SD Card

The MEGA65 features two SD card slots: One at the rear side of the case and
one at the bottom of the case under a cover.

Currently, QNICE-FPGA only supports the one at the bottom under the cover.

### Installing the QNICE core on MEGA65

1. Copy the [QNICE @ MEGA65 core](../dist_kit/@TODO) onto a FAT32 formatted
   SD Card.

2. Power-on the MEGA65 while you hold the `No Scroll` key.

3. Choose an empty slot using `CTRL` plus the number of the empty slot.

4. Choose a `.cor` file from your SD Card using the arrow keys and `Return`.

5. The MEGA65 is storing the core in non-volatile memory so that from now on,
   you can directly boot the core.

### Booting the QNICE core

1. Power-on the MEGA65 while you hold the `No Scroll` key.

2. Choose the QNICE core with the arrow keys or by pressing it's number

### Creating your own `.cor` file

ISE or Vivado bitstreams (`.bit` files) need to be converted into
MEGA65 Cores (`.cor` files) by using the `tools/bit2core` tool. The bitstream
needs to be in a specific format as described [here](../tools/bit2core.c#L16)
to work as a Core on the MEGA65.

### Board and hardware revisions

For the QNICE @ MEGA65 release at hand, we used the very first MEGA65
prototype computer, which has the board revision 2 (MEGA65R2). There where
only a couple of those prototypes produced, so you will probably have a newer
board revision: The first publicly available MEGA65 computer will be the
[MEGA65 DevKit](https://shop.trenz-electronic.de/en/30390-MEGA65-Development-Kit-highly-advanced-C64-and-C65-compatible-8-bit-computer)
with board revision 3 (MEGA65R3). And the final product for the market might
have an even higher board revision.

| Hardware  | Release     | Board | Description
|-----------|-------------|-------|-------------------------------------------
| Prototype | 2019        | R2    | First MEGA65 prototype that actually looks like a MEGA65. It uses the combination of an ADV7511 chip and a TPD12S016 companion chip to produce HDMI output.
| DevKit    | 2020 (*)    | R3    | Development computer; for the first time for a broader audience. Acrylic case. At the time of writing this, we learned from the MEGA team they might drop the ADV7511.
| MEGA65 V1 | 2021/22 (*) | ?     | First release to the public

(*) means: "estimated"

Currently, we only fully support the MEGA65R2 board. That means that HDMI
output only works there. On other boards, this release (even the binary `.cor`
file) should work out-of-the-box, too. But it will only generate VGA output
and no HDMI output.

### HDMI

MEGA65 supports HDMI output. The hardware in theory is capable of displaying
different things on the VGA and HDMI output (e.g. dual-screen). For making
things simple, we are just mirroring the 640x480 @ 60 Hz VGA output on HDMI.
Just plug in your HDMI monitor and it should work. The HDMI output is
naturally much clearer and sharper than the VGA output.

For fine-tuning the HDMI output on your monitor, you can use the registers
`VGA$HDMI_H_MIN`, `VGA$HDMI_H_MAX` and `VGA$HDMI_V_MAX`. There is a test
program available where you can interactively play with these registers:
[c/test_programs/hdmi_de.c](../c/test_programs/hdmi_de.c).

### HyperRAM

MEGA65 comes with 8MB of HyperRAM which extends the 32 kWords of free RAM
that QNICE-FPGA has built-in by default. Optionally, another 8MB can be added.
We only tested and worked with the built-in 8MB of the MEGA65, but
theoretically, the system should also be able to work with 16MB.

HyperRAM is slower than the built-in RAM and QNICE-FPGA currently does not
have a memory controller, paging, DMA or similar mechanism implemented, yet.
Therefore HyperRAM can only be accessed via registers: 
`IO$M65HRAM_LO`, `IO$M65HRAM_HI`, `IO$M65HRAM_DATA8` and `IO$M65HRAM_DATA16`.

Have a look at
[test_programs/MEGA65/hyperram.asm](../test_programs/MEGA65/hyperram.asm)
and at
[c/test_programs/hyperramtest.c](../c/test_programs/hyperramtest.c)
to learn more. There is also a work-in-progress demo that is meant to load
a large ASCII animation ("video clip") into HyperRAM and then display it
on the screen:
[c/test_programs/the-matrix.c](../c/test_programs/the-matrix.c)

### Keys

| Key Combination | Meaning                                |
|-----------------|----------------------------------------|
| RESTORE + 1     | Toggle STDIN: MEGA65 keyboard and UART |
| RESTORE + 2     | Toggle STDOUT: MEGA65 VGA and UART     |
| MEGA + UP       | Page Up                                |
| MEGA + DOWN     | Page Down                              |
| MEGA + LEFT     | POS1                                   |
| MEGA + RIGHT    | END                                    |
| MEGA + *        | ^ (power symbol)                       |
| MEGA + 0        | ° (degree symbol)                      |
| MEGA + e        | € (Euro symbol)                        |
| MEGA + a        | German Umlaut ä (+SHIFT: Ä)            |
| MEGA + o        | German Umlaut ö (+SHIFT: Ö)            |
| MEGA + u        | German Umlaut ü (+SHIFT: Ü)            |
| MEGA + s        | German Umlaut ß                        |

### Using Serial I/O as STDIN/STDOUT

The MEGA65 does not come with a serial interface by default. The DevKit
version is supposed to have the JTAG programmer (see description below)
built-in. For other versions you need to purchase and install the programmer.

#### Preparing your PC or Mac

* You need to use the `TE-0790` JTAG programmer as described in the chapter
  "Flashing the FPGAs and CPLDs in the MEGA65" of the
  [MEGA65 User's Guide](https://github.com/MEGA65/mega65-user-guide/blob/master/MEGA65-Book_draft.pdf).

* On some operating systems you might need to install FTDI drivers. On a Mac
  it works without additional drivers.

* The MEGA65 will show up as "Digilent USB Device" in your OS and/or terminal
  program.

* Choose "Port 2" of this device and set your terminal program to `115,200
  baud, 8-N-1 (no CTS/RTS)`. Connect to the MEGA65.

#### Routing QNICE-FPGA's STDIN/STDOUT

Press the `RESTORE` key together with the `1` to toggle STDIN between the
MEGA65 keyboard and the UART. Press `RESTORE` plus `2` to toggle STDOUT
between VGA and the UART.

Caveat: After switching STDIN to another input, you still need to press one
more key on the old input, before the switch to the new input is finally
active.

### Creating Core files

The MEGA65 is able to load `.cor` files directly from SD card, so that MEGA65
users do not need a Xilinx toolchain to change the bitstrem ("Core") that they
are running.

Core files can be generated from compatible bitstreams using `tools/bit2core`.
"Compatible" means, that the following settings are used in the Vivado `xdc`
file and/or that these properties are configured in the ISE project within
the IDE.

```
## Configuration and Bitstream properties
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
```
