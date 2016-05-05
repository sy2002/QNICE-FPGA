;;
;;  This is a first attempt on a simple yet usable Forth interpreter for the QNICE system.
;;
;; 07-JAN-2016  Bernd Ulmann    Started thinking about this... :-)
;;
;;  The threading model used is STC (Subroutine Threaded Code) working on data structures like these
;; (cf. "Moving Forth" by Brad Rodriguez, http://www.bradrodriguez.com/papers/moving1.htm):
;;
;;                     ------+-----+-------------+---------+---------------------------
;; Current Forth word:   ... ! ... ! RSUB SQUARE ! RSUB ...! ...
;;                     ------+-----+-------------+---------+---------------------------
;;                                           /        ^
;;                                          /         \____________
;;                                         V                       \
;;                         +--------+----+----------+-----------+-----+
;;                         ! SQUARE ! -> ! RSUB DUP ! RSUB MULT ! RET !
;;                         +--------+----+----------+-----------+-----+
;;                                               /            ^
;;                                              /              \
;;                                             V                \
;;                         +-----+----+----------------------+-----+
;;                         ! DUP ! -> ! machine code for DUP ! RET !
;;                         +-----+----+----------------------+-----+
;;
;;  Each word starts with a null terminated string containins its name (this deviates from a traditional
;; Forth). Following the name is a pointer to the start of the next word definition, so all words form a 
;; simple linked list. The rest of the word is just code, either a list of subroutine calls (RSUB) or 
;; hand crafted code implementing some basic functionality.
;;
;;  Using an STC model it is natural to use R13, the hardware stack pointer, as the return stack 
;; pointer. R12 is used as the stack pointer for the data stack. As dictated by the QNICE architecture,
;; the return stack will grow from large adresses to smaller ones. The stack pointer R12 is initialized to 
;; start someplace below the SP and also grows towards smaller addresses, so the memory layout is as follows:
;;
;; +---------------------+-------------------+----------------------------+------------+--------------+----------+
;; ! 0x0000 ---- 0x7FFFF ! 0x8000 ---- ...   !              ...           !     ...    ! ...     FEFF ! FF00 ... !
;; +---------------------+-------------------+----------------------------+------------+--------------+----------+
;; !    QNICE monitor    ! Forth interpreter ! Space for word definitions ! Data stack ! Return stack ! IO area  !
;; +---------------------+-------------------+----------------------------+------------+--------------+----------+
;; 
;;  Pushing a value onto the data stack is accomplished by
;;
;;      MOVE    ..., @--R12
;;
;; while retrieving a value from this stack is done by
;;
;;      MOVE    @R12++, ...,
;;
;; so that the data stack pointer always points to the current top of stack (TOS) location.
;;

#include "../monitor/sysdef.asm"
#include "../monitor/monitor.def"

#define DEBUG

#define DSP R12     // Data stack pointer
;
; Constants:
;
WORD_AREA_SIZE      .EQU        0x0100
RETURN_STACK_SIZE   .EQU        0x0100
LINE_BUFFER_SIZE    .EQU        0x0100
;
                    .ORG        0x8000                      ; Run in RAM
                    MOVE        SP, DSP
                    SUB         RETURN_STACK_SIZE, DSP
;
                    MOVE        WELCOME_TEXT, R8
                    SYSCALL(puts, 1)
#ifdef DEBUG
                    MOVE        DATA_SP_TEXT, R8
                    SYSCALL(puts, 1)
                    MOVE        R12, R8
                    SYSCALL(puthex, 1)
                    SYSCALL(crlf, 1)
                    MOVE        DATA_SP_TEXT, R8
                    SYSCALL(puts, 1)
                    MOVE        SP, R8
                    SYSCALL(puthex, 1)
                    SYSCALL(crlf, 1)
#endif
;
; Test area:
;
                    RSUB        GET_TOKEN, 1
                    SYSCALL(puts, 1)
;
                    SYSCALL(exit, 1)                        ; Return to monitor

#ifdef DEBUG
DATA_SP_TEXT        .ASCII_W    "Data stack pointer: "
RETURN_SP_TEXT      .ASCII_W    "Return stack pointer: "
#endif
WELCOME_TEXT        .ASCII_W    "QNICE-Forth V. 0.1, B. Ulmann\n\n";
;
;***************************************************************************************
;*  GET_TOKEN reads from STDIN and returns a pointer to a null-terminated string 
;* containing the next (whitespace-delimited) token in R8.
;***************************************************************************************
;
GET_TOKEN           INCRB
                    MOVE        _GET_TOKEN_BUFFER, R8
                    SYSCALL(gets, 1)
                    RBRA        TRIM_LEADING, 1             ; Remove leading whitespaces
                    DECRB
                    RET
_GET_TOKEN_LAST_P   .BLOCK      1                           ; Static variable holding the last pointer
_GET_TOKEN_BUFFER   .BLOCK      LINE_BUFFER_SIZE
;
;***************************************************************************************
;*  TRIM_LEADING removes leading whitespace characters from a string pointed to
;* by R8 and returns a new pointer in R8.
;***************************************************************************************
;
TRIM_LEADING        INCRB
_TRIM_LEADING_LOOP  MOVE        @R8++, R0                   ; Get first/next character
                    RBRA        _TRIM_LEADING_FIN, Z        ; Finished if null character found
                    CMP         CHR$SPACE, R0               ; Is it a space character?
                    RBRA        _TRIM_LEADING_LOOP, Z       ; Yes, skip the character
                    CMP         CHR$TAB, R0                 ; Tab-character?
                    RBRA        _TRIM_LEADING_LOOP, Z       ; Yes, skip the character
                    CMP         CHR$CR, R0                  ; CR?
                    RBRA        _TRIM_LEADING_LOOP, Z       ; Yes, skip it...
                    CMP         CHR$LF, R0                  ; LF?
                    RBRA        _TRIM_LEADING_LOOP, Z       ; Yes, skip it...
; No we know that it is neither EOS nor a whitespace character
_TRIM_LEADING_FIN   SUB         0x0001, R8                  ; Adjust pointer one to the left
                    DECRB
                    RET
;
;***************************************************************************************
;*  GET_ADDRESS returns the address of a word code block. If no word with the given name
;* is found, 0 is returned.
;*
;* Input:  R8: Pointer to a null-terminated string containing the word name.
;* Output: R8: Address of the code block or 0.
;***************************************************************************************
;
;
GET_ADDRESS         INCRB
                    MOVE        FIRST_WORD, R0              ; First word in dictionary
                    MOVE        R8, R1                      ; R1 points to the word we are looking for
_GET_ADDRESS_LOOP   MOVE        R0, R8                      ; Prepare strlen system call
                    SYSCALL(strlen, 1)
                    MOVE        R9, R2                      ; R2 contains the length of the current word
                    MOVE        R1, R9                      ; R8 -> current word, R9 -> word we are looking for
                    SYSCALL(strcmp, 1)
                    MOVE        R10, R10                    ; Test result
                    RBRA        _GET_ADDRESS_NEXT, !Z       ; Not found - find next word
                    ADD         R2, R8                      ; Find code block
                    ADD         0x0002, R8
                    RBRA        _GET_ADDRESS_OK, 1          ; Return
_GET_ADDRESS_NEXT   ADD         R2, R8                      ; Find pointer to next word
                    ADD         0x0001, R8
                    MOVE        @R8, R0                     ; Get the pointer
                    RBRA        _GET_ADDRESS_LOOP, !Z       ; Next iteration if it was not a null pointer
                    XOR         R8, R8                      ; Clear R8 in case we did not find the word
_GET_ADDRESS_OK     DECRB
                    RET
;
;***************************************************************************************
;* Builtin words
;***************************************************************************************
;
FIRST_WORD          .ASCII_W    "EMIT"
                    .DW         _>R
                    MOVE        @R12++, R8
                    SYSCALL(putc, 1)
                    RET
_>R                 .ASCII_W    ">R"
                    .DW         _MINUS
                    MOVE        @R12++, @--SP
                    RET
_MINUS              .ASCII_W    "-"
                    .DW         _PLUS
                    SUB         @R12++, @R12
                    RET
_PLUS               .ASCII_W    "+"
                    .DW         _SWAP
                    ADD         @R12++, @R12
                    RET
_SWAP               .ASCII_W    "SWAP"
                    .DW         _DUP
                    MOVE        @R12++, R0
                    MOVE        @R12++, R1
                    MOVE        R0, @--R12
                    MOVE        R1, @--R12
                    RET
_DUP                .ASCII_W    "DUP"
                    .DW         _DROP
                    MOVE        @R12, @--R12
                    RET
_DROP               .ASCII_W    "DROP"
                    .DW         WORDS                       ; Pointer to user definable word area
                    MOVE        @R12++, R0
                    RET
;
; User defined words:
;
WORDS               .BLOCK      WORD_AREA_SIZE              ; Reserve some memory for word definitions
;
FIN                 .BLOCK      1
