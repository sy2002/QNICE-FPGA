
#ifndef _SPRITE_H_
#define _SPRITE_H_

typedef unsigned int t_sprite_palette[16];
#define sprite_palette_transparent \
{ \
   VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, \
   VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, \
   VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, \
   VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT, VGA_COLOR_TRANSPARENT \
}

typedef unsigned int t_sprite_bitmap[32*32/4];

void sprite_wr(unsigned int addr, unsigned int data);

void sprite_clear_all();

void sprite_set_palette(unsigned int sprite_num, const t_sprite_palette palette);

void sprite_set_bitmap(unsigned int sprite_num, const t_sprite_bitmap bitmap);

void sprite_set_bitmap_ptr(unsigned int sprite_num, int sprite_num_ptr);

void sprite_set_config(unsigned int sprite_num, unsigned int config);

void sprite_set_position(unsigned int sprite_num, int pos_x, int pos_y);

#endif // _SPRITE_H_
