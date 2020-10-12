#include "rand.h"    // Random generator
#include "conio.h"
#include "maze_grid.h"

// Define the size of the maze.
#define MAX_ROWS  18
#define MAX_COLS  38
#define MAX_SQUARES	(MAX_ROWS*MAX_COLS)

// Each square has a value that is a bitmask of open walls.
// E.g. the value 3 means that the square has openings to the north and the
// east, while there are blocking walls to the south and the west.
static char grid[MAX_SQUARES];

static int curSq;
static int endSq;

#define GetRow(sq)	(sq % MAX_ROWS)
#define GetCol(sq)	(sq / MAX_ROWS)

static const int offset[MAX_DIRS] = {-1, MAX_ROWS, -MAX_ROWS, 1};

static char GetRandomDir()
{
   return my_rand() % MAX_DIRS;
}

static int GetRandomSquare()
{
   return my_rand() % MAX_SQUARES;
}


// Draw the current square as 3x3 characters.
void maze_drawPos(int sq, int level, int hint)
{
   const char wall = '#';
   char col = 1 + 2*GetCol(sq);
   char row = 1 + 2*GetRow(sq);
   char g = grid[sq];

   int color = 0x0000;
   switch (level)
   {
      case 1 : color = 0x0000; break;  // COLOR_LIGHT_GREEN
      case 2 : color = 0x0400; break;  // COLOR_YELLOW
      case 3 : color = 0x0300; break;  // COLOR_ORANGE
   }

   if ((level == 1) ||
      ((level == 2) && (g&(1<<VISITED))) ||
      ((level == 3) && (sq == curSq)) ||
      ((hint == 1) && (sq == endSq)))
   {
      cputcxy(col,   row,   color + wall);
      cputcxy(col,   row+2, color + wall);
      cputcxy(col+2, row+2, color + wall);
      cputcxy(col+2, row,   color + wall);
      cputcxy(col+1, row,   color + ((g&(1<<DIR_NORTH)) ? ' ' : wall));
      cputcxy(col+2, row+1, color + ((g&(1<<DIR_EAST))  ? ' ' : wall));
      cputcxy(col,   row+1, color + ((g&(1<<DIR_WEST))  ? ' ' : wall));
      cputcxy(col+1, row+2, color + ((g&(1<<DIR_SOUTH)) ? ' ' : wall));
      if (sq == endSq)
         cputcxy(col+1, row+1, color + '*');
      else if (sq == curSq)
         cputcxy(col+1, row+1, color + '@');
      else
         cputcxy(col+1, row+1, color + ' ');
   }
} // end of maze_drawPos


void maze_draw(int level, int hint)
{
   clrscr();
   for (int sq=0; sq<MAX_SQUARES; ++sq)
   {
      maze_drawPos(sq, level, hint);
   }
   maze_drawPos(curSq, level, hint);
} // end of maze_draw


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
void maze_init()
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
            grid[sq] += mask_old; maze_drawPos(sq, 1, 0);
            sq = newSq;
            grid[sq] += mask_new; maze_drawPos(sq, 1, 0);
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

   curSq = MAX_SQUARES - 1;
   grid[curSq] |= 1<<VISITED;

   do
   {
      endSq = GetRandomSquare();
   } while (GetRow(endSq) >= MAX_ROWS/2 || GetCol(endSq) >= MAX_COLS/2);
} // end of maze_init


int maze_move(int dir)
{
   if (grid[curSq] & (1<<dir))   // Check if move is allowed.
   {
      curSq += offset[dir];
      grid[curSq] |= 1<<VISITED;
   }

   return (curSq == endSq);
} // end of maze_move


void maze_reset()
{
   for (int sq=0; sq<MAX_SQUARES; ++sq)
   {
      grid[sq] &= ~(1<<VISITED);
   }
   curSq = MAX_SQUARES - 1;
   grid[curSq] |= 1<<VISITED;
} // end of maze_reset


