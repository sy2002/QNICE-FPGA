; SD Card and FAT32 development testbed
; contains reusable functions that can be the basis for enhancing the monitor
; done by sy2002 in June 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

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
MAIN_MRR        SYSCALL(getc, 1)
                CMP     R8, '1'
                RBRA    IA_DUMP, Z
                CMP     R8, '2'
                RBRA    MNT_SD, Z
                CMP     R8, '3'
                RBRA    END_PROGRAM, Z

                RBRA    MAIN_MRR, 1

;=============================================================================
; Mount partition 1 as FAT32 and perform various tests
;=============================================================================                

MNT_SD          MOVE    STR_MNT_TILE, R8
                SYSCALL(puts, 1)
                MOVE    MOUNT_STRUCT, R8
                RSUB    FAT32$MOUNT_SD, 1       ; mount device
                MOVE    R9, R8
                RSUB    ERR_CHECK, 1
                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                MOVE    STR_MNT_FSSTART, R8     ; show fs start adddress
                SYSCALL(puts, 1)
                MOVE    MOUNT_STRUCT, R8
                ADD     FAT32$DEV_FS_HI, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)
                MOVE    STR_SPACE1, R8
                SYSCALL(puts, 1)
                MOVE    MOUNT_STRUCT, R8
                ADD     FAT32$DEV_FS_LO, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                RBRA    END_PROGRAM, 1

;=============================================================================
; Interactive register dump
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

;=============================================================================
; Mount structure (variable) and string constants
;=============================================================================

MOUNT_STRUCT    .BLOCK 16                       ; mount struct / device handle

STR_TITLE       .ASCII_W "SD Card development testbed\n===========================\n\n"
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
STR_MEN_TITLE   .ASCII_P "\nChoose a test case to proceed:\n"
                .ASCII_P "    1.   Dump raw data from SD Card\n"
                .ASCII_P "    2.   Mount partition 1 (assuming valid MBR and a FAT32 file system)\n"
                .ASCII_W "    3.   Exit\n\n"
STR_IA_TITLE    .ASCII_W "Read 512 byte block from SD card and output it:\n"
STR_IA_HIGH     .ASCII_W "    Address HIGH word: "
STR_IA_LOW      .ASCII_W "    Address LOW word:  "
STR_IA_AGAIN    .ASCII_W "Enter 'y' for reading another block: "
STR_ERR_END     .ASCII_W "\nTERMINATED DUE TO FATAL ERROR: "
STR_MNT_TILE    .ASCII_W "Mounting partition #1 of SD Card as FAT32: "
STR_MNT_FSSTART .ASCII_W "    linear start address of file system: "

;=============================================================================
;=============================================================================
;
; REUSABLE CONSTANT DEFINITIONS AND FUNCTIONS START HERE
;
;=============================================================================
;=============================================================================

;
;*****************************************************************************
;* SD$RESET resets the SD Card.
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
;* SD$READ_BLOCK reads a 512 byte block from the SD Card. 
;*
;* Input: R8/R9 = LO/HI words of the 32-bit read address
;* Output: R8 = 0 (no error), or error code
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
;* SD$WRITE_BLOCK writes a 512 byte block to the SD Card.
;*
;* @TODO: Implement and document
;*****************************************************************************
;
SD$WRITE_BLOCK  INCRB
                DECRB
                RET
;
;*****************************************************************************
;* SD$READ_BYTE reads a byte from the read buffer memory of the controller.
;*
;* Input: R8 = address between 0 .. 511
;* Output: R8 = byte
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
;* SD$WRITE_BYTE writes a byte to the write memory buffer of the controller.
;*
;* @TODO: Implement and document
;*****************************************************************************
;
SD$WRITE_BYTE   INCRB
                DECRB
                RET
;
;*****************************************************************************
;* SD$WAIT_BUSY waits, while the SD Card is executing any command.
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
;* FAT32$MOUNT_SD mounts the SD card partition 1 as a FAT32 file system
;*
;* Wrapper to simplify the use of the generic FAT32$MOUNT function. Read the
;* documentation of FAT32$MOUNT to learn more.
;* 
;* INPUT:  R8 points to a XX word large empty structure.
;* OUTPUT: R8 points to a handle of the mounted device that is used in
;*         subsequent function calls.
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
                MOVE    1, @R0

                ; call master mount function
                RSUB    FAT32$MOUNT, 1

                DECRB
                RET

;*****************************************************************************
;* FAT32$MOUNT mounts a FAT32 file system on arbitrary hardware.
;*
;* The abstraction requires 5 functions to be implemented: Read and write
;* a 512-byte-sized sector using LBA mode. Read and write a byte from within
;* a buffer that contains the current sector. Reset the device. The function
;* signatures and behaviour needs to be equivalent to the SD card functions
;* that are part of this library. You need to pass pointers to these functions
;* to the mount function call in the mount initialization structure.
;*
;* All subsequent calls to FAT32 functions expect as the first parameter a
;* pointer to the mount data structure that is being generated during the
;* execution of this function. With this mechanism, an arbitrary amount of
;* filesystems can be mounted on an arbitrary amount and type of hardware.
;*
;* INPUT: R8: pointer to the mount initialization structure that is build up
;* in the following form. Important: The structure is XX words large, that
;* means that a call to FAT32$MOUNT will append more words to the structure
;* than the ones, that have to be pre-filled before calling FAT32$MOUNT:
;*  word #0: pointer to a device reset function, similar to SD$RESET
;*  word #1: pointer to a block read function, similar to SD$READ_BLOCK
;*  word #2: pointer to a block write function, similar to SD$WRITE_BLOCK
;*  word #3: pointer to a byte read function, similar to SD$READ_BYTE
;*  word #4: pointer to a byte write function, similar to SD$WRITE_BYTE
;*  word #5: number of the partition to be mounted (0x0001 .. 0x0004)
;*  word #6 .. word # : will be filled by by FAT32$MOUNT, their layout is
;*                      as follows:
;*  word #6: start address of file system (low word of linear address)
;*  word #7: start address of file system (high word of linear address)
;*
;* OUTPUT: R8 is preserved and still points to the structure that has been
;* filled by the function from word #6 on.
;* R9 contains 0, if everything went OK, otherwise it contains the error code
;*****************************************************************************
;
FAT32$MOUNT     INCRB

                MOVE    R8, R0                  ; save pointer to structure

                MOVE    R8, @--SP
                MOVE    R10, @--SP
                MOVE    R11, @--SP

                ; Exit with an error code, if a partition other than 1 is
                ; requested to be read. The reason for this behaviour is,
                ; that at the time of the writing of this code, we are not
                ; having a multiplication function, yet, that allows to
                ; multiply a 32bit value by 512. But this would be necessary
                ; to calculate the start address (LBA) of partition #2 in case
                ; that partition #1 is larger than $FFFF x 512 = ~31MB.
                MOVE    R0, R1
                ADD     FAT32$DEV_PARTITION, R1
                CMP     1, @R1
                RBRA    _F32_MNT_RESET, Z
                MOVE    FAT32$ERR_NOTIMPL, R9 
                RBRA    _F32_MNT_END, 1

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
                CMP     0, R8
                RBRA    _F32_MNT_MBR, Z
                MOVE    R8, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_MBR    MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                MOVE    R0, R8
                MOVE    FAT32$MBR_MAGIC_ADDR, R9    ; read magic word
                RSUB    FAT32$READ_W, 1
                CMP     FAT32$MBR_MAGIC, R10        ; compare magic word
                RBRA    _F32_MNT_RPAR, Z            ; magic correct: go on
                MOVE    FAT32$ERR_MBR, R9           ; magic wrong: error code
                RBRA    _F32_MNT_END, 1

                ; read and decode first partition table entry:
                ; 1. check for the FAT32 type description
                ; 2. check, if the linear start address of the file system
                ;    of the first partition is less than ~31MB, because
                ;    otherwise we would need better multiplication functions
                ;    (see explanation about hardcoded partition 1 above)
                ; 3. calculate the linar start address by multiplying the
                ;    sector number with 512
_F32_MNT_RPAR   MOVE    FAT32$MBR_PARTTBL_START, R8 ; hardcoded partition 1
                ADD     FAT32$MBR_PT_TYPE, R8       ; type flag: FAT32 ?
                MOVE    FAT32$DEV_BYTE_READ, R10
                RSUB    FAT32$CALL_DEV, 1
                CMP     FAT32$MBR_PT_TYPE_C1, R8    ; check for alternative 1
                RBRA    _F32_MNT_TCOK, Z            ; OK: continue
                CMP     FAT32$MBR_PT_TYPE_C2, R8    ; check for alternative 2
                RBRA    _F32_MNT_TCOK, Z            ; OK: continue
                MOVE    FAT32$ERR_PARTTBL, R9       ; not OK: error code
                RBRA    _F32_MNT_END, 1  
_F32_MNT_TCOK   MOVE    R0, R8
                MOVE    FAT32$MBR_PARTTBL_START, R9 ; find FS start sector
                ADD     FAT32$MBR_PT_FS_START, R9
                RSUB    FAT32$READ_DW, 1
                CMP     R11, 0                      ; the first partition..
                RBRA    _F32_MNT_SOK, Z             ; ..needs to start within
                MOVE    FAT32$ERR_SIZE, R9          ; ..the first ~31 MB
                RBRA    _F32_MNT_END, 1
_F32_MNT_SOK    MOVE    FAT32$SECTOR_SIZE, R8       ; calculate linear addr
                MOVE    R10, R9
                SYSCALL(mulu, 1)
                MOVE    R0, R1
                ADD     FAT32$DEV_FS_LO, R1         ; store linear addr
                MOVE    R10, @R1
                MOVE    R0, R1
                ADD     FAT32$DEV_FS_HI, R1
                MOVE    R11, @R1

                ; read and decode "Volume ID" (first sector of the FS)
                ; 1. check for magic
                ; 2. check for 512-byte sector size
                ; 3. check for two FATs
                ; 4. read sectors per fat and check if the hi word of sectors
                ;    per fat is zero, as we otherwise would again run into
                ;    multiplication problems (see above)
                ; 5. read root directory first cluster and check if the hi
                ;    word is zero for the same reason
                ; 6. read sectors per cluster
                MOVE    R10, R8                     ; read 512 byte block
                MOVE    R11, R9
                MOVE    FAT32$DEV_BLOCK_READ, R10
                MOVE    R0, R11
                RSUB    FAT32$CALL_DEV, 1
                CMP     0, R8
                RBRA    _F32_MNT_VID, Z
                MOVE    R8, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_VID    MOVE    R0, R8
                MOVE    FAT32$MAGIC_OFS, R9         ; check magic
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
_F32_MNT_VERR   MOVE    FAT32$ERR_FAT32VOLID, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_RVID   MOVE    R0, R8
                MOVE    FAT32$SECPERFAT_OFS, R9     ; read sectors per FAT
                RSUB    FAT32$READ_DW, 1
                CMP     0, R11
                RBRA    _F32_MNT_SERR, !Z
                MOVE    R10, R1                     ; R1: sectors per FAT
                MOVE    FAT32$ROOTCLUS_OFS, R9      ; read root dir 1st clus.
                RSUB    FAT32$READ_DW, 1
                CMP     0, R11
                RBRA    _F32_MNT_SERR, !Z
                MOVE    R10, R2                     ; R2: root dir 1st clus.
                RBRA    _F32_MNT_RVI2, 1
_F32_MNT_SERR   MOVE    FAT32$ERR_SIZE, R9
                RBRA    _F32_MNT_END, 1
_F32_MNT_RVI2   MOVE    FAT32$SECPERCLUS_OFS, R9    ; read sectors per cluster
                RSUB    FAT32$READ_B, 1
                MOVE    R10, R3                     ; R3: sectors per cluster
                MOVE    FAT32$RSSECCNT_OFS, R9      ; read number resvd. sec.
                RSUB    FAT32$READ_W, 1
                MOVE    R10, R4                     ; R4: # reserved sectors

                MOVE    0, R9 ; @TODO GO ON HERE

_F32_MNT_END    MOVE    @SP++, R11                  ; restore registers
                MOVE    @SP++, R10
                MOVE    @SP++, R8

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$CALL_DEV calls a device management function
;*
;* IN:  R8, R9 are the parameters to the function
;*      R10 is the function index
;*      R11 is the mount data structure
;*
;* OUT: R8 is the return value from the function
;*****************************************************************************
;
FAT32$CALL_DEV  INCRB

                MOVE    R11, R0                 ; compute function address
                ADD     R10, R0
                MOVE    _F32$CD_END, @--SP      ; compute return address

                MOVE    @R0, PC                 ; perform function call

_F32$CD_END     DECRB
                RET
;
;*****************************************************************************
;* FAT32$READ_B reads a byte from the current sector buffer
;*
;* IN:  R8:  pointer to mount data structure
;*      R9:  address (0 .. 511)
;* OUT: R10: the byte that was read
;*****************************************************************************
;
FAT32$READ_B    INCRB
                MOVE    R8, @--SP

                MOVE    R8, R11                 ; mount data structure
                MOVE    R9, R8                  ; read address
                MOVE    FAT32$DEV_BYTE_READ, R10
                RSUB    FAT32$CALL_DEV, 1
                MOVE    R8, R10

                MOVE    @SP++, R8
                DECRB
                RET
;                
;*****************************************************************************
;* FAT32$READ_W reads a word from the current sector buffer
;*
;* Assumes that the buffer is stored in little endian (as this is the case
;* for MBR and FAT32 data structures)
;* 
;* IN:  R8:  pointer to mount data structure
;*      R9:  address (0 .. 511)
;* OUT: R10: the word that was read
;*****************************************************************************
;
FAT32$READ_W    INCRB

                MOVE    R8, @--SP
                MOVE    R9, @--SP

                RSUB    FAT32$READ_B, 1         ; read low byte ...
                MOVE    R10, R0                 ; ... and remember it
                ADD     1, R9                   ; read high byte ...
                RSUB    FAT32$READ_B, 1
                MOVE    R10, R1                 ; ... and remember it

                SWAP    R1, R10                 ; R1 lo = high byte of R10
                OR      R0, R10                 ; R0 lo = low byte of R10

                MOVE    @SP++, R9
                MOVE    @SP++, R8

                DECRB
                RET
;
;*****************************************************************************
;* FAT32$READ_DW reads a double word from the current sector buffer
;*
;* Assumes that the buffer is stored in little endian (as this is the case
;* for MBR and FAT32 data structures)
;*
;* IN:  R8:  pointer to mount data structure
;*      R9:  address (0 .. 511)
;* OUT: R10: the low word that was read
;*      R11: the high word that was read
;*****************************************************************************
;
FAT32$READ_DW   INCRB
                MOVE    R9, @--SP

                RSUB    FAT32$READ_W, 1
                MOVE    R10, R0
                ADD     2, R9
                RSUB    FAT32$READ_W, 1
                MOVE    R10, R11
                MOVE    R0, R10

                MOVE    @SP++, R9
                DECRB
                RET
