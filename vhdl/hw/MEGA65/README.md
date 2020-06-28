MEGA65 Hardware Specific Files
==============================

Visit [https://mega65.org/](https://mega65.org/) to learn more about the
MEGA65 project.

This folder contains four types of MEGA65 specific files:

* **Drivers** are low-level hardware modules that have not been written with
  the primary goal of reusability in mind. Instead, they are part of the
  MEGA65 core development and optimized for being used within the MEGA65
  core project. They are located in the subfolder `drivers`.

* **Wrappers** are QNICE-FPGA specific adaptations of the drivers. They make
  sure, that the MEGA65 hardware can be accessed via the MMIO (memory mapped
  IO) model of QNICE. Furthermore, they make sure that QNICE specific
  peculiarities are taken care of.

* **Ports** are files that are part of the regular QNICE-FPGA distribution,
  where the necessity came up to change things specifically for the MEGA65
  hardware.

* **Simulation files** are located in the subfolder `sim` and are additional
  modules necessary to simulate specific situations in Vivado's simulator.
  They are not needed to synthesize a bitstream for real hardware.

MEGA 65 Drivers
---------------

The MEGA65 Hardware Drivers were mainly written by Paul Gardner-Stephen, who
is also co-founder of the MEGA65 project.

The GitHub repository of the MEGA65 Core is here:
[https://github.com/MEGA65/mega65-core](https://github.com/MEGA65/mega65-core).

One file (`i2c_master.vhdl`) has been written by Scott Larson, who
open-sourced the file
[here](https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324).

All the driver files are located in the `drivers` subfolder.

### License

Paul licensed the MEGA65 sources under GNU LESSER GENERAL PUBLIC LICENSE,
Version 3, 29 June 2007.

Scott Larson licensed his I2C bus master using an "provided as-is" freeware
Open Source license.

### Debugtools

Many of Pauls drivers make use of the file `debugtools.vhdl`, which is only
being used during simulation. The synthesizer in ISE and Vivado will remove
everything when creating bitstreams for real hardware.

### Keyboard Driver

The MEGA65 keyboard driver is consisting of the following files:

```
kb_matrix_ram.vhdl
matrix_to_ascii.vhdl
mega65kbd_to_matrix.vhdl
```

I (sy2002) took them on April, 18 2020 from the
[MEGA65 GitHub Core Repo](https://github.com/MEGA65/mega65-core)
using branch `165-hyperram`.
[This link points to the relevant Commit #84e8394](https://github.com/MEGA65/mega65-core/tree/84e8394524814a4ac34e8722211642f0cabdaf31/src/vhdl),
in case you need to get these files from the original source.

#### Modifications

* Added support for the CURSOR LEFT and CURSOR UP keys (they appear like the shifted versions of RIGHT/DOWN)
* Added support for MEGA65 key + CURSOR LEFT/CURSOR UP ($dc/$db)
* The asterisk (*) key is now transmitted without shift
* Shift + asterisk sends $e3
* The British Pound (£) key now works without alt
* Arrow left/shift arrow left are now $ea/$eb
* Arrow up/shift arrow up are now $e0/$e8
* The pi symbol (MEGA65 + arrow up) sends $ec
* MEGA65 + 0 => degree symbol (°)
* Tab stays tab, also under shift, ctrl and alt
* Commented out debugtools and report outputs
* bugfix: did put suppress_key_glitches on sensitivity list of process

Important: Due to the cursor key enhancements, `matrix_col_idx` needs now
to count from 0 to 9 (versus 0 to 8 in the original driver).

### !!! WIP !!! HyperRAM Driver

The MEGA65 HyperRAM driver consists of the file `hyperram.vhdl`.

I took it on June, 6 2020 from the
[MEGA65 GitHub Core Repo](https://github.com/MEGA65/mega65-core)
using branch `165-hyperram`.
[This link points to the relevant Commit #a100863](https://github.com/MEGA65/mega65-core/blob/a100863955f5feb67949f872cbb112d81aa7ce1e/src/vhdl/hyperram.vhdl),
in case you need to get the file from the original source.

#### Modifications

* Made it stand-alone by including the `debugtools` and `cputypes` 
  dependencies into `hyperram.vhdl`: Two new packages at the top of the file:
  `package cache_row_type` and `package `debugtools`.

### HDMI Driver

MEGA65 board revision 2 (MEGA65R2) uses the ADV7511 chip to generate HDMI
output and the TPD12S016 companion chip to protect the ADV7511 from static
and other interferences. While the TPD12S016 is just "switched on" inside
the top file by asserting the pins `ct_hpd` and `ls_oe`, the ADV7511 needs a
pretty sophisticated configuration via its I2C bus.

The HDMI driver files are:

```
hdmi_i2c.vhdl
i2c_master.vhdl
```

I took them on June, 14 2020 from the
[MEGA65 GitHub Core Repo](https://github.com/MEGA65/mega65-core)
using branch `138-hdmi-audio-27mhz`.
[This link points to the relevant Commit #50a9201](https://github.com/MEGA65/mega65-core/tree/50a920187ef547cc89ecaaea0b1ef55dcf69342c/src/vhdl),
in case you need to get these files from the original source.

#### Modifications

* Paul modified Steven's original `i2c_master.vhdl` which was made with and
  for Intel's Quartus design software so that it can be synthesized using
  Xilinx' ISE and Vivado: The `case` statement in lines 85-103 of Steven's
  original file was replaced by the `if` `elsif` statements in Paul's
  file in lines 99-116. Furthermore, Paul added debug output for simulation.

* The ADV7511 chip is configured for 640x480 in `hdmi_i2c.vhdl`. Additionally,
  the sound transmission was de-activated. The array `reg_value_pairs` 
  contains the QNICE-FPGA specific configuration. More information can be
  found in the "ADV7511 Programming Guide" by Analog Devices, which is
  publicly available for download.

MEGA65 Wrappers
---------------

* `hyperram_ctl.vhd` HyperRAM statemachine and MMIO wrapper
* `keyboard.vhd` Keyboard statemachine and MMIO wrapper

MEGA65 Ports
------------

* `MEGA65_ISE.vhd` Top file for synthesizing with ISE
* `MEGA65_Vivado.vhd` Top file for synthesizing with Vivado
* `mmio_mux.vhd` MMIO multiplexer 

### Porting Notes

* In contrast to the Nexys board, where we use bit banging to generate the
  VGA signal, the MEGA65 possesses a VDAC. You need to set the following
  signals, otherwise the screen will remain blank:
  ```
  vdac_sync_n <= '0';
  vdac_blank_n <= '1';
  ```

* For some strange and not yet fully understood reasons, the Vivado bitstream
  had severe problems with a blurry VGA display, while the ISE bitstream
  had not. The solution was to invert the phase of the VDAC clock
  in the Vivado version. Now we have a crisp and clear image in both versions.
  We suspected that Vivado has another BRAM timing, so that the signals were
  not "ready" when the VDAC tried to latch them and now using the phase shift
  we won some time. Maybe this is true, but as of now the whole thing is as
  riddle.

* Board revision MEGA65R2 has two chips for generating the HDMI output signal:
  ADV7511 and TPD12S016. See section "HDMI Driver" above for details. Future
  board revisions might work differently, so we will probably need to adjust
  the MEGA65 port of QNICE-FPGA then.  

* Another difference between the ISE and Vivado version: For some reason ISE
  is not able to synthesize the design using a Xilinx specific MMCME clock
  generator for generating the 50 MHz `SLOW_CLOCK`. So we use a simple
  clock divider in `MEGA65_ISE.vhd` while we use a MMCME clock module in
  `MEGA_Vivado.vhd`.

* The MEGA65 keyboard is accessed via a smart controller which is implemented
  on a CPLD. Additionally, the MEGA65 supports 8MB of HyperRAM by default.
  Both components are accessed using specific Core-FPGA pins and we are
  reusing original MEGA65 VHDL to implement the necessary
  hardware driver components. Go to the
  [README.md in vhdl/hw/MEGA65/drivers](../vhdl/hw/MEGA65/drivers/README.md)
  to learn more.

* The routing of STDIN/STDOUT
  (as described [here](@TODO))
  that is done via the physical switches 0 and 1 on a Nexys board is done
  via special `RESTORE` key combinations
  (as described [here](@TODO)).

MEGA65 Simulation files
-----------------------

### HyperRAM Simulation

The HyperRAM simulation is a testbed and debugging environment for HyperRAM.
It consists of a minimal QNICE-FPGA on MEGA65 simulation: Just the core
computer plus the HyperRAM (no VGA, no UART, no keyboard, etc.). The top file
is `sim_hram_dbg.vhd`. It makes sure, that `sim_hram_dbg.rom` is being loaded,
which is the result of compiling `sim_hram_dbg.asm`. The HyperRAM istself
is simulated using `s27kl0641.vhd`.

The following files are part of the HyperRAM simulation:

```
conversions.vhd
gen_utils.vhd
s27kl0641.vhd
sim_hram_dbg.asm
sim_hram_dbg.vhd
sim_hram_dbg_globals.vhd
sim_hram_mmio_mux.vhd
```

You can start the simulation in the Vivado IDE using `sim_hram` from the
`Simulation Sources` branch in the sources view of the Project Manager.
