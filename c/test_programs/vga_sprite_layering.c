/*  Program to test Sprite Layering
 *
 *  This program tests six different situations, as described below. This
 *  tests the various layering combinations of sprites and text.

 *  Case 1.
 *  TEXT        (GREEN on BLACK)
 *  SPRITE 0    (RED. configured as IN-FRONT-OF)
 *  This shall display a RED color, because the sprite is in front of the text.
 *
 *  Case 2.
 *  SPRITE 0    (RED. configured as BEHIND)
 *  TEXT        (GREEN on BLACK)
 *  This shall display GREEN text on RED background, because the sprite is
 *  behind the text but in front of the background.
 *
 *  Case 3.
 *  TEXT        (GREEN on BLACK)
 *  SPRITE 1    (BLUE. configured as IN-FRONT-OF)
 *  SPRITE 0    (RED. configured as IN-FRONT-OF)
 *  This shall display a RED color, because sprite 0 is always in front of sprite 1.
 *
 *  Case 4.
 *  SPRITE 1    (BLUE. configured as BEHIND)
 *  TEXT        (GREEN on BLACK)
 *  SPRITE 0    (RED. configured as IN-FRONT-OF)
 *  This shall again display a RED color, because sprite 0 is in-front-of the text.
 *
 *  Case 5.
 *  SPRITE 1    (BLUE. configured as BEHIND)
 *  SPRITE 0    (RED. configured as BEHIND)
 *  TEXT        (GREEN on BLACK)
 *  This shall display GREEN text on RED background, again because sprite 0 is in front of sprite 1.
 *
 *  Case 6.
 *  SPRITE 0    (RED. configured as BEHIND)
 *  TEXT        (GREEN on BLACK)
 *  SPRITE 1    (BLUE. configured as IN-FRONT-OF)
 *  This shall display GREEN text on RED background, because sprite 0 takes precedence over sprite 1.
 *
 *
 *  How to compile: qvc vga_sprite_layering.c sprite.c conio.c -O3 -c99
 *
 *  done by MJoergen in September 2020
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"
#include "sprite.h"
#include "conio.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

const t_sprite_palette palette = {
   VGA_COLOR_TRANSPARENT,  // Index 0
   VGA_COLOR_RED,          // Index 1
   VGA_COLOR_BLUE,         // Index 2
                           // Indices 3-15 will be cleared
};

const t_sprite_bitmap bitmap_red = {
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x1111, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
}; // bitmap_red

const t_sprite_bitmap bitmap_blue = {
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
   0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222, 0x2222,
}; // bitmap_blue

struct {
   int x;
   int y;
   const t_sprite_bitmap *pBitMap;
   int csr;
} sprites[10] = {
   // Case 1
   {0, 0, &bitmap_red, VGA_SPRITE_CSR_VISIBLE},

   // Case 2
   {24, 0, &bitmap_red, VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_BEHIND},

   // Case 3
   {48, 0, &bitmap_red, VGA_SPRITE_CSR_VISIBLE},
   {48, 0, &bitmap_blue, VGA_SPRITE_CSR_VISIBLE},

   // Case 4
   {0, 20, &bitmap_red, VGA_SPRITE_CSR_VISIBLE},
   {0, 20, &bitmap_blue, VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_BEHIND},

   // Case 5
   {24, 20, &bitmap_red, VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_BEHIND},
   {24, 20, &bitmap_blue, VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_BEHIND},

   // Case 6
   {48, 20, &bitmap_red, VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_BEHIND},
   {48, 20, &bitmap_blue, VGA_SPRITE_CSR_VISIBLE},
};

struct {
   int x;
   int y;
   const char line0[16];
   const char line1[16];
   const char line2[16];
   const char line3[16];
   const char line4[16];
} tests[6] = {
   { 0,  0, "TEXT", "RED",  "",     "", "=> RED"},
   {24,  0, "RED",  "TEXT", "",     "", "=> GREEN on RED"},
   {48,  0, "TEXT", "BLUE", "RED",  "", "=> RED"},
   { 0, 20, "BLUE", "TEXT", "RED",  "", "=> RED"},
   {24, 20, "BLUE", "RED",  "TEXT", "", "=> GREEN on RED"},
   {48, 20, "RED",  "TEXT", "BLUE", "", "=> GREEN on RED"},
};

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Hide cursor
   qmon_vga_cls();                        // Clear screen
   sprite_clear_all();                    // Remove all sprites

   MMIO(VGA_STATE) |= VGA_EN_SPRITE;      // Enable sprites

   for (int i=0; i<6; ++i)
   {
      for (int x=0; x<6; ++x)
         for (int y=0; y<5; ++y)
            cputcxy(tests[i].x+x, tests[i].y+y, '#');

      cputsxy(tests[i].x, tests[i].y+8,  tests[i].line0);
      cputsxy(tests[i].x, tests[i].y+9,  tests[i].line1);
      cputsxy(tests[i].x, tests[i].y+10, tests[i].line2);
      cputsxy(tests[i].x, tests[i].y+11, tests[i].line3);
      cputsxy(tests[i].x, tests[i].y+12, tests[i].line4);
   }

   for (int i=0; i<10; ++i)
   {
      sprite_set_palette(i,  palette);
      sprite_set_bitmap(i,   *sprites[i].pBitMap);
      sprite_set_config(i,   sprites[i].csr);
      sprite_set_position(i, sprites[i].x*8+8, sprites[i].y*12+12);
   }

   return 0;
} // main
