/*
 * A litte game that generates a maze and lets the player find his/her
 * way out of the maze.
 *
 * Maze is displayed on the VGA screen.
 * Keyboard controls are:
 *   UP    : w, k
 *   DOWN  : s, j
 *   LEFT  : a, h
 *   RIGHT : d, l
 *
 * done by MJoergen in August 2020
 */

#include "conio.h"
#include "rand.h"

#define MAX_ROWS  15
#define MAX_COLS  15
#define MAX_SQUARES	(MAX_ROWS*MAX_COLS)

char grid[MAX_SQUARES];

#define GetRow(sq)	(sq % MAX_ROWS)
#define GetCol(sq)	(sq / MAX_ROWS)

enum
{
   DIR_NORTH = 0,
   DIR_EAST,
   DIR_WEST,
   DIR_SOUTH,
   MAX_DIRS
};
const int offset[MAX_DIRS] = {-1, MAX_ROWS, -MAX_ROWS, 1};

char GetRandomDir()
{
   return my_rand() % MAX_DIRS;
}

int GetRandomSquare()
{
   return my_rand() % MAX_SQUARES;
}


void DrawPos(int sq)
{
   const char wall = '#';
   char col = 1 + 2*GetCol(sq);
   char row = 1 + 2*GetRow(sq);
   char g = grid[sq];

   cputcxy(col,   row,   wall);
   cputcxy(col,   row+2, wall);
   cputcxy(col+2, row+2, wall);
   cputcxy(col+2, row,   wall);
   cputcxy(col+1, row,   (g&(1<<DIR_NORTH)) ? ' ' : wall);
   cputcxy(col+2, row+1, (g&(1<<DIR_EAST))  ? ' ' : wall);
   cputcxy(col,   row+1, (g&(1<<DIR_WEST))  ? ' ' : wall);
   cputcxy(col+1, row+2, (g&(1<<DIR_SOUTH)) ? ' ' : wall);
   cputcxy(col+1, row+1, ' ');
} // end of DrawPos


void InitMaze(void)
{
   int sq;
   int count;
   int c;

   for(sq=0; sq<MAX_SQUARES; sq++)
   {
      grid[sq]=0;
   }

   sq = GetRandomSquare();
   count = MAX_SQUARES-1;
   while (count)
   {
      int dir = GetRandomDir();
      int newSq = sq + offset[dir];

      int sameRow = (GetRow(sq)==GetRow(newSq));
      int sameCol = (GetCol(sq)==GetCol(newSq));

      if ( ((sameRow && !sameCol) || (!sameRow && sameCol))
            && (newSq>=0) && (newSq<MAX_SQUARES) )
      {
         if (!grid[newSq])
         {	/* We haven't been here before. */

            /* Make an opening */
            int mask_old = 1 << dir;
            int mask_new = 1 << (MAX_DIRS-1) - dir;
            grid[sq] += mask_old; // DrawPos(sq); // Uncomment during debugging
            sq = newSq;
            grid[sq] += mask_new; // DrawPos(sq); // Uncomment during debugging
            count--;
         }
         else if ((my_rand() % 6) == 0)
         {
            /* Start from a different square that is connected */
            do
            {
               sq = GetRandomSquare();
            }
            while (!grid[sq]);
         }
      }
   }
} // end of InitMaze


int main()
{
   int curSq, printSq;

   int seed = time();
   my_srand(seed);

   cputsxy(1, 18, "Generating maze for you ...\0");

   InitMaze();

   clrscr();

   /* Set start square to lower right corner */
   curSq = MAX_SQUARES - 1;

   while (curSq >= 0)
   {
      int dir;

#define BEEN_HERE 1<<7

      grid[curSq] |= BEEN_HERE;

      // Redraw entire maze on screen.
      for (printSq=0; printSq<MAX_SQUARES; printSq++)
      {
         if (grid[printSq] & BEEN_HERE)
         {
            DrawPos(printSq);
         }
      }

      // Set cursor at current position.
      cputcxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2, curSq ? '@' : '*');
      gotoxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2);

      if (!curSq)
      {
         cputsxy(1, 38, "You escaped!\0");
         return 0;
      }

      // Get input direction from user.
      dir = MAX_DIRS;
      switch (cgetc())
      {
         case 'w': case 'k': dir = DIR_NORTH; break;
         case 's': case 'j': dir = DIR_SOUTH; break;
         case 'd': case 'l': dir = DIR_EAST; break;
         case 'a': case 'h': dir = DIR_WEST; break;
         case 'q': curSq = -1; break;  // Exit game
      }

      if (dir < MAX_DIRS)
      {
         if (grid[curSq] & (1<<dir))   // Check if move is allowed.
         {
            curSq += offset[dir];
         }
      }
   } // end of while (curSq >= 0)

   return 0;
} // end of main

