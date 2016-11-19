/*
    __close.c is an abstraction for the Standard C Library that is used
    to close a file handle

    done by sy2002 in November 2016
*/

#include <stdio.h>
#include <stdlib.h>
#include "qmon.h"

void __close(int h)
{
    free((fat32_file_handle*) h);
}

