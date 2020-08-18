QNICE Programming Best Practices
================================

There are three ways to program QNICE, all of them are covered in this guide.

* Native assembler
* VASM assembler (from the VBCC toolchain)
* C (VBCC toolchain)

Disclaimer: This is a "living document", i.e. at this moment, we do not claim
that it is even near to complete.

All languages
-------------

* The folder `dist_kit` contains important includes
* The Monitor acts as "operating system" and offers convenient functions as
  documented in `doc/monitor/doc.pdf`. They range from IO functions over
  math and string functions to debug functions.
* Configure your editor to convert SPACEs to TABs
* When using register banks, always make sure, that the register bank
  selector in the upper eight bits of SR is **always** pointing to the highest
  active bank. Reason: Interrupt Service Routines might also use register
  banks to save and restore the lower registers. So: If you need to reserve
  multiple banks, then just increase the bank selector accordingly. The
  principle is similar to reserving something on the stack, but the other
  way round: You are *incrementing* the bank selector to reserve space but
  you would *decrement* the stack pointer for doing so.
* When writing an interrupt service routine (ISR), make sure that you do not
  leave any register modified when calling `RTI`. You may use the stack.    

Native assembler
----------------

* Use `.asm` as file extension
* Use one semicolon `;` to start a comment
* Write all mnemonics, register names and labels in UPPER CASE
* Write comments in mixed case
* Always include `dist_kit/sysdef.asm`, so that you have the convenience
  macros for the CPU registers `SP`, `SR` and `PC` as well as the
  convenience macros for `RET` for returning from a subroutine and 
  `SYSCALL` (if monitor functions are needed).
* Use `SYSCALL(<monitor function>, <branch flag>)` to call a monitor function.
  Do not directly use a branch command, because we might at a later stage
  add more logic to `SYSCALL`.
* Optinally include `dist_kit/monitor.def`, if you need "operating system"
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

There is a template file in `test_programs/template.asm` that you an use as
a starting point for your projets. It contains the right columns and spacings
and includes some more best practices.

### Subroutines

* Sub routines must use the upper registers R8 to R12 to return values.
* They must not change any upper register that is not needed for returning 
  values.
* Another elegant way to return one or more boolean values is to use the
  status register's flags C, V and N, because you can then use branch
  commands after the subroutine returns without the need of an additional
  `CMP`.
* QNICE's register banks often times allow you to omit the stack when entering
  and leaving sub routines because in many cases, the lower registers R0 to R7
  are more than enough (and if not, you can use more than one bank per
  subroutine). This is why in general, every sub routine begins with an
  `INCRB` and ends just before the `RET` with a `DECRB`. And if you used
  more than one bank, make sure that you decrement by the appropriate
  amount of banks.

VASM assembler
--------------

WIP, <different includes, supports macros>

C
-

WIP
<For C: Mention -c99 and -O3 (and that it is worth to use -O3), mention how
you can switch to use INCRB/DECRB instead of the stack for functions, mention
heap and memory, ...For C: Mention -c99 and -O3
(and that it is worth to use -O3), mention how you can switch to use
INCRB/DECRB instead of the stack for functions, mention heap and memory, ...>
