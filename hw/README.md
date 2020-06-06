Hardware
========

We created QNICE-FPGA as a portable System-on-a-Chip, so that it should be
possible to synthesize it for any suitably powerful FPGA board.

This folder contains the FPGA vendor specific and board (hardware instance)
specific files necessary to synthesize the QNICE-FPGA bitstream. Currently
we are supporting these vendor/board/toolchain combinations:

* Xilinx: **Nexys4 DDR** and **Nexys A7** using Vivado or ISE
* Xilinx: **MEGA65** using Vivado or ISE

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

The top file for this platform is [env1.vhd](../vhdl/hw/nexys4ddr/env1.vhd).

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
MEGA65 Cores (`.cor` files) by using the `tools/bit2core` tool. The bitstream
needs to be in a specific format as described [here](../tools/bit2core.c#L16)
to work as a Core on the MEGA65.

### ISE 14.7

Use the project `hw/xilinx/MEGA65/ISE/QNICE-MEGA65.xise` to synthesize
for MEGA65 using ISE. The bitstream format is already configured to be
compatible with MEGA65 Cores. Right-click "Generate Programming File" in 
ISE's process view and choose "Process Properties" to learn more.

The top file for MEGA65 using ISE is
[MEGA65_ISE.vhd](../vhdl/hw/MEGA65/MEGA65_ISE.vhd). For some reason ISE is
not able to synthesize the design using a Xilinx specific MMCME clock
generator for generating the 50 MHz `SLOW_CLOCK`. So we use a simple
clock divider. This is the only difference between the ISE and the Vivado
version of the top file.

### Vivado 2019.2 (or newer)

Use the project `hw/xilinx/MEGA65/Vivado/MEGA65.xpr` to synthesize for MEGA65
using Vivado. The bitstream format is already configured to be compatible
with MEGA65 Cores. Look at the
[XDC file](../hw/xilinx/MEGA65/Vivado/mega65.xdc), section
"## Configuration and Bitstream properties" to learn more.

The top file for MEGA65 using Vivado is
[MEGA65_Vivado.vhd](../vhdl/hw/MEGA65/MEGA65_Vivado.vhd).

### Porting Notes

* In contrast to the Nexys board, where we use bit banging to generate the
  VGA signal, the MEGA65 possesses a VDAC. You need to set the following
  signals, otherwise the screen will remain blank:
  ```
  vdac_sync_n <= '0';
  vdac_blank_n <= '1';
  ```
* The MEGA65 keyboard is accessed via a smart controller which is implemented
  on a CPLD. Additionally, the MEGA65 supports 8MB of HyperRAM by default.
  Both components are accessed using specific Core-FPGA pins and we are
  reusing original MEGA65 VHDL to implement the necessary
  hardware driver components. Go to the
  [README.md in vhdl/hw/MEGA65/drivers](../vhdl/hw/MEGA65/drivers/README.md)
  to learn more.

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

