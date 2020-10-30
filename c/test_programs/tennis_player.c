#include "tennis.h"

/* Game variables are declared here */

static int move_left;      // Current status of LEFT cursor key
static int move_right;     // Current status of RIGHT cursor key

t_vec player_position;
t_vec player_velocity;


/*
 * This function is called once at start of the program
 */
void player_init()
{
   /* Define player sprite */
   t_sprite_palette palette = sprite_palette_transparent;
   palette[1] = VGA_COLOR_WHITE;
   sprite_set_palette(0, palette);
   sprite_set_bitmap(0, sprite_player);
   sprite_set_config(0, VGA_SPRITE_CSR_VISIBLE);

   player_position.x = 200*POS_SCALE;
   player_position.y = 480*POS_SCALE;

   player_velocity.x = 0*VEL_SCALE;
   player_velocity.y = 0*VEL_SCALE;

   move_left  = 0;
   move_right = 0;
} // end of player_init


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void player_draw()
{
   /*
    * The player is shown as a semi cirle, and the variable player_position
    * gives the centre of this circle. However, sprite coordinates are the upper
    * left corner of the sprite. Therefore, we have to adjust the coordinates
    * with the size of the sprite.
    */
   sprite_set_position(0,
         player_position.x/POS_SCALE-SPRITE_RADIUS,
         player_position.y/POS_SCALE-SPRITE_RADIUS);
} // end of player_draw


/*
 * This function is called once per frame, i.e. 60 times a second
 */
int player_update()
{
   /* Update state of player movement keys */
   int ev = MMIO(IO_KBD_EVENT);
   switch (ev)
   {
      case KBD_CUR_LEFT              : move_left  = 1; break;
      case KBD_CUR_RIGHT             : move_right = 1; break;
      case KBD_CUR_LEFT  | KBD_BREAK : move_left  = 0; break;
      case KBD_CUR_RIGHT | KBD_BREAK : move_right = 0; break;
      case 'q'                       : return 1;   /* q   : Quit program */
      case 'Q'                       : return 1;   /* Q   : Quit program */
      case 0x1b                      : return 1;   /* ESC : Quit program */
      case 0x03                      : return 1;   /* ^C  : Quit program */
#ifdef DEBUG
      default                        : if (ev) {printf("%04x\n", ev);} break;
#endif
   }

   /* Calculate player velocity */
   if (move_right && !move_left)
      player_velocity.x = PLAYER_SPEED*VEL_SCALE;
   else if (!move_right && move_left)
      player_velocity.x = -PLAYER_SPEED*VEL_SCALE;
   else
      player_velocity.x = 0;

   /* Move player */
   player_position.x += player_velocity.x / (VEL_SCALE/POS_SCALE);
   player_position.y += player_velocity.y / (VEL_SCALE/POS_SCALE);

   /* Handle collision with right side */
//   if (player_position.x >= POS_SCALE * (BAR_LEFT - PLAYER_RADIUS))
//      player_position.x = POS_SCALE * (BAR_LEFT - PLAYER_RADIUS);
   if (player_position.x >= POS_SCALE * (SCREEN_RIGHT - PLAYER_RADIUS))
   {
      player_position.x = POS_SCALE * (SCREEN_RIGHT - PLAYER_RADIUS);
   }

   /* Handle collision with left side */
   if (player_position.x < POS_SCALE * (SCREEN_LEFT + PLAYER_RADIUS))
   {
      player_position.x = POS_SCALE * (SCREEN_LEFT + PLAYER_RADIUS);
   }

   return 0;
} // end of player_update

