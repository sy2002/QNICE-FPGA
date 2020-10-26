#include "tennis.h"

/* Game variables are declared here */

static t_vec position;
static t_vec velocity;


/*
 * This function is called once at start of the program
 */
void ball_init()
{
   /* Define player sprite */
   t_sprite_palette palette = sprite_palette_transparent;
   palette[1] = VGA_COLOR_RED;
   sprite_set_palette(1, palette);
   sprite_set_bitmap(1, sprite_ball);
   sprite_set_config(1, VGA_SPRITE_CSR_VISIBLE);

   position.x = 200*POS_SCALE;
   position.y = 80*POS_SCALE;

   velocity.x = 0;
   velocity.y = 0;
} // end of player_init


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void ball_draw()
{
   /*
    * The player is shown as a semi cirle, and the variables pos_x and pos_y
    * give the centre of this circle. However, sprite coordinates are the upper
    * left corner of the sprite. Therefore, we have to adjust the coordinates
    * with the size of the sprite.
    */
   sprite_set_position(1,
         position.x/POS_SCALE-BALL_RADIUS,
         position.y/POS_SCALE-BALL_RADIUS);
} // end of ball_draw


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void ball_update()
{
   position.x += velocity.x / (VEL_SCALE/POS_SCALE);
   position.y += velocity.y / (VEL_SCALE/POS_SCALE);

   velocity.y += GRAVITY;
} // end of ball_update

