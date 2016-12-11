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

   enhanced by sy2002 to also test gets_s and gets_slf in December 2016
*/

#include "qmon.h"  

#ifndef __QNICE__
#error This code is meant to run on QNICE.
#endif

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

typedef int (*fp)();

#ifdef USE_MONITOR
    #define gets(x)         qmon_gets(x)
    #define gets_s(x, y)    qmon_gets_s(x, y)
    #define gets_slf(x, y)  qmon_gets_slf(x, y)
    #define TITLE_STRING "QNICE Monitor gets testbed - done by sy2002 in December 2016\r\n" 
#else
    #define gets(x)         ((fp)0xE004)(x)
    #define gets_s(x, y)    ((fp)0xE00D)(x, y)
    #define gets_slf(x, y)  ((fp)0xE013)(x, y)
    #define TITLE_STRING "gets development testbed - done by sy2002 in December 2016\r\n"
#endif

void hexdump_string(char* str)
{
    const char* HEX_DIGITS = "0123456789ABCDEF";
    int n = 10;

    qmon_puts("====== HEXDUMP: START =======\r\n");

    while (*str)
    {
        qmon_putc(HEX_DIGITS[(*str & 0x00F0) >> 4]);
        qmon_putc(HEX_DIGITS[*str & 0x000F]);
        qmon_putc(' ');
        if (!--n)
        {
            qmon_crlf();
            n = 10;
        }
        str++;
    }

    if (n != 10)
        qmon_crlf();

    qmon_puts("====== HEXDUMP: END  ========\r\n");    
}

void test_gets_s_and_gets_slf(char* input_buffer, char mode)
{
    qmon_puts("***************************************************\r\n");
    if (mode == 1)
        qmon_puts("     gets_s\r\n");
    else
        qmon_puts("     gets_slf\r\n");
    qmon_puts("***************************************************\r\n\r\n");        
    qmon_puts("Enter the buffer size using four hexadecimal digits (max 0400): ");
    int buf_size = qmon_gethex();
    qmon_crlf();
    if (buf_size <= 1024)
    {
        qmon_puts("Enter something via ");
        if (mode == 1)
        {
            qmon_puts("gets_s: ");
            gets_s(input_buffer, buf_size);
        }
        else
        {
            qmon_puts("gets_slf: ");
            gets_slf(input_buffer, buf_size);
        }
        qmon_crlf();

        int i = 0;
        while (*((int*) input_buffer + i) != 0) i++;
        qmon_puts("Number of chars entered (in hex): ");
        qmon_puthex(i);
        qmon_crlf();

        qmon_puts("You entered via ");
        if (mode == 1)
            qmon_puts("gets_s: ");
        else
            qmon_puts("gets_slf: ");
        qmon_puts(input_buffer);
        qmon_crlf();
        hexdump_string(input_buffer);    
    }
    else
        qmon_puts("Illegal buffer size.\n");
    qmon_puts("\r\n\r\n\r\n"); 
}

int main()
{
    int i;
    int magic[4] = {0xFF90, 0x0016, 0x2309, 0x1976};
    char input_buffer[1024];

    qmon_puts(TITLE_STRING);
    qmon_puts("supports backspace for editing and CR, LF and CR/LF as input terminator.\r\n");
    qmon_crlf();

#ifndef USE_MONITOR
    //check for gets.asm to be loaded at 0xE000 onwards
    for (i = 0; i < 4; i++)
        if (*((int*) 0xE000 + i) != magic[i])
        {
            qmon_puts("error: companion routines from gets.asm are not loaded.\r\n");
            return -1;
        }
#endif        

    //gets test
    qmon_puts("***************************************************\r\n");
    qmon_puts("     gets\r\n");
    qmon_puts("***************************************************\r\n\r\n");    
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
    hexdump_string(input_buffer);
    qmon_puts("\r\n\r\n\r\n");   

    //gets_s test
    test_gets_s_and_gets_slf(input_buffer, 1);

    //gets_slf test
    test_gets_s_and_gets_slf(input_buffer, 2);
}
