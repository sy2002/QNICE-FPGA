// A small test program
//
// When compiled with "qvc issue_175.c -O3" the program correctly outputs
// x=989, v=-20
//
// However, when compiled with "qvc issue_175.c" the program incorrectly outputs
// x=989, v=96

#include <stdio.h>

struct ss
{
   int x;
   int v;
   int r;
} s = {2000, 20, 10};


int main()
{
   struct ss *ps = &s;

   if (ps->x >= 1000-ps->r && ps->v > 0)
   {
      ps->x = 999-ps->r;
      ps->v = -ps->v;
   }
   printf("x=%d, v=%d\n", ps->x, ps->v);
   return 0;
}

