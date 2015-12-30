;
;;=======================================================================================
;; The collection of VGA related function starts here
;;=======================================================================================
;

;
;***************************************************************************************
;* Some constant definitions
;***************************************************************************************
;
VGA$MAX_X               .EQU    79                      ; Max. X-coordinate in decimal!
VGA$MAX_Y               .EQU    39                      ; Max. Y-coordinate in decimal!
VGA$MAX_CHARS           .EQU    3200                    ; VGA$MAX_X * VGA$MAX_Y
;
VGA$COLOR_RED           .EQU    0x0004
VGA$COLOR_GREEN         .EQU    0x0002
VGA$COLOR_BLUE          .EQU    0x0001
VGA$COLOR_WHITE         .EQU    0x0007
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
                        RSUB    VGA$CLS, 1              ; Clear the screen
                        XOR     R0, R0
                        MOVE    _VGA$X, R1
                        MOVE    R0, @R1                 ; Reset X coordinate
                        MOVE    VGA$CR_X, R1            ; Store it in VGA$CR_X
                        MOVE    R0, @R1                 ; ...and let the hardware know
                        MOVE    _VGA$Y, R1
                        MOVE    R0, @R1                 ; The same with Y...
                        MOVE    VGA$CR_Y, R1
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
;* X- and, if necessary, the Y-coordinate. No scrolling is currently implemented - 
;* if the end of the screen is reached, the next character will be printed at location
;* (0, 0) again. I.e. this functions implements a rather crude type-writer.
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
                        CMP     0x000D, R8                  ; Is it a CR?
                        RBRA    _VGA$PUTC_NO_CR, !Z         ; No
                        XOR     R4, R4                      ; CR -> Reset X-coordinate
                        RBRA    _VGA$PUTC_END, 1            ; Update registers and exit
_VGA$PUTC_NO_CR         CMP     0x000A, R8                  ; Is it a LF?
                        RBRA    _VGA$PUTC_NORMAL_CHAR, !Z   ; No, so just a normal character
                        ADD     0x0001, R5                  ; Increment Y-coordinate
                        CMP     VGA$MAX_Y, R5               ; EOScreen reached?
                        RBRA    _VGA$PUTC_END, !Z           ; No, just update and exit
                        XOR     R5, R5                      ; Yes, reset Y-coordinate
                        RBRA    _VGA$PUTC_END, 1            ; Update registers and exit
_VGA$PUTC_NORMAL_CHAR   MOVE    VGA$CHAR, R6                ; R6 points to the HW char-register
                        MOVE    R8, @R6                     ; Output the character
; Now update the X- and Y-coordinate still contained in R4 and R5:
                        CMP     VGA$MAX_X, R4               ; Have we reached the EOL?
                        RBRA    _VGA$PUTC_1, !Z             ; No
                        XOR     R4, R4                      ; Yes, reset X-coordinate to 0 and
                        CMP     VGA$MAX_Y, R5               ; check if we have reached EOScreen
                        RBRA    _VGA$PUTC_2, !Z             ; No
                        XOR     R5, R5                      ; Yes, reset Y-coordinate to 0
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
                        DECRB
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
                        MOVE    _VGA$Y, R2          ; Clear the SW Y-register
                        MOVE    R0, @R2
                        MOVE    ' ', R8             ; Print spaces
                        MOVE    VGA$MAX_CHARS, R0   ; How many characters?
_VGA$CLS_LOOP           RSUB    VGA$PUTCHAR, 1      ; Print a space character
                        SUB     0x0001, R0
                        RBRA    _VGA$CLS_LOOP, !Z   ; Not done?
                        DECRB
                        RET
