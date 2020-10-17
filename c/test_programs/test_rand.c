/*  Simple test of the Random Number Generator
 *
 *  How to compile:  qvc test_rand.c
 *
 *  done by MJoergen in October 2020
*/

#include <stdio.h>
#include <qmon.h>

int main()
{
   /* Constant seed */
   qmon_srand(0x1234);

   /* Print 10 random numbers */
   for (int i=0; i<10; ++i)
   {
      printf("%d\n", qmon_rand());
   }

   /* Generate a large set of random numbers */
   for (unsigned int i=0; i<50000; ++i)
   {
      qmon_rand();
   }

   printf("\n");

   /* Print 10 more random numbers */
   for (int i=0; i<10; ++i)
   {
      printf("%d\n", qmon_rand());
   }

   return 0;
}

