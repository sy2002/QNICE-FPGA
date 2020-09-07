QNICE-FPGA Performance Characteristics
======================================

* The system runs with 50 MHz on all currently supported hardware targets.

* The CPU is built around a variable-length state machine. This means that
  there are instructions that are as short as two clock cycles and others that
  are in general as long as six clock cycles.

* Slow RAM, ROM and peripheral devices can make the execution even longer, as
  they are able to add wait-states to the CPU's execution.

* It is therefore difficult, to measure "The" CPU performance in MIPS
  (Million Instructions Per Second). In contrast, it always depends on the
  workload that is being executed.

* Peak performance has been measured in a math-heavy demo such as the
  mandelbrot demo: 14.67 MIPS. Q-TRIS runs at 13.21 MIPS.

* For the sake of the VGA and WASM emulator, the average QNICE performance
  is defined as **13.21 MIPS**.

MIPS measurements on September 7, 2020 using CPU version 1.7
------------------------------------------------------------

The newly implemented "FastPath" feature that makes sure, that all
instructions that operate on registers only (including branches) are from now
on only taking two CPU cycles.

### Mandelbrot: 14.67 MIPS

```
0000 0082 6CBD = 8,547,517 cycles            => 0.1710 sec
0000 0026 4514 = 2,508,052 instructions      => 3.41 cycles / instruction
                                             => 14.67 MIPS
```

Compared with V1.6, this is a 8% speed-up.

### Q-TRIS: 13.21 MIPS

```
0004 32FE 6649 = 18,035,402,313 cycles       => 360.71 sec => 6:01 min
0001 1C12 2094 =  4,765,917,332 instructions => 3.78 cycles / instruction
                                             => 13.21 MIPS
```

Compared with V1.6, this is a 2% speed-up.

MIPS measurements on August 18, 2020 using CPU version 1.6
----------------------------------------------------------

There are two instrumented versions of QNICE demo programs located in
`test_programs`: `mandel_perf_test.asm` (Mandelbrot demo) and
`q-tris_perf_test.asm`. The MIPS tests are performed by using
STDIN=STDOUT=VGA. UART would lead to different results. Mandelbrot has been
run three times, because the scrolling behaviour in VGA leads to different
performance (scrolling does cost performance). Q-TRIS was played for about
7:27 minutes to get a realistic value.

### Mandelbrot: 13.62 MIPS

```
0000 008C 7A95 = 9,206,421 cycles            => 0.1841 sec
0000 0026 4514 = 2,508,052 instructions      => 3.67 cycles / instruction
                                             => 13.62 MIPS
```

### Q-TRIS: 12.97 MIPS

```
0005 33BE B478 = 22,342,972,536 cycles       => 446.86 sec => 7:27 min
0001 5996 6BCC =  5,797,997,516 instructions => 3.85 cycles / instruction
                                             => 12.97 MIPS
```

Compared with measurements made with the V1.5 ISA, this is a 7% speed-up.
