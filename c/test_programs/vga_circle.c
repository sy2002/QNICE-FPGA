/*  VGA Circle demonstration
 *
 *  This program draws a filled circle. Even though
 *  this program runs in text mode, the circle is drawn
 *  with the maximum resolution. This is made possible
 *  by continuously modifying the font (the 256 character
 *  bitmaps) while drawing the circle.
 *
 *  How to compile: qvc vga_circle.c -O3 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

//#include "qmon.h"
//#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static void circle_plot(unsigned int x, unsigned int y)
{
//   unsigned int char_x = x/8;
//   unsigned int char_y = y/12;

//   MMIO(VGA_CR_X) = char_x;
//   MMIO(VGA_CR_Y) = char_y;

   MMIO(0xFF33) += 1;

   printf("x=%u, y=%u\n", x, y);
}


int main()
{
   const unsigned int radius = 230;

   // Bresenham's Circle Drawing Algorithm

   int x=0;
   int y=radius;
   int d=3-(2*radius);

   while (x <= y)
   {
      circle_plot(radius + x, radius + y);
      x += 1;
      if (d<0)
         d += 4*x+6;
      else
      {
         d += 4*(x-y)+10;
         y -= 1;
      }
   }
   return 0;
} // int main()

