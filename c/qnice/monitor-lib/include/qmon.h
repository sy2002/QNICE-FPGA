/*
    QNICE Monitor Functions for VBCC

    Wrapper functions to make the Monitor functions available
    within C programs and within the C standard library.

    done by sy2002 in October 2016
    enhanced by sy2002 in August & September 2022: FAT32 writing: first vers.
*/

#ifndef _QMON_H
#define _QMON_H

#include <stdio.h>

#include "qmon-ep.h"
#include "sysdef.h"

typedef int (*_qmon_fp)();

#define qmon_getc(x)                ((_qmon_fp)  QMON_EP_GETC)(x)
#define qmon_putc(x)                ((_qmon_fp)  QMON_EP_PUTC)(x)
#define qmon_gets(x)                ((_qmon_fp)  QMON_EP_GETS)(x)
#define qmon_gets_s(x, y)           ((_qmon_fp)  QMON_EP_GETS_S)(x, y)
#define qmon_gets_slf(x, y)         ((_qmon_fp)  QMON_EP_GETS_SLF)(x, y)
#define qmon_puts(x)                ((_qmon_fp)  QMON_EP_PUTS)(x)
#define qmon_crlf                   ((_qmon_fp)  QMON_EP_CRLF)
#define qmon_vga_cls                ((_qmon_fp)  QMON_EP_VGA_CLS)
#define qmon_gethex                 ((_qmon_fp)  QMON_EP_GETHEX)
#define qmon_puthex(x)              ((_qmon_fp)  QMON_EP_PUTHEX)(x)
#define qmon_str2upper(x)           ((_qmon_fp)  QMON_EP_STR2UPPER)(x)
#define qmon_exit                   ((_qmon_fp)  QMON_EP_EXIT)

/* ========================================================================
   STRING I/O AND STRING HANDLING FUNCTIONS
   ======================================================================== */

/* Split the input string into an amount of segments, separated by the
   separator char. Returns the number of segments. Mallocs an appropriate
   buffer for the output automatically, so you pass a pointer to your
   string pointer. You need to manually free the output buffer.
   The memory structure of the memory that *output is pointing to is
   as follows:
   <size of segment incl. null terminator><null terminated segment>
   <next...>
   Example:
   input="a/simple/test", separator='/' then *output points to memory that
   looks like this:
       2a<zero terminator>
       7simple<zero terminator>
       5test<zero terminator> 
   and the function returns 3. */   
int qmon_split_str(char* input, char separator, char** output);

/* ========================================================================
    FAT32 IMPLEMENTATION

    Functions to mount a device, work with directories and files.

    All functions that return an int have the following semantics:
    0 == no error, any other value indicates an error that is defined
    in sysdef.h. The error values are either FAT32_ERR_* or hardware specific
    errors. In the SD Card case, these are SD_ERR_* errors.

    QNICE Monitor's FAT32 library is using a hardware abstraction that
    is built into the mounting mechanism. This version of the library
    only offers a version for the built-in SD Card. If you want to use
    FAT32 on another hardware, then write a wrapper for QMON_EP_F32_MNT
    which calls FAT32$MOUNT in monitor/fat32_library.asm.
   ======================================================================== */

/* Non C standard function to determine the size of a file */
unsigned long fsize(FILE* fileptr);

typedef unsigned int fat32_device_handle[FAT32_DEV_STRUCT_SIZE];
typedef unsigned int fat32_file_handle[FAT32_FDH_STRUCT_SIZE];
typedef unsigned int fat32_dir_entry[FAT32_DE_STRUCT_SIZE];

/* Mount a partition of the built-in SD Card and by doing so, fill the
   mount data structure aka fat32_device_handle with valid information. */
int fat32_mount_sd(fat32_device_handle dev_handle, int partition);

/* Open a directory for further processing by filling valid data into a
   directory handle (aka file handle). Pass a valid device handle. */
int fat32_open_dir(fat32_device_handle dev_handle, fat32_file_handle dir_handle);

/* Changes the current directory relative to the device handle. Use '/' as a
   delimiter for paths, '..' for one level up and '.' for the current path. */
int fat32_change_dir(fat32_device_handle dev_handle, char* path);

/* Iterate through all entries of a directory that are matching the filter
   criteria given by attribs (FAT32_FA_* from sysdef.h). Use FAT32_FA_DEFAULT,
   if you want to browse for non hidden files and directories but not for
   the volume id. Each call to the function (re-)fills the directory entry
   structure given in d_entry. entry_valid indicates, if d_entry contains
   valid data, which also means that it makes sense to call fat32_list_dir
   again to check, if there are more entries. */
int fat32_list_dir(fat32_file_handle f_handle, fat32_dir_entry d_entry, int attribs, int* entry_valid);

/* Print a directory entry on STDOUT and use attribs to define how to format
   the output (FAT32_PRINT_SHOW_* from sysdef.h). Use FAT32_PRINT_DEFAULT,
   if you want to print the DIR> indicator, size, date and time, but no
   file attributes. */
void fat32_print_dir_entry(fat32_dir_entry d_entry, int attribs);

/* Open a file, you can use a file name that contains a nested path using
   '/' as a separator, '..' for one level up and '.' for the current path.
   Pass a valid device handle and an empty file handle. The file handle
   fill be filled. */
int fat32_open_file(fat32_device_handle dev_handle, fat32_file_handle f_handle, char* name);

/* Read one byte from a file into the low byte of "*result", increase internal
   read pointer. Returns 0 if OK, FAT32_EOF on end of file or any other
   error code. */
int fat32_read_file(fat32_file_handle f_handle, int* result);

/* Write low byte in "data" to file at the current seek position and increase
   internal write pointer. Returns 0 if OK, FAT32_EOF on end of file or any
   other error code. */
int fat32_write_file(fat32_file_handle f_handle, unsigned int data);

/* Seek to a read position within the file. Returns 0, if OK,
   FAT23_ERR_SEEKTOOLARGE, if the seek would exceed the file or
   any other error code. */
int fat32_seek_file(fat32_file_handle f_handle, unsigned long seek_pos);

/* Writes the 512-byte sector buffer to the physical medium.
   Returns 0, if OK, error code otherwise */
int fat32_flush_file(fat32_file_handle f_handle);

/* Closes file and writes unwritten changes to disk.
   Returns 0, if OK, error code otherwise */
int fat32_close_file(fat32_file_handle f_handle);

#endif