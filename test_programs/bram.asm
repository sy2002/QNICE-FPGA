; Block RAM test that includes running an application from RAM
; done by sy2002 in August 2015

IO$TIL_BASE     .EQU    0xFF10              ; address of TIL-display
RAM_VARIABLE    .EQU    0x8000              ; address of a variable in RAM
STACK_TOP       .EQU    0x8010              ; top of the stack
EXE_START       .EQU    0x8011              ; start address of code in RAM

                .ORG    0x0000

                ; copy source code to RAM to execute it there
                ; this tests multiple things, also, if relative jumps
                ; are really working and if opcode fetches also work in RAM

                MOVE CODE_END, R0           ; end of "to-be-copied-code"
                MOVE CODE_START, R1         ; run variable for copying: source
                MOVE EXE_START, R2          ; run variable for copying: dest
                MOVE 1, R3                  ; we need to subtract 1 often
                SUB R1, R0                  ; how many bytes to copy - 1
                                            ; as the last opcode 2 bytes
                
COPY_CODE       MOVE @R1++, @R2++           ; copy from src to dst
                SUB R3, R0                  ; one less item to go
                RBRA COPY_CODE, !N          ; R0 is #bytes-1, so check for !N
                                            ; instead of checking for !Z

                ABRA EXE_START, 1           ; execute code from RAM

                ; this is the test code that tests BRAM operations
                ; and the stack and sub routine calls
                ; it should show 0x2309 on the TIL on success

CODE_START      MOVE IO$TIL_BASE, R12       ; TIL display address
                MOVE RAM_VARIABLE, R0       ; address of a variable in RAM
                MOVE STACK_TOP, R13         ; setup stack pointer

                MOVE 0x22EE, @R0            ; write 0x22EE to variable in BRAM
                RSUB ADD_IT, 1              ; use a sub routine to add 0x09
                RSUB ADD_IT, 1              ; ... multiple times ...   
                RSUB ADD_IT, 1              ; ... to the variable in BRAM

                MOVE @R0, @R12              ; display 0x2309 on the TIL

                HALT

ADD_IT          ADD 0x0009, @R0             ; add 9 to BRAM's 0x8000
CODE_END        MOVE @R13++, R15            ; return from sub routine