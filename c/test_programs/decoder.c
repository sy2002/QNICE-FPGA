/*
 *  decoder.c
 *
 *  This tool transforms the output of lvgl's image converter to a format
 *  that can be processed in a QNICE-FPGA demo such as world.c. 24-bit RGB
 *  to QNICE's 15-bit RGB palette conversion is included.
 *
 *  done by MJoergen in September 2020
 *
 *  Here is the workflow of how to obtain such an image:
 *
 *  1. Go to a site like opengameart.org and grab some content.
 * 
 *     We used this here:
 *     https://opengameart.org/content/15-planet-sprites
 *     by Viktor Hahn (Viktor.Hahn@web.de), who licensed it under CC BY 4.0
 *
 *  2. Use an image processing tool to make sure the image has a size that is
 *     in x and y direction a multiple of the target sprite defined in 
 *     the define "SPRITE_SIZE" below. Normally, SPRITE_SIZE is 16 or 32.
 *
 *  3. Use an image processing tool such as GIMP or Photoshop and reduce the
 *     image to the so called "indexed color mode", which means that the
 *     image has a palette in contrast to True Color or High Color. Choose
 *     16 colors. Make sure that you play with GIMP's or Photoshop's palette
 *     conversion and dithering options to obtain the best quality.
 *
 *  4. Save as PNG.
 * 
 *  5. Go to https://lvgl.io/tools/imageconverter, choose "indexed 16 colors"
 *     and make a C file by choosing "C array". Do not check any dithering
 *     option. If this website is not there any more, here is the source
 *     code on GitHub:
 *     https://github.com/lvgl/lv_utils/blob/master/img_conv_core.php
 *
 *  6. Save the resulting C file to e.g. planet.c
 *
 *  7. Compile this program together with the saved C-file, e.g.
 *     gcc decoder.c planet.c -o decoder_planet
 *
 *  8. Run the compiled result and save the output to a new file, e.g. planet_sprite.c
 * 
 *  9. This generated file can now be used directly in Q-NICE.
*/

#include <stdint.h>
#include <stdio.h>
#include "lvgl.h"

#define NAME atom

// We assume the resulting sprites are 32x32 pixels.
#define SPRITE_SIZE 32

extern const lv_img_dsc_t NAME;

int main()
{
   printf("#include \"sprite.h\"\n");

   // We assume the palette contains 16 colors.
   printf("const t_sprite_palette palette = {\n");
   for (int i=0; i<16; ++i)
   {
      uint8_t b = NAME.data[4*i];
      uint8_t g = NAME.data[4*i+1];
      uint8_t r = NAME.data[4*i+2];
      uint8_t a = NAME.data[4*i+3];
      uint16_t qnice_col = (r/8)*32*32 + (g/8)*32 + (b/8);
      printf("   0x%04x, \n", qnice_col);
   }
   printf("};\n\n");

   const uint8_t *pBitmap = &NAME.data[16*4];

   const int sprites_x = NAME.header.w/SPRITE_SIZE;
   const int sprites_y = NAME.header.h/SPRITE_SIZE;

   const int num_sprites = sprites_x*sprites_y;

   printf("const t_sprite_bitmap bitmaps[%d] = {\n", num_sprites);

   for (int sprite = 0; sprite < num_sprites; ++sprite)
   {
      printf("{\n");
      int pixel_offset = (sprite/sprites_x)*SPRITE_SIZE*NAME.header.w +
                         (sprite%sprites_x)*SPRITE_SIZE;

      printf("// Sprite number=%d, pixel_offset=%d\n", sprite, pixel_offset);

      for (int dy=0; dy<SPRITE_SIZE; ++dy)
      {
         printf("   ");
         // We assume that four pixels can fit into a QNICE word.
         for (int dx=0; dx<SPRITE_SIZE/4; ++dx)
         {
            // We assume two pixels per byte.
            uint8_t msb = pBitmap[(pixel_offset+dy*NAME.header.w+4*dx)/2];
            uint8_t lsb = pBitmap[(pixel_offset+dy*NAME.header.w+4*dx)/2+1];
            printf("0x%04x, ", msb*256+lsb);
         }
         printf("\n");
      }
      printf("},\n\n");
   }
   printf("};\n\n");
} // main

