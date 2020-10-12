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

#include "conio.h"      // Function to write to the VGA screen
#include "rand.h"       // Random generator
#include "maze_grid.h"  // The actual internals of the maze generation

enum
{
   MENU,       // Show menu
   PLAYING,    // Show maze
   GAME_OVER   // Show end-screen
} gameState;

// Level 1 shows everything
// Level 2 shows the squares alreay visited
// Level 3 shows only the current square
int level = 1;

// If non-zero then display the ending square
int hint = 0;


static void draw_menu()
{
   int color = 0;
   switch (level)
   {
      case 1 : color = 0x0000; break;  // COLOR_LIGHT_GREEN
      case 2 : color = 0x0400; break;  // COLOR_YELLOW
      case 3 : color = 0x0300; break;  // COLOR_ORANGE
   }
   clrscr();
   cputsxy(1, 10, "Welcome to this aMAZEing game!\0", color);
   cputsxy(1, 12, "Press g to generate a new maze.\0", color);
   cputsxy(1, 13, "Press 123 to change the level of the game.\0", color);
   cputsxy(1, 14, "Move around with the keys WASD / HJKL / arrows.\0", color);
   cputsxy(1, 15, "Press r to reset the current maze.\0", color);
   cputsxy(1, 16, "Press x to get a hint.\0", color);
   cputsxy(1, 17, "Press q to quit the game.\0", color);
   cputsxy(1, 18, "Press m to return to this menu.\0", color);
} // end of draw_menu


static int game_update()
{
   switch (gameState)
   {
      case MENU:
         draw_menu();
         break;
      case PLAYING:
         maze_draw(level, hint);
         break;
      case GAME_OVER:
         maze_draw(level, hint);
         cputsxy(1, 38, "You escaped!\0", 0);
         break;
   }

   hint = 0;
   switch (cgetc())
   {
      case '1' : level = 1; break;
      case '2' : level = 2; break;
      case '3' : level = 3; break;
      case 'g' : if (gameState == MENU)
                 {
                    clrscr();
                    maze_init();
                    maze_draw(level, hint);
                    gameState = PLAYING;
                 }
                 break;
      case 'r' : if (gameState != MENU) {maze_reset(); gameState = PLAYING;} break;
      case 'x' : hint = 1; break;
      case 'm' : gameState = MENU; break;

      case 'w' : case 'k' : if (gameState == PLAYING) {if (maze_move(DIR_NORTH)) gameState = GAME_OVER;} break;
      case 's' : case 'j' : if (gameState == PLAYING) {if (maze_move(DIR_SOUTH)) gameState = GAME_OVER;} break;
      case 'd' : case 'l' : if (gameState == PLAYING) {if (maze_move(DIR_EAST)) gameState = GAME_OVER;} break;
      case 'a' : case 'h' : if (gameState == PLAYING) {if (maze_move(DIR_WEST)) gameState = GAME_OVER;} break;

      case 'q' : cputsxy(1, 38, "GOODBYE!.\0", 0);
                 return 1;    // End the game.
   }

   return 0; // Keep playing
} // end of gameUpdate


int main()
{
   my_srand(time());    // Seed random number generator.
   level = 1;

   gameState = MENU;
   while (1)
   {
      if (game_update())
         break;
   }

   return 0;
} // end of main

