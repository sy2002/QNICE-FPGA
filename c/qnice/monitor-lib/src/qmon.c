/*
    QNICE Monitor Functions for VBCC

    Wrapper functions to make the Monitor functions available
    within C programs and within the C standard library.

    done by sy2002 in October 2016
    enhanced by sy2002 in August 2022: fat32_read_file
*/

#include "qmon.h"
#include "qmon-ep.h"

#define MACRO_STRINGIFY(x) #x
#define M2S(x) MACRO_STRINGIFY(x)

/* ========================================================================
   STRING I/O AND STRING HANDLING FUNCTIONS
   ======================================================================== */    

int def_qmon_split_str(char* input, char separator, char** output) =
  "          ASUB     " M2S(QMON_EP_SPLIT) ", 1\n"    //call STR$SPLIT in monitor
  "          MOVE     R13, R0\n"                      //R0=SP: stack contains split strings, save stack
  "          MOVE     R9, R1\n"                       //R1=R9: save amount of words generated on stack
  "          MOVE     R8, R2\n"                       //R2=R8: save amount of split strings
  "          MOVE     R10, R3\n"                      //R3: save char** output
  "          CMP      R2, 0\n"                        //empty string?
  "          RBRA     _QMS_ML, !Z\n"                  //no: go on
  "          MOVE     0, @R3\n"                       //yes: set *output to zero and ...
  "          RBRA     _QMS_END, 1\n"                  //... return zero as function value
  "_QMS_ML:  MOVE     R9, R8\n"                       //use R9 to prepare malloc function call
  "          ASUB     #_malloc, 1\n"                  //R8=malloc(size of amount of words gen. on stack) "
  "          MOVE     R8, @R3\n"                      //*output = R8 (save heap pointer)
  "          CMP      R8, 0\n"                        //did malloc work?
  "          RBRA     _QMS_END, Z\n"                  //no: return
  "          MOVE     R1, R4\n"                       //R4=amount of words to copy
  "_QMS_LP:  MOVE     @R0++, @R8++\n"                 //copy from stack to newly malloced memory
  "          SUB      1, R4\n"                        //amount of words to copy -= 1
  "          RBRA     _QMS_LP, !Z\n"                  //loop until everything is done
  "_QMS_END: MOVE     R2, R8\n"                       //return amount of split strings
  "          ADD      R1, R13\n";                     //"delete" return values of STR$SPLIT from stack

int qmon_split_str(char* input, char separator, char** output)
{
    return def_qmon_split_str(input, separator, output);
}

/* ========================================================================
    FAT32 IMPLEMENTATION
   ======================================================================== */

unsigned long fsize(FILE* fileptr)
{
    /* the system is little endian and within the file handle the file size
       is stored in little endian, too; so we simply need to de-reference
       the appropriate address in memory as an unsigned long */
    int* ptr = (int*) fileptr->filehandle;
    long* filesize = (long*) (ptr + FAT32_FDH_SIZE_LO);
    return (unsigned long) *filesize;
}

int def_fat32_mount_sd(fat32_device_handle dev_handle, int partition) =
  "          ASUB     " M2S(QMON_EP_F32_MNT_SD) ", 1\n"     //call FAT32$MOUNT_SD in monitor
  "          MOVE     R9, R8\n";                            //return 0 or error code

int fat32_mount_sd(fat32_device_handle dev_handle, int partition)
{
    return def_fat32_mount_sd(dev_handle, partition);
}

int def_fat32_open_dir(fat32_device_handle dev_handle, fat32_file_handle dir_handle) =
  "          ASUB     " M2S(QMON_EP_F32_OD) ", 1\n"         //call FAT32$DIR_OPEN in monitor
  "          MOVE     R9, R8\n";                            //return 0 or error code


int fat32_open_dir(fat32_device_handle dev_handle, fat32_file_handle dir_handle)
{
    return def_fat32_open_dir(dev_handle, dir_handle);
}

int def_fat32_change_dir(fat32_device_handle dev_handle, char* path) =
  "          XOR      R10, R10\n"                           //R10 = 0 means: use '/' as path separator
  "          ASUB     " M2S(QMON_EP_F32_CD) ", 1\n"         //call FAT32$CD in monitor
  "          MOVE     R9, R8\n";                            //return 0 or error code

int fat32_change_dir(fat32_device_handle dev_handle, char* path)
{
    return def_fat32_change_dir(dev_handle, path);    
}


int def_fat32_list_dir(fat32_file_handle f_handle, fat32_dir_entry d_entry, int attribs, int* entry_valid) = 
  "          ASUB     " M2S(QMON_EP_F32_LD) ", 1\n"         //call FAT32$DIR_LIST in monitor
  "          MOVE     R11, R8\n"                            //return 0 or error code
  "          MOVE     @R13, R9\n"                           //get "entry_valid" pointer from stack (do not change SP)
  "          MOVE     R10, @R9\n";                          //*entry_valid = R10


int fat32_list_dir(fat32_file_handle f_handle, fat32_dir_entry d_entry, int attribs, int* entry_valid)
{
    return def_fat32_list_dir(f_handle, d_entry, attribs, entry_valid);
}

void fat32_print_dir_entry(fat32_dir_entry d_entry, int attribs)
{
    ((_qmon_fp) QMON_EP_F32_PD)(d_entry, attribs);
}

int def_fat32_open_file(fat32_device_handle dev_handle, fat32_file_handle f_handle, char* name) =
  "          XOR      R11, R11\n"                         //R11 = 0 means '/' is the path separator
  "          ASUB     " M2S(QMON_EP_F32_FOPEN) ", 1\n"    //call FAT32$FILE_OPEN in monitor
  "          MOVE     R10, R8\n";                         //return 0 or error code

int fat32_open_file(fat32_device_handle dev_handle, fat32_file_handle f_handle, char* name)
{
    return def_fat32_open_file(dev_handle, f_handle, name);
}

int def_fat32_read_file(fat32_file_handle f_handle, int* result) =
  "          MOVE     R9, R0\n"                           //R0: save pointer to result
  "          ASUB     " M2S(QMON_EP_F32_FREAD) ", 1\n"    //call FAT32$FILE_RB in monitor
  "          MOVE     R9, @R0\n"                          //return result
  "          MOVE     R10, R8\n";                         //return 0 or EOF or error code

int fat32_read_file(fat32_file_handle f_handle, int* result)
{
    return def_fat32_read_file(f_handle, result);
}

int def_fat32_write_file(fat32_file_handle f_handle, unsigned int data) =
  "          ASUB     " M2S(QMON_EP_F32_FWRITE) ", 1\n"   //call FAT32$FILE_WB in monitor
  "          MOVE     R9, R8\n";                          //return 0 or EOF or error code

int fat32_write_file(fat32_file_handle f_handle, unsigned int data)
{
    return def_fat32_write_file(f_handle, data);
}

int def_fat32_seek_file(fat32_file_handle f_handle, unsigned long seek_pos) = 
  "          MOVE     R13, R11\n"                         //R0 = SP = ptr to low word of seek_pos
  "          MOVE     @R11++, R9\n"                       //R9 = low word of seek_pos
  "          MOVE     @R11++, R10\n"                      //R10 = high word of seek_pos
  "          ASUB     " M2S(QMON_EP_F32_FSEEK) ", 1\n"    //call FFAT32$FILE_SEEK in monitor
  "          MOVE     R9, R8\n";  

int fat32_seek_file(fat32_file_handle f_handle, unsigned long seek_pos)
{
    return def_fat32_seek_file(f_handle, seek_pos);
}

int def_fat32_flush_file(fat32_file_handle f_handle) =
  "          ASUB     " M2S(QMON_EP_F32_FFLUSH) ", 1\n"   //call FAT32$FLUSH in monitor
  "          MOVE     R9, R8\n";                          //return 0 or EOF or error code

int fat32_flush_file(fat32_file_handle f_handle)
{
    return def_fat32_flush_file(f_handle);
}

int def_fat32_close_file(fat32_file_handle f_handle) =
  "          ASUB     " M2S(QMON_EP_F32_FCLOSE) ", 1\n"   //call FAT32$CLOSE in monitor
  "          MOVE     R9, R8\n";                          //return 0 or EOF or error code

int fat32_close_file(fat32_file_handle f_handle)
{
    return def_fat32_close_file(f_handle);
}
