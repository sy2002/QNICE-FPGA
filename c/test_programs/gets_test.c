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
*/

#ifndef __QNICE__
#error This code is meant to run on QNICE.
#endif

#ifdef USE_MONITOR
    #define gets(x)   ((fp)0x0006)(x)   
    #define TITLE_STRING "QNICE Monitor gets testbed - done by sy2002 in October 2016" 
#else
    #define gets(x)   ((fp)0xE004)(x)   
    #define TITLE_STRING "gets development testbed - done by sy2002 in October 2016"
#endif

#define putsnl(x) ((fp)0x0008)(x)
#define exit(x)   ((fp)0x0016)(x)
#define puthex(x) ((fp)0x0026)(x)

typedef int (*fp)();

static void puts(char *p)
{
  putsnl(p);
  putsnl("\r\n");
}

int main()
{
    int i;
    int magic[4] = {0xFF90, 0x0016, 0x2309, 0x1976};
    char input_buffer[1024];

    puts(TITLE_STRING);
    puts("supports backspace for editing and CR, LF and CR/LF as input terminator.");
    puts("");

#ifndef USE_MONITOR
    /* check for gets.asm to be loaded at 0xE000 onwards */
    for (i = 0; i < 4; i++)
        if (*((int*) 0xE000 + i) != magic[i])
        {
            puts("error: companion routines from gets.asm are not loaded.");
            exit(1);
        }
#endif        

    /* test gets */

    putsnl("Enter something: ");
    gets(input_buffer);
    puts("\n");

    i = 0;
    while (*((int*) input_buffer + i) != 0) i++;
    putsnl("Number of chars entered (in hex): ");
    puthex(i);
    puts("");

    putsnl("You entered: ");
    puts(input_buffer);

    exit(0);
}