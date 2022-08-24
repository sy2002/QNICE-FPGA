;
; First test of the simplified FAT32 writing routine that was done
; in August 2022 and that allows to modifying the bytes of an existing
; file without appending or deleting data and without creating new files.
;
; done in August 2022 by sy2002

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    HANDLE_DEV, R8          ; device handle
                MOVE    1, R9                   ; partition 1
                SYSCALL(f32_mnt_sd, 1)          ; mount device
                CMP     0, R9                   ; error code in R9
                RBRA    MOUNT_OK, Z             ; no error: continue

                MOVE    STR_ERR_MNT, R8         ; error: stop
ERR_END1        SYSCALL(puts, 1)
                MOVE    R9, R8                  ; error code is in R9
                SYSCALL(puthex, 1)
ERR_END2        SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)
                SYSCALL(exit, 1)

MOUNT_OK        MOVE    HANDLE_FILE, R9         ; file hdl; R8: still dev hdl
                MOVE    STR_TEST_FILE, R10      ; R10: file name
                XOR     R11, R11                ; R11=0: "/" is path separator
                SYSCALL(f32_fopen, 1)           ; open file
                CMP     0, R10                  ; this time: error code in R10
                RBRA    FOPEN_OK, Z             ; no error: continue

                MOVE    STR_FNF, R8             ; file not found: stop
                SYSCALL(puts, 1)
                RBRA    ERR_END2, 1

                ; we will overwrite each byte of the test file with the ever
                ; increasing low byte of R0
FOPEN_OK        MOVE    R9, R8                  ; R8: file handle
                XOR     R0, R0                  ; R0: start with zero

LOOP            MOVE    R0, R9
                SYSCALL(f32_fwrite, 1)          ; write byte
                CMP     FAT32$EOF, R9           ; end of file?
                RBRA    NEXT, Z                 ; yes: next test
                CMP     0, R9                   ; everything OK?
                RBRA    LOOP_1, Z               ; yes

                MOVE    STR_ERR_WRITE1, R8
                RBRA    ERR_END1, 1

LOOP_1          ADD     1, R0                   ; next byte
                RBRA    LOOP, 1

                ; seek to some hardcoded positions and write some hardcoded
                ; values (you need to make sure that the test file is large
                ; enough)
NEXT            MOVE    SEEKTEST_COUNT, R0
                MOVE    @R0, R0
                MOVE    SEEKTEST, R1

NEXT_0          MOVE    @R1++, R9
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9
                RBRA    NEXT_1, Z

                MOVE    STR_ERR_SEEK, R8
                RBRA    ERR_END1, 1

NEXT_1          MOVE    @R1++, R9
                SYSCALL(f32_fwrite, 1)
                CMP     0, R9
                RBRA    NEXT_2, Z

                MOVE    STR_ERR_WRITE2, R8
                RBRA    ERR_END1, 1

NEXT_2          SUB     1,  R0
                RBRA    NEXT_0, !Z           

                ; it is important to close the file (handle is still in R8)
                ; because during file close, the sector buffer is being
                ; flushed and potentially remaining bytes are written
END             SYSCALL(f32_fclose, 1)
                CMP     0, R9
                RBRA    DONE, Z

                MOVE    STR_ERR_CLOSE, R8
                RBRA    ERR_END1, 1

DONE            MOVE    STR_DONE, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

HANDLE_DEV      .BLOCK FAT32$DEV_STRUCT_SIZE
HANDLE_FILE     .BLOCK FAT32$FDH_STRUCT_SIZE

                ; test file
                ; caution: this test file will be overwritten
STR_TEST_FILE   .ASCII_W "/asm/32bit-div.asm"
;STR_TEST_FILE   .ASCII_W "/qbin/the-matrix.html"

                ; general strings
STR_TITLE       .ASCII_P "Simple FAT32$FILE_WB test - "
                .ASCII_W "done by sy2002 in August 2022\n"
STR_FNF         .ASCII_W "File not found. Please check STR_TEST_FILE."
STR_ERR_MNT     .ASCII_W "Error mounting SD-card and/or file system: "
STR_ERR_WRITE1  .ASCII_W "Write #1 error: "
STR_ERR_WRITE2  .ASCII_W "Write #2 error: "
STR_ERR_SEEK    .ASCII_W "Seek error: "
STR_ERR_CLOSE   .ASCII_W "Close error: "
STR_DONE        .ASCII_W "Done.\n\n"

                ; seek positions and values
SEEKTEST_COUNT  .DW 3                
SEEKTEST        .DW   23, 0x0023
                .DW 1025, 0x0009
                .DW 3050, 0x0076
