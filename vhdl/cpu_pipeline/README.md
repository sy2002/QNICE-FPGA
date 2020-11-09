# Design of a new *pipelined* CPU

When designing a new pipelined version of the QNICE CPU, there is a elephant in
the room: An instruction such as `ADD @R0, @R1`, which itself is only a single
word in memory, will require four memory access: Reading the instruction,
reading from @R0, reading from @R1, and finally writing to @R1.  Since the
system bus in the QNICE only allows for a single memory access at a time, this
instruction must consume (at least) four clock cycles.

The design currently being worked on bases the pipelined approach on the above
observation: In each clock cycle the instruction proceeds from one stage to the next,
where each stage handles a single memory access. In other words, the first design
will have a four-stage pipeline:

* Stage 1: Read instruction
* Stage 2: Read operand 1
* Stage 3: Read operand 2
* Stage 4: Write result

Each of the above stages will have a memory interface (address and data)
feeding into a central arbiter. The purpose of the arbiter is to allow only a
single stage at a time access to the memory.

The four stages must be prioritized in some way. Presumably, priority should be
given to the highest numbered stage, so that the pipeline can be emptied as
quickly as possible. This priority scheme is still TBD.

The four stages also interact with the register file.

The current QNICE design allows combinatorial reads from both the register file
and from memory. Here memory read is synchronous to the falling clock edge, so
appears combinatorial from the CPU's perspective. We will probably later on
insert flip-flops when reading from register file and/or memory, in order to
reduce the long combinatorial paths and thereby increase the clock frequency.
However, in order to keep the design as simple as possible, this is deferred to
later.

So far, the design looks as follows:

![Pipeline Design](design.png)

The important design decisions are as follows:
* There are four stages.
* Each stage receives input in the same clock cycle as providing the output.

In other words, the horizontal connections are combinatorial. The vertical
connections are registered. The registering is depicted with the thick
horizontal bars where the connections originate from.

Important constants (e.g. instruction decoding) is placed in the package file
`cpu_constants.vhd`.

## Pipeline flow and back pressure
Data usually flows from one stage to the next on every clock cycle. However, sometimes
a stage does not have data to deliver to the next stage. This creates an idle
cycle, and must be signalled in some way. Here we use the signal `valid` to
indicate if the next stage should do some work or just skip this clock cycle.

Similarly, the arbiter may grant or deny access to the external memory. In
other words, if - say - `Read Operand 2` and `Write Result` both want to access
memory, only `Write Result` will be granted access. In the mean time, the stage
`Read Operand 2` must wait until it is granted access. This stalls the entire
pipeline all the way back to the start, because no stage before `Read Operand
2` may proceed. This stalling is indicated by the signal `ready`, which is
deasserted when a stage is not able to accept new data.

## Testing
I'm simultaneously testing the design in simulation and in hardware. I've
therefore written a top-level entity `top.vhd` that instantiates the pipelined
CPU as well as a small memory. This small memory acts as a RAM, and is
initialized with some instructions. In others words, the memory provides
instructions for the CPU as well as acting as writeable memory while the
instructions are being executed.

In order for the synthesis to not reduce away all the logic, I've connected the
PC register to the LED outputs.

I've written a small simulation testbench that instantiates this top level
entity and provides clock and reset.

### Test methodology
So the test methodology is to write one or more small assembly programs and
place them in a file e.g. `test1.asm`. Then to start the test simply type:

```
make test1
```

This will assemble the file `test1.asm` into binary data in the file
`prog.rom`, which is used to initialize the memory. Then the PC is reset
(currently to 0x0010), and the CPU starts executing!

Verification is done by manually inspecting the generated waveform.

## Arbiter and pipeline

In the following we'll analyze the dynamics of the pipeline and the
arbitration for the memory in a few different cases.

### `MOVE @R, R`

First we will consider a sequence of instructions of the same instruction,
namely `MOVE @R, R`. To execute this instrution, the CPU needs to perform an
instruction fetch, as well as reading the source operand.  In other words, the
stages `Read Inst` and `Read Source` will be performing memory accesses, while
the stages `Read Dest` and `Write Result` will not.

The following table shows each stage as a row, and with time progressing to the
right. As an instruction propagates through the pipeline, it will travel
diagonally down to the right. If an instruction is shown with small letters,
then that means the instruction is not performing any memory access in that
particular clock cycle. In other words, in each column at most one row may
perform a memory access.

```
Read Inst    | MOVE @R,R0 | .. wait .. | MOVE @R,R1 | .. wait .. | MOVE @R,R2 | .......... |
Read Source  | .......... | MOVE @R,R0 | .......... | MOVE @R,R1 | .......... | MOVE @R,R2 |
Read Dest    | .......... | .......... | move @r,r0 | .......... | move @r,r1 | .......... |
Write Result | .......... | .......... | .......... | move @r,r0 | .......... | move @r,r1 |
```

The table shows how "Read Source" takes precedence over "Read Inst". So at the
second time step, no instruction fetch is taking place while the CPU is reading
the source operand from @R. The word "wait" indicates that the stage would
like to do some work, but is not allowed due to.

The table also shows that the memory bus is active on all clock cycles, and a
new instruction starts every two clock cycles.

### `MOVE R, @R`
Next we will consider a seemingly similar looking sequence, this time with the
instruction `MOVE R, @R`. This instruction will access memory three times:
`Read Inst`, `Read Dest`, and `Write Result`. The dynamics is now somewhat more complicated,
as shown in the following:

```
Read Inst    | MOVE R,@R0 | MOVE R,@R1 | .. wait .. | .. wait .. | .. wait .. | .. wait .. | MOVE R,@R2
Read Source  | .......... | move r,@r0 | move r,@r1 | .......... | .......... | .......... | ..........
Read Dest    | .......... | .......... | MOVE R,@R0 | .. wait .. | MOVE R,@R1 | .......... | ..........
Write Result | .......... | .......... | .......... | MOVE R,@R0 | .......... | MOVE R,@R1 | ..........
```

We see how it now takes six clock cycles to perform two instructions, and that
the memory system is active on every clock cycle. In the fourth cycle, the
stage `Read Dest` is forced to wait, because of memory arbitration.

One may argue that the MOVE instruction does not need to read the destination
operand. That is entirely true, but the above dynamics still apply to
instructions like `ADD R, @R`. To put it differently, the instruction `MOVE R,
@R` can be optimized by having it not read the destination operand. This is
still TBD.

### Register file access
In the current design, there are three simultaneous writes to the CPU registers:

* In the `Read Source` stage in case of pre-decrement or post-increment.
* In the `Read Dest` stage in case of pre-decrement or post-increment.
* In the `Write Result` stage when the destination is a register.

However, any given instruction only updates at most two CPU registers. So does
the register file really need three write ports? This quesion is important,
because the synthesis tool only allows one write port for RAM blocks, when
they are combined with multiple read ports.

Consider the following sequence of instructions:
```
ADD R0, R1        (update register R1 in stage 4)
ADD R2, @R3++     (update register R3 in stage 3)
ADD @R4++, R5     (update register R4 in stage 2 and register R5 in stage 4)
```

The table below shows register file updates (indicated with the instruction
written in upper case letters):

```
1. Read Inst    | add r0, r1    | add r2, @r3++ | add @r4++, r5 | ............. | ............. | .............
2. Read Source  | ............. | add r0, r1    | add r2, @r3++ | ADD @R4++, R5 | ............. | .............
3. Read Dest    | ............. | ............. | add r0, r1    | ADD R2, @R3++ | add @r4++, r5 | .............
4. Write Result | ............. | ............. | ............. | ADD R0, R1    | add r2, @r3++ | ADD @R4++, R5
```

It is seen that in the fourth clock cycle, three different pipeline stages all
want to write to the register file simultaneously.

However, in this specific combination of instructions the third instruction
will be stalled due to the memory arbiter.

So this analysis shows that the register file needs three write ports, but most
of the time, not all three writes will be active at any given time.  In other
words, we need another arbiter, this time for the register access!  This is
necessary, in order to be able to implement the register file using RAM blocks
in the FPGA.

### Redesign
So this calls for another iteration of the design.  The previous arbiter is now
renamed to `arbiter_mem.vhd` and a new `arbiter_regs.vhd` is added. The
register arbiter allows only a single stage to write to the register file at a
given time.  In the figure below is shown the new arbiter placed in between the
processing stages and the register file.

![Pipeline Design 2](design2.png)

Crucial for this redesign is that the register arbiter provides a `ready` signal
to each stage, indicating whether that stage is allowed access. So now each
stage must wait for three conditions:

* Access to register write
* Access to memory
* Access to next stage

Only when all three conditions are met simultaneously may the stage proceed
with its processing.  Otherwise it must wait until the next clock cycle, thus
stalling the entire pipeline. However, this extra register arbiter doesn't seem
to lead to major pipeline stalling in practice. A close analysis will follow
later (TBD).

The implementation of the register arbiter is similar to the memory arbiter,
but with only three "clients" it becomes slightly simpler. Just like with the
memory arbiter priority is given to the later stages. This decision too is TBD,
but initially it is believed to help proving that the pipeline never locks up,
i.e.  where multiple stages are waiting for each other, and no stages are
proceeding.

It should be noted that updating of the `PC` and the `SR` is handled separately.
The register arbiter only handles regular register updates.

## Implementation in hardware
Since the design is becoming more complex, it is necessary that the memory
block is implemented using RAM blocks in the FPGA. This requires a synchronous
read.  So far, our design expects a combinatorial read from the memory, but
this can be achieved by clocking the memory on the **falling** clock edge. So
the memory performs a synchronous read, but the CPU still has the remaining
half of the clock cycle to process the data.

Adding this change to the design leads to timing violations when running at 100
Mhz.  So now we see that all these combinatorial connections lead to large
timing paths (as expected) and reduces the maximum frequency. In particular,
the memory block itself consumes half of a clock cycle, as mentioned above.

In order to meet timing, a clock module is added in `top.vhd` to generate a
slower clock.  Later, we might look into how we can increase the clock
frequency e.g. by introducing more pipeline stages. Currently, the clock is
running at 65 MHz.

Simulating a clock module is very slow, so to avoid that I've connected the
CPU and memory in a `system.vhd` file, which can be used for both simulation
and synthesis. This module is then instantiated in the top level synthesis file
and in the simulation testbench.

The current resource utilization in the FPGA is as follows:

* Slice LUTs : 354
* Slice Registers : 111
* Slices : 107

This shows the CPU uses very few resources indeed. But the ALU is not fully
implemented yet, and neither is register banking.

Here is a short TODO list for the next few steps:
* Finish the ALU, including generating the correct value for `SR`.
* Optimize the `MOVE R, @R` instruction so that it does not read from `@R`, since
  that value is not used.
* Make sure instructions like `MOVE @R15++, R` work, so that we can load
  immediate values into registers.
* And then finally conditional branching, so that we can start writing
  self-verifying test cases.

## Optimizing `MOVE R, @R`
It seems that the memory interface is a saturated interface, meaning that on
every clock cycle the CPU is either reading from or writing to memory. It
therefore makes sense to optimize instructions, so they only spend memory
bandwidth if it is really needed.

Some instructions, e.g. MOVE, SWAP, and NOT, do not read the old value of the
destination. Therefore, they can be optimized by not requesting a memory
access. To simplify the implementation I've introduced a new signal `mem_request`
in the file `read_dst_operand.vhd`. The same signal has been introduced into
the other pipeline stages as well, just for consistency.

Since the `MOVE R, @R` instruction now only accesses the memory twice,
the memory arbitration dynamics are different, as shown in the following:

```
Read Inst    | MOVE R,@R0 | MOVE R,@R1 | MOVE R,@R2 | .. wait .. | .. wait .. | .. wait .. | MOVE R,@R3
Read Source  | .......... | move r,@r0 | move r,@r1 | move r,@r2 | .......... | .......... | ..........
Read Dest    | .......... | .......... | move r,@r0 | move r,@r1 | move r,@r2 | .......... | ..........
Write Result | .......... | .......... | .......... | MOVE R,@R0 | MOVE R,@R1 | MOVE R,@R2 | ..........
```

In six clock cycles the CPU can execute three instructions, compared to two before.

## Finalizing the ALU
The ALU is a large combinatorial module, including two barrel shifters
(shifting a variable amount). It therefore makes sense to complete this module,
to see how it influences the resource count and timing.

It turns out the timing is unaffected. The resource utilization has
approximately doubled to:

* Slice LUTs : 601
* Slice Registers : 116
* Slices : 175

## The instructions `MOVE @R15++, R`
This instruction is tricky, becaue it updates the PC. Fortunately, this update
takes place already in stage 2 where a memory read operation is taking place,
thus stopping an instruction fetch. Meanwhile, stage 2 is also writing the
updated value to the PC, so it will be ready for the next instruction.

A minor edit to the file `registers.vhd` was all that was needed.

## Branch instruction
Conditional branching is a very tricky subject. Ideally, we should implement
some kind of branch prediction. But for now, we'll instead just stall the
pipeline for some clock cycles, in order to be sure that the status register is
updated.

The idea is that the branch instruction is executed in stage 4. But
furthermore, when a branch instruction is encountered in stage 1, this stage
will stop any further instruction fetching for another 3 clock cycles. This
means that the status register in stage 4 is guaranteed to have the correct
value.

And that is it! All the basic functionality is now implemented (but not
tested).  And there are still all the pipeline hazards.

But just for fun, I've copied the `cpu_test.asm` file into a local copy
`test2.asm` with a few changes, e.g. the start address is changed to 0x0000.
Getting this comprehensive CPU test to run without errors will take some effort,
but at least it can run for a few clock cycles now.

One bug found so far is that the status register should only be updated when
executing an instruction. I've therefore added a `valid` signal to the ALU.

## Running the `test2.asm`
It is great to have a comprehensive CPU test suite, and the current design is
now able to run this test (using the command `make test2`) and give meaningful
(but incorrect) results.  Apart from the branch hazards that we've fixed in a
brutally inefficient way above, I don't expect so many pipeline hazards, so it
therefore makes sense to try and run this test now to see what bugs are
discovered.

To aid in debugging, I've added a small disassembler. This will print out
to the console the disassembly of the current instruction executed.

One bug found quickly was that branch instructions should read their target
location from the source operand, and not from the destination operand. This is
actually an error in the QNICE ISA documentation, that is yet to be fixed.

With this bug fixed the test now runs until address `0x0149` where it tries to
execute the instruciton `CMP R0, @R15++`.  And here we see our first true
pipeline hazard: The PC is updated in the third clock cycle
`read_dst_operand` but already in the second clock cycle is the next
instruction being fetched, before the PC has been incremented.

This is therefore a good time to look more detailed into the operations
performed in each pipeline stage:

* Stage 1:
  - Receive `PC` from register file
  - Present `PC` to memory
  - Receive instruction from memory
  - Write updated `PC` to register file
* Stage 2:
  - Present `src` register address to register file
  - Receive `src` register value from register file
  - Present `src` operand address to memory
  - Receive `src` operand value from memory
  - Write updated `src` register value to register file
* Stage 3:
  - Present `dst` register address to register file
  - Receive `dst` register value from register file
  - Present `dst` operand address to memory
  - Receive `dst` operand value from memory
  - Write updated `dst` register value to register file
* Stage 4:
  - Calculate result using ALU
  - Write `dst` result value to memory
  - Write calculated `dst` register value to register file
  - Write new `PC` to register file (if branching)

The lines involving the memory (two lines each stage) must remain there,
because that is what our whole design is based around. However, many of the
other operations can be moved around somewhat. This has effect on pipeline
hazards as well as on timing closure.

One such change could be to move the ALU calculation from stage 4 to stage 3.
This will give access to the status register one clock cycle earlier, and may
therefore reduce our (inefficient) branch delay by one clock cycle. Since the
ALU is a very timing expensive component, this move will have an impact on
timing as well (but that impact may be both positive or negative).

Another possible change is to read the `src` and `dst` register values earlier,
perhaps already in stage 1. Writing the updated `src` and `dst` register values can
then be moved up one clock cycle each, to stages 1 and 2 respectively. This
last change will help with our current bug, where the `PC` is updated in stage 3.

Due to the recent changes (mainly conditional branching) I've had to reduce the
clock frequency further to 50 Mhz.

I made a small change in `read_src_operand` and `read_dst_operand`, because
there is no need for the memory address to depend on the register arbiter.
This change improves timing, because it reduces the combinatorial inputs to the
memory address.

Some more statistics at this stage of the project:

Resource utilization:

* Slice LUTs : 688
* Slice Registers : 135
* Slices : 207

Timing:

* The slowest timing path has a slack of 0.7 ns and a logic
depth of 8 levels: The `read_dst_operand` stage reads the destination register
value from the register file and then reads the destination operand from
memory. As the clock half-period is 10 ns, the current slack suggests a possible
clock frequency of 500/(10-0.7) = 53 MHz.

Test coverage:

* `test2.asm` fails first at 0x0149, which is approximately 6% of the whole test.

Pipeline statistics (when reading from 0x0149):

* Clock cycles : 445
* Instructions : 118
* Cycles per instruction : 445/118 = 3.77
* Memory cycles : 232
* Memory stalls : 17
* Memory utilization : 232/445 = 52%
* Register write cycles : 210
* Register write stalls : 0
* Register write utilization : 210/445 = 47%

`Memory stalls` counts whenever any stage has to wait for memory access, i.e.
whenever more than one stage wants to access the memory in the same cycle.
`Register write stalls` measures the similar occurrence in the register arbiter.

The statistics above show that there is very little contention to the memory
(only 17 occurences) and no contention to the register write. Despite this, the
`cycles per instruction` is very high (almost 4).  These results are not
very representative (hopefully!) and are mainly indicative of the CPU test
consisting of a lot of branch instructions that each take 4 clock cycles.

To facilitate optimizations (and bugfixes) I've made a few minor changes:

* Separate read and write register. This gives more flexibility for optimizations.
* Add debug output to console about memory accesses. This helps tracking down bugs.
* Stop the simulation when a control instruction (e.g. HALT) occurs.

With these changes the test now ends with the following lines:

```
arbiter_mem.vhd:70:16:@4560ns:(report note): MEM: read instruction from 0x0149
arbiter_mem.vhd:70:16:@4570ns:(report note): MEM: read instruction from 0x014A
arbiter_mem.vhd:74:16:@4580ns:(report note): MEM: read dst operand from 0x014B
arbiter_mem.vhd:76:16:@4590ns:(report note): MEM: write result to 0x014B
cpu_constants.vhd:165:10:@4590ns:(report note): 0149 (C03E) CMP R0, 0x1233
arbiter_mem.vhd:70:16:@4600ns:(report note): MEM: read instruction from 0x014C
cpu_constants.vhd:165:10:@4600ns:(report note): 014A (1234) ADD R2, R13
ghdl:error: bound check failure at memory.vhd:62
```

Here it is much more clear that the line `MEM: read instruction from 0x014A` is
incorrect, since address 0x014A contains an operand, and not an instruction.

## Fixing pipeline hazards

Now begins the long and arduous task of tracking down and fixing the pipeline
hazards. Currently, we're stopped at the instruction `CMP R, @PC++`. The reason
is that in stage 2 we begin fetching the next instuction from an incorrect
address, because only in stage 3 is the PC incremented.

I initially made several attempts at solving this problem by moving the
register writes from stages 2 and 3 to stages 1 and 2. However, this lead to a
host of other problems that I couldn't readily solve, so I've temporarily given
up on that approach. Instead I'm looking into performing more instruction
decoding in stage 1. What comes to mind is to block the instruction fetch, if
the current instruction is updating the PC. This is simply done by adding a
single line to `read_instruction.vhd`:

```
mem_request <= '0' when valid_r = '1' and instruction_r(R_DEST_REG) = C_REG_PC else
```

This change is not enough, since stage 1 still erroneously passes on a valid
instruction even though no instruction fetch was performed. This turns
out to be another easy fix by adding the condition `mem_request and` to the line:

```
ready <= mem_request and mem_ready and ready_i and not rst_i;
```

Alas, this still fails, because now only the very first instruction in
`test2.asm` is executed. This time it is because the `count_r` signal is not
being decremented, when `ready` is not asserted. This is not the intended
behaviour; `count_r` should be decremented regardless of the `ready` signal.
This too is an easy fix, just by moving the `if ready = '1' then` inside the
`when 0 =>`.

With all these small changes, finally the instruction `CMP R, @PC++` seems to
work. There is just one more thing. Looking at the console output reveals the
lines:
```
arbiter_mem.vhd:70:16:@4440ns:(report note): MEM: read instruction from 0x0149
arbiter_mem.vhd:74:16:@4460ns:(report note): MEM: read dst operand from 0x014A
arbiter_mem.vhd:76:16:@4470ns:(report note): MEM: write result to 0x014A
cpu_constants.vhd:165:10:@4470ns:(report note): 0149 (C03E) CMP R0, 0x1233
```
The problem here is the third line: `MEM: write result to 0x014A`. This is
incorrect behaviour, because the `CMP` instruction should not write to the
destination.  This is yet another trivial fix, just by adding the line:
```
mem_request <= '0' when instruction_i(R_OPCODE) = C_OP_CMP else
```
in `write_result.vhd``write_result.vhd`

Still the test fails in roughly the same place, this time with the lines:
```
arbiter_mem.vhd:70:16:@4440ns:(report note): MEM: read instruction from 0x0149
arbiter_mem.vhd:74:16:@4460ns:(report note): MEM: read dst operand from 0x014A
arbiter_mem.vhd:70:16:@4470ns:(report note): MEM: read instruction from 0x014B
cpu_constants.vhd:165:10:@4470ns:(report note): 0149 (C03E) CMP R0, 0x1233
arbiter_mem.vhd:72:16:@4480ns:(report note): MEM: read src operand from 0x014C
cpu_constants.vhd:158:10:@4500ns:(report note): 014B (FF8B) ABRA 0x0150, !Z
arbiter_mem.vhd:70:16:@4510ns:(report note): MEM: read instruction from 0x0150
read_instruction.vhd:102:22:@4510ns:(report failure): CONTROL instruction
```
The problem is that the instruction being executed is `CMP R0, 0x1233`, but in
the `test2.asm` source file the correct instruction is `CMP R0, 0x1234`.  So it
would appear that the destination value is decremented erroneously.  The
problem is the lines
```
if valid_i = '1' and ready = '1' then
   case conv_integer(instruction_i(R_DEST_MODE)) is
```         
in the file `read_dst_operand.vhd`. The reason is that the "destination mode"
field in the instrucion is not valid in case of branch or control instructions.
So the previous instruction `0145 (FF83) ABRA 0x0149, Z` was actually
interpreted as having a destination operand of `@--R0`, which prompted a
decrement of the `R0` register and the associated destination operand value.
Again the fix is easy (once the root cause has been found!) and that is to add
the conditionals
```
   instruction_i(R_OPCODE) /= C_OP_CTRL and
   instruction_i(R_OPCODE) /= C_OP_BRA then
```
to the above code segment.

And, finally, the test proceeds. Phew! This was quite arduous, mainly due to
lots of small bugs.  Interestingly, the changes made above have somewhat
improved the statistics. So at the time of executing the instruction at 0x0149,
now only 433 clock cycles have occurred, instead of the value 445 reported
previously. I believe the reason is that the signal `count_r` is now
decremented always, and no longer dependent on a conditional.

The test now fails with the lines:
```
arbiter_mem.vhd:70:16:@4890ns:(report note): MEM: read instruction from 0x016B
cpu_constants.vhd:165:10:@4890ns:(report note): 0169 (C13E) CMP R1, 0x1234
arbiter_mem.vhd:72:16:@4900ns:(report note): MEM: read src operand from 0x016C
cpu_constants.vhd:158:10:@4920ns:(report note): 016B (FF83) ABRA 0x0170, Z
arbiter_mem.vhd:70:16:@4930ns:(report note): MEM: read instruction from 0x0170
read_instruction.vhd:102:22:@4930ns:(report failure): CONTROL instruction
```

Pipeline statistics (when reading from 0x016B):

* Clock cycles : 478
* Instructions : 131
* Cycles per instruction : 478/131 = 3.65
* Memory cycles : 258
* Memory stalls : 22
* Memory utilization : 258/478 = 54%
* Register write cycles : 203
* Register write stalls : 0
* Register write utilization : 203/478 = 42%

Interestingly, the total number of register writes has gone down, but that must
be due to the fix in `read_dst_operand.vhd`, where we now make an exception for
branch and control instructions.

## Fixing more bugs
Looking at the waveform it is seen that a previous instruction `CMP 0x1234, R1`
is changing the value of `R1`. Clearly this is an error, so some minor changes
are made in `write_result.vhd`, basically just suppressing any register writes
in case of a `CMP` instruction.

With these changes the test now fails with the lines:
```
arbiter_mem.vhd:70:16:@4970ns:(report note): MEM: read instruction from 0x0171
arbiter_mem.vhd:70:16:@4980ns:(report note): MEM: read instruction from 0x0172
arbiter_mem.vhd:72:16:@4990ns:(report note): MEM: read src operand from 0x0173
arbiter_mem.vhd:70:16:@5us:(report note): MEM: read instruction from 0x0174
cpu_constants.vhd:165:10:@5us:(report note): 0171 (0004) MOVE R0, R1
arbiter_mem.vhd:72:16:@5010ns:(report note): MEM: read src operand from 0x0175
cpu_constants.vhd:165:10:@5010ns:(report note): 0172 (CF84) CMP 0x1234, R1
cpu_constants.vhd:158:10:@5030ns:(report note): 0174 (FF8B) ABRA 0x0179, !Z
arbiter_mem.vhd:70:16:@5040ns:(report note): MEM: read instruction from 0x0179
read_instruction.vhd:102:22:@5040ns:(report failure): CONTROL instruction
```

It is attempting to execute the two instructions
```
MOVE R0, R1
CMP 0x1234, R1
```
However, at the time of execution in stage 4, the destination operand (from
register value `R1`) has not been updated. So this is a real pipeline data
hazard.

## Fixing some pipeline hazards
Before proceeding I find it convenient to do some refactorings. The purpose is
mainly to clean up the code so it becomes more readable. Once this is done, it
is fairly easy to fix the above pipeline hazard. When the instruction `CMP
0x1234, R1` is in stage 3, the previous instruction `MOVE R0, R1` is in stage 4
updating the register R1. So the module `read_dst_operand.vhd` should check
whether it is reading from the same regsiter that the module `write_result.vhd`
is writing to.

This is handled by the following few lines of code:
```
reg_data_in <= res_data_i when res_wr_i = '1' and
                               res_wr_reg_i = instruction_i(R_DEST_REG) else
               reg_data_i;
```

The signals `res_data_i`, `res_wr_i`, and `res_wr_reg_i` all come from stage 4,
while the signal `reg_data_i` comes from the register file.

A similar data hazard is when stage 4 is writing to a register that has already
been read in stage 1. So a similar set of lines are inserted to deal with that:
```
src_operand <= res_data_i when res_wr_i = '1' and
                               res_wr_reg_i = instruction_i(R_SRC_REG) else
               src_operand_i;
```
Here `src_operand_i` comes from the previous stage.

With these changes the test runs much farther now, and stops with the
following lines:

```
arbiter_mem.vhd:70:16:@13160ns:(report note): MEM: read instruction from 0x03D7
arbiter_mem.vhd:70:16:@13170ns:(report note): MEM: read instruction from 0x03D8
arbiter_mem.vhd:70:16:@13180ns:(report note): MEM: read instruction from 0x03D9
arbiter_mem.vhd:76:16:@13190ns:(report note): MEM: write result to 0x03FD
cpu_constants.vhd:165:10:@13190ns:(report note): 03D7 (0409) MOVE R4, @R2
arbiter_mem.vhd:76:16:@13200ns:(report note): MEM: write result to 0x03FE
cpu_constants.vhd:165:10:@13200ns:(report note): 03D8 (050D) MOVE R5, @R3
arbiter_mem.vhd:74:16:@13210ns:(report note): MEM: read dst operand from 0x03DB
arbiter_mem.vhd:70:16:@13220ns:(report note): MEM: read instruction from 0x03DC
cpu_constants.vhd:165:10:@13220ns:(report note): 03D9 (C43E) CMP R4, 0x1234
arbiter_mem.vhd:70:16:@13230ns:(report note): MEM: read instruction from 0x03DD
arbiter_mem.vhd:72:16:@13240ns:(report note): MEM: read src operand from 0x03DE
arbiter_mem.vhd:76:16:@13250ns:(report note): MEM: write result to 0x03FA
cpu_constants.vhd:165:10:@13250ns:(report note): 03DC (0003) MOVE R0, @--R0
arbiter_mem.vhd:72:16:@13260ns:(report note): MEM: read src operand from 0x03DE
arbiter_mem.vhd:70:16:@13270ns:(report note): MEM: read instruction from 0x03DF
read_instruction.vhd:102:22:@13270ns:(report failure): CONTROL instruction
```

Here the line `MEM: read dst operand from 0x03DB` is incorrect, because this
is an instruction.

It turns out there are some problems when a source or destination operand is of
the type `@PC++`. This was because the stages `read_src_operand.vhd` and
`read_dst_operand.vhd` would proceed with the execution even though the
register file was busy. This was fixed by just some small changes in these two files.

The next problem that was revealed occurs when writing directly to the PC,
together with delays caused by arbitration. For now I temporarily added a delay
in `read_instruction.vhd`, similarly to branches. I feel this is an inelegant
solution, but for now I'm aiming for correctness (i.e. bugfixing) rather than
elegance.

Now the test proceeds a bit further and ends with:
```
cpu_constants.vhd:158:10:@17150ns:(report note): 0424 (FFB0) RSUB 0x0001, 1
arbiter_mem.vhd:70:16:@17160ns:(report note): MEM: read instruction from 0x0427
arbiter_mem.vhd:72:16:@17170ns:(report note): MEM: read src operand from 0x0428
arbiter_mem.vhd:70:16:@17180ns:(report note): MEM: read instruction from 0x0429
cpu_constants.vhd:165:10:@17190ns:(report note): 0427 (0FA4) MOVE 0x0447, R9
arbiter_mem.vhd:72:16:@17200ns:(report note): MEM: read src operand from 0x042A
arbiter_mem.vhd:74:16:@17210ns:(report note): MEM: read dst operand from 0x0447
arbiter_mem.vhd:70:16:@17220ns:(report note): MEM: read instruction from 0x042B
cpu_constants.vhd:165:10:@17220ns:(report note): 0429 (CFA5) CMP 0x5678, @R9
arbiter_mem.vhd:72:16:@17230ns:(report note): MEM: read src operand from 0x042C
cpu_constants.vhd:158:10:@17250ns:(report note): 042B (FFAB) RBRA 0x0011, !Z
arbiter_mem.vhd:70:16:@17270ns:(report note): MEM: read instruction from 0x042D
arbiter_mem.vhd:72:16:@17280ns:(report note): MEM: read src operand from 0x042E
arbiter_mem.vhd:70:16:@17290ns:(report note): MEM: read instruction from 0x042F
arbiter_mem.vhd:70:16:@17300ns:(report note): MEM: read instruction from 0x0430
cpu_constants.vhd:165:10:@17300ns:(report note): 042D (3FA4) SUB 0x0446, R9
arbiter_mem.vhd:72:16:@17310ns:(report note): MEM: read src operand from 0x0431
cpu_constants.vhd:165:10:@17320ns:(report note): 042F (C934) CMP R9, R13
cpu_constants.vhd:158:10:@17330ns:(report note): 0430 (FFAB) RBRA 0x000D, !Z
arbiter_mem.vhd:70:16:@17350ns:(report note): MEM: read instruction from 0x0432
arbiter_mem.vhd:72:16:@17360ns:(report note): MEM: read src operand from 0x0433
arbiter_mem.vhd:74:16:@17370ns:(report note): MEM: read dst operand from 0x0446
arbiter_mem.vhd:70:16:@17380ns:(report note): MEM: read instruction from 0x0434
cpu_constants.vhd:165:10:@17380ns:(report note): 0432 (CFA5) CMP 0x0426, @R9
arbiter_mem.vhd:72:16:@17390ns:(report note): MEM: read src operand from 0x0435
cpu_constants.vhd:158:10:@17410ns:(report note): 0434 (FFAB) RBRA 0x000A, !Z
arbiter_mem.vhd:70:16:@17430ns:(report note): MEM: read instruction from 0x0440
read_instruction.vhd:105:22:@17430ns:(report failure): CONTROL instruction
```

The problem now is that `RSUB` and `ASUB` are simply not implemented yet.  We
have now the following statistics:

Test coverage:

* `test2.asm` fails first at 0x0424, which is approximately 20% of the whole test.

Pipeline statistics (when reading from 0x0424):

* Clock cycles : 1700
* Instructions : 412
* Cycles per instruction : 1700/412 = 4.13
* Memory cycles : 808
* Memory stalls : 106
* Memory utilization : 808/1700 = 48%
* Register write cycles : 605
* Register write stalls : 0
* Register write utilization : 605/1700 = 36%

Resource utilization:

* Slice LUTs : 759
* Slice Registers : 167
* Slices : 223

Timing:

* The slowest timing path has a slack of -1.3 ns and a logic depth of 15
  levels.  This suggests a maximum frequency of 500/(10+1.3) = 44 MHz.

Unfortunately, the CPI has increased beyond 4 and the frequency has gone down
below 50 MHz, so considerable worse performance. In fact, even worse than the
existing sequential implementation of the CPU. This is somewhat disappointing,
and certainly fuels a desire to perform optimizations.

## Redesigning the pipeline
The timing problems are due to the half clock cycle memory read. So an obvious
fix is to give the memory a full clock cycle to perform a read. This is done
simply by changing `falling_edge` to `rising_edge` in the file `memory.vhd`.
This is also a more clean design, since mixing falling\_edge and rising\_edge
is quite confusing.

However, this change now means the CPU no longer can perform a combinatorial
read from memory. In other words, the pipeline must be redesigned completely,
and we will therefore be restarting (almost) completely from scratch.

The block diagram is still the same, with four stages competing for access
to the memory address bus. However, the data flow is changed.

The new flow looks as follows:

* Stage 1:
  - Receive `PC` from register file
  - Initiate memory read from `PC`
  - Write incremented `PC` to register file
* Stage 2:
  - Receive instruction from memory
  - Decode instruction
  - Read 'src' and 'dst' registers from register file
  - Optionally initiate memory read from `src`
  - Optionally write updated `src` register value to register file
* Stage 3:
  - Receive `src` operand value from memory
  - Optionally initiate memory read from `dst`
  - Optionally write updated `dst` register value to register file
* Stage 4:
  - Receive `dst` operand value from memory
  - Calculate result using ALU
  - Optionally write `dst` result value to memory
  - Optionally write calculated `dst` register value to register file
  - Optionally write new `PC` to register file (if branching)

One thing I've done differently this time is to perform a complete instruction
decoding in stage 2 when the instruction is received. This includes deciding
in which stages to perform memory and/or register accesses.

A second thing I've done differently is that I've employed a trivial branch
prediction that assumes the branch is not taken. This means that instruction
fetches continue after a branch instruction, regardless of whether the branch
**is** taken. In the event that the branch is taken, then the entire pipeline is
flushed, i.e. all pipeline stages are invalidated. This removes the 3-clock
cycle delay in the previous solution, for all the cases where the branch is not
taken.

Another more implementation-specific change is that I've collected all the
signals from one stage to the next in a single common record type. So instead
of three different record types `t_stage1`, `t_stage2`, and `t_stage3`, I now
have only a single record type `t_stage`. This reduces the number of lines of
code, and relies on the synthesis tool being able to optimize away unused record
elements.

One thing to mention regarding memory, is that it is now necessary to actively
make use of the signal `read_i`. This is because after a successful read an
idle (i.e. non-read) clock cycle may change the address, and this should not
change the instruction read from memory. In other words, the module
`read_instruction.vhd` relies on being able to read the instruction at a later
clock cycle.

Test coverage:

* `test2.asm` fails first at 0x0149, which is approximately 6% of the whole test.

Pipeline statistics (when reading from 0x0149):

* Clock cycles : 343
* Instructions : 167
* Cycles per instruction : 343/167 = 2.05
* Memory cycles : 280
* Memory stalls : 113
* Memory utilization : 280/343 = 82%
* Register write cycles : 133
* Register write stalls : 0
* Register write utilization : 133/343 = 39%

Resource utilization:

* Slice LUTs : 632
* Slice Registers : 185
* Slices : 185

Timing:

* The slowest timing path has a slack of 7.3 ns (at 50 MHz) and a logic depth
  of 11 levels.  This suggests a maximum frequency of 1000/(20-7.3) = 78 MHz.

First of all, the timing is now much better than before, with a maximum
frequency of 78 MHz compared to 53 Mhz previously.

It is very interesting to compare the above numbers with the previous version,
which reached exactly the same address too.

The new version fetches many more instructions (167 versus 118). This is due
to the branch mis-predictions. On the other hand, fewer clock cycles are used
in total (343 versus 445). This is again due to the faster branch handling.

The register write cycles has decreased (from 210 to 133). This is because
branches taken, i.e. updating PC, is now handled "directly" by the register
file and is no longer implemented as a generic register write.

## Fixing pipeline hazards (again)
This time I'm trying a different approach to pipeline hazards. Instead of
copying a value from a later stage to an earlier stage, I rather try to delay
the earlier stage in case of a pipeline hazard. The reason for this is that the
data copying introduces long combinatorial paths that reduce the maximum
clock frequency.

This new appeoach amounts to the signal `wait_o` from stage 2 to stage 1. This
signal is used if the PC is being updated (e.g. a @PC++ operand), in which case
the next instruction fetch is delayed.

In stage 2 I can furthermore detect whether there is a register collision, in
which case the stage just waits for one clock cycle.

With these changes, the test now runs all the way to the `RSUB` instruction,
which is still not implemented.

Test coverage:

* `test2.asm` fails first at 0x0424, which is approximately 20% of the whole test.

Pipeline statistics (when reading from 0x0424):

* Clock cycles : 1376
* Instructions : 540
* Cycles per instruction : 1376/540 = 2.55
* Memory cycles : 1006
* Memory stalls : 26
* Memory utilization : 1006/1376 = 73%
* Register write cycles : 475
* Register write stalls : 0
* Register write utilization : 475/1376 = 35%

Resource utilization:

* Slice LUTs : 671
* Slice Registers : 206
* Slices : 204

Timing:

* The slowest timing path has a slack of 6.6 ns (at 50 MHz) and a logic depth of 13
  levels.  This suggests a maximum frequency of 1000/(20-6.6) = 74 MHz.

The slowest timing path is the signal `write_result.dst_operand`, which comes
directly out of a Block RAM and into the ALU. However, adding a register to
this signal has little to no effect on the overall timing, because there is
also another long timing path through the instruction decoding in stage 2 into
the stage 1 and then the register file. So it seems already at this stage that
we have reached the limit of what this design can achieve.

Since reading from a Block RAM itself takes over 2 ns, it could be relevant to
add (another) register to the memory output. This would require yet another
redesign of the pipeline, so let's not go there just yet.

## Implementing `RSUB` and `ASUB`
The RSUB instruction is quite complicated since it must:
* Read source operand (potentially from memory, potentially updating source register)
* Write `PC` to memory (pointed to by `SP`)
* Decrement `SP`.
In order to simplify the implementation (and to reduce the load on the register
arbiter) I've decided to let the register file treat the `SP` as a special
register, just like the `PC` and the `SR`.

So the register file now has some new signals `sp_o`, `res_wr_spi_i`, and
`res_sp_i`. The treatment of the `SP` in the register file is analogous to the
`PC`.

The instruction decoding in `read_src_operand` now has a new output signal
`res_reg_sp_update` that is asserted only during `ASUB` and `RSUB`.
Additionally, the signals `res_mem_wr_request` and `res_mem_wr_address`
are modified to allow write to memory.

Similarly, the `write_result.vhd` is updated to allow writing to memory of the
`PC` as well as the `ALU`.  And that is it! The pipelined CPU can now perform
`RSUB` and `ASUB`.

The next thing missing are the instructions `INCRB` and `DECRB`. So before
implementing those, I'll add support for register banking.

## Implementing register banking and fixing more bugs
The `INCRB` and `DECRB` instructions are relatively easy to implement. I've
chosen to implement them inside the ALU. The biggest changes are in the file
`cpu_constants.vhd`, where the disassembler now supports the control
instructions.

Pipeline hazards I've chosen to handle by delaying any instructions that
read the SR. This is done quite simply in `read_src_operand.vhd` using
the already existing `reg_collision`.

Adding support for register banking was done entirely within the register file.

And finally, the CPU test suite shows its worth and uncovered a few trivial
bugs in the ALU.

The test now runs much further, and fails when executing the following two
instructions:
```
MOVE    R0, @R4
MOVE    @R1, @--R2
```
What currently happens is that stage 2 reads from `R1` and only in the next
clock cycle does stage 4 write to `R4`.  The problem is that `R4` and `R1`
point to the same location in memory, so we here have a data hazard.

Test coverage:

* `test2.asm` fails first at 0x0C05, which is approximately 57% of the whole test.

Pipeline statistics (when reading from 0x0C05):

* Clock cycles : 20590
* Instructions : 7936
* Cycles per instruction : 20590/7936 = 2.59
* Memory cycles : 14143
* Memory stalls : 1337
* Memory utilization : 14143/20590 = 69%
* Register write cycles : 8562
* Register write stalls : 0
* Register write utilization : 8562/20590 = 42%

Resource utilization:

* Slice LUTs : 2580
* Slice Registers : 259
* Slices : 727

Timing:

* The slowest timing path has a slack of 1.5 ns (at 50 MHz) and a logic depth of 12
  levels.  This suggests a maximum frequency of 1000/(20-1.5) = 54 MHz.

So we see that the frequency has gone down significantly. This is due to the
register file.  The slowest timing paths are seen to be in `read_src_operand`,
where an instruction is read from memory, the source register is read from the
register file, this source register is incremented, and finally written back to
the register file.

There is an optimization opportunity here, but would require redesigning the
pipeline yet again. The crucial point is that any instruction will only ever
write twice to the register file, yet we currenly support writes from three
different stages. Furthermore, the instruction decoding and reading from memory
is only performed in stage 2. So if register writes can be concentrated to
only stages 3 and 4, the timing should improve.

## Timing optimization
So before fixing more pipeline hazards I decided to implement the timing
optimization suggested just above, i.e. to have only stages 3 and 4 write to
the register file. This reduces the amount of work done in stage 2, and
specifically stage 2 no longer writes to the register file.

The module `arbiter_regs` is greatly simplified now, and the file
`read_dst_operand.vhd` now just updates the source register instead of the
destination register. Similarly, the file `write_result.vhd` simply multiplexes
between updating a register operand and write a result to the register.

The file `read_src_operand.vhd` turned out to need some more pipeline hazard
detection. The reason is that instructions involving e.g. @PC++ as the source
operand now update the PC in stage 3 and not in stage 2. This could be resolved
by expanding the signal `reg_collision` with detecting explicite updates to the
PC register.

And with these changes the test runs just like before, and fails at address
0x0C05.  Unfortunately, the pipeline statistics have worsened:

Pipeline statistics (when reading from 0x0C05):

* Clock cycles : 22626
* Instructions : 7360
* Cycles per instruction : 22626/7360 = 3.07
* Memory cycles : 19536
* Memory stalls : 1341
* Memory utilization : 19536/22626 = 86%
* Register write cycles : 8562
* Register write stalls : 0
* Register write utilization : 8562/22626 = 38%

But the timing is better:

Resource utilization:

* Slice LUTs : 2603
* Slice Registers : 294
* Slices : 726

Timing:

* The slowest timing path has a slack of 3.6 ns (at 50 MHz) and a logic depth of 10
  levels.  This suggests a maximum frequency of 1000/(20-3.6) = 61 MHz.

The slowest timing paths are still in `read_src_operand`, this time reading and
decoding an instruction from memory, reading the source register from the
register file, and finally reading the source operand value from memory.  This
seems difficult to optimize, because the above is indeed a description of all
the work required in this stage.

However, examining the timing path in more detail shows that a lot of the delay
is due to routing delay. This is because the register file is very large
(256\*8\*16 = 32k bits), and implemented in LUT RAM.  Each LUT RAM is very
small, so the register file needs a lot of them, in fact the utilization report
shows that 1432 LUT RAMs are used, distributed over 528 slices. In other words,
the register file consumes a large **area** of the FPGA, and this leads to
large routing delays. Indeed, the timing report shows that the path through the
register file alone is around 9.5 ns.

Perhaps it is possible to re-implement the register file using Block RAMs
clocked on the falling clock (yes, that again!), thus consuming a much smaller
area.  The downside is that only half a clock cycle is available, and reading
from Block RAMs is quite slow. This will require some experimenting to
determine, whether this proposed optimization will work.

So I just did a test by adding a `falling_edge` triggered flip-flop when
reading in the register file.  Note that the simulation test still runs as
before, because the `falling_edge` does not change the semantics of the
pipeline.  The timing of this change is slightly worse, i.e. now a frequency of
55 MHz.  The overall size of the design is much smaller, as predicted, but the
timing is limited by the half clock cycle. So this would suggest that
implementing synchronous reads from the register file will improve performance.
Alas, this requires (again) another redesign of the pipeline.

In order to get a rough estimate of the potential performance improvement, I've
temporarily changed the `falling_edge` to `rising_edge` when reading from the
register file. This now breaks the semantics of the pipeline, but I can still
run synthesis and implementation to see the timing report.

This time the freqency jumps up to 67 MHz. The longest timing path is now in
stage 4 where the destination operand is received from memory, processed in the
ALU and updates the `SR` in the register file. This suggests that there should
be (another) register on the memory output.

It's too soon to draw any conclusions, but there does seem to be still some
options for timing optimizations.

To be continued...

