// This small test program is used to test the IO@KBD_EVENT register,
// see Issue #142.
//
// It runs in an infinite loop, and prints to the console any events from the
// USB keyboard.

#include <stdio.h>
#include <sysdef.h>

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

int main()
{
   while (1)
   {
      int ev = MMIO(IO_KBD_EVENT);
      if (ev)
      {
         if (ev > 0)
            printf("MAKE %04x\n", ev);
         else
            printf("BREAK %04x\n", ev);
      }
   }

   return 0;
}

