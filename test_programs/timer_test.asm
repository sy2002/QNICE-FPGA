;
; Testing timers
;
; Jumping to the entry point 0xE000 initializes timer 0 to generate an 
; interrupt every 1000 milliseconds. The ISR just prints a message 
; every second.
;
; Jumping to the entry point at 0xE100 disables the timer by setting 
; the INT-register of the timer to 0x0000.
;
; done in July 2020 by vaxman and extended in August 2020 by sy2002

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0xE000

        ; ----------------------------------------------------
        ; register test of the timer interrupt device
        ; ----------------------------------------------------

        MOVE    IO$TIMER_0_PRE, R0
        MOVE    IO$TIMER_0_CNT, R1
        MOVE    IO$TIMER_0_INT, R2
        MOVE    IO$TIMER_1_PRE, R3
        MOVE    IO$TIMER_1_CNT, R4
        MOVE    IO$TIMER_1_INT, R5

        MOVE    0xFFFF, @R0
        MOVE    0xEEEE, @R1
        MOVE    0xDDDD, @R2
        MOVE    0xCCCC, @R3
        MOVE    0xBBBB, @R4
        MOVE    0xAAAA, @R5

        CMP     0xDDDD, @R2
        RBRA    A_HALT, !Z
        MOVE    0x0000, @R2     ; stop timer 0
        CMP     0xAAAA, @R5
        RBRA    A_HALT, !Z
        MOVE    0x0000, @R5     ; stop timer 1
        CMP     0xFFFF, @R0
        RBRA    A_HALT, !Z
        CMP     0xEEEE, @R1
        RBRA    A_HALT, !Z
        CMP     0xCCCC, @R3
        RBRA    A_HALT, !Z
        CMP     0xBBBB, @R4
        RBRA    A_HALT, !Z

        ; ----------------------------------------------------
        ; Install ISR for timer 0 with 1 sec period:
        ; Regularly prints a string on STDOUT
        ; ----------------------------------------------------

        MOVE    TT_1, R8
        SYSCALL(puts, 1)

        MOVE    IO$TIMER_0_PRE, R0
        MOVE    0x0064, @R0++   ; Prescaler = 100 -> 1 ms (based on a 100 kHz prescaler input)
        MOVE    0x03E8, @R0++   ; One interrupt per 1000 ms
        MOVE    ISR_T0, @R0++   ; Set the ISR address

        ; ----------------------------------------------------
        ; Install ISR for timer 1 with 40ms period:
        ; Displays a bouncing "ball" (O) on the first line
        ; of the VGA screen with 25 Hz
        ; ----------------------------------------------------

        MOVE    TT_2, R8
        SYSCALL(puts, 1)
        MOVE    IO$TIMER_1_PRE, R0
        MOVE    0x0064, @R0++   ; Prescaler = 100 -> 1 ms (based on a 100 kHz prescaler input)
        MOVE    0x0028, @R0++   ; One interrupt per 40 ms
        MOVE    ISR_T1, @R0++   ; Set the ISR address

        ; ----------------------------------------------------
        ; Display uninstall instructions and exit to Monitor
        ; ----------------------------------------------------        

        MOVE    TT_3,R8
        SYSCALL(puts, 1)
        SYSCALL(exit, 1)

STR_ERR .ASCII_W    "Timer Interrupt Device: Register write/read test failed.\n"
A_HALT  MOVE    STR_ERR, R8
        SYSCALL(puts, 1)
        SYSCALL(exit, 1)

        ; ----------------------------------------------------
        ; ISRs
        ; ----------------------------------------------------

; This is the timer 0 interrupt service routine
ISR_T0  MOVE    R8, @--SP       ; Do not modify registers in an ISR, so save R8

        MOVE    ISR_T0T, R8     ; Print message in ISR_T0T
        SYSCALL(puts, 1)
        MOVE    COUNTER, R8
        ADD     1, @R8
        MOVE    @R8, R8
        SYSCALL(puthex, 1)
        SYSCALL(crlf, 1)

        MOVE    @SP++, R8       ; Restore R8 from stack
        RTI                     ; Return from interrupt

; This is the timer 1 interrupt service routine
ISR_T1  INCRB

        MOVE    VGA$STATE, R0   ; save the old VGA state (incl. cursor)
        MOVE    @R0, @--SP 
        AND     0xFF9F, @R0     ; switch the cursor off

        MOVE    VGA$CR_X, R1    ; x,y coordinates for printing on VGA
        MOVE    VGA$CR_Y, R2
        MOVE    VGA$CHAR, R5    ; print at the position of the "turtle"
        MOVE    @R1, R6         ; save the original values
        MOVE    @R2, R7

        MOVE    CURSOR, R3      ; move the turtle cursor to the last pos
        MOVE    @R3, @R1
        MOVE    0, @R2
        MOVE    SCRSV, R4       ; restore the character that was "under"
        MOVE    @R4, @R5        ; the turtle at the last iteration

        MOVE    DIR, R0         ; are we moving to the right?
        CMP     0, @R0
        RBRA    _IT1L, !Z       ; no, to the left        
        CMP     79, @R1         ; did we already reach the right boundary?
        RBRA    _IT1RR, Z       ; yes
_IT1R1  ADD     1, @R1          ; next x-pos to the right
        RBRA    _IT1DR, 1       ; draw
_IT1RR  MOVE    1, @R0          ; change direction: move left
_IT1L   CMP     0, @R1          ; did we already reach the left boundary?
        RBRA    _IT1LL, Z       ; yes
        SUB     1, @R1          ; next x-pos to the left
        RBRA    _IT1DR, 1
_IT1LL  MOVE    0, @R0          ; change direction: move right
        RBRA    _IT1R1, 1
_IT1DR  MOVE    @R5, @R4        ; save what is under the turtle
        MOVE    'O', @R5        ; draw ball
        MOVE    @R1, @R3        ; save cursor X


_END    MOVE    @R1, R6         ; restore the original cursor pos values
        MOVE    @R2, R7

        MOVE    VGA$STATE, R0   ; restore the original VGA state
        MOVE    @SP++, @R0

        DECRB
        RTI

TT_1    .ASCII_W    "Setup timer 0 to interrupt every 1000 milliseconds.\n"
TT_2    .ASCII_W    "Setup timer 1 to interrupt every 40 milliseconds.\n"
TT_3    .ASCII_W    "Run E500 to halt the timers and uninstall the ISRs.\n"
ISR_T0T .ASCII_W    "Timer 0 has issued interrupt request #"

COUNTER .DW 0
CURSOR  .DW 0
SCRSV   .DW 32 ; space character
DIR     .DW 0

        ; ----------------------------------------------------
        ; Uninstaller: Call 0xE500 to uninstall the ISR
        ; ----------------------------------------------------

        .ORG    0xE500
; Turn off timer interrupts - this must be called manually!
TOFF    MOVE    IO$TIMER_0_INT, R0
        MOVE    0, @R0
        MOVE    IO$TIMER_1_INT, R0
        MOVE    0, @R0
        SYSCALL(exit, 1)
