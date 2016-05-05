;;
;; QMON - a simple monitor for the QNICE processor
;;
;; The labels and constants of each subsystem are prefixed with a short name denoting the particular 
;; subsystem, followed by a dollar sign. Examples for this are IO$BASE or STR$STRMP etc. Labels 
;; within a routine follow this prefix style but have an additional underscore following the dollar 
;; sign to denote that these labels should normally not be the target of a branch or subroutine call 
;; from outside code areas.
;;
;; B. Ulmann fecit
;;
;;  17-DEC-2007: Begin of coding
;;  03-AUG-2015: After upgrading the emulator and fixing some (serious) bugs the work on the
;;               monitor continues
;;  06-AUG-2015: Basic monitor functions implemented
;;  28..30-DEC-2015: VGA- and USB-support
;;  JAN-2016:    Central dispatch table, scrolling support
;;
;; Known bugs: 
;;
;; Bits and pieces:
;;   - All functions expect their input parameters in the registers R8, R9 and maybe R10.
;;   - The result of a function is returned in the first non-used high numbered register, so if a 
;;     function expects its parameters in R8 and R9, it will return its result in R10. If it only 
;;     expects one parameter, the result will be
;;     returned in R9 respectively.
;;   - Every function name starts with its subsection name followed by a dollar sign, so all string 
;;     routines have names starting with "STR$".
;;   - Labels within a function always have an underscore following the subsystem name, so a label 
;;     within the routine STR$CMP would have the form "STR$_CMP...". So never jump to a label of the 
;;     form "<SSN>$_..." since this will be a label buried inside a function.
;;   - Every subsystem (string routines, IO routines etc.) has its own constants which are always 
;;     located after the code for the routines.
;;   - To assemble this monitor just call the "asm" shell script which will use the C preprocessor 
;;     to include the necessary library files.
;;
;
; Main program:
;
;  The main program starts with the central dispatch table used to call monitor routines from 
; external programs. This maybe considered as a light-weight-system-call. Although it is, of course,
; possible to call any monitor routine directly from another program this would result in the 
; need of reassembling everything after even the tiniest change in the monitor. Therefore all
; routines accessible to other programs, the runtime-library, are not called directly but through
; one level of indirection using the following dispatch table.
;  This dispatch table consists of more than pure addresses - it contains branches which wastes
; one word per entry but reduces the time penalty induced by this additional level of indirection.
;  Please keep the following things in mind when changing/extending the monitor:
;
; - The absolute start address (0x000) of the dispatch table and the sequence of its entries must
;   not be changed!
; - If there are new subroutines exposed to external programs, their respective entries are just
;   appended at the end of the dispatch table.
; - The labels of the dispatch table entries are written in lower case and should match as closely
;   as possible the standard names from a typical C-runtime library.
;
reset!          RBRA    QMON$COLDSTART, 1       ; Skip the dispatch table on reset
getc!           RBRA    IO$GETCHAR, 1
putc!           RBRA    IO$PUTCHAR, 1
gets!           RBRA    IO$GETS, 1
puts!           RBRA    IO$PUTS, 1
crlf!           RBRA    IO$PUT_CRLF, 1
til!            RBRA    IO$TIL, 1
mult!           RBRA    MTH$MUL, 1
memset!         RBRA    MEM$FILL, 1
memcpy!         RBRA    MEM$MOVE, 1
wait!           RBRA    MISC$WAIT, 1
exit!           RBRA    MISC$EXIT, 1
chr2upper!      RBRA    CHR$TO_UPPER, 1
str2upper!      RBRA    STR$TO_UPPER, 1
strlen!         RBRA    STR$LEN, 1
chomp!          RBRA    STR$CHOMP, 1
strcmp!         RBRA    STR$CMP, 1
strchr!         RBRA    STR$STRCHR, 1
gethex!         RBRA    IO$GET_W_HEX, 1
puthex!         RBRA    IO$PUT_W_HEX, 1

;
;  The actual monitor code starts here:
;
QMON$COLDSTART  AND     0x00FF, SR              ; Make sure we are in register bank 0
                MOVE    VAR$STACK_START, SP     ; Initialize stack pointer
                RSUB    VGA$INIT, 1             ; Does not clear the screen, so that
                                                ; the HW boot message stays visible
                MOVE    QMON$WELCOME, R8        ; Print welcome message
                RSUB    IO$PUTS, 1
                MOVE    IO$KBD_STATE, R8        ; Set DE keyboard locale as default    
                OR      KBD$LOCALE_DE, @R8      
;                MOVE    QMON$LAST_ADDR, R8      ; Clear memory after the monitor
;                ADD     0x0001, R8              ; Start address
;                MOVE    VAR$STACK_START, R9     ; Determine length of memory area 
;                SUB     R8, R9                  ;   to be cleared
;                SUB     0x0001, R9              ; We need one stack cell for the following call
;                XOR     R10, R10                ; Clear with zero words
;                RSUB    MEM$FILL, 1             ; Clear
                RBRA    QMON$MAIN_LOOP, 1       ; skip redundant warmstart commands
;;TODO: Clear registers
QMON$WARMSTART  AND     0x00FF, SR              ; Reset register bank to zero
                MOVE    VAR$STACK_START, SP     ; Set up stack pointer to highest available address
                RSUB    IO$PUT_CRLF, 1
QMON$MAIN_LOOP  MOVE    QMON$PROMPT, R8         ; Print monitor prompt
                RSUB    IO$PUTS, 1
QMON$NEXT_CHR   RSUB    IO$GETCHAR, 1           ; Wait for a key being pressed
                AND     KBD$ASCII, R8           ; Ignore special keys like F-keys, cursor, etc.
                RBRA    QMON$NEXT_CHR, Z
                RSUB    CHR$TO_UPPER, 1         ; Convert it into an uppercase letter
                RSUB    IO$PUTCHAR, 1           ; Echo the character
                CMPU    'C', R8                 ; Control group?
                RBRA    QMON$MAYBE_M, !Z        ; No
; Control group
                MOVE    QMON$CG_C, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GETCHAR, 1           ; Get command character
                RSUB    CHR$TO_UPPER, 1
                CMPU    'C', R8                 ; Cold start?
                RBRA    QMON$C_MAYBE_H, !Z      ; No...
; CONTROL/COLDSTART:
                MOVE    QMON$CG_C_C, R8
                RSUB    IO$PUTS, 1
                RSUB    VGA$CLS, 1              ; This manual clear screen is
                                                ; needed because the power-on
                                                ; cold start does not clear
                                                ; the screen to keep the HW
                                                ; startup message visible
                RBRA    QMON$COLDSTART, 1       ; Yes!
QMON$C_MAYBE_H  CMPU    'H', R8                 ; Halt?
                RBRA    QMON$C_MAYBE_R, !Z
; CONTROL/HALT:
                MOVE    QMON$CG_C_H, R8
                RSUB    IO$PUTS, 1
                HALT
QMON$C_MAYBE_R  CMPU    'R', R8                 ; Run?
                RBRA    QMON$C_MAYBE_S, !Z      ; No
; CONTROL/RUN:
                MOVE    QMON$CG_C_R, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get address
                RSUB    IO$PUT_CRLF, 1
                ABRA    R8, 1                   ; Jump to address specified
; CONTROL/CLEAR SCREEN:
QMON$C_MAYBE_S  CMPU    'S', R8                 ; Clear screen?
                RBRA    QMON$C_ILLEGAL, !Z      ; No
                RSUB    VGA$CLS, 1              ; Yes, clear screen...
                RBRA    QMON$MAIN_LOOP, 1       ; Return to main loop
QMON$C_ILLEGAL  MOVE    QMON$ILLCMD, R8         ; Control group C, illegal command
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$MAYBE_M    CMPU    'M', R8                 ; Compare with 'M'
                RBRA    QMON$MAYBE_H, !Z        ; No M, try next...
; Memory control group:
                MOVE    QMON$CG_M, R8           ; Print control group name
                RSUB    IO$PUTS, 1
                RSUB    IO$GETCHAR, 1           ; Get command character
                RSUB    CHR$TO_UPPER, 1         ; ...convert it to upper case
                CMPU    'C', R8                 ; 'Change'?
                RBRA    QMON$M_MAYBE_D, !Z
; MEMORY/CHANGE:
                MOVE    QMON$CG_M_C, R8         ; Print prompt for address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Read in address
                MOVE    R8, R0
                MOVE    QMON$CG_M_C1, R8        ; Prepare output of current value
                RSUB    IO$PUTS, 1
                MOVE    @R0, R8                 ; Get current value
                RSUB    IO$PUT_W_HEX, 1         ; Print current value
                MOVE    QMON$CG_M_C2, R8        ; Prompt for new value
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, @R0
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_D  CMPU    'D', R8
                RBRA    QMON$M_MAYBE_E, !Z      ; No D, try next...
; MEMORY/DUMP:
                MOVE    QMON$CG_M_D, R8         ; Print prompt for start address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get start address
                MOVE    R8, R0                  ; Remember start address in R8
                MOVE    QMON$CG_M_D2, R8        ; Print prompt for end address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get end address
                RSUB    IO$PUT_CRLF, 1
                MOVE    R8, R9
                MOVE    R0, R8
                RSUB    IO$DUMP_MEMORY, 1       ; Dump memory contents
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_E  CMPU    'E', R8                 ; Is it an 'E'?
                RBRA    QMON$M_MAYBE_F, !Z      ; No...
; MEMORY/EXAMINE:
                MOVE    QMON$CG_M_E, R8         ; Print prompt for address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Read address
                MOVE    R8, R0
                MOVE    ' ', R8
                RSUB    IO$PUTCHAR, 1
                MOVE    @R0, R8
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_F  CMPU    'F', R8
                RBRA    QMON$M_MAYBE_L, !Z
; MEMORY/FILL:
                MOVE    QMON$CG_M_F, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R0
                MOVE    QMON$CG_M_F2, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R1
                MOVE    QMON$CG_M_F3, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R10
                MOVE    R0, R8
                SUB     R0, R1
                ADD     0x0001, R1
                MOVE    R1, R9
                RSUB    MEM$FILL, 1
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_L  CMPU    'L', R8
                RBRA    QMON$M_MAYBE_M, !Z
; MEMORY/LOAD:
                MOVE    QMON$CG_M_L, R8
                RSUB    IO$PUTS, 1
_QMON$ML_LOOP   RSUB    IO$GET_W_HEX, 1             ; Get address
                MOVE    R8, R0
                RSUB    IO$GET_W_HEX, 1             ; Get value
                MOVE    R8, @R0
                RBRA    _QMON$ML_LOOP, 1
QMON$M_MAYBE_M  CMPU    'M', R8
                RBRA    QMON$M_MAYBE_S, !Z
; MEMORY/MOVE:
                MOVE    QMON$CG_M_M, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R0
                MOVE    QMON$CG_M_M2, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R1
                MOVE    QMON$CG_M_M3, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1
                MOVE    R8, R10
                MOVE    R0, R8
                MOVE    R1, R9
                RSUB    MEM$MOVE, 1
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_S  CMPU    'S', R8
                RBRA    QMON$M_ILLEGAL, !Z
; MEMORY/DISASSEMBLE:
                MOVE    QMON$CG_M_S, R8         ; Print prompt for start address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get start address
                MOVE    R8, R0                  ; Remember start address in R8
                MOVE    QMON$CG_M_S2, R8        ; Print prompt for end address
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get end address
                RSUB    IO$PUT_CRLF, 1
                MOVE    R8, R9                  ; R9 contains the end address
                MOVE    R0, R8                  ; R8 contains the start address
_QMON$MS_LOOP   RSUB    DBG$DISASM, 1           ; Disassemble one instruction at 
                                                ; addr. R8 - this increments R8!
                CMPU    R8, R9                  ; End reached?
                RBRA    _QMON$MS_LOOP, !N       ; No, next instruction
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_ILLEGAL  MOVE    QMON$ILLCMD, R8
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$MAYBE_H    CMPU    'H', R8
                RBRA    QMON$NOT_H, !Z          ; No H, try next...
; HELP:
                MOVE    QMON$HELP, R8           ; H(elp) - print help text
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$NOT_H      MOVE    QMON$ILLCMDGRP, R8A     ; Illegal command group
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1

QMON$WELCOME    .ASCII_P    "\n\nSimple QNICE-monitor - Version 0.5 (Bernd Ulmann, January 2016)\n"
#ifdef RAM_MONITOR
                .ASCII_P    "Running in RAM!\n"
#endif
                .ASCII_W    "---------------------------------------------------------------\n\n"
QMON$PROMPT     .ASCII_W    "QMON> "
QMON$ILLCMDGRP  .ASCII_W    " *** Illegal command group ***\n"
QMON$ILLCMD     .ASCII_W    " *** Illegal command ***\n"
QMON$HELP       .ASCII_P    "ELP:\n\n"
                .ASCII_P    "    C(control group):\n"
                .ASCII_P    "        C(old start) H(alt) R(un) Clear(S)creen\n"
                .ASCII_P    "    H(elp)\n"
                .ASCII_P    "    M(emory group):\n"
                .ASCII_P    "        C(hange) D(ump) E(xamine) F(ill) L(oad) M(ove)\n"
                .ASCII_P    "        di(S)assemble\n"
                .ASCII_P    "\n    General: CTRL-E performs a warm start whenever an\n"
                .ASCII_P    "        input from keyboard is expected.\n"
                .ASCII_P    "\n    M(emory)L(oad) can be used to load assembler output\n"
                .ASCII_P    "        by pasting it to the terminal. CTRL-E terminates.\n"
                .ASCII_P    "\n    Scrolling (VGA): CTRL-(F)orward or (CsrDown) / CTRL-(B)ackward or (CsrUp)\n"
                .ASCII_P    "        One page: (PgDown), (PgUp)  /  10 lines: CTRL-(PgDown), CTRL-(PgUp)\n"
                .ASCII_P    "        First page: (Home) / last page: (End)\n"
                .ASCII_W    "\n"
QMON$CG_C       .ASCII_W    "ONTROL/"
QMON$CG_C_C     .ASCII_W    "COLD START"
QMON$CG_C_H     .ASCII_W    "HALT\n\n"
QMON$CG_C_R     .ASCII_W    "RUN ADDRESS="
QMON$CG_M       .ASCII_W    "EMORY/"
QMON$CG_M_C     .ASCII_W    "CHANGE ADDRESS="
QMON$CG_M_C1    .ASCII_W    " CURRENT VALUE="
QMON$CG_M_C2    .ASCII_W    " NEW VALUE="
QMON$CG_M_D     .ASCII_W    "DUMP START ADDRESS="
QMON$CG_M_D2    .ASCII_W    " END ADDRESS="
QMON$CG_M_E     .ASCII_W    "EXAMINE ADDRESS="
QMON$CG_M_F     .ASCII_W    "FILL START ADDRESS="
QMON$CG_M_F2    .ASCII_W    " END ADDRESS="
QMON$CG_M_F3    .ASCII_W    " VALUE="
QMON$CG_M_L     .ASCII_W    "LOAD - ENTER ADDRESS/VALUE PAIRS, TERMINATE WITH CTRL-E\n"
QMON$CG_M_M     .ASCII_W    "MOVE FROM="
QMON$CG_M_M2    .ASCII_W    " TO="
QMON$CG_M_M3    .ASCII_W    " LENGTH="
QMON$CG_M_S     .ASCII_W    "DISASSEMBLE START ADDRESS="
QMON$CG_M_S2    .ASCII_W    " END ADDRESS="
