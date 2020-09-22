#include "sysdef.h"
#include "sprite.h"

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

// low level write to Sprite RAM
void sprite_wr(unsigned int addr, unsigned int data)
{
   MMIO(VGA_SPRITE_ADDR) = addr;
   MMIO(VGA_SPRITE_DATA) = data;
} // end of sprite_wr

void sprite_set_palette(unsigned int sprite_num, const t_sprite_palette palette)
{
   unsigned int addr = VGA_SPRITE_PALETTE + sprite_num*16;
   for (int i=0; i<16; ++i)
   {
      sprite_wr(addr++, palette[i]);
   }
} // sprite_set_palette

void sprite_set_bitmap(unsigned int sprite_num, const t_sprite_bitmap bitmap)
{
   static unsigned int bitmap_ptr = VGA_SPRITE_BITMAP;   // Initialized to first free bitmap

   for (int i=0; i<32*32/4; ++i)
   {
      sprite_wr(bitmap_ptr+i, *(((const unsigned int *)bitmap) + i));
   }

   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_BITMAP_PTR + sprite_num*4, bitmap_ptr);

   bitmap_ptr += 32*32/4;                                // Update bitmap_ptr
} // sprite_set_bitmap

void sprite_set_config(unsigned int sprite_num, unsigned int config)
{
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_CSR + sprite_num*4, config);
} // sprite_set_config

void sprite_set_position(unsigned int sprite_num, int pos_x, int pos_y)
{
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_POS_X + sprite_num*4, pos_x);
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_POS_Y + sprite_num*4, pos_y);
} // sprite_set_position

