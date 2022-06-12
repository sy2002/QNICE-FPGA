library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package sdcard_globals is

   -- From Part1_Physical_Layer_Simplified_Specification_Ver8.00.pdf,
   -- Section 4.7.4 Detail Command Description, Page 117

   -- Class 0 Basic Commands                              -- Expected response:
   constant CMD_GO_IDLE_STATE            : natural :=  0; -- none
   constant CMD_ALL_SEND_CID             : natural :=  2; -- R2
   constant CMD_SEND_RELATIVE_ADDR       : natural :=  3; -- R6
   constant CMD_SET_DSR                  : natural :=  4; -- none
   constant CMD_SELECT_CARD              : natural :=  7; -- R1b
   constant CMD_SEND_IF_COND             : natural :=  8; -- R7 or none
   constant CMD_SEND_CSD                 : natural :=  9; -- R2
   constant CMD_SEND_CID                 : natural := 10; -- R2
   constant CMD_VOLTAGE_SWITCH           : natural := 11; -- R1
   constant CMD_STOP_TRANSMISSION        : natural := 12; -- R1b
   constant CMD_SEND_STATUS              : natural := 13; -- R1
   constant CMD_GO_INACTIVE_STATE        : natural := 15; -- none

   -- Class 2 and 4 Block Commands                        -- Expected response:
   constant CMD_SET_BLOCKLEN             : natural := 16; -- R1
   constant CMD_READ_SINGLE_BLOCK        : natural := 17; -- R1
   constant CMD_READ_MULTIPLE_BLOCK      : natural := 18; -- R1
   constant CMD_SET_TUNING_BLOCK         : natural := 19; -- R1
   constant CMD_SPEED_CLASS_CONTROL      : natural := 20; -- R1b
   constant CMD_ADDRESS_EXTENSION        : natural := 22; -- R1
   constant CMD_SET_BLOCK_COUNT          : natural := 23; -- R1
   constant CMD_WRITE_BLOCK              : natural := 24; -- R1
   constant CMD_WRITE_MULTIPLE_BLOCK     : natural := 25; -- R1
   constant CMD_PROGRAM_CSD              : natural := 27; -- R1

   -- Class 6 Write Protection Commands                   -- Expected response:
   constant CMD_SET_WRITE_PROT           : natural := 28; -- R1b
   constant CMD_CLR_WRITE_PROT           : natural := 29; -- R1b
   constant CMD_SEND_WRITE_PROT          : natural := 30; -- R1

   -- Class 5 Erase Commands                              -- Expected response:
   constant CMD_ERASE_WR_BLK_START       : natural := 32; -- R1
   constant CMD_ERASE_WR_BLK_END         : natural := 33; -- R1
   constant CMD_ERASE                    : natural := 38; -- R1b

   -- Class 8 Application Specific Commands               -- Expected response:
   constant CMD_APP_CMD                  : natural := 55; -- R1
   constant CMD_GEN_CMD                  : natural := 56; -- R1

   -- Class 10 Switch Function Commands                   -- Expected response:
   constant CMD_SWITCH_FUNC              : natural :=  6; -- R1

   -- Application Specific Commands                       -- Expected response:
   constant ACMD_SET_BUS_WIDTH           : natural :=  6; -- R1
   constant ACMD_SD_STATUS               : natural := 13; -- R1
   constant ACMD_SET_NUM_WR_BLOCKS       : natural := 22; -- R1
   constant ACMD_SET_WR_BLK_ERASE_COUNT  : natural := 23; -- R1
   constant ACMD_SD_SEND_OP_COND         : natural := 41; -- R3
   constant ACMD_SET_CLR_CARD_DETECT     : natural := 42; -- R1
   constant ACMD_SEND_SCR                : natural := 51; -- R1


   -- Section 4.3.13, Page 105
   -- Response R7
   subtype  CMD8_1_2V                 is natural range  13 downto  13;  -- PCIe 1.2V Support
   subtype  CMD8_PCIE                 is natural range  12 downto  12;  -- PCIe Availability
   subtype  CMD8_VHS                  is natural range  11 downto   8;  -- Supply Voltage
   subtype  CMD8_CHECK                is natural range   7 downto   0;  -- Check pattern
   constant CMD8_VHS_27_36             : std_logic_vector(3 downto 0) := "0001";
   constant CMD8_VHS_LOW               : std_logic_vector(3 downto 0) := "0010";

   subtype  CMD_RCA                   is natural range  31 downto  16;  -- RCA
   constant CMD_RCA_DEFAULT            : std_logic_vector(31 downto 16) := (others => '0');

   subtype  ACMD6_BUS_WIDTH           is natural range   1 downto   0;
   constant ACMD6_BUS_WIDTH_1          : std_logic_vector(1 downto 0) := "00";
   constant ACMD6_BUS_WIDTH_4          : std_logic_vector(1 downto 0) := "10";



   -- From Part1_Physical_Layer_Simplified_Specification_Ver8.00.pdf,
   -- Section 4.9 Responses, Page 131
   constant RESP_R1_LEN                  : natural :=  48;  -- Normal response
   constant RESP_R2_LEN                  : natural := 136;  -- CID, CSD register
   constant RESP_R3_LEN                  : natural :=  48;  -- OCR register
   constant RESP_R6_LEN                  : natural :=  48;  -- Published RCA response
   constant RESP_R7_LEN                  : natural :=  48;  -- Card interface condition


   -- From Part1_Physical_Layer_Simplified_Specification_Ver8.00.pdf,
   -- Section 4.10.1 Card Status, Page 134
   subtype  R_CMD_INDEX                 is natural range 39 downto 32;
   constant CARD_STAT_OUT_OF_RANGE       : natural := 31;
   constant CARD_STAT_ADDRESS_ERROR      : natural := 30;
   constant CARD_STAT_BLOCK_LEN_ERROR    : natural := 29;
   constant CARD_STAT_ERASE_SEQ_ERROR    : natural := 28;
   constant CARD_STAT_ERASE_PARAM        : natural := 27;
   constant CARD_STAT_WP_VIOLATION       : natural := 26;
   constant CARD_STAT_CARD_IS_LOCKED     : natural := 25;
   constant CARD_STAT_LOCK_UNLOCK_FAILED : natural := 24;
   constant CARD_STAT_COM_CRC_ERROR      : natural := 23;
   constant CARD_STAT_ILLEGAL_COMMAND    : natural := 22;
   constant CARD_STAT_CARD_ECC_FAILED    : natural := 21;
   constant CARD_STAT_CC_ERROR           : natural := 20;
   constant CARD_STAT_ERROR              : natural := 19;
   constant CARD_STAT_CSD_OVERWRITE      : natural := 16;
   constant CARD_STAT_WP_ERASE_SKIP      : natural := 15;
   constant CARD_STAT_CARD_ECC_DISABED   : natural := 14;
   constant CARD_STAT_ERASE_RESET        : natural := 13;
   subtype  CARD_STAT_CURRENT_STATE     is natural range 12 downto 9;
   constant CARD_STAT_READY_FOR_DATA     : natural :=  8;
   constant CARD_STAT_FX_EVENT           : natural :=  6;
   constant CARD_STAT_APP_CMD            : natural :=  5;
   constant CARD_STAT_AKE_SEQ_ERROR      : natural :=  3;

   constant CARD_STATE_IDLE  : std_logic_vector(3 downto 0) := X"0";
   constant CARD_STATE_READY : std_logic_vector(3 downto 0) := X"1";
   constant CARD_STATE_IDENT : std_logic_vector(3 downto 0) := X"2";
   constant CARD_STATE_STBY  : std_logic_vector(3 downto 0) := X"3";
   constant CARD_STATE_TRAN  : std_logic_vector(3 downto 0) := X"4";
   constant CARD_STATE_DATA  : std_logic_vector(3 downto 0) := X"5";
   constant CARD_STATE_RCV   : std_logic_vector(3 downto 0) := X"6";
   constant CARD_STATE_PRG   : std_logic_vector(3 downto 0) := X"7";
   constant CARD_STATE_DIS   : std_logic_vector(3 downto 0) := X"8";


   -- From Part1_Physical_Layer_Simplified_Specification_Ver8.00.pdf,
   -- Section 5 Card Registers, Page 204

   -- Response R2
   subtype  R2_CID                    is natural range 127 downto   0;
   subtype  CID_MID                   is natural range 127 downto 120;  -- Manufacturer ID
   subtype  CID_OID                   is natural range 119 downto 104;  -- OEM/Application ID
   subtype  CID_PNM                   is natural range 103 downto  64;  -- Product name
   subtype  CID_PRV                   is natural range  63 downto  56;  -- Product revision
   subtype  CID_PSN                   is natural range  55 downto  24;  -- Product serial number
   subtype  CID_MDT                   is natural range  19 downto   8;  -- Manufacturing date
   subtype  CID_CRC                   is natural range   7 downto   1;  -- CRC7 checksum

   -- Response R2
   subtype  R2_CSD                    is natural range 127 downto   0;
   subtype  CSD_CSD_STRUCTURE         is natural range 127 downto 126;  -- CSD structure
   subtype  CSD_TAAC                  is natural range 119 downto 112;  -- data read access-time-1
   subtype  CSD_NSAC                  is natural range 111 downto 104;  -- data read access-time-2
   subtype  CSD_TRAN_SPEED            is natural range 103 downto  96;  -- max. data transfer rate
   subtype  CSD_CCC                   is natural range  95 downto  84;  -- card command classes
   subtype  CSD_READ_BL_LEN           is natural range  83 downto  80;  -- max. read data block length
   subtype  CSD_READ_BL_PARTIAL       is natural range  79 downto  79;  -- partial blocks for read allowed
   subtype  CSD_WRITE_BLK_MISALIGN    is natural range  78 downto  78;  -- write block misalignment
   subtype  CSD_READ_BLK_MISALIGN     is natural range  77 downto  77;  -- read block misalignment
   subtype  CSD_DSR_IMP               is natural range  76 downto  76;  -- DSR implemented
   subtype  CSD_C_SIZE                is natural range  73 downto  62;  -- device size
   subtype  CSD_VDD_R_CURR_MIN        is natural range  61 downto  59;  -- max. read current @ VDD min
   subtype  CSD_VDD_R_CURR_MAX        is natural range  58 downto  56;  -- max. read current @ VDD max
   subtype  CSD_VDD_W_CURR_MIN        is natural range  55 downto  53;  -- max. write current @ VDD min
   subtype  CSD_VDD_W_CURR_MAX        is natural range  52 downto  50;  -- max. write current @ VDD max
   subtype  CSD_C_SIZE_MULT           is natural range  49 downto  47;  -- device size multiplier
   subtype  CSD_ERASE_BLK_EN          is natural range  46 downto  46;  -- erase single block enable
   subtype  CSD_SECTOR_SIZE           is natural range  45 downto  39;  -- erase sector size
   subtype  CSD_WP_GRP_SIZE           is natural range  38 downto  32;  -- write protect group size
   subtype  CSD_WP_GRP_ENABLE         is natural range  31 downto  31;  -- write protect group enable
   subtype  CSD_R2W_FACTOR            is natural range  28 downto  26;  -- write speed factor
   subtype  CSD_WRITE_BL_LEN          is natural range  25 downto  22;  -- max. write data block length
   subtype  CSD_WRITE_BL_PARTIAL      is natural range  21 downto  21;  -- partial blocks for write allowed
   subtype  CSD_FILE_FORMAT_GRP       is natural range  15 downto  15;  -- File format group
   subtype  CSD_COPY                  is natural range  14 downto  14;  -- copy flag
   subtype  CSD_PERM_WRITE_PROTECT    is natural range  13 downto  13;  -- permanent write protection
   subtype  CSD_TMP_WRITE_PROTECT     is natural range  12 downto  12;  -- temporary write protection
   subtype  CSD_FILE_FORMAT           is natural range  11 downto  10;  -- File format
   subtype  CSD_CRC                   is natural range   7 downto   1;  -- CRC

   -- Response R3 and ACMD41
   constant OCR_27X                    : natural := 15;
   constant OCR_28X                    : natural := 16;
   constant OCR_29X                    : natural := 17;
   constant OCR_30X                    : natural := 18;
   constant OCR_31X                    : natural := 19;
   constant OCR_32X                    : natural := 20;
   constant OCR_33X                    : natural := 21;
   constant OCR_34X                    : natural := 22;
   constant OCR_35X                    : natural := 23;
   constant OCR_S18A                   : natural := 24; -- Switching to 1.8V Accepted
   constant OCR_CO2T                   : natural := 27; -- Over 2TB support Status
   constant OCR_UHSII                  : natural := 29; -- UHS-II Card Status
   constant OCR_CCS                    : natural := 30; -- Card Capacity Status
   constant OCR_BUSY                   : natural := 31; -- Card power up status bit

   -- Response R6
   subtype  R6_RCA                    is natural range  31 downto  16;  -- RCA
   constant R6_STAT_COM_CRC_ERROR      : natural := 15;
   constant R6_STAT_ILLEGAL_COMMAND    : natural := 14;
   constant R6_STAT_ERROR              : natural := 13;
   subtype  R6_STAT_CURRENT_STATE     is natural range 12 downto 9;
   constant R6_STAT_READY_FOR_DATA     : natural :=  8;
   constant R6_STAT_FX_EVENT           : natural :=  6;
   constant R6_STAT_APP_CMD            : natural :=  5;
   constant R6_STAT_AKE_SEQ_ERROR      : natural :=  3;

   subtype  SCR_SCR_STRUCTURE         is natural range  63 downto  60;  -- SCR Structure
   subtype  SCR_SD_SPEC               is natural range  59 downto  56;  -- SD Memory Card - Spec. Version
   subtype  SCR_DATA_STAT_AFTER_ERASE is natural range  55 downto  55;  -- data_status_after erases
   subtype  SCR_SD_SECURITY           is natural range  54 downto  52;  -- CPRM Security Support
   subtype  SCR_SD_BUS_WIDTHS         is natural range  51 downto  48;  -- DAT Bus widths supported
   subtype  SCR_SD_SPEC3              is natural range  47 downto  47;  -- Spec. Version 3.00 or higher
   subtype  SCR_EX_SECURITY           is natural range  46 downto  43;  -- Extended Security Support
   subtype  SCR_SD_SPEC4              is natural range  42 downto  42;  -- Spec. Version 4.00 or higher
   subtype  SCR_SD_SPECX              is natural range  41 downto  38;  -- Spec. Version 5.00 or higher
   subtype  SCR_CMD_SUPPORT           is natural range  35 downto  32;  -- Command Support bits

end package sdcard_globals;

