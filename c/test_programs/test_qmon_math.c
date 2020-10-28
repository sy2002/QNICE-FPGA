/* Test program for monitor-lib's math functions.

   These functions are faster than other mechanisms such as VBCC's
   native mechanism, because VBCC does not support the special case
   16-bit input => 32-bit outpout.

   done by sy2002 in October 2020
*/

#include <stdio.h>
#include "qmon.h"

int main()
{
    printf("This program tests monitor-lib's math functions.\n\n");

    int a, b, c;
    unsigned int au, bu, cu, mu;

    printf("qmon_muls: signed: 16-bit * 16-bit = 32-bit\n");
    scanf("%i", &a);
    scanf("%i", &b);
    printf("a = %i, b = %i, a * b = %li\n\n", a, b, qmon_muls(a, b));

    printf("qmon_mulu: unsigned: 16-bit * 16-bit = 32-bit\n");
    scanf("%u", &au);
    scanf("%u", &bu);
    printf("au = %u, bu = %u, au * bu = %lu\n\n", au, bu, qmon_mulu(au, bu));

    printf("qmon_divmod_s: signed: 16-bit / 16-bit = 16-bit and ditto modulo:\n");
    scanf("%i", &a);
    scanf("%i", &b);
    c = qmon_divmod_s(a, b, &mu);
    printf("a = %i, b = %i, a / b = %i, a %% b = %u\n", a, b, c, mu);

    /* Check if qmon_divs, which is internally just a wrapper of
       qmon_divmod_s works, too */
    if (qmon_divs(a, b) != c)
        printf("ERROR: qmon_divs does not work!\n");
    printf("\n");

    printf("qmon_divmod_u: unsigned: 16-bit / 16-bit = 16-bit and ditto modulo:\n");
    scanf("%u", &au);
    scanf("%u", &bu);
    cu = qmon_divmod_u(au, bu, &mu);
    printf("au = %u, bu = %u, au / bu = %u, au %% bu = %u\n", au, bu, cu, mu);

    /* Check if qmon_divu, which is internally just a wrapper of
       qmon_divmod_u works, too */
    if (qmon_divu(au, bu) != cu)
        printf("ERROR: qmon_divu does not work!\n");
    printf("\n");

    return 0;
}
