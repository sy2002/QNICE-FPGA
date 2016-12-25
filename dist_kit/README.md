The *dist_kit* folder
=====================

* This is the distribution kit of QNICE.

* For those of you having a Nexys 4 DDR board, the most important file here
  is the FPGA bitstream file having the .bit file extension. It contains the
  QNICE FPGA hardware plus the Monitor ROM. Copy it on a microSD card
  or a USB stick, set the jumpers on your board correctly and you can boot
  up QNICE-FPGA.

* The other files are needed for doing QNICE software development, as they
  contain important register definitions, common constants and command
  shortcuts.

* Native QNICE assembler:

  * sysdef.asm: Command shortcuts (RET, INCRB, DECRB, NOP, SYSCALL), register
    short names (PC, SR, SP), addresses for memory mapped I/O of peripheral
    devices, commonly used constants.

  * monitor.def: Addresses of operating system routines that can be used in
    SYSCALLs.

* VASM:

  * sysdef.vasm: Addresses for memory mapped I/O, commonly usd constants.

  * qnice-conv.vasm: Convenience macros aka command shortcuts (RET, INCRB,
    DECRB, NOP, SYSCALL).

  * monitor.vdef: Addresses of operating system routines that can be used
    in SYSCALLs.

* C:

  * sysdef.h: Addresses for memory mapped I/O, commonly used constants.

  * qmon-ep.h Addresses of operating system routines. Since they sometimes
    have other call semantics than the C-QMON ABI, you should normally not
    use qmon-ep.h directly, but use the Standard C Library instead.
    If you need to use the monitor library functions directly, then preferably
    use the wrappers in c/qnice/monitor-lib/include/qmon.h
