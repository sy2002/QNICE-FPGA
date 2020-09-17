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
* Configure your editor to convert SPACEs to TABs.

Register Banks
--------------

Register banks are a pretty unique feature of the QNICE ISA. Not a lot of
programmers are familiar with this concept, so please take your time and also
read the [introduction documentation](doc/intro/qnice_intro.pdf).

* There are 256 register banks for the registers R0 to R7.
* You an change a register bank by either writing to the upper 8 bits of the
  status register `SR` or by using the `INCRB` or `DECRB` instructions. The
  latter one can be executed in only two CPU cycles, so they are faster than
  for example an `ADD 0x0100, SR`.
* The main use case for register banks is to speed up sub-routine calls by
  having an `INCRB` at the beginning of the sub-routine to provide a clean
  set of registers R0 to R7 and and a `DECRB` at the end of the sub-routine. 
  (More details: See best practices for [subroutines](#subroutines) below.)
* Normally, you should treat the register bank like a stack of registers,
  that means that you might do things like this:
  ```
  INCRB
  [... your code ...]
  INCRB
  [... more code ...]
  INCRB
  [... even more code ...]
  DECRB
  [... clean up stuff ...]
  DECRB
  [... clean up some more stuff]
  DECRB
  ```
* If you know what you are doing, you can also use register banks in more
  creative ways but be warned, that you are then leaving the field of
  best practices.

Interrupt Service Routines (ISRs)
---------------------------------

ISRs are a very complex subject matter. Therefore it makes sense that you
familiarize yourself with the way how the the interrupt mechanisms are
working in hardware by having a look at [doc/int-device.md](int-device.md).

* End your ISR with `RTI`.
* Most important best practice: Be careful, be paranoid. ISRs "must not 
  change anything" since they might happen at any time and "everywhere". So
  make sure that when your ISRs ends the **CPU registers R0 to R12** as well
  as the **registers of all devices you used** are untouched.
* Be sensible about the run-time of the ISR. Be aware of the performance
  impact that it might have to the system.
* Don't worry about flags or the status register `SR`, the stack pointer `SP`
  or the program counter `PC`: The CPU saves all three of them to shadow
  registers when entering an ISR and restores them when leaving it.
* If you need to work with register banks in an ISR, then the best practice
  is to begin your ISR with `MOVE 0xF000, SR`: This gives you 16 register
  banks to work with and leaves 240 for the other currently running software
  outside your ISR. The probability is very high, that there won't be any
  collisions. Since the CPU restores `SR` after `RTI`, you don't have to worry
  about having done the `MOVE 0xF000, SR` at the beginning.
* Avoid using `INCRB` and `DECRB` in ISRs because there might
  be situations, where you overwrite the register banks of the other
  currently running software.
* It is OK to use the stack.
* Programming ISRs in C: It is very important that your ISR is decorated not
  only with `__interrupt` but also with `__norbank` because you want to 
  avoid using `INCRB` and `DECRB` in ISRs. C will use the stack instead.
* You can trust that `SYSCALL` "operating system" functions are safe for ISRs.
* Sample ISR stub:
  ```
  MY_ISR      MOVE 0xF000, SR
              [your code, including INCRB/DECRB if needed]
              RTI
  ```
* Installing ISRs: Always make sure that your first move is to write to
  the register that contains the address of the ISR, because otherwise an
  interrupt might occur without a valid ISR address being present.
* Uninstalling ISRs: To avoid race conditions, make sure that the register
  that contains the ISR always either points to the ISR itself or to an adress
  that contains an `RTI`. That means that the best practice for shutting down
  an ISR is to write to the registers that are forcing the device to stop
  generating ISRs, without clearing the register that contains the address
  of the ISR or at least point it to a memory location that contains an `RTI`.

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
* When writing a tight inner loop which needs maximum performance, be aware
  that register to register operations only need two CPU cycles, so that
  for example your inner loop should branch to an address stored in a register
  like `RBRA R8, 1` versus directly addressing a label like
  `RBRA MY_LABEL, 1`. Also `ADD R8, R9` is faster than `ADD @R8, R9`.

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
* Sample subroutine stub:
  ```
  MY_SUBROUTINE    INCRB
                   [...]
                   DECRB
                   RET
  ``

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
  __interrupt __norbank void irq(void)
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
