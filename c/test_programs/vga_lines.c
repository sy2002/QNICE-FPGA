/*  VGA Scan Line demonstration
 *
 *  This program generates a mesmerizing pattern.
 *
 *  It makes use of the Scan Line register. Specifically, the program
 *  continuously (in a tight loop) updates the background color based
 *  on the current scan line.
 *
 *  How to compile: qvc vga_lines.c -O3 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

#include "sysdef.h"
#include "qmon.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Disable hardware cursor.

   qmon_vga_cls();                        // Clear screen.

   // Enable User Palette
   MMIO(VGA_PALETTE_OFFS) = VGA_PALETTE_OFFS_USER;

   // Infinite loop
   MMIO(VGA_PALETTE_ADDR) = VGA_PALETTE_OFFS_USER + 16;           // Select background color #0.
   int j=0;
   while (1)
   {
      while (MMIO(VGA_SCAN_LINE) < 480)
      {
         MMIO(VGA_PALETTE_DATA) = (MMIO(VGA_SCAN_LINE)+j)*62;
      }

      ++j;
      while (MMIO(VGA_SCAN_LINE) >= 480)
         ;
   }

   return 0;
} // int main()

