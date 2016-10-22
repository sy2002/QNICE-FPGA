/* Cellular Automata
   Wolfram, "A New Kind of Science", Chapter 2 and 3.

   Michael Ashley / UNSW / 11-May-2003
   http://newt.phys.unsw.edu.au/~mcba/phys2020/notes/cell1.html

   Modified for QNICE by sy2002 in October 2016
*/

#define DISPLAYWIDTH 80
#define MAXSTEPS     24

#ifdef __QNICE__

    #define getchar(x) ((fp)0x0002)(x)
    #define gets(x)    ((fp)0x0006)(x)
    #define putsnl(x)  ((fp)0x0008)(x)
    #define exit(x)    ((fp)0x0016)(x)

    typedef int (*fp)();

    static void puts(char* p)
    {
      putsnl(p);
      putsnl("\n\r");
    }

    #define putc putsnl
    #define GREETING "Wolfram's Cellular Automata for QNICE"

#else

    #include <stdio.h>
    #include <stdlib.h>

    #define putc printf
    #define GREETING "Wolfram's Cellular Automata"

#endif

/*
  Each cell has a value of 0 or 1.

  The value of a cell in the next generation depends on its current
  value, and the values of the neighbouring two cells. 

  The calculation of the new value therefore depends on the values of 
  3 single-bit quantities, giving 8 possible alternative configurations.

  The calculation can therefore be represented using a array giving the
  8 possibilities. We call this array "rule". The index into the
  rule array is the 3-bit number composed from the state (0/1) of the cell
  under consideration and the neighbouring two cells. The value stored
  in the rule array is either 0 or 1, depending on whether the cell is
  "dead/alive" in the next generation.
*/

int rule[8];

/*
  We start with a 1D line of cells of length "DISPLAYWIDTH". With
  each generation, the line of cells can grow by one cell at the 
  beginning and one cell at the end. So, we have to make room for
  "DISPLAYWIDTH + 2 * MAXSTEPS" cells, where "MAXSTEPS" is the
  number of generations we will follow.
*/

typedef struct
{
    unsigned char cell[DISPLAYWIDTH + 2 * MAXSTEPS];
} state;


void initialise(state* s)
{

    /* This function initialises the 1D line of cells with zeroes, 
       apart from a single alive cell in the middle. */

    int i;
    for (i = 0; i < (sizeof s->cell) / (sizeof s->cell[0]); i++)
    {
        s->cell[i] = 0;
        if (i == MAXSTEPS + DISPLAYWIDTH / 2)
            s->cell[i] = 1;
    }
}

void createRule(int r[8], unsigned char n)
{
    /* Create the "rule" array. */
    
    int i;
    for (i = 0; i < 8; i++)
    {
        r[i] = 0x01 & (n >> i);
    }
}

void applyRule(state* prev, state* next, int i)
{

    /* This function takes an existing state, prev, and applies the
       evolution rule to the i'th element, returning the result in next. */

    next->cell[i] = rule[(prev->cell[i - 1] << 2) +
                         (prev->cell[i] << 1) + 
                          prev->cell[i + 1]];
}

void evolve(state* prev, state* next)
{

    /* Applies the rule to all elements (apart from the end-points) of
       an existing state, prev, and returns the result in next. */

    int i;
    for (i = 1; i < (sizeof prev->cell) / (sizeof prev->cell[0]) - 1; i++)
    {
        applyRule(prev, next, i);
    }
}

void displayState(state* s)
{
    int i;
    for (i = 0; i < DISPLAYWIDTH; i++)
    {
        if (s->cell[i + MAXSTEPS])
        {
            putc("*");
        }
        else
        {
            putc(" ");
        }
    }
    putc("\n");
}

int mul(int a, int b)
{
    int i, retval;
    retval = 0;
    for (i = 0; i < b; i++)
        retval += a;
    return retval;
}

int str2int(char* str)
{
    int i, base, retval;
    char* s = str;
    int PowersOfTen[3] = {1, 10, 100};

    i = 0;
    while (*s++ != 0)
        i++;
    if (i > 3)
        i = 3;

    base = 0;
    retval = 0;
    while (i)
    {
        int digit = *(str + i - 1) - 48;
        if (digit < 0)
            digit = 0;
        if (digit > 9)
            digit = 9;
        retval += mul(PowersOfTen[base], digit);
        base++;
        i--;
    }

    return retval < 256 ? retval : 255;
}

int main()
{
    int n, i;
    state s0, s1;
    char inputstring[100];

    puts(GREETING);
    puts("by Michael Ashley in May 2003, modified for QNICE by sy2002 in October 2016");    
    puts("Rule numbers need to be between 0 and 255.");
    puts("Some known-to-be-nice rules are: 30, 54, 60, 90, 126, 129, 150, 250");
    putc("Enter rule #");
    gets(inputstring);
    puts("");

    n = str2int(inputstring);

    initialise(&s0);
    initialise(&s1);

    createRule(rule, n);

    for (i = 0; i < MAXSTEPS / 2; i++)
    {
        displayState(&s0);
        evolve(&s0, &s1);
        displayState(&s1);
        evolve(&s1, &s0);
    }

    exit(0);
}
