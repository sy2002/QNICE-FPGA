/*
 * A collection of routines to write to VGA screen,
 * Supports a very small subset on the old conio library.
 * done by MJoergen in August 2020
 */

void gotoxy(int col, int row);
void cputcxy(int col, int row, int ch);
void cputsxy(int col, int row, const char *str);   // String must be zero-terminated.
void clrscr();
char cgetc();
long time();

