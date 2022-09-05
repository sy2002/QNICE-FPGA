/*
    __seek.c is an abstraction for the Standard C Library that is used
    to implement fseek.

    done by sy2002 in September 2022
*/

#include <stdio.h>
#include "qdefs.h"
#include "qmon.h"

long __seek(int h, long o, int d)
{
  //Currently, we only support the mode SEEK_SET.
  if (d != SEEK_SET)
    return -1;

  fat32_file_handle* file_handle = (fat32_file_handle*) h;
  if (fat32_seek_file(file_handle, o) == 0)
    return o;
  else
    return -1;
}
