QNICE Programming Best Practices
================================

There are three ways to program QNICE, all of them are covered in this guide.

* Native QNICE assembler
* VASM assembler (from the VBCC toolchain)
* C (VBCC toolchain)

Disclaimer: This is a "living document", i.e. at this moment, we do not claim
that it is even near to complete.

All languages
-------------

* The folder `dist_kit` contains important includes.
* The Monitor acts as "operating system" and offers convenient functions as
  documented in `doc/monitor/doc.pdf`. They range from IO functions over
  math and string functions to debug functions.
* Configure your editor to convert [TABs to
  SPACEs](https://stackoverflow.blog/2017/06/15/developers-use-spaces-make-money-use-tabs/).
* When using register banks make sure that the register bank
  selector in the upper eight bits of SR is **always** pointing to the highest
  active bank. Reason: Interrupt Service Routines might interrupt your code
  any time and they might also use register banks to save and restore the
  lower registers. So: If you need to reserve multiple banks, then just
  increase the bank selector accordingly. The principle is similar to
  reserving something on the stack, but the other way round: You
  are *incrementing* the bank selector to reserve space but you would
  *decrement* the stack pointer for doing so.
* When writing an interrupt service routine (ISR), make sure that you do not
  leave any register modified when calling `RTI`. You may use the stack.    

Native QNICE assembler
----------------------

* Use `.asm` as file extension.
* Use one semicolon `;` to start a comment.
* Write all mnemonics, register names, and labels in UPPER CASE.
* Write comments in mixed case.
* Always include `dist_kit/sysdef.asm`, so that you have the convenience
  macros for the CPU registers `SP`, `SR`, and `PC` as well as the
  convenience macros for `RET` for returning from a subroutine and 
  `SYSCALL` (if monitor functions are needed).
* Use `SYSCALL(<monitor function>, <branch flag>)` to call a monitor function.
  Do not directly use a branch command, because we might at a later stage
  add more logic to `SYSCALL`.
* Optionally include `dist_kit/monitor.def`, if you need "operating system"
  functions such as "return to monitor" aka `SYSCALL(exit, 1)` or others.

### Columns and spacing

The following spacing has proven to be optimal and will also allow a very
convenient screen layout of our future debugging tools.

```
LLLLLLLLLLLLLLL AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA SSCCCCCCCCCCCCCCCCCCCCCCCCCCCC               
                ; calculate the position where new Tetrominos emerge from
CALC_TTR_POS    MOVE    Tetromino_Y, R1
                MOVE    -8, @R1                 ; y start pos = -8
                MOVE    PLAYFIELD_X, R0         ; x start pos is the middle...
                ADD     PLAYFIELD_W, R0         ; ... of the playfield ...
                SHR     1, R0                   ; ..which is ((X+W) / 2) - of
                MOVE    TTR_SX_Offs, R1         ; of is taken from TTR_SX_Offs

```

* Overall width: 78 characters
* Up to 15 characters for labels (`L`): columns 1 to 15
* Then one space: column 16
* Up to 31 characters for the assembly code (`A`): columns 17 to 47
* The operands start at column 25
* Then one space: column 48
* If you want to comment, then start it with a semicolon which is directly
  followed by a space `; ` (`S`) in columns 49 and 50. From column 51 on,
  you can type your comment (`C`) with a maximum of 28 characters.

There is a template file in `test_programs/template.asm` that you can use as
a starting point for your projects. It contains the right columns and spacings
and includes some more best practices.

### Subroutines

* Sub routines must use the upper registers R8 to R12 to return values.
* They must not change any upper register that is not needed for returning 
  values.
* Another elegant way to return one or more boolean values is to use the
  status register's flags because you can then use branch commands after
  the subroutine returns without the need of an additional `CMP`.
* QNICE's register banks often times allow you to omit the stack when entering
  and leaving sub routines because in many cases, the lower registers R0 to R7
  are more than enough (and if not, you can use more than one bank per
  subroutine). This is why in general, every sub routine begins with an
  `INCRB` and ends just before the `RET` with a `DECRB`. And if you used
  more than one bank, make sure that you decrement by the appropriate
  amount of banks.

VASM assembler
--------------

* The priciples of the native assembler apply in principle.
* In `c/test_programs/vasm_test.asm` there is a sample file.
* Include `dist_kit/qnice-conv.vasm` for accessing the convenience macros.
* Include `dist_kit/sysdef.vasm` for the MMIO addresses and registers.
* Include `monitor.vdef` for the "operating system" routines.

C
-

* You need to set up the environment by doing a
  `source setenv.source` while being in the folder `c`. (It does not work,
  if you call it from another folder.)
* The sample programs are in `c/test_programs/`.
* Most of the time, you will want to compile by using
  `qvc <source> -c99 -O3`; this leads to best performance.
  If the output `.out` grows too large or does not work as expected, you
  might want to decrease the optimization level to `-O2` or `-O1`.
  The C99 standard using `-c99` is recommended for QNICE-FPGA.
* If you need the intermediary files such as the assembler file that the
  compiler generates, then use the switch `-k`.
* The heap size is currently set to 4096 words. It grows upwards coming from
  the end of the application and therefore grows towards the stack that is
  coming downwards from somewhere near 0xFEFF. Currently there are no
  checking mechanisms that check a collision between stack and heap.
  So be careful.
* Instead of heap memory, you might just want to use static variables within
  the code segment.
* VBCC is able to use QNICE's register bank feature: If `-speed` is set, 
  then VBCC evaluates `-rw-threshold`, which is 2 by default. It means:
  As soon as more than 2 registers need to be saved, then bank switching
  is performed.

  If you need to prevent this, e.g. because you have a recursive function,
  then use the `__norbank` directive:
  ```
  __norbank void highly_recursive(int x, int y, int z)
  {
    ...
  }
  ```
  If you want to force it, even when the to-be-saved registers are smaller
  than threshold, then use the `__rbank` directive:
  ```
  __rbank void always_use_bankswitching(int x)
  {
    ...
  }
  ```
* If you write an ISR in C then use `__interrupt`, as in this example
  ```
  __interrupt __rbank void irq(void)
  {
    ...
  }  
  ```
* The `qvc` command has all the include and library paths automatically set,
  so that you do not need to add paths to your includes. Neither do you need
  to manually link any libraries.
* Additionally to the Standard C library that can be included as usual, there
  is the QNICE Monitor library that provides "operating system functions"
  to C programs. It can be included via `#include "qmon.h"` and you can find
  it in `c/qnice/monitor-lib/include/qmon.h`
* You can also include `sysdef.h`, if you need low-level access to devices.
