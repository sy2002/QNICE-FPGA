#include "tennis.h"

/* Game variables are declared here */

unsigned player_score;
unsigned bot_score;

unsigned player_life;
unsigned bot_life;

/*
 * This function is called once at start of the program
 */
void score_init()
{
   player_score = 0;
   bot_score = 0;

   player_life = 5;
   bot_life = 5;
} // end of score_init


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void score_draw()
{
   char buffer[10];
   int l = snprintf(buffer, 9, "%u", player_score);
   buffer[l] = 0;
   cputcxy(20, 10, '0' + player_life);
   cputsxy(20, 11, buffer, 0);

   l = snprintf(buffer, 9, "%u", bot_score);
   buffer[l] = 0;
   cputcxy(60, 10, '0' + bot_life);
   cputsxy(60, 11, buffer, 0);
} // end of score_draw


/*
 * This function is called once per frame, i.e. 60 times a second
 */
void score_update(int action)
{
   switch (action)
   {
      case SCORE_PLAYER_HIT  : bot_score += 10;    break;
      case SCORE_PLAYER_LOSE : player_life -= 1;   break;
      case SCORE_BOT_HIT     : player_score += 10; break;
      case SCORE_BOT_LOSE    : bot_life -= 1;      break;
   }
} // end of score_update

