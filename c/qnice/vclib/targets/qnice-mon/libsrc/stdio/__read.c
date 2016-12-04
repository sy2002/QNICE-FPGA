/*
    __read.c is an abstraction for the Standard C Library that is used
    to read an amount "l" of characters to the destination address "p"
    using the device specified by the handle "h". It returns the amount
    of characters read.

    done by sy2002 in November 2016
*/

#include <stdio.h>
#include "qdefs.h"
#include "qmon.h"

size_t __read(int h, char* p, size_t l)
{
    printf("DEBUGOUT: __read: l = %i\n", l);

    /* read from STDIN (which is defined by the switches on the FPGA board)
       point to improve: we are ignoring "l" in this case */
    if (h == QNICE_STDIN)
    {
        qmon_gets(p);

        char* cnt = p;
        while (*cnt != 0)
            cnt++;
        *cnt = '\n';
        *(++cnt) = 0;

        qmon_putc('\r');
        qmon_putc('\n');

        return (size_t) cnt - (size_t) p;
    }

    //cannot read from STDOUT or STDERR
    else if (h == QNICE_STDOUT || h == QNICE_STDERR)
        return -1;

    //read from a file
    else
    {
        int result;
        int retval;        
        size_t bytes_read = 0;
        fat32_file_handle* file_handle = (fat32_file_handle*) h;

        while (bytes_read < l)
        {
            retval = fat32_read_file(*file_handle, &result);
            if (retval == 0)
            {
                *p = (char) result;
                p++;
                bytes_read++;
            }
            else if (retval == FAT32_EOF)
                break;
            else
                return -1;
        }

        return bytes_read;
    }
}
