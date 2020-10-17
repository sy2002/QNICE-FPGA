;=
;;=========================================================================================
;; Since the current memory layout has ROM in 0x0000 .. 0x7FFF and RAM in 
;; 0x8000 .. 0xFFFF, we need some space for variables used by the monitor in the upper
;; RAM. 
;;
;; These memory locations are defined in the following and have to be located directly 
;; below the IO-page which itself starts on 0xFF00. So the address after the .ORG
;; directive is crucial and has to be adapted manually since the assembler is (as of
;; now) unable to perform address arithmetic!
;;=========================================================================================
;
            .ORG    0xFEE9

VAR$STACK_START         .BLOCK  0x0001                  ; Here comes the stack...
;
;******************************************************************************************
;* MTH: Current seed for the Random Number Generator
;******************************************************************************************
;
_MTH$SEED_LOW           .BLOCK  0x0001                  ; Bits 15-0 of the seed
_MTH$SEED_HIGH          .BLOCK  0x0001                  ; Bits 30-16 of the seed
;
;******************************************************************************************
;* VGA control block
;******************************************************************************************
;
_VGA$X                  .BLOCK  0x0001                  ; Current X coordinate
_VGA$Y                  .BLOCK  0x0001                  ; Current Y coordinate
;
;******************************************************************************************
;* SD Card / FAT32 support
;******************************************************************************************
;
_SD$DEVICEHANDLE        .BLOCK  FAT32$DEV_STRUCT_SIZE   ; sysdef.asm: FAT32$DEV_STRUCT_SIZE
