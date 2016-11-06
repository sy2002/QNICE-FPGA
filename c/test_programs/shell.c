/*
   Shell inspired by the SD Card and FAT32 development testbed sdcard.asm
   Direct interaction with the Monitor functions, the C library is not
   used for any file or directory related functionality.

   You can also use this as a reference implementation of how to use
   the Monitor functions.

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
#include <ctype.h>

#include "qmon.h"           // QNICE Monitor wrapper functions
#include "sysdef.h"         // QNICE definitions and hardware registers

fat32_device_handle   dh;
fat32_file_handle     fh;
fat32_dir_entry       de;

char*           input_str;
char*           split_str = 0;

//Print help, i.e. all commands and their parameters
void print_help()
{
    puts("    navigate: dir and cd <path> (use / as a path separator)");
    puts("    list files (complex names are allowed, use / as path separator):");
    puts("        cat <filename> and cathex <filename>");
    puts("        for seeking within the file, add a number (decimal or hex as 0x...)");
    puts("        separated by a : after the filename, e.g. <filename>:1234");
    puts("    print this info: help");
    puts("    end program: exit\r\n");
}

//In case of an error, output the error code and terminate the program
void execute(int error)
{
    if (error != 0)
    {
        if ((error & 0xFF00) != 0xEE00)
            error &= 0x00FF;
        printf("fatal error: 0x%04X\r\n", error);
        exit(error);
    }
}

//In case malloc failed, output an error and terminate the program
void malloc_check(void* p, char* context)
{
    if (p == 0)
    {
        printf("fatal error: not enough heap for %s.\r\n", context);
        exit(-1);
    }
}

/* Extract filename and, if applicable seek position from prm and
   execute the cat operation. If cathex == 0, then ASCII mode is
   done, while accepting CR, LF and CR/LF. Otherwise a hexdump is done. */
void perform_cat(char* prm, int cathex)
{
    unsigned long seek_pos = 0;
    char* file_name;

    //extract seek position, if any
    char* argv;
    int argc = qmon_split_str(prm, ':', &argv);
    malloc_check(argv, "argv");
    if (argc == 2)
    {
        char* dummy;
        file_name = argv + 1;
        seek_pos = strtoul(argv + ((int) *argv) + 2, &dummy, 0);
    }
    else
        file_name = prm;

    int ret = fat32_open_file(dh, fh, file_name);

    if (ret == 0)
    {
        int seek_res = 0;
        if (seek_pos)
            seek_res = fat32_seek_file(fh, seek_pos);

        if (seek_res == 0)
        {
            int read_byte, res;
            int was_cr = 0; //was the byte of the last iteration a CR
            int hex_counter = 0;
            char recent[17];
            recent[16] = 0;

            while ((res = fat32_read_file(fh, &read_byte)) == 0)
            {
                //perform ASCII cat
                if (cathex == 0)
                {
                    //handle CR, LF and CR/LF
                    if (read_byte == CHR_CR || read_byte == CHR_LF)
                    {
                        //if LF after CF, then skip LF as we already
                        //printed a CR/LF when we read the CF
                        if (!(was_cr && read_byte == CHR_LF))
                        {
                            putc('\r', stdout);
                            putc('\n', stdout);
                        }
                    }
                    else
                        //print character
                        putc(read_byte, stdout);

                    was_cr = read_byte == CHR_CR;
                }

                //perform hexdump
                else
                {
                    printf("%02X ", (unsigned char) read_byte);
                    recent[hex_counter] = iscntrl(read_byte) ? '.' : read_byte;
                    if (++hex_counter == 16)
                    {
                        printf("        %s\r\n", recent);
                        hex_counter = 0;
                    }
                }

            }

            //every return value other than EOF is a fatal error
            if (res != FAT32_EOF)
                execute(ret);

            //in hexdump mode: print the last few bytes
            else if (cathex && hex_counter)
            {
                recent[hex_counter] = 0;
                for (int i = 0; i < 16 - hex_counter; i++)
                   printf("   ");
                printf("        %s\r\n", recent);
            }

            putc('\r', stdout);
            putc('\n', stdout);
        }
        else if (seek_res == FAT23_ERR_SEEKTOOLARGE)
            printf("error: seek position is larger than file: %lu\r\n", seek_pos);
        else
            execute(seek_res); //fatal error, end program
    }
    else if (ret == FAT32_ERR_FILENOTFOUND)
        printf("error: file not found: %s\r\n", file_name);
    else
        execute(ret); //fatal error, end program

    free(argv);
}

int main()
{
    puts("SD Card Shell Demo - done by sy2002 in October 2016\r\n");
    print_help();

    //mount partition #1 of built-in SD Card as FAT32
    execute(fat32_mount_sd(dh, 1));

    //reserve memory for the input string
    input_str = malloc(1024);
    malloc_check(input_str, "input_str");

    while (1)
    {
        if (split_str != 0)
            free(split_str);

        //show prompt and read input string
        printf("SDCARD> ");
        fflush(stdout);
        qmon_gets(input_str);
        puts("");
        
        //split input string into command and parameter
        int input_amount = qmon_split_str(input_str, ' ', &split_str);

        //sanity checks: empty string and no heap memory
        if (input_amount == 0)
            continue;
        malloc_check(split_str, "split_str");

        /* see the documentation of qmon_split_str in 
           c/qnice/monitor-lib/include/qmon.h to understand, how this works */
        char* cmd = split_str + 1;
        char* prm = split_str + ((int) *split_str) + 2;
        qmon_str2upper(cmd);

        printf("split_str = %u\r\n", (unsigned int) split_str);        

        //EXIT: end program
        if (strcmp(cmd, "EXIT") == 0)
        {
            free(input_str);
            free(split_str);            
            return 0;
        }

        //HELP: show help text
        else if (strcmp(cmd, "HELP") == 0)
            print_help();

        //DIR: list current directory's content
        else if (strcmp(cmd, "DIR") == 0)
        {
            execute(fat32_open_dir(dh, fh));
            int entry_valid = 1;
            while (entry_valid)
            {
                execute(fat32_list_dir(fh, de, FAT32_FA_DEFAULT, &entry_valid));
                if (entry_valid)
                    fat32_print_dir_entry(de, FAT32_PRINT_DEFAULT);
            }
        }

        //CD: change current directory
        else if (strcmp(cmd, "CD") == 0)
        {
            char* path = input_str + 3;
            int ret = fat32_change_dir(dh, path);
            if (ret != 0)
            {
                if (ret == FAT32_ERR_DIRNOTFOUND)
                    printf("error: directory not found: %s\r\n", path);
                else
                    execute(ret); //fatal error, end program
            }
        }

        //CAT: print file as ASCII (accept CR, LF, CR/LF)
        else if (strcmp(cmd, "CAT") == 0 && input_amount == 2)
            perform_cat(prm, 0);

        //CATHEX: print file as hexdump
        else if (strcmp(cmd, "CATHEX") == 0 && input_amount == 2)
            perform_cat(prm, 1);

        //ILLEGAL COMMAND
        else
            puts("illegal command");
    }
}