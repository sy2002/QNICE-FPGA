/*
 * The Park-Miller Random Number Generator, using two 16x16 bit multiplies.
 * done by MJoergen in October 2020
 */


/*
 * The use of union here allows easy access to the upper 16 bits and lower 16
 * bits of the corresponding 32 bit value.
 */

typedef union
{
   unsigned long ul;
   unsigned short us[2];
} ul_union_t;

static ul_union_t g_seed;


void my_srand(unsigned long seed)
{
   g_seed.ul = seed + 3; /* Avoid setting the seed to zero. */
} /* my_srand */


/*
 * The seed is updated using the following calculation:
 *
 * X' = a*X mod n,
 *
 * where a = 48271 and n = 2^31-1.
 *
 * A crucial detail in this implementation is that the value of X is less than
 * 2^31, i.e.  the MSB is always 0.
 */
unsigned long my_rand()
{
	const unsigned long A = 48271;

   /* Here we extract bits 14-0 and multiply by A */
   /* The result will be less than 2^31-1 */
   ul_union_t low;
   low.ul = (g_seed.us[0] & 0x7fff) * A;

   /* Here we extract bits 30-15 and multiply by A */
	ul_union_t high;
	high.ul = ((g_seed.us[1]<<1) + (g_seed.us[0] >> 15)) * A;

   /* At this stage we have the following equlity: */
   /* high*2^15 + low = seed * A */

   /* The sum y+z is equal to (high*2^15) mod (2^31-1). */
   ul_union_t y,z;
   y.us[1] = high.us[0] >> 1;
   y.us[0] = high.us[1];
   z.us[1] = 0;
   z.us[0] = (high.us[0] & 1) << 15;

   ul_union_t x;
   x.ul = low.ul + y.ul + z.ul;

   /* The value of x is always less than 2^32-2 here. */

   ul_union_t w;
   w.us[1] = 0;
   w.us[0] = x.us[1] >> 15;

   x.us[1] &= 0x7fff;
   x.ul += w.ul;

   g_seed.ul = x.ul;

   return g_seed.us[1]; // This is always positive.
} // my_rand

