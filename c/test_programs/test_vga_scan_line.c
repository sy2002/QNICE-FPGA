// This program rapidly samples the behaviour of the VGA_SCAN_LINE register.
// The requirement is that this register increases by one in the range 0 to 524 inclusive.
// If this requirement fails, the sequence of monitored values is written to stdout.
//
// Details:
// https://github.com/sy2002/QNICE-FPGA/issues/181

#include <stdio.h>
#include <qmon.h>

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

unsigned int buffer[10000];
int size;

int main()
{
   while (1)
   {
      size = 0;
      unsigned int last = 525;
      unsigned int this = 0;

      while (size < 10000)
      {
         this = MMIO(VGA_SCAN_LINE);
         while (this == last)
         {
            this = MMIO(VGA_SCAN_LINE);
         }
         last = this;

         buffer[size++] = this;
      }

      int err_index = 0;
      last = buffer[0];
      for (int i=1; i<10000; ++i)
      {
         if (buffer[i] != last+1 && !(last == 524 && buffer[i] == 0))
         {
            err_index = i;
         }
         last = buffer[i];
      }

      if (err_index > 5)
      {
         printf("Suspicious:\n");
         for (int i=err_index-5; i<err_index+5; ++i)
         {
            printf("%u\n", buffer[i]);
         }
         break;
      }
      else
      {
         printf("Ok this time.\n");
      }
   }

   return 0;
}

