/*
    Various tests to read one or more chars.
    by sy2002 in November 2016
*/

#include <stdio.h>
#include <string.h>

int main()
{
    char in;
    char alot[100];

    puts("get a lot of chars using fgets:");
    /*fgets(alot, 100, stdin);*/
    gets(alot);
    printf("You entered: %s. The string length is %u and the last char has the code %u\n", alot, strlen(alot), (unsigned) alot[strlen(alot) - 1]);

/*
    puts("get one char using scanf:");
    scanf("%c",&in);
    printf("You entered: %c\n", in);
*/

    puts("1. get one char using getchar:");
    in = getchar();
    printf("You entered %c\n", in);

    puts("2. get one char using getchar:");
    in = getchar();
    printf("You entered %c\n", in);    

    puts("3. get one char using getchar:");
    in = getchar();
    printf("You entered %c\n", in);        
}