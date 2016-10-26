//;
//;  sysdef.asm: This file contains definitions to simplify assembler programming
//;              and for accessing the various hardware registers via MMIO
//;

//
//***************************************************************************************
//*  Assembler macros which make life much easier:
//***************************************************************************************
//


//
//  Some register short names:
//

//
//***************************************************************************************
//* Constant definitions
//***************************************************************************************
//

// ========== VGA ==========

#define VGA$MAX_X              	79                      // Max. X-coordinate in decimal!
#define VGA$MAX_Y              	39                      // Max. Y-coordinate in decimal!
#define VGA$MAX_CHARS          	3200                    // VGA$MAX_X * VGA$MAX_Y
#define VGA$CHARS_PER_LINE     	80  

#define VGA$EN_HW_CURSOR       	0x0040                  // Show hardware cursor
#define VGA$EN_HW_SCRL         	0x0C00                  // Hardware scrolling enable
#define VGA$CLR_SCRN           	0x0100                  // Clear screen
#define VGA$BUSY               	0x0200                  // VGA is currently performing a task

#define VGA$COLOR_RED          	0x0004
#define VGA$COLOR_GREEN        	0x0002
#define VGA$COLOR_BLUE         	0x0001
#define VGA$COLOR_WHITE        	0x0007

// ========== CYCLE COUNTER ==========

#define CYC$RESET              	0x0001                  // Reset cycle counter
#define CYC$RUN                	0x0002                  // Start/stop counter

// ========== EAE ==========

#define EAE$MULU               	0x0000                  // Unsigned 16 bit multiplication
#define EAE$MULS               	0x0001                  // Signed 16 bit multiplication
#define EAE$DIVU               	0x0002                  // Unsigned 16 bit division with remainder
#define EAE$DIVS               	0x0003                  // Signed 16 bit division with remainder
#define EAE$BUSY               	0x8000                  // Busy flag (1 = operation still running)

// ========== SD CARD ==========

#define SD$CMD_RESET           	0x0000                  // Reset SD card
#define SD$CMD_READ            	0x0001                  // Read 512 bytes from SD to internal buffer
#define SD$CMD_WRITE           	0x0002                  // Write 512 bytes from int. buf. to SD
#define SD$BIT_ERROR           	0x4000                  // Error flag: 1, if last operation failed
#define SD$BIT_BUSY            	0x8000                  // Busy flag: 1, if current op. is still running
#define SD$TIMEOUT_MID         	0x0479                  // equals ~75.000.000 cycles, i.e. 1.5sec @ 50 MHz

#define SD$ERR_MASK            	0x00FF                  // AND mask for errors: HI byte = state machine info, so mask it for error checks 
#define SD$ERR_R1_ERROR        	0x0001                  // SD Card R1 error (R1 bit 6-0)
#define SD$ERR_CRC_OR_TIMEOUT  	0x0002                  // Read CRC error or Write Timeout error
#define SD$ERR_RESPONSE_TOKEN  	0x0003                  // Data Response Token error (Token bit 3)
#define SD$ERR_ERROR_TOKEN     	0x0004                  // Data Error Token error (Token bit 3-0)
#define SD$ERR_WRITE_PROTECT   	0x0005                  // SD Card Write Protect switch
#define SD$ERR_CARD_UNUSABLE   	0x0006                  // Unusable SD card
#define SD$ERR_NO_CARD         	0x0007                  // No SD card (no response from CMD0)
#define SD$ERR_READ_TIMEOUT    	0x0008                  // Timeout while trying to receive the read start token "FE"
#define SD$ERR_TIMEOUT         	0xEEFF                  // General timeout

#define SD$CT_SD_V1            	0x0001                  // Card type: SD Version 1
#define SD$CT_SD_V2            	0x0002                  // Card type: SD Version 2
#define SD$CT_SDHC             	0x0003                  // Card type: SDHC (or SDXC)

// ========== FAT32 =============

// FAT32 ERROR CODES

#define FAT32$ERR_MBR          	0xEE10                  // no or illegal Master Boot Record (MBR) found
#define FAT32$ERR_PARTITION_NO 	0xEE11                  // the partition number needs to be in the range 1 .. 4
#define FAT32$ERR_PARTTBL      	0xEE12                  // no or illegal partition table entry found (e.g. no FAT32 partition)
#define FAT32$ERR_NOTIMPL      	0xEE13                  // functionality is not implemented
#define FAT32$ERR_SIZE         	0xEE14                  // partition size or volume size too large (see doc/constraints.txt)
#define FAT32$ERR_NOFAT32      	0xEE15                  // illegal volume id (either not 512 bytes per sector, or not 2 FATs or wrong magic)
#define FAT32$ERR_ILLEGAL_SIC  	0xEE16                  // trying to read/write a sector within a cluster that is out of range
#define FAT32$ERR_ILLEGAL_CLUS 	0xEE17                  // trying to access an illegal cluster number
#define FAT32$ERR_CORRUPT_DH   	0xEE18                  // corrupt directory handle (e.g. because current to-be-read offs > sector size)
#define FAT32$ERR_DIRNOTFOUND  	0xEE19                  // directory not found (illegal path name passed to change directory command)
#define FAT32$ERR_FILENOTFOUND 	0xEE20                  // file not found
#define FAT23$ERR_SEEKTOOLARGE 	0xEE21                  // seek position > file size

// FAT32 STATUS CODES

#define FAT32$EOF              	0xEEEE                  // end of file reached

// LAYOUT OF THE MOUNT DATA STRUCTURE (DEVICE HANDLE)

#define FAT32$DEV_RESET        	0x0000                  // pointer to device reset function
#define FAT32$DEV_BLOCK_READ   	0x0001                  // pointer to 512-byte block read function
#define FAT32$DEV_BLOCK_WRITE  	0x0002                  // pointer to 512-byte block write function
#define FAT32$DEV_BYTE_READ    	0x0003                  // pointer to 1-byte read function (within block buffer)
#define FAT32$DEV_BYTE_WRITE   	0x0004                  // pointer to 1-byte write function (within block buffer)
#define FAT32$DEV_PARTITION    	0x0005                  // number of partition to be mounted
#define FAT32$DEV_FS_LO        	0x0006                  // file system start address (LBA): low word
#define FAT32$DEV_FS_HI        	0x0007                  // file system start address (LBA): high word
#define FAT32$DEV_FAT_LO       	0x0008                  // fat start address (LBA): low word
#define FAT32$DEV_FAT_HI       	0x0009                  // fat start address (LBA): high word
#define FAT32$DEV_CLUSTER_LO   	0x000A                  // cluster start address (LBA): low word
#define FAT32$DEV_CLUSTER_HI   	0x000B                  // cluster start address (LBA): high word
#define FAT32$DEV_SECT_PER_CLUS	0x000C                  // sectors per cluster
#define FAT32$DEV_RD_1STCLUS_LO	0x000D                  // root directory first cluster: low word
#define FAT32$DEV_RD_1STCLUS_HI	0x000E                  // root directory first cluster: high word
#define FAT32$DEV_AD_1STCLUS_LO	0x000F                  // currently active directory first cluster: low word
#define FAT32$DEV_AD_1STCLUS_HI	0x0010                  // currently active directory first cluster: high word

#define FAT32$DEV_STRUCT_SIZE  	0x0011                  // size (words) of the mount data structure (device handle)

// LAYOUT OF THE FILE HANDLE AND DIRECTORY HANDLE (FDH)

#define FAT32$FDH_DEVICE       	0x0000                  // pointer to the device handle
#define FAT32$FDH_CLUSTER_LO   	0x0001                  // current cluster (low word)
#define FAT32$FDH_CLUSTER_HI   	0x0002                  // current cluster (high word)
#define FAT32$FDH_SECTOR       	0x0003                  // current sector
#define FAT32$FDH_INDEX        	0x0004                  // current byte index within current sector
#define FAT32$FDH_SIZE_LO      	0x0005                  // only in case FDH is a file: low word of file size, otherwise undefined
#define FAT32$FDH_SIZE_HI      	0x0006                  // only in case FDH is a file: high word of file size, otherwise undefined
#define FAT32$FDH_READ_LO      	0x0007                  // only in case FDH is a file: low word of already read amount of bytes
#define FAT32$FDH_READ_HI      	0x0008                  // only in case FDH is a file: high word of already read amount of bytes

#define FAT32$FDH_STRUCT_SIZE  	0x0009                  // size of the directory handle structure

// FILE ATTRIBUTES

#define FAT32$FA_READ_ONLY     	0x0001                  // read only file
#define FAT32$FA_HIDDEN        	0x0002                  // hidden file
#define FAT32$FA_SYSTEM        	0x0004                  // system file
#define FAT32$FA_VOLUME_ID     	0x0008                  // volume id (name of the volume)
#define FAT32$FA_DIR           	0x0010                  // directory
#define FAT32$FA_ARCHIVE       	0x0020                  // archive flag

#define FAT32$FA_DEFAULT       	0x0035                  // browse for non hidden files and directories but not for the volume id
#define FAT32$FA_ALL           	0x0037                  // browse for all files, but not for the volume id

// LAYOUT OF THE DIRECTORY ENTRY STRUCTURE

#define FAT32$DE_NAME          	0x0000                  // volume, file or directory name, zero terminated (max 256 characters)
#define FAT32$DE_ATTRIB        	0x0101                  // file attributes (read-only, hidden, system, volume id, directory, archive)
#define FAT32$DE_SIZE_LO       	0x0102                  // file size: low word
#define FAT32$DE_SIZE_HI       	0x0103                  // file size: high word
#define FAT32$DE_YEAR          	0x0104                  // last file write: year   (valid range 1980 .. 2107)
#define FAT32$DE_MONTH         	0x0105                  // last file write: month
#define FAT32$DE_DAY           	0x0106                  // last file write: day
#define FAT32$DE_HOUR          	0x0107                  // last file write: hour
#define FAT32$DE_MINUTE        	0x0108                  // last file write: minute
#define FAT32$DE_SECOND        	0x0109                  // last file write: second (in 2 second steps, valid range 0 .. 58)
#define FAT32$DE_CLUS_LO       	0x010A                  // start cluster: low word
#define FAT32$DE_CLUS_HI       	0x010B                  // start cluster: high word

#define FAT32$DE_STRUCT_SIZE   	0x010C                  // size (words) of the directory entry data structure of the

// DISPLAY FLAGS FOR FILE ENTRY PRETTY PRINTER

#define FAT32$PRINT_SHOW_DIR   	0x0001                  // show "<DIR>" indicator
#define FAT32$PRINT_SHOW_ATTRIB	0x0002                  // show attributes as "HRSA"
#define FAT32$PRINT_SHOW_SIZE  	0x0004                  // show file size
#define FAT32$PRINT_SHOW_DATE  	0x0008                  // show file date as YYYY-MM-DD
#define FAT32$PRINT_SHOW_TIME  	0x0010                  // show file time as HH:MM

#define FAT32$PRINT_DEFAULT    	0x001D                  // print <DIR> indicator, size, date and time (no attributes)
#define FAT32$PRINT_ALL        	0x001F                  // print all details

// ========== KEYBOARD ==========

// STATUS REGISTER

#define KBD$NEW_ASCII          	0x0001                  // new ascii character available
#define KBD$NEW_SPECIAL        	0x0002                  // new special key available
#define KBD$NEW_ANY            	0x0003                  // any new key available 

#define KBD$ASCII              	0x00FF                  // mask the special keys
#define KBD$SPECIAL            	0xFF00                  // mask the ascii keys

#define KBD$LOCALE             	0x001C                  // bit mask for checking locales
#define KBD$LOCALE_US          	0x0000                  // default: US keyboard layout
#define KBD$LOCALE_DE          	0x0004                  // DE: German keyboard layout

#define KBD$MODIFIERS          	0x00E0                  // bit mask for checking modifiers
#define KBD$SHIFT              	0x0020                  // modifier "SHIFT" pressed
#define KBD$ALT                	0x0040                  // modifier "ALT" pressed
#define KBD$CTRL               	0x0080                  // modifier "CTRL" pressed

// READ REGISTER: COMMON ASCII CODES

#define KBD$SPACE              	0x0020
#define KBD$ENTER              	0x000D
#define KBD$ESC                	0x001B
#define KBD$TAB                	0x0009
#define KBD$BACKSPACE          	0x0008

// READ REGISTER: SPECIAL KEYS

#define KBD$F1                 	0x0100
#define KBD$F2                 	0x0200
#define KBD$F3                 	0x0300
#define KBD$F4                 	0x0400
#define KBD$F5                 	0x0500
#define KBD$F6                 	0x0600
#define KBD$F7                 	0x0700
#define KBD$F8                 	0x0800
#define KBD$F9                 	0x0900
#define KBD$F10                	0x0A00
#define KBD$F11                	0x0B00
#define KBD$F12                	0x0C00

#define KBD$CUR_UP             	0x1000
#define KBD$CUR_DOWN           	0x1100
#define KBD$CUR_LEFT           	0x1200
#define KBD$CUR_RIGHT          	0x1300
#define KBD$PG_UP              	0x1400
#define KBD$PG_DOWN            	0x1500
#define KBD$HOME               	0x1600
#define KBD$END                	0x1700
#define KBD$INS                	0x1800
#define KBD$DEL                	0x1900

// READ REGISTER: CTRL + character is also mapped to an ASCII code

#define KBD$CTRL_A             	0x0001 
#define KBD$CTRL_B             	0x0002 
#define KBD$CTRL_C             	0x0003 
#define KBD$CTRL_D             	0x0004 
#define KBD$CTRL_E             	0x0005 
#define KBD$CTRL_F             	0x0006 
#define KBD$CTRL_G             	0x0007 
#define KBD$CTRL_H             	0x0008 
#define KBD$CTRL_I             	0x0009 
#define KBD$CTRL_J             	0x000A 
#define KBD$CTRL_K             	0x000B 
#define KBD$CTRL_L             	0x000C 
#define KBD$CTRL_M             	0x000D 
#define KBD$CTRL_N             	0x000E 
#define KBD$CTRL_O             	0x000F 
#define KBD$CTRL_P             	0x0010 
#define KBD$CTRL_Q             	0x0011 
#define KBD$CTRL_R             	0x0012 
#define KBD$CTRL_S             	0x0013 
#define KBD$CTRL_T             	0x0014 
#define KBD$CTRL_U             	0x0015 
#define KBD$CTRL_V             	0x0016 
#define KBD$CTRL_W             	0x0017 
#define KBD$CTRL_X             	0x0018 
#define KBD$CTRL_Y             	0x0019 
#define KBD$CTRL_Z             	0x001A 

//
//  Useful ASCII constants:
//
#define CHR$BELL       	0x0007 // ASCII-BELL character
#define CHR$TAB        	0x0009 // ASCII-TAB character
#define CHR$SPACE      	0x0020 // ASCII-Space
#define CHR$CR         	0x000d // Carriage return
#define CHR$LF         	0x000a // Line feed

//
//***************************************************************************************
//*  IO-page addresses:
//***************************************************************************************
//
//
//  VGA-registers:
//
#define VGA$STATE          	0xFF00 // VGA status register
    // Bits 11-10: Hardware scrolling / offset enable: Bit #10 enables the use
    //             of the offset register #4 (display offset) and bit #11
    //             enables the use of register #5 (read/write offset).
    // Bit      9: Busy: VGA is currently busy, e.g. clearing the screen,
    //             printing, etc. While busy, commands will be ignored, but
    //             they can still be written into the registers, though
    // Bit      8: Set bit to clear screen. Read bit to find out, if clear
    //             screen is still active
    // Bit      7: VGA enable (1 = on; 0: no VGA signal is generated)
    // Bit      6: Hardware cursor enable
    // Bit      5: Hardware cursor blink enable
    // Bit      4: Hardware cursor mode: 1 - small
    //                              0 - large
    // Bits   2-0: Output color for the whole screen, bits (2, 1, 0) = RGB
#define VGA$CR_X           	0xFF01 // VGA cursor X position
#define VGA$CR_Y           	0xFF02 // VGA cursor Y position
#define VGA$CHAR           	0xFF03 // write: VGA character to be displayed
                                // read: character "under" the cursor
#define VGA$OFFS_DISPLAY   	0xFF04 // Offset in bytes that is used when displaying
                                // the video RAM. Scrolling forward one line
                                // means adding 0x50 to this register.
                                // Only works, if bit #10 in VGA$STATE is set.
#define VGA$OFFS_RW        	0xFF05 // Offset in bytes that is used, when you read
                                // or write to the video RAM using VGA$CHAR.
                                // Works independently from VGA$OFFS_DISPLAY.
                                // Active, when bit #11 in VGA$STATE is set.
//
//  Registers for TIL-display:
//
#define IO$TIL_DISPLAY 	0xFF10 // Address of TIL-display
#define IO$TIL_MASK    	0xFF11 // Mask register of TIL display
//
//  Switch-register:
//
#define IO$SWITCH_REG  	0xFF12 // 16 binary keys
//
//  USB-keyboard-registers:
//
#define IO$KBD_STATE   	0xFF13 // Status register of USB keyboard
//    Bit  0 (read only):      New ASCII character avaiable for reading
//                             (bits 7 downto 0 of Read register)
//    Bit  1 (read only):      New special key available for reading
//                             (bits 15 downto 8 of Read register)
//    Bits 2..4 (read/write):  Locales: 000 = US English keyboard layout,
//                             001 = German layout, others: reserved for more locales
//    Bits 5..7 (read only):   Modifiers: 5 = shift, 6 = alt, 7 = ctrl
//                             Only valid, when bits 0 and/or 1 are '1'
//
#define IO$KBD_DATA    	0xFF14 // Data register of USB keyboard
//    Contains the ASCII character in bits 7 downto 0  or the special key code
//    in 15 downto 0. The "or" is meant exclusive, i.e. it cannot happen that
//    one transmission contains an ASCII character PLUS a special character.
//
//  CYCLE-COUNT-registers       
//
#define IO$CYC_LO      	0xFF17     // low word of 48-bit counter
#define IO$CYC_MID     	0xFF18     // middle word of 48-bit counter
#define IO$CYC_HI      	0xFF19     // high word of 48-bit counter
#define IO$CYC_STATE   	0xFF1A     // status register
//    Bit  0 (write only):     Reset counter to zero and start counting, i.e.
//                             bit 1 is automatically set to 1 when resetting
//    Bit  1 (read/write):     Start/stop counter
//
//  EAE (Extended Arithmetic Element) registers:
//
#define IO$EAE_OPERAND_0   	0xFF1B
#define IO$EAE_OPERAND_1   	0xFF1C
#define IO$EAE_RESULT_LO   	0xFF1D
#define IO$EAE_RESULT_HI   	0xFF1E
#define IO$EAE_CSR         	0xFF1F // Command and Status Register
//
//  EAE-Opcodes (CSR):   0x0000  MULU  32-bit result in LO HI
//                       0x0001  MULS  32-bit result in LO HI
//                       0x0002  DIVU  result in LO, modulo in HI
//                       0x0003  DIVS  result in LO, modulo in HI
//  Bit 15 of CSR is the busy bit. If it is set, the EAE is still busy crunching numbers.
//
//
//  UART-registers:
//
#define IO$UART_SRA    	0xFF21 // Status register (relative to base address)
#define IO$UART_RHRA   	0xFF22 // Receiving register (relative to base address)
#define IO$UART_THRA   	0xFF23 // Transmitting register (relative to base address)
//
//  SD CARD INTERFACE registers
//
#define IO$SD_ADDR_LO  	0xFF24 // low word of 32bit linear SD card block address
#define IO$SD_ADDR_HI  	0xFF25 // high word of 32bit linear SD card block address
#define IO$SD_DATA_POS 	0xFF26 // "Cursor" to navigate the 512-byte data buffer
#define IO$SD_DATA     	0xFF27 // read/write 1 byte from/to the 512-byte data buffer
#define IO$SD_ERROR    	0xFF28 // error code of last operation (read only)
#define IO$SD_CSR      	0xFF29 // Command and Status Register (write to execute command)
//
//  SD-Opcodes (CSR):    0x0000  Reset SD card
//                       0x0001  Read 512 bytes from the linear block address
//                       0x0002  Write 512 bytes to the linear block address
//  Bits 0..2 are write-only (reading always returns 0)
//  Bit 14 of the CSR is the error bit: 1, if the last operation failed. In such
//                                      a case, the error code is in IO$SD_ERROR and
//                                      you need to reset the controller to go on
//  Bit 15 of the CSR is the busy bit: 1, if current operation is still running
