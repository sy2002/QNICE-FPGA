/*
    __read.c is an abstraction for the Standard C Library that is used
    to read an amount "l" of characters to the destination address "p"
    using the device specified by the handle "h". It returns the amount
    of characters read.

    When reading from STDIN, we are working in a line buffered mode, that
    by default (i.e. when QMON_LINEBUFFER_SIZE is not defined otherwise
    upon library compile time) supports 159 characters. Within this buffer,
    users can work with the DEL/BS key to edit. If larger amount of characters
    are entered, then DEL/BS only goes back until the last "boundary" of the
    buffer. That also means, that an arbitrary amount of characters can be
    entered, independent of QMON_LINEBUFFER_SIZE, which must at least be
    set to 2.

    done by sy2002 in November .. December 2016
*/

#include <stdlib.h>
#include "qdefs.h"
#include "qmon.h"

#ifndef QMON_LINEBUFFER_SIZE
#define QMON_LINEBUFFER_SIZE 160
#endif

static char* linebuffer = (char*) 0;
static char* current_char = (char*) 0;

size_t __read(int h, char* p, size_t l)
{
    //read from STDIN (which is defined by the switches on the FPGA board)
    if (h == QNICE_STDIN)
    {
        if (linebuffer == 0 || *current_char == (char) 0)
        {
            if (linebuffer)
                free(linebuffer);

            if (linebuffer = malloc(QMON_LINEBUFFER_SIZE))
            {                
                current_char = linebuffer;

                qmon_gets_slf(linebuffer, QMON_LINEBUFFER_SIZE);

                char* cnt = linebuffer;
                while (*cnt != 0)
                    cnt++;
                if (cnt != linebuffer && *(cnt - 1) == '\n')
                    qmon_crlf();
            }
            else
            {
                qmon_puts("Runtime error in __read.c: Error allocating line buffer.\r\n");
                qmon_exit();
            }
        }

        size_t n = 0;
        while (n < l)
        {
            char c = *current_char;

            *p = c;
            n++;

            if (c == '\n')
            {
                free(linebuffer);
                linebuffer = current_char = (char*) 0;
                break;
            }

            p++;
            current_char++;                        
        }

        return n;
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

void _EXIT_2___read(void)
{
    if (linebuffer)
    {
        free(linebuffer);
        linebuffer = current_char = (char*) 0;
    }
}
