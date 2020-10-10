/*
 * A litte game that generates a maze and lets the player find his/her
 * way out of the maze.
 *
 * Maze is displayed on the VGA screen.
 * Keyboard controls are:
 *   UP    : w
 *   DOWN  : s
 *   LEFT  : a
 *   RIGHT : d
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

int init = 0;

// Level 1 shows everything
// Level 2 shows the squares alreay visited
// Level 3 shows only the current square
int level = 1;

int curSq;
int endSq;
int hint = 0;

enum
{
   DIR_NORTH = 0,
   DIR_EAST,
   DIR_WEST,
   DIR_SOUTH,
   MAX_DIRS,
   VISITED = 7
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

   curSq = MAX_SQUARES - 1;
   grid[curSq] |= 1<<VISITED;

   do
   {
      endSq = GetRandomSquare();
   } while (GetRow(endSq) >= MAX_ROWS/2 || GetCol(endSq) >= MAX_COLS/2);
} // end of InitMaze


static void gameInit()
{
   init = 0;
   level = 1;
   hint = 0;

   clrscr();
   cputsxy(1, 10, "Welcome to this aMAZEing game!\0");
   cputsxy(1, 12, "Press g to generate a new maze.\0");
   cputsxy(1, 13, "Press 123 to change the level of the game.\0");
   cputsxy(1, 14, "Move around with the keys WASD / HJKL / arrows.\0");
   cputsxy(1, 15, "Press r to reset the current maze.\0");
   cputsxy(1, 16, "Press x to get a hint.\0");
   cputsxy(1, 17, "Press q to quit the game.\0");
   cputsxy(1, 18, "Press m to return to this menu.\0");
} // end of gameInit


static void ShowMaze()
{
   clrscr();
   for (int sq=0; sq<MAX_SQUARES; ++sq)
   {
      DrawPos(sq);
   }
} // end of ShowMaze


static void playerUpdate(int dir)
{
   if (!init)
      return;

   if (grid[curSq] & (1<<dir))   // Check if move is allowed.
   {
      curSq += offset[dir];
      grid[curSq] |= 1<<VISITED;
   }

   if (curSq == endSq)
   {
      ShowMaze();
      cputsxy(1, 38, "You escaped!\0");
   }
} // end of playerUpdate

static void ResetMaze()
{
   for (int sq=0; sq<MAX_SQUARES; ++sq)
   {
      grid[sq] &= ~(1<<VISITED);
   }
   curSq = MAX_SQUARES - 1;
   grid[curSq] |= 1<<VISITED;
} // end of ResetMaze


static int gameUpdate()
{
   if (init)
   {
      ShowMaze();
      DrawPos(curSq);
   }

   hint = 0;
   char ch;
   switch (ch = cgetc())
   {
      case '1' : if (init) {level = 1; ShowMaze();} break;
      case '2' : if (init) {level = 2; ShowMaze();} break;
      case '3' : if (init) {level = 3; ShowMaze();} break;
      case 'g' : clrscr(); InitMaze(); ShowMaze(); init = 1; break;
      case 'r' : ResetMaze(); break;
      case 'x' : hint = 1; break;
      case 'm' : gameInit(); break;

      case 'w' : case 'k' : playerUpdate(DIR_NORTH); break;
      case 's' : case 'j' : playerUpdate(DIR_SOUTH); break;
      case 'd' : case 'l' : playerUpdate(DIR_EAST); break;
      case 'a' : case 'h' : playerUpdate(DIR_WEST); break;

      case 'q' : cputsxy(1, 38, "GOODBYE!.\0");
                 return 1;    // End the game.
   }

   return 0; // Keep playing
} // end of gameUpdate


int main()
{
   my_srand(time());    // Seed random number generator.

   gameInit();
   while (1)
   {
      if (gameUpdate())
         break;
   }

   return 0;
} // end of main

