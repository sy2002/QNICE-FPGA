; New gets library function for the monitor: development testbed
; Works together with c/test_programs/gets_test.c and therefore
; starts at 0xE000. Load this program first, before executing gets_test.c
;
; gets_test.c expects the following 4 words as a "magic" at 0xE000:
; 0xFF90, 0x0016, 0x2309, 0x1976
; It further expects the entry point of GETS to be 0xE004
;
; done by sy2002 in October 2016
; enhanced by sy2002 to support gets_s and gets_slf in December 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0xE000

                SYSCALL(exit, 1)        ; 0xE000: 0xFF90 0x0016
                .DW 0x2309, 0x1976      ; 0xE002: 0x2309 0x1976
                                        ; 0xE004: GETS entry for gets_test.c

;===================== REUSABLE CODE FOR MONITOR STARTS HERE =================
;
;***************************************************************************************
;* IO$GETS reads a zero terminated string from STDIN and echos typing on STDOUT
;*
;* ALWAYS PREFER IO$GETS_S OVER THIS FUNCTION!
;*
;* It accepts CR, LF and CR/LF as input terminator, so it directly works with various
;* terminal settings on UART and also with keyboards on PS/2 ("USB"). Furtheron, it
;* accepts BACKSPACE for editing the string.
;*
;* R8 has to point to a preallocated memory area to store the input line
;***************************************************************************************
;
IO$GETS         MOVE    R9, @--SP           ; save original R9
                MOVE    R10, @--SP          ; save original R10
                XOR     R9, R9              ; R9 = 0: unlimited chars
                XOR     R10, R10            ; R10 = 0: no LF at end of str.
                RSUB    IO$GETS_CORE, 1     ; get the unlimited string
                MOVE    @SP++, R10          ; restore original R10
                MOVE    @SP++, R9           ; restore original R9
                RET
;
;***************************************************************************************
;* IO$GETS_S reads a zero terminated string from STDIN into a buffer with a
;*           specified maximum size and echos typing on STDOUT
;*
;* It accepts CR, LF and CR/LF as input terminator, so it directly works with various
;* terminal settings on UART and also with keyboards on PS/2 ("USB"). Furtheron, it
;* accepts BACKSPACE for editing the string.
;*
;* A maximum amount of (R9 - 1) characters will be read, because the function will
;* add the zero terminator to the string, which then results in R9 words.
;*
;* R8 has to point to a preallocated memory area to store the input line
;* R9 specifies the size of the buffer, so (R9 - 1) characters can be read;
;*    if R9 == 0, then an unlimited amount of characters is being read
;***************************************************************************************
;
IO$GETS_S       MOVE    R10, @--SP          ; save original R10
                XOR     R10, R10            ; R10 = 0: no LF at end of str.
                RSUB    IO$GETS_CORE, 1     ; get string
                MOVE    @SP++, R10          ; restore original R10
                RET
;
;***************************************************************************************
;* IO$GETS_SLF reads a zero terminated string from STDIN into a buffer with a specified
;*             maximum size and echos typing on STDOUT. A line feed character is added
;*             to the string in case the function is ended not "prematurely" by
;*             reaching the buffer size, but by pressing CR or LF or CR/LF.
;*
;* It accepts CR, LF and CR/LF as input terminator, so it directly works with various
;* terminal settings on UART and also with keyboards on PS/2 ("USB"). Furtheron, it
;* accepts BACKSPACE for editing the string.
;*
;* A maximum amount of (R9 - 1) characters will be read, because the function will
;* add the zero terminator to the string, which then results in R9 words.
;*
;* R8 has to point to a preallocated memory area to store the input line
;* R9 specifies the size of the buffer, so (R9 - 1) characters can be read;
;*    if R9 == 0, then an unlimited amount of characters is being read
;***************************************************************************************
;
IO$GETS_SLF     MOVE    R10, @--SP          ; save original R10
                MOVE    1, R10              ; R10 = 1: add LF, if the function
                                            ; ends regularly, i.e. by a key
                                            ; stroke (LF, CR or CR/LF)
                RSUB    IO$GETS_CORE, 1     ; get string
                MOVE    @SP++, R10          ; restore original R10
                RET
;
;***************************************************************************************
;* IO$GETS_CORE implements the various gets variants.
;*
;* Refer to the comments for IO$GETS, IO$GET_S and IO$GET_SLF
;*
;* R8  has to point to a preallocated memory area to store the input line
;* R9  specifies the size of the buffer, so (R9 - 1) characters can be read;
;*     if R9 == 0, then an unlimited amount of characters is being read
;* R10 specifies the LF behaviour: R10 = 0 means never add LF, R10 = 1 means: add a
;*     LF when the input is ended by a key stroke (LF, CR or CR/LF) in contrast to
;*     automatically ending due to a full buffer
;***************************************************************************************
;
IO$GETS_CORE    INCRB
                MOVE    R10, @--SP          ; save original R10
                MOVE    R11, @--SP          ; save original R11
                MOVE    R12, @--SP          ; save original R12

                MOVE    R10, R12            ; R12 = add LF flag
                XOR     R11, R11            ; R11 = character counter = 0
                MOVE    R9, R10             ; R10 = max characters
                SUB     1, R10              ; R10 = R9 - 1 characters

                MOVE    R8, R0              ; save original R8
                MOVE    R8, R1              ; R1 = working pointer

_IO$GETS_LOOP   CMP     R9, 0               ; unlimited characters?
                RBRA    _IO$GETS_GETC, Z    ; yes
                CMP     R11, R10            ; buffer size - 1 reached?
                RBRA    _IO$GETS_ZT, Z      ; yes: add zero terminator
                ADD     1, R11              ; no: next character

_IO$GETS_GETC   SYSCALL(getc, 1)            ; get char from STDIN
                CMP     R8, 0x000D          ; accept CR as line end
                RBRA    _IO$GETS_CR, Z
                CMP     R8, 0x000A          ; accept LF as line end
                RBRA    _IO$GETS_LF, Z
                CMP     R8, 0x0008          ; use BACKSPACE for editing
                RBRA    _IO$GETS_BS, Z
                CMP     R8, 0x007F          ; treat DEL key as BS, e.g. for ..
                RBRA    _IO$GETS_DEL, Z     ; .. MAC compatibility in EMU
_IO$GETS_ADDBUF MOVE    R8, @R1++           ; store char to buffer
_IO$GETS_ECHO   SYSCALL(putc, 1)            ; echo char on STDOUT
                RBRA    _IO$GETS_LOOP, 1    ; next character

_IO$GETS_LF     CMP     R12, 0              ; evaluate LF flag
                RBRA    _IO$GETS_ZT, Z      ; 0 = do not add LF flag
                MOVE    0x000A, @R1++       ; add LF

_IO$GETS_ZT     MOVE    0, @R1              ; add zero terminator
                MOVE    R0, R8              ; restore original R8

                MOVE    @SP++, R12          ; restore original R12
                MOVE    @SP++, R11          ; restore original R11
                MOVE    @SP++, R10          ; restore original R10
                DECRB
                RET

                ; For also accepting CR/LF, we need to do a non-blocking
                ; check on STDIN, if there is another character waiting.
                ; IO$GETCHAR is a blocking call, so we cannot use it here.
                ; STDIN = UART, if bit #0 of IO$SWITCH_REG = 0, otherwise
                ; STDIN = PS/2 ("USB") keyboard
                ;
                ; At a terminal speed of 115200 baud = 14.400 chars/sec
                ; (for being save, let us assume only 5.000 chars/sec)
                ; and a CPU frequency of 50 MHz we need to wait about
                ; 10.000 CPU cycles until we check, if the terminal program
                ; did send one other character. The loop at GETS_CR_WAIT
                ; costs about 7 cycles per iteration, so we loop (rounded up)
                ; 2.000 times.
                ; As a simplification, we assume the same waiting time
                ; for a PS/2 ("USB") keyboard

_IO$GETS_CR     MOVE    2000, R3            ; CPU speed vs. transmit speed
_IO$GETS_CRWAIT SUB     1, R3
                RBRA    _IO$GETS_CRWAIT, !Z

                MOVE    IO$SWITCH_REG, R2   ; read the switch register
                MOVE    @R2, R2
                AND     0x0001, R2          ; lowest bit set?
                RBRA    _IO$GETS_CRUART, Z  ; no: read from UART

                MOVE    IO$KBD_STATE, R2    ; read the keyboard status reg.
                MOVE    @R2, R2
                AND     0x0001, R2          ; char waiting/lowest bit set?
                RBRA    _IO$GETS_LF, Z      ; no: then add zero term. and ret.

                MOVE    IO$KBD_DATA, R2     ; yes: read waiting character
                MOVE    @R2, R2
                RBRA    _IO$GETS_CR_LF, 1   ; check for LF


_IO$GETS_CRUART MOVE    IO$UART_SRA, R2     ; read UART status register
                MOVE    @R2, R2
                AND     0x0001, R2          ; is there a character waiting?
                RBRA    _IO$GETS_LF, Z      ; no: then add zero term. and ret.

                MOVE    IO$UART_RHRA, R2    ; yes: read waiting character
                MOVE    @R2, R2

_IO$GETS_CR_LF  CMP     R2, 0x000A          ; is it a LF (so we have CR/LF)?
                RBRA    _IO$GETS_LF, Z      ; yes: then add zero trm. and ret.

                ; it is CR/SOMETHING, so add both: CR and "something" to
                ; the string and go on waiting for input, but only of the
                ; buffer is large enough. Otherwise only add CR.
                MOVE    0x000D, @R1++       ; add CR
                CMP     R9, 0               ; unlimited characters?
                RBRA    _IO$GETS_CRSS, Z    ; yes: go on and add SOMETHING
                CMP     R11, R10            ; buffer size - 1 reached?
                RBRA    _IO$GETS_ZT, Z      ; yes: add zero terminator and end
                ADD     1, R11              ; increase amount of stored chars                
_IO$GETS_CRSS   MOVE    R2, R8              ; no: prepare to add SOMETHING
                RBRA    _IO$GETS_ADDBUF, 1  ; add it to buffer and go on

                ; handle BACKSPACE for editing and accept DEL as alias for BS
                ;
                ; For STDOUT = UART it is kind of trivial, because you "just"
                ; need to rely on the fact, that the terminal settings are
                ; correct and then the terminal program takes care of the
                ; nitty gritty details like moving the cursor and scrolling.
                ;
                ; For STDOUT = VGA, this needs to be done manually by this
                ; routine.

_IO$GETS_DEL    MOVE    0x0008, R8          ; treat DEL as BS
_IO$GETS_BS     SUB     1, R11              ; do not count DEL/BS character
                CMP     R0, R1              ; beginning of string?
                RBRA    _IO$GETS_LOOP, Z    ; yes: ignore BACKSPACE key

                SUB     1, R1               ; delete last char in memory
                SUB     1, R11              ; do not count last char in mem.                

                MOVE    IO$SWITCH_REG, R2   ; read the switch register
                MOVE    @R2, R2
                AND     0x0002, R2          ; bit #1 set?
                RBRA    _IO$GETS_ECHO, Z    ; no: STDOUT = UART: just echo

                MOVE    VGA$CR_X, R2        ; R2: HW X-register
                MOVE    VGA$CR_Y, R3        ; R3: HW Y-register
                MOVE    VGA$CHAR, R4        ; R4: HW put/get character reg.
                MOVE    _VGA$X, R5          ; R5: SW X-register
                MOVE    _VGA$Y, R6          ; R6: SW Y-register

                CMP     @R2, 0              ; cursor already at leftmost pos.?
                RBRA    _IO$GETS_BSLUP, Z   ; yes: scroll one line up

                SUB     1, @R2              ; cursor one position to the left
                SUB     1, @R5
_IO$GETS_BSX    MOVE    0x0020, @R4         ; delete char on the screen
                RBRA    _IO$GETS_LOOP, 1    ; next char/key

_IO$GETS_BSLUP  CMP     @R3, VGA$MAX_Y      ; cursor already bottom line?
                RBRA    _IO$GETS_BSSUP, Z   ; yes: scroll screen up

                SUB     1, @R3              ; cursor one line up
                SUB     1, @R6
_IO$GETS_BSXLU  MOVE    VGA$MAX_X, @R2      ; cursor to the rightpost pos.
                MOVE    VGA$MAX_X, @R5
                RBRA    _IO$GETS_BSX, 1     ; delete char on screen and go on

_IO$GETS_BSSUP  MOVE    VGA$OFFS_DISPLAY, R7        ; if RW > DISP then do not
                MOVE    VGA$OFFS_RW, R8             ; scroll up the screen
                CMP     @R8, @R7                    ; see VGA$SCROLL_UP_1 for
                RBRA    _IO$GETS_BSUPSP, N          ; an explanation

                SUB     VGA$CHARS_PER_LINE, @R7     ; do the visual scrolling
_IO$GETS_BSUPSP SUB     VGA$CHARS_PER_LINE, @R8     ; scroll the RW window

                CMP     @R7, @R8                    ; if after the scrolling
                RBRA    _IO$GETS_NOCRS, !Z          ; RW = DISP then show
                MOVE    VGA$STATE, R8               ; the cursor
                OR      VGA$EN_HW_CURSOR, @R8

_IO$GETS_NOCRS  MOVE    VGA$MAX_Y, @R3              ; cursor to bottom
                MOVE    VGA$MAX_Y, @R6
                RBRA    _IO$GETS_BSXLU, 1           ; cursor to rightmost pos.

;===================== REUSABLE CODE FOR MONITOR ENDS HERE ===================

#include "../monitor/variables.asm"
