# vbcc - portable ISO C compiler

vbcc is a highly optimizing portable and retargetable ISO C compiler. It
supports ISO C according to ISO/IEC 9899:1989 and a subset of the new
standard ISO/IEC 9899:1999 (C99). 

This is vbcc's website: http://www.compilers.de/vbcc.html

## Optimization

VBCC is a highly optimizing compiler, so don't be shy to work with `-O3`.
If you experience problems, you can still go to a lower level of optimization.

Use `-maxoptpasses=15` (or higher), if you get warnings like this:

```
warning 172 in function "xyz": would need more than 10 optimizer passes for best results
```

## QNICE specifics

### Register bank switching

VBCC is able to use QNICE's register bank feature entering and leaving
functions instead of using the stack.

If `-speed` is set, then VBCC evaluates `-rw-threshold`, which is 2 by
default. It means: As soon as more than 2 registers need to be saved, then
bank switching is performed.

If you need to prevent this, e.g. because you have a recursive function, then
use the __norbank directive:

```
__norbank void highly_recursive(int x, int y, int z)
{
    ...
}
```

If you want to force it, even when the to-be-saved registers are smaller than
treshold, then use the __rbank directive:

```
__rbank void always_use_bankswitching(int x)
{
    ...
}
```

### Interrupt Service Routines (ISRs)

When leaving an ISR, QNICE needs a "return from interrupt" `RTI` opcode. This
can be enforced by using the `__interrupt` function prefix.

```
__interrupt __rbank void irq(void)
{
    ...
}
```

## Updating to newer compiler versions

QNICE-FPGA contains a version of the whole vbcc toolchain including the
compiler, the assembler and the linker, that is adjusted to and optimized
for QNICE-FPGA. The official QNICE-FPGA releases contain the version that is
known to work for the specific QNICE-FPGA release. If you nevertheless want
or need to upgrade, then we advise to follow these instructions.

### Update and recompile the compiler

1. Get the newest snapshot of VBCC and copy it to `c/vbcc`

2. Run **`tools/make-toolchain.sh`**. This makes sure,
   that `monitor/compile_and_distribute.sh` is automatically being run first,
   which is important for having the newest `sysdef.h` in `compiler-backend`.
   From there, the new compiler backend is automatically copied into the
   VBCC folder and then the toolchain is being made.

###  Recompile the libraries

1. Go to the `c` folder and enter `source setenv.source`

2. First run `make-qnice-monitor-lib.sh`, because the standard
   C library depends on it

3. Then make sure that you have copied the source code of the standard C
   library (which is not Open Source) into `vclib`.

4. Then run `make-vclib.sh`

### Recompile /qbin and test

1. Run `/qbin/make.sh`

2. Test what can be tested in the emulator

3. Test on hardware

4. At least also test `c/test_programs/arith.c`
