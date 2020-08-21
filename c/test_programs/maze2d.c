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

#include "conio.h"   // Function to write to the VGA screen
#include "rand.h"    // Random generator

// Define the size of the maze.
#define MAX_ROWS  18
#define MAX_COLS  38
#define MAX_SQUARES	(MAX_ROWS*MAX_COLS)

// Each square has a value that is a bitmask of open walls.
// E.g. the value 3 means that the square has openings to the north and the
// east, while there are blocking walls to the south and the west.
char grid[MAX_SQUARES];

enum
{
   DIR_NORTH = 0,
   DIR_EAST,
   DIR_WEST,
   DIR_SOUTH,
   MAX_DIRS
};

#define GetRow(sq)	(sq % MAX_ROWS)
#define GetCol(sq)	(sq / MAX_ROWS)

const int offset[MAX_DIRS] = {-1, MAX_ROWS, -MAX_ROWS, 1};

static char GetRandomDir()
{
   return my_rand() % MAX_DIRS;
}

static int GetRandomSquare()
{
   return my_rand() % MAX_SQUARES;
}


// Draw the current square as 3x3 characters.
static void DrawPos(int sq)
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
   cputcxy(col+1, row+1, ' ');   // Place cursor at centre of square.
} // end of DrawPos

static void pause()
{
   for (long i=0; i<1000; ++i)
   {
      // Calling my_rand() prevents the optimizer from pruning this loop,
      // because my_rand() has side-effects (it updates the seed).
      my_rand();
   }
} // end of pause

// Generate maze
static void InitMaze(void)
{
   int sq;
   int count;
   int c;

   for(sq=0; sq<MAX_SQUARES; sq++)
   {
      grid[sq]=0; // Initially all walls are blocked.
   }

   sq = GetRandomSquare(); // Start at a random square in the maze.
   count = MAX_SQUARES-1;  // Number of squares remaining to be visited.
   while (count)           // Continue until all squares are visited.
   {
      int dir = GetRandomDir();
      int newSq = sq + offset[dir]; // Go to a neighbouring square.

      int sameRow = (GetRow(sq)==GetRow(newSq));
      int sameCol = (GetCol(sq)==GetCol(newSq));

      // Check whether the new square is in fact inside the maze.
      if ( ((sameRow && !sameCol) || (!sameRow && sameCol))
            && (newSq>=0) && (newSq<MAX_SQUARES) )
      {
         if (!grid[newSq])
         {	/* We haven't been here before. */

            /* Make an opening */
            int mask_old = 1 << dir;
            int mask_new = 1 << (MAX_DIRS-1) - dir;
            grid[sq] += mask_old; DrawPos(sq);
            sq = newSq;
            grid[sq] += mask_new; DrawPos(sq);
            count--;
            pause();
         }
         else
         {  // We're moved to a square we've already visited.
            // Either we continue moving around, or we - occasionally -
            // teleport to a random other square inside the part of the maze
            // already built.
            if ((my_rand() % 6) == 0)
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
   }
} // end of InitMaze


static void playGame()
{
   /* Set start square to lower right corner */
   int curSq = MAX_SQUARES - 1;

   while (curSq >= 0)
   {
      int dir;

      DrawPos(curSq);

      // Set cursor at current position.
      cputcxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2, curSq ? '@' : '*');
      gotoxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2);

      if (!curSq)
      {
         cputsxy(1, 38, "You escaped!\0");
         return;
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

      // Clear cursor at current position.
      cputcxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2, ' ');

      if (dir < MAX_DIRS)
      {
         if (grid[curSq] & (1<<dir))   // Check if move is allowed.
         {
            curSq += offset[dir];
         }
      }
   } // end of while (curSq >= 0)
} // end of playGame

int main()
{
   clrscr();
   cputsxy(1, 10, "Welcom to this aMAZEing game!\0");
   cputsxy(1, 12, "Press g to generate a new maze.\0");
   cputsxy(1, 13, "Move around with the keys wasd or hjkl.\0");
   cputsxy(1, 14, "Press r to reset the current maze.\0");
   cputsxy(1, 15, "Press q to quit the game.\0");

   switch (cgetc())
   {
      case 'g' :
         my_srand(time());    // Seed random number generator.
         InitMaze();          // Generate a completely new maze.
         clrscr();            // Clear screen.
         playGame();          // Play the game.
         break;

      case 'q' :
         cputsxy(1, 16, "GOODBYE!.\0");
         return 0;
   }

   return 0;
} // end of main

