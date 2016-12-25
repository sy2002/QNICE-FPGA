; Classical "Hello World!" example for getting started coding
; QNICE assembler using the native toolchain: First, it prints "Hello World!"
; and then it counts from 1 to 10 and prints "Count #x", where x is decimal
; and goes from 1 to 10. So besides the simple "Hellow World!" printing, this
; example also shows how to use "operating system" functions and how to do
; sub routine calls.
;
; While you are in the test_programs folder, enter the following line to
; compile and (if you are on a Mac) to automatically put the hello.out file
; into your clipboard so that you can directly copy/paste it to the Monitor
; using the M/L command. If you are on another OS, copy the hello.out file
; manually to your clipboard. Have a look at "README.md" in the main folder.
;
; ../assembler/asm hello.asm
;
; Start the program using the C/R command with the address 8000.
;
; done by sy2002 in December 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000                  ; start address is 0x8000

                MOVE    STR_HELLO, R8           ; pointer to "Hello World!"
                SYSCALL(puts, 1)                ; print on active stdout
                                                ; (stdout can be switched by
                                                ; using Switch #1 on the FPGA
                                                ; board between UART and VGA)
                RSUB    COUNT, 1                ; sub routine to count to 10                
                SYSCALL(exit, 1)                ; back to monitor

COUNT           INCRB                           ; increase register bank
                MOVE    1, R0                   ; begin counting from 1
                XOR     R9, R9                  ; R9 = 0
_COUNT_LOOP     MOVE    STR_COUNT, R8           ; pointer to "Count #"
                SYSCALL(puts, 1)                ; print on active stdout
                MOVE    R0, R8                  ; convert counter to decimal..
                MOVE    STR_COUNTER, R10        ; ..see documentation for..
                SYSCALL(h2dstr, 1)              ; STR$H2D, string_library.asm
                MOVE    R11, R8                 ; R11 = decimal without spaces
                SYSCALL(puts, 1)                ; print on stdout
                SYSCALL(crlf, 1)                ; next line
                ADD     1, R0                   ; continue counting
                CMP     R0, 11                  ; 11 means we counted to 10
                RBRA    _COUNT_LOOP, !Z         ; not yet, so next iteration
                DECRB                           ; decrease register bank
                RET                             ; return from subroutine

; String Constants
STR_HELLO       .ASCII_W "Hello World!\n"
STR_COUNT       .ASCII_W "Count #"

; Variables
STR_COUNTER     .BLOCK 11                       ; reserve 11 words memory
