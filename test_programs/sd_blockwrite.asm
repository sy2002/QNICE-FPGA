; ****************************************************************************
; SD Card Blockwrite Test
;
; Writes one 512-byte block at the specified address. The 512-byte block
; consists of two times $00..$FF and the target address can be defined using
; two LBA constants.
;
; done by sy2002 in September 2022
; ****************************************************************************

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000                  ; start at 0x8000

;                ; wait about 20 seconds
;                MOVE    0x0900, R0
;LOOP_1          MOVE    0xFFFF, R1
;LOOP_2          SUB     1, R1
;                RBRA    LOOP_2, !Z
;                SUB     1, R0
;                RBRA    LOOP_1, !Z

                ; Reset SD card
                MOVE    IO$SD_CSR, R0
                MOVE    SD$CMD_RESET, @R0
WAIT_RESETEND   MOVE    @R0, R1
                AND     SD$BIT_BUSY, R1
                RBRA    WAIT_RESETEND, !Z

                ; fill 512-byte internal buffer with 2x $00..$FF
                MOVE    IO$SD_DATA_POS, R0
                MOVE    IO$SD_DATA, R1
                MOVE    0, @R0            
FILL            MOVE    @R0, @R1
                ADD     1, @R0
                CMP     512, @R0
                RBRA    FILL, !Z

                ; Write block
                MOVE    IO$SD_ADDR_LO, R0
                MOVE    LBA_LO, @R0
                MOVE    IO$SD_ADDR_HI, R0
                MOVE    LBA_HI, @R0
                MOVE    IO$SD_CSR, R0
                MOVE    SD$CMD_WRITE, @R0

                SYSCALL(exit, 1)


; Write at block at 7GB = 7.516.192.768 bytes = 0xE00000 blocks
LBA_HI          .EQU    0x00E0
LBA_LO          .EQU    0x0000
