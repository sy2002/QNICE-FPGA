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
2. Learn about [constraints](constraints.md): What kind of SD card types can
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
* [Constraints](constraints.md)
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
* [MEGA 65 Specifics](../hw/README.md#specifics-of-the-mega65-hardware)
* [Memory map](../README.md#memory-map)
* [Monitor as QNICE-FPGA operating system (OS)](monitor-os.md)
* [Monitor functions](monitor/doc.pdf)
* [Mounting FAT32 devices in the emulator (how-to)](emumount.txt)
* [Nexys 4 DDR Hardware](../hw/README.md#nexys-4-ddr-and-nexys-a7)
* [Nexys 4 DDR Specifics](../hw/README.md#specifics-of-the-nexys-4-ddr-and-nexys-a7-hardware)
* [Nexys A7 Hardware](../hw/README.md#nexys-4-ddr-and-nexys-a7)
* [Nexys A7 Specifics](../hw/README.md#specifics-of-the-nexys-4-ddr-and-nexys-a7-hardware)
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
* [VBCC how-to update](vbcc.md#updating-to-newer-compiler-versions)
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
   connect to QNICE-FPGA via your terminal program using the settings `115,200
   baud, 8-N-1, RTS/CTS ON`. Note that on some Linux machines the terminal
   program `picocom` is buggy. See [constraints.md](constraints.md) for more
   details and a work-around.
   Use the keystrokes `M` and then `L` to enter Monitor's "Memory/Load" mode.
   Copy/Paste the content of the `.out` file that you want to transfer into the
   terminal window of your host computer.  Press `CTRL+E` when done to return
   to the Monitor. Hint: The script `assembler/asm` automatically copies the
   `.out` file to the clipboard: On macOS using `pbcopy` and on Linux using
   `xclip` (if available).

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

