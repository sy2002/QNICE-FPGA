#include "tennis.h"

/* Game variables are declared here */

static t_vec position;
static t_vec velocity;

extern t_vec player_position; // Position of player

/*
 * This is an optimized multiply routine.
 * It takes two 16-bit signed inputs and returns a 32-bit signed output.
 */
static long muls(int arg1, int arg2)
{
   // Using a union is much faster than performing explicit shifts.
   union {
      long l;
      int  i[2];
   } u;

   MMIO(IO_EAE_OPERAND_0) = arg1;
   MMIO(IO_EAE_OPERAND_1) = arg2;
   MMIO(IO_EAE_CSR)       = EAE_MULS;
   u.i[0] = MMIO(IO_EAE_RESULT_LO); // This implicitly assumes little-endian.
   u.i[1] = MMIO(IO_EAE_RESULT_HI);
   return u.l;
} // end of muls


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
 * This function is written based on this article:
 * https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
 */
static t_vec calcNewVelocity(t_vec pos1, t_vec pos2, t_vec vel1, t_vec vel2)
{
   t_vec delta_pos = {.x=pos1.x-pos2.x, .y=pos1.y-pos2.y};
   t_vec delta_vel = {.x=vel1.x-vel2.x, .y=vel1.y-vel2.y};

   // Since the radius is at most 16, the total distance is at most 32. With a scaling factor of 32,
   // the largest value of delta_pos.xy is 32*32 = 2^10. So the largest value of dpdp is 2^20.
   long dpdv = muls(delta_pos.x,delta_vel.x) + muls(delta_pos.y,delta_vel.y);
   long dpdp = muls(delta_pos.x,delta_pos.x) + muls(delta_pos.y,delta_pos.y);

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


static void collision_point(t_vec otherPos, int distance)
{
   t_vec delta_pos = {.x=otherPos.x-position.x, .y=otherPos.y-position.y};

   long x2 = muls(delta_pos.x, delta_pos.x);
   long y2 = muls(delta_pos.y, delta_pos.y);
   long r2 = muls(distance, distance);
   const t_vec zero = {0, 0};

   if (x2+y2 < r2)
   {
      velocity = calcNewVelocity(
            position,
            otherPos,
            velocity,
            zero);
   }
} // end of collision_point


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
int ball_update()
{
   position.x += velocity.x / (VEL_SCALE/POS_SCALE);
   position.y += velocity.y / (VEL_SCALE/POS_SCALE);

   /* Collision against left wall */
   if (position.x < POS_SCALE*(SCREEN_LEFT+BALL_RADIUS))
   {
      position.x = POS_SCALE*(SCREEN_LEFT+BALL_RADIUS);

      if (velocity.x < 0)
      {
         velocity.x = -velocity.x;
      }
   }

   /* Collision against right wall */
   if (position.x > POS_SCALE*(SCREEN_RIGHT-BALL_RADIUS))
   {
      position.x = POS_SCALE*(SCREEN_RIGHT-BALL_RADIUS);

      if (velocity.x > 0)
      {
         velocity.x = -velocity.x;
      }
   }

   /* Collision against top wall */
   if (position.y < POS_SCALE*SCREEN_TOP)
   {
      position.y = POS_SCALE*SCREEN_TOP;

      if (velocity.y < 0)
      {
         velocity.y = -velocity.y;
      }
   }

   /* Collision against left side of barrier */
   if (position.x > POS_SCALE*(BAR_LEFT-BALL_RADIUS) && position.y > POS_SCALE*(BAR_TOP-BALL_RADIUS))
   {
      position.x = POS_SCALE*(BAR_LEFT-BALL_RADIUS);

      if (velocity.x > 0)
      {
         velocity.x = -velocity.x;
      }
   }

   /* Collision against right side of barrier */
   if (position.x < POS_SCALE*(BAR_RIGHT+BALL_RADIUS) && position.y > POS_SCALE*(BAR_TOP-BALL_RADIUS))
   {
      position.x = POS_SCALE*(BAR_RIGHT+BALL_RADIUS);

      if (velocity.x < 0)
      {
         velocity.x = -velocity.x;
      }
   }

   /* Collision against top side of barrier */
   if (position.y > POS_SCALE*(BAR_TOP-BALL_RADIUS) &&
         position.x > POS_SCALE*(BAR_LEFT-BALL_RADIUS) &&
         position.x < POS_SCALE*(BAR_RIGHT+BALL_RADIUS))
   {
      position.y = POS_SCALE*(BAR_TOP-BALL_RADIUS);

      if (velocity.y > 0)
      {
         velocity.y = -velocity.y;
      }
   }

   const t_vec barTopLeft  = {BAR_LEFT, BAR_TOP};
   const t_vec barTopRight = {BAR_RIGHT, BAR_TOP};

   /* Collision against barrier corners */
   collision_point(barTopLeft, BALL_RADIUS);
   collision_point(barTopRight, BALL_RADIUS);

   /* Collision against player */
   collision_point(player_position, PLAYER_RADIUS+BALL_RADIUS);

   velocity.y += GRAVITY;

   return 0;
} // end of ball_update
