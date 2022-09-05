/*
    Test program the overwrites a given file by pseudo-random numbers
    and after that it tests, if the writing actually worked.

    by sy2002 in August 2022
*/

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

#include <stdio.h>
#include <string.h>

#include <qmon.h>

const char* default_testfile = "/asm/32bit-div.asm";

int main()
{
    printf("fwrite.c: Test program that overwrites a test file.\n"
           "Test file: %s\n", default_testfile);

    /* Currently, we only support read and read/update files.
       These modes are valid: r, rb, r+, rb+
       The underlying vclib does not support "r+b" (which should be equivalent
       to "rb+"), but only "rb+" itself.
       The system is differntiating between binary and text mode.
    */    
    FILE* file1 = fopen(default_testfile, "rb+");

    if (file1)
    {
        unsigned int counter = 0;
        while (fwrite(&counter, 1, 1, file1))
            counter++;

        if (fseek(file1, 1025, SEEK_SET) == 0)
        {
            char buf[4] = {0x23, 0x09, 0x19, 0x76};
            if (fwrite(&buf, 1, 4, file1) != 4)
                printf("ERROR: \"Seeked\" write failed!\n");
        }
        else
            printf("ERROR: Seek test failed!\n");

        //make sure to close the file so that unwritten data can be written
        unsigned int retval = fclose(file1);
        if (retval == 0)
            printf("Success.\n");
        else
            printf("Error closing file. Error code: %u\n", retval);        
    }
    else
        printf("Error opening test file.\n");

    return 0;
}