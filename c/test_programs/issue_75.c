/*
   This simple test program is supposed to output 4
   It was seen that compiling with optimization it works,
   but without optimization it fails.
   So this must be retested with all levels of optimization, i.e.
   * qvc test.c
   * qvc test.c -O
   * qvc test.c -O0
   * qvc test.c -O1
   * qvc test.c -O2
   * qvc test.c -O3

   Details:
   https://github.com/sy2002/QNICE-FPGA/issues/75
*/

#include <stdio.h>

char grid[16];

int main()
{
   int sq = 9;
   int dir = 2;

   grid[sq] = 0;

   grid[sq] += 1 << (dir);
   printf("%d\n", grid[sq]);

   return 0;
}

