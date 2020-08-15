#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0x8000

        MOVE    IO$TIMER_0_PRE, R0
        MOVE    IO$TIMER_0_CNT, R1
        MOVE    IO$TIMER_0_INT, R2
        MOVE    IO$TIMER_1_PRE, R3
        MOVE    IO$TIMER_1_CNT, R4
        MOVE    IO$TIMER_1_INT, R5

        MOVE    1000, @R0
        MOVE    100,  @R1

        MOVE    1000, @R3
        MOVE    50,   @R4

        MOVE    T1, R8
        SYSCALL(puts, 1)

        MOVE    ISR1, @R2
        MOVE    ISR2, @R5

        SYSCALL(exit, 1)

ISR1    INCRB
        MOVE    R8, R0
        MOVE    ISR1_T, R8
        SYSCALL(puts, 1);
        MOVE    R0, R8
        DECRB
        RTI
ISR1_T  .ASCII_W    "Timer 0 triggered...\n"
        
ISR2    INCRB
        MOVE    R8, R0
        MOVE    ISR2_T, R8
        SYSCALL(puts, 1);
        MOVE    R0, R8
        DECRB
        RTI
ISR2_T  .ASCII_W    "Timer 1 triggered...\n"

T1      .ASCII_W    "Timers setup but not yet activated...\n"
