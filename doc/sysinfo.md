SYSINFO
=======

SYSINFO is a mechanism that is meant to increase portability by allowing a
unified way of querying the capabilities of the current platform.

Currently, the QNICE runs on several very different platforms:

* Nexys 4 DDR FPGA board
* MEGA65 retro computer
* Console emulator
* Web based emulator
* ... and several more

These different platforms have very different capabilities e.g. in
the peripherals supported, the resources allocated, etc.

The advantage of SYSINFO is that an application program for the QNICE
has a central location to query the platform in order to make the most of it.

Test program `sysinfo.c`
-----------------------

In the folder `c/test_programs` there is a C-program `sysinfo.c`.  This will
query the SYSINFO database and print to stdout in human readable format.

For example, running on the console emulator the test program gives the following output:

```
Hardware platform:  Emulator (no VGA)
CPU speed:          50 MHz
CPU register banks: 256
RAM start address:  0x8000
RAM size:           32 kw
GPU sprites:        0
GPU screen lines:   0
UART max baudrate:  0 kb/s
QNICE version:      1.7
MMU present:        No
EAE present:        Yes
FPU present:        No
GPU present:        No
Keyboard present:   No
```

Register Map
---

To query the SYSINFO the user must write the parameter address to address
0xFFE8 and then read the parameter value from address 0xFFE9.  This indirect
addressing scheme is used to allow for future extensions to the SYSINFO
database.


SYSINFO registers
---

| address | description                      |
| ------- | -------------------------------- |
|  0x0000 | Hardware platform enumeration    |
|  0x0001 | Main clock frequency (in MHz)    |
|  0x0002 | Number of register banks         |
|  0x0003 | Start address of RAM             |
|  0x0004 | Amount of RAM (in kilo-words)    |
|  0x0005 | Number of sprites supported      |
|  0x0006 | Number of lines in screen buffer |
|  0x0007 | Maximum baudrate (in kb/s)       |
|  0x0008 | QNICE version                    |
|  0x0100 | Nonzero if built-in MMU present  |
|  0x0101 | Nonzero if built-in EAE present  |
|  0x0102 | Nonzero if built-in FPU present  |
|  0x0103 | Nonzero if built-in GPU present  |
|  0x0104 | Nonzero if keyboard present      |

Hardware platform enumeration
---

The basic idea is: There is a generic info that it is e.g. a Digilent Nexys board,
so that software that is supposed to run on all Nexys boards does not need to check
for 0x0011 and 0x0012 but only for 0x001\*. The same for the MEGA65. Same for
emulator: If you check for 0x000\* then you know you're on the emulator.

|  value | platform                 |
| ------ | ------------------------ |
| 0x0000 | Enumator (no VGA)        |
| 0x0001 | Enumator with VGA        |
| 0x0002 | Enumator on Web Assembly |
| 0x0010 | Digilent Nexys board     |
| 0x0011 | Digilent Nexys 4 DDR     |
| 0x0012 | Digilent Nexys A7-100T   |
| 0x0020 | MEGA65 board             |
| 0x0021 | MEGA65 Revision 2        |
| 0x0022 | MEGA65 Revision 3        |
| 0x0030 | DE10 Nano board          |

QNICE version
-------------

The QNICE version is formatted as follows:
* Bits 15-8 : Major version
* Bits 7-4  : Minor version
* Bits 3-0  : Revision
