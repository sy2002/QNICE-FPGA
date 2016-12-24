/*
    Test a sequence of malloc/free
    We are not using stdio by intension to avoid malloc/free side effects.
    done by sy2002 in December 2016
*/

#include <stdlib.h>
#include "qmon.h"

int main()
{
    int i;
    char* linebuffer = 0;
    for (i = 0; i < 50; i++)
    {
        qmon_puts("[malloc_test]: Iteration #");
        qmon_puthex(i);
        qmon_crlf();

        if (!linebuffer)
        {
            qmon_puts("[malloc_test]: linebuffer was 0. trying to malloc...\n\r");
            if (linebuffer = malloc(160))
            {
                qmon_puts("[malloc_test]: malloc OK. linebuffer = ");
                qmon_puthex((int) linebuffer);
                qmon_crlf();
            }
            else
            {
                qmon_puts("[malloc_test]: MALLOC FAILED!\n\r");
                qmon_exit();
            }
        }
        else
        {
            qmon_puts("[malloc_test]: freeing linebuffer, which is ");
            qmon_puthex((int) linebuffer);
            qmon_crlf();
            free(linebuffer);
            linebuffer = (char*) 0;
        }
    }
}
