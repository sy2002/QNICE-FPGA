/*
    __read.c is an abstraction for the Standard C Library that is used
    to read an amount "l" of characters to the destination address "p"
    using the device specified by the handle "h". It returns the amount
    of characters read.

    done by sy2002 in November .. December 2016
*/

#include <stdio.h>
#include <stdlib.h>
#include "qdefs.h"
#include "qmon.h"

#define LINEBUFFER_SIZE 4

static char* linebuffer = (char*) 0;
static char* current_char = (char*) 0;

size_t __read(int h, char* p, size_t l)
{
    //read from STDIN (which is defined by the switches on the FPGA board)
    if (h == QNICE_STDIN)
    {
        if (linebuffer == 0 || *current_char == (char) 0)
        {
            printf("linebuffer was 0. malloc and gets.\n");

            if (linebuffer)
                free(linebuffer);

            linebuffer = malloc(LINEBUFFER_SIZE);
            current_char = linebuffer;

            qmon_gets_slf(linebuffer, LINEBUFFER_SIZE - 1);

            char* cnt = linebuffer;
            while (*cnt != 0)
                cnt++;
            if (cnt != linebuffer && *(cnt - 1) == '\n')
            {
                qmon_putc('\r');
                qmon_putc('\n');
            }
        }

        size_t n = 0;
        while (n < l)
        {
            char c = *current_char;

            printf("n = %i, l = %i, c = %c\n", n, l, c);

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
/*
  size_t n=0;
  char c;

  while(n<l){
   c=__mon_getc();
   if(c<0) break;
   __mon_putc(c);
   if(c=='\r'){
     c='\n';
     __mon_putc(c);
   }
   *p++=c;
   n++;
   if(c=='\n')
    break;
  }

   return n;        
    }
*/

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
