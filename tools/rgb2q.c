/*  rgb2q - Convert 24-bit RGB values to the 15-bit QNICE format
    done by sy2002 in September 2020
*/

#include <stdlib.h>
#include <stdio.h>

unsigned int palette_convert_24_to_15(unsigned long color)
{
   return ((color & 0x00F80000) >> 9)
        + ((color & 0x0000F800) >> 6)
        + ((color & 0x000000F8) >> 3);
}


/* This routine is not yet used and needs to be improved in case we enhance
   this tool to convert in both directions. The formula for converting each
   component of the 15-bit RGB to 24-bit RGB is: multiply by 0x83A and SHR 8 */
unsigned long palette_convert_15_to_24(unsigned long color)
{
   return ((color << 9) & 0x00F80000)
        + ((color << 6) & 0x0000F800)
        + ((color << 3) & 0x000000F8);
}

int main(int argc, char* argv[])
{
    if (argc != 2)
    {
        printf("rgb2q <24-bit RGB value as integer or as hex value written as 0x000000>\n");
        return 1;
    }

    unsigned long val = strtol(argv[1], NULL, 0);   
    printf("24-bit RGB value %06X => 15-bit QNICE value 0x%04X\n", val, palette_convert_24_to_15(val));
    return 0;
}