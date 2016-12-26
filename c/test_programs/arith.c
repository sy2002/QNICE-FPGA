#include <stdio.h>

main()
{
  long x,y;
  unsigned long a,b;

  printf("x,y: ");
  fflush(stdout);
  do{}while(scanf("%li,%li",&x,&y)!=2);

  printf("signed arithmetics\n");
  printf("%ld + %ld = %ld\n",x,y,x+y);
  printf("%ld - %ld = %ld\n",x,y,x-y);
  printf("%ld * %ld = %ld\n",x,y,x*y);
  printf("%ld / %ld = %ld\n",x,y,x/y);
  printf("%ld %% %ld = %ld\n",x,y,x%y);
  printf("%ld << %ld = %ld\n",x,y,x<<y);
  printf("%ld >> %ld = %ld\n",x,y,x>>y);
  printf("%ld & %ld = %ld\n",x,y,x&y);
  printf("%ld | %ld = %ld\n",x,y,x|y);
  printf("%ld ^ %ld = %ld\n",x,y,x^y);

  a=x;
  b=y;
  printf("unsigned arithmetics\n");
  printf("%lu + %lu = %lu\n",a,b,a+b);
  printf("%lu - %lu = %lu\n",a,b,a-b);
  printf("%lu * %lu = %lu\n",a,b,a*b);
  printf("%lu / %lu = %lu\n",a,b,a/b);
  printf("%lu %% %lu = %lu\n",a,b,a%b);
  printf("%lu << %lu = %lu\n",a,b,a<<b);
  printf("%lu >> %lu = %lu\n",a,b,a>>b);
  printf("%lu & %lu = %lu\n",a,b,a&b);
  printf("%lu | %lu = %lu\n",a,b,a|b);
  printf("%lu ^ %lu = %lu\n",a,b,a^b);


  printf("signed comp\n");
  if(x==y) puts("=="); else puts("!=");
  if(x!=y) puts("!="); else puts("==");
  if(x<y) puts("<"); else puts(">=");
  if(x>=y) puts(">="); else puts("<");
  if(x<=y) puts("<="); else puts(">");
  if(x>y) puts(">"); else puts("<=");

  printf("unsigned comp\n");
  if(a==b) puts("=="); else puts("!=");
  if(a!=b) puts("!="); else puts("==");
  if(a<b) puts("<"); else puts(">=");
  if(a>=b) puts(">="); else puts("<");
  if(a<=b) puts("<="); else puts(">");
  if(a>b) puts(">"); else puts("<=");

  exit(0);
}

