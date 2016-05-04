; Block RAM test that includes running an application from RAM
; initially done by sy2002 in August 2015
; reused/enhanced/modified for fixing the TriState issue in May 2016

#include "../dist_kit/sysdef.asm"

RAM_VARIABLE    .EQU    0x8000              ; address of a variable in RAM
STACK_TOP       .EQU    0x800F              ; top of the stack
EXE_START       .EQU    0x8010              ; start address of code in RAM

                .ORG    0x0000

                ; copy source code to RAM to execute it there
                ; this tests multiple things, also, if relative jumps
                ; are really working and if opcode fetches also work in RAM

                MOVE CODE_END, R0           ; end of "to-be-copied-code"
                MOVE CODE_START, R1         ; run variable for copying: source
                MOVE EXE_START, R2          ; run variable for copying: dest
                MOVE 1, R3                  ; we need to subtract 1 often
                SUB R1, R0                  ; how many words to copy
                                            ; caution: if the last opcode
                                            ; consists of two words, this 
                                            ; needs to be incremented or
                                            ; the label needs to be put one
                                            ; line below
                
COPY_CODE       MOVE @R1++, @R2++           ; copy from src to dst
                SUB R3, R0                  ; one less item to go
                RBRA COPY_CODE, !N          ; R0 is decremented one time too
                                            ; often so check for !N instead !Z

                ABRA EXE_START, 1           ; execute code from RAM

                ; this is the test code that tests BRAM operations
                ; and the stack and sub routine calls
                ; it should show 0x2309 on the TIL on success as it calculates
                ; 0x22DD + 0x11 + 0x9 + 0x9 + 0x9 = 0x2309

CODE_START      MOVE IO$TIL_DISPLAY, R12    ; TIL display address
                MOVE RAM_VARIABLE, R0       ; address of a variable in RAM
                MOVE STACK_TOP, R13         ; setup stack pointer

                MOVE 0x22DD, @R0++          ; write 0x22DD to variable in BRAM
                MOVE 0x0011, @R0            ; write 0x011 to another variable
                MOVE R0, R8                 ; remember the other variable

                ADD @R8, @--R0              ; nice "borderline case", as this
                                            ; is executed in BRAM (not in ROM)
                                            ; and uses a BRAM var. that is
                                            ; added to a BRAM variable
                                            ; plus there is a pre-decrement
                                            ; so that R0 points back to the
                                            ; original variable

                RSUB ADD_IT, 1              ; use a sub routine to add 0x09
                RSUB ADD_IT, 1              ; ... multiple times ...   
                RSUB ADD_IT, 1              ; ... to the variable in BRAM

                MOVE @R0, @R12              ; display 0x2309 on the TIL

                HALT

ADD_IT          ADD 0x0009, @R0             ; add 9 to BRAMs 0x8000
CODE_END        MOVE @R13++, R15            ; return from sub routine
