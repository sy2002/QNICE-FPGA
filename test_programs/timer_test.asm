;
;  Testing timers. 
;
;  Jumping to the entry point 0x8000 initializes timer 0 to generate an 
; interrupt every 1000 milliseconds. The ISR just prints a message 
; every second.
;
;  Jumping to the entry point at 0x8100 disables the timer by setting 
; the INT-register of the timer to 0x0000.
;
#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0x8000
        MOVE    TT_1, R8
        SYSCALL(puts, 1)

        MOVE    IO$TIMER_0_PRE, R0
        MOVE    0x0064, @R0++   ; Prescaler = 100 -> 1 ms (based on a 100 kHz prescaler input)
        MOVE    0x03E8, @R0++   ; One interrupt per 1000 ms
        MOVE    ISR_T0, @R0++   ; Set the ISR address

        SYSCALL(exit, 1)

; This is the timer interrupt service routine:
ISR_T0  MOVE    ISR_T0T, R8
        SYSCALL(puts, 1)
        RTI

TT_1    .ASCII_W    "Setup timer 0 to interrupt every 1000 milliseconds.\n"
ISR_T0T .ASCII_W    "Timer 0 has issued an interrupt request!\n"

        .ORG    0x8100
; Turn off timer interrupts - this must be called manually!
TOFF    MOVE    IO$TIMER_0_INT, R0
        MOVE    0, @R0
        SYSCALL(exit, 1)
