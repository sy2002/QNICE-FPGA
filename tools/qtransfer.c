/*  qtransfer - Safely transfer .out files to QNICE
    done by sy2002 in May and June 2020

    Use case: Transfer .out files and be sure, that they arrive correctly on
    the QNICE. Particularly in situations (such as MEGA65) where no RTS/CTS
    is available, the built in CRC16 makes sure, that everything went OK.

    qtransfer.asm needs to run on QNICE, before you run qtransfer.c

    Dependency:
    https://sigrok.org/wiki/Libserialport
    Mac: brew install libserialport
    Linux (Ubuntu/Debian): sudo apt-get install libserialport-dev

    How to compile: Use cc on macOS and gcc on Linux:
    cc qtransfer.c -o qtransfer -O3 -lserialport
*/

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>

#include <libserialport.h>

//Calculate CRC16 for each byte of the given buffer
uint16_t calc_crc(char* buffer, unsigned int size)
{
    const uint16_t mask = 0xA001;
    uint16_t crc = 0xFFFF;
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

//Helper function for error handling
int check(enum sp_return result)
{
        char *error_message;
 
        switch (result) {
        case SP_ERR_ARG:
                printf("Error: Invalid argument.\n");
                abort();
        case SP_ERR_FAIL:
                error_message = sp_last_error_message();
                printf("Error: Failed: %s\n", error_message);
                sp_free_error_message(error_message);
                abort();
        case SP_ERR_SUPP:
                printf("Error: Not supported.\n");
                abort();
        case SP_ERR_MEM:
                printf("Error: Couldn't allocate memory.\n");
                abort();
        case SP_OK:
        default:
                return result;
        }
}

const unsigned int std_timeout = 200;   //0.2sec
const unsigned short BURST_SIZE = 30;   // when increasing: revisit std_timeout
                                        // and adjust BURST_WORDS in qtransfer.asm

int main(int argc, char* argv[])
{
    char* portname;
    struct sp_port* port;
    int result;

    FILE* inputf;
    char buf[100];
    char response[100];

    if (argc < 3 || (inputf = fopen(argv[1], "r")) == 0)
    {
        printf("qtransfer <filename> <portname>\n");
        return 1;
    }

    fseek(inputf, 0L, SEEK_END);
    unsigned long file_lines = ftell(inputf) / 14;
    if (ftell(inputf) % 14 != 0)
    {
        printf("Error: Input file %s seems to be corrupt.\n", argv[1]);
        return 1;
    }
    rewind(inputf);

    check(sp_get_port_by_name(argv[2], &port));
    check(sp_open(port, SP_MODE_READ_WRITE));
    check(sp_set_baudrate(port, 115200));
    check(sp_set_bits(port, 8));
    check(sp_set_parity(port, SP_PARITY_NONE));
    check(sp_set_stopbits(port, 1));
    check(sp_set_flowcontrol(port, SP_FLOWCONTROL_NONE));

    //initial handshake: send "START\n" and receive a zero terminated "ACK"
    check(sp_blocking_write(port, "START\n", 6, std_timeout));
    check(sp_drain(port));
    if (check(sp_blocking_read(port, buf, 4, std_timeout)) != 4 || strcmp(buf, "ACK") != 0)
    {
        printf("Protocol error. (Are you running qtransfer on QNICE?)\n");
        return 1;
    }

    unsigned long lines_done = 0;
    unsigned long lines_lp = 0;

    char lines[BURST_SIZE][100];
    char crcbuf[BURST_SIZE][8];

    uint16_t lines_cnt = BURST_SIZE;
    uint16_t start_address; 

    while (lines_cnt == BURST_SIZE)
    {   
        for (lines_cnt = 0; lines_cnt < BURST_SIZE; lines_cnt++)
        {
            fgets(lines[lines_cnt], sizeof(lines[lines_cnt]), inputf);
            if (feof(inputf))
                break;
        }

        //if there is nothing to transmit, because the amount of lines
        //(file_lines) mod BURST_SIZE == 0 then exit loop and transmit END
        if (lines_cnt == 0)
            break;

        //announce current burst size
        char burst_str[6];
        sprintf(burst_str, "%04hX\n", (uint16_t) lines_cnt);
        check(sp_blocking_write(port, burst_str, 5, std_timeout));
        check(sp_drain(port));

        //build transmit string: (<burst> x (<address><data>\n))<crc>\n
        for (uint16_t n = 0; n < lines_cnt; n++)            
        {                        
            memset(buf, 0, sizeof(buf));
            strncpy(&buf[0], &lines[n][2], 4);
            strncpy(&buf[4], &lines[n][9], 4);
            buf[8] = '\n';
            check(sp_blocking_write(port, buf, 9, std_timeout));
            strncpy(crcbuf[n], buf, 8);

            if (lines_done == 0 && n == 0)
            {
                lines[0][6] = 0;
                start_address = strtol(&lines[0][2], NULL, 16);
            }
        }        
        memset(buf, 0, sizeof(buf));
        sprintf(&buf[0], "%04hX", calc_crc((char*) crcbuf, lines_cnt * 8));
        buf[4] = '\n';
        check(sp_blocking_write(port, buf, 5, std_timeout));
        check(sp_drain(port));

        //receive answer (or fill up the buffer on QNICE side with '\n')
        int actual;
        if ((actual = check(sp_blocking_read(port, buf, 4, std_timeout))) == 4 && strcmp(buf, "ACK") == 0)
        {
            lines_done += lines_cnt;
            if (lines_done - lines_lp > file_lines / 10)
            {
                float percentage = ((float) lines_done / (float) file_lines) * 100;
                if (percentage != 100.0)
                    printf("  %.0f%% done\n", percentage);
                lines_lp = lines_done;
            }
            continue;            
        }
        else
        {
            int input_waiting = check(sp_input_waiting(port));
            if (input_waiting)
                actual += check(sp_blocking_read(port, &buf[actual], input_waiting, std_timeout));
            buf[actual] = 0;
            if (strcmp(buf, "CRCERR") == 0)
                printf("CRC ERROR between line %lu and %lu\n", lines_done, lines_done + lines_cnt);
            else
                printf("UNKNOWN ERROR! (%s)\n", buf);
            return 1;
        }
    }

    fclose(inputf);

    //notify about end of bursts
    check(sp_blocking_write(port, "END\n", 4, std_timeout));
    printf(" 100%% done\n");    

    //transmit start address and length
    sprintf(buf, "%04hX\n", (uint16_t) start_address);
    check(sp_blocking_write(port, buf, 5, std_timeout));
    sprintf(buf, "%04hX\n", (uint16_t) file_lines);
    check(sp_blocking_write(port, buf, 5, std_timeout));
    check(sp_drain(port));
    usleep(300000);

    check(sp_close(port));
    sp_free_port(port);

    return 0;
}
