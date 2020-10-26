#ifndef _TENNIS_H_
#define _TENNIS_H_

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"
#include "sprite.h"
#include "conio.h"
#include "sprite.h"

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

extern const t_sprite_bitmap sprite_player;
extern const t_sprite_bitmap sprite_ball;


/* Define some useful constants */
extern const int CHAR_WIDTH;
extern const int SCREEN_WIDTH;
extern const int SCREEN_HEIGHT;
extern const int BAR_POS_CH;
extern const int BAR_HEIGHT_CH;
extern const int BAR_LEFT;
extern const int BAR_RIGHT;
extern const int BAR_TOP;
extern const int PLAYER_SPEED;
extern const int PLAYER_RADIUS;
extern const int SCREEN_LEFT;
extern const int SCREEN_RIGHT;
extern const int SCREEN_BOTTOM;
extern const int SCREEN_TOP;
extern const int WHITE_SQUARE;
extern const int BALL_RADIUS;
extern const int VEL_SCALE;
extern const int POS_SCALE;
extern const int GRAVITY;

typedef struct
{
   int x;
   int y;
} t_vec;

#endif // _TENNIS_H_

