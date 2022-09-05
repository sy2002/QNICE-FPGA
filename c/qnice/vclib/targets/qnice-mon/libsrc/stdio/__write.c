/*
    __write.c is an abstraction for the Standard C Library that is used
    to write an amount "l" of characters from the source address "p"
    using the device specified by the handle "h". It returns the amount
    of characters written.

    done by sy2002 in November 2016
    enhanced by sy2002 in August 2022
*/

#include <stdio.h>
#include "qdefs.h"
#include "qmon.h"

size_t __write(int h, const char* p, size_t l)
{
    /* write to STDOUT or STDERR, which are the same on QNICE and
       which are defined by the switches on the FPGA board */
    if (h == QNICE_STDOUT || h == QNICE_STDERR)
    {
        size_t i;
        for (i = l; i != 0; i--)
            qmon_putc(*p++);
        return l;
    }

    //cannot write to STDIN
    else if (h == QNICE_STDIN)
        return 0;

    //write to a file
    else
    {
        int retval;
        size_t bytes_written = 0;
        fat32_file_handle* file_handle = (fat32_file_handle*) h;

        while (bytes_written < l)
        {
            retval = fat32_write_file(*file_handle, *p);
            if (retval == 0)
            {
                p++;
                bytes_written++;
            }
            else if (retval == FAT32_EOF)
                break;
            else
                return -1;
        }

        return bytes_written;
    }
}
