/* 16-bit HyperRAM testbed
   
   Original purpose: Help to debug and solve the issues
   https://github.com/MEGA65/mega65-core/issues/280
   and
   https://github.com/MEGA65/mega65-core/issues/280

   done by sy2002 in October 2020
*/


#include <stdio.h>
#include "sysdef.h"

#define QNICE_HRAM( __x ) *((unsigned int volatile *) __x )

int main()
{
    return 0;
}