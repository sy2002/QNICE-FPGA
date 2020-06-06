QNICE-FPGA: Overview
====================

As an intro, mention the hardware that QNICE-FPGA is able to run on with
some nice pictures.

Also mention the emulator and link to it.

Explain folder structure in main folder and also here in the doc folder.

Explain what the Monitor is (operating system)

Data transfer via SD Card and via a serial connection (link to the
description in the getting started section and point out to the qtransfer
system as an alternative)

Explain how you can route STDIN/STDOUT using the switch register, which can
be implemented differently on different hardware: Nexys4 DDR/Nexys A7:
physical switches. MEGA65: RESTORE key combinations. As soon as done:
update @TODO in README.md in hw folder to link here.

Folder Structure
----------------

### QNICE-FPGA Root Folder

| Folder name   | Description
|---------------|------------------------------------------------------------
| assembler     | Native QNICE assembler: Main file is `qasm.c`. You usually call it via the script `asm`, which utilizes the C preprocessor.
| c             | C programming environment based on the vbcc compiler system. You need to activate `setenv.source` (e.g. via `source`) to use it. The subfolder `test_programs` contains experiments and demos written in C.
| demos         | QNICE demos written in assembler. Most noteworthy is `q-tris.asm`.
| dist_kit      | Distribution Kit: Contains standard include files for assembler and C as well as ready-made bitstreams and MEGA Core files
| doc           | Documentation: See explanation of file and folder structure below.
| emulator      | Emulator: Learn more via [emulator/README.md](../emulator/README.md)
| hw            |
| monitor       |
| pore          |
| qbin          |
| test_programs |
| tools         |
| vhdl          |

MEGA65
------

Add an image, some intro text, some basics, ... sort the following unsorted
paragraphs. Explain how to connect to a computer, if you want serial, ...

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

### TODO how to make a core: use tools/bit2core

... ISE config derived from several xcd commands

### HyperRAM

How to access. Special test programs, ...

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

* Choose "Port 2" of this device and set your terminal program to 115.200
  baud, 8-N-1 (no CTS/RTS). Connect to the MEGA65.

#### Routing QNICE-FPGA's STDIN/STDOUT

Press the `RESTORE` key together with the `1` to toggle STDIN between the
MEGA65 keyboard and the UART. Press `RESTORE` plus `2` to toggle STDOUT
between VGA and the UART.

Caveat: After switching STDIN to another input, you still need to press one
more key on the old input, before the switch to the new input is finally
active.

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

### VHDL Development for the MEGA65

Some hints, learnings: "Digitlent Device", how to map VGA port so that
they work, ...

