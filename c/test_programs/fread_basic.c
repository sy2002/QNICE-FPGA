/*
    Development testbed for __open.c, __read.c and __close.c so that the
    stdio functions fopen and fread work.

    done by sy2002 in November 2016
*/

#include <stdio.h>

void catfile(char* name)
{
    FILE* fh = fopen(name, "r");

    if (fh)
    {
        int read_byte;
        int was_cr = 0;
        while (fread(&read_byte, 1, 1, fh) == 1)
        {
            if (read_byte == '\r' || read_byte == '\n')
            {
                /* if LF after CF, then skip LF as we already
                   printed a CR/LF when we read the CF */
                if (!(was_cr && read_byte == '\n'))
                    putchar('\n');
            }
            else
                /* print character */
                putchar(read_byte);

            was_cr = read_byte == '\r';
        }

        if (!feof(fh))
            printf("Error while reading file: %s", name);

        if (fclose(fh) != 0)
            printf("Error while closing file: %s", name);
    }
    else
        printf("Cannot open file: %s\n", name);    
}

int main()
{
    const int cat_amount = 4;
    char* cat_files[4] =
    {
        "dummy-to-test-filenotfound",
        "test-lf.txt",
        "test-cr.txt",
        "testcrlf.txt"
    };

    int i;
    for (i = 0; i < cat_amount; i++)
    {
        printf("Printing file: %s\n", cat_files[i]);
        puts("================================================================================");

        catfile(cat_files[i]);

        puts("\n================================================================================");
    }

    return 0;
}
