;;
;;  sysdef.asm: This file contains definitions to simplify assembler programming
;;              and for accessing the various hardware registers via MMIO
;;

;
;***************************************************************************************
;*  Assembler macros which make life much easier:
;***************************************************************************************
;
#define RET     MOVE    @R13++, R15
#define INCRB   ADD     0x0100, R14
#define DECRB   SUB     0x0100, R14
#define NOP     ABRA    R15, 1

#define SYSCALL(x,y)    ASUB    x, y

;
;  Some register short names:
;
#define PC  R15
#define SR  R14
#define SP  R13

;
;***************************************************************************************
;* Constant definitions
;***************************************************************************************
;

; ========== VGA ==========

VGA$MAX_X               .EQU    79                      ; Max. X-coordinate in decimal!
VGA$MAX_Y               .EQU    39                      ; Max. Y-coordinate in decimal!
VGA$MAX_CHARS           .EQU    3200                    ; VGA$MAX_X * VGA$MAX_Y
VGA$CHARS_PER_LINE      .EQU    80  

VGA$EN_HW_CURSOR        .EQU    0x0040                  ; Show hardware cursor
VGA$EN_HW_SCRL          .EQU    0x0C00                  ; Hardware scrolling enable
VGA$CLR_SCRN            .EQU    0x0100                  ; Clear screen
VGA$BUSY                .EQU    0x0200                  ; VGA is currently performing a task

VGA$COLOR_RED           .EQU    0x0004
VGA$COLOR_GREEN         .EQU    0x0002
VGA$COLOR_BLUE          .EQU    0x0001
VGA$COLOR_WHITE         .EQU    0x0007

; ========== CYCLE COUNTER ==========

CYC$RESET               .EQU    0x0001                  ; Reset cycle counter
CYC$RUN                 .EQU    0x0002                  ; Start/stop counter

; ========== EAE ==========

EAE$MULU                .EQU    0x0000                  ; Unsigned 16 bit multiplication
EAE$MULS                .EQU    0x0001                  ; Signed 16 bit multiplication
EAE$DIVU                .EQU    0x0002                  ; Unsigned 16 bit division with remainder
EAE$DIVS                .EQU    0x0003                  ; Signed 16 bit division with remainder
EAE$BUSY                .EQU    0x8000                  ; Busy flag (1 = operation still running)

; ========== SD CARD ==========

SD$CMD_RESET            .EQU    0x0000                  ; Reset SD card
SD$CMD_READ             .EQU    0x0001                  ; Read 512 bytes from SD to internal buffer
SD$CMD_WRITE            .EQU    0x0002                  ; Write 512 bytes from int. buf. to SD
SD$BIT_ERROR            .EQU    0x4000                  ; Error flag: 1, if last operation failed
SD$BIT_BUSY             .EQU    0x8000                  ; Busy flag: 1, if current op. is still running
SD$TIMEOUT_MID          .EQU    0x0479                  ; equals ~75.000.000 cycles, i.e. 1.5sec @ 50 MHz
SD$ERR_TIMEOUT          .EQU    0xEE01                  ; error: operation timed out

; ========== FAT32 =============

; FAT32 ERROR CODES

FAT32$ERR_MBR           .EQU    0xEE10                  ; no or illegal Master Boot Record (MBR) found
FAT32$ERR_PARTITION_NO  .EQU    0xEE11                  ; the partition number needs to be in the range 1 .. 4
FAT32$ERR_PARTTBL       .EQU    0xEE12                  ; no or illegal partition table entry found (e.g. no FAT32 partition)
FAT32$ERR_NOTIMPL       .EQU    0xEE13                  ; functionality is not implemented
FAT32$ERR_SIZE          .EQU    0xEE14                  ; partition size or volume size too large (see doc/constraints.txt)
FAT32$ERR_NOFAT32       .EQU    0xEE15                  ; illegal volume id (either not 512 bytes per sector, or not 2 FATs or wrong magic)

; CONSTANTS FOR PARSING MBR and FAT32

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

; LAYOUT OF THE MOUNT DATA STRUCTURE (DEVICE HANDLE)

FAT32$DEV_RESET         .EQU    0x0000                  ; pointer to device reset function
FAT32$DEV_BLOCK_READ    .EQU    0x0001                  ; pointer to 512-byte block read function
FAT32$DEV_BLOCK_WRITE   .EQU    0x0002                  ; pointer to 512-byte block write function
FAT32$DEV_BYTE_READ     .EQU    0x0003                  ; pointer to 1-byte read function (within block buffer)
FAT32$DEV_BYTE_WRITE    .EQU    0x0004                  ; pointer to 1-byte write function (within block buffer)
FAT32$DEV_PARTITION     .EQU    0x0005                  ; number of partition to be mounted
FAT32$DEV_FS_LO         .EQU    0x0006                  ; file system start address (LBA): low word
FAT32$DEV_FS_HI         .EQU    0x0007                  ; file system start address (LBA): high word
FAT32$DEV_FAT_LO        .EQU    0x0008                  ; fat start address (LBA): low word
FAT32$DEV_FAT_HI        .EQU    0x0009                  ; fat start address (LBA): high word
FAT32$DEV_CLUSTER_LO    .EQU    0x000A                  ; cluster start address (LBA): low word
FAT32$DEV_CLUSTER_HI    .EQU    0x000B                  ; cluster start address (LBA): high word
FAT32$DEV_SECT_PER_CLUS .EQU    0x000C                  ; sectors per cluster
FAT32$DEV_RD_1STCLUS_LO .EQU    0x000D                  ; root directory first cluster: low word
FAT32$DEV_RD_1STCLUS_HI .EQU    0x000F                  ; root directory first cluster: high word
FAT32$DEV_AD_1STCLUS_LO .EQU    0x0010                  ; currently active directory first cluster: low word
FAT32$DEV_AD_1STCLUS_HI .EQU    0x0011                  ; currently active directory first cluster: high word

; ========== KEYBOARD ==========

; STATUS REGISTER

KBD$NEW_ASCII           .EQU    0x0001                  ; new ascii character available
KBD$NEW_SPECIAL         .EQU    0x0002                  ; new special key available
KBD$NEW_ANY             .EQU    0x0003                  ; any new key available 

KBD$ASCII               .EQU    0x00FF                  ; mask the special keys
KBD$SPECIAL             .EQU    0xFF00                  ; mask the ascii keys

KBD$LOCALE              .EQU    0x001C                  ; bit mask for checking locales
KBD$LOCALE_US           .EQU    0x0000                  ; default: US keyboard layout
KBD$LOCALE_DE           .EQU    0x0004                  ; DE: German keyboard layout

KBD$MODIFIERS           .EQU    0x00E0                  ; bit mask for checking modifiers
KBD$SHIFT               .EQU    0x0020                  ; modifier "SHIFT" pressed
KBD$ALT                 .EQU    0x0040                  ; modifier "ALT" pressed
KBD$CTRL                .EQU    0x0080                  ; modifier "CTRL" pressed

; READ REGISTER: COMMON ASCII CODES

KBD$SPACE               .EQU    0x0020
KBD$ENTER               .EQU    0x000D
KBD$ESC                 .EQU    0x001B
KBD$TAB                 .EQU    0x0009
KBD$BACKSPACE           .EQU    0x0008

; READ REGISTER: SPECIAL KEYS

KBD$F1                  .EQU    0x0100
KBD$F2                  .EQU    0x0200
KBD$F3                  .EQU    0x0300
KBD$F4                  .EQU    0x0400
KBD$F5                  .EQU    0x0500
KBD$F6                  .EQU    0x0600
KBD$F7                  .EQU    0x0700
KBD$F8                  .EQU    0x0800
KBD$F9                  .EQU    0x0900
KBD$F10                 .EQU    0x0A00
KBD$F11                 .EQU    0x0B00
KBD$F12                 .EQU    0x0C00

KBD$CUR_UP              .EQU    0x1000
KBD$CUR_DOWN            .EQU    0x1100
KBD$CUR_LEFT            .EQU    0x1200
KBD$CUR_RIGHT           .EQU    0x1300
KBD$PG_UP               .EQU    0x1400
KBD$PG_DOWN             .EQU    0x1500
KBD$HOME                .EQU    0x1600
KBD$END                 .EQU    0x1700
KBD$INS                 .EQU    0x1800
KBD$DEL                 .EQU    0x1900

; READ REGISTER: CTRL + character is also mapped to an ASCII code

KBD$CTRL_A              .EQU    0x0001 
KBD$CTRL_B              .EQU    0x0002 
KBD$CTRL_C              .EQU    0x0003 
KBD$CTRL_D              .EQU    0x0004 
KBD$CTRL_E              .EQU    0x0005 
KBD$CTRL_F              .EQU    0x0006 
KBD$CTRL_G              .EQU    0x0007 
KBD$CTRL_H              .EQU    0x0008 
KBD$CTRL_I              .EQU    0x0009 
KBD$CTRL_J              .EQU    0x000A 
KBD$CTRL_K              .EQU    0x000B 
KBD$CTRL_L              .EQU    0x000C 
KBD$CTRL_M              .EQU    0x000D 
KBD$CTRL_N              .EQU    0x000E 
KBD$CTRL_O              .EQU    0x000F 
KBD$CTRL_P              .EQU    0x0010 
KBD$CTRL_Q              .EQU    0x0011 
KBD$CTRL_R              .EQU    0x0012 
KBD$CTRL_S              .EQU    0x0013 
KBD$CTRL_T              .EQU    0x0014 
KBD$CTRL_U              .EQU    0x0015 
KBD$CTRL_V              .EQU    0x0016 
KBD$CTRL_W              .EQU    0x0017 
KBD$CTRL_X              .EQU    0x0018 
KBD$CTRL_Y              .EQU    0x0019 
KBD$CTRL_Z              .EQU    0x001A 

;
;  Useful ASCII constants:
;
CHR$BELL        .EQU 0x0007 ; ASCII-BELL character
CHR$TAB         .EQU 0x0009 ; ASCII-TAB character
CHR$SPACE       .EQU 0x0020 ; ASCII-Space
CHR$CR          .EQU 0x000d ; Carriage return
CHR$LF          .EQU 0x000a ; Line feed

;
;***************************************************************************************
;*  IO-page addresses:
;***************************************************************************************
;
;
;  VGA-registers:
;
VGA$STATE           .EQU 0xFF00 ; VGA status register
    ; Bits 11-10: Hardware scrolling / offset enable: Bit #10 enables the use
    ;             of the offset register #4 (display offset) and bit #11
    ;             enables the use of register #5 (read/write offset).
    ; Bit      9: Busy: VGA is currently busy, e.g. clearing the screen,
    ;             printing, etc. While busy, commands will be ignored, but
    ;             they can still be written into the registers, though
    ; Bit      8: Set bit to clear screen. Read bit to find out, if clear
    ;             screen is still active
    ; Bit      7: VGA enable (1 = on; 0: no VGA signal is generated)
    ; Bit      6: Hardware cursor enable
    ; Bit      5: Hardware cursor blink enable
    ; Bit      4: Hardware cursor mode: 1 - small
    ;                              0 - large
    ; Bits   2-0: Output color for the whole screen, bits (2, 1, 0) = RGB
VGA$CR_X            .EQU 0xFF01 ; VGA cursor X position
VGA$CR_Y            .EQU 0xFF02 ; VGA cursor Y position
VGA$CHAR            .EQU 0xFF03 ; write: VGA character to be displayed
                                ; read: character "under" the cursor
VGA$OFFS_DISPLAY    .EQU 0xFF04 ; Offset in bytes that is used when displaying
                                ; the video RAM. Scrolling forward one line
                                ; means adding 0x50 to this register.
                                ; Only works, if bit #10 in VGA$STATE is set.
VGA$OFFS_RW         .EQU 0xFF05 ; Offset in bytes that is used, when you read
                                ; or write to the video RAM using VGA$CHAR.
                                ; Works independently from VGA$OFFS_DISPLAY.
                                ; Active, when bit #11 in VGA$STATE is set.
;
;  Registers for TIL-display:
;
IO$TIL_DISPLAY  .EQU 0xFF10 ; Address of TIL-display
IO$TIL_MASK     .EQU 0xFF11 ; Mask register of TIL display
;
;  Switch-register:
;
IO$SWITCH_REG   .EQU 0xFF12 ; 16 binary keys
;
;  USB-keyboard-registers:
;
IO$KBD_STATE    .EQU 0xFF13 ; Status register of USB keyboard
;    Bit  0 (read only):      New ASCII character avaiable for reading
;                             (bits 7 downto 0 of Read register)
;    Bit  1 (read only):      New special key available for reading
;                             (bits 15 downto 8 of Read register)
;    Bits 2..4 (read/write):  Locales: 000 = US English keyboard layout,
;                             001 = German layout, others: reserved for more locales
;    Bits 5..7 (read only):   Modifiers: 5 = shift, 6 = alt, 7 = ctrl
;                             Only valid, when bits 0 and/or 1 are '1'
;
IO$KBD_DATA     .EQU 0xFF14 ; Data register of USB keyboard
;    Contains the ASCII character in bits 7 downto 0  or the special key code
;    in 15 downto 0. The "or" is meant exclusive, i.e. it cannot happen that
;    one transmission contains an ASCII character PLUS a special character.
;
;  CYCLE-COUNT-registers       
;
IO$CYC_LO       .EQU 0xFF17     ; low word of 48-bit counter
IO$CYC_MID      .EQU 0xFF18     ; middle word of 48-bit counter
IO$CYC_HI       .EQU 0xFF19     ; high word of 48-bit counter
IO$CYC_STATE    .EQU 0xFF1A     ; status register
;    Bit  0 (write only):     Reset counter to zero and start counting, i.e.
;                             bit 1 is automatically set to 1 when resetting
;    Bit  1 (read/write):     Start/stop counter
;
;  EAE (Extended Arithmetic Element) registers:
;
IO$EAE_OPERAND_0    .EQU    0xFF1B
IO$EAE_OPERAND_1    .EQU    0xFF1C
IO$EAE_RESULT_LO    .EQU    0xFF1D
IO$EAE_RESULT_HI    .EQU    0xFF1E
IO$EAE_CSR          .EQU    0xFF1F ; Command and Status Register
;
;  EAE-Opcodes (CSR):   0x0000  MULU  32-bit result in LO HI
;                       0x0001  MULS  32-bit result in LO HI
;                       0x0002  DIVU  result in LO, modulo in HI
;                       0x0003  DIVS  result in LO, modulo in HI
;  Bit 15 of CSR is the busy bit. If it is set, the EAE is still busy crunching numbers.
;
;
;  UART-registers:
;
IO$UART_SRA     .EQU 0xFF21 ; Status register (relative to base address)
IO$UART_RHRA    .EQU 0xFF22 ; Receiving register (relative to base address)
IO$UART_THRA    .EQU 0xFF23 ; Transmitting register (relative to base address)
;
;  SD CARD INTERFACE registers
;
IO$SD_ADDR_LO   .EQU 0xFF24 ; low word of 32bit linear SD card block address
IO$SD_ADDR_HI   .EQU 0xFF25 ; high word of 32bit linear SD card block address
IO$SD_DATA_POS  .EQU 0xFF26 ; "Cursor" to navigate the 512-byte data buffer
IO$SD_DATA      .EQU 0xFF27 ; read/write 1 byte from/to the 512-byte data buffer
IO$SD_ERROR     .EQU 0xFF28 ; error code of last operation (read only)
IO$SD_CSR       .EQU 0xFF29 ; Command and Status Register (write to execute command)
;
;  SD-Opcodes (CSR):    0x0000  Reset SD card
;                       0x0001  Read 512 bytes from the linear block address
;                       0x0002  Write 512 bytes to the linear block address
;  Bits 0..2 are write-only (reading always returns 0)
;  Bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
;                                      a case, the error code is in IO$SD_ERROR and
;                                      you need to reset the controller to go on
;  Bit 15 of the CSR is the busy bit: 1, if current operation is still running
