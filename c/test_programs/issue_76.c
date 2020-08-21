/*
   Displayed result: r=565, res=565
   Expected result:  r=565, res=190
*/

#include <stdio.h>

static unsigned long get_val()
{
  return 565;
}

static void test()
{
  unsigned long r = get_val();
  int res = r % 375;
  printf("r=%lu, res=%d\n", r, res);
}

int main()
{
  test();
}
