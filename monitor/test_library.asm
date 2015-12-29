;
;;=======================================================================================
;; This library contains basic test routines which are no permanent part of the 
;; monitor. The contents of this file will change rapidly and should not be relied
;; upon!
;;=======================================================================================
;

;
;***************************************************************************************
;* Test the VGA$PUTCHAR-function by printing characters and the reading out and 
;* displaying the current cursor coordinates.
;***************************************************************************************
;
VGA$TEST                RSUB    VGA$INIT, 1             ; Initialize VGA-interface
                        MOVE    _VGA$X, R0              ; Setup pointers to the 
                        MOVE    _VGA$Y, R1              ; SW coordinates
                        MOVE    0x0041, R2              ; Print "A"s
_VGA$TEST_LOOP          MOVE    @R0, R8
                        RSUB    IO$PUT_W_HEX, 1         ; Print current coordinates
                        MOVE    ' ', R8
                        RSUB    IO$PUTCHAR, 1
                        MOVE    @R1, R8
                        RSUB    IO$PUT_W_HEX, 1
                        MOVE    ' ', R8
                        RSUB    IO$PUTCHAR, 1
                        MOVE    R2, R8
                        RSUB    IO$PUT_W_HEX, 1
                        RSUB    IO$PUT_CRLF, 1
                        MOVE    0x0001, R8              ; Wait a moment
                        RSUB    MISC$WAIT, 1
                        MOVE    R2, R8
                        RSUB    VGA$PUTCHAR, 1          ; Print a single "A"-character
                        ADD     0x0001, R2              ; Next character
                        CMP     0x005B, R2              ; One after Z?
                        RBRA    _VGA$TEST_LOOP, !Z      ; No, just continue
                        MOVE    0x0041, R2
                        RBRA    _VGA$TEST_LOOP, 1
