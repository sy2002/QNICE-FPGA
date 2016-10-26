/* Shell inspired by the SD Card and FAT32 development testbed sdcard.asm
   Direct interaction with the Monitor functions, the C library is not
   used for any file or directory related functionality.

   compile with -c99

   done by sy2002 in October 2016
*/

#ifndef __QNICE__
#error This program only runs on QNICE.
#endif

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sysdef.h"

#define mon_gets(x)                         ((fp)0x0006)(x)
#define mon_str2upper(x)                    ((fp)0x001A)(x)
#define mon_f32_mnt_sd(h, p)                ((lfp)0x0044)(h, p)
#define mon_f32_od(hdev, hfile)             ((lfp)0x0048)(hdev, hfile)
#define mon_f32_pd(d, a)                    ((fp)0x004E)(d, a)

typedef int (*fp)();
typedef unsigned long (*lfp)();

typedef unsigned int device_handle[17];
typedef unsigned int file_handle[9];
typedef unsigned int dir_entry[268];

device_handle   dh;
file_handle     fh;
dir_entry       de;

char*           input_str;
char*           split_str;

int fat32_mount_sd(device_handle dev_handle, int partition)
{
    return (int) (mon_f32_mnt_sd(dev_handle, partition) >> 16);
}

int fat32_open_dir(device_handle dev_handle, file_handle f_handle)
{
    return (int) (mon_f32_od(dev_handle, f_handle) >> 16);
}

unsigned long mon_f32_ld(file_handle f_handle, dir_entry d_entry, int attribs) =
  "         ADD      0x0100, R14\n"
  "         ASUB     0x004A, 1\n"
  "         MOVE     R10, R8\n"
  "         MOVE     R11, R9\n"
  "         SUB      0x0100, R14\n";


int fat32_list_dir(file_handle f_handle, dir_entry d_entry, int attribs, int* entry_valid)
{
    unsigned long ret = mon_f32_ld(f_handle, d_entry, attribs);
    *entry_valid = (int) (ret & 0x0000FFFF);
    return (int) (ret >> 16);
}

void fat32_print_dir_entry(dir_entry d_entry, int attribs)
{

}

int mon_split_str(char* input, char separator, char* output) =
  "         ADD      0x0100, R14\n"
  "         ASUB     0x0036, 1\n"
  "         MOVE     R13, R0\n"
  "         MOVE     R9, R1\n"
  "_MSS_LP: MOVE     @R0++, @R10++\n"
  "         SUB      1, R1\n"
  "         RBRA     _MSS_LP, !Z\n"
  "         ADD      R9, R13\n"
  "         SUB      0x0100, R14\n";

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
        if ((error & 0xFF00) != 0xEE00)
            error &= 0x00FF;
        printf("fatal error: 0x%04X\n", error);
        exit(error);
    }
}

int main()
{
    puts("SD Card Shell Demo - done by sy2002 in October 2016\n");
    print_help();

    execute(fat32_mount_sd(dh, 1));

    if (!(input_str = malloc(512)) || !(split_str = malloc(1024)))
    {
        puts("fatal error: not enough heap.");
        return -1;
    }

    while (1)
    {
        printf("SDCARD> ");
        fflush(stdout);
        mon_gets(input_str);
        puts("");
        
        int input_amount = mon_split_str(input_str, ' ', split_str);
        char* cmd = split_str + 1;
        char* prm = split_str + *((int*) split_str) + 1;
        mon_str2upper(cmd);

        if (strcmp(cmd, "EXIT") == 0)
        {
            free(input_str);
            free(split_str);            
            return 0;
        }

        else if (strcmp(cmd, "HELP") == 0)
            print_help();

        else if (strcmp(cmd, "DIR") == 0)
        {
            execute(fat32_open_dir(dh, fh));
            int entry_valid = 1;
            while (entry_valid)
            {
                execute(fat32_list_dir(fh, de, FAT32_FA_DEFAULT, &entry_valid));
                if (entry_valid)
                    mon_f32_pd(de, FAT32_PRINT_DEFAULT);
            }
        }

        else if (strcmp(cmd, "CD") == 0)
        {
            puts("CMD=CD");
        }

        else if (strcmp(cmd, "CAT") == 0)
        {
            puts("CMD=CAT");
        }

        else if (strcmp(cmd, "CATHEX") == 0)
        {
            puts("CMD=CATHEX");
        }

        else
        {
            puts("illegal command");
        }
    }
}