#include "tennis.h"

/* Game variables are declared here */

t_vec bot_position;
t_vec bot_velocity;

extern t_vec ball_position;    // Located in tennis_ball.c

/*
 * This function is called once at start of the program
 */
void bot_init()
{
   /* Define player sprite */
   t_sprite_palette palette = sprite_palette_transparent;
   palette[1] = VGA_COLOR_WHITE;
   sprite_set_palette(2, palette);
   sprite_set_bitmap(2, sprite_player);
   sprite_set_config(2, VGA_SPRITE_CSR_VISIBLE);

   bot_position.x = 500*POS_SCALE;
   bot_position.y = 480*POS_SCALE;

   bot_velocity.x = 0*VEL_SCALE;
   bot_velocity.y = 0*VEL_SCALE;
} // end of bot_init


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void bot_draw()
{
   /*
    * The bot is shown as a semi cirle, and the variable bot_position
    * gives the centre of this circle. However, sprite coordinates are the upper
    * left corner of the sprite. Therefore, we have to adjust the coordinates
    * with the size of the sprite.
    */
   sprite_set_position(2,
         bot_position.x/POS_SCALE-SPRITE_RADIUS,
         bot_position.y/POS_SCALE-SPRITE_RADIUS);
} // end of bot_draw


int prevent_possible_compiler_bug = 0;

/*
 * This function is called once per frame, i.e. 60 times a second
 */
void bot_update()
{
   /* Aimly slight to the right of the ball, so that a collision will tend to
    * push the ball towards the player */
   int target_x = ball_position.x + 3*POS_SCALE;

   /* Calculate distance to target */
   int diff_x = target_x - bot_position.x;

   /* Limit speed of movement */
   if (diff_x > BOT_SPEED*POS_SCALE)
   {
      bot_velocity.x = BOT_SPEED*VEL_SCALE;
   }
   else if (diff_x < -BOT_SPEED*POS_SCALE)
   {
      bot_velocity.x = -BOT_SPEED*VEL_SCALE;
   }
   else
   {
      bot_velocity.x = diff_x * (VEL_SCALE/POS_SCALE);
   }

   /* Move bot */
   bot_position.x += bot_velocity.x / (VEL_SCALE/POS_SCALE);
   bot_position.y += bot_velocity.y / (VEL_SCALE/POS_SCALE);

   /* Handle collision with right side */
   if (bot_position.x >= POS_SCALE * (SCREEN_RIGHT - BOT_RADIUS))
   {
      bot_position.x = POS_SCALE * (SCREEN_RIGHT - BOT_RADIUS);
   }

   /* Handle collision with left side */
   if (bot_position.x < POS_SCALE * (BAR_RIGHT + BOT_RADIUS))
   {
      bot_position.x = POS_SCALE * (BAR_RIGHT + BOT_RADIUS);
   }

   /* Without this line, the program crashes when the last if-branch above is taken */
   ++prevent_possible_compiler_bug;
} // end of bot_update

