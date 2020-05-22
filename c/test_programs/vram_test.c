/*  Video RAM test for QNICE-FPGA

    Tests read/write patterns of the video ram to check.

    Background: Commit ab32ecd in branch develop introduced a new kind of
    video ram: Single clock, dual port vs dual clock dual port before.
    Therefore it is important so test, if reading/writing still works
    as intended.
    
    done by sy2002 in May 2020
*/

#include <stdio.h>
#include <string.h>
#include "sysdef.h"
#include "qmon.h"

#define MMIO( __x ) *((unsigned int volatile *) __x )

const char* key = "öalskdfKAJ";

unsigned long MurmurHash2 (const void* key, long len, unsigned long seed)
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.

    const unsigned long m = 0x5bd1e995;
    const int r = 24;

    // Initialize the hash to a 'random' value

    unsigned long h = seed ^ len;

    // Mix 4 bytes at a time into the hash

    const unsigned char * data = (const unsigned char *)key;

    while(len >= 4)
    {
        unsigned long k = *(unsigned long *)data;

        k *= m; 
        k ^= k >> r; 
        k *= m; 
        
        h *= m; 
        h ^= k;

        data += 4;
        len -= 4;
    }
    
    // Handle the last few bytes of the input array

    switch(len)
    {
        case 3: h ^= data[2] << 16;
        case 2: h ^= data[1] << 8;
        case 1: h ^= data[0];
                h *= m;
    };

    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.

    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;

    return h;
} 


int main()
{
    unsigned int c = 0;

    qmon_vga_cls();
    printf("Video RAM Test - done by sy2002 in May 2020\n");
    printf("===========================================\n\n");
    printf("Test #1: Randomly fill pages 2 and 3 and compare the values: ");
    fflush(stdin);

//    MMIO(VGA_STATE) |= 0x800; //switch on multi-pages via VGA_OFFS_RW

    //Test #1: WRITE
    for (int y = 0; y < 40; y++)
        for (int x = 0; x < 80; x++)
        {
            unsigned int random_char = (unsigned int) MurmurHash2(key, strlen(key), 239 + (x * y) + c++) % 256;
            MMIO(VGA_CR_X) = x;
            MMIO(VGA_CR_Y) = y;
            MMIO(VGA_OFFS_RW) = 3200; //"page" 2 (screen directly following the current screen)
            MMIO(VGA_CHAR) = random_char;
            MMIO(VGA_OFFS_RW) = 6400; //"page" 3
            MMIO(VGA_CHAR) = random_char;
        }

    //Test #1: READ/COMPARE

//    MMIO(VGA_STATE) &= ~0x800; //switch  off multi-pages



    return 0;
}