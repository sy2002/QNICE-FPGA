#include "qmon.h"
#include "llemul.h"

#define HEADER udtyp __mulint32(ustyp low1,ustyp high1,ustyp dummy,ustyp low2,ustyp high2)
#define FOOTER

HEADER
{
    qmon_mulu32_int(low1, high1, low2, high2);
}
FOOTER
