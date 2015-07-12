//Converts a qasm output file into a file that QNICE-FPGA's ROM understands
//written by sy2002, July 4th 2015
//
//how to compile: gcc qasm2rom.c -o qasm2rom -std=c99

#include <stdio.h>
#include <string.h>

FILE* input_file;
FILE* output_file;

char input_buffer[20];
char* pib = (char*) &input_buffer;

char binary[16][5] = {  "0000",
                        "0001",
                        "0010",
                        "0011",
                        "0100",
                        "0101",
                        "0110",
                        "0111",
                        "1000",
                        "1001",
                        "1010",
                        "1011",
                        "1100",
                        "1101",
                        "1110",
                        "1111"  };

char digits [] = "0123456789ABCDEF";

int main(int argc, char *argv[])
{
    if (argc != 3)
    {
        printf("usage: qasm2rom <input file> <output file>\n");
        return -1;
    }

    input_file = fopen(argv[1], "r");
    if (!input_file)
    {
        printf("input file %s could not be opened\n", argv[1]);
        return -2;
    }

    output_file = fopen(argv[2], "w+");
    if (!output_file)
    {
        printf("output file %s could not be created\n", argv[2]);
        return -3;
    }

    while (fgets(pib, 20, input_file))
    {
        if (strlen(pib) > 12)
        {
            for (int i = 9; i < 13; ++i)          
                fprintf(output_file, "%s", (char*) &binary[strchr(digits, pib[i]) - digits]);
            fprintf(output_file, "\n");
        }
    }

    fclose(input_file);
    fclose(output_file);

    return 0;
}