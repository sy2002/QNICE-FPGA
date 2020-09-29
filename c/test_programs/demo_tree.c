/*  VGA demonstration of sprite animation
 *
 *  This program displays an animated atom consisting of 24 separate images.
 *
 *  How to compile:  qvc demo_tree.c sprite.c tree_sprite.c -c99 -O3 -maxoptpasses=15
 *
 *  done by MJoergen in September 2020
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"
#include "sprite.h"

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

// These variables are defined in atom_sprite.c
extern const t_sprite_bitmap bitmaps[];

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Hide cursor
   qmon_vga_cls();                        // Clear screen
   sprite_clear_all();                    // Remove all sprites

   MMIO(VGA_STATE) |= VGA_EN_SPRITE;      // Enable sprites

   // Set background color to white
   MMIO(VGA_PALETTE_OFFS) = VGA_PALETTE_OFFS_USER;
   MMIO(VGA_PALETTE_ADDR) = VGA_PALETTE_OFFS_USER + 0x10;
   MMIO(VGA_PALETTE_DATA) = VGA_COLOR_WHITE;

   // Loop over all images
   for (int image=0; image<96; ++image)
   {
      sprite_set_bitmap(image,   bitmaps[image]);

      int y = image/8;
      int x = image%8;

      sprite_set_position(image, 100+x*16, 100+y*16);
      sprite_set_config(image,   VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_LOWRES);
   }

   qmon_gets();

   return 0;
}

