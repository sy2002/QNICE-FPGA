/*  VGA demonstration of sprite animation
 *
 *  This program displays an animated atom consisting of 24 separate images.
 *
 *  How to compile:  qvc demo_atom.c sprite.c atom_sprite.c -c99 -O3 -maxoptpasses=15
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

   sprite_set_config(0, VGA_SPRITE_CSR_MIRROR_X);  // To Be Removed. This is a work-around for a hardware bug.

   while (1)
   {
      // Loop over all images
      for (int image=0; image<24; ++image)
      {
         for (int y=0; y<2; ++y)
         {
            for (int x=0; x<2; ++x)
            {
               sprite_set_palette(1+2*y+x,  palette);
               sprite_set_bitmap(1+2*y+x,   bitmaps[image*2+x+48*y]);
               sprite_set_config(1+2*y+x,   VGA_SPRITE_CSR_VISIBLE | VGA_SPRITE_CSR_MIRROR_X);  // MIRROR_X is to be removed. That is a work-around for yet another hardware bug.
               sprite_set_position(1+2*y+x, 240+x*32, 160+y*32);
            }
         }

         // Wait 6 frames before updating image.
         for (int f=0; f<6; ++f)
         {
            while (MMIO(VGA_SCAN_LINE) > 480)
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
            while (MMIO(VGA_SCAN_LINE) <= 480)
            {}
         }
      }
   }

end:
   return 0;
}

