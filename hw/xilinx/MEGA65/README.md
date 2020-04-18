QNICE-FPGA on the MEGA65
========================

Using Serial I/O as STDIN/STDOUT
--------------------------------

### Preparing your PC or Mac

* You need to use the `TE-0790` JTAG programmer as described in the chapter
  "Flashing the FPGAs and CPLDs in the MEGA65" of the MEGA65 User's Guide.

* On some operating systems you might need to install FTDI drivers. On a Mac
  it works without additional drivers.

* The MEGA65 will show up as "Digilent USB Device" in your OS and/or terminal
  program.

* Choose "Port 2" of this device and set your terminal program to 115.200 baud,
  8-N-1 (no CTS/RTS). Connect to the MEGA65.

### Routing QNICE-FPGA's STDIN/STDOUT

Press the `RESTORE` key together with the `1` to toggle STDIN between the
MEGA65 keyboard and the UART. Press `RESTORE` plus `2` to toggle STDOUT
between VGA and the UART.

### Technical Background Info

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

Porting Notes
-------------

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
