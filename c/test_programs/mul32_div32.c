#ifndef __QNICE__
#error This is a QNICE specific program.
#endif

#define getchar(x) ((fp)0x0002)(x)
#define gets(x)    ((fp)0x0006)(x)
#define putsnl(x)  ((fp)0x0008)(x)
#define exit(x)    ((fp)0x0016)(x)

typedef int (*fp)();

static void puts(char* p)
{
  putsnl(p);
  putsnl("\n\r");
}

int main()
{
    long a = 239197600;
    long b = 23;
    long res_div = a / b;
    long res_mod = a % b;
    exit(0);
}