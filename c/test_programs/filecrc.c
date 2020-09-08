/*  filecrc - Tool to calculate the CRC16 for an .out file as if it would be
    in memory. So the CRC is not calculated on the strings in the .out file
    but on their memory representation.

    Meant to be compiled on the host.

    Can be for example used to check, if qtransfer works by using this
    in conjunction with mrmcrc.c.

    CAUTION: The .out file in question needs to fill the QNICE-FPGA memory
    linearily. If there are gaps, then the CRC16 might be wrong. Alternatively
    it makes sense to write zeros in the QNICE-FPGA memory before starting
    a qtransfer test.

    done by sy2002 in September 2020
*/

#ifdef __QNICE__
#error filecrc.c is meant to run on the host. Use memcrc.c on QNICE-FPGA.
#endif

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

//Calculate CRC16 for each word of the given buffer
uint16_t calc_crc(uint16_t* buffer, unsigned int size)
{
    const uint16_t mask = 0xA001;
    uint16_t crc = 0xFFFF;
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

const unsigned int QMEM_SIZE = 64*1024;
const uint16_t     QMEM_MAX  = QMEM_SIZE - 1;

uint16_t            qnice_memory[QMEM_SIZE];
uint16_t            start_addr;
uint16_t            last_addr = 0;
uint16_t            length = 0;
bool                init_addr_found = false;

int main(int argc, char* argv[])
{
    for (uint16_t i = 0; i < QMEM_MAX; i++)
        qnice_memory[i] = 0;

    FILE* inputf;

    if (argc != 2 || (inputf = fopen(argv[1], "r")) == 0)
    {
        printf("filecrc <name of a .out file>\n");
        return 1;
    }

    fseek(inputf, 0L, SEEK_END);
    unsigned long file_lines = ftell(inputf) / 14;
    if (ftell(inputf) % 14 != 0)
    {
        printf("Error: Input file %s seems to be corrupt.\n", argv[1]);
        fclose(inputf);
        return 2;
    }
    rewind(inputf);

    while (!feof(inputf))
    {
        unsigned int address, data;
        fscanf(inputf, "0x%04X 0x%04X\n", &address, &data);


        if (address > QMEM_MAX || data > QMEM_MAX)
        {
            printf("Error: Illegal address or data: 0x%X\n 0x%X\n ", address, data);
            fclose(inputf);
            return 3;
        }

        if (!init_addr_found)
        {
            init_addr_found = true;
            start_addr = address;
        }
        else if (init_addr_found && last_addr + 1 != address)
            printf("Warning: Non-consecutive address: %04X\n", address);
         
        last_addr = address;

        qnice_memory[(uint16_t) address] = (uint16_t) data;
        length++;
    }
    fclose(inputf);    

    uint16_t crc = calc_crc(&qnice_memory[start_addr], length);
    printf("Start address:\t%04X\nLength:\t\t%04X\nCRC16\t\t%04X\n\n", start_addr, length, crc);

    return 0;
}