/*  VGA demonstration of sprite animation
 *
 *  This program displays an animated atom consisting of 24 separate images.
 *
 *  How to compile:  qvc demo_atom.c sprite.c atom_sprite.c -c99 -O3 -maxoptpasses=15
 *
 *  The atom sprite comes from the Space Shooter Art Pack 01 by Playniax:
 *  We bought a license for it on itch.io on 2020-09-03 21:40:30. The license
 *  allows us to use it for QNICE-FPGA and to distribute it in it's processed
 *  form as atom.c and atom_sprite.c. The original sprite .PNG that we bought
 *  must not be distributed, this is why you won't find it in our GitHub repo.
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
extern const t_sprite_palette palette;
extern const t_sprite_bitmap bitmaps[];

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Hide cursor
   qmon_vga_cls();                        // Clear screen
   sprite_clear_all();                    // Remove all sprites

   MMIO(VGA_STATE) |= VGA_EN_SPRITE;      // Enable sprites

   // Configure all bitmaps
   for (int image=0; image<96; ++image)
   {
      sprite_set_palette(image, palette);
      sprite_set_bitmap(image,  bitmaps[image]);
   }

   int image = 0;
   int offset_x = 100*256;
   int offset_y = 0;

   while (1)
   {
      // Location of image
      int pos_x = 320 + offset_x/256;
      int pos_y = 240 + offset_y/256;

      // Update image position
      for (int sprite=0; sprite<4; ++sprite)
      {
         int x=sprite%2;
         int y=sprite/2;
         sprite_set_position(sprite,   pos_x-32+x*32, pos_y-32+y*32);
         sprite_set_bitmap_ptr(sprite, image*2+x+48*y);
         sprite_set_config(sprite,     VGA_SPRITE_CSR_VISIBLE);

      }

      // Cycle through all bitmaps
      image = (image+1) % 24;

      // Wait 6 frames before updating image.
      for (int f=0; f<6; ++f)
      {
         offset_y -= offset_x/256;
         offset_x += offset_y/256;

         while (MMIO(VGA_SCAN_LINE) >= 480)
         {
            if (MMIO(IO_UART_SRA) & 1)
            {
               unsigned int tmp = MMIO(IO_UART_RHRA);
               goto end;
            }
            if (MMIO(IO_KBD_STATE) & KBD_NEW_ANY)
            {
               unsigned int tmp = MMIO(IO_KBD_DATA);
               goto end;
            }
         }
         while (MMIO(VGA_SCAN_LINE) < 480)
         {}
      }
   }

end:

   MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR;   // Enable cursor
   qmon_vga_cls();                        // Clear screen
   sprite_clear_all();                    // Remove all sprites
   MMIO(VGA_STATE) &= ~VGA_EN_SPRITE;     // Disable sprites

   return 0;
}

