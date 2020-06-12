/*  UNFINISHED FIRST WIP DRAFT THAT DOES NOT REALLY WORK

    Visually appealing HyperRAM test that displays a scene from
    "The Matrix" as ASCII art.

    The correct functioning of the HyperRAM is checked via CRC.
    The ASCII video is taken from: http://www.media4u.ch/de/the-matrix.html

    started and left (for now) unfinished by sy2002 in June 2020

    TODO: Implement a smarter way to scale the original 238x87 down to the
          80x40 that QNICE needs. First idea:

          1. Fist of all write a small analyzer that calculates the
             "brightness" value of each letter that is used. E.g. use python
             and a dictionary and then count the amount of pixels (and maybe
             add some intelligence about the distribution) in each character.

          2. After we have a table that maps brightness values to ASCII
             we can analyze e.g. a gliding window of 3x2 and take the average
             instead of just throwing away each second line and two out of
             three columns

    Alternately, encoding the whole thing natively to 80x40 using some tool
    from the internet might work nicely, too.
*/

#include <stdio.h>
#include <string.h>

#include "qmon.h"
#include "sysdef.h"

//QNICE @ MEGA65 HyperRAM MMIO
#define IO_M65HRAM_LO       0xFF60 // Low word of address  (15 downto 0)
#define IO_M65HRAM_HI       0xFF61 // High word of address (26 downto 16)
#define IO_M65HRAM_DATA     0xFF62 // 8-bit data in/out

#define MMIO( __x ) *((unsigned int volatile *) __x )

void qnice_set_hram_address(unsigned long addr)
{
    addr -= 0x8000000L;
    MMIO(IO_M65HRAM_HI)   = (unsigned int) (addr >> 16);
    MMIO(IO_M65HRAM_LO)   = (unsigned int) addr & 0x0000FFFFL;    
}

void lpoke(unsigned long addr, char value)
{
    qnice_set_hram_address(addr);
    MMIO(IO_M65HRAM_DATA) = (unsigned int) value;
}

char lpeek(unsigned long addr)
{
    qnice_set_hram_address(addr);
    return MMIO(IO_M65HRAM_DATA);
}

//Calculate CRC16 for each byte of the given buffer
unsigned int calc_crc(char* buffer, unsigned int size)
{
    const unsigned int mask = 0xA001;
    unsigned int crc = 0xFFFF;
    int i = 0;
    while (i < size)
    {
        crc ^= *buffer;
        crc = (crc & 1) ? (crc >> 1) ^ mask : crc >> 1;
        buffer++;        
        i++;
    }
    return crc;
}

int main()
{
    FILE*   f;
    if ((f = fopen("/qbin/the-matrix.html", "r")) == 0)
    {
        printf("Error: Could not open /qbin/the-matrix.html\n");
        return 1;
    }

    unsigned int frames = 0;
    char line[400];

    const char*         trigger_start       = "<pre id=\"text";
    const char*         trigger_end         = "</pre>";
    const unsigned char trigger_end_size    = 7;

    const unsigned int  input_dx            = 238;
    const unsigned int  input_dy            = 87;  
    const unsigned int  output_dx           = 80;
    const unsigned int  putput_dy           = 40;

    unsigned long       mempos              = 0;    
    unsigned int        frame_count         = 0;

    while (frame_count < 100)
    {
        fgets(line, sizeof(line), f);
        if (feof(f))
            break;

        //find next frame
        if (strstr(line, trigger_start) == line)
        {
            printf("Frame: %u\n", frame_count);
            //read frame
            unsigned int frame_len = 0;
            while  (frame_len < 40)
            {
                fgets(line, sizeof(line), f);
                if (feof(f))
                {
                    printf("Error: Corrupt input file.\n");
                    fclose(f);
                    return 1;
                }

                int i = 0;
                while (i < input_dx)
                {
                    lpoke(mempos++, line[i]);
                    i += 3;
                }

                fgets(line, sizeof(line), f);
                frame_len++;
            }
            frame_count++;
        }
    }

    printf("mempos: %lu\n", mempos);
    getc(stdin);

    qmon_vga_cls();

    MMIO(VGA_OFFS_RW) = MMIO(VGA_OFFS_DISPLAY) = 0;
    int page = 0;

    frame_count = 0;
    while (frame_count < 100)
    {
        //double buffering to avoid excessive flickering
        MMIO(VGA_OFFS_DISPLAY) = page * 3200;
        page = 1 - page;
        MMIO(VGA_OFFS_RW) = page * 3200;

        for (int delay = 0; delay < 10; delay ++)
            for (int y = 0; y < 40;  y++)
            {
                MMIO(VGA_CR_Y) = y;
                for (int x = 0; x < 80; x++)
                {
                    MMIO(VGA_CR_X) = x;
                    MMIO(VGA_CHAR) = lpeek(frame_count * 3200 + y * 80 + x);
                }
            }

        frame_count++;
    }

    fclose(f);
    return 0;
}
