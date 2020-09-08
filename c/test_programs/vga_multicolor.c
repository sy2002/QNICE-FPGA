/*  VGA Multicolor demonstration
 *
 *  This program draws a box full of X's with different foreground and
 *  background colors.
 *
 *  How to compile: qvc vga_multicolor.c -O3 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static void putxyc(unsigned int x, unsigned int y, unsigned int ch, unsigned int col)
{
   MMIO(VGA_CR_X) = x;
   MMIO(VGA_CR_Y) = y;
   MMIO(VGA_CHAR) = col*256 + ch;
}

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Disable hardware cursor

   for (int r=0; r<20; ++r)
   {
      for (int x=r; x<80-r; ++x)
      {
         for (int y=r; y<40-r; ++y)
         {
            putxyc(x,y,'X',(13*r) & 0xFF);
         }
      }
   }

   return 0;
}
