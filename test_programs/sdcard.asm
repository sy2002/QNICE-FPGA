; SD Card and FAT32 development testbed
; contains reusable functions that can be the basis for enhancing the monitor
; done by sy2002 in June, July 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; Initialize Variables
                MOVE    DIR_FLAGS, R8
                MOVE    FAT32$FA_DEFAULT, @R8
                MOVE    PRINT_FLAGS, R8
                MOVE    FAT32$PRINT_DEFAULT, @R8

                ; Reset SD Card
                MOVE    STR_RESET, R8
                SYSCALL(puts, 1)
                RSUB    SD$RESET, 1
                RSUB    ERR_CHECK, 1
                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                
                ; SD registers
                MOVE    IO$SD_ADDR_LO, R0
                MOVE    IO$SD_ADDR_HI, R1
                MOVE    IO$SD_DATA_POS, R2
                MOVE    IO$SD_DATA, R3
                MOVE    IO$SD_ERROR, R4
                MOVE    IO$SD_CSR, R5

                ; perform register write/read-back checks
                MOVE    STR_REGCHK_T, R8
                SYSCALL(puts, 1)
                MOVE    0, R11                  ; deactivate do not write mode
                MOVE    R0, R8                  ; check ADDR_LO
                MOVE    0x2309, R9
                MOVE    STR_REGCHK_AL, R10
                RSUB    REG_CHECK, 1
                MOVE    R1, R8                  ; check ADDR_HI
                MOVE    0xABA0, R9
                MOVE    STR_REGCHK_AH, R10
                RSUB    REG_CHECK, 1
                MOVE    R2, R8                  ; check DATA_POS
                MOVE    0x4505, R9
                MOVE    STR_REGCHK_DP, R10
                RSUB    REG_CHECK, 1
                MOVE    R3, R8                  ; check DATA
                MOVE    0x0076, R9              ; (is an 8-bit register)
                MOVE    STR_REGCHK_DTA, R10
                RSUB    REG_CHECK, 1
                MOVE    1, R11                  ; activate do not write mode
                MOVE    R4, R8                  ; ERROR is read only
                MOVE    0x0000, R9              ; and must be zero
                MOVE    STR_REGCHK_ER, R10
                RSUB    REG_CHECK, 1
                MOVE    R5, R8                  ; CSR status bits
                MOVE    0x0000, R9              ; must be zero
                MOVE    STR_REGCHK_CS, R10
                RSUB    REG_CHECK, 1

                ; main menu
MAIN_MENU       MOVE    STR_MEN_TITLE, R8
                SYSCALL(puts, 1)
                MOVE    STR_MEN_1, R8
                SYSCALL(puts, 1)
MAIN_MRR        SYSCALL(getc, 1)
                CMP     R8, '1'
                RBRA    IA_DUMP, Z
                CMP     R8, '2'
                RBRA    MNT_SD, Z
                CMP     R8, '3'
                RBRA    END_PROGRAM, Z

                RBRA    MAIN_MRR, 1

;=============================================================================
; Mount partition 1 as FAT32, perform various tests and enter interactive mode
;=============================================================================                

MNT_SD          MOVE    STR_MNT_TILE, R8        ; print testcase title
                SYSCALL(puts, 1)

                MOVE    DEVICE_HANDLE, R8       ; device handle
                MOVE    1, R9                   ; partition #1
                RSUB    FAT32$MOUNT_SD, 1       ; mount device
                MOVE    R9, R8
                RSUB    ERR_CHECK, 1
                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                MOVE    STR_MNT_FSSTART, R8     ; show fs start address
                MOVE    FAT32$DEV_FS_HI, R9
                MOVE    FAT32$DEV_FS_LO, R10
                MOVE    1, R11
                RSUB    OUTPUT_DW, 1

                MOVE    STR_MNT_FATSTRT, R8     ; show FAT start address
                MOVE    FAT32$DEV_FAT_HI, R9
                MOVE    FAT32$DEV_FAT_LO, R10
                RSUB    OUTPUT_DW, 1

                MOVE    STR_MNT_CLSSTRT, R8     ; show clusters start address
                MOVE    FAT32$DEV_CLUSTER_HI, R9
                MOVE    FAT32$DEV_CLUSTER_LO, R10
                RSUB    OUTPUT_DW, 1

                MOVE    STR_MNT_SPC, R8         ; show sectors per cluster
                MOVE    FAT32$DEV_SECT_PER_CLUS, R9
                MOVE    0, R11
                RSUB    OUTPUT_DW, 1

                MOVE    STR_MNT_ROOT, R8        ; show 1st cluster of root dir
                MOVE    FAT32$DEV_RD_1STCLUS_HI, R9
                MOVE    FAT32$DEV_RD_1STCLUS_LO, R10
                MOVE    1, R11
                RSUB    OUTPUT_DW, 1

                MOVE    STR_MNT_ACTIVE, R8      ; show 1st cluster active dir
                MOVE    FAT32$DEV_AD_1STCLUS_HI, R9
                MOVE    FAT32$DEV_AD_1STCLUS_LO, R10
                RSUB    OUTPUT_DW, 1

                SYSCALL(crlf, 1)

                MOVE    STR_INTERACTIVE, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                
                ; show prompt and read command
NEW_PROMPT      MOVE    STR_PROMPT, R8
                SYSCALL(puts, 1)
                MOVE    STRBUF, R0                
INPUT_LOOP      SYSCALL(getc, 1)
                SYSCALL(putc, 1)
                CMP     R8, 0x000D              ; accept CR as line end
                RBRA    INPUT_END, Z
                CMP     R8, 0x000A              ; accept LF as line end
                RBRA    INPUT_END, Z
                MOVE    R8, @R0++               ; store character
                RBRA    INPUT_LOOP, 1
INPUT_END       MOVE    0, @R0                  ; add zero terminator
                SYSCALL(crlf, 1)

                ; separate command from the rest of the string
                MOVE    STRBUF, R8
                MOVE    ' ', R9
                RSUB    SPLIT, 1
                MOVE    R9, R0                  ; R0 = restore stack offset
                MOVE    SP, R1                  ; R1 = string array

                CMP     R8, 0                   ; nothing entered
                RBRA    INPUT_NP, Z

                MOVE    R1, R8                  ; command array
                ADD     1, R8                   ; skip size
                SYSCALL(str2upper, 1)           ; command string to upper case

                ; check for "dir" command
                MOVE    STR_IB_DIR, R9
                SYSCALL(strcmp, 1)
                CMP     R10, 0                  ; dir command?
                RBRA    INPUT_N1, !Z            ; no: try next
                RSUB    DIR, 1                  ; yes: perform dir command
                RBRA    INPUT_NP, 1             ; new prompt

                ; check for "cd" command
INPUT_N1        MOVE    STR_IB_CD, R9
                SYSCALL(strcmp, 1)
                CMP     R10, 0                  ; cd command?
                RBRA    INPUT_N2, !Z            ; no: try next
                MOVE    2, R5                   ; lengh of command "CD"                
                RSUB    _INPUT_CHKPAR, 1        ; check for parameter                
                MOVE    DEVICE_HANDLE, R8       ; device handle for cd command
                MOVE    STRBUF, R9
                ADD     3, R9                   ; skip 3 chars ("cd ")
                MOVE    R9, R7                  ; remember path
                XOR     R10, R10
                RSUB    FAT32$CD, 1             ; change directory
                MOVE    R9, R8
                CMP     R8, FAT32$ERR_DIRNOTFOUND ; path not found?
                RBRA    _INPUTN1EC, !Z          ; other error or no error
                MOVE    STR_IB_CD_ERR, R8       ; error msg and new prompt
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                RBRA    INPUT_NP, 1             
_INPUTN1EC      RSUB    ERR_CHECK, 1
                RBRA    INPUT_NP, 1             ; new prompt

                ; check for "exit" command
INPUT_N2        MOVE    STR_IB_EXIT, R9
                SYSCALL(strcmp, 1)
                CMP     R10, 0                  ; exit command?
                RBRA    INPUT_N3, !Z            ; no: try next
                ADD     R0, SP                  ; yes: restore stack and exit
                RBRA    END_PROGRAM, 1

                ; check for "cat" command
INPUT_N3        MOVE    STR_IB_CAT, R9
                SYSCALL(strcmp, 1)
                CMP     R10, 0                  ; cat command?
                RBRA    INPUT_N4, !Z            ; no: try next
                MOVE    3, R5                   ; lengh of command "CAT"    
                RSUB    _INPUT_CHKPAR, 1        ; check for parameter                                
                MOVE    STRBUF, R8
                ADD     4, R8                   ; skip 4 chars ("cat ")
                XOR     R9, R9                  ; CAT mode = ASCII
_DOCAT          XOR     R10, R10                ; default: no seek
                XOR     R11, R11
                MOVE    R8, R7                  ; look for seek position
_DOCAT_SEARCHSP CMP     @R7, 0                  ; end of string?
                RBRA    _DOCAT_START, Z
                CMP     @R7++, ':'              ; seek position separator?
                RBRA    _DOCAT_READSP, Z        ; yes: read seek pos
                RBRA    _DOCAT_SEARCHSP, 1
_DOCAT_READSP   MOVE    R7, R10
                RSUB    _INPUT_READHEX, 1
                MOVE    0, @--R7                ; delete : using zero term.
_DOCAT_START    MOVE    R8, R7                  ; remember filename
                RSUB    CAT, 1                  ; yes: perform the command
                CMP     R8, FAT32$ERR_FILENOTFOUND ; file not found?
                RBRA    _INPUTN3SE, !Z          ; other error or no error
                MOVE    STR_IB_FNF_ERR, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)                
                RBRA    INPUT_NP, 1
_INPUTN3SE      CMP     R8, FAT23$ERR_SEEKTOOLARGE ; seek pos > file size?
                RBRA    _INPUTN3EC, !Z          ; other error or no error
                MOVE    STR_IB_SEEK_ERR, R8
                SYSCALL(puts, 1)
                MOVE    R11, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    INPUT_NP, 1
_INPUTN3EC      RSUB    ERR_CHECK, 1
                RBRA    INPUT_NP, 1             ; new prompt

                ; check for "cathex" command
INPUT_N4        MOVE    STR_IB_CATHEX, R9
                SYSCALL(strcmp, 1)
                CMP     R10, 0                  ; cathex command?
                RBRA    INPUT_ERR, !Z           ; no: error
                MOVE    6, R5                   ; lengh of command "CATHEX"
                RSUB    _INPUT_CHKPAR, 1        ; check for parameter                                                
                MOVE    STRBUF, R8
                ADD     7, R8                   ; skip 7 chars ("cathex ")
                MOVE    1, R9                   ; CAT mode = HEX
                RBRA    _DOCAT, 1

INPUT_ERR       MOVE    R8, R7
                MOVE    STR_REGCHK_ER, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                RBRA    INPUT_NP, 1

INPUT_NP        ADD     R0, SP                  ; restore stack
                RBRA    NEW_PROMPT, 1           ; new prompt

                ; parameter check sub-sub routine
                ; R5 contains length of command
                ; R9 contains name of command
                ; on error: skip command and next prompt
_INPUT_CHKPAR   MOVE    STRBUF, R6
                ADD     R5, R6
                CMP     ' ', @R6
                RBRA    _INPUT_CHKERR, !Z
                ADD     1, R6
                CMP     0, @R6
                RBRA    _INPUT_CHKERR, Z
                RET                             ; parameter OK: return                
_INPUT_CHKERR   MOVE    STR_IB_NOPAR, R8
                SYSCALL(puts, 1)
                MOVE    R9, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                SUB     1, SP                   ; avoid stack leak because ...
                RBRA    INPUT_NP, 1             ; ... we leave w/o RET

                ; hex read sub-sub routine
                ; INPUT:  R10 = string to be converted
                ; OUTPUT: R11|R10 = 32bit HI|LO value
                ; on error: skip command and next prompt
_INPUT_READHEX  INCRB

                MOVE    R10, R0                 ; R0 = input string
                XOR     R10, R10                ; return value low word
                XOR     R11, R11                ; return value high word

                MOVE    R8, R6                  ; save R8 & R9
                MOVE    R9, R7

                MOVE    R0, R8                  ; all chars upper case
                SYSCALL(str2upper, 1)

                MOVE    R0, R5                  ; R5 = work pointer
                MOVE    0, R1                   ; 8 digits = 32bit
                MOVE    12, R2                   ; SHL counter
                XOR     R3, R3                  ; temp LO word
                XOR     R4, R4                  ; temp HI word
                MOVE    _INPUT_RHX_NIB, R9      ; R9 = hex nibbles

_INPUT_RHX_LP   MOVE    @R5++, R8
                CMP     R8, 0                   ; zero term. too early?
                RBRA    _INPUT_RHX_ERR, Z       ; yes: error
                SYSCALL(strchr, 1)              ; find hex niblle
                CMP     R10, 0
                RBRA    _INPUT_RHX_ERR, Z       ; not found: error
                SUB     R9, R10                 ; extract digit
                SHL     R2, R10                 ; correct position for nibble
                SUB     4, R2                   ; next time: one nibble less
                CMP     R1, 3
                RBRA    _INPUT_RHX_HI, !N       ; R1 <= 3: HI (walk form left)
                ADD     R10, R3                 ; store to LO word
                RBRA    _INPUT_RHX_INC, 1
_INPUT_RHX_HI   ADD     R10, R4                 ; store to HI word
_INPUT_RHX_INC  ADD     1, R1                   ; next nibble
                CMP     8, R1                   ; done?
                RBRA    _INPUT_RHX_DONE, Z      ; yes
                CMP     4, R1                   ; reset SHL counter?
                RBRA    _INPUT_RHX_LP, !Z       ; no: loop
                MOVE    12, R2                  ; yes: reset SHL counter ...
                RBRA    _INPUT_RHX_LP, 1        ; ... and loop

_INPUT_RHX_DONE MOVE    R6, R8                  ; restore R8 & R9
                MOVE    R7, R9

                MOVE    R3, R10                 ; return value LO
                MOVE    R4, R11                 ; return value HI

                DECRB
                RET

_INPUT_RHX_NIB  .ASCII_W "0123456789ABCDEF"                

_INPUT_RHX_ERR  MOVE    STR_IB_HEX_ERR, R8
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)                
                DECRB
                SUB     1, SP                   ; avoid stack leak because ...
                RBRA    INPUT_NP, 1             ; ... we leave w/o RET

;=============================================================================
; Lists the contents of a file
; INPUT:  R8  = filename string
;         R9  = mode: 0 = ASCII, 1 = HEX
;         R10 = LO seek position 
;         R11 = HI seek position
; OUTPUT: R8 is 0, if everything is OK, otherwise R8 = error code
;=============================================================================

CAT             INCRB

                MOVE    R10, R0                     ; R1|R0 = HI|LO seek pos
                MOVE    R11, R1

                MOVE    R9, R5                      ; R5 = mode selector
                XOR     R4, R4                      ; R4 = count hex per line

                MOVE    R8, R10                     ; R10 = filename string
                MOVE    DEVICE_HANDLE, R8           ; R8 = device handle
                SUB     FAT32$FDH_STRUCT_SIZE, SP
                MOVE    SP, R9                      ; R9 = file handle
                XOR     R11, R11                    ; R11 = 0 => / sep.char
                RSUB    FAT32$FILE_OPEN, 1
                MOVE    R10, R8                     ; return error code
                RBRA    _CAT_RET, !Z                ; return if error

                MOVE    R9, R8                      ; R8 = file handle
                XOR     R6, R6                      ; R6 = CR/LF detector

                ; perform seek
                ; (the seek function is smart enough not to seek, if 0 is
                ; is passed as the seek position)
                MOVE    R9, @--SP                   ; save R9 & R10
                MOVE    R10, @--SP

                MOVE    R0, R9                      ; R10|R9 = seek pos
                MOVE    R1, R10
                RSUB    FAT32$FILE_SEEK, 1          ; perform seek
                CMP     R9, 0                       ; error?
                RBRA    _CAT_SEEKOK, Z              ; no
                MOVE    R9, R8                      ; yes: exit with error
                MOVE    @SP++, R10                  ; restore R9 & 10
                MOVE    @SP++, R9
                RBRA    _CAT_RET, 1                 ; exit with error

_CAT_SEEKOK     MOVE    @SP++, R10                  ; restore R9 & R10
                MOVE    @SP++, R9

                ; simple loop to print everything until EOF is reached
_CAT_LOOP       RSUB    FAT32$FILE_RB, 1            ; read byte
                CMP     R10, FAT32$EOF              ; EOF reached?
                RBRA    _CAT_EOF, Z                 ; yes: print crlf and exit
                CMP     R10, 0                      ; another error?
                RBRA    _CAT_PRINT, Z               ; no: go on
                MOVE    R10, R8                     ; yes: return error
                RBRA    _CAT_RET, 1

_CAT_PRINT      CMP     R5, 0                       ; print ASCII?
                RBRA    _CAT_PRINT_A, Z             ; yes
                CMP     R4, 16                      ; no: check hex counter
                RBRA    _CAT_PRINT_H, !Z            ; print hex word
                SYSCALL(crlf, 1)                    ; new line
                XOR     R4, R4                      ; reset hex counter                
_CAT_PRINT_H    MOVE    R8, R7
                MOVE    R9, R8
                SYSCALL(puthex, 1)                  ; print hex word
                MOVE    STR_SPACE1, R8
                SYSCALL(puts, 1)
                ADD     1, R4                       ; increase hex counter
                MOVE    R7, R8
                RBRA    _CAT_LOOP, 1

                ; support LF only CR only and CR/LF line ends
_CAT_PRINT_A    CMP     R9, CHR$CR                  ; CR?
                RBRA    _CAT_PT_CR, Z               ; yes
                CMP     R9, CHR$LF                  ; LF?
                RBRA    _CAT_PT_LF, Z               ; yes

                MOVE    R8, R7                      ; no: print character
                MOVE    R9, R8                
                SYSCALL(putc, 1)
                MOVE    R7, R8
                RBRA    _CAT_LOOP, 1                ; next byte

_CAT_PT_CR      SYSCALL(crlf, 1)                    ; next line
                MOVE    1, R6                       ; CR/LF detector ON
                RBRA    _CAT_LOOP, 1
_CAT_PT_LF      CMP     1, R6                       ; CR/LF?
                RBRA    _CAT_PT_LFI, Z              ; yes: ignore LF
                SYSCALL(crlf, 1)                    ; no: do the LF                
                RBRA    _CAT_LOOP, 1
_CAT_PT_LFI     XOR     R6, R6                      ; CR/LF OFF
                RBRA    _CAT_LOOP, 1

_CAT_EOF        SYSCALL(crlf, 1)
                MOVE    0, R8

_CAT_RET        ADD     FAT32$FDH_STRUCT_SIZE, SP   ; restore stack
                MOVE    R5, R9                      ; restore R9               
                MOVE    R0, R10                     ; restore R10 & R11
                MOVE    R1, R11 
                DECRB
                RET

;=============================================================================
; List current directory and use the settings stored in
; DIR_FLAGS and PRINT_FLAGS
;
; WARNING: In case of a fatal exit via ERR_CHECK, this leads to stack leaks
; (This does not matter here, because this function is not part of the
; reusable functions. It is just one of the test case functions that is
; testing the resubale functions. The reusable functions themselves are of
; course cleaning up the stack, also on error.)
;=============================================================================

DIR             INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                INCRB

                XOR     R4, R4                  ; file counter = 0

                MOVE    DEVICE_HANDLE, R8       ; open directory for browsing
                SUB     FAT32$FDH_STRUCT_SIZE, SP
                MOVE    SP, R0                  ; R0 = directory handle
                MOVE    R0, R9
                RSUB    FAT32$DIR_OPEN, 1
                MOVE    R8, R0                  ; test: R8 should still be R0
                MOVE    R9, R8
                RSUB    ERR_CHECK, 1

                SUB     FAT32$DE_STRUCT_SIZE, SP
                MOVE    SP, R1                  ; R1 = directory entry struct
NEXT_DIR_ENT    MOVE    R0, R8
                MOVE    R1, R9
                MOVE    DIR_FLAGS, R10
                MOVE    @R10, R10
                RSUB    FAT32$DIR_LIST, 1                
                MOVE    R11, R8
                RSUB    ERR_CHECK, 1
                CMP     R10, 1                  ; current entry valid?
                RBRA    DIR_DONE, !Z            ; no: end

                MOVE    R1, R8                  ; yes: print entry
                MOVE    PRINT_FLAGS, R9
                MOVE    @R9, R9
                RSUB    FAT32$PRINT_DE, 1

                ADD     1, R4                   ; increase file counter
                                                ; also includes "." and ".."

                RBRA    NEXT_DIR_ENT, 1         ; next entry

DIR_DONE        XOR     R9, R9                  ; print file counter (decimal)
                MOVE    R4, R8
                SUB     11, SP
                MOVE    SP, R10
                RSUB    H2D_ASCII, 1
                MOVE    R11, R8
                SYSCALL(puts, 1)
                MOVE    STR_IB_DIR_SUM, R8       
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                ADD     11, SP

                ; restore stack
                ; (does not happen in case of fatal error, i.e. in such a
                ; a case we have a stack leak and return to the monitor)
                ADD     FAT32$FDH_STRUCT_SIZE, SP
                ADD     FAT32$DE_STRUCT_SIZE, SP

                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                DECRB
                RET

;=============================================================================
; Interactive dump of linear SD Card addresses
;=============================================================================

                ; allow interactive dumps of arbitrary addresses
IA_DUMP         MOVE    STR_IA_TITLE, R8
                SYSCALL(puts, 1)
                MOVE    STR_IA_HIGH, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                MOVE    R8, R1                  ; block addr hi word
                SYSCALL(crlf, 1)
                MOVE    STR_IA_LOW, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                MOVE    R8, R0                  ; block read addr lo word
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; read 512 bytes from given address
                ; address must be a multiple of 512, otherwise the system
                ; will automatically "round it down" to the next 512 block
                MOVE    R0, R8
                MOVE    R1, R9
                RSUB    SD$READ_BLOCK, 1
                RSUB    ERR_CHECK, 1

                ; output the 512 bytes of the buffer
                MOVE    0, R6
OUTPUT_LOOP     MOVE    R6, R8                  ; read byte at position R6...
                RSUB    SD$READ_BYTE, 1         ; ...from buffer
                SYSCALL(puthex, 1)              ; output hex value
                MOVE    STR_SPACE2, R8          ; output two separating spaces
                SYSCALL(puts, 1)
                ADD     1, R6                   ; next byte
                MOVE    R6, R8                  ; if bytecount mod 16 is zero,
                MOVE    16, R9                  ; i.e. if a line has 16 hex
                SYSCALL(divu, 1)                ; numbers, then output a
                CMP     0, R11                  ; CR/LF so that the output
                RBRA    OUTPUT_LOOP_1, !Z       ; is nicely formatted
                SYSCALL(crlf, 1)
OUTPUT_LOOP_1   CMP     512, R6
                RBRA    OUTPUT_LOOP, !Z
                SYSCALL(crlf, 1)

                ; check if the user like to dump another buffer
                MOVE STR_IA_AGAIN, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
                SYSCALL(crlf, 1)
                CMP     'y', R8
                RBRA    IA_DUMP, Z
                RBRA    MAIN_MENU, 1

                ; back to monitor
END_PROGRAM     SYSCALL(exit, 1)


;=============================================================================
; Helper sub routines for performing the checks
;=============================================================================

; Register check subroutine: Expects the to be written and read-back
; register in R8, the value in R9 and the name string in R10
; R11: if 1 then no write is performed, only the read-back. This is needed
; for the CSR register as writing to it performs an action. It is also
; advisable for the ERROR register as you cannot write to it
REG_CHECK       INCRB
                MOVE    R8, R0

                ; print "checking <register name>"
                MOVE    STR_REGCHK_R, R8
                SYSCALL(puts, 1)
                MOVE    R10, R8
                SYSCALL(puts, 1)

                CMP     R11, 1
                RBRA    _REG_CHECK_DW, Z

                ; write SD card register, read it back and test the value
                MOVE    R9, @R0                 ; write to the register
_REG_CHECK_DW   MOVE    @R0, R1                 ; read it back
                CMP     R1, R9                  ; check if the read val is ok
                RBRA    _REG_CHECK_OK, Z        ; jump if OK
                MOVE    STR_FAILED, R8          ; print FAILED, if not OK...
                SYSCALL(puts, 1)
                MOVE    R1, R8
                SYSCALL(puthex, 1)              ; ...and show the wrong value
                RBRA    _REG_CHECK_CNT, 1
_REG_CHECK_OK   MOVE    STR_OK, R8              ; print OK, if OK
                SYSCALL(puts, 1)
_REG_CHECK_CNT  SYSCALL(crlf, 1)

                DECRB
                RET

; Error check subroutine: If R8 is nonzero, then the error code is printed
; and then the program is terminated
ERR_CHECK       INCRB

                CMP     R8, 0                   ; if no error: return
                RBRA    _ERR_CHECK_END, Z

                MOVE    R8, R9                  ; save error code
                MOVE    STR_ERR_END, R8         ; print error string
                SYSCALL(puts, 1)
                MOVE    R9, R8                  ; print error code
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                DECRB                           ; terminate execution
                SYSCALL(exit, 1)

_ERR_CHECK_END  DECRB
                RET

; Output a title and a DWORD value from the device handle
; R8 = Title
; R9 = offset lo
; R10 = offset hi
; R11: output DWORD, when R11 = 1, else output WORD
OUTPUT_DW       INCRB

                MOVE    R8, R0

                SYSCALL(puts, 1)

                MOVE    DEVICE_HANDLE, R8
                ADD     R9, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)

                CMP     1, R11
                RBRA    _OUTPUT_DW_END, !Z

                MOVE    DEVICE_HANDLE, R8
                ADD     R10, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)

_OUTPUT_DW_END  SYSCALL(crlf, 1)                
                MOVE    R0, R8

                DECRB
                RET

;=============================================================================
; Variables
;=============================================================================

DEVICE_HANDLE   .BLOCK 17                       ; mount struct / device handle

DIR_FLAGS       .BLOCK 1                        ; which file to browse? 
PRINT_FLAGS     .BLOCK 1                        ; which attributes to print?

;=============================================================================
; String constants
;=============================================================================

STR_TITLE       .ASCII_P "SD Card development testbed  -  done by sy2002 in June, July 2016\n"
                .ASCII_W "=================================================================\n\n"
STR_OK          .ASCII_W "OK"
STR_FAILED      .ASCII_W "FAILED: "
STR_SPACE1      .ASCII_W " "
STR_SPACE2      .ASCII_W "  "
STR_RESET       .ASCII_W "Resetting SD Card: "
STR_REGCHK_T    .ASCII_W "Register write and read-back:\n"
STR_REGCHK_R    .ASCII_W "    checking "
STR_REGCHK_AL   .ASCII_W "ADDR_LO: "
STR_REGCHK_AH   .ASCII_W "ADDR_HI: "
STR_REGCHK_DP   .ASCII_W "DATA_POS: "
STR_REGCHK_DTA  .ASCII_W "DATA: "
STR_REGCHK_ER   .ASCII_W "ERROR: "
STR_REGCHK_CS   .ASCII_W "CSR: "
STR_MEN_TITLE   .ASCII_W "\nChoose a test case to proceed:\n"
STR_MEN_1       .ASCII_P "    1.   Dump raw data from SD Card\n"
                .ASCII_P "    2.   Mount partition 1 (assuming valid MBR and a FAT32 file system)\n"
                .ASCII_W "    3.   Exit\n\n"
STR_IA_TITLE    .ASCII_W "Read 512 byte block from SD card and output it:\n"
STR_IA_HIGH     .ASCII_W "    Address HIGH word: "
STR_IA_LOW      .ASCII_W "    Address LOW word:  "
STR_IA_AGAIN    .ASCII_W "Enter 'y' for reading another block: "
STR_ERR_END     .ASCII_W "\nTERMINATED DUE TO FATAL ERROR: "
STR_MNT_TILE    .ASCII_W "Mounting partition #1 of SD Card as FAT32: "
STR_MNT_FSSTART .ASCII_W "    file system start address (LBA): "
STR_MNT_FATSTRT .ASCII_W "    FAT start address (LBA): "
STR_MNT_CLSSTRT .ASCII_W "    clusters start address (LBA): "
STR_MNT_SPC     .ASCII_W "    sectors per cluster: "
STR_MNT_ROOT    .ASCII_W "    root directory first cluster (LBA): "
STR_MNT_ACTIVE  .ASCII_W "    active directory first cluster (LBA): "
STR_INTERACTIVE .ASCII_P "Interactive browing mode:\n"
                .ASCII_P "    navigate: dir and cd <path> (use / as a path separator)\n"
                .ASCII_P "    list files (complex names are allowed, use / as path separator):\n"
                .ASCII_P "        cat <filename> and cathex <filename>\n"
                .ASCII_P "        for seeking within the file, add a 32bit hex number (8 digits)\n"
                .ASCII_P "        separated by a : after the filename, e.g. <filename>:00000000\n"
                .ASCII_W "    end interactive browsing mode using exit\n"
STR_PROMPT      .ASCII_W "SDCARD> "
STR_IB_DIR      .ASCII_W "DIR"
STR_IB_DIR_SUM  .ASCII_W " files and directories found."
STR_IB_CD       .ASCII_W "CD"
STR_IB_CD_ERR   .ASCII_W "Path not found: "
STR_IB_EXIT     .ASCII_W "EXIT"
STR_IB_CAT      .ASCII_W "CAT"
STR_IB_CATHEX   .ASCII_W "CATHEX"
STR_IB_FNF_ERR  .ASCII_W "File not found: "
STR_IB_NOPAR    .ASCII_W "Parameter missing for command: "
STR_IB_HEX_ERR  .ASCII_W "Illegal 32bit hex number for seek position: "
STR_IB_SEEK_ERR .ASCII_W "Seek position larger than file size: "

;=============================================================================
;=============================================================================
;
; REUSABLE FAT32 CONSTANT DEFINITIONS AND FUNCTIONS START HERE
;
;=============================================================================
;=============================================================================

; INTERNAL CONSTANTS FOR PARSING MBR and FAT32
; (not meant to be published in sysdef.asm)

FAT32$MBR_LO            .EQU    0x0000                  ; low byte of MBRs position (linear addressing)
FAT32$MBR_HI            .EQU    0x0000                  ; high byte of MBRs position (linear addressing)
FAT32$MBR_MAGIC         .EQU    0xAA55                  ; magic word at address #510 (decoded to big endian, stored as 0x55AA)
FAT32$MBR_MAGIC_ADDR    .EQU    0x01FE                  ; absolute address of magic bytes
FAT32$MBR_PARTTBL_START .EQU    0x01BE                  ; absolute start address of the partition table
FAT32$MBR_PARTTBL_RSIZE .EQU    0x0010                  ; size of each partition table record in bytes
FAT32$MBR_PT_TYPE       .EQU    0x0004                  ; partition type address (relative to the partition table)
FAT32$MBR_PT_TYPE_C1    .EQU    0x000B                  ; type flag (alternative 1) for FAT32
FAT32$MBR_PT_TYPE_C2    .EQU    0x000C                  ; type flag (alternative 2) for FAT32
FAT32$MBR_PT_FS_START   .EQU    0x0008                  ; file system start sector (relative to the partition table)

FAT32$MAGIC             .EQU    0xAA55                  ; volume id magic
FAT32$MAGIC_OFS         .EQU    0x01FE                  ; offset of volume id magic (word)
FAT32$JMP1_1            .EQU    0x00EB                  ; Sanity check: Jump instruction to boot code:
FAT32$JMP2              .EQU    0x00E9                  ; (JMP1_1 AND JMP1_2) OR JMP_2
FAT32$JMP1_OR_2_OFS     .EQU    0x0000                  
FAT32$JMP1_2            .EQU    0x0090
FAT32$JMP1_2_OFS        .EQU    0x0002
FAT32$SANITY            .EQU    0x0000                  ; (word) must be zero on FAT32
FAT32$SANITY_OFS        .EQU    0x0016
FAT32$SECTOR_SIZE       .EQU    0x0200                  ; we assume the ubiquitous 512-byte sectors
FAT32$SECTOR_SIZE_OFS   .EQU    0x000B                  ; offset of sector size in volume id (word)
FAT32$FATNUM            .EQU    0x0002                  ; number of FATs (needs to be always two) (byte)
FAT32$FATNUM_OFS        .EQU    0x0010                  ; offset of number of FATs in volume id (byte)
FAT32$SECPERCLUS_OFS    .EQU    0x000D                  ; should be 1, 2, 4, 8, 16, 32, 64, 128 (byte)
FAT32$RSSECCNT_OFS      .EQU    0x000E                  ; number of reserved sectors (word)
FAT32$SECPERFAT_OFS     .EQU    0x0024                  ; sectors per fat, depends on disk size (dword)
FAT32$ROOTCLUS_OFS      .EQU    0x002C                  ; root directory first cluster (dword)

FAT32$FE_SIZE           .EQU    0x0020                  ; size of one directory entry
FAT32$FE_DEL            .EQU    0x00E5                  ; flag for deleted (or "empty") entry
FAT32$FE_NOMORE         .EQU    0x0000                  ; flag for last deleted (or "empty") entry, no more are following
FAT32$FE_ATTRIB         .EQU    0x000B                  ; offset of the file attribute
FAT32$FE_FILESIZE       .EQU    0x001C                  ; offset of the file size (dword)
FAT32$FE_FILEDATE       .EQU    0x0018                  ; date of last write (creation is treated as write)
FAT32$FE_FILETIME       .EQU    0x0016                  ; time of last write (creation is treated as write)
FAT32$FE_CLUS_LO        .EQU    0x001A                  ; first cluster: low word
FAT32$FE_CLUS_HI        .EQU    0x0014                  ; first cluster: high word
FAT32$FE_DISPLAYCASE    .EQU    0x000C                  ; only for short names: bit 3 = display filename lower case, bit 4 = ext. lower case
FAT32$FE_DC_NAME_MASK   .EQU    0x0008                  ; FAT32$FE_DISPLAYCASE: filter for bit 3
FAT32$FE_DC_EXT_MASK    .EQU    0x0010                  ; FAT32$FE_DISPLAYCASE: filter for bit 4
FAT32$FE_SPECIAL_CHAR   .EQU    0x0005                  ; if the first char is this, then replace by E5
FAT32$FE_PADDING        .EQU    0x0020                  ; padding used in short file names
FAT32$FE_LE_FINAL       .EQU    0x0040                  ; flag signalling last entry of a long filename table
FAT32$FE_LE_CHKSUM      .EQU    0x000D                  ; long filename checksum
FAT32$FE_LE_C1_5        .EQU    0x0001                  ; long filename: characters 1 .. 5
FAT32$FE_LE_C6_11       .EQU    0x000E                  ; long filename: characters 6 .. 11
FAT32$FE_LE_C12_13      .EQU    0x001C                  ; long filename: characters 12 .. 13


FAT32$INT_LONG_NAME     .EQU    0x000F                  ; internal flag used to filter for long file names
FAT32$INT_LONG_MASK     .EQU    0x003F                  ; internal mask for filtering long file file and directory names

FAT32$PRINT_DE_DIR_Y    .ASCII_W "<DIR> "
FAT32$PRINT_DE_DIR_N    .ASCII_W "      "
FAT32$PRINT_DE_DIR_S    .ASCII_W "           "
FAT32$PRINT_DE_AN       .ASCII_W " "
FAT32$PRINT_DE_AH       .ASCII_W "H"
FAT32$PRINT_DE_AR       .ASCII_W "R"
FAT32$PRINT_DE_AS       .ASCII_W "S"
FAT32$PRINT_DE_AA       .ASCII_W "A"
FAT32$PRINT_DE_DATE     .ASCII_W "-"
FAT32$PRINT_DE_TIME     .ASCII_W ":"

;
;*****************************************************************************
;* SD$RESET resets the SD Card
;*
;* R8: 0, if everything went OK, otherwise the error code
;*****************************************************************************
;
SD$RESET        INCRB
                MOVE    IO$SD_CSR, R0                
                MOVE    SD$CMD_RESET, @R0
                RSUB    SD$WAIT_BUSY, 1
                DECRB
                RET
;
;*****************************************************************************
;* SD$READ_BLOCK reads a 512 byte block from the SD Card
;*
;* INPUT:  R8/R9 = LO/HI words of the 32-bit read address
;* OUTPUT: R8 = 0 (no error), or error code
;*
;* The read data is stored inside 512 byte buffer of the the SD controller 
;* memory that can then be accessed via SD$READ_BYTE.
;*
;* IMPORTANT: The 32-bit read address must be a multiple of 512, otherwise it
;* will be automatically "down rounded" to the nearest 512 byte block.
;*****************************************************************************
;
SD$READ_BLOCK   INCRB

                MOVE    R8, R1                  ; save R8 due to WAIT_BUSY

                RSUB    SD$WAIT_BUSY, 1         ; wait to be ready
                CMP     R8, 0                   ; error?
                RBRA    _SD$RB_END, !Z          ; yes: return

                MOVE    IO$SD_ADDR_LO, R0       ; lo word of 32-bit address
                MOVE    R1, @R0
                MOVE    IO$SD_ADDR_HI, R0       ; hi word of 32-bit address
                MOVE    R9, @R0
                MOVE    IO$SD_CSR, R0
                MOVE    SD$CMD_READ, @R0        ; issue block read command
                RSUB    SD$WAIT_BUSY, 1         ; wait until finished

_SD$RB_END      DECRB
                RET
;
;*****************************************************************************
;* SD$WRITE_BLOCK writes a 512 byte block to the SD Card
;*
;* @TODO: Implement and document
;*****************************************************************************
;
SD$WRITE_BLOCK  INCRB
                DECRB
                RET
;
;*****************************************************************************
;* SD$READ_BYTE reads a byte from the read buffer memory of the controller
;*
;* INPUT:  R8 = address between 0 .. 511
;* OUTPUT: R8 = byte
;*
;* No boundary checks are performed.
;*****************************************************************************
;
SD$READ_BYTE    INCRB

                MOVE    IO$SD_DATA_POS, R0
                MOVE    R8, @R0
                MOVE    IO$SD_DATA, R0
                MOVE    @R0, R8

                DECRB
                RET
;
;*****************************************************************************
;* SD$WRITE_BYTE writes a byte to the write memory buffer of the controller
;*
;* @TODO: Implement and document
;*****************************************************************************
;
SD$WRITE_BYTE   INCRB
                DECRB
                RET
;
;*****************************************************************************
;* SD$WAIT_BUSY waits, while the SD Card is executing any command
;*
;* R8: 0, if everything went OK, otherwise the error code
;*
;* Side effect: Starts the cycle counter (if it was stopped), but does not
;* reset the value, so that other countings are not influenced. 
;*****************************************************************************
;
SD$WAIT_BUSY    INCRB

                ; Make sure that the cycle counter is running for being
                ; able to measure the timeout. Do not reset it, but find
                ; the target value via addition (wrap around is OK), so that
                ; other running cycle counting processes are not disturbed
                ; by this
                MOVE    IO$CYC_STATE, R0        ; make sure, the cycle counter
                OR      CYC$RUN, @R0            ; is running
                MOVE    IO$CYC_MID, R3
                MOVE    @R3, R7
                ADD     SD$TIMEOUT_MID, R7

                ; check busy status of SD card and timeout
                MOVE    IO$SD_CSR, R0           ; SD Card Command & Status
                MOVE    IO$SD_ERROR, R2         ; SD Card Errors
_SD$WAIT_BUSY_L MOVE    @R3, R1                 ; check for timeout
                CMP     R1, R7                  ; timeout reached
                RBRA    _SD$WAIT_TO, Z          ; yes: return timeout
                MOVE    @R0, R1                 ; read CSR register       
                AND     SD$BIT_BUSY, R1         ; check busy flag
                RBRA    _SD$WAIT_BUSY_L, !Z     ; loop if busy flag is set
                MOVE    @R2, R8                 ; return error value
                RBRA    _SD$WAIT_END, 1

_SD$WAIT_TO     MOVE    SD$ERR_TIMEOUT, R8
_SD$WAIT_END    DECRB
                RET  
;
;*****************************************************************************
;* FAT32$MOUNT_SD mounts a SD card partition as a FAT32 file system
;*
;* Wrapper to simplify the use of the generic FAT32$MOUNT function. Read the
;* documentation of FAT32$MOUNT to learn more.
;* 
;* INPUT:  R8 points to a 17 word large empty structure. This structure will
;*         be filled by the mount function and it therefore becomes the device
;*         handle that you need for subsequent FAT32 function calls. For being
;*         on the safe side: Instead of hardcoding "17", use the constant
;*         FAT32$DEV_STRUCT_SIZE instead.
;*         R9 partition number to mount (1 .. 4)
;* OUTPUT: R8 points to the handle (identical to the input value of R8)
;*         R9 contains 0 if OK, otherwise the error code
;*****************************************************************************
;
FAT32$MOUNT_SD  INCRB

                ; store the function pointers to the SD card specific
                ; device handling functions within the mount structure
                ; and set the partition to 1
                MOVE    R8, R0
                ADD     FAT32$DEV_RESET, R0
                MOVE    SD$RESET, @R0
                MOVE    R8, R0
                ADD     FAT32$DEV_BLOCK_READ, R0
                MOVE    SD$READ_BLOCK, @R0
                MOVE    R8, R0
                ADD     FAT32$DEV_BLOCK_WRITE, R0
                MOVE    SD$WRITE_BLOCK, @R0
                MOVE    R8, R0
                ADD     FAT32$DEV_BYTE_READ, R0
                MOVE    SD$READ_BYTE, @R0
                MOVE    R8, R0
                ADD     FAT32$DEV_BYTE_WRITE, R0
                MOVE    SD$WRITE_BYTE, @R0
                MOVE    R8, R0
                ADD     FAT32$DEV_PARTITION, R0
                MOVE    R9, @R0

                ; call master mount function
                RSUB    FAT32$MOUNT, 1

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$MOUNT mounts a FAT32 file system on arbitrary hardware
;*
;* The abstraction requires 5 functions to be implemented: Read and write
;* a 512-byte-sized sector using LBA mode. Read and write a byte from within
;* a buffer that contains the current sector. Reset the device. The function
;* signatures and behaviour needs to be equivalent to the SD card functions
;* that are part of this library. You need to pass pointers to these functions
;* to the mount function call in the mount initialization structure.
;*
;* All subsequent calls to FAT32 functions expect as the first parameter a
;* pointer to the mount data structure (aka device handle) that is being
;* generated during the execution of this function. With this mechanism, an
;* arbitrary amount of filesystems can be mounted on an arbitrary amount and
;* type of hardware.
;*
;* INPUT: R8: pointer to the mount initialization structure that is build up
;* in the following form. Important: The structure is 17 words large, that
;* means that a call to FAT32$MOUNT will append more words to the structure
;* than the ones, that have to be pre-filled before calling FAT32$MOUNT:
;*  word #0: pointer to a device reset function, similar to SD$RESET
;*  word #1: pointer to a block read function, similar to SD$READ_BLOCK
;*  word #2: pointer to a block write function, similar to SD$WRITE_BLOCK
;*  word #3: pointer to a byte read function, similar to SD$READ_BYTE
;*  word #4: pointer to a byte write function, similar to SD$WRITE_BYTE
;*  word #5: number of the partition to be mounted (0x0001 .. 0x0004)
;*  word #6 .. word #17 : will be filled by by FAT32$MOUNT, their layout is
;*                        as described in the FAT32$DEV_* constants beginning
;*                        from index #7 on.
;*
;* For being on the safe side: Instead of hardcoding "17" as the size of the
;* whole mount data structure (device handle) use the constant 
;* FAT32$DEV_STRUCT_SIZE instead.
;*
;* OUTPUT: R8 is preserved and still points to the structure that has been
;* filled by the function from word #6 on.
;* R9 contains 0, if everything went OK, otherwise it contains the error code
;*****************************************************************************
;
FAT32$MOUNT     INCRB                           ; sometimes more registers ..
                INCRB                           ; .. are needed, so 2x INCRB

                MOVE    R8, R0                  ; save pointer to structure

                MOVE    R8, @--SP
                MOVE    R10, @--SP
                MOVE    R11, @--SP
                MOVE    R12, @--SP

                ; reset the device and exit on error
_F32_MNT_RESET  MOVE    FAT32$DEV_RESET, R10
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                MOVE    R8, R9
                RBRA    _F32_MNT_END, !Z

                ; read the Master Boot record and sector and check the
                ; magic bytes as a first indication of a working MBR
                MOVE    FAT32$MBR_LO, R8            ; address (LBA) of MBR
                MOVE    FAT32$MBR_HI, R9
                MOVE    FAT32$DEV_BLOCK_READ, R10   ; read 512 byte sector
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                CMP     0, R8
                RBRA    _F32_MNT_MBR, Z
                MOVE    R8, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_MBR    MOVE    R0, R8
                MOVE    FAT32$MBR_MAGIC_ADDR, R9    ; read magic word
                RSUB    FAT32$READ_W, 1
                CMP     FAT32$MBR_MAGIC, R10        ; compare magic word
                RBRA    _F32_MNT_PNCHK, Z           ; magic correct: go on
                MOVE    FAT32$ERR_MBR, R9           ; magic wrong: error code
                RBRA    _F32_MNT_END, 1

                ; calculate partition table start offset: this is defined as:
                ;     FAT32$MBR_PARTTBL_START +
                ;     ((#partition - 1) x FAT32$MBR_PARTTBL_RSIZE)
                ; we need to subtract 1 from #partition, because the number
                ; of partitions are defined to be between 1 and 4
_F32_MNT_PNCHK  MOVE    R0, R8                      ; get device handle
                ADD     FAT32$DEV_PARTITION, R8     ; retrieve the partition..
                MOVE    @R8, R8                     ; ..that shall be mounted
                CMP     R8, 0                       ; partition must be 1 .. 4
                RBRA    _F32_MNT_PNGOK, N           ; partition is > 0: OK
_F32_MNT_PNERR  MOVE    FAT32$ERR_PARTITION_NO, R9  ; exit with an error
                RBRA    _F32_MNT_END, 1
_F32_MNT_PNGOK  CMP     R8, 4
                RBRA    _F32_MNT_POFFS, !N          ; partition is <= 4: OK 
                RBRA    _F32_MNT_PNERR, 1           ; else exit with an error
_F32_MNT_POFFS  SUB     1, R8                       ; #partition - 1
                MOVE    FAT32$MBR_PARTTBL_RSIZE, R9 ; mult. with record size
                SYSCALL(mulu, 1)                    ; result is in R10
                ADD     FAT32$MBR_PARTTBL_START, R10
                MOVE    R10, R12                    ; offset is now in R12

                ; read and decode the selected partition table entry:
                ; 1. check for the FAT32 type description
                ; 2. check, if the linear start address of the file system
                ;    of the first partition is less than ~31MB, because
                ;    otherwise we would need better multiplication functions
                ;    (see explanation about hardcoded partition 1 above)
                ; 3. calculate the linar start address by multiplying the
                ;    sector number with 512
_F32_MNT_RPAR   MOVE    R12, R8                     ; partition table offset
                ADD     FAT32$MBR_PT_TYPE, R8       ; type flag: FAT32 ?
                MOVE    FAT32$DEV_BYTE_READ, R10
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                CMP     FAT32$MBR_PT_TYPE_C1, R8    ; check for alternative 1
                RBRA    _F32_MNT_TCOK, Z            ; OK: continue
                CMP     FAT32$MBR_PT_TYPE_C2, R8    ; check for alternative 2
                RBRA    _F32_MNT_TCOK, Z            ; OK: continue
                MOVE    FAT32$ERR_PARTTBL, R9       ; not OK: error code
                RBRA    _F32_MNT_END, 1  
_F32_MNT_TCOK   MOVE    R0, R8                      ; device handle
                MOVE    R12, R9                     ; partition table offset
                ADD     FAT32$MBR_PT_FS_START, R9   ; find FS start sector
                RSUB    FAT32$READ_DW, 1
                MOVE    R0, R1                      ; device handle
                ADD     FAT32$DEV_FS_LO, R1         ; FS start LBA low word
                MOVE    R10, @R1                    ; store it in device hndl
                MOVE    R0, R1
                ADD     FAT32$DEV_FS_HI, R1         ; FS start LBA low word
                MOVE    R11, @R1                    ; store it in device hndl

                ; Go to the first 512 byte sector of the file system (FS)
                ; and read it. For doing so, a 2 x 32bit multiplication
                ; needs to be utilized, because the FS start LBA
                ; FAT32$DEV_FS_LO / FAT32$DEV_FS_HI is 32bit and this needs
                ; to be multiplied by FAT32$SECTOR_SIZE (512) to obtain
                ; the linar address. But the upper two words of the 64bit
                ; result value need to be zero, otherwise the medium is too
                ; large to be handled by this FAT32 implementation
                MOVE    R10, R8
                MOVE    R11, R9
                MOVE    FAT32$SECTOR_SIZE, R10
                MOVE    0, R11
                RSUB    MULU32, 1
                CMP     0, R11
                RBRA    _F32_MNT_SERR, !Z
                CMP     0, R10
                RBRA    _F32_MNT_SERR, !Z
                RBRA    _F32_MNT_DVID, 1
_F32_MNT_SERR   MOVE    FAT32$ERR_SIZE, R9
                RBRA    _F32_MNT_END, 1
               
                ; decode the FAT32 Volume ID (1st 512 byte sector)
                ; 1. sanity check: jump instruction to boot code
                ; 2. sanity check: word offs 22 must be zero on FAT32
                ; 3. check for magic
                ; 4. check for 512-byte sector size
                ; 5. check for two FATs
                ; 6. read sectors per fat and check if the hi word of sectors
                ;    per fat is zero, as we otherwise would again run into
                ;    multiplication problems (see above)
                ; 7. read root directory first cluster and check if the hi
                ;    word is zero for the same reason
                ; 8. read sectors per cluster
                ; 9. read reserved sectors
_F32_MNT_DVID   MOVE    FAT32$DEV_BLOCK_READ, R10
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                CMP     0, R8
                RBRA    _F32_MNT_VID, Z
                MOVE    R8, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_VID    MOVE    R0, R8
                MOVE    FAT32$JMP1_OR_2_OFS, R9     ; sanity check: jump inst.
                RSUB    FAT32$READ_B, 1
                CMP     FAT32$JMP2, R10
                RBRA    _F32_MNT_SAN, Z
                CMP     FAT32$JMP1_1, R10
                RBRA    _F32_MNT_VERR, !Z
                MOVE    FAT32$JMP1_2_OFS, R9
                RSUB    FAT32$READ_B, 1
                CMP     FAT32$JMP1_2, R10
                RBRA    _F32_MNT_VERR, !Z
_F32_MNT_SAN    MOVE    FAT32$SANITY_OFS, R9
                RSUB    FAT32$READ_W, 1
                CMP     FAT32$SANITY, R10
                RBRA    _F32_MNT_MGC, Z
                RBRA    _F32_MNT_VERR, 1                
_F32_MNT_MGC    MOVE    FAT32$MAGIC_OFS, R9         ; check magic
                RSUB    FAT32$READ_W, 1
                CMP     FAT32$MAGIC, R10
                RBRA    _F32_MNT_VERR, !Z
                MOVE    FAT32$SECTOR_SIZE_OFS, R9   ; check 512 byte sector
                RSUB    FAT32$READ_W, 1
                CMP     FAT32$SECTOR_SIZE, R10
                RBRA    _F32_MNT_VERR, !Z
                MOVE    FAT32$FATNUM_OFS, R9        ; check for two FATs
                RSUB    FAT32$READ_B, 1
                CMP     FAT32$FATNUM, R10
                RBRA    _F32_MNT_VERR, !Z
                RBRA    _F32_MNT_RVID, 1
_F32_MNT_VERR   MOVE    FAT32$ERR_NOFAT32, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_RVID   MOVE    R0, R8
                MOVE    FAT32$SECPERFAT_OFS, R9     ; read sectors per FAT
                RSUB    FAT32$READ_DW, 1
                MOVE    R10, R1                     ; R1: sectors per FAT LO
                MOVE    R11, R2                     ; R2: sectors per FAT HI
                MOVE    FAT32$ROOTCLUS_OFS, R9      ; read root dir 1st clus.
                RSUB    FAT32$READ_DW, 1
                MOVE    R10, R3                     ; R3: rootdir 1st clus. LO
                MOVE    R11, R4                     ; R4: rootdir 1st clus. HI
                MOVE    FAT32$SECPERCLUS_OFS, R9    ; read sectors per cluster
                RSUB    FAT32$READ_B, 1
                MOVE    R10, R5                     ; R5: sectors per cluster
                MOVE    FAT32$RSSECCNT_OFS, R9      ; read number resvd. sec.
                RSUB    FAT32$READ_W, 1
                MOVE    R10, R6                     ; R6: # reserved sectors

                ; calculate begin of FAT (LBA)
                ; fat_begin_lba = Partition_LBA_Begin + Num_of_Rsvd_Sectors
                MOVE    R0, R8
                ADD     FAT32$DEV_FS_LO, R8
                MOVE    @R8, R8                     ; FS start: LO
                MOVE    R0, R9
                ADD     FAT32$DEV_FS_HI, R9
                MOVE    @R9, R9                     ; FS start: HI
                ADD     R6, R8                      ; 32bit add resvd. sect.
                ADDC    0, R9
                MOVE    R0, R7
                ADD     FAT32$DEV_FAT_LO, R7        ; store it in device hndl
                MOVE    R8, @R7
                MOVE    R0, R7
                ADD     FAT32$DEV_FAT_HI, R7
                MOVE    R9, @R7

                ; calculate begin of clusters (LBA)
                ; clust_begin_lba = fat_begin_lba + (Num_FATs * Sect_per_FAT)
                DECRB
                MOVE    R8, R0                      ; save FAT start LO
                MOVE    R9, R1                      ; save FAT start HI
                INCRB
                MOVE    2, R8                       ; Num_FATs is hardcoded 2
                MOVE    0, R9
                MOVE    R1, R10                     ; sectors per fat LO
                MOVE    R2, R11                     ; sectors per fat HI
                RSUB    MULU32, 1
                CMP     0, R10
                RBRA    _F32_MNT_SERR, !Z
                CMP     0, R11
                RBRA    _F32_MNT_SERR, !Z
                DECRB
                MOVE    R0, R10                     ; restore FAT start LO
                MOVE    R1, R11                     ; restore FAT start HI
                INCRB
                ADD     R10, R8                     ; 32bit addition ..
                ADDC    R11, R9                     ; .. result is in R9|R8
                MOVE    R0, R10
                ADD     FAT32$DEV_CLUSTER_LO, R10
                MOVE    R8, @R10                    ; store result LO
                MOVE    R0, R10
                ADD     FAT32$DEV_CLUSTER_HI, R10
                MOVE    R9, @R10                    ; store result HI

                ; store sectors per cluster and root directory 1st cluster
                ; and set currently active directory to root directory
                MOVE    R0, R10
                ADD     FAT32$DEV_SECT_PER_CLUS, R10
                MOVE    R5, @R10
                MOVE    R0, R10
                ADD     FAT32$DEV_RD_1STCLUS_LO, R10
                MOVE    R3, @R10
                MOVE    R0, R10
                ADD     FAT32$DEV_RD_1STCLUS_HI, R10
                MOVE    R4, @R10
                MOVE    R0, R10
                ADD     FAT32$DEV_AD_1STCLUS_LO, R10
                MOVE    R3, @R10
                MOVE    R0, R10
                ADD     FAT32$DEV_AD_1STCLUS_HI, R10
                MOVE    R4, @R10

                MOVE    0, R9                       ; no errors occured

_F32_MNT_END    MOVE    @SP++, R12
                MOVE    @SP++, R11                  ; restore registers
                MOVE    @SP++, R10
                MOVE    @SP++, R8

                DECRB
                DECRB
                RET
;
;*****************************************************************************
;* FAT32$DIR_OPEN opens the current directory for browsing
;*
;* Call this function, before working with FAT32$DIR_LIST. Directly after
;* mounting a device, the "current directory" equals the root directory.
;*
;* INPUT:  R8  points to a valid device handle
;*         R9  points to an empty directory handle struct that will be filled
;*             (use FAT32$FDH_STRUCT_SIZE to reserve the memory)
;* OUTPUT: R8  points to the filled directory handle structure, i.e. it points
;*             to where R9 originally pointed to
;*         R9  0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$DIR_OPEN  INCRB

                MOVE    R9, R0                      ; save device handle
                ADD     FAT32$FDH_DEVICE, R0
                MOVE    R8, @R0

                MOVE    R8, R0                      ; save the cluster of ...
                ADD     FAT32$DEV_AD_1STCLUS_LO, R0 ; ... the current dir.                
                MOVE    R9, R1
                ADD     FAT32$FDH_CLUSTER_LO, R1
                MOVE    @R0, @R1
                MOVE    @R0, R2
                MOVE    R8, R0
                ADD     FAT32$DEV_AD_1STCLUS_HI, R0
                MOVE    R9, R1
                ADD     FAT32$FDH_CLUSTER_HI, R1
                MOVE    @R0, @R1
                MOVE    @R0, R3

                MOVE    R9, R0                      ; start with sector 0
                ADD     FAT32$FDH_SECTOR, R0
                MOVE    0, @R0

                MOVE    R9, R0                      ; start with index 0
                ADD     FAT32$FDH_INDEX, R0
                MOVE    0, @R0 

                MOVE    R9, R0                      ; remember dir. handle

                MOVE    R2, R9                      ; low word of cluster
                MOVE    R3, R10                     ; high word of cluster
                MOVE    0, R11                      ; sector
                RSUB    FAT32$READ_SIC, 1           ; R9 contains OK or error

                MOVE    R0, R8                      ; return dir. handle

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$DIR_LIST is used to browse the currently active directory
;*
;* This function is meant to be called iteratively to return one directory
;* entry after the other. It supports long filenames. The implementation
;* supports a maximum of 65.535 files within one folder.
;*
;* INPUT:  R8  points to a valid directory handle (created by FAT32$DIR_OPEN)
;*         R9  points to am empty directoy entry structure, having the size of
;*             FAT32$DE_STRUCT_SIZE, that will be filled by this function.
;*         R10 or-ed list of FAT32$FA_* flags to filter for certain types:
;*             if the attribute is not set, then an entry having this flag
;*             will not be browsed (i.e. it will be hidden). Use
;*             FAT32$FA_DEFAULT, if you want to browse for all non hidden
;*             files and directories.
;* OUTPUT: R8  still points to the directory handle
;*         R9  points to the now filled directory entry structure
;*         R10 1, if the current entry is a valid entry and therefore another
;*             iteration (i.e. call to FAT32$DIR_LIST) makes sense
;*             0, if the current entry is not valid and therefore the end
;*             of the directory has been reached (R11 is 0 in such a case)
;*         R11 0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$DIR_LIST  INCRB                               ; if referenced in
                MOVE    R8, R0                      ; comments, the registers
                MOVE    R9, R1                      ; of this bank are 
                MOVE    R12, R7                     ; prefixed with a §

                MOVE    R10, R2                     ; §R2 = attrib filters
                                                    ; §R3 and §R4 used below
                INCRB

                MOVE    R8, R0
                ADD     FAT32$FDH_DEVICE, R0
                MOVE    @R0, R0                     ; R0 = device handle
                MOVE    R8, R1                      ; R1 = directory handle
                MOVE    R9, R2                      ; R2 = dir. entry struct.

                ; make sure that the 512-byte read-buffer contains the
                ; sector that is needed, and in parallel update the file and
                ; directory handle, if necessary
_F32_DLST_SKIP  RSUB    FAT32$READ_FDH, 1
                CMP     R9, 0
                RBRA    _F32_DLST_C1, Z
                MOVE    0, R10
                MOVE    R9, R11                
                RBRA    _F32_DLST_END, 1

                ; read the first byte (byte #0)
_F32_DLST_C1    MOVE    R0, R8                      ; R8 = device handle
                MOVE    R1, R3 
                ADD     FAT32$FDH_INDEX, R3         ; R3 = pointer to index
                MOVE    @R3, R4                     ; R4 = index aka byte addr
                MOVE    R4,  R9                     ; R9 = address of byte
                RSUB    FAT32$READ_B, 1             ; read byte to R10

                ; check if we reached the end of the directory
                CMP     R10, FAT32$FE_NOMORE        ; last entry?
                RBRA    _F32_DLST_C2, !Z            ; no: go on checking
                MOVE    0, R10                      ; yes, EOD reached
                MOVE    0, R11
                RBRA    _F32_DLST_END, 1

                ; check, if the entry marks a deleted entry and if yes
                ; skip it
_F32_DLST_C2    CMP     R10, FAT32$FE_DEL           ; deleted entry?
                RBRA    _F32_DLST_C3, !Z            ; no: go on checking
_F32_DLST_DS    ADD     FAT32$FE_SIZE, R4           ; set index to next record
                MOVE    R4, @R3                     ; write back idx to FDH
                MOVE    R1, R8                      ; R8 = directory handle
                RBRA    _F32_DLST_SKIP, 1           ; skip entry, read next

                ; special first character handling
_F32_DLST_C3    CMP     R10, FAT32$FE_SPECIAL_CHAR  ; special char?
                RBRA    _F32_DLST_C4, !Z            ; no: go on
                MOVE    FAT32$FE_DEL, R10           ; yes: set the special chr

                ; store first read character to dir. entry struct.
_F32_DLST_C4    MOVE    R2, R5                      ; dir. entry struct.
                ADD     FAT32$DE_NAME, R5           ; R5 = offs. to name
                MOVE    R10, @R5                    ; store character #0                

                ; retrieve attributes and store them to the dir. entry struct.
                MOVE    R0, R8                      ; R8 = device handle
                ADD     FAT32$FE_ATTRIB, R9         ; offset for entry attrib.
                RSUB    FAT32$READ_B, 1             ; read attribute to R10
                MOVE    R2, R12                     ; store attribute
                ADD     FAT32$DE_ATTRIB, R12
                MOVE    R10, @R12

                ; long name?
                MOVE    R10, R7
                AND     FAT32$INT_LONG_MASK, R7
                CMP     R7, FAT32$INT_LONG_NAME
                RBRA    _F32_DLST_SN1, !Z           ; no: short name

                ; long name: last entry starts with bit 6 set, if not
                ; then skip all long name entries until the next short
                ; name entry is there, or EOD
                MOVE    @R5, R7
                MOVE    FAT32$FE_LE_FINAL, R12
                AND     R12, R7
                RBRA    _F32_DLST_DS, Z             ; no flag: skip entry
                MOVE    @R5, R7
                NOT     R12, R12                    ; remove flag
                AND     R12, R7                     ; R7 = # long name records
                MOVE    R7, R6                      ; R6 = current record

                ; long name: check, if the record counter (byte #0) equals the
                ; current record, then retrieve the first checksum and
                ; store it in R11, all subsequent checksums need to be equal
                ; to R11, otherwise we skip the record until the
                ; next short name arrives
_F32_DLST_LN1   MOVE    R0, R8
                MOVE    R4, R9
                RSUB    FAT32$READ_B, 1
                AND     R12, R10                    ; remove start flag
                CMP     R10, R6                     ; record cntr = cur. rec.?
                RBRA    _F32_DLST_LN1B, Z           ; yes: go on
                RBRA    _F32_DLST_DS, !Z            ; no: skip until short nm.
_F32_DLST_LN1B  ADD     FAT32$FE_LE_CHKSUM, R9      ; read checksum
                RSUB    FAT32$READ_B, 1
                CMP     R6, R7                      ; first checksum?
                RBRA    _F32_DLST_LN2, !Z           ; no
                MOVE    R10, R11                    ; R11: checksum
_F32_DLST_LN2   CMP     R10, R11                    ; checksum OK?
                RBRA    _F32_DLST_DS, !Z            ; no: skip until short nm.

                ; long name: retrieve the long file name that is stored at
                ; various offsets within the 32byte record and store it on the
                ; stack as this is a good mechanism of putting it together in
                ; the right order (it is stored the kind of backwards)
                MOVE    R5, R9
                DECRB
                MOVE    R9, R5                      ; §R5 = temp. stor. R5
                SUB     13, SP                      ; max. 13 chars per record
                MOVE    SP, R6                      ; §R6 = string buffer
                INCRB

                MOVE    5, R5                       ; first 5 characters
                MOVE    R4, R9
                ADD     FAT32$FE_LE_C1_5, R9        ; first character
_F32_DLST_LN3   RSUB    FAT32$READ_B, 1             ; read character
                ADD     2, R9                       ; ign. Unicode; ASCII only
                DECRB
                MOVE    R10, @R6++                  ; store character
                INCRB
                SUB     1, R5
                RBRA    _F32_DLST_LN3, !Z

                MOVE    6, R5                       ; another 6 characters
                MOVE    R4, R9
                ADD     FAT32$FE_LE_C6_11, R9       ; chars 6 .. 11
_F32_DLST_LN4   RSUB    FAT32$READ_B, 1
                ADD     2, R9
                DECRB
                MOVE    R10, @R6++
                INCRB
                SUB     1, R5
                RBRA    _F32_DLST_LN4, !Z

                MOVE    2, R5                       ; another 2 characters
                MOVE    R4, R9
                ADD     FAT32$FE_LE_C12_13, R9      ; chars 12 .. 13
_F32_DLST_LN5   RSUB    FAT32$READ_B, 1
                ADD     2, R9
                DECRB
                MOVE    R10, @R6++
                INCRB
                SUB     1, R5
                RBRA    _F32_DLST_LN5, !Z

                DECRB                               ; restore original R5
                MOVE    R5, R9
                INCRB
                MOVE    R9, R5

                ADD     FAT32$FE_SIZE, R4           ; update idx: next record
                MOVE    R4, @R3                     ; store it to FDH
                MOVE    R1, R8                      ; R8 = FDH
                RSUB    FAT32$READ_FDH, 1
                MOVE    @R3, R4                     ; re-read due to READ_FDH
                CMP     0, R9                       ; check for error
                RBRA    _F32_DLST_LN6, Z            ; no error: go on
                MOVE    R9, R12                     ; error: restore stack
                MOVE    R7, R8                      ; ((R7-R6)+1)*13 is the
                SUB     R6, R8                      ; amount of memory to
                ADD     1, R8                       ; be reclaimed (max. 256)
                MOVE    13, R9                      
                SYSCALL(mulu, 1)
                ADD     R10, SP                     ; restore stack pointer
                MOVE    0, R10                      ; return invalid entry
                MOVE    R12, R11                    ; return error code
                RBRA    _F32_DLST_END, 1

_F32_DLST_LN6   SUB     1, R6                       ; next record
                RBRA    _F32_DLST_LN1, !Z

                ; copy long name from stack to directory entry structure
                ; this also restores the stack pointer
                MOVE    R11, R12
                MOVE    R7, R8                      ; R7 = # long name records
                MOVE    13, R9                      ; 13 bytes per record
                SYSCALL(mulu, 1)                    ; R10 = amount of bytes
_F32_DLST_LN7   MOVE    @SP++, @R5++
                SUB     1, R10
                RBRA    _F32_DLST_LN7, !Z
                MOVE    0, @R5                      ; add zero terminator
                MOVE    R12, R11

                ; read short name and calculate checksum
                ; this is a sanity check to find out, if the long filename
                ; really belongs to the short one, or if the long filename
                ; is an orphan; in the latter case: set the short filename
                ; as the definitive filename and discard the long filename
                SUB     11, SP                      ; res. 11 byets on stack
                MOVE    SP, R6                      ; R6: storate pointer
                MOVE    11, R7                      ; 8.3 filename = 11 chars
                MOVE    R0, R8                      ; R8: device handle
                MOVE    R4, R9                      ; R9: index
_F32_DLST_LN8   RSUB    FAT32$READ_B, 1             ; read char to R10
                MOVE    R10, @R6++                  ; store char on stack
                ADD     1, R9                       ; next index
                SUB     1, R7                       ; next char
                RBRA    _F32_DLST_LN8, !Z           ; loop
                MOVE    SP, R8
                RSUB    FAT32$CHECKSUM, 1
                ADD     11, SP                      ; restore stack pointer
                CMP     R8, R11                     ; checksum OK?
                RBRA    _F32_DLST_C1, !Z            ; discard orphan

                ; long name: we need to retrieve the attributes again, 
                ; as only the last record has the correct attributes
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = current index
                ADD     FAT32$FE_ATTRIB, R9         ; offset for entry attrib.
                RSUB    FAT32$READ_B, 1             ; read attribute to R10
                MOVE    R2, R12                     ; store attribute
                ADD     FAT32$DE_ATTRIB, R12
                MOVE    R10, @R12

                ; long name: apply attribute filter
                DECRB
                MOVE    R2, R8                      ; §R2 = attrib filter
                INCRB
                NOT     R8, R8                      ; the attribs not set..
                AND     R8, R10                     ; ..shall be filtered out
                RBRA    _F32_DLST_DS, !Z            ; so skip if != 0

                ; long name: go on and collect the other vital data
                ; that is common to long and short named entries
                RBRA    _F32_DLST_VITAL, 1

                ; short name: apply attribute filter
_F32_DLST_SN1   DECRB
                MOVE    R2, R8                      ; §R2 = attrib filter
                INCRB
                NOT     R8, R8                      ; the attribs not set..
                AND     R8, R10                     ; ..shall be filtered out
                RBRA    _F32_DLST_DS, !Z            ; so skip if != 0

                ; short name: find out if the file name and/or the extension
                ; shall be displayed as lower case characters
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_DISPLAYCASE, R9
                RSUB    FAT32$READ_B, 1             ; R10 = read flags
                DECRB                               ; store result in other
                                                    ; register bank
                MOVE    0, R3                       ; §R3 = lower case name?
                MOVE    0, R4                       ; §R4 = lower case ext?
                MOVE    R10, R9                     ; lower case name?
                AND     FAT32$FE_DC_NAME_MASK, R9
                RBRA    _F32_DLST_SN2, Z
                MOVE    1, R3                       ; yes: §R3 set to "true"
                INCRB
                MOVE    R8, R12                     ; lower case 1st character
                MOVE    @R5, R8
                RSUB    TO_LOWER, 1
                MOVE    R8, @R5
                MOVE    R12, R8
                DECRB
_F32_DLST_SN2   MOVE    R10, R9
                AND     FAT32$FE_DC_EXT_MASK, R9    ; lower case extension?
                RBRA    _F32_DLST_SN3, Z
                MOVE    1, R4                       ; yes: §R4 set to "true"
_F32_DLST_SN3   INCRB

                ; short name: retrieve it from index #1 (second character)
                ; because the char from index #0 has already been retrieved;
                ; the 8.3 filenames are stored as 11 bytes using 0x20 to
                ; fill/pad and the "." is not stored; as we already did
                ; read 1 byte, we still need to read 10 more bytes
                ADD     1, R5                       ; R5 points to name
                MOVE    2, R6                       ; char num (cnt from 1)
                MOVE    R4, R9                      ; R9 = index to char #0
_F32_DLST_SBL1  ADD     1, R9                       ; next character
                RSUB    FAT32$READ_B, 1             ; read byte to R10
                CMP     R6, 8                       ; still in the name part?                
                RBRA    _F32_DLST_SBL2, N           ; no: extension part
                DECRB
                MOVE    R3, R12                     ; §R3 true? low. cs. name
                INCRB
                CMP     R12, 1                      ; lower case name?
                RBRA    _F32_DLST_SBL3, !Z          ; no: go on
                MOVE    R8, R12                     ; yes: convert to lower
                MOVE    R10, R8
                RSUB    TO_LOWER, 1
                MOVE    R8, R10
                MOVE    R12, R8
                RBRA    _F32_DLST_SBL3, 1 
_F32_DLST_SBL2  DECRB
                MOVE    R4, R12                     ; §R4 true? low. cs. ext
                INCRB
                CMP     R12, 1                      ; lower case extension?
                RBRA    _F32_DLST_SBL3, !Z          ; no: go on
                MOVE    R8, R12                     ; yes: convert to lower
                MOVE    R10, R8
                RSUB    TO_LOWER, 1
                MOVE    R8, R10
                MOVE    R12, R8
_F32_DLST_SBL3  CMP     R10, FAT32$FE_PADDING       ; padding characters?
                RBRA    _F32_DLST_SBL4, Z           ; yes: ignore it
                MOVE    R10, @R5++                  ; no: store character
_F32_DLST_SBL4  CMP     R6, 8                       ; add a "." after 8th chr
                RBRA    _F32_DLST_SBL5, !Z          ; not the 8th character
                MOVE    '.', @R5++
_F32_DLST_SBL5  ADD     1, R6                       ; one more char is read
                CMP     R6, 11                      ; all chars read?
                RBRA    _F32_DLST_SBL1, !N          ; one more to go?
                MOVE    0, @R5                      ; add zero terminator

                ; short name: if there is no file extension (i.e. the original
                ; characters 9, 10, 11 were 0x0020), we now have a 8.3 name
                ; that ends with a "." due to how the above mentioned logic
                ; works: it always adds a "." after the 8th character;
                ; as in 8.3 names no "." is allowed in a regular filename,
                ; it is safe to say in such a case: if the last character is
                ; a "." then delete this last character
                MOVE    R5, R8                      ; points to zero term.
                CMP     @--R8, '.'                  ; ends with a "."?
                RBRA    _F32_DLST_VITAL, !Z         ; no: go on
                MOVE    0, @R8                      ; yes: delete by adding a
                                                    ; new zero terminator

                ; short name and long name: retrieve all the vital info:
                ; file size, last write timestamp, start cluster
_F32_DLST_VITAL NOP      ; @TODO test corrupt directories
                         ; includung orphans (e.g. by using wxHexEditor);

                ; file size         
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_FILESIZE, R9
                RSUB    FAT32$READ_DW, 1            ; R10/R11 = lo/hi filesize
                MOVE    R2, R8                      ; R8 = dir. entry. struct.
                ADD     FAT32$DE_SIZE_LO, R8        ; R8 => file size low word
                MOVE    R10, @R8                    ; store file size low word
                MOVE    R2, R8
                ADD     FAT32$DE_SIZE_HI, R8        ; R8 => size high word
                MOVE    R11, @R8                    ; store size high word

                ; file date
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_FILEDATE, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R2, R8
                ADD     FAT32$DE_YEAR, R8           ; R8 = pointer to year
                MOVE    R10, R5                     ; R5 = 16bit encoded date
                SHR     9, R5                       ; year is in bits 9..15
                ADD     1980, R5                    ; relative to 01/01/1980
                MOVE    R5, @R8                     ; store year to dir. ent.
                MOVE    R2, R8
                ADD     FAT32$DE_MONTH, R8          ; R8 = pointer to month
                MOVE    R10, R5                     ; R5 = 16bit encoded date
                SHR     5, R5                       ; month is in bits 5..8
                AND     0x000F, R5                  ; extract month only
                MOVE    R5, @R8                     ; store month to dir. ent.
                MOVE    R2, R8
                ADD     FAT32$DE_DAY, R8            ; R8 = pointer to day
                MOVE    R10, R5                     ; R5 = 16bit encoded date
                AND     0x001F, R5                  ; day is in bits 0..4
                MOVE    R5, @R8                     ; store day to dir. entry

                ; file time
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_FILETIME, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R2, R8
                ADD     FAT32$DE_HOUR, R8           ; R8 = pointer to hour
                MOVE    R10, R5                     ; R5 = 16bit encoded time
                SHR     11, R5                      ; hour is in bits 11..15
                MOVE    R5, @R8                     ; store hour to dir. ent.
                MOVE    R2, R8
                ADD     FAT32$DE_MINUTE, R8         ; R8 = pointer to minute
                MOVE    R10, R5                     ; R5 = 16bit encoded time
                SHR     5, R5                       ; minute is in bits 5..10
                AND     0x003F, R5
                MOVE    R5, @R8                     ; store minute to dir. en.
                MOVE    R2, R8
                ADD     FAT32$DE_SECOND, R8         ; R8 = pointer to second
                MOVE    R10, R5                     ; R5 = 16bit encoded time
                AND     0x001F, R5                  ; second is in bits 0..4
                SHL     1, R5                       ; seconds stored as 2 secs
                MOVE    R5, @R8                     ; store seconds to dir. e.

                ; first cluster
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_CLUS_HI, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R2, R8
                ADD     FAT32$DE_CLUS_HI, R8        ; R8 = pointer to clus. hi
                MOVE    R10, @R8                    ; store clus. hi to d. en.
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R4, R9                      ; R9 = index to be read
                ADD     FAT32$FE_CLUS_LO, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R2, R8
                ADD     FAT32$DE_CLUS_LO, R8        ; R8 = pointer to clus. lo
                MOVE    R10, @R8                    ; store clus. lo to d. en.

                ; update index to next directory entry and return
                ADD     FAT32$FE_SIZE, R4           ; update index
                MOVE    R4, @R3                     ; store it to FDH
                MOVE    1, R10                      ; return "valid entry"
                MOVE    0, R11                      ; return "no errors"

_F32_DLST_END   DECRB                               ; restore R8, R9, R12
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R7, R12
                DECRB
                RET
;
;*****************************************************************************
;* FAT32$FILE_OPEN opens a file for reading or writing or both
;*
;* You can either pass a simple file name or a complex nested path where the
;* last path segment is interpreted as a file name.
;* Consult the documentation of FAT32$CD to learn more about the meaning and
;* handling of the separator char.
;*
;* INPUT:  R8  points to a valid device handle
;*         R9  points to an empty file handle struct that will be filled
;*             (use FAT32$FDH_STRUCT_SIZE to reserve the memory)
;*         R10 points to a zero terminated filename string (path)
;*         R11 separator char (if zero, then "/" will be used)
;* OUTPUT: R8  still points to the same handle
;*         R9  points to the same address but this is now a valid/filled hndl
;*         R10 0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$FILE_OPEN INCRB
                
                ; save original registers
                MOVE    R9, R0                      ; R0 = file handle struct
                MOVE    R11, R1

                MOVE    R0, R11                     ; passing a non zero value
                                                    ; means: operation mode
                                                    ; is set to file open
                MOVE    R10, R9                     ; R9: filename string
                MOVE    R1, R10                     ; R10: separator char
                RSUB    FAT32$CD_OR_OF, 1           ; open file
                MOVE    R9, R10                     ; return OK or err. in R10
                RBRA    _F32_FO_RET, !Z             ; leave on error

                ; retrieve the first cluster of the file
                MOVE    R0, R2
                ADD     FAT32$FDH_CLUSTER_LO, R2
                MOVE    @R2, R9                     ; R9 = cluster lo
                MOVE    R0, R2
                ADD     FAT32$FDH_CLUSTER_HI, R2
                MOVE    @R2, R10                    ; R10 = cluster hi
                XOR     R11, R11                    ; R11 = sector = 0

                ; special case: if the first cluster is zero, than we
                ; have a file of filesize zero; we can open it, and we can
                ; write to it, but if we would try to read from it, we would
                ; immediatelly get an EOF
                CMP     R9, R11
                RBRA    _F32_FO_READ, !Z
                CMP     R10, R11
                RBRA    _F32_FO_READ, !Z
                MOVE    0, R10                      ; no errors
                RBRA    _F32_FO_RET, 1              ; filesize is 0: return

                ; filesize is > 0, so read the first 512 byte sector of the file into the
                ; the internal buffer                
_F32_FO_READ    RSUB    FAT32$READ_SIC, 1           ; read data
                MOVE    R9, R10                     ; return OK or err. in R10

_F32_FO_RET     MOVE    R0, R9                      ; restore org. registers
                MOVE    R1, R11

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$FILE_RB reads one byte from an open file
;*
;* The read operation takes place at the current internal "seek position"
;* within the file, i.e. subsequent calls to FILE_RB will result in reading
;* byte per byte.
;*
;* INPUT:  R8  points to a valid file handle
;* OUTPUT: R8  still points to the file handle
;*         R9  low byte = currently read byte; high byte = 0
;*         R10 0, if the read operation succeeded
;*             FAT32$EOF, if the end of file has been reached; in this case
;*                        the value of R9 is 0 (means "undefined" here)
;*             any other error code in case of an error
;*****************************************************************************
;
FAT32$FILE_RB   INCRB

                ; check for eof by comparing the already read amount of bytes
                ; with the filesize (we need to do this, because we cannot
                ; rely on the FAT last cluster marker, because a file can be
                ; obviously smaller than a cluster)
                MOVE    R8, R0
                ADD     FAT32$FDH_READ_LO, R0
                MOVE    R8, R1
                ADD     FAT32$FDH_SIZE_LO, R1
                CMP     @R0, @R1
                RBRA    _F32_FRB_START, !Z
                MOVE    R8, R0
                ADD     FAT32$FDH_READ_HI, R0
                MOVE    R8, R1
                ADD     FAT32$FDH_SIZE_HI, R1
                CMP     @R0, @R1
                RBRA    _F32_FRB_START, !Z
                MOVE    FAT32$EOF, R10              ; return EOF
                RBRA    _F32_FRB_RET, 1

                ; follow the FAT cluster chain and adjust cluster/sector/index
                ; within the handle, if necessary; that means that also
                ; new sectors will be read, if necessary
_F32_FRB_START  RSUB    FAT32$READ_FDH, 1
                MOVE    R9, R10                     ; R10 is the return value
                RBRA    _F32_FRB_RET, !Z            ; return on error

                ; read the byte
                MOVE    R8, R7                      ; save original R8
                ADD     FAT32$FDH_DEVICE, R8
                MOVE    @R8, R8                     ; retrieve device handle
                MOVE    R7, R9
                ADD     FAT32$FDH_INDEX, R9
                MOVE    @R9, R9                     ; retrieve the read index
                RSUB    FAT32$READ_B, 1             ; read one byte
                MOVE    R7, R8                      ; restore original R8
                MOVE    R10, R9                     ; R9 = read byte = retval
                MOVE    0, R10                      ; R10 = 0 = no error

                ; increase the index and the read size as we just successfully
                ; did read read one byte
                MOVE    R8, R0
                ADD     FAT32$FDH_INDEX, R0
                ADD     1, @R0                      ; increase index by 1
                MOVE    R8, R0
                ADD     FAT32$FDH_READ_LO, R0
                MOVE    R8, R1
                ADD     FAT32$FDH_READ_HI, R1
                ADD     1, @R0                      ; 32bit add 1 to read size
                ADDC    0, @R1

_F32_FRB_RET    DECRB
                RET
;
;*****************************************************************************
;* FAT32$FILE_SEEK positions the read/write pointer within an open file
;*
;* INPUT:  R8  points to a valid file handle
;*         R9  LO word of seek position
;*         R10 HI word of seek position
;* OUTPUT: R8  still points to file handle
;*         R9  0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$FILE_SEEK INCRB

                MOVE    R8, R0                      ; R0 = file handle
                MOVE    R9, R1                      ; R2|R1 = HI|LO seek pos
                MOVE    R10, R2
                MOVE    R11, R3

                ; if the seek position is zero, then skip the function
                CMP     0, R1
                RBRA    _F32_FS_CHKSIZ, !Z
                CMP     0, R2
                RBRA    _F32_FS_CHKSIZ, !Z
                MOVE    0, R9                       ; no error
                RBRA    _F32_FS_RET, 1

                ; if the seek position is larger than the file size,
                ; then skip the function;
                ; the 32bit compare is done via a 32bit sub and then
                ; checking for a negative result via the carry flag
_F32_FS_CHKSIZ  MOVE    R0, R4
                ADD     FAT32$FDH_SIZE_LO, R4
                MOVE    @R4, R4                     ; file size LO
                MOVE    R0, R5
                ADD     FAT32$FDH_SIZE_HI, R5       ; file size HI
                MOVE    @R5, R5
                SUB     R1, R4
                SUBC    R2, R5
                RBRA    _F32_FS_START, !C           ; seekpos <= filesize
                MOVE    FAT23$ERR_SEEKTOOLARGE, R9
                RBRA    _F32_FS_RET, 1

                ; 1. divide the 32bit seek position by 512
                ; 2. push the index forward <quotient> times and then
                ; 3. set the the new index to the <modulo>

                ; divide the 32bit seek position by 512
_F32_FS_START   MOVE    R1, R8                      ; R9|R8 = HI|LO dividend
                MOVE    R2, R9
                MOVE    FAT32$SECTOR_SIZE, R10      ; R11|R10 = HI|LO divisor
                XOR     R11, R11
                RSUB    DIVU32, 1

                ; push the index forward R9|R8 = <quotient> times
                ; pushing is done by setting the index to the sector size
                ; (which is normally 512) and then using FAT32$READ_FDH
                MOVE    R8, R4                      ; R5|R4 = HI|LO of the ..
                MOVE    R9, R5                      ; 32bit amount to push

_F32_FS_LOOP    CMP     R4, 0                       ; still anything to push?
                RBRA    _F32_FS_IPUSH, !Z
                CMP     R5, 0
                RBRA    _F32_FS_IPUSH, !Z
                RBRA    _F32_FS_INDEX, 1

_F32_FS_IPUSH   SUB     1, R4                       ; 32bit sub 1 from R5|R4
                SUBC    0, R5 
                MOVE    R0, R6
                ADD     FAT32$FDH_INDEX, R6
                MOVE    FAT32$SECTOR_SIZE, @R6      ; set index to push mode
                MOVE    R0, R8
                RSUB    FAT32$READ_FDH, 1
                CMP     0, R9                       ; error?
                RBRA    _F32_FS_IPUSH2, Z           ; no: continue
                RBRA    _F32_FS_RET, 1              ; yes: quit
_F32_FS_IPUSH2  MOVE    R0, R6                      ; 32bit add the amount ..
                ADD     FAT32$FDH_READ_LO, R6       ; .. of read bytes to ..
                MOVE    R0, R7                      ; .. the file handle
                ADD     FAT32$FDH_READ_HI, R7
                ADD     FAT32$SECTOR_SIZE, @R6
                ADDC    0, @R7
                RBRA    _F32_FS_LOOP, 1             ; next iteration

                ; set the new index to the <modulo>
_F32_FS_INDEX   MOVE    R0, R6
                ADD     FAT32$FDH_INDEX, R6
                MOVE    R10, @R6                    ; set index to modulo
                MOVE    R0, R6                      ; 32bit add the amount ..
                ADD     FAT32$FDH_READ_LO, R6       ; .. of read bytes to ..
                MOVE    R0, R7                      ; .. the file handle
                ADD     FAT32$FDH_READ_HI, R7
                ADD     R10, @R6
                ADDC    0, @R7                
                MOVE    0, R9                       ; no error

_F32_FS_RET     MOVE    R0, R8                      ; restore R8 and R10
                MOVE    R2, R10
                MOVE    R3, R11

                DECRB
                RET                
;
;*****************************************************************************
;* FAT32$CD changes the current directory
;*
;* This function supports traversing deeply in one call using nested
;* directories like "dir1/dir2/dir3/dir4". Any non-zero separator char
;* can be used. It is important to pass a separator char, even if you do not
;* plan to pass nested directories. If in doubt, just pass 0x002F, which is
;* the ASCII code for / (passing 0x0000 also leads to 0x002F being used).
;*
;* A separator char as the very first char (e.g. "/dir1/dir2") means, that
;* we start searching from the root directory. No separator char at the
;* beginning means, that we work relative to the current directory. The FAT32
;* typical "." and ".." work as expected.
;*
;* FAT32 is case preserving but not case sensitive.
;*
;* INPUT:  R8  points to a valid device handle
;*         R9  points to a zero terminated directory string (path)
;*         R10 separator char (if zero, then "/" will be used)
;* OUTPUT: R8  still points to the directory handle
;*         R9  0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$CD        INCRB
                MOVE    R11, R0

                XOR     R11, R11                    ; operation mode = CD
                RSUB    FAT32$CD_OR_OF, 1

                MOVE    R0, R11
                DECRB
                RET
;
;*****************************************************************************
;* FAT32$PRINT_DE is a pretty printer for directory entries
;*
;* Uses monitor (system) stdout to print. Allows the configuration of the
;* amount of data that shall be printed: Filename only is the minimum. 
;* Additionally attributes, file sizes, file date and file time can be shown.
;* The printed layout is as follows:
;*
;* <DIR> HRSA BBBBBBBBB YYYY-MM-DD HH:MM   name...
;*
;* <DIR> means that the entry is a directory, otherwise whitespace
;* H = hidden flag
;* R = read only flag
;* S = system flag
;* A = archive flag
;* BBBBBBBBB = decimal size of the file in bytes
;* YYYY-MM-DD = file date
;* HH:MM = file time
;* name... = file name in long file format
;*
;* INPUT:  R8:  pointer to directy entry structure
;*         R9:  print flags as defined in FAT32$PRINT_SHOW_*
;*****************************************************************************
;
FAT32$PRINT_DE  INCRB
                MOVE    R10, R0                     ; save R10 .. R12
                MOVE    R11, R1
                MOVE    R12, R2
                INCRB 

                MOVE    R8, R0                      ; R0 = ptr to dir. ent. s.
                MOVE    R9, R1                      ; R1 = print flags

                ; print <DIR> indicator
                MOVE    R1, R2                      ; show <dir> indicator?
                AND     FAT32$PRINT_SHOW_DIR, R2
                RBRA    _F32_PDE_A1, Z              ; no: go on
                MOVE    R0, R2                      ; is current entry a dir.?
                ADD     FAT32$DE_ATTRIB, R2
                MOVE    @R2, R2
                MOVE    FAT32$PRINT_DE_DIR_N, R8    ; assume no
                AND     FAT32$FA_DIR, R2
                RBRA    _F32_PDE_D1, Z
                MOVE    FAT32$PRINT_DE_DIR_Y, R8    ; yes, it is
_F32_PDE_D1     SYSCALL(puts, 1)                    ; print <DIR> or whitespc

                ; print attributes
_F32_PDE_A1     MOVE    R1, R2                      ; show attributes?
                AND     FAT32$PRINT_SHOW_ATTRIB, R2
                RBRA    _F32_PDE_S1, Z              ; no: go on
                MOVE    R0, R2
                ADD     FAT32$DE_ATTRIB, R2
                MOVE    @R2, R3                     ; @R2 contains attrib
                MOVE    FAT32$PRINT_DE_AN, R8
                AND     FAT32$FA_ARCHIVE, R3        ; attrib = archive?
                RBRA    _F32_PDE_A2, Z
                MOVE    FAT32$PRINT_DE_AA, R8
_F32_PDE_A2     SYSCALL(puts, 1)                
                MOVE    @R2, R3                     ; @R2 contains attrib
                MOVE    FAT32$PRINT_DE_AN, R8
                AND     FAT32$FA_HIDDEN, R3         ; attrib = hidden?
                RBRA    _F32_PDE_A3, Z
                MOVE    FAT32$PRINT_DE_AH, R8
_F32_PDE_A3     SYSCALL(puts, 1)
                MOVE    @R2, R3                     ; @R2 contains attrib
                MOVE    FAT32$PRINT_DE_AN, R8
                AND     FAT32$FA_READ_ONLY, R3      ; attrib = read only?
                RBRA    _F32_PDE_A4, Z
                MOVE    FAT32$PRINT_DE_AR, R8
_F32_PDE_A4     SYSCALL(puts, 1)
                MOVE    @R2, R3                     ; @R2 contains attrib
                MOVE    FAT32$PRINT_DE_AN, R8
                AND     FAT32$FA_SYSTEM, R3         ; attrib = system?
                RBRA    _F32_PDE_A5, Z
                MOVE    FAT32$PRINT_DE_AS, R8
_F32_PDE_A5     SYSCALL(puts, 1)
                MOVE    FAT32$PRINT_DE_AN, R8       ; print space
                SYSCALL(puts, 1)

                ; print size
_F32_PDE_S1     MOVE    R1, R2                      ; show file size?
                AND     FAT32$PRINT_SHOW_SIZE, R2
                RBRA    _F32_PDE_DATE, Z            ; no: go on
                MOVE    R0, R2                      ; is current entry a dir.?
                ADD     FAT32$DE_ATTRIB, R2
                MOVE    @R2, R2
                AND     FAT32$FA_DIR, R2
                RBRA    _F32_PDE_S2, Z              ; no: print file size
                MOVE    FAT32$PRINT_DE_DIR_S, R8    ; yes: print spaces ...
                SYSCALL(puts, 1)                    ; ... instead of file size                
                RBRA    _F32_PDE_DATE, 1
_F32_PDE_S2     MOVE    R0, R8                      ; R8 = dir. entry struct.
                ADD     FAT32$DE_SIZE_LO, R8        ; retrieve LO/HI of ...
                MOVE    @R8, R8                     ; ... filesize in R8/R9
                MOVE    R0, R9
                ADD     FAT32$DE_SIZE_HI, R9
                MOVE    @R9, R9
                XOR     R7, R7                      ; print trailing spaces
                RSUB    _F32_PDE_PD, 1              ; print decimal filesize
                MOVE    FAT32$PRINT_DE_AN, R8       ; print space
                SYSCALL(puts, 1)

                ; print date
_F32_PDE_DATE   MOVE    1, R7                       ; do not print trailing sp
                MOVE    R1, R2                      ; show date?
                AND     FAT32$PRINT_SHOW_DATE, R2
                RBRA    _F32_PDE_TIME, Z            ; no: go on
                MOVE    R0, R8
                ADD     FAT32$DE_YEAR, R8
                MOVE    @R8, R8                     ; R8 = year
                XOR     R9, R9                      ; high word = zero
                RSUB    _F32_PDE_PD, 1              ; print year as decimal
                MOVE    FAT32$PRINT_DE_DATE, R8     ; print separator
                SYSCALL(puts, 1)
                MOVE    R0, R8
                ADD     FAT32$DE_MONTH, R8
                MOVE    @R8, R8                     ; R8 = month
                XOR     R9, R9                      ; hi word zero
                RSUB    _F32_PDE_PD, 1              ; print month as decimal
                MOVE    FAT32$PRINT_DE_DATE, R8     ; print separator
                SYSCALL(puts, 1)
                MOVE    R0, R8
                ADD     FAT32$DE_DAY, R8
                MOVE    @R8, R8                     ; R8 = day
                XOR     R9, R9                      ; hi word zero
                RSUB    _F32_PDE_PD, 1              ; print day as decimal
                MOVE    FAT32$PRINT_DE_AN, R8       ; print space
                SYSCALL(puts, 1)

                ; print time
_F32_PDE_TIME   MOVE    1, R7                       ; do not print trailing sp
                MOVE    R1, R2                      ; show time?
                AND     FAT32$PRINT_SHOW_TIME, R2
                RBRA    _F32_PDE_N1, Z              ; no: go on
                MOVE    R0, R8
                ADD     FAT32$DE_HOUR, R8
                MOVE    @R8, R8                     ; R8 = hour
                XOR     R9, R9                      ; high word = zero
                RSUB    _F32_PDE_PD, 1              ; print hour as decimal
                MOVE    FAT32$PRINT_DE_TIME, R8     ; print separator
                SYSCALL(puts, 1)
                MOVE    R0, R8
                ADD     FAT32$DE_MINUTE, R8
                MOVE    @R8, R8                     ; R8 = minute
                XOR     R9, R9                      ; high word = zero
                RSUB    _F32_PDE_PD, 1              ; print minute as decimal
                MOVE    FAT32$PRINT_DE_AN, R8       ; print space
                SYSCALL(puts, 1)

                ; print name
_F32_PDE_N1     MOVE    R0, R8
                ADD     FAT32$DE_NAME, R8
                SYSCALL(puts, 1)                    ; print name
                SYSCALL(crlf, 1)                    ; next line out stdout
                
_F32_PDE_END    MOVE    R0, R8                      ; restore R8 .. R11
                MOVE    R1, R9

                DECRB
                MOVE    R0, R10
                MOVE    R1, R11
                MOVE    R2, R12
                DECRB
                RET

                ; sub-sub routine to print a decimal that is in HI|LO=R9|R8
                ; if R7 = 0 then then print trailing spaces
                ; if R7 = 1 then numbers < 10 will receive one trailing zero
                ;           but no trailing spaces at all
_F32_PDE_PD     SUB     11, SP                      ; create 11 bytes memory..
                MOVE    SP, R10                     ; ..area on the stack
                RSUB    H2D_ASCII, 1                ; make decimal string
                CMP     R7, 0                       ; print trailing spaces?
                RBRA    _F32_PDE_PDNT, !Z           ; no
                MOVE    R10, R8                     ; yes: use R10 to print
                RBRA    _F32_PDE_PDPS, 1            ; print
_F32_PDE_PDNT   CMP     R12, 1                      ; only one digit?
                RBRA    _F32_PDE_PDOD, !Z           ; no: go on
                MOVE    0x0030, @--R11              ; yes: add trailing zero
_F32_PDE_PDOD   MOVE    R11, R8                     ; use R10 to print
_F32_PDE_PDPS   SYSCALL(puts, 1)                    ; print decimal
                ADD     11, SP                      ; restore stack
                RET
;
;*****************************************************************************
;* FAT32$CALL_DEV calls a device management function
;*
;* INPUT:  R8, R9 are the parameters to the function
;*         R10 is the function index
;*         R11 is the mount data structure (device handle)
;*
;* OUTPUT: R8 is the return value from the function
;*****************************************************************************
;
FAT32$CALL_DEV  INCRB

                MOVE    R11, R0                 ; compute function address
                ADD     R10, R0
                MOVE    _F32$CDEVEND, @--SP     ; compute return address

                MOVE    @R0, PC                 ; perform function call

_F32$CDEVEND    DECRB
                RET
;
;*****************************************************************************
;* FAT32$CD_OR_OF changes the current directory or opens a file
;*
;* This is an internal help function, because changing a directory and
;* opening a file requires very similar actions. See the documentation for
;* FAT32$CD and FAT32$FILE_OPEN for details.
;*
;* INPUT:  R8  points to a valid device handle
;*         R9  points to a zero terminated string (directory or filename)
;*         R10 separator char (if zero, then "/" will be used)
;*         R11 operation mode: 0 = FAT32$CD, otherwise FAT32$FILE_OPEN
;*             in the latter case, R11 points to the file handle structure
;*             that will be filled by FAT32$CDOF.
;* OUTPUT: R9  0, if OK, otherwise error code
;*         all other registers remain unchanged
;*****************************************************************************
;
FAT32$CD_OR_OF  INCRB

                MOVE    R10, R0                 ; save original registers
                MOVE    R11, R1
                MOVE    R12, R2

                ; save original active directory so that we can restore
                ; it in case of an error, so that a CD or FILE_OPEN to a
                ; non existing location or file does not lead to a changed
                ; AD pointer within the device handle
                MOVE    R8, R3                  ; §R3 = org. AD cluster LO                 
                ADD     FAT32$DEV_AD_1STCLUS_LO, R3
                MOVE    @R3, R3
                MOVE    R8, R4
                ADD     FAT32$DEV_AD_1STCLUS_HI, R4
                MOVE    @R4, R4                 ; $R4 = org. AD cluster HI

                INCRB 

                MOVE    R8, R0                  ; R0 = device handle
                MOVE    R9, R1                  ; R1 = path
                MOVE    R11, R12                ; R12 = op. mode/file handle

                ; if no separator char is given, then use /
                CMP     R10, 0
                RBRA    _F32_DF_1, !Z
                MOVE    '/', R10

                ; if the first character in the path is a separator char,
                ; then change the current working directory (AD) to 
                ; root (RD) and skip the separator char
                ; (just in case there are multiple separator chars at the
                ; beginning, i.e. more than just one: these will be filtered
                ; out by the SPLIT function later)
_F32_DF_1       CMP     @R1, R10
                RBRA    _F32_DF_2, !Z
                ADD     1, R1                   ; skip first character
                RSUB    _F32_CDROOT, 1          ; change to root

                ; split the path into segments and build an outer loop
                ; around the next section (_F32_DF_NXSG) that iteratively
                ; dives into the full path consisting of the split segments
_F32_DF_2       MOVE    R1, R8
                MOVE    R10, R9
                RSUB    SPLIT, 1
                MOVE    R9, R2                  ; R2 = stack pointer restore
                CMP     R8, 0
                RBRA    _F32_DF_ENDNR, Z        ; path is empty: end
                MOVE    R8, R3                  ; R3 = amount of segments
                MOVE    SP, R4                  ; R4 = current path segment

                ; reserve memory for the directory handle (FDH) and for the
                ; directory entry handle (DE) on the stack
                SUB     FAT32$FDH_STRUCT_SIZE, SP
                MOVE    SP, R5                  ; R5 = directory handle
                SUB     FAT32$DE_STRUCT_SIZE, SP
                MOVE    SP, R6                  ; R6 = directory entry handle

                ; change directory into current path segment:
                ; 1. open directory, create directory handle
                ; 2. browse directory entries to find the current path segm.:
                ;    a) check for entries that are of type FAT32$FA_DIR 
                ;    b) compare directory name (case insensitive)
                ; 3. use start cluster of found entry as new AD entry
                ; in case of a file (R12 != 0)
                ; work similar to the case of the directory, but treat
                ; the last path segment as a filename
_F32_DF_NXSG    ADD     1, R4                   ; skip length info of path
                MOVE    R0, R8                  ; R8 = R0 = device handle
                MOVE    R5, R9                  ; R9 = R5 = directory handle
                RSUB    FAT32$DIR_OPEN, 1       ; open directory for browsing
                CMP     R9, 0                   ; errors?
                RBRA    _F32_DF_ENDWR, !Z       ; return error in R9

_F32_DF_LNX     MOVE    R5, R8                  ; R8 = R5 = directory handle
                MOVE    R6, R9                  ; R9 = R6 = dir. entry handle
                MOVE    FAT32$FA_ALL, R10       ; flags: "browse everything"
                RSUB    FAT32$DIR_LIST, 1       ; browse next entry
                CMP     R11, 0                  ; errors?
                RBRA    _F32_DF_NXSG3, Z        ; no errors
                MOVE    R11, R9
                RBRA    _F32_DF_ENDWR, 1        ; return error
_F32_DF_NXSG3   CMP     R10, 0                  ; file or directory not found
                RBRA    _F32_DF_NXSG4, !Z       ; we can go on
                CMP     R12, 0                  ; error: return & restore AD
                RBRA    _F32_DF_NXERRD, Z       ; operation mode = CD?
                MOVE    FAT32$ERR_FILENOTFOUND, R9 ; error: file not found
                RBRA    _F32_DF_ENDWR, 1        ; return error
_F32_DF_NXERRD  MOVE    FAT32$ERR_DIRNOTFOUND, R9 ; error: directory not found
                RBRA    _F32_DF_ENDWR, 1        ; return error
_F32_DF_NXSG4   MOVE    R6, R7                  ; chk attrib depending on R12
                ADD     FAT32$DE_ATTRIB, R7
                MOVE    @R7, R7                 ; R7 now contains the attrib
                CMP     R12, 0                  ; operation mode = CD?
                RBRA    _F32_DF_CFCD, Z         ; yes: check for directory
                CMP     R3, 1                   ; no: last path segment?
                RBRA    _F32_DF_CFCD, !Z        ; no: so treat it as a path
                AND     FAT32$FA_DIR, R7        ; yes: now we check for a file
                RBRA    _F32_DF_LNX, !Z         ; no file but dir: try next DE
                RBRA    _F32_DF_NXSG5, 1        ; go on with the name compare
_F32_DF_CFCD    AND     FAT32$FA_DIR, R7        ; directory flag set?
                RBRA    _F32_DF_LNX, Z          ; no directory: try next DE
_F32_DF_NXSG5   MOVE    R6, R7                  ; R7 = dir. entry name
                ADD     FAT32$DE_NAME, R7
                MOVE    R7, R8
                SYSCALL(str2upper, 1)           ; dir. entry name uppercase
                MOVE    R4, R8
                SYSCALL(str2upper, 1)           ; current path segm. uppercase
                MOVE    R7, R9
                SYSCALL(strcmp, 1)              ; compare DE with current path
                CMP     R10, 0
                RBRA    _F32_DF_LNX, !Z         ; no match: try next DE

                ; this code is executed, when the directory entry (DE)
                ; matches the current path segment; in such a case,
                ; we need to distinguish: are we currently doing a CD
                ; or are we opening a file: in the latter case: if the current
                ; segment is the last one, then this is the actual file, so
                ; we are not "CDing" in subdirectories any more (i.e. not
                ; modifying the AD any more), but we are returning the start
                ; cluster of the file and its filesize within the file handle
                ; structure that is passed in R12
                CMP     R12, 0                  ; operation mode = CD?
                RBRA    _F32_DF_MATCHD, Z       ; yes: so do the CD
                CMP     R3, 1                   ; is it the last path segment?
                RBRA    _F32_DF_MATCHD, !Z      ; no: so do the CD
                
                ; fill the file handle structure and return with a success
                MOVE    R12, R7
                ADD     FAT32$FDH_DEVICE, R7
                MOVE    R0, @R7                 ; set the device handle
                MOVE    R12, R7
                ADD     FAT32$FDH_CLUSTER_LO, R7
                MOVE    R6, R8
                ADD     FAT32$DE_CLUS_LO, R8
                MOVE    @R8, @R7                ; set the cluster lo word
                MOVE    R12, R7
                ADD     FAT32$FDH_CLUSTER_HI, R7
                MOVE    R6, R8
                ADD     FAT32$DE_CLUS_HI, R8
                MOVE    @R8, @R7                ; set the cluster hi word
                MOVE    R12, R7
                ADD     FAT32$FDH_SIZE_LO, R7
                MOVE    R6, R8
                ADD     FAT32$DE_SIZE_LO, R8
                MOVE    @R8, @R7                ; set the filesize lo word
                MOVE    R12, R7
                ADD     FAT32$FDH_SIZE_HI, R7
                MOVE    R6, R8
                ADD     FAT32$DE_SIZE_HI, R8
                MOVE    @R8, @R7                ; set the filesize hi word
                XOR     R8, R8                  ; R8 = 0
                MOVE    R12, R7
                ADD     FAT32$FDH_SECTOR, R7
                MOVE    R8, @R7                 ; set the start sector to 0
                MOVE    R12, R7
                ADD     FAT32$FDH_INDEX, R7     
                MOVE    R8, @R7                 ; set the start index to 0
                MOVE    R12, R7
                ADD     FAT32$FDH_READ_LO, R7
                MOVE    R8, @R7                 ; already read size LO = 0
                MOVE    R12, R7
                ADD     FAT32$FDH_READ_HI , R7
                MOVE    R8, @R7                 ; already read size HI = 0
                RBRA    _F32_DF_SUCCESS, 1      ; return a success

                ; change the directory by setting AD within the device handle
_F32_DF_MATCHD  MOVE    R6, R7                  ; match! set AD to new cluster
                ADD     FAT32$DE_CLUS_LO, R7
                MOVE    R0, R8
                ADD     FAT32$DEV_AD_1STCLUS_LO, R8
                MOVE    @R7, @R8                ; perform the actual CD (low)
                MOVE    R6, R7
                ADD     FAT32$DE_CLUS_HI, R7
                MOVE    R0, R8
                ADD     FAT32$DEV_AD_1STCLUS_HI, R8
                MOVE    @R7, @R8                ; perform the actual CD (high)

                ; there is a speciality in the FAT32 specification:
                ; in case of a ".." that points to root, FAT32$DE_CLUS_LO
                ; and FAT32$DE_CLUS_HI will be zero (i.e. illegal); therefore
                ; we need to handle this special case
                CMP     @R7, 0                  ; FAT32$DE_CLUS_HI = 0?
                RBRA    _F32_DF_SUCCESS, !Z     ; no: go on
                MOVE    R6, R7
                ADD     FAT32$DE_CLUS_LO, R7
                CMP     @R7, 0                  ; FAT32$DE_CLUS_LO = 0?
                RBRA    _F32_DF_SUCCESS, !Z     ; no: go on
                MOVE    R6, R7
                ADD     FAT32$DE_NAME, R7
                CMP     @R7++, '.'              ; first "." of ".."?
                RBRA    _F32_DF_SUCCESS, !Z     ; no: go on
                CMP     @R7, '.'                ; second "." of ".."?
                RBRA    _F32_DF_SUCCESS, !Z     ; no: go on
                MOVE    R6, R9                  ; yes: cd to root, then go on
                RSUB    _F32_CDROOT, 1
                MOVE    R9, R6

_F32_DF_SUCCESS MOVE    0, R9                   ; operation was successful

                ; loop if there is another segment left
                SUB     1, R3                   ; one less path segment
                RBRA    _F32_DF_ENDWR, Z        ; end if no more path segmts.
                ADD     @--R4, R4               ; R4 was incremented to skip..
                                                ; ..the length information, ..
                                                ; ..so we need to predecr. ..
                                                ; ..and then increase the ..
                                                ; ..pointer to the next segm.                                                
                RBRA    _F32_DF_NXSG, 1         ; process next path segment

                ; restore SP
_F32_DF_ENDWR   ADD     FAT32$FDH_STRUCT_SIZE, SP
                ADD     FAT32$DE_STRUCT_SIZE, SP

_F32_DF_ENDNR   ADD     R2, SP                  ; restore stack pointer
                MOVE    R0, R8                  ; restore original R8

                DECRB

                ; in the case that we are in the file open mode (R12 != 0)
                ; or case of an error: restore the original active dir. (AD)
                CMP     R12, 0                  ; are we in file open mode?
                RBRA    _F32_DF_RESTAD, !Z      ; yes: restore AD
                CMP     R9, 0                   ; was there an error?
                RBRA    _F32_DF_RET, Z          ; no error: return
_F32_DF_RESTAD  MOVE    R8, R7
                ADD     FAT32$DEV_AD_1STCLUS_LO, R7
                MOVE    R3, @R7
                MOVE    R8, R7
                ADD     FAT32$DEV_AD_1STCLUS_HI, R7
                MOVE    R4, @R7

                MOVE    R0, R10                 ; restore original registers
                MOVE    R1, R11
                MOVE    R2, R12

_F32_DF_RET     DECRB
                RET

                ; sub-sub routine to change the AD to the RD
_F32_CDROOT     MOVE    R0, R6
                ADD     FAT32$DEV_RD_1STCLUS_LO, R6
                MOVE    R0, R7
                ADD     FAT32$DEV_AD_1STCLUS_LO, R7
                MOVE    @R6, @R7                ; AD LO cluster = RD LO clust.
                MOVE    R0, R6
                ADD     FAT32$DEV_RD_1STCLUS_HI, R6
                MOVE    R0, R7
                ADD     FAT32$DEV_AD_1STCLUS_HI, R7
                MOVE    @R6, @R7                ; AD HI cluster = RD HI clust.
                RET                
;
;*****************************************************************************
;* FAT32$READ_FDH fills the read buffer according to the current index in FDH
;*
;* If the index within FDH is < FAT32$SECTOR_SIZE (512), then it is assumed,
;* that no read operation needs to be performed, i.e. another function has
;* already filled the 512-byte read-buffer. Otherwise, the sector is
;* increased (and the index is reset to 0) and if necessary also the cluster
;* is increased (and the sector is reset to 0). The new index, sector and
;* cluster values are stored within the FDH (file and directory handle).
;* In case of an increased index or sector or cluster value, the 512-byte
;* read-buffer is re-read for subsequent read accesses.
;*
;* INPUT:  R8: FDH
;* OUTPUT: R8: FDH
;*         R9: 0, if OK, otherwise error code
;*****************************************************************************
;
FAT32$READ_FDH  INCRB
                MOVE    R8, R0
                MOVE    R10, R1
                MOVE    R11, R2
                MOVE    R12, R3
                INCRB

                MOVE    R8, R0
                ADD     FAT32$FDH_DEVICE, R0
                MOVE    @R0, R0                     ; R0 = device handle
                MOVE    R8, R1                      ; R1 = FDH

                ; @TODO: as soon as this function is generalized to also
                ; be able to write / append, then also files with an initial
                ; size of zero (1st clst. = 0) must be allowed to be appended

                ; if the first cluster = 0 then we try to read from an
                ; illegal cluster, therefore exit with an error message
                XOR     R3, R3 
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_LO, R2
                CMP     @R2, R3
                RBRA    _F32_RFDH_START, !Z
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_HI, R2
                CMP     @R2, R3
                RBRA    _F32_RFDH_START, !Z
                MOVE    FAT32$ERR_ILLEGAL_CLUS, R9
                RBRA    _F32_RFDH_END, 1

                ; if the current "to-be-read" index equals 512, then
                ; we need to read the next sector within the cluster
_F32_RFDH_START MOVE    R1, R2
                ADD     FAT32$FDH_INDEX, R2
                MOVE    @R2, R3                     ; R3 = "to-be-read" index
                CMP     R3, FAT32$SECTOR_SIZE
                RBRA    _F32_RFDH_CISS, !Z

                ; reset the index and increase the sector
                ; if the sector is larger than the sectors per cluster, then
                ; we need to increase the cluster (i.e. look up the next one
                ; in the FAT); otherwise we can just read the new sector
                ; within the same cluster
                MOVE    0, @R2                      ; write back resetted idx
                MOVE    0, R3                       ; R3 = "to-be-read" index
                MOVE    R1, R2
                ADD     FAT32$FDH_SECTOR, R2
                MOVE    @R2, R4
                ADD     1, R4                       ; R4 = increased sector
                MOVE    R0, R2
                ADD     FAT32$DEV_SECT_PER_CLUS, R2
                MOVE    @R2, R2
                SUB     1, R2                       ; we count from 0
                CMP     R4, R2                      ; R4 > sectors per clus.?
                RBRA    _F32_RFDH_INCC, N           ; yes: next cluster
                MOVE    R1, R2                      ; no: write back ...
                ADD     FAT32$FDH_SECTOR, R2        ; ... increased sector
                MOVE    R4, @R2
                MOVE    R0, R8
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_LO, R2
                MOVE    @R2, R9                     ; LO word of cluster
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_HI, R2
                MOVE    @R2, R10                    ; HI word of cluster
                MOVE    R4, R11                     ; sector number
                RSUB    FAT32$READ_SIC, 1           ; read sector in cluster
                RBRA    _F32_RFDH_END, 1

                ; next cluster:
                ; 1. reset the sector and index to 0 and write it back
                ; 2. retrieve the current cluster
                ; 3. calculate the 32bit sector offset (LBA)
                ; 4. retrieve FAT start address (LBA) and add offset from (3)
                ; 5. calculate linear address of sector and load it
                ; 6. retrieve and resolve the FAT32 cluster pointer, save the
                ;    new one back to the directory handle and load the
                ;    sector 0 within this cluster

                ; next cluster: reset the sector to 0 and write it back
_F32_RFDH_INCC  MOVE    R1, R2                      
                ADD     FAT32$FDH_SECTOR, R2
                MOVE    0, @R2                      ; write back sector = 0
                MOVE    R1, R2
                ADD     FAT32$FDH_INDEX, R2
                MOVE    0, @R2                      ; write back index = 0

                ; retrieve the current cluster to HI|LO = R3|R2
                MOVE    R1, R9
                ADD     FAT32$FDH_CLUSTER_HI, R9
                MOVE    @R9, R9
                MOVE    R1, R8
                ADD     FAT32$FDH_CLUSTER_LO, R8
                MOVE    @R8, R8

                ; calculate the 32bit sector offset:
                ; FAT32 stores 512 byte / 32 bit = 128 cluster pointers
                ; per 512 byte sector; for knowing the sector, in which we
                ; find the cluster pointer for the current cluster, we need
                ; to integer-divide it by 128; for knowing the offset
                ; within the sector, we look at the modulus
                XOR     R11, R11
                MOVE    128, R10
                RSUB    DIVU32, 1                   ; R9|R8 = sector offset 
                MOVE    R10, R12                    ; R12   = index in sector                        

                ; retrieve FAT start address (LBA) to HI|LO = R3|R2 and add
                ; the 32bit sector offset from HI|LO = R9|R8; 
                ; the result is in HI|LO = R9|R8
                MOVE    R0, R2
                ADD     FAT32$DEV_FAT_LO, R2
                MOVE    @R2, R2
                MOVE    R0, R3
                ADD     FAT32$DEV_FAT_HI, R3
                MOVE    @R3, R3
                ADD     R2, R8
                ADDC    R3, R9

                ; calculate linear address of sector by multiplying the
                ; LBA address in R9|R8 by 512 and load it
                ; if the result is larger than 32bit, then we have an error
                MOVE    512, R10
                XOR     R11, R11
                RSUB    MULU32, 1                   ; mult. result = R11..R8
                CMP     R11, 0                      ; result > 48bit?
                RBRA    _F32_RFDH_INCC2, Z          ; no: go on checking
                RBRA    _F32_RFDH_INCCE, 1
_F32_RFDH_INCC2 CMP     R10, 0                      ; result > 32bit?
                RBRA    _F32_RFDH_INCC3, Z          ; no: go on
_F32_RFDH_INCCE MOVE    FAT32$ERR_SIZE, R9          ; return size error
                RBRA    _F32_RFDH_END, 1
_F32_RFDH_INCC3 MOVE    FAT32$DEV_BLOCK_READ, R10   ; R10 = function index
                MOVE    R0, R11                     ; R11 = device handle
                RSUB    FAT32$CALL_DEV, 1
                CMP     R8, 0
                RBRA    _F32_RFDH_INCC4, Z
                MOVE    R8, R9
                RBRA    _F32_RFDH_END, 1

                ; retrieve and resolve the FAT32 cluster pointer, save the
                ; new one back to the directory handle and load the
                ; sector 0 within this cluster
_F32_RFDH_INCC4 MOVE    R0, R8                      ; R8 = device handle
                MOVE    R12, R9                     ; R9 = index, 32bit, so 
                SHL     2, R9                       ; multiply by 4 to get it
                RSUB    FAT32$READ_DW, 1            ; pointer in R11|R10
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_LO, R2
                MOVE    R10, @R2                    ; store cluster low word
                MOVE    R1, R2
                ADD     FAT32$FDH_CLUSTER_HI, R2
                MOVE    R11, @R2                    ; store cluster high word
                MOVE    R0, R8                      ; R8 = device handle
                MOVE    R10, R9                     ; R9 = cluster low word
                MOVE    R11, R10                    ; R10 = cluster high word
                XOR     R11, R11                    ; R11 = sector 0
                RSUB    FAT32$READ_SIC, 1           ; load data sector
                RBRA    _F32_RFDH_END, 1

                ; check for access beyond the sector size (means illegal hndl)                
_F32_RFDH_CISS  CMP     R3, FAT32$SECTOR_SIZE
                RBRA    _F32_RFDH_DONE, !N
                MOVE    FAT32$ERR_CORRUPT_DH, R9
                RBRA    _F32_RFDH_END, 1

_F32_RFDH_DONE  MOVE    0, R9
_F32_RFDH_END   DECRB
                MOVE    R0, R8
                MOVE    R1, R10
                MOVE    R2, R11
                MOVE    R3, R12
                DECRB
                RET
;
;*****************************************************************************
;* FAT32$READ_SIC reads a sector within a cluster
;*
;* INPUT:   R8:  device handle
;*          R9:  LO word of cluster
;*          R10: HI word of cluster
;*          R11: sector within cluster
;* OUTPUT:  R8:  device handle
;           R9:  0, if OK, otherweise error code
;*****************************************************************************
;
FAT32$READ_SIC  INCRB

                MOVE    R10, R0
                MOVE    R11, R1

                INCRB

                ; if sector within cluster is larger than the amount of
                ; clusters per sector then exit with an error message
                MOVE    R8, R0
                ADD     FAT32$DEV_SECT_PER_CLUS, R0
                MOVE    @R0, R0
                SUB     1, R0                       ; we start counting from 0
                CMP     R11, R0
                RBRA    _F32_RSIC_C1, !N
                MOVE    FAT32$ERR_ILLEGAL_SIC, R9
                RBRA    _F32_RSIC_END, 1

                ; all clusters numbers need to be >= 2
_F32_RSIC_C1    CMP     R10, 0                      ; if hi word != 0 then ...
                RBRA    _F32_RSIC_C2, !Z            ; it is for sure >= 2
                CMP     R9, 1                       ; if low word > 1, then
                RBRA    _F32_RSIC_C2, N             ; it is also >= 2
                MOVE    FAT32$ERR_ILLEGAL_CLUS, R9
                RBRA    _F32_RSIC_END, 1

                ; lba_addr = cluster_begin_lba +
                ;           (cluster_number - 2) * sectors_per_cluster +
                ;           sector
_F32_RSIC_C2    MOVE    R8, R0                      ; save device handle
                MOVE    R11, R1                     ; save sector
                MOVE    R9, R8                      ; R8 = cluster LO
                MOVE    R10, R9                     ; R9 = cluster HI
                SUB     2, R8                       ; cluster = cluster - 2
                SUBC    0, R9
                MOVE    R0, R10                     ; get sectors_per_cluster
                ADD     FAT32$DEV_SECT_PER_CLUS, R10
                MOVE    @R10, R10
                MOVE    0, R11
                RSUB    MULU32, 1                   ; above mentioned "*"
                MOVE    R0, R2                      ; add cluster_begin_lba
                ADD     FAT32$DEV_CLUSTER_LO, R2
                MOVE    @R2, R2
                ADD     R2, R8
                ADDC    0, R9
                ADDC    0, R10
                ADDC    0, R11
                MOVE    R0, R2
                ADD     FAT32$DEV_CLUSTER_HI, R2
                MOVE    @R2, R2
                ADD     R2, R9
                ADDC    0, R10
                ADDC    0, R11
                ADD     R1, R8                      ; add sector
                ADDC    0, R9
                ADDC    0, R10
                ADDC    0, R11
                CMP     0, R11                      ; too large?
                RBRA    _F32_RSIC_C3, Z
                CMP     0, R10
                RBRA    _F32_RSIC_C3, Z
                MOVE    FAT32$ERR_SIZE, R9
                RBRA    _F32_RSIC_END, 1

                ; linear address = lba_addr * 512
_F32_RSIC_C3    MOVE    FAT32$SECTOR_SIZE, R10
                MOVE    0, R11
                RSUB    MULU32, 1
                CMP     0, R11                      ; too large?
                RBRA    _F32_RSIC_C4, Z
                CMP     0, R10
                RBRA    _F32_RSIC_C4, Z
                MOVE    FAT32$ERR_SIZE, R9
                RBRA    _F32_RSIC_END, 1

                ; read sector into internal buffer
_F32_RSIC_C4    MOVE    FAT32$DEV_BLOCK_READ, R10
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                MOVE    R8, R9
                MOVE    R0, R8

_F32_RSIC_END   DECRB
                
                MOVE    R0, R10
                MOVE    R1, R11

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$CHECKSUM computes a directory entry checksum
;*
;* Used to confirm the binding between a long filename and its corresponding
;* short filename and used to detect long filename orphans. Algorithm:
;*
;*        Sum = 0;
;*        for (FcbNameLen=11; FcbNameLen!=0; FcbNameLen--) {
;*            // NOTE: The operation is an unsigned char rotate right
;*            Sum = ((Sum & 1) ? 0x80 : 0) + (Sum >> 1) + *pFcbName++;
;*
;* INPUT:  R8:  pointer to the 11 bytes of a short name
;* OUTPUT: R8:  1 unsigned byte checksum (upper byte of R8 is zero)
;*****************************************************************************
;
FAT32$CHECKSUM  INCRB

                MOVE    11, R0                      ; R0 = character count
                XOR     R1, R1                      ; R1 = 8 bit sum                

                ; perform an unsigned char rotate right
_F32_CHKSM_LP   SHR     1, R1                       ; shift right 1 into X
                RBRA    _F32_CHKSM_NRI, !X          ; X=0: skip
                OR      0x80, R1                    ; X=1: rotate in a 1

                ; perform an unsigned char addition
_F32_CHKSM_NRI  ADD     @R8++, R1                   ; do "+ *FcbName++"
                AND     0x00FF, R1                  ; unsigned char addition

                ; loop
                SUB     1, R0
                RBRA    _F32_CHKSM_LP, !Z  

                MOVE    R1, R8                      ; return checksum

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$READ_B reads a byte from the current sector buffer
;*
;* INPUT:  R8:  pointer to mount data structure (device handle)
;*         R9:  address (0 .. 511)
;* OUTPUT: R10: the byte that was read
;*****************************************************************************
;
FAT32$READ_B    INCRB

                MOVE    R8, R0
                MOVE    R11, R1
                MOVE    R12, R2


                MOVE    R8, R11                 ; mount data structure
                MOVE    R9, R8                  ; read address
                MOVE    FAT32$DEV_BYTE_READ, R10
                RSUB    FAT32$CALL_DEV, 1
                MOVE    R8, R10

                MOVE    R0, R8
                MOVE    R1, R11
                MOVE    R2, R12

                DECRB
                RET
;                
;*****************************************************************************
;* FAT32$READ_W reads a word from the current sector buffer
;*
;* Assumes that the buffer is stored in little endian (as this is the case
;* for MBR and FAT32 data structures)
;* 
;* INPUT:  R8:  pointer to mount data structure (device handle)
;*         R9:  address (0 .. 511)
;* OUTPUT: R10: the word that was read
;*****************************************************************************
;
FAT32$READ_W    INCRB

                MOVE    R8, R0
                MOVE    R9, R1

                RSUB    FAT32$READ_B, 1         ; read low byte ...
                MOVE    R10, R2                 ; ... and remember it
                ADD     1, R9                   ; read high byte ...
                RSUB    FAT32$READ_B, 1
                MOVE    R10, R3                 ; ... and remember it

                SWAP    R3, R10                 ; R3 lo = high byte of R10
                OR      R2, R10                 ; R2 lo = low byte of R10

                MOVE    R0, R8
                MOVE    R1, R9

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$READ_DW reads a double word from the current sector buffer
;*
;* Assumes that the buffer is stored in little endian (as this is the case
;* for MBR and FAT32 data structures)
;*
;* INPUT:  R8:  pointer to mount data structure (device handle)
;*         R9:  address (0 .. 511)
;* OUTPUT: R10: the low word that was read
;*         R11: the high word that was read
;*****************************************************************************
;
FAT32$READ_DW   INCRB
                MOVE    R9, R0

                RSUB    FAT32$READ_W, 1
                MOVE    R10, R1
                ADD     2, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R10, R11
                MOVE    R1, R10

                MOVE    R0, R9
                DECRB
                RET

;=============================================================================
;=============================================================================
;
; POTENTIAL EXTENSIONS OF OTHER MONITOR LIBRARIES START HERE
;
;=============================================================================
;=============================================================================

;
;*****************************************************************************
;* MULU32 multiplies two 32bit unsigned values and returns a 64bit unsigned
;*
;* INPUT:  R8/R9   = LO/HI of unsigned multiplicant 1
;*         R10/R11 = LO/HI of unsigned multiplicant 2
;* OUTPUT: R11/R10/R9/R8 = HI .. LO of 64bit result
;*****************************************************************************
;
MULU32          INCRB                           ; registers R3..R0 = result ..
                INCRB                           ; .. therefore two INCRBs

                ; save arguments as in R1|R0 * R3|R2
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                ; algorithm:
                ;       R1R0
                ; x     R3R2
                ; ----------
                ;       R2R0
                ; +   R2R1
                ; +   R3R0
                ; + R3R1
                ; ----------

                MOVE    R0, R8                  ; R2 * R0
                MOVE    R2, R9
                SYSCALL(mulu, 1)                ; result in R11|R10
                DECRB
                MOVE    R10, R0
                MOVE    R11, R1
                XOR     R2, R2
                XOR     R3, R3
                INCRB

                MOVE    R1, R8                  ; R2 * R1
                MOVE    R2, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R0, R8                  ; R3 * R0
                MOVE    R3, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R1, R8                  ; R3 * R1
                MOVE    R3, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R2
                ADDC    R11, R3

                MOVE    R3, R11                 ; store result (return values)
                MOVE    R2, R10
                MOVE    R1, R9
                MOVE    R0, R8

                DECRB
                RET
;
;*****************************************************************************
;* DIVU32 divides 32bit dividend by 32bit divisor and returns
;*        a 32bit quotient and a 32bit modulo
;*        warning: no division by zero warning; instead, the function returns
;*        zero as result and as modulo
;*
;* INPUT:  R8/R9   = LO|HI of unsigned dividend
;*         R10/R11 = LO|HI of unsigned divisor
;* OUTPUT: R8/R9   = LO|HI of unsigned quotient
;*         R10/R11 = LO|HI of unsigned modulo
;*****************************************************************************
;
DIVU32          INCRB

                ; perform the division by using the following algorithm, where
                ; N = dividend = HI|LO = R9|R8
                ; D = divisor  = HI|LO = R11|R10
                ; Q = quotient = HI|LO = R1|R0
                ; R = remainder (modulo) = HI|LO = R3|R2
                ;
                ; Q := 0               quotient and remainder = 0
                ; R := 0                     
                ; for i = n−1...0 do   where n is number of bits in N
                ;   R := R << 1        left-shift R by 1 bit
                ;   R(0) := N(i)       set the least-significant bit
                ;                      of R equal to bit i of the divisor    
                ;   if R >= D then
                ;     R := R − D
                ;     Q(i) := 1
                ;   end
                ; end                

                XOR     R0, R0                  ; HI|LO = R1|R0 = quotient
                XOR     R1, R1                  
                XOR     R2, R2                  ; HI|LO = R3|R2 = reminder
                XOR     R3, R3

                ; division by zero
                ; as we have no interrupts and no additional error flag,
                ; we return zero on a division by zero
                CMP     R11, R0
                RBRA    _DIVU32_START, !Z
                CMP     R10, R0
                RBRA    _DIVU32_START, !Z
                RBRA    _DIVU32_END, 1

_DIVU32_START   MOVE    31, R4                  ; R4 = bit counter: 31 .. 0

                ; R := R << 1: 32bit shift-left of R
_DIVU32_NEXTBIT AND     0xFFFD, SR              ; clear X (shift in '0')
                SHL     1, R2                   ; MSB of lo word shifts to C
                RBRA    _DIVU32_SHL0, !C        ; C=0 => X=0
                OR      0x0002, SR              ; C=1 => X=1
                SHL     1, R3                   ; hi word (shifts in X=1)
                RBRA    _DIVU32_RNI, 1
_DIVU32_SHL0    AND     0xFFFD, SR              ; C=0 => X=0                
                SHL     1, R3                   ; hi word (shifts in X=0)

                ; R(0) := N(i)
_DIVU32_RNI     MOVE    R4, R6
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _DIVU32_RNIL, !N        ; yes: consider low word of R
                MOVE    R9, R5                  ; high word of N
                SUB     16, R6                  ; correct index b/c of hi word
                RBRA    _DIVU32_RNIH, 1
_DIVU32_RNIL    MOVE    R8, R5                  ; low word of N
_DIVU32_RNIH    AND     0xFFFB, SR              ; clear C
                SHR     R6, R5                  ; extract bit by SHR to the ..
                AND     1, R5                   ; ..LSB pos. and and-ing 1
                AND     0xFFFE, R2              ; clear target bit and ...
                OR      R5, R2                  ; ... set it again, if needed

                ; if R >= D then
                ; done by doing 32bit R - D and checking:
                ; if MSB = 1, then R < D, else R >= D
                ; hint: MSB in this case is the 33th bit, i.e. bit #32 = carry
                MOVE    R2, R5                  ; R5 = low word of R
                MOVE    R3, R6                  ; R6 = high word of R
                SUB     R10, R5                 ; R6|R5 = 32bit (R := R - D)
                SUBC    R11, R6
                RBRA    _DIVU32_ITERATE, C      ; bit #32 is "negative"

                ; when reaching this code, R is >= D
                ;   if R >= D then
                ;     R := R − D
                ;     Q(i) := 1
                ;   end
                MOVE    R6, R3                  ; R = R6|R5 = (R := R - D)
                MOVE    R5, R2
                MOVE    1, R7                   ; Q(i) := 1 by shifting a "1"
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _DIVU32_QL, !N          ; yes: consider low word of Q
                MOVE    R4, R6                  ; R6 := i
                SUB     16, R6                  ; adjust for high word
                AND     0xFFFD, SR              ; clear X
                SHL     R6, R7                  ; move "1" to the right place
                OR      R7, R1                  ; R1:= hi Q(i) := 1
                RBRA    _DIVU32_ITERATE, 1

_DIVU32_QL      AND     0xFFFD, SR              ; clear X
                SHL     R4, R7                  ; move "1" to the right place
                OR      R7, R0                  ; R0 := low Q(i) := 1

                ; for i = n−1...0 do (i.e. also one loop for the case i=0)
_DIVU32_ITERATE SUB     1, R4
                RBRA    _DIVU32_NEXTBIT, !N     ; !N includes a round for i=0

                ; return results
_DIVU32_END     MOVE    R1, R9                  ; hi Q
                MOVE    R0, R8                  ; lo Q
                MOVE    R3, R11                 ; hi R
                MOVE    R2, R10                 ; lo R

                DECRB
                RET
;
;*****************************************************************************
;* TO_LOWER converts the character in R8 to lower case
;* (already added to the monitor, but not synthesized yet as of 16/7/3)
;* (so this is TEMP; replace by SYSCALL, soon)
;*****************************************************************************
;
TO_LOWER        INCRB
                CMP     R8, '@'                 ; Is it "@" or less than that?
                RBRA    _TO_LOWER_EXIT, !N      ; Yes: nothing to do
                CMP     R8, 'Z'                 ; Is it greater than 'Z'
                RBRA    _TO_LOWER_EXIT, N       ; Yes: nothing to do
                ADD     0x0020, R8              ; Perform the conversion
_TO_LOWER_EXIT  DECRB
                RET
;
;*****************************************************************************
;* SPLIT splits a string into substrings using a delimiter char
;*
;* Returns the substrings on the stack, i.e. after being done, you need to
;* add the amount of words returned in R9 to the stack pointer to clean
;* it up again and not leaving "memory leaks".
;*
;* The memory layout of the returned area is:
;* <size of string incl. zero terminator><string><zero terminator>
;*
;* The strings are returned in positive order, i.e. you just need to add
;* the length of the previous string to the returned string pointer
;* (i.e. stack pointer) to jump to the next substring from left to right.
;*
;* INPUT:  R8: pointer to zero terminated string
;*         R9: delimiter char
;* OUTPUT: SP: stack pointer pointer to the first string
;*         R8: amount of strings
;*         R9: amount of words to add to the stack pointer to restore it
;*****************************************************************************
;
SPLIT           INCRB

                MOVE    @SP++, R0               ; save return address and
                                                ; delete it by adding 1

                ; find the end of the string, R1 will point to it
                MOVE    1, R2
                MOVE    R8, R1
_SPLIT_FE       CMP     @R1, 0
                RBRA    _SPLIT_FE2, Z
                ADD     R2, R1
                RBRA    _SPLIT_FE, 1

_SPLIT_FE2      MOVE    R1, R2                  ; R2 = end of current substr
                XOR     R6, R6                  ; R6 = amount of strings
                XOR     R7, R7                  ; R7 = amount of words for R9

                ; skip empty string
                CMP     R8, R1
                RBRA    _SPLIT_ES_END, Z

                ; find the first occurrence of the delimiter
_SPLIT_FD       CMP     @--R1, R9               ; check for delimiter, mv left
                RBRA    _SPLIT_SS, Z            ; yes, delimiter found
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _SPLIT_SS, Z
                RBRA    _SPLIT_FD, 1                

                ; copy substring on the stack, if it is at least one
                ; non-delimiter character
_SPLIT_SS       MOVE    R2, R3
                SUB     R1, R3                  ; length of substring w/o zero
                CMP     R3, 1                   ; only one character?
                RBRA    _SPLIT_SSB, !Z          ; no: go on
                CMP     @R1, R9                 ; only one char and char=delim
                RBRA    _SPLIT_SS_SKP, Z        ; yes: skip
_SPLIT_SSB      ADD     1, R6                   ; one more string                
                SUB     R3, SP                  ; reserve memory on the stack
                SUB     2, SP                   ; size word & zero terminator
                ADD     R3, R7                  ; adjust amount of words ..
                ADD     2, R7                   ; .. equally to stack usage
                CMP     @R1, R9                 ; first char delimiter?
                RBRA    _SPLIT_SS_BGN, !Z       ; no: go on
                ADD     1, SP                   ; yes: adjust stack usage ..
                SUB     1, R7                   ; .. and word counter ..
                SUB     1, R3                   ; .. and reduce length ..
                ADD     1, R1                   ; .. and change start
_SPLIT_SS_BGN   MOVE    R1, R4                  ; R4 = cur. char of substring
                MOVE    SP, R5                  ; R5 = target memory of char
                MOVE    R3, @R5                 ; save size w/o zero term.
                ADD     1, @R5++                ; adjust for zero term.
_SPLIT_SS_CPY   MOVE    @R4++, @R5++            ; copy char
                SUB     1, R3                   ; R3 = amount to be copied
                RBRA    _SPLIT_SS_CPY, !Z
                MOVE    0, @R5                  ; add zero terminator

_SPLIT_SS_SKP   MOVE    R1, R2                  ; current index = new end
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _SPLIT_FD, !Z

_SPLIT_ES_END   MOVE    R6, R8                  ; return amount of strings
                MOVE    R7, R9                  ; return amount of bytes

                MOVE    R0, @--SP               ; put return address on stack

                DECRB
                RET                
;
;*****************************************************************************
;* H2D_ASCII converts a 32bit value to a decimal representation in ASCII;
;* leading zeros are replaced by spaces (ASCII 0x20); zero terminator is added
;*
;* INPUT:  R8/R9   = LO/HI of the 32bit value
;*         R10     = pointer to a free memory area that is 11 words long
;* OUTPUT: R10     = the function fills the given memory space with the
;*                   decimal representation and adds a zero terminator
;*                   this includes leading white spaces
;*         R11     = pointer to string without leading white spaces
;*         R12     = amount of digits/characters that the actual number has,
;*                   without the leading spaces
;*****************************************************************************
;
H2D_ASCII       INCRB

                MOVE    R8, R0                  ; save original values
                MOVE    R9, R1
                MOVE    R10, R2

                MOVE    R10, R3                 ; R3: working pointer
                XOR     R4, R4                  ; R4: digit counter

                ; add zero terminator
                ADD     10, R3
                MOVE    0, @R3

                ; extract decimals by repeatedly dividing the 32bit value
                ; by 10; the modulus is the decimal that is converted to
                ; ASCII by adding the ASCII code of zero which is 0x0030
                XOR     R11, R11                ; high word = 0
_H2DASCII_ML    MOVE    10, R10                 ; divide by 10
                RSUB    DIVU32, 1               ; perform division
                ADD     0x0030, R10             ; R10 = digit => ASCII conv.
                MOVE    R10, @--R3              ; store digit
                ADD     1, R4                   ; increase digit counter
                CMP     R8, 0                   ; quotient = 0? (are we done?)
                RBRA    _H2DASCII_TS, Z         ; yes: add trailing spaces                
                RBRA    _H2DASCII_ML, 1         ; next digit, R8/R9 has result

_H2DASCII_TS    CMP     R3, R2                  ; working pntr = memory start
                RBRA    _H2DASCII_DONE, Z       ; yes: then done
                MOVE    0x0020, @--R3           ; no: add trailing space
                RBRA    _H2DASCII_TS, 1         ; next digit

_H2DASCII_DONE  MOVE    R0, R8                  ; restore original values
                MOVE    R1, R9
                MOVE    R2, R10

                MOVE    R10, R11                ; return pointer to string ..
                MOVE    10, R7                  ; .. without white spaces
                SUB     R4, R7
                ADD     R7, R11

                MOVE    R4, R12                 ; return digit counter             
                DECRB
                RET

;=============================================================================
;=============================================================================
;
; POTENTIAL EXTENSIONS OF THE MONITOR END HERE
;
;=============================================================================

STRBUF          .BLOCK 1
