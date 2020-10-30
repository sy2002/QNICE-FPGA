#include <qmon.h>
#include "tennis.h"

/* Game variables are declared here */

t_vec ball_position;
t_vec ball_velocity;

extern t_vec player_position; // Located in tennis_player.c
extern t_vec bot_position;    // Located in tennis_bot.c


/*
 * This function calculates (x*y)/z.
 */
static int muldiv(long x, long y, long z)
{
   // Since the multiplication x*y may overflow, we instead scale x and z with
   // the constant value k.
   const int k = VEL_SCALE;

   // We write x = q*k + r, where r = x mod k.
   const long q = x/k;
   const long r = x - q*k;    // |r| < k

   // We write z = s*k + t, where t = z mod k.
   const long s = z/k;
   const long t = z - s*k;    // |t| < k

   // We write q*y = a*s + p, where p = q*y mod s.
   const long a = (q*y)/s;
   const long p = q*y - a*s;  // |p| < s

   // At this stage, "a" is a first approximation to (x*y)/z.

   // Now we calculate the deviation u=x*y-a*z
   // = (q*k+r)*y - a*(s*k+t)
   // = (q*y-a*s)*k + r*y - a*t
   // This calculation won't overflow, because |p*k| < |s*k| < |z|.
   const long u = p*k + r*y - a*t;

   // A better approximation is now "a + u/z".

   // Finally handle the rounding, based on the deviation.
   int res = a;
   if (u > z/2)
      res += 1;
   if (u < -z/2)
      res -= 1;

   return res;
} // end of muldiv


/*
 * Calculate the dot product of two vectors
 */
static long vector_dot(t_vec vec1, t_vec vec2)
{
   return qmon_muls(vec1.x, vec2.x) + qmon_muls(vec1.y, vec2.y);
} // end of vector_dot


/*
 * This function is written based on this article:
 * https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
 */
static t_vec calcNewVelocity(t_vec pos1, t_vec pos2, t_vec vel1, t_vec vel2)
{
   t_vec delta_pos = {.x=pos1.x-pos2.x, .y=pos1.y-pos2.y};
   t_vec delta_vel = {.x=vel1.x-vel2.x, .y=vel1.y-vel2.y};

   long dpdv = vector_dot(delta_pos, delta_vel);
   long dpdp = vector_dot(delta_pos, delta_pos);

   t_vec result = vel1;
   if (dpdv < 0)
   {
      long dividend = 2L*(-dpdv);
      long divisor = dpdp;

      result.x += muldiv(dividend, delta_pos.x, divisor);
      result.y += muldiv(dividend, delta_pos.y, divisor);
   }

   return result;
} // end of calcNewVelocity


/*
 * This function handles collision between the ball and a moving circle.
 */
static void collision_circle(t_vec *pOtherPos, int otherRadius)
{
   // Construct vector from ball to other circle
   t_vec vector_to_other = {.x=pOtherPos->x-ball_position.x, .y=pOtherPos->y-ball_position.y};

   // Calculate current distance squared
   long current_dist2 = vector_dot(vector_to_other, vector_to_other);

   // Calculate required distance
   int required_distance = otherRadius + BALL_RADIUS*POS_SCALE;

   // Calculate required distance squared
   long required_dist2 = qmon_muls(required_distance, required_distance);

   // Check whether a collision has actually occurred
   if (current_dist2 < required_dist2)
   {
      // Update position of ball. This is done by the formula
      //   delta_pos = (required_distance - current_distance) / current_distance * vector_to_other
      // But calculating the current_distance involves a square root, so instead
      // we use the following approximate formula
      //   delta_pos = (required_distance^2 - current_distance^2) / (2*required_distance^2) * vector_to_other
      long dividend = required_dist2 - current_dist2;
      long divisor = 2*required_dist2;

      int dx = muldiv(dividend, vector_to_other.x, divisor);
      int dy = muldiv(dividend, vector_to_other.y, divisor);

      // If the other object is a circle, move both objects an equal amount in the X-direction
      if (otherRadius)
      {
         ball_position.x -= dx/2;
         pOtherPos->x += dx/2;

         ball_position.y -= dy;
      }
      else // if the other object is a point, move only the ball
      {
         ball_position.x -= dx;
         ball_position.y -= dy;
      }

      const t_vec zero_velocity = {0, 0};
      ball_velocity = calcNewVelocity(ball_position, *pOtherPos, ball_velocity, zero_velocity);
   }
} // end of collision_circle


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

   ball_position.x = 198*POS_SCALE;
   ball_position.y = 180*POS_SCALE;

   ball_velocity.x = 0*VEL_SCALE;
   ball_velocity.y = 0*VEL_SCALE;
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
         ball_position.x/POS_SCALE-SPRITE_RADIUS,
         ball_position.y/POS_SCALE-SPRITE_RADIUS);
} // end of ball_draw


/*
 * This function is called once per frame, i.e. 60 times a second
 */
int ball_update()
{
   ball_position.x += ball_velocity.x / (VEL_SCALE/POS_SCALE);
   ball_position.y += ball_velocity.y / (VEL_SCALE/POS_SCALE);

   /* Ball fell out of bottom of screen */
   if (ball_position.y > POS_SCALE*(SCREEN_BOTTOM+BALL_RADIUS))
   {
      return 1;
   }

   /* Collision against left wall */
   if (ball_position.x < POS_SCALE*(SCREEN_LEFT+BALL_RADIUS))
   {
      ball_position.x = POS_SCALE*(SCREEN_LEFT+BALL_RADIUS);

      if (ball_velocity.x < 0)
      {
         ball_velocity.x = -ball_velocity.x;
      }
   }

   /* Collision against right wall */
   if (ball_position.x > POS_SCALE*(SCREEN_RIGHT-BALL_RADIUS))
   {
      ball_position.x = POS_SCALE*(SCREEN_RIGHT-BALL_RADIUS);

      if (ball_velocity.x > 0)
      {
         ball_velocity.x = -ball_velocity.x;
      }
   }

   /* Collision against top wall */
   if (ball_position.y < POS_SCALE*(SCREEN_TOP+BALL_RADIUS))
   {
      ball_position.y = POS_SCALE*(SCREEN_TOP+BALL_RADIUS);

      if (ball_velocity.y < 0)
      {
         ball_velocity.y = -ball_velocity.y;
      }
   }

   /* Collision against left side of barrier */
   if (ball_position.x > POS_SCALE*(BAR_LEFT-BALL_RADIUS) &&
       ball_position.x < POS_SCALE*BAR_MIDDLE &&
       ball_position.y > POS_SCALE*BAR_TOP)
   {
      ball_position.x = POS_SCALE*(BAR_LEFT-BALL_RADIUS);

      if (ball_velocity.x > 0)
      {
         ball_velocity.x = -ball_velocity.x;
      }
   }

   /* Collision against right side of barrier */
   if (ball_position.x > POS_SCALE*BAR_MIDDLE &&
       ball_position.x < POS_SCALE*(BAR_RIGHT+BALL_RADIUS) &&
       ball_position.y > POS_SCALE*BAR_TOP)
   {
      ball_position.x = POS_SCALE*(BAR_RIGHT+BALL_RADIUS);

      if (ball_velocity.x < 0)
      {
         ball_velocity.x = -ball_velocity.x;
      }
   }

   /* Collision against top side of barrier */
   if (ball_position.y > POS_SCALE*(BAR_TOP-BALL_RADIUS) &&
       ball_position.x > POS_SCALE*BAR_LEFT &&
       ball_position.x < POS_SCALE*BAR_RIGHT)
   {
      ball_position.y = POS_SCALE*(BAR_TOP-BALL_RADIUS);

      if (ball_velocity.y > 0)
      {
         ball_velocity.y = -ball_velocity.y;
      }
   }

   t_vec barTopLeft  = {BAR_LEFT*POS_SCALE,  BAR_TOP*POS_SCALE};
   t_vec barTopRight = {BAR_RIGHT*POS_SCALE, BAR_TOP*POS_SCALE};

   /* Collision against player */
   collision_circle(&player_position, PLAYER_RADIUS*POS_SCALE);
   player_position.y = 480*POS_SCALE;

   /* Collision against bot */
   collision_circle(&bot_position, BOT_RADIUS*POS_SCALE);
   bot_position.y = 480*POS_SCALE;

   /* Collision against barrier corners */
   collision_circle(&barTopLeft,  0);
   collision_circle(&barTopRight, 0);

   ball_velocity.y += GRAVITY;

   return 0;
} // end of ball_update

