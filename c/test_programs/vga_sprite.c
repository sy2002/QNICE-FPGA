/*  VGA Sprite demonstration
 *
 *  How to compile: qvc vga_sprite.c -O3 -c99
 *
 *  done by MJoergen in September 2020
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

// low level write to Sprite RAM
static void sprite_wr(unsigned int addr, unsigned int data)
{
   MMIO(VGA_SPRITE_ADDR) = addr;
   MMIO(VGA_SPRITE_DATA) = data;
} // end of sprite_wr

typedef struct
{
   unsigned int pos_x;
   unsigned int pos_y;
   unsigned int bitmap_ptr;
   unsigned int csr;
} t_sprite_config;

// write configuration of a sprite
static void sprite_wr_config(int sprite_num, t_sprite_config config)
{
   unsigned int addr = sprite_num*4 + VGA_SPRITE_CONFIG;
   sprite_wr(addr++, config.pos_x);
   sprite_wr(addr++, config.pos_y);
   sprite_wr(addr++, config.bitmap_ptr);
   sprite_wr(addr, config.csr);
} // end of sprite_wr_config

// write palette of a sprite
static void sprite_wr_palette(int sprite_num, unsigned int palette[16])
{
   unsigned int addr = sprite_num*16 + VGA_SPRITE_PALETTE;
   unsigned int *p = &palette[0];
   for (int i=0; i<16; ++i)
   {
      sprite_wr(addr++, *p++);
   }
} // end of sprite_wr_palette

// write bitmap of a sprite
static void sprite_wr_bitmap(unsigned int addr, unsigned int bitmap[32*32/4])
{
   unsigned int *p = &bitmap[0];
   for (int i=0; i<32*32/4; ++i)
   {
      sprite_wr(addr++, *p++);
   }
} // end of sprite_wr_bitmap


int main()
{
   // Enable sprites
   MMIO(VGA_STATE) |= VGA_EN_SPRITE;

   // Set background color
   MMIO(VGA_PALETTE_OFFS) = VGA_PALETTE_OFFS_USER;
   MMIO(VGA_PALETTE_ADDR) = VGA_PALETTE_OFFS_USER+16;
   MMIO(VGA_PALETTE_DATA) = 0xFFFF;

   // Place sprite in the middle of the screen
   t_sprite_config sprite0 = {.pos_x=320-16,
                              .pos_y=240-16,
                              .bitmap_ptr=VGA_SPRITE_BITMAP,
                              .csr=VGA_SPRITE_CSR_VISIBLE};
   // Just a random palette that is easy to recognize
   unsigned int palette[16] = {0x0000, 0x1111, 0x2222, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777,
                               0x8888, 0x9999, 0xAAAA, 0xBBBB, 0xCCCC, 0xDDDD, 0xEEEE, 0xFFFF};

   // A sprite with a top border and a left border
   unsigned int bitmap[32*32/4] = {0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF,
                                   0xE000};

   sprite_wr_config(0, sprite0);
   sprite_wr_palette(0, palette);
   sprite_wr_bitmap(VGA_SPRITE_BITMAP, palette);

   qmon_gets();
   return 0;
} // main

