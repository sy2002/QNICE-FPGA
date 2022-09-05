/*
    Test program that runs several write tests within the constraints of the
    current FAT32 implementation that does not allow to add new bytes to
    an existing file but only write within the existing file's boundaries.

    1. Overwrites a given file linearily by pseudo-random numbers and then
       test, if this worked.

    2. Perform a random amount of episodes while in each episode we first
       seek to a random position and write a random amount of data and then
       we check, if this worked by re-reading the file and checking against
       the pseudo-random number generator.

    by sy2002 in September 2022
*/

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

#include <stdio.h>
#include <string.h>

#include "qmon.h"

typedef unsigned int uint16_t;
typedef unsigned long uint32_t;

const char* default_testfile = "/asm/32bit-div.asm";
//const char* default_testfile = "/qbin/the-matrix.html";
const uint16_t default_seed = 23976;

/* ========================================================================
   Pseudo-Random-Number Generator
   https://lemire.me/blog/2019/07/03/a-fast-16-bit-random-number-generator/
   ======================================================================== */

uint16_t wyhash16_x;

uint32_t hash16(uint32_t input, uint32_t key)
{
  uint32_t hash = input * key;
  return ((hash >> 16) ^ hash) & 0xFFFF;
}

uint16_t wyhash16()
{
  wyhash16_x += 0xfc15;
  return hash16(wyhash16_x, 0x2ab);
}

/* ========================================================================
   Main Program
   ======================================================================== */

int main()
{
    printf("fwrite.c: Performs multiple FAT32 write tests. "
           "Done by sy2002 in September 2022.\n"
           "Test file (will be overwritten): %s\n\n", default_testfile);

    printf("Test #1: Overwrite with pseudo random numbers\n");

    /* Currently, we only support read and read/update files (within the
       boundaries of the existing file, no appending).
       These modes are valid: r, rb, r+, rb+
       The underlying vclib does not support "r+b" (which should be equivalent
       to "rb+"), but only "rb+" itself.
       The system is differentiating between binary and text mode.
    */    
    FILE* file1 = fopen(default_testfile, "rb+");
    unsigned int bytes, retval, readbuf, random;
    unsigned long filepos_w, filepos_r, filesize;
    if (file1)
    {
        /* Test #1: Fill file with pseudo random numbers

           Important: Given that we currently only support overwriting files
           (without appending bytes) and given that fseek is not yet
           supporting SEEK_END, we need another mechanism to find out the
           size of a file to be able to fully overwrite it. The solution
           is the non-standard C function fsize. */
        wyhash16_x = default_seed;
        filepos_w = 0;
        filesize = fsize(file1);
        while (filepos_w != filesize)
        {
            random = wyhash16();
            fwrite(&random, 1, 1, file1);
            filepos_w += 1;
        };
        printf("Test #1: Done. Filesize = %lu\n", filepos_w);

        /* Test #2: Seek back to position 0, read file and compare
           the file's actual data with the pseudo-random stream */

        printf("Test #2: Read back file and check pseudo random numbers\n");
        if (fseek(file1, 0, SEEK_SET) != 0)
        {
            printf("ERROR: fseek back to position 0 failed.\n");
            return -1;
        }
        wyhash16_x = default_seed;
        filepos_r = 0;
        do
        {
            bytes = fread(&readbuf, 1, 1, file1);
            if (bytes == 1)
            {
                readbuf &= 0x00FF;
                random = wyhash16() & 0x00FF;
                if (readbuf != random)
                {
                    printf("ERROR: Read wrong byte %x at position %lu, expected %x\n", readbuf, filepos_r, random);
                    return - 1;
                }
                filepos_r++;
            }
        } while (bytes == 1);


        if (filepos_r != filepos_w)
        {
            printf("ERROR: Read lead to different filesize (%lu) than write (%lu)\n", filepos_r, filepos_w);
            return -1;
        }

        printf("Test #2: Success.\n");

        /* Test #3: Seek to an amount of random positions and fill the file
           and this point with a random amount of random values. Then
           close the file and then read back and check the values. */
        wyhash16_x = default_seed + 23;
        unsigned int episodes = (wyhash16() & 0x003F) + 1; //maximum 64 episodes
        unsigned int episode, amount = 1;
        unsigned long seekpos = 0;
        printf("Test #3: Running %u episodes of random seek random write\n", episodes);
        for (episode = 1; episode <= episodes; episode++)
        {
            unsigned long new_seekpos = (filesize / episodes) * (episode - 1) + (wyhash16() & 0xFF);
            while (new_seekpos <= seekpos + amount)
                new_seekpos += amount;
            seekpos = new_seekpos;
            if (seekpos >= filesize)
            {
                printf("  Episode %u: Skip from here\n", episode);
                break;
            }
            amount = wyhash16() & 0x00FF;        
            if (seekpos + amount > filesize)
                amount = filesize - seekpos;
            printf("  Episode %u: seek pos = %lu, amount = %u\n", episode, seekpos, amount);
            if (fseek(file1, seekpos, SEEK_SET) != 0)
            {
                printf("ERROR: fseek failed\n");
                return -1;
            }
            filepos_w = 0;
            while (filepos_w < amount)
            {
                random = wyhash16();
                fwrite(&random, 1, 1, file1);
                filepos_w++;
            }
        }

        printf("Test #3: Done.\n");


        /* Test #4: Test closing file (and flush buffer) */
        retval = fclose(file1);
        if (retval == 0)
            printf("Test #4: Close file: Success.\n");
        else
        {
            printf("Error closing file. Error code: %u\n", retval);   
            return -1;
        }

        /* Test #5: Re-open file and re-read file and validate the episodes
           written above */
        printf("Test #5: Re-open file and validate episodes\n");
        file1 = fopen(default_testfile, "rb+");
        if (!file1)
        {
            printf("ERROR: Could not re-open file.\n");
            return -1;
        }

        wyhash16_x = default_seed + 23;
        episodes = (wyhash16() & 0x003F) + 1; //maximum 64 episodes
        seekpos = 0;
        amount = 1;
        for (episode = 1; episode <= episodes; episode++)
        {
            unsigned long new_seekpos = (filesize / episodes) * (episode - 1) + (wyhash16() & 0xFF);
            while (new_seekpos <= seekpos + amount)
                new_seekpos += amount;
            seekpos = new_seekpos;            
            if (seekpos >= filesize)
            {
                printf("  Episode %u: Skip from here\n", episode);
                break;
            }  
            amount = wyhash16() & 0x00FF;
            if (seekpos + amount > filesize)
                amount = filesize - seekpos;               
            printf("  Episode %u: seek pos = %lu, amount = %u\n", episode, seekpos, amount);
            if (fseek(file1, seekpos, SEEK_SET) != 0)
            {
                printf("ERROR: fseek failed\n");
                return -1;
            }
            filepos_r = 0;
            while (filepos_r < amount)
            {
                if (fread(&readbuf, 1, 1, file1))
                {
                    readbuf &= 0x00FF;
                    random = wyhash16() & 0x00FF;
                    if (readbuf != random)
                    {
                        printf("ERROR: Read %x at pos %lu but expected %x\n", readbuf, seekpos + filepos_r, random);
                        return -1;
                    }
                }
                else
                {
                    printf("ERROR: Read failed.\n");
                    return -1;
                }
                filepos_r++;
            }
        }

        printf("Test #5: Success.\n");
        retval = fclose(file1);
        if (retval == 0)
            printf("Test #5: Close file: Success.\n");
        else
        {
            printf("Error closing file. Error code: %u\n", retval);   
            return -1;
        }        
    }
    else
        printf("ERROR: Could not open %s in mode \"rb+\"\n", default_testfile);

    return 0;
}