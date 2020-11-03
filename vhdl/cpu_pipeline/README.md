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
introduce flip-flops when reading from register file and/or memory, in order to
increase the clock frequency. However, in order to keep the design as simple as
possible, this is deferred to later.

So far, the design looks as follows:

![Pipeline Design](design.png)

The important design decisions are as follows:
* There are four stages.
* Each stage receives input in the same clock cycle as providing the output.

In other words, the horizontal connections are combinatorial. The vertical
connections are registered. The registering is depicted with the thick
horiontal bars where the connections originate from.

Important constants (e.g. instruction decoding) is placed in the package file
`cpu_constants.vhd`.

## Pipeline flow and back pressure
Data usually flows from stage to stage on every clock cycle. However, sometimes
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
PC to the LED outputs.

I've written a small simulation testbench that instantiates this top level
entity and provides clock and reset.

### Test methodology
So the test methodology is to write one or more small assembly program and
place them in the file e.g. `test1.asm`. Then to start the test simply type:

```
make test1
```

This will assemble the file `test1.asm` into binary data in the file
`prog.rom`, which is used to initialize the memory. Then the PC is reset
(currently to 0x0010), and the CPU starts executing!

Verification is done by manually inspecting the generated waveform.

