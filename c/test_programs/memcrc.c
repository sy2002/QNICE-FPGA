/*  memcrc - Tool to calculate the CRC16 for a given memory region

    Can be for example used to check, if qtransfer works when being used
    in conjunction with filecrc.c

    Cannot check itself, as C is having internal variables that are
    overwritten after starting the program.

    So for performing a qtransfer test, it is best to have a large chunk of
    data in .out format that is starting at 0xB000 (0xB000 because C is
    fiddling with memory around 0xA000 and 0xB000 seems to be enough safety
    buffer).

    How to compile: qvc memcrc.c -c99 -O3

    done by sy2002 in September 2020
*/

#include <stdlib.h>
#include <stdio.h>

//Calculate CRC16 for each word of the given buffer
unsigned int calc_crc(unsigned int* buffer, unsigned int size)
{
    const unsigned int mask = 0xA001;
    unsigned int crc = 0xFFFF;
    unsigned int i = 0;
    while (i < size)
    {
        crc ^= *buffer;
        crc = (crc & 1) ? (crc >> 1) ^ mask : crc >> 1;
        buffer++;        
        i++;
    }
    return crc;
}

unsigned int addr_start, length;

int main()
{
    printf("memcrc - Tool to calculate the CRC16 for a given memory region\n");
    printf("All numbers are expected to be 16-bit 4-digit hex values\n");

    printf("Start address: ");
    do {} while (scanf("%04x", &addr_start) != 1);
    printf("Length in words: ");
    do {} while (scanf("%04x", &length) != 1);

    printf("\nCRC16=%04X\n", calc_crc((unsigned int*) addr_start, length));
    return 0;
}
