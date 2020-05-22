/*  Video RAM test for QNICE-FPGA

    Tests read/write patterns of the video ram to check.

    Background: Commit c5bfb88 in branch develop introduced a new kind of
    video ram: Single clock, dual port vs dual clock dual port before. The
    reason was, that Vivado synthesized the old version as LUTs and used up
    the whole FPGAs resources by doing so.

    The new version works on both - ISE and Vivado. Therefore it is important
    to test, if reading/writing the video RAM still works as intended.
    
    done by sy2002 in May 2020
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sysdef.h"
#include "qmon.h"

#define MMIO( __x ) *((unsigned int volatile *) __x )

const char* key = "öalskdfKAJ";

//pseudo random generator
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
    unsigned int page, x, y, diff1, diff2, diff3, c;

    page = diff1 = diff2 = diff3 = c = 0;

    qmon_vga_cls();
    printf("Video RAM Test - done by sy2002 in May 2020\n");
    printf("===========================================\n\n");
    printf("Test #1: Non-linear: Fill page 2 and backup to page 3 and compare: ");
    fflush(stdout);

    //Test #1: WRITE
    for (y = 0; y < 40; y++)
        for (x = 0; x < 80; x++)
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
    for (y = 0; y < 40; y++)
        for (x = 0; x < 80; x++)
        {
            MMIO(VGA_CR_X) = x;
            MMIO(VGA_CR_Y) = y;
            MMIO(VGA_OFFS_RW) = 3200; //"page" 2 (screen directly following the current screen)
            int val1 = MMIO(VGA_CHAR);

            MMIO(VGA_OFFS_RW) = 6400; //"page" 3
            int val2 = MMIO(VGA_CHAR);

            if (val1 != val2)
                diff1++;
        }

    MMIO(VGA_OFFS_RW) = 0;
    printf(diff1 == 0 ? "OK\n" : "FAILED!\n");

    printf("Test #2: Linear fill page 1 to 20 and compare: <Press ENTER>\n");
    getc(stdin);

    //Test #2: WRITE
    for (page = 0; page < 20; page++)
    {
        MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = 3200 * page;

        for (y = 0; y < 40; y++)
            for (x = 0; x < 80; x++)
            {
                MMIO(VGA_CR_X) = x;
                MMIO(VGA_CR_Y) = y;
                MMIO(VGA_CHAR) = (unsigned int) MurmurHash2(key, strlen(key), 1976 + (x * y) + page) % 256;
            }
    }

    //Test #2: READ/COMPARE
    for (page = 0; page < 20; page++)
    {
        MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = 3200 * page;

        for (y = 0; y < 40; y++)
            for (x = 0; x < 80; x++)
            {
                MMIO(VGA_CR_X) = x;
                MMIO(VGA_CR_Y) = y;

                if (MMIO(VGA_CHAR) != (unsigned int) MurmurHash2(key, strlen(key), 1976 + (x * y) + page) % 256)
                    diff2++;
            }
    }

    MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = 0;
    qmon_vga_cls();
    printf("Video RAM Test - done by sy2002 in May 2020\n");
    printf("===========================================\n\n");
    printf("Test #1: Non-linear: Fill page 2 and backup to page 3 and compare: ");
    printf(diff1 == 0 ? "OK\n" : "FAILED!\n");
    printf("Test #2: Linear fill page 1 to 20 and compare: ");    
    printf(diff2 == 0 ? "OK\n" : "FAILED!\n");
    printf("Test #3: Non-linear, random 64000 writes and compares: <Press ENTER>\n");
    getc(stdin);

    //Test #3: WRITE
    MMIO(VGA_CR_X) = 0;
    MMIO(VGA_CR_Y) = 0;
    for (unsigned int i = 0; i < 64000; i++)
    {
        unsigned int random = MurmurHash2(key, strlen(key), i);
        MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = random;
        MMIO(VGA_CHAR) = random % 256;
    }

    //Test #3: READ/COMPARE
    for (unsigned int i = 0; i < 64000; i++)
    {
        unsigned int random = MurmurHash2(key, strlen(key), i);
        MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = random;
        if (MMIO(VGA_CHAR) != random % 256)
            diff3++;
    }

    MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = 0;
    qmon_vga_cls();
    printf("Video RAM Test - done by sy2002 in May 2020\n");
    printf("===========================================\n\n");
    printf("Test #1: Non-linear: Fill page 2 and backup to page 3 and compare: ");
    printf(diff1 == 0 ? "OK\n" : "FAILED!\n");
    printf("Test #2: Linear fill page 1 to 20 and compare: ");    
    printf(diff2 == 0 ? "OK\n" : "FAILED!\n");
    printf("Test #3: Non-linear, random 64000 writes and compares: ");
    printf(diff3 == 0 ? "OK\n\n" : "FAILED!\n\n");

    unsigned int error_count = diff1 + diff2 + diff3;
    if (error_count == 0)
        printf("SUCCESS! Video RAM passed all tests.\n");
    else
        printf("FAILURE! Corrupt Video RAM! %u errors detected.\n", error_count);

    return 0;
}