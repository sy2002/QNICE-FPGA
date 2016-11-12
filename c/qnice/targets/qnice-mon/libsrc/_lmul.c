#include "qmon-ep.h"
#include "llemul.h"

#define MACRO_STRINGIFY(x) #x
#define M2S(x) MACRO_STRINGIFY(x)

#define HEADER udtyp __mulint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)

unsigned long qmon_mulu32_int(unsigned int a_lo, unsigned int a_hi) = 
  "          MOVE     @R13++, R11\n"
  "          MOVE     @R13, R10\n"
  "          SUB      1, R13\n"
  "          ASUB     " M2S(QMON_EP_MULU32) ", 1\n";    //call MTH$MULU32 in monitor

HEADER
{
    qmon_mulu32_int(low1, high1);
}
FOOTER
