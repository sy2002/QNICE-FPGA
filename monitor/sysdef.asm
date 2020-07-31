;;
;;  sysdef.asm: This file contains definitions to simplify assembler programming
;;              and for accessing the various hardware registers via MMIO
;;
;
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
;*  IO-page addresses: Default: 8 registers per block
;***************************************************************************************
;
IO$AREA_START   .EQU 0xFF00
;
;---------------------------------------------------------------------------------------
;  Block FF00: FUNDAMENTAL IO
;---------------------------------------------------------------------------------------
;
;  Switch-register:
;
IO$SWITCH_REG   .EQU 0xFF00 ; 16 binary keys
;
;  Registers for TIL-display:
;
IO$TIL_DISPLAY  .EQU 0xFF01 ; Address of TIL-display
IO$TIL_MASK     .EQU 0xFF02 ; Mask register of TIL display
;
;  USB-keyboard-registers:
;
IO$KBD_STATE    .EQU 0xFF03 ; Status register of USB keyboard
;    Bit  0 (read only):      New ASCII character avaiable for reading
;                             (bits 7 downto 0 of Read register)
;    Bit  1 (read only):      New special key available for reading
;                             (bits 15 downto 8 of Read register)
;    Bits 2..4 (read/write):  Locales: 000 = US English keyboard layout,
;                             001 = German layout, others: reserved for more locales
;    Bits 5..7 (read only):   Modifiers: 5 = shift, 6 = alt, 7 = ctrl
;                             Only valid, when bits 0 and/or 1 are '1'
;
IO$KBD_DATA     .EQU 0xFF04 ; Data register of USB keyboard
;    Contains the ASCII character in bits 7 downto 0  or the special key code
;    in 15 downto 8. The "or" is meant exclusive, i.e. it cannot happen that
;    one transmission contains an ASCII character PLUS a special character.
;
;---------------------------------------------------------------------------------------
;  Block FF08: SYSTEM COUNTERS
;---------------------------------------------------------------------------------------
;
;  CYCLE-COUNT-registers       
;
IO$CYC_LO       .EQU 0xFF08     ; low word of 48-bit counter
IO$CYC_MID      .EQU 0xFF09     ; middle word of 48-bit counter
IO$CYC_HI       .EQU 0xFF0A     ; high word of 48-bit counter
IO$CYC_STATE    .EQU 0xFF0B     ; status register
;    Bit  0 (write only):     Reset counter to zero and start counting, i.e.
;                             bit 1 is automatically set to 1 when resetting
;    Bit  1 (read/write):     Start/stop counter
;
;  INSTRUCTION-COUNT-registers       
;
IO$INS_LO       .EQU 0xFF0C     ; low word of 48-bit counter
IO$INS_MID      .EQU 0xFF0D     ; middle word of 48-bit counter
IO$INS_HI       .EQU 0xFF0E     ; high word of 48-bit counter
IO$INS_STATE    .EQU 0xFF0F     ; status register
;    Bit  0 (write only):     Reset counter to zero and start counting, i.e.
;                             bit 1 is automatically set to 1 when resetting
;    Bit  1 (read/write):     Start/stop counter
;
;---------------------------------------------------------------------------------------
;  Block FF10: UART
;---------------------------------------------------------------------------------------
;
;  QNICE-FPGA supports: IO$UART_SRA, IO$UART_RHRA and IO$UART_THRA 
;  The other registers are mentioned for completeness to map real hardware (16550)
;
IO$UART_MR1A    .EQU 0xFF10 ; n/a
IO$UART_MR1B    .EQU 0xFF10 ; n/a
IO$UART_SRA     .EQU 0xFF11 ; Status register (relative to base address)
IO$UART_RHRA    .EQU 0xFF12 ; Receiving register (relative to base address)
IO$UART_THRA    .EQU 0xFF13 ; Transmitting register (relative to base address)
;
;---------------------------------------------------------------------------------------
;  Block FF18: EAE
;---------------------------------------------------------------------------------------
;
;  EAE (Extended Arithmetic Element) registers:
;
IO$EAE_OPERAND_0    .EQU    0xFF18
IO$EAE_OPERAND_1    .EQU    0xFF19
IO$EAE_RESULT_LO    .EQU    0xFF1A
IO$EAE_RESULT_HI    .EQU    0xFF1B
IO$EAE_CSR          .EQU    0xFF1C ; Command and Status Register
;
;  EAE-Opcodes (CSR):   0x0000  MULU  32-bit result in LO HI
;                       0x0001  MULS  32-bit result in LO HI
;                       0x0002  DIVU  result in LO, modulo in HI
;                       0x0003  DIVS  result in LO, modulo in HI
;  Bit 15 of CSR is the busy bit. If it is set, the EAE is still busy crunching numbers.
;
;---------------------------------------------------------------------------------------
;  Block FF20: SD CARD
;---------------------------------------------------------------------------------------
;
;  SD CARD INTERFACE registers
;
IO$SD_ADDR_LO   .EQU 0xFF20 ; low word of 32bit linear SD card block address
IO$SD_ADDR_HI   .EQU 0xFF21 ; high word of 32bit linear SD card block address
IO$SD_DATA_POS  .EQU 0xFF22 ; "Cursor" to navigate the 512-byte data buffer
IO$SD_DATA      .EQU 0xFF23 ; read/write 1 byte from/to the 512-byte data buffer
IO$SD_ERROR     .EQU 0xFF24 ; error code of last operation (read only)
IO$SD_CSR       .EQU 0xFF25 ; Command and Status Register (write to execute command)
;
;  SD-Opcodes (CSR):    0x0000  Reset SD card
;                       0x0001  Read 512 bytes from the linear block address
;                       0x0002  Write 512 bytes to the linear block address
;  Bits 0 .. 2 are write-only (reading always returns 0)
;  Bits 13 .. 12 return the card type: 00 = no card / unknown card
;                                      01 = SD V1
;                                      10 = SD V2
;                                      11 = SDHC                       
;  Bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
;                                      a case, the error code is in IO$SD_ERROR and
;                                      you need to reset the controller to go on
;  Bit 15 of the CSR is the busy bit: 1, if current operation is still running
;
;---------------------------------------------------------------------------------------
;  Block FF28: TIMER 0 and 1
;---------------------------------------------------------------------------------------
;
;  Interrupt timer: There are four timers capable of generating interrupts.
;                   Each timer is controlled by three 16 bit registers:
;
;  IO$TIMER_x_PRE: The 100 kHz timer clock is divided by the value stored in
;                  this device register. 100 (which corresponds to 0x0064 in
;                  the prescaler register) yields a 1 millisecond pulse which
;                  in turn is fed to the actual counter.
;  IO$TIMER_x_CNT: When the number of output pulses from the prescaler circuit 
;                  equals the number stored in this register, an interrupt will
;                  be generated (if the interrupt address is 0x0000, the
;                  interrupt will be suppressed).
;  IO$TIMER_x_INT: This register contains the address of the desired interrupt 
;                  service routine.
;
IO$TIMER_0_PRE  .EQU 0xFF28
IO$TIMER_0_CNT  .EQU 0xFF29
IO$TIMER_0_INT  .EQU 0xFF2A
IO$TIMER_1_PRE  .EQU 0xFF2B
IO$TIMER_1_CNT  .EQU 0xFF2C
IO$TIMER_1_INT  .EQU 0xFF2D
;
;---------------------------------------------------------------------------------------
;  Block FF30: VGA (double block, 16 registers)
;---------------------------------------------------------------------------------------
;
VGA$STATE           .EQU 0xFF30 ; VGA status register
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
VGA$CR_X            .EQU 0xFF31 ; VGA cursor X position
VGA$CR_Y            .EQU 0xFF32 ; VGA cursor Y position
VGA$CHAR            .EQU 0xFF33 ; write: VGA character to be displayed
                                ; read: character "under" the cursor
VGA$OFFS_DISPLAY    .EQU 0xFF34 ; Offset in bytes that is used when displaying
                                ; the video RAM. Scrolling forward one line
                                ; means adding 0x50 to this register.
                                ; Only works, if bit #10 in VGA$STATE is set.
VGA$OFFS_RW         .EQU 0xFF35 ; Offset in bytes that is used, when you read
                                ; or write to the video RAM using VGA$CHAR.
                                ; Works independently from VGA$OFFS_DISPLAY.
                                ; Active, when bit #11 in VGA$STATE is set.
VGA$HDMI_H_MIN      .EQU 0xFF36 ; HDMI Data Enable: X: minimum valid column
VGA$HDMI_H_MAX      .EQU 0xFF37 ; HDMI Data Enable: X: maximum valid column
VGA$HDMI_V_MAX      .EQU 0xFF38 ; HDMI Data Enable: Y: maximum row (line)                                
;
;---------------------------------------------------------------------------------------
;  Block FFF0: MEGA65 (double block, 16 registers)
;---------------------------------------------------------------------------------------
;
IO$RESERVED_M65     .EQU 0xFFF0 ; RESERVED SPACE FROM 0xFFF0 TO 0xFFFF


;
;***************************************************************************************
;* Constant definitions
;***************************************************************************************
;

; ========== VGA ==========

VGA$MAX_X               .EQU    79                      ; Max. X-coordinate in decimal!
VGA$MAX_Y               .EQU    39                      ; Max. Y-coordinate in decimal!
VGA$MAX_CHARS           .EQU    3200                    ; 80 * 40 chars
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

; ========== CYCLE COUNTER ==========

INS$RESET               .EQU    0x0001                  ; Reset instruction counter
INS$RUN                 .EQU    0x0002                  ; Start/stop counter

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

SD$ERR_MASK             .EQU    0x00FF                  ; AND mask for errors: HI byte = state machine info, so mask it for error checks 
SD$ERR_R1_ERROR         .EQU    0x0001                  ; SD Card R1 error (R1 bit 6-0)
SD$ERR_CRC_OR_TIMEOUT   .EQU    0x0002                  ; Read CRC error or Write Timeout error
SD$ERR_RESPONSE_TOKEN   .EQU    0x0003                  ; Data Response Token error (Token bit 3)
SD$ERR_ERROR_TOKEN      .EQU    0x0004                  ; Data Error Token error (Token bit 3-0)
SD$ERR_WRITE_PROTECT    .EQU    0x0005                  ; SD Card Write Protect switch
SD$ERR_CARD_UNUSABLE    .EQU    0x0006                  ; Unusable SD card
SD$ERR_NO_CARD          .EQU    0x0007                  ; No SD card (no response from CMD0)
SD$ERR_READ_TIMEOUT     .EQU    0x0008                  ; Timeout while trying to receive the read start token "FE"
SD$ERR_TIMEOUT          .EQU    0xEEFF                  ; General timeout

SD$CT_SD_V1             .EQU    0x0001                  ; Card type: SD Version 1
SD$CT_SD_V2             .EQU    0x0002                  ; Card type: SD Version 2
SD$CT_SDHC              .EQU    0x0003                  ; Card type: SDHC (or SDXC)

; ========== FAT32 =============

; FAT32 ERROR CODES

FAT32$ERR_MBR           .EQU    0xEE10                  ; no or illegal Master Boot Record (MBR) found
FAT32$ERR_PARTITION_NO  .EQU    0xEE11                  ; the partition number needs to be in the range 1 .. 4
FAT32$ERR_PARTTBL       .EQU    0xEE12                  ; no or illegal partition table entry found (e.g. no FAT32 partition)
FAT32$ERR_NOTIMPL       .EQU    0xEE13                  ; functionality is not implemented
FAT32$ERR_SIZE          .EQU    0xEE14                  ; partition size or volume size too large (see doc/constraints.txt)
FAT32$ERR_NOFAT32       .EQU    0xEE15                  ; illegal volume id (either not 512 bytes per sector, or not 2 FATs or wrong magic)
FAT32$ERR_ILLEGAL_SIC   .EQU    0xEE16                  ; trying to read/write a sector within a cluster that is out of range
FAT32$ERR_ILLEGAL_CLUS  .EQU    0xEE17                  ; trying to access an illegal cluster number
FAT32$ERR_CORRUPT_DH    .EQU    0xEE18                  ; corrupt directory handle (e.g. because current to-be-read offs > sector size)
FAT32$ERR_DIRNOTFOUND   .EQU    0xEE19                  ; directory not found (illegal path name passed to change directory command)
FAT32$ERR_FILENOTFOUND  .EQU    0xEE20                  ; file not found
FAT23$ERR_SEEKTOOLARGE  .EQU    0xEE21                  ; seek position > file size

; FAT32 STATUS CODES

FAT32$EOF               .EQU    0xEEEE                  ; end of file reached

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
FAT32$DEV_RD_1STCLUS_HI .EQU    0x000E                  ; root directory first cluster: high word
FAT32$DEV_AD_1STCLUS_LO .EQU    0x000F                  ; currently active directory first cluster: low word
FAT32$DEV_AD_1STCLUS_HI .EQU    0x0010                  ; currently active directory first cluster: high word
FAT32$DEV_BUFFERED_FDH  .EQU    0x0011                  ; FDH which is responsible for the current 512 byte hardware buffer filling

FAT32$DEV_STRUCT_SIZE   .EQU    0x0012                  ; size (words) of the mount data structure (device handle)

; LAYOUT OF THE FILE HANDLE AND DIRECTORY HANDLE (FDH)

FAT32$FDH_DEVICE        .EQU    0x0000                  ; pointer to the device handle
FAT32$FDH_CLUSTER_LO    .EQU    0x0001                  ; current cluster (low word)
FAT32$FDH_CLUSTER_HI    .EQU    0x0002                  ; current cluster (high word)
FAT32$FDH_SECTOR        .EQU    0x0003                  ; current sector
FAT32$FDH_INDEX         .EQU    0x0004                  ; current byte index within current sector
FAT32$FDH_SIZE_LO       .EQU    0x0005                  ; only in case FDH is a file: low word of file size, otherwise undefined
FAT32$FDH_SIZE_HI       .EQU    0x0006                  ; only in case FDH is a file: high word of file size, otherwise undefined
FAT32$FDH_READ_LO       .EQU    0x0007                  ; only in case FDH is a file: low word of already read amount of bytes
FAT32$FDH_READ_HI       .EQU    0x0008                  ; only in case FDH is a file: high word of already read amount of bytes

FAT32$FDH_STRUCT_SIZE   .EQU    0x0009                  ; size of the directory handle structure

; FILE ATTRIBUTES

FAT32$FA_READ_ONLY      .EQU    0x0001                  ; read only file
FAT32$FA_HIDDEN         .EQU    0x0002                  ; hidden file
FAT32$FA_SYSTEM         .EQU    0x0004                  ; system file
FAT32$FA_VOLUME_ID      .EQU    0x0008                  ; volume id (name of the volume)
FAT32$FA_DIR            .EQU    0x0010                  ; directory
FAT32$FA_ARCHIVE        .EQU    0x0020                  ; archive flag

FAT32$FA_DEFAULT        .EQU    0x0035                  ; browse for non hidden files and directories but not for the volume id
FAT32$FA_ALL            .EQU    0x0037                  ; browse for all files, but not for the volume id

; LAYOUT OF THE DIRECTORY ENTRY STRUCTURE

FAT32$DE_NAME           .EQU    0x0000                  ; volume, file or directory name, zero terminated (max 256 characters)
FAT32$DE_ATTRIB         .EQU    0x0101                  ; file attributes (read-only, hidden, system, volume id, directory, archive)
FAT32$DE_SIZE_LO        .EQU    0x0102                  ; file size: low word
FAT32$DE_SIZE_HI        .EQU    0x0103                  ; file size: high word
FAT32$DE_YEAR           .EQU    0x0104                  ; last file write: year   (valid range 1980 .. 2107)
FAT32$DE_MONTH          .EQU    0x0105                  ; last file write: month
FAT32$DE_DAY            .EQU    0x0106                  ; last file write: day
FAT32$DE_HOUR           .EQU    0x0107                  ; last file write: hour
FAT32$DE_MINUTE         .EQU    0x0108                  ; last file write: minute
FAT32$DE_SECOND         .EQU    0x0109                  ; last file write: second (in 2 second steps, valid range 0 .. 58)
FAT32$DE_CLUS_LO        .EQU    0x010A                  ; start cluster: low word
FAT32$DE_CLUS_HI        .EQU    0x010B                  ; start cluster: high word

FAT32$DE_STRUCT_SIZE    .EQU    0x010C                  ; size (words) of the directory entry data structure of the

; DISPLAY FLAGS FOR FILE ENTRY PRETTY PRINTER

FAT32$PRINT_SHOW_DIR    .EQU    0x0001                  ; show "<DIR>" indicator
FAT32$PRINT_SHOW_ATTRIB .EQU    0x0002                  ; show attributes as "HRSA"
FAT32$PRINT_SHOW_SIZE   .EQU    0x0004                  ; show file size
FAT32$PRINT_SHOW_DATE   .EQU    0x0008                  ; show file date as YYYY-MM-DD
FAT32$PRINT_SHOW_TIME   .EQU    0x0010                  ; show file time as HH:MM

FAT32$PRINT_DEFAULT     .EQU    0x001D                  ; print <DIR> indicator, size, date and time (no attributes)
FAT32$PRINT_ALL         .EQU    0x001F                  ; print all details

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
