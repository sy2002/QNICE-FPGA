#include <stdio.h>

static unsigned int count;
static long sum;
static int min;
static int max;

void stat_clear()
{
   count = 0;
   sum = 0;
   min = 32767;
   max = -32768;
}

void stat_update(int data)
{
   count += 1;
   sum += data;

   if (data < min)
      min = data;

   if (data > max)
      max = data;
}

void stat_show()
{
   printf("Mean = %ld\n", sum/count);
   printf("Min = %d\n", min);
   printf("Max = %d\n", max);
}

