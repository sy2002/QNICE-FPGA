/*
 * The Park-Miller Random Number Generator, using two 16x16 bit multiplies.
 * done by MJoergen in August 2020
 */

static unsigned long g_seed;

void my_srand(unsigned long seed)
{
   g_seed = seed + 3; // Avoid setting the seed to zero.
} // my_srand

unsigned long my_rand()
{
	const unsigned long A = 48271;

   // TBD: Rewrite to make use of EAE on the QNICE platform.
	unsigned long low  = (g_seed & 0x7fff) * A;
	unsigned long high = (g_seed >> 15)    * A;

	unsigned long x = low + ((high & 0xffff) << 15) + (high >> 16);

	x = (x & 0x7fffffff) + (x >> 31);
   g_seed = x;

   return (g_seed >> 8) & 0x7FFF; // Make sure number is positive.
} // my_rand

