/*  VGA Circle demonstration
 *
 *  This program draws a filled circle. Even though
 *  this program runs in text mode, the circle is drawn
 *  with the maximum resolution. This is made possible
 *  by continuously modifying the font (the 256 character
 *  bitmaps) while drawing the circle.
 *
 *  How to compile: qvc vga_circle.c -O2 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static int next_char = 0x21;

static const int font_height = 12;
static const int font_width = 8;
static const int char_space = 0x20;

static void plot(unsigned int x, unsigned int y)
{
   // Convert pixel coordinates to character coordinates
   unsigned int char_x = x/font_width;
   unsigned int char_y = y/font_height;

   // Get character at this position.
   MMIO(VGA_CR_X) = char_x;
   MMIO(VGA_CR_Y) = char_y;
   int ch = MMIO(VGA_CHAR) & 0xFF;

   // If character is a space, we need to allocate a new character
   // and clear the bitmap.
   if (ch == char_space)
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
   }

   // Set pixel
   unsigned int offset_x = x % font_width;
   unsigned int offset_y = y % font_height;
   MMIO(VGA_FONT_ADDR) = ch*font_height+offset_y;
   MMIO(VGA_FONT_DATA) |= 128 >> offset_x;
} // plot


int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Disable hardware cursor.
   MMIO(VGA_STATE) |= VGA_CLR_SCRN;       // Initiate hardware screen clearing.

   const unsigned int centre_x = 300;
   const unsigned int centre_y = 240;
   const unsigned int radius = 75;

   // Bresenham's Circle Drawing Algorithm

   int x=0;
   int y=radius;
   int d=3-(2*radius);

   while (x <= y)
   {
      for (int px = centre_x - x; px <= centre_x + x; ++px)
      {
         plot(px, centre_y - y);
         plot(px, centre_y + y);
      }
      for (int px = centre_x - y; px <= centre_x + y; ++px)
      {
         plot(px, centre_y - x);
         plot(px, centre_y + x);
      }

      x += 1;
      if (d<0)
         d += 4*x+6;
      else
      {
         d += 4*(x-y)+10;
         y -= 1;
      }
   }

   for (int i=0; i<800; ++i)
   {
      for (int j=0; j<10000; j++)
         for (int k=0; k<50; k++)
            ;
      MMIO(VGA_PALETTE_ADDR) = 0;
      MMIO(VGA_PALETTE_DATA) += 240;
   }

   return 0;
} // int main()

