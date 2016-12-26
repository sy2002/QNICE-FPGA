#include "llemul.h"

#define HEADER udtyp __divmod(ustyp low1,ustyp high1,ustyp low2,ustyp high2,udtyp *modptr)
#define FOOTER

#include "_divmod.h"

#define negate(low,high) low=-low; high=-high; if (low>(ustyp)0) high--;

udtyp __divuint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)
{
  return __divmod(low1,high1,low2,high2,0);
}

sdtyp __divint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)
{
  int neg = 0;
  sdtyp result;

  if ((sstyp)high1 < 0) {
    neg ^= 1;
    negate(low1,high1);
  }
  if ((sstyp)high2 < 0) {
    neg ^= 1;
    negate(low2,high2);
  }
  result = (sdtyp)__divmod(low1,high1,low2,high2,0);
  return neg ? -result : result;
}

udtyp __moduint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)
{
  udtyp result;

  (void)__divmod(low1,high1,low2,high2,&result);
  return result;
}

sdtyp __modint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)
{
  int neg;
  sdtyp result;

  if ((sstyp)high1 < 0) {
    neg = 1;
    negate(low1,high1);
  }
  else
    neg = 0;
  if ((sstyp)high2 < 0) {
    negate(low2,high2);
  }
  (void)__divmod(low1,high1,low2,high2,&result);
  return neg ? -result : result;
}
