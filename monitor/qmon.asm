;;
;; QMON - a simple monitor for the QNICE processor
;;
;; The labels and constants of each subsystem are prefixed with a short name denoting the particular 
;; subsystem, followed by a dollar sign. Examples for this are IO$BASE or STR$STRMP etc. Labels 
;; within a routine follow this prefix style but have an additional underscore following the dollar 
;; sign to denote that these labels should normally not be the target of a branch or subroutine call 
;; from outside code areas.
;;
;; B. Ulmann, sy2002 fecit
;;
;;  17-DEC-2007: Begin of coding
;;  03-AUG-2015: After upgrading the emulator and fixing some (serious) bugs the work on the
;;               monitor continues
;;  06-AUG-2015: Basic monitor functions implemented
;;  28..30-DEC-2015: VGA- and USB-support
;;  JAN-2016:    Central dispatch table (by vaxman), VGA scrolling support (by sy2002)
;;  OCT-2016:    32bit integer math, SD Card and FAT32 support (by sy2002)
;;  DEC-2016:    Completely redone string input: gets, gets_s, gets_slf, gets_core (by sy2002)
;;               Added file system support: mount, browse, load/run (by sy2002)
;;  AUG-2020:    Support for new ISA, improved disassembly of relative branches (by vaxman)
;;  SEP-2020:    qtransfer client (by sy2002)
;;
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
muls!           RBRA    MTH$MULS, 1
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
mulu!           RBRA    MTH$MULU, 1
vga_cls!        RBRA    VGA$CLS, 1
divu!           RBRA    MTH$DIVU, 1
divs!           RBRA    MTH$DIVS, 1
chr2lower!      RBRA    CHR$TO_LOWER, 1
mulu32!         RBRA    MTH$MULU32, 1
divu32!         RBRA    MTH$DIVU32, 1
split!          RBRA    STR$SPLIT, 1
h2dstr!         RBRA    STR$H2D, 1
sd_reset!       RBRA    SD$RESET, 1
sd_r_block!     RBRA    SD$READ_BLOCK, 1
sd_w_block!     RBRA    SD$WRITE_BLOCK, 1
sd_r_byte!      RBRA    SD$READ_BYTE, 1
sd_w_byte!      RBRA    SD$WRITE_BYTE, 1
f32_mnt_sd!     RBRA    FAT32$MOUNT_SD, 1
f32_mnt!        RBRA    FAT32$MOUNT, 1
f32_od!         RBRA    FAT32$DIR_OPEN, 1
f32_ld!         RBRA    FAT32$DIR_LIST, 1
f32_cd!         RBRA    FAT32$CD, 1
f32_pd!         RBRA    FAT32$PRINT_DE, 1
f32_fopen!      RBRA    FAT32$FILE_OPEN, 1
f32_fread!      RBRA    FAT32$FILE_RB, 1
f32_fseek!      RBRA    FAT32$FILE_SEEK, 1
gets_s!         RBRA    IO$GETS_S, 1
gets_slf!       RBRA    IO$GETS_SLF, 1
vga_init!       RBRA    VGA$INIT, 1
in_range_u!     RBRA    MTH$IN_RANGE_U, 1
in_range_s!     RBRA    MTH$IN_RANGE_S, 1
enter!          RBRA    MISC$ENTER, 1
leave!          RBRA    MISC$LEAVE, 1
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
                MOVE    _SD$DEVICEHANDLE, R8    ; Unmount the SD Card
                XOR     @R8, @R8
;                MOVE    QMON$LAST_ADDR, R8      ; Clear memory after the monitor
;                ADD     0x0001, R8              ; Start address
;                MOVE    VAR$STACK_START, R9     ; Determine length of memory area 
;                SUB     R8, R9                  ;   to be cleared
;                SUB     0x0001, R9              ; We need one stack cell for the following call
;                XOR     R10, R10                ; Clear with zero words
;                RSUB    MEM$FILL, 1             ; Clear
                RBRA    QMON$MAIN_LOOP, 1       ; skip redundant warmstart commands

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
                CMP     'C', R8                 ; Control group?
                RBRA    QMON$MAYBE_M, !Z        ; No
; Control group
                MOVE    QMON$CG_C, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GETCHAR, 1           ; Get command character
                RSUB    CHR$TO_UPPER, 1
                CMP     'C', R8                 ; Cold start?
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
QMON$C_MAYBE_H  CMP     'H', R8                 ; Halt?
                RBRA    QMON$C_MAYBE_R, !Z
; CONTROL/HALT:
                MOVE    QMON$CG_C_H, R8
                RSUB    IO$PUTS, 1
                HALT
QMON$C_MAYBE_R  CMP     'R', R8                 ; Run?
                RBRA    QMON$C_MAYBE_S, !Z      ; No
; CONTROL/RUN:
                MOVE    QMON$CG_C_R, R8
                RSUB    IO$PUTS, 1
                RSUB    IO$GET_W_HEX, 1         ; Get address
                RSUB    IO$PUT_CRLF, 1
                RSUB    _VGA$FACTORY_PAL, 1     ; factory default vga palette
                ABRA    R8, 1                   ; Jump to address specified
; CONTROL/CLEAR SCREEN:
QMON$C_MAYBE_S  CMP     'S', R8                 ; Clear screen?
                RBRA    QMON$C_ILLEGAL, !Z      ; No
                RSUB    VGA$CLS, 1              ; Yes, clear screen...
                RBRA    QMON$MAIN_LOOP, 1       ; Return to main loop
QMON$C_ILLEGAL  MOVE    QMON$ILLCMD, R8         ; Control group C, illegal command
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$MAYBE_M    CMP     'M', R8                 ; Compare with 'M'
                RBRA    QMON$MAYBE_F, !Z        ; No M, try next...
; Memory control group:
                MOVE    QMON$CG_M, R8           ; Print control group name
                RSUB    IO$PUTS, 1
                RSUB    IO$GETCHAR, 1           ; Get command character
                RSUB    CHR$TO_UPPER, 1         ; ...convert it to upper case
                CMP     'C', R8                 ; 'Change'?
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
QMON$M_MAYBE_D  CMP     'D', R8
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
QMON$M_MAYBE_E  CMP     'E', R8                 ; Is it an 'E'?
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
QMON$M_MAYBE_F  CMP     'F', R8
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
QMON$M_MAYBE_L  CMP     'L', R8
                RBRA    QMON$M_MAYBE_M, !Z
; MEMORY/LOAD:
                MOVE    QMON$CG_M_L, R8
                RSUB    IO$PUTS, 1
_QMON$ML_LOOP   RSUB    IO$GET_W_HEX, 1             ; Get address
                MOVE    R8, R0
                RSUB    IO$GET_W_HEX, 1             ; Get value
                MOVE    R8, @R0
                RBRA    _QMON$ML_LOOP, 1
QMON$M_MAYBE_M  CMP     'M', R8
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
QMON$M_MAYBE_S  CMP     'S', R8
                RBRA    QMON$M_MAYBE_Q, !Z
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
                CMP     R8, R9                  ; End reached?
                RBRA    _QMON$MS_LOOP, !N       ; No, next instruction
                RBRA    QMON$MAIN_LOOP, 1
QMON$M_MAYBE_Q  CMP     'Q', R8
                RBRA    QMON$M_ILLEGAL, !Z
; MEMORY/QTRANSFER
                RBRA    QTRANSFER$START, 1      ; we must not use RSUB here
                                                ; why? see qtransfer.asm
QMON$M_ILLEGAL  MOVE    QMON$ILLCMD, R8
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$MAYBE_F    CMP     'F', R8
                RBRA    QMON$MAYBE_H, !Z        ; No F, try next...
; File control group
                MOVE    QMON$CG_F, R8           ; Print control group name 
                RSUB    IO$PUTS, 1
                RSUB    IO$GETCHAR, 1           ; Get command character
                RSUB    CHR$TO_UPPER, 1         ; ...convert it to upper case
; FILE/LIST DIRECTORY
                CMP     'D', R8                 ; Is it a 'D'?
                RBRA    QMON$F_MAYBE_C, !Z      ; no: try next...
                MOVE    QMON$CG_F_D, R8         ; print command name
                RSUB    IO$PUTS, 1
                RSUB    QMON$DIR, 1             ; list current directory
                RBRA    QMON$MAIN_LOOP, 1
QMON$F_MAYBE_C  CMP     'C', R8                 ; Is it a 'C'?
                RBRA    QMON$F_MAYBE_L, !Z      ; no: try next...
; FILE/CHANGE DIRECTORY
                MOVE    QMON$CG_F_C, R8         ; print command name
                RSUB    IO$PUTS, 1
                RSUB    QMON$CD, 1              ; change directory
                RBRA    QMON$MAIN_LOOP, 1
QMON$F_MAYBE_L  CMP     'L', R8                 ; Is it a 'L'?
                RBRA    QMON$F_MAYBE_R, !Z      ; no: try next...
; FILE/LOAD
                MOVE    QMON$CG_F_L, R8         ; print command name
                RSUB    IO$PUTS, 1
                RSUB    QMON$LOAD, 1            ; load file
                RBRA    QMON$MAIN_LOOP, 1
QMON$F_MAYBE_R  CMP     'R', R8                 ; Is it a 'R'?
                RBRA    QMON$C_ILLEGAL, !Z      ; no: reuse error message of 'C'
; FILE/RUN
                MOVE    QMON$CG_F_R, R8         ; print command name
                RSUB    IO$PUTS, 1
                RSUB    QMON$LOAD, 1            ; load file, return start address in R6
                CMP     R6, 0xFFFF              ; successfully loaded file
                RBRA    QMON$MAIN_LOOP, Z       ; no: next command
                MOVE    QMON$CG_F_R_MSG, R8     ; yes: print "Running..." status message
                RSUB    IO$PUTS, 1
                RSUB    _VGA$FACTORY_PAL, 1     ; factory default vga palette                
                ABRA    R6, 1                   ; run program
QMON$MAYBE_H    CMP     'H', R8
                RBRA    QMON$NOT_H, !Z          ; No H, try next...
;                 
; HELP:
                MOVE    QMON$HELP, R8           ; H(elp) - print help text
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1
QMON$NOT_H      MOVE    QMON$ILLCMDGRP, R8      ; Illegal command group
                RSUB    IO$PUTS, 1
                RBRA    QMON$MAIN_LOOP, 1

;***************************************************************************************
;* SD Card / file system functions
;***************************************************************************************

; Check, if we have a valid device handle and if not, mount the SD Card as the device.
; For now, we are using partition 1 hardcoded. This can be easily changed in the
; following code, but then we need an explicit mount/unmount mechanism, which is
; currently done automatically.
; Returns the device handle in R8, R9 = 0 if everything is OK,
; otherwise errorcode in R9 and R8 = 0
QMON$CHKORMNT   MOVE    _SD$DEVICEHANDLE, R8
                CMP     0, @R8                  ; valid handle?
                RBRA    QMON$CHKORMNT_E, !Z     ; yes: leave
                MOVE    1, R9                   ; partition #1
                RSUB    FAT32$MOUNT_SD, 1       ; no: try to mount the SD Card
                CMP     0, R9                   ; mounting worked?
                RBRA    QMON$CHKORMNT_E, Z      ; yes: leave
                MOVE    QMON$CG_F_EMNT, R8      ; print error message
                RSUB    IO$PUTS, 1
                MOVE    R9, R8                  ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8 
                XOR     R8, R8                  ; return 0 as device handle                   
QMON$CHKORMNT_E RET

; List the current directory
QMON$DIR        RSUB    QMON$CHKORMNT, 1        ; get device handle in R8
                CMP     R8, 0                   ; worked?
                RBRA    QMON$DIR_E, Z           ; no: exit
                SUB     FAT32$FDH_STRUCT_SIZE, SP ; memory for directory handle
                MOVE    SP, R9                  ; directory handle to R9
                RSUB    FAT32$DIR_OPEN, 1       ; open directory for reading
                CMP     R9, 0                   ; worked?
                RBRA    QMON$DIR_EL, Z          ; yes: go on
                MOVE    QMON$CG_F_EOD, R8       ; no: print error message
                RSUB    IO$PUTS, 1
                MOVE    R9, R8                  ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8                                
                RBRA    QMON$DIR_EM, 1          ; free memory and exit
QMON$DIR_EL     SUB     FAT32$DE_STRUCT_SIZE, SP ; memory for directory entry
                MOVE    SP, R9                  ; dir. entry handle to R9
QMON$DIR_LOOP   MOVE    FAT32$FA_DEFAULT, R10   ; standard browsing mode
                RSUB    FAT32$DIR_LIST, 1       ; get next directory entry
                CMP     R11, 0                  ; worked?
                RBRA    QMON$DIR_ELL, Z         ; yes: go on
                MOVE    QMON$CG_F_EBD, R8       ; print error message
                RSUB    IO$PUTS, 1
                MOVE    R9, R8                  ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8                
                RBRA    QMON$DIR_EMM, 1         ; free memory and exit
QMON$DIR_ELL    CMP     R10, 1                  ; valid entry?
                RBRA    QMON$DIR_EMM, !Z        ; no: free memory and exit
                MOVE    R8, R10                 ; save directory handle
                MOVE    R9, R8                  ; print entry
                MOVE    FAT32$PRINT_DEFAULT, R9 ; default print layout
                RSUB    FAT32$PRINT_DE, 1
                MOVE    R8, R9                  ; restore dir. entry handle
                MOVE    R10, R8                 ; restore directory handle
                RBRA    QMON$DIR_LOOP, 1        ; next entry
QMON$DIR_EMM    ADD     FAT32$DE_STRUCT_SIZE, SP  ; free memory for directory entry
QMON$DIR_EM     ADD     FAT32$FDH_STRUCT_SIZE, SP ; free memory for directory handle
QMON$DIR_E      RET                     

; Change directory, the maximum length of the input may be 255 characters
QMON$CD         SUB     256, SP                 ; memory: 255 characters + zero term.
                MOVE    SP, R8                  ; R8 = input string
                MOVE    256, R9                 ; R9 = buffer size
                RSUB    IO$GETS_S, 1            ; enter string
                RSUB    IO$PUT_CRLF, 1          ; CR/LF
                CMP     @R8, 0                  ; completely empty string?
                RBRA    QMON$CD_E, Z            ; yes: exit
                MOVE    R8, R11                 ; R11 = saved pointer to input string
                RSUB    QMON$CHKORMNT, 1        ; get device handle in R8
                CMP     R8, 0                   ; worked?
                RBRA    QMON$CD_E, Z            ; no: exit
                MOVE    R11, R9                 ; R9 = path
                XOR     R10, R10                ; use '/' as path segment separator
                RSUB    FAT32$CD, 1             ; change directory
                CMP     R9, 0                   ; worked?
                RBRA    QMON$CD_E, Z            ; yes
                CMP     R9, FAT32$ERR_DIRNOTFOUND ; directory not found?
                RBRA    QMON$CD_OE, !Z          ; no: other error
                MOVE    QMON$CG_F_ECDNF, R8     ; print "Directory not found: "
                RSUB    IO$PUTS, 1
                MOVE    R11, R8                 ; print name of not found directory
                RSUB    IO$PUTS, 1
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$CD_E, 1
QMON$CD_OE      MOVE    QMON$CG_F_ECD, R8       ; print general error message
                RSUB    IO$PUTS, 1
                MOVE    R9, R8                  ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8
QMON$CD_E       ADD     256, SP                 ; free memory for string input
                RET

; Load file in the .out file format, the maximum input length may be 255 characters
; returns the start address of the binary in R6
QMON$LOAD       MOVE    0xFFFF, R6              ; R6 = start address of loaded binary
                SUB     256, SP                 ; memory: 255 characters + zero term.
                MOVE    SP, R8                  ; R8 = input string
                MOVE    256, R9                 ; R9 = buffer size
                RSUB    IO$GETS_S, 1            ; enter string
                RSUB    IO$PUT_CRLF, 1          ; CR/LF
                CMP     @R8, 0                  ; completely empty string?
                RBRA    QMON$LOAD_E, Z          ; yes: exit
                MOVE    R8, R10                 ; R10 = file name
                MOVE    R8, R12                 ; R12 = saved pointer to file name
                RSUB    QMON$CHKORMNT, 1        ; get device handle in R8
                CMP     R8, 0                   ; worked?
                RBRA    QMON$LOAD_E, Z          ; no: exit
                XOR     R11, R11                ; use '/' as path segment separator
                SUB     FAT32$FDH_STRUCT_SIZE, SP ; memory for file handle
                MOVE    SP, R9                  ; R9 = file handle
                RSUB    FAT32$FILE_OPEN, 1      ; open file
                CMP     R10, 0                  ; worked?
                RBRA    QMON$LOAD_START, Z      ; yes
                CMP     R10, FAT32$ERR_FILENOTFOUND ; file not found?
                RBRA    QMON$LOAD_OE, !Z        ; no: other error
                MOVE    QMON$CG_F_EFNF, R8      ; print "File not found: "
                RSUB    IO$PUTS, 1
                MOVE    R12, R8                 ; print filename
                RSUB    IO$PUTS, 1
                RSUB    IO$PUT_CRLF, 1
                RBRA    QMON$LOAD_EE, 1         ; free memory and exit
QMON$LOAD_OE    MOVE    QMON$CG_F_EFOF, R8      ; print "File open failed."
                RSUB    IO$PUTS, 1
                MOVE    R10, R8                 ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8
                RBRA    QMON$LOAD_EE, 1         ; free memory and exit    
QMON$LOAD_START MOVE    R9, R8                  ; R8 = file handle
                SUB     12, SP                  ; memory for address and value
                MOVE    SP, R11                 ; R11 = address and value
                MOVE    SP, R0                  ; R0 = working pointer
                MOVE    12, R1                  ; R1 = counter for address and value
QMON$LOAD_READ  RSUB    FAT32$FILE_RB, 1        ; read one byte
                CMP     R10, FAT32$EOF          ; EOF?
                RBRA    QMON$LOAD_EEE, Z        ; yes: free memory and exit
                CMP     R10, 0                  ; other error?
                RBRA    QMON$LOAD_EXEC, Z       ; no: go on and execute loading
                MOVE    QMON$CG_F_ELD, R8       ; print "Error loading file."
                RSUB    IO$PUTS, 1
                MOVE    R10, R8                 ; print error code
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8
                RBRA    QMON$LOAD_EEE, 1        ; free memory and exit    
QMON$LOAD_EXEC  MOVE    R8, R7                  ; save file handle
                MOVE    R9, R8 
                RSUB    CHR$TO_UPPER, 1         ; convert char to upper case
                MOVE    R8, R9                  ; restore character reg. R9
                MOVE    R7, R8                  ; restore file handle
                CMP     R9, 0x0020              ; skip space
                RBRA    QMON$LOAD_READ, Z
                CMP     R9, 0x0009              ; skip TAB
                RBRA    QMON$LOAD_READ, Z
                CMP     R9, 0x000A              ; skip LF
                RBRA    QMON$LOAD_READ, Z
                CMP     R9, 0x000D              ; skip CR
                RBRA    QMON$LOAD_READ, Z
                MOVE    R9, @R0++               ; store character
                SUB     1, R1                   ; 12 characters for address and value
                RBRA    QMON$LOAD_READ, !Z      ; loop, if not yet 12 characters
                MOVE    R11, R0                 ; reset working pointer
                RSUB    QMON$LOADHEX, 1         ; R2 contains first 4-digit hex value
                CMP     R6, 0xFFFF              ; address already set?
                RBRA    QMON$LOAD_EXC2, !Z      ; yes (means R6 != 0xFFFF): skip
                MOVE    R2, R6                  ; no; remember start address
QMON$LOAD_EXC2  MOVE    R2, R5                  ; R5 = current address
                RSUB    QMON$LOADHEX, 1
                MOVE    R2, @R5                 ; load binary to current address
                MOVE    R7, R8                  ; restore file handle
                MOVE    R11, R0                 ; reset working pointer
                MOVE    12, R1                  ; reset loop counter
                RBRA    QMON$LOAD_READ, 1       ; next address/value pair
QMON$LOAD_SCF   MOVE    QMON$CG_F_ILC1, R8      ; print "Error parsing file ("
                RSUB    IO$PUTS, 1
                MOVE    R12, R8                 ; print filename
                RSUB    IO$PUTS, 1
                MOVE    QMON$CG_F_ILC2, R8      ; print "). Illegal character: "
                RSUB    IO$PUTS, 1
                MOVE    @--R0, R8               ; print the illegal character
                RSUB    IO$PUTCHAR, 1
                RSUB    IO$PUT_CRLF, 1
                MOVE    _SD$DEVICEHANDLE, R8    ; invalidate device handle
                XOR     @R8, @R8
QMON$LOAD_EEE   ADD     12, SP                    ; free memory for address and value
QMON$LOAD_EE    ADD     FAT32$FDH_STRUCT_SIZE, SP ; free memory for file handle
QMON$LOAD_E     ADD     256, SP                   ; free memory for string input
                CMP     R6, 0xFFFF              ; did we successfully load something?
                RBRA    QMON$LOAD_RET, Z        ; no: return
                MOVE    QMON$CG_F_S1, R8        ; yes: print success and load addresses
                RSUB    IO$PUTS, 1
                MOVE    R12, R8
                RSUB    IO$PUTS, 1
                MOVE    QMON$CG_F_S2, R8
                RSUB    IO$PUTS, 1
                MOVE    R6, R8
                RSUB    IO$PUT_W_HEX, 1
                MOVE    QMON$CG_F_S3, R8
                RSUB    IO$PUTS, 1
                MOVE    R5, R8
                RSUB    IO$PUT_W_HEX, 1
                RSUB    IO$PUT_CRLF, 1
QMON$LOAD_RET   RET

QMON$LOADHEX    CMP     @R0++, '0'              ; sanity check
                RBRA    QMON$LOAD_E1E, !Z       ; failed
                CMP     @R0++, 'X'              ; sanity check
                RBRA    QMON$LOAD_E1E, !Z
                MOVE    4, R1                   ; address = 4 chars
                XOR     R2, R2                  ; R2 = address                
QMON$LOAD_E1    MOVE    @R0++, R8               ; current char
                MOVE    IO$HEX_NIBBLES, R9      ; list of valid chars in a hex number
                RSUB    STR$STRCHR, 1           ; check if char is valid
                CMP     R10, 0
                RBRA    QMON$LOAD_E1C, !Z       ; char is OK: go on
QMON$LOAD_E1E   ADD     1, SP                   ; char not OK: skip return address on stack
                RBRA    QMON$LOAD_SCF, 1        ; directly jump to error message
QMON$LOAD_E1C   SUB     IO$HEX_NIBBLES, R10     ; get numeric representation of char
                SHL     4, R2                   ; last digit moves to the left
                ADD     R10, R2                 ; current digit adds to address
                SUB     1, R1                   ; are we done?
                RBRA    QMON$LOAD_E1, !Z        ; no: next char
                RET


;***************************************************************************************
;* Strings
;***************************************************************************************
                
QMON$WELCOME    .ASCII_P    "\n\nSimple QNICE-monitor - Version 1.7 (Bernd Ulmann, sy2002, September 2020)\n"
#ifdef RAM_MONITOR
                .ASCII_P    "Running in RAM!\n"
#endif
                .ASCII_W    "-------------------------------------------------------------------------\n\n"
QMON$PROMPT     .ASCII_W    "QMON> "
QMON$ILLCMDGRP  .ASCII_W    " *** Illegal command group ***\n"
QMON$ILLCMD     .ASCII_W    " *** Illegal command ***\n"
QMON$HELP       .ASCII_P    "ELP:\n\n"
                .ASCII_P    "    C(control group):\n"
                .ASCII_P    "        C(old start) H(alt) R(un) Clear(S)creen\n"
                .ASCII_P    "    H(elp)\n"
                .ASCII_P    "    M(emory group):\n"
                .ASCII_P    "        C(hange) D(ump) E(xamine) F(ill) L(oad) M(ove)\n"
                .ASCII_P    "        di(S)assemble (Q)transfer\n"
                .ASCII_P    "    F(ile group):\n"
                .ASCII_P    "        List (D)irectory C(hange directory) L(oad) R(un)\n"
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
QMON$CG_F       .ASCII_W    "ILE/"
QMON$CG_F_D     .ASCII_W    "LIST DIRECTORY\n"
QMON$CG_F_EMNT  .ASCII_W    "Error mounting device: SD Card. Error code: "
QMON$CG_F_EOD   .ASCII_W    "Error opening current directory for reading. Error code: "
QMON$CG_F_EBD   .ASCII_W    "Error browsing current directory. Error code: "
QMON$CG_F_C     .ASCII_W    "CHANGE DIRECTORY: "
QMON$CG_F_ECD   .ASCII_W    "Error while changing directory. Error code: "
QMON$CG_F_ECDNF .ASCII_W    "Directory not found: "
QMON$CG_F_L     .ASCII_W    "LOAD: "
QMON$CG_F_EFNF  .ASCII_W    "File not found: "
QMON$CG_F_EFOF  .ASCII_W    "File open failed. Error code: "
QMON$CG_F_ELD   .ASCII_W    "Error loading file. Error code: "
QMON$CG_F_ILC1  .ASCII_W    "Error parsing file ("
QMON$CG_F_ILC2  .ASCII_W    "). Illegal character: "
QMON$CG_F_S1    .ASCII_W    "Successfully loaded "
QMON$CG_F_S2    .ASCII_W    " from "
QMON$CG_F_S3    .ASCII_W    " to "
QMON$CG_F_R     .ASCII_W    "RUN: "
QMON$CG_F_R_MSG .ASCII_W    "Running...\n"
