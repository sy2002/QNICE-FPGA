/*
    __close.c is an abstraction for the Standard C Library that is used
    to close a file handle

    done by sy2002 in November 2016
    enhanced by sy2002 in August 2022
*/

#include <stdio.h>
#include <stdlib.h>
#include "qmon.h"

void __close(int h)
{
    fat32_file_handle* file_handle = (fat32_file_handle*) h;
    fat32_close_file(*file_handle);
    free(file_handle);
}
