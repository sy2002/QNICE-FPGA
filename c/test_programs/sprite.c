#include "sysdef.h"
#include "sprite.h"

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

// low level write to Sprite RAM
void sprite_wr_addr(unsigned int addr)
{
   MMIO(VGA_SPRITE_ADDR) = addr;
} // end of sprite_wr_addr


// low level write to Sprite RAM
void sprite_wr_data(unsigned int data)
{
   MMIO(VGA_SPRITE_DATA) = data;
} // end of sprite_wr_data


// low level write to Sprite RAM
void sprite_wr(unsigned int addr, unsigned int data)
{
   sprite_wr_addr(addr);
   sprite_wr_data(data);
} // end of sprite_wr


void sprite_clear_all()
{
   for (int i=0; i<128; ++i)
   {
      sprite_wr_addr(VGA_SPRITE_CONFIG + VGA_SPRITE_CSR + i*4);
      sprite_wr_data(0);
   }
}

void sprite_set_palette(unsigned int sprite_num, const t_sprite_palette palette)
{
   unsigned int addr = VGA_SPRITE_PALETTE + sprite_num*16;

   sprite_wr_addr(addr);
   for (int i=0; i<16; ++i)
   {
      sprite_wr_data(palette[i]);
   }
} // sprite_set_palette


void sprite_set_bitmap(unsigned int sprite_num, const t_sprite_bitmap bitmap)
{
   unsigned int addr = VGA_SPRITE_BITMAP + sprite_num*(32*32/4);
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_BITMAP_PTR + sprite_num*4, addr);

   sprite_wr_addr(addr);
   for (int i=0; i<32*32/4; ++i)
   {
      sprite_wr_data(bitmap[i]);
   }
} // sprite_set_bitmap


void sprite_set_bitmap_ptr(unsigned int sprite_num, int sprite_num_ptr)
{
   unsigned int addr = VGA_SPRITE_BITMAP + sprite_num_ptr*(32*32/4);
   sprite_wr_addr(VGA_SPRITE_CONFIG + VGA_SPRITE_BITMAP_PTR + sprite_num*4);
   sprite_wr_data(addr);
} // sprite_set_bitmap_ptr


void sprite_set_config(unsigned int sprite_num, unsigned int config)
{
   sprite_wr_addr(VGA_SPRITE_CONFIG + VGA_SPRITE_CSR + sprite_num*4);
   sprite_wr_data(config);
} // sprite_set_config


void sprite_set_position(unsigned int sprite_num, int pos_x, int pos_y)
{
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_POS_X + sprite_num*4, pos_x);
   sprite_wr(VGA_SPRITE_CONFIG + VGA_SPRITE_POS_Y + sprite_num*4, pos_y);
} // sprite_set_position

