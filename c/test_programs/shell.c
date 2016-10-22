/* Shell inspired by the SD Card and FAT32 development testbed sdcard.asm
   Direct interaction with the Monitor functions, the C library is not
   used for any file or directory related functionality.

   done by sy2002 in October 2016 */

#ifndef __QNICE__
#error This program only runs on QNICE.
#endif

#include <stdio.h>

#define mon_gets(x)             ((fp)0x0006)(x)
#define mon_f32_mnt_sd(h, p)    ((lfp)0x0044)(h, p)

typedef int (*fp)();
typedef unsigned long (*lfp)();

typedef unsigned int device_handle[17];

device_handle   dh;

int fat32_mount_sd(device_handle dev_handle, int partition)
{
    return (int) (mon_f32_mnt_sd(dev_handle, partition) >> 16);
}

void print_help()
{
    puts("    navigate: dir and cd <path> (use / as a path separator)");
    puts("    list files (complex names are allowed, use / as path separator):");
    puts("        cat <filename> and cathex <filename>");
    puts("        for seeking within the file, add a decimal number");
    puts("        separated by a : after the filename, e.g. <filename>:1234");
    puts("    print this info: help");
    puts("    end program: exit\n");
}

void execute(int error)
{
    if (error != 0)
    {
        if (error & 0xFF00 != 0xEE00)
            error &= 0x00FF;
        printf("fatal error: 0x%04X\n", error);
        exit(0);
    }
}

int main()
{
    puts("SD Card Shell Demo - done by sy2002 in October 2016\n");
    print_help();

    execute(fat32_mount_sd(dh, 1));

    return 0;
}