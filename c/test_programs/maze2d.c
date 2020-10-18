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

#include "sysdef.h"     // KBD_CUR_UP etc.
#include "conio.h"      // Function to write to the VGA screen
#include "qmon.h"       // Random generator
#include "maze_grid.h"  // The actual internals of the maze generation

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

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
   int row = 5;
   cputsxy(1, row++, "Welcome to this aMAZEing game!\0", color);
   row++;
   cputsxy(1, row++, "You are trapped in the maze.", color);
   cputsxy(1, row++, "Find your way to the * to escape!", color);
   cputsxy(1, row++, "* In Level 1, you know where you are.", color);
   cputsxy(1, row++, "* In Level 2, you can still remember the path you walked.", color);
   cputsxy(1, row++, "* But in level 3, only a dim torch is illuminating the direct surrounding.", color);
   row++;
   cputsxy(1, row++, "Don't be ashamed to ask for help and press 'x' in level 2 and level 3.", color);
   row++;
   cputsxy(1, row++, "Press g to generate a new maze.\0", color);
   cputsxy(1, row++, "Press 123 to change the level of the game.\0", color);
   cputsxy(1, row++, "Move around with the keys WASD / HJKL / arrows.\0", color);
   cputsxy(1, row++, "Press r to reset the current maze.\0", color);
   cputsxy(1, row++, "Press q to quit the game.\0", color);
   cputsxy(1, row++, "Press m to return to this menu.\0", color);
} // end of draw_menu


static int get_color()
{
   switch (level)
   {
      case 1 : return 0x0000;   // COLOR_LIGHT_GREEN
      case 2 : return 0x0400;   // COLOR_YELLOW
      case 3 : return 0x0300;   // COLOR_ORANGE
   }
   return 0x0000;
} // end of get_color


static int get_mask()
{
   switch (level)
   {
      case 1 : return MAZE_MASK_ALL;
      case 2 : return MAZE_MASK_VISITED | (hint ? MAZE_MASK_END : 0);
      case 3 : return MAZE_MASK_CURRENT | (hint ? MAZE_MASK_END : 0);
   }
   return MAZE_MASK_ALL;
} // end of get_mask


static void draw_ending()
{
   int color = get_color();

   const char *end[] = {
      " __     __                                              _   ",
      " \\ \\   / /                                             | |  ",
      "  \\ \\_/ /__  _   _    ___  ___  ___ __ _ _ __   ___  __| |  ",
      "   \\   / _ \\| | | |  / _ \\/ __|/ __/ _` | '_ \\ / _ \\/ _` |  ",
      "    | | (_) | |_| | |  __/\\__ \\ (_| (_| | |_) |  __/ (_| |  ",
      "    |_|\\___/ \\__,_|  \\___||___/\\___\\__,_| .__/ \\___|\\__,_|  ",
      "                                        | |                 ",
      "                                        |_|                 ",
      "                                                            "};
   for (int i=0; i<9; ++i)
   {
      cputsxy(10, 15+i, end[i], color);
   }
   cputsxy(10, 30, "Press g to generate a new maze.\0", color);
} // end of draw_ending

static int game_update()
{
   switch (gameState)
   {
      case MENU:
         draw_menu();
         break;
      case PLAYING:
         if (level == 3)
            clrscr();
         maze_draw(get_color(), get_mask());
         break;
      case GAME_OVER:
         maze_draw(get_color(), get_mask());
         draw_ending();
         break;
   }
   int ch;
   do
   {
      ch = cpeekc();
   } while (!ch);

   if (hint)
   {
      clrscr();
      hint = 0;
   }

   switch (ch)
   {
      case '1' : level = 1; clrscr(); break;
      case '2' : level = 2; clrscr(); break;
      case '3' : level = 3; clrscr(); break;
      case 'g' : if (gameState != PLAYING)
                 {
                    clrscr();
                    maze_init();
                    maze_draw(get_color(), get_mask());
                    if (level > 1)
                       clrscr();
                    gameState = PLAYING;
                 }
                 break;
      case 'r' : if (gameState != MENU) {maze_reset(); gameState = PLAYING;} break;
      case 'x' : hint = 1; break;
      case 'm' : gameState = MENU; break;

      case 'w' : case 'k' : case KBD_CUR_UP    : if (gameState == PLAYING) {if (maze_move(DIR_NORTH)) gameState = GAME_OVER;} break;
      case 's' : case 'j' : case KBD_CUR_DOWN  : if (gameState == PLAYING) {if (maze_move(DIR_SOUTH)) gameState = GAME_OVER;} break;
      case 'd' : case 'l' : case KBD_CUR_RIGHT : if (gameState == PLAYING) {if (maze_move(DIR_EAST))  gameState = GAME_OVER;} break;
      case 'a' : case 'h' : case KBD_CUR_LEFT  : if (gameState == PLAYING) {if (maze_move(DIR_WEST))  gameState = GAME_OVER;} break;

      case 'q' : clrscr();
                 cputsxy(30, 18, "GOODBYE!\0", 0);
                 return 1;    // End the game.
   }

   return 0; // Keep playing
} // end of gameUpdate


int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Hide cursor

   qmon_srand(time());    // Seed random number generator.
   level = 1;

   gameState = MENU;
   while (1)
   {
      if (game_update())
         break;
   }

   MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR;   // Enable cursor

   return 0;
} // end of main

