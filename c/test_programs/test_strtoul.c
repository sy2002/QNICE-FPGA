
#include <stdio.h>
#include <stdlib.h>

int main()
{
    char* dummy;
    unsigned long value;

    puts("Convert using strtoul:\n");
    value = strtoul("65536", &dummy, 0);
    printf("65536 == %lu\n", value);

    value = strtoul("65540", &dummy, 0);
    printf("65540 == %lu\n", value);

    value = strtoul("196611", &dummy, 0);
    printf("196611 == %lu\n", value);

    puts("\nConvert using atol:\n");
    value = atol("65536");
    printf("65536 == %lu\n", value);

    value = atol("65540");
    printf("65540 == %lu\n", value);

    value = atol("196611");
    printf("196611 == %lu\n", value);

    return 0;
}