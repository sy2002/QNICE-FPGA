#include <stdio.h>
#include "qdefs.h"

int __isatty(int h)
{
  return (h == QNICE_STDOUT) || (h == QNICE_STDIN) || (h == QNICE_STDERR) ? 1 : 0;
}
