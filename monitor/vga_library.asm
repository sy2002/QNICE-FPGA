;
;;=======================================================================================
;; The collection of VGA related function starts here
;;=======================================================================================
;

;
;***************************************************************************************
;* VGA$INIT
;*
;* VGA on, hardware cursor on, large, blinking, reset current character coordinates
;***************************************************************************************
;
VGA$INIT                INCRB
                        MOVE    VGA$STATE, R0
                        MOVE    0x00E0, @R0             ; Enable everything
                        OR      VGA$COLOR_GREEN, @R0    ; Set font color to green
                        OR      VGA$EN_HW_SCRL, @R0     ; Enable offset registers
                        XOR     R0, R0
                        MOVE    _VGA$X, R1
                        MOVE    R0, @R1                 ; Reset X coordinate
                        MOVE    VGA$CR_X, R1            ; Store it in VGA$CR_X
                        MOVE    R0, @R1                 ; ...and let the hardware know
                        MOVE    _VGA$Y, R1
                        MOVE    R0, @R1                 ; The same with Y...
                        MOVE    VGA$CR_Y, R1
                        MOVE    R0, @R1
                        MOVE    VGA$OFFS_DISPLAY, R1    ; Reset the display offset reg.
                        MOVE    R0, @R1
                        MOVE    VGA$OFFS_RW, R1         ; Reset the rw offset reg.
                        MOVE    R0, @R1
                        DECRB
                        RET
;
;***************************************************************************************
;* VGA$CHAR_AT_XY
;*
;* R8:  Contains character to be printed
;* R9:  X-coordinate (0 .. 79)
;* R10: Y-coordinate (0 .. 39)
;*
;* Output a single char at a given coordinate pair.
;***************************************************************************************
;
VGA$CHAR_AT_XY          INCRB
                        MOVE    VGA$CR_X, R0
                        MOVE    R8, @R0
                        MOVE    VGA$CR_Y, R0
                        MOVE    R9, @R0
                        MOVE    VGA$CHAR, R0
                        MOVE    R10, @R0
                        DECRB
                        RET
;
;***************************************************************************************
;* VGA$PUTCHAR
;*
;* Print a character to the VGA display. This routine automatically increments the
;* X- and, if necessary, the Y-coordinate. Scrolling is implemented - if the end of the
;* scroll buffer is reached after about 20 screen pages, the next character will cause
;* a CLS and then will be printed at location (0, 0) on screen page 0 again.
;*
;* This routine relies on the stored coordinates VGA$X and VGA$Y which always contain
;* the coordinate of the next (!) character to be displayed and will be updated 
;* accordingly. This implies that it is possible to perform other character output and
;* cursor coordinate manipulation between two calls to VGA$PUTC without disturbing
;* the position of the next character to be printed.
;*
;* R8: Contains the character to be printed.
;***************************************************************************************
;
; TODO: \t
;
VGA$PUTCHAR             INCRB
                        MOVE    VGA$CR_X, R0                ; R0 points to the HW X-register
                        MOVE    VGA$CR_Y, R1                ; R1 points to the HW Y-register
                        MOVE    _VGA$X, R2                  ; R2 points to the SW X-register
                        MOVE    _VGA$Y, R3                  ; R2 points to the SW X-register
                        MOVE    @R2, R4                     ; R4 contains the current X-coordinate
                        MOVE    @R3, R5                     ; R5 contains the current Y-coordinate
                        MOVE    R4, @R0                     ; Set the HW X-coordinate
                        MOVE    R5, @R1                     ; Set the HW Y-coordinate
; Before we output anything, let us check for 0x0A and 0x0D:
                        CMPU    0x000D, R8                  ; Is it a CR?
                        RBRA    _VGA$PUTC_NO_CR, !Z         ; No
                        XOR     R4, R4                      ; CR -> Reset X-coordinate
                        RBRA    _VGA$PUTC_END, 1            ; Update registers and exit
_VGA$PUTC_NO_CR         CMPU    0x000A, R8                  ; Is it a LF?
                        RBRA    _VGA$PUTC_NORMAL_CHAR, !Z   ; No, so just a normal character
                        ADD     0x0001, R5                  ; Increment Y-coordinate
                        MOVE    VGA$MAX_Y, R7               ; To utilize the full screen, we need...
                        ADD     1, R7                       ; ...to compare to 40 lines due to ADD 1, R5
                        CMPU    R7, R5                      ; EOScreen reached?
                        RBRA    _VGA$PUTC_END, !Z           ; No, just update and exit

                        MOVE    0, R8                       ; VGA$SCROLL_UP_1 in automatic mode
                        RSUB    VGA$SCROLL_UP_1, 1          ; Yes, scroll one line up...
                        CMPU    1, R8                       ; Wrap-around/clrscr happened?
                        RBRA    _VGA$PUTC_END_SKIP, Z       ; Yes: Leave the function w/o rundown

                        SUB     0x0001, R5                  ; No: Decrement Y-coordinate b/c we scrolled
;
                        MOVE    VGA$OFFS_RW, R7             ; Take care of the rw offset register
                        ADD     VGA$CHARS_PER_LINE, @R7
;
                        RBRA    _VGA$PUTC_END, 1            ; Update registers and exit
_VGA$PUTC_NORMAL_CHAR   MOVE    VGA$CHAR, R6                ; R6 points to the HW char-register
                        MOVE    R8, @R6                     ; Output the character
; Now update the X- and Y-coordinate still contained in R4 and R5:
                        CMPU    VGA$MAX_X, R4               ; Have we reached the EOL?
                        RBRA    _VGA$PUTC_1, !Z             ; No
                        XOR     R4, R4                      ; Yes, reset X-coordinate to 0 and
                        CMPU    VGA$MAX_Y, R5               ; check if we have reached EOScreen
                        RBRA    _VGA$PUTC_2, !Z             ; No

                        MOVE    0, R8                       ; VGA$SCROLL_UP_1 in automatic mode                        
                        RSUB    VGA$SCROLL_UP_1, 1          ; Yes, scroll one line up...
                        CMPU    1, R8                       ; Wrap-around/clrscr happened?
                        RBRA    _VGA$PUTC_END_SKIP, Z       ; Yes: Leave the function w/o rundown                        

                        MOVE    VGA$OFFS_RW, R7             ; Take care of the rw offset register
                        ADD     VGA$CHARS_PER_LINE, @R7
                        RBRA    _VGA$PUTC_END, 1            ; and finish
_VGA$PUTC_1             ADD     0x0001, R4                  ; Just increment the X-coordinate
                        RBRA    _VGA$PUTC_END, 1            ; and finish 
_VGA$PUTC_2             ADD     0x0001, R5                  ; Increment Y-coordinate and finish
; Rundown of the function
_VGA$PUTC_END           MOVE    R4, @R0                     ; Update the HW coordinates to
                        MOVE    R5, @R1                     ; display cursor at next location
                        MOVE    R4, @R2                     ; Store current coordinates in 
                        MOVE    R5, @R3                     ; _VGA$X and _VGA$Y
;
_VGA$PUTC_END_SKIP      DECRB
                        RET
;
;***************************************************************************************
;* VGA$SCROLL_UP_1
;*
;* Scroll one line up - this function only takes care of the display offset, NOT
;* of the read/write offset!
;*
;* R8 (input): 0 = scroll due to calculations, 1 = scroll due to key press
;* R8 (output): 0 = standard exit; 1 = clear screen was performed
;***************************************************************************************
;
VGA$SCROLL_UP_1         INCRB
                        MOVE    VGA$OFFS_DISPLAY, R0
                        MOVE    VGA$OFFS_RW, R1

                        ; calculate the new offset and only allow scrolling up, if ...
                        ;   a) ... the screen is full, i.e. we are at the
                        ;          last line, display offs = rw offs AND
                        ;          it is not the user who wants to scroll, but the system
                        ;   b) ... we scrolled down before, i.e. the display
                        ;          offset  < rw offset AND it is not the system who wants
                        ;          to scroll, but the user (no autoscroll but content is
                        ;          appended at the bottom)
                        ;   c) ... we would not wrap at 64.000, but in such a case clear
                        ;          the screen at reset the offsets
                        MOVE    0, R3                       ; perform a 32-bit subtraction...
                        MOVE    @R0, R2                     ; ...to find out, if display < rw...
                        MOVE    0, R5                       ; ...(R3R2) = 32-bit enhanced display...
                        MOVE    @R1, R4                     ; ...(R5R4) = 32-bit enhanced rw
                        SUB     R4, R2                      ; ...result in (R3R2)...
                        SUBC    R5, R3                      ; ...if negative, then highest bit of R3... 
                        SHL     1, R3                       ; ...is set, so move upper bit to Carry...
                        RBRA    _VGA$SCROLL_UP_1_CKR80, C   ; ...because if Carry, then display < rw

                        CMPU    @R1, @R0                    ; display = rw?
                        RBRA    _VGA$SCROLL_UP_1_CKR81, Z   ; yes: check R8
                        RBRA    _VGA$SCROLL_UP_1_NOP, 1     ; it is >, so skip

                        ; case display < rw
                        ; automatic scrolling when new content is written to the end
                        ; of the STDIN is disabled as soon as the user scrolled upwards
_VGA$SCROLL_UP_1_CKR80  CMPU    0, R8 
                        RBRA    _VGA$SCROLL_UP_1_NOP, Z
                        RBRA    _VGA$SCROLL_UP_1_DOIT, 1

                        ; case display = offs
                        ; do not scroll if the user wants to, but only if the
                        ; system needs to due to a calculation result
_VGA$SCROLL_UP_1_CKR81  CMPU    1, R8
                        RBRA    _VGA$SCROLL_UP_1_NOP, Z

                        ; avoid wrapping at 64.000: 60.800 is the last offset
                        ; we can support before resetting everything as
                        ; 64.000 - (80 x 40) = 60.800
                        CMPU    60800, @R0                  ; display = 60800?
                        RBRA    _VGA$SCROLL_UP_1_DOIT, !Z   ; no: scroll
                        RSUB    VGA$CLS, 1                  ; yes: clear screen...
                        MOVE    1, R8                       ; set clrscr flag
                        RBRA    _VGA$SCROLL_UP_1_END, 1     ; exit function

                        ; perform the actual scrolling
_VGA$SCROLL_UP_1_DOIT   ADD     VGA$CHARS_PER_LINE, @R0

                        ; if after the scrolling disp = rw, then show cursor
                        CMPU    @R1, @R0
                        RBRA    _VGA$SCROLL_UP_1_NOP, !Z
                        MOVE    VGA$STATE, R0
                        OR      VGA$EN_HW_CURSOR, @R0

_VGA$SCROLL_UP_1_NOP    MOVE 0, R8                          ; no clrscr happened
_VGA$SCROLL_UP_1_END    DECRB
                        RET

;
;***************************************************************************************
;* VGA$SCROLL_UP
;*
;* Scroll many lines up, smartly: As VGA$SCROLL_UP_1 is used in a loop, all cases
;* are automatically taken care of.
;*
;* R8 contains the amount of lines, R8 is not preserved
;***************************************************************************************
;
VGA$SCROLL_UP           INCRB
                        MOVE    R8, R0

_VGA$SCROLL_UP_LOOP     MOVE    1, R8                       ; use "manual" mode
                        RSUB    VGA$SCROLL_UP_1, 1          ; perform scrolling
                        SUB     1, R0                       
                        RBRA    _VGA$SCROLL_UP_LOOP, !Z

                        DECRB
                        RET
;
;***************************************************************************************
;* VGA$SCROLL_DOWN_1
;*
;* Scroll one line down
;***************************************************************************************
;
VGA$SCROLL_DOWN_1       INCRB
                        MOVE    VGA$OFFS_DISPLAY, R0

                        ; if the offset is 0, then do not scroll
                        MOVE    @R0, R1
                        RBRA    _VGA$SCROLL_DOWN_1_NOP, Z

                        ; do the actual scrolling
                        SUB     VGA$CHARS_PER_LINE, R1
                        MOVE    R1, @R0              

                        ; hide the cursor
                        MOVE    VGA$STATE, R0
                        NOT     VGA$EN_HW_CURSOR, R1
                        AND     R1, @R0

_VGA$SCROLL_DOWN_1_NOP  DECRB
                        RET
;
;***************************************************************************************
;* VGA$SCROLL_DOWN
;*
;* Scroll many lines down, smartly: As VGA$SCROLL_DOWN_1 is used in a loop, all cases
;* are automatically taken care of.
;*
;* R8 contains the amount of lines, R8 is not preserved
;***************************************************************************************
;
VGA$SCROLL_DOWN         INCRB
                        MOVE    R8, R0

_VGA$SCROLL_DOWN_LOOP   RSUB    VGA$SCROLL_DOWN_1, 1        ; perform scrolling
                        SUB     1, R0                       
                        RBRA    _VGA$SCROLL_DOWN_LOOP, !Z

                        DECRB
                        RET
;
;***************************************************************************************
;* VGA$SCROLL_HOME_END
;*
;* Uses the "_1" scroll routines to scroll to the very top ("Home") or to the very
;* bottom("End"). As we are looping the "_1" functions, all special cases are
;* automatically taken care of.
;*
;* R8 = 0: HOME  R8 = 1: END
;***************************************************************************************
;
VGA$SCROLL_HOME_END     INCRB
                        MOVE    VGA$OFFS_DISPLAY, R0
                        MOVE    VGA$OFFS_RW, R1

                        CMPU    1, R8                       ; scroll to END?
                        RBRA    _VGA$SCRL_HOME_END_E, Z

                        ; Scroll to the very top ("Home")
_VGA$SCRL_HOME_END_H    CMPU    0, @R0                      ; Home reached?
                        RBRA    _VGA$SCRL_HOME_END_EOF, Z   ; yes
                        RSUB    VGA$SCROLL_DOWN_1, 1        ; no: scroll down
                        RBRA    _VGA$SCRL_HOME_END_H, 1          

                        RBRA _VGA$SCRL_HOME_END_EOF, 1

                        ; Scroll to the very bottom ("End")                        
_VGA$SCRL_HOME_END_E    CMPU    @R1, @R0                    ; End reached?
                        RBRA    _VGA$SCRL_HOME_END_EOF, Z   ; Yes
                        MOVE    1, R8                       ; No: scroll up in ... 
                        RSUB    VGA$SCROLL_UP_1, 1          ; ... "manual" scrolling mode
                        RBRA    _VGA$SCRL_HOME_END_E, 1 

_VGA$SCRL_HOME_END_EOF  DECRB
                        RET
;
;***************************************************************************************
;* VGA$CLS
;*
;* Clear the VGA-screen and place the cursor in the upper left corner.
;***************************************************************************************
;
VGA$CLS                 INCRB
                        XOR     R0, R0
                        MOVE    _VGA$X, R1          ; Clear the SW X-register
                        MOVE    R0, @R1
                        MOVE    _VGA$Y, R1          ; Clear the SW Y-register
                        MOVE    R0, @R1
; Reset hardware cursor address
                        MOVE    VGA$CR_X, R1        ; Store it in VGA$CR_X
                        MOVE    R0, @R1             ; ...and let the hardware know
                        MOVE    _VGA$Y, R1
                        MOVE    R0, @R1             ; The same with Y...
; Reset scrolling registers
                        MOVE    VGA$OFFS_DISPLAY, R1
                        MOVE    R0, @R1
                        MOVE    VGA$OFFS_RW, R1
                        MOVE    R0, @R1
; Actually clear screen (and all screen pages in the video RAM)
                        MOVE    VGA$STATE, R0
                        OR      VGA$CLR_SCRN, @R0
; Wait until screen is cleared
_VGA$CLS_WAIT           MOVE    @R0, R1
                        AND     VGA$CLR_SCRN, R1
                        RBRA    _VGA$CLS_WAIT, !Z

                        DECRB
                        RET
