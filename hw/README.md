Hardware
========

We created QNICE-FPGA as a portable System-on-a-Chip, so that it should be
possible to synthesize it for any suitably powerful FPGA board.

This folder contains the FPGA vendor specific and board (hardware instance)
specific files necessary to synthesize the QNICE-FPGA bitstream. Currently
we are supporting these vendor/board/toolchain combinations:

* Xilinx: Nexys4 DDR and Nexys A7 using Vivado or ISE
* Xilinx: MEGA65 using Vivado or ISE

Scroll down to the respective section learn more about a particular supported
combinations. And if your hardware is not included here, please read on
at the section "General advise for porting", which is at the very bottom
of this README.md.

The structure of this folder is:

```
<fpga-vendor>/<board (hardware)>/<toolchain (IDE)>
```

Additionally there are hardware specific VHDL files in

```
vhdl/hw/<hardware name>
```

Nexys 4 DDR and Nexys A7
------------------------

![Nexys4_DDR_Img](../doc/github/nexys4ddr.jpg)

Currently, our reference development board is a 
[Nexys 4 DDR](https://store.digilentinc.com/nexys-4-ddr-artix-7-fpga-trainer-board-recommended-for-ece-curriculum/),
which has been retired by Nexys but you can still get it on eBay. As far as
we know, the sucessor
[Nexys A7](https://store.digilentinc.com/nexys-a7-fpga-trainer-board-recommended-for-ece-curriculum/)
is compatible, so we currently assume, that you can use the Nexys 4 DDR
IDE files to also synthesize for the Nexys A7.

### ISE 14.7

We created the original QNICE-FPGA using
[Xilinx' ISE 14.7](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive-ise.html).
The free ISE WebPACK license is sufficient for working with QNICE-FPGA.
Open the project `hw/xilinx/nexys4ddr/ISE/env1.xise` to synthesize using ISE.

### Vivado 2019.2 (or newer)

Vivado is the successor of ISE. Even though ISE can still be downloaded for
free from Xilinx as the time of writing, Vivado is way to go when developing
for Xilinx FPGAs. So we made a port of QNIEC-FPGA to Vivado, which you can
[download here](https://www.xilinx.com/support/download.html); we recommend
to use the "HLx Editions" with the free Vivado WebPACK license.
Open the project `hw/xilinx/nexys4ddr/Vivado/qnice_nexys.xpr`
to synthesize using Vivado.

MEGA65
------

![MEGA65_Img](../doc/github/mega65.jpg)

The MEGA65 is the 21st century realization of the Commodore 65 heritage:
A complete 8-bit computer running around 50x faster than a C64 while
being highly compatible. Go to [mega65.org](https://mega65.org/) to learn
more about it.

The MEGA65 is an open source / open hardware project available
[here on GitHub](https://github.com/MEGA65/). It supports multiple so called
"Cores", which means that you can upload your own hardware to MEGA65's FPGA,
which is a Xilinx Artix-7 in a `xc7a100tfgg484` package.

Hint: ISE or Vivado bitstreams (`.bit` files) need to be converted into
MEGA65 Cores (`.cor` files) by using the `tools/bit2cor` tool.

### ISE 14.7

Use the project `hw/xilinx/MEGA65/ISE/QNICE-MEGA65.xise` to synthesize
for MEGA65 using ISE.

### Vivado 2019.2 (or newer)

Use the project `hw/xilinx/MEGA65/Vivado/MEGA65.xpr` to synthesize for MEGA65
using Vivado.

### TODO how to make a core: use tools/bit2core

... ISE config derived from several xcd commands

### SD Card

The MEGA65 features two SD card slots: One at the rear side of the case and
one at the bottom of the case under a cover.

Currently, QNICE-FPGA only supports the one at the bottom under the cover.

### Using Serial I/O as STDIN/STDOUT

#### Preparing your PC or Mac

* You need to use the `TE-0790` JTAG programmer as described in the chapter
  "Flashing the FPGAs and CPLDs in the MEGA65" of the MEGA65 User's Guide.

* On some operating systems you might need to install FTDI drivers. On a Mac
  it works without additional drivers.

* The MEGA65 will show up as "Digilent USB Device" in your OS and/or terminal
  program.

* Choose "Port 2" of this device and set your terminal program to 115.200 baud,
  8-N-1 (no CTS/RTS). Connect to the MEGA65.

#### Routing QNICE-FPGA's STDIN/STDOUT

Press the `RESTORE` key together with the `1` to toggle STDIN between the
MEGA65 keyboard and the UART. Press `RESTORE` plus `2` to toggle STDOUT
between VGA and the UART.

Caveat: After switching STDIN to another input, you still need to press one
more key on the old input, before the switch to the new input is finally active.

#### Technical Background Info

The initial Nexys 4 DDR version of QNICE-FPGA sports 16 switches, which are
directly linked with the "Switch Register" `0xFF12`
(see also `IO$SWITCH_REG` in the file `dist_kit/sysdef.asm`). The rightmost
switch is Bit #0.

|Switch Register| Value | Meaning                 |
|-------------- |-------|-------------------------|
|Bit #0         | 0     |STDIN  = UART            |
|Bit #0         | 1     |STDIN  = MEGA65 keyboard |
|Bit #1         | 0     |STDOUT = UART            |
|Bit #1         | 1     |STDOUT = MEGA65 VGA out  |

The above mentioned `RESTORE` key combinations are toggling the bits #0 and #1
of the Switch Register.

### Porting Notes

* The VDAC which generates the VGA image needs to be wired like this
  ```
  vdac_sync_n <= '0';
  vdac_blank_n <= '1';  
  ```

* The MEGA65 keyboard driver components `mega65kbd_to_matrix` (hardware driver)
  and `matrix_to_ascii` (ASCII generator) both need a counter signal as
  input: `matrix_col_idx`. This signal needs to count upwards on the rising
  edge of the same clock as all the components use from 0 to 7 and then
  flip back to 0 again.

General advise for porting
--------------------------

* In general, the code that is written in a portable way and therefore is
  suitable as a good starting point for porting is the QNICE-FPGA
  implementation for Digilent's Xilinx Virtex-7 based board
  "Nexys4 DDR": Create two new folders according to the folder
  structure mentioned above. Copy this top file into your own folder:
  `vhdl/hw/nexys4ddr/env1.vhd`. You might want to rename it to match your
  hardware's or port's name. Start modifying this top file to fit your needs.

* If you are not on Xilinx hardware, then the first thing you might want to do
  is to comment out everything related to the Xilinx `MMCME` based generation
  of the 25.175 MHz VGA pixelclock in `env1.vhd`. Even though the 25.175 MHz
  pixelclock generates a better and sharper image on most displays, the 25 MHz
  version is also absolutely OK and it is more portable, as it only relies on
  a simple clock divider to generate the pixelclock. So you might want to
  comment out the `UNISIM` library and the `MMCME` instantiation that
  generates the signal `clk25MHz` and comment in the clock divider process
  `generate_clk25MHz : process(SLOW_CLOCK)` instead. Do not forget to
  set appropriate time constraints for the clock in the IDE or development
  environment of your choice; `TS_clk25MHz` in `env1.ucf` might be an
  inspiration.

* In the file `hw/xilinx/nexys4ddr/ISE/env1.ucf` you will find advise 
  about how to do the mapping from the NETs to the hardware's pins and what
  kind of timing constraints you might want to use.

* Make sure that you connect at least the IO pins for PS2, VGA, UART 
  and the two switches (`SWITCHES<0>` and `SWITCHES<1>`).

* The system is designed to run at 50 MHz. Other speeds would break various
  timings (see also [TODO.txt](../TODO.txt) to learn more). `env1` expects to
  receive a 100 MHz clock, which it then divides down to the
  50 MHz clock `SLOW_CLOCK`.

* EAE's combinatorial division networks take longer than the regular 50 MHz 
  clock period, so be sure to specify a timing constraint for your specific
  hardware/toolchain combination. `hw/xilinx/nexys4ddr/ISE/env1.ucf` can be
  used as an inspiration.

* `env1_globals.vhd` contains several important global constants. You can for
  example define the content of the ROM there by changing `ROM_FILE` and
  `ROM_SIZE`. One application for this is to transform QNICE-FPGA into a
  "Q-TRIS Arcade Machine" by using `demos/q-tris.rom` compiled with the define
  `QTRIS_STANDALONE`. Another one might be to replace the "operating system"
  that we call "Monitor" (`monitor/monitor.rom`) by something else.
  You can also use `env1_globals.vhd` to reduce the amount of registers
  (the size of the register file) by changing `SHADOW_REGFILE_SIZE`. But be
  aware that some QNICE programs may fail as the QNICE ISA demands the 
  amount of shadow registers to be 256.

