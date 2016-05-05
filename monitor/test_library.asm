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
VGA$FULL_SCREEN_TEST    RSUB    VGA$INIT, 1             ; Initialize VGA-interface
                        MOVE    0x0041, R2              ; Print "A"s
_VGA$FS_TEST_LOOP       MOVE    R2, R8
                        RSUB    VGA$PUTCHAR, 1          ; Print a single "A"-character
                        ADD     0x0001, R2              ; Next character
                        CMPU    0x005B, R2              ; One after Z?
                        RBRA    _VGA$FS_TEST_LOOP, !Z   ; No, just continue
                        MOVE    0x0041, R2
                        RBRA    _VGA$FS_TEST_LOOP, 1

VGA$CRLF_TEST           RSUB    VGA$INIT, 1
                        MOVE    0x0041, R2
_VGA$CRLF_LOOP          MOVE    R2, R8
                        RSUB    VGA$PUTCHAR, 1          ; Print a single "A"-character
                        ADD     0x0001, R2              ; Next character
                        CMPU    0x005B, R2              ; One after Z?
                        RBRA    _VGA$CRLF_LOOP, !Z      ; No, just continue
                        MOVE    0x0041, R2              ; Reset char to "A"
                        MOVE    0x000A, R8
                        RSUB    VGA$PUTCHAR, 1          ; Print LF
                        MOVE    0x000D, R8
                        RSUB    VGA$PUTCHAR, 1          ; Print CR
                        MOVE    0x0002, R8
                        RSUB    MISC$WAIT, 1
                        RBRA    _VGA$CRLF_LOOP, 1
