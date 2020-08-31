/*  VGA Scan Line demonstration
 *
 *  This program generates a mesmerizing pattern.
 *
 *  It makes use of the Scan Line register. Specifically, the program
 *  continuously (in a tight loop) updates the background colour based
 *  on the current scan line.
 *
 *  How to compile: qvc vga_lines.c -O3 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Disable hardware cursor.
   MMIO(VGA_STATE) |= VGA_CLR_SCRN;       // Initiate hardware screen clearing.

   // Wait until hardware screen clearing is done.
   while (MMIO(VGA_STATE) & (VGA_CLR_SCRN | VGA_BUSY))
      ;

   // Infinite loop
   MMIO(VGA_PALETTE_ADDR) = 16;  // Background colour
   int j=0;
   while (1)
   {
      for (int i=0; i<30000; ++i)
      {
         MMIO(VGA_PALETTE_DATA) = (MMIO(VGA_SCAN_LINE)+j)*62;
      }
      ++j;
   }

   return 0;
} // int main()

