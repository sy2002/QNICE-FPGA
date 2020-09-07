/* Generate fractals from bit patterns in ASCII
   https://en.wikipedia.org/wiki/Sierpinski_carpet

   "Code Golf" example taken from

   http://codegolf.stackexchange.com/questions/54453/generate-fractals-from-bit-patterns-in-ascii

   written by LambdaBeta in August, 11 2015
   adjusted for QNICE-FPGA by sy2002 in October 2016
*/

#include <stdio.h>
#include <stdlib.h>

#include "sysdef.h"

int main() 
{
    int bitpattern, scale, generation, i, blocksize, x, y;
    int width = 1;
    char* out;
    unsigned long cycles;

    printf("Sierpinski Fractal Generator\n");
    printf("by LambdaBeta in August 2015, adjusted for QNICE by sy2002 in October 2016\n\n");
    printf("Enter bitpattern, scale (2 .. 5) and generation count (0 .. 5).\n");
    printf("Here are some value pairs that produce nice results:\n");
    printf(" [b, s, g] = 495, 3, 3\n");
    printf(" [b, s, g] = 7, 2, 5\n");
    printf(" [b, s, g] = 186, 3, 3\n");
    printf(" [b, s, g] = ");
    do {} while (scanf("%i,%i,%i", &bitpattern, &scale, &generation) != 3);
    printf("\n");

    for (i = 0; i < generation; ++i) {width *= scale;}
    out = malloc(width * width);
    if (out == NULL)
    {
        printf("Heap error: We need %i words minimum heap size.", width * width);
        return 0;
    }

#ifdef __QNICE__
    *((unsigned int*) IO_CYC_STATE) |= 1; /* reset cycle counter */ 
#endif

    for (i = 0; i < width * width; ++i) out[i]='#';

    blocksize = width / scale;
    for (i = 0; i < generation; ++i)
    {
        int x,y;
        for (y = 0; y < width; ++y)
        {
            for (x = 0; x < width; ++x)
            {
                int localX = (x / blocksize) % scale;
                int localY = (y / blocksize) % scale;
                int localPos = localY * scale + localX;
                if (!((bitpattern >> localPos) & 1)) out[y*width+x]=' ';
            }
        }
        blocksize /= scale;
    }

    for (y = 0; y < width; ++y)
    {
        for (x = 0; x < width; ++x)
            printf("%c ",out[y * width + x]);
        printf("\n");
    }

#ifdef __QNICE__
    cycles = *((unsigned long*) IO_CYC_LO); /* read the lower 32 bit of the cycle counter */
    printf("\n\nCalculation duration: %lu CPU cycles, i.e. %lu ms\n", cycles, cycles / 50000);
#endif

    return 0;
}
