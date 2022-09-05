/*
    __open.c is an abstraction for the Standard C Library that is used
    to open files named "name" using the "mode" (which corresponds to the
    fopen syntax and semantics); returns -1 on error.

    done by sy2002 in November 2016
    enhanced by sy2002 in August 2022
*/


#include <stdio.h>
#include <stdlib.h>
#include "qmon.h"

static fat32_device_handle device_handle = {0, 0};

int __open(const char* name, const char* mode)
{
    int res;

    /* Currently, we only support read and read/update files.
       These modes are valid: r, rb, r+, rb+
       The underlying vclib does not support "r+b" (which should be equivalent
       to "rb+"), but only "rb+" itself.
       The system is differntiating between binary and text mode.
    */
    if (*mode == 'r')
    {
        char mode1 = *(mode + 1)
        char mode2 = *(mode + 2)
        char mode3 = *(mode + 3)

        if !( mode1 == 0 ||                                  /* mode == "r"   */
             (mode1 == 'b' && mode2 == 0) ||                 /* mode == "rb"  */
             (mode1 == '+' && mode2 == 0) ||                 /* mode == "r+"  */
             (mode1 == 'b' && mode2 == '+' && mode3 == 0))   /* mode == "rb+" */
                return -1; //illegal mode

        /* If this is the first call to __open, then create a device handle
           first. Currently, we only support SD cards, so we hardcoded 
           try to mount the first partition of the SD card as FAT32 device */
        if (device_handle[0] == 0 && device_handle[1] == 0)
        {
            res = fat32_mount_sd(device_handle, 1);
            if (res != 0)
            {
                //reset device handle for being able to retry later
                device_handle[0] = 0;
                device_handle[1] = 0;

                /* return error
                   this might be sub-optimal, as we might want to
                   return more detailed error information */
                return -1;                
            }
        }

        //allocate memory for the file handle
        fat32_file_handle* file_handle = malloc(FAT32_FDH_STRUCT_SIZE);
        if (file_handle == 0)
            return -1;

        //open file (supports paths within file names)
        res = fat32_open_file(device_handle, *file_handle, (char*) name);

        //everything != 0 means error, so free the memory and exit
        if (res != 0)
        {
            free(file_handle);
            return -1;
        }

        //everything went OK, so return the file handle
        return (int) file_handle;
    }

    //other mode than read-only: return with error
    else
        return -1;
}

