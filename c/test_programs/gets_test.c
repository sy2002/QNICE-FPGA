/* gets_test.c
   
   Test program for the development testbed for the new monitor gets
   function that is supporting CR, LF and CR/LF as an input terminator
   and therefore works well on UART and keyboard as STDIN. It also
   supports backspace for editing.

   Two modes of operation:

   1. Standard: You need to load the .out file of test_programs/gets.asm
   before running this program. That means, in this mode gets_test.c is
   used to work with the development testbed.

   2. Monitor: Use QNICE Monitor's built-in gets function instead. For
   activating this mode, compile while defining USE_MONITOR.

   done by sy2002 in October 2016

   enhanced by sy2002 to also test gets_s in December 2016
*/

#ifndef __QNICE__
#error This code is meant to run on QNICE.
#endif

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

typedef int (*fp)();

#ifdef USE_MONITOR
    #define gets(x) qmon_gets(x)    
    #define TITLE_STRING "QNICE Monitor gets testbed - done by sy2002 in December 2016\n" 
#else
    #define gets(x) ((fp)0xE004)(x)   
    #define TITLE_STRING "gets development testbed - done by sy2002 in December 2016\n"
#endif

#include "qmon.h"   

int main()
{
    int i;
    int magic[4] = {0xFF90, 0x0016, 0x2309, 0x1976};
    char input_buffer[1024];

    qmon_puts(TITLE_STRING);
    qmon_puts("supports backspace for editing and CR, LF and CR/LF as input terminator.\n");
    qmon_crlf();

#ifndef USE_MONITOR
    /* check for gets.asm to be loaded at 0xE000 onwards */
    for (i = 0; i < 4; i++)
        if (*((int*) 0xE000 + i) != magic[i])
        {
            qmon_puts("error: companion routines from gets.asm are not loaded.\n");
            return -1;
        }
#endif        

    /* test gets */

    qmon_puts("Enter something via gets: ");
    gets(input_buffer);
    qmon_crlf();

    i = 0;
    while (*((int*) input_buffer + i) != 0) i++;
    qmon_puts("Number of chars entered (in hex): ");
    qmon_puthex(i);
    qmon_crlf();

    qmon_puts("You entered via gets: ");
    qmon_puts(input_buffer);
    qmon_crlf();    
}
