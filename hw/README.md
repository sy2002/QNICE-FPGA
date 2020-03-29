Hardware
========

We created QNICE-FPGA as a portable System-on-a-Chip, so that it should be
possible to synthesize it for any suitably powerful FPGA board. This folder
contains the FPGA vendor specific and board (hardware instance) specific files
necessary to synthesize the QNICE-FPGA bitstream.

The structure of this folder is:

```
<fpga-vendor>/<board (hardware)>/<toolchain (IDE)>
```

General advise for porting
--------------------------

* The root file for the system is `vhdl/env1.vhdl`.

* Make sure that you connect at least the IO pins for PS2, VGA, UART 
  and the two switches (`SWITCHES<0>` and `SWITCHES<1>`).

* In the file `hw/xilinx/nexys4ddr/ISE/env1.ucf` you will find advise 
  about how to do the mapping from the NETs to the hardware.

* The system is designed to run at 50 MHz. Other speeds would break various
  timings (see also [TODO.txt](../TODO.txt) to learn more). `env1` expects to
  receive a 100 MHz clock, which it then divides down to the
  50 MHz clock `SLOW_CLOCK`.

* EAE's combinatorial division networks take longer than the regular 50 MHz 
  clock period, so be sure to specify a timing constraint for your specific
  hardware/toolchain combination. `hw/xilinx/nexys4ddr/ISE/env1.ucf` can be
  used as an inspiration.

Nexys 4 DDR and Nexys A7
------------------------

![Nexys4_DDR_Img](../doc/github/nexys4ddr.jpg)

Currently, our reference development board is a 
[Nexys 4 DDR](https://store.digilentinc.com/nexys-4-ddr-artix-7-fpga-trainer-board-recommended-for-ece-curriculum/),
which has been retired by Nexys but you can still get it on eBay. As far as
we know, the sucessor
[Nexys A7](https://store.digilentinc.com/nexys-a7-fpga-trainer-board-recommended-for-ece-curriculum/)
is quite compatible, so we currently assume, that you can use the Nexys 4 DDR
IDE files to also synthesize for the Nexys A7.

### ISE 14.7

We created the original QNICE-FPGA using
[Xilinx' ISE 14.7](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive-ise.html).
Open the project `hw/xilinx/nexys4ddr/ISE/env1.xise` to synthesize using ISE.

### Vivado <Version>

Work in progress ...  `xilinx/nexys4ddr/Vivado`
