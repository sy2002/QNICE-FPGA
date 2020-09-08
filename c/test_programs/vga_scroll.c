/*  VGA Scrolling Text demonstration
 *
 *  This program generates a scrolling line of text in the middle of the screen.
 *
 *  How to compile: qvc vga_scroll.c -O3 -c99
 *
 *  done by MJoergen in August 2020
*/

#include <stdio.h>

#include "sysdef.h"
#include "qmon.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

// Part of transcript from lecture by Alan Watts: "The Real You".
const char text[] =
"                                                                              \
The Real You - If you're ready to wake up, you're going to \
wake up and if you're not ready, you're going to stay pretending that you're \
just 'poor little me'.  And since you're all here and engaged in this sort of \
inquiry and listening to this sort of lecture, I assume that you're all on the \
process of waking up or else you're teasing yourself with some kind of \
flirtation with waking up which you're not serious about.  But I assume maybe \
you are not serious, but sincere that you are ready to wake up. So then, when \
you're in the way of waking up and finding out who you really are, what you do \
is what the whole universe is doing at the place you call here and now.  You \
are something the whole universe is doing in the same way that a wave is \
something that the whole ocean is doing.  The real you is not a puppet which \
life pushes around.  The real, deep down you is the whole universe. \
                                                                ";

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Disable hardware cursor.
   qmon_vga_cls();                        // Clear screen.

   // Enable User Palette
   MMIO(VGA_PALETTE_OFFS) = VGA_PALETTE_OFFS_USER;

   int dx=0;
   int counter=0;
   int pos=0;
   MMIO(VGA_PALETTE_ADDR) = VGA_PALETTE_OFFS_USER + 16;           // Select background colour #0.
   MMIO(VGA_CR_Y) = 25;
   while (1)
   {
      while (MMIO(VGA_SCAN_LINE) != 300)  // 300 = 25*12
         ;
      MMIO(VGA_ADJUST_X) = dx; // Pixels to adjust screen in X direction
      MMIO(VGA_PALETTE_DATA) = VGA_COLOR_RED;

      while (MMIO(VGA_SCAN_LINE) != 312)  // 312 = 26*12
         ;
      MMIO(VGA_ADJUST_X) = 8; // Pixels to adjust screen in X direction
      MMIO(VGA_PALETTE_DATA) = VGA_COLOR_DARK_GRAY;

      while (MMIO(VGA_SCAN_LINE) != 324)  // 324 = 27*12
         ;
      MMIO(VGA_ADJUST_X) = 0; // Pixels to adjust screen in X direction

      ++counter;
      if ((counter % 3) == 0)
      {
         ++dx;
         if (dx == 8)
         {
            dx = 0;
            for (int i=0; i<81; ++i)
            {
               MMIO(VGA_CR_X) = i;
               MMIO(VGA_CHAR) = text[pos+i];
            }
            ++pos;
            if (pos+80 > sizeof(text))
            {
               pos = 0;
            }
         }
      }
   } // while

   return 0;
} // int main()

