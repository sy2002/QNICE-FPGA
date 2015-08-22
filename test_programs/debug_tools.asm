; utility routines for debugging
; sysdef.asm needs to be included before this
; done by sy2002 in August 2015

; copy code from one memory destination (e.g. ROM) to another (e.g. RAM)
; R8: amount of instruction words to copy
; R9: src, R10: dst
;
; CAUTION FOR R8: if the last opcode consists of two words, then better
; place the label one line later, e.g. to a .BLOCK 1 statement, otherwise
; the second word of the last opcode will not be copied

COPY_CODE       MOVE @R9++, @R10++          ; copy from src to dst
                SUB 1, R8                   ; one less item to go
                RBRA COPY_CODE, !N          ; R0 is decremented one time too
                                            ; much, so check for !N instead of
                                            ; checking for !Z
                RET                         ; return from sub routine

; sub routine to wait for about 1 second (assuming a ~10 MIPS operation)

WAIT_A_SEC      MOVE    0x1388, R8          ; inner wait cycles: 5.000 decimal
                MOVE    0x09C4, R9          ; outer wait cycles: 2.500 decimal
                RSUB    WAIT_A_WHILE, 1     ; wait
                RET                         ; return from sub routine

; sub routine to wait for R8 x R9 cycles

WAIT_A_WHILE    INCRB                       ; next register bank
                MOVE    R9, R1              ; outer wait cycles
WAS_WAIT_LOOP2  MOVE    R8, R0              ; inner wait cycles
WAS_WAIT_LOOP1  SUB     1, R0               ; dec inner wait cycles and ...
                RBRA    WAS_WAIT_LOOP1, !Z  ; ... repeat if not zero
                SUB     1, R1               ; dec outer wait cycles and ...
                RBRA    WAS_WAIT_LOOP2, !Z  ; ... repeat if not zero
                DECRB                       ; restore previous register bank
                RET                         ; return from sub routine
