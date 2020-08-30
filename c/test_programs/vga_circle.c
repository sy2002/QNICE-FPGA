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
#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static int next_char = 0x21;
static int first = 1;

static const int font_height = 12;
static const int font_width = 8;
static const int font_allbits = 255;
static const int char_empty = 0x20;
static const int char_full = 0x1F;

static void circle_plot(unsigned int x, unsigned int y, int right)
{
   // Convert pixel coordinates to character coordinates
   unsigned int char_x = x/font_width;
   unsigned int char_y = y/font_height;

   MMIO(VGA_CR_X) = char_x;
   MMIO(VGA_CR_Y) = char_y;

   // Get character at this position.
   int ch = MMIO(VGA_CHAR) & 0xFF;

   // If character is a space, we need to allocate a new character
   // and clear the bitmap.
   if (ch <= char_empty)
   {
      MMIO(VGA_CHAR) = next_char;
      ch = next_char;

      // Clear bitmap of new character.
      for (int i=0; i<font_height; ++i)
      {
         MMIO(VGA_FONT_ADDR) = ch*font_height+i;
         MMIO(VGA_FONT_DATA) = 0;
      }

      next_char++;

      if (right)
      {
         if (first)
         {
            // Clear bitmap of new character.
            for (int i=0; i<font_height; ++i)
            {
               MMIO(VGA_FONT_ADDR) = char_full*font_height+i;
               MMIO(VGA_FONT_DATA) = font_allbits;
            }
            first = 0;
         }

         MMIO(VGA_CR_X) += 1;
         while ((MMIO(VGA_CHAR) & 0xFF) == char_empty)
         {
            MMIO(VGA_CHAR) = char_full;
            MMIO(VGA_CR_X) += 1;
         }
      }
   }

   unsigned int offset_x = x % font_width;
   unsigned int offset_y = y % font_height;

   // Set all pixels left or right of this point
   MMIO(VGA_FONT_ADDR) = ch*font_height+offset_y;
   if (right)
      MMIO(VGA_FONT_DATA) |= font_allbits >> offset_x;
   else
      MMIO(VGA_FONT_DATA) |= ~((font_allbits>>1) >> offset_x);
} // circle_plot


int main()
{
   const unsigned int centre_x = 300;
   const unsigned int centre_y = 240;
   const unsigned int radius = 220;

   // Bresenham's Circle Drawing Algorithm

   int x=0;
   int y=radius;
   int d=3-(2*radius);

   while (x <= y)
   {
      circle_plot(centre_x + x, centre_y + y, 0);
      circle_plot(centre_x + y, centre_y + x, 0);
      circle_plot(centre_x + x, centre_y - y, 0);
      circle_plot(centre_x + y, centre_y - x, 0);
      circle_plot(centre_x - x, centre_y + y, 1);
      circle_plot(centre_x - y, centre_y + x, 1);
      circle_plot(centre_x - x, centre_y - y, 1);
      circle_plot(centre_x - y, centre_y - x, 1);
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

