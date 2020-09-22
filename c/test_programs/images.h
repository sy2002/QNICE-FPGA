/*  VGA Sprite demonstration
 *
 *  This program demonstrates bouncing balls using all 128 sprites.
 *
 *  How to compile: qvc demo_sprite_balls.c -O3 -c99
 *
 *  done by MJoergen in September 2020
*/

#ifndef _IMAGES_H_
#define _IMAGES_H_

#include "sprite.h"

#define NUM_IMAGES 2

struct
{
   unsigned int radius_scaled;
   unsigned int mass;
   const t_sprite_bitmap *sprite_bitmap;
} images[NUM_IMAGES];

#endif // _IMAGES_H_

