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

#include <stdio.h>
#include "sysdef.h"     // KBD_CUR_UP etc.
#include "conio.h"      // Function to write to the VGA screen
#include "qmon.h"       // Random generator
#include "maze_grid.h"  // The actual internals of the maze generation

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

typedef struct
{
   unsigned int seconds;
   unsigned int centis;
} t_time;

static t_time gbl_timer;   // Incremented in timer interrupt

static int gbl_timer_active;

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

// Record times for each level
t_time records[3];

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


static void draw_time(int x, int y, t_time time)
{
   if (time.seconds || time.centis)
   {
      unsigned int seconds = time.seconds;

      unsigned int hours = seconds / 3600;
      seconds = seconds % 3600;

      unsigned int minutes = seconds / 60;
      seconds = seconds % 60;

      char str[13] = "\0\0\0\0\0\0\0\0\0\0\0\0\0";
      snprintf(str, 13, "%02u:%02u:%02u.%02u",
            hours, minutes, seconds, time.centis);

      cputsxy(x, y, str, get_color());
   }
} // end of draw_time

static void draw_menu()
{
   int color = get_color();
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
   row++;
   cputsxy(1, row++, "Records:\0", color);
   cputsxy(1, row, "Level 1 : \0", color); draw_time(11, row++, records[0]);
   cputsxy(1, row, "Level 2 : \0", color); draw_time(11, row++, records[1]);
   cputsxy(1, row, "Level 3 : \0", color); draw_time(11, row++, records[2]);
} // end of draw_menu


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
      cputsxy(10, 10+i, end[i], color);
   }
   cputsxy(10, 30, "Press g to generate a new maze.\0", color);
} // end of draw_ending

static void game_over()
{
   int color = get_color();

   const char *msg[] = {
      "  _   _                                            _ _ ",
      " | \\ | |                                          | | |",
      " |  \\| | _____      __  _ __ ___  ___ ___  _ __ __| | |",
      " | . ` |/ _ \\ \\ /\\ / / | '__/ _ \\/ __/ _ \\| '__/ _` | |",
      " | |\\  |  __/\\ V  V /  | | |  __/ (_| (_) | | | (_| |_|",
      " |_| \\_|\\___| \\_/\\_/   |_|  \\___|\\___\\___/|_|  \\__,_(_)",
      "                                                       "};

   int updateRecord = 0;
   if (!records[level-1].seconds && !records[level-1].centis)
      updateRecord = 1;
   if (gbl_timer.seconds < records[level-1].seconds)
      updateRecord = 1;
   if (gbl_timer.seconds == records[level-1].seconds && gbl_timer.centis < records[level-1].centis)
      updateRecord = 1;

   if (updateRecord)
   {
      records[level-1] = gbl_timer;

      for (int i=0; i<7; ++i)
      {
         cputsxy(10, 22+i, msg[i], color);
      }
   }
} // end of game_over


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
         gbl_timer_active = 0;
         maze_draw(get_color(), get_mask());
         game_over();
         draw_ending();
         break;
   }
   int ch;
   do
   {
      if (gameState == PLAYING)
         draw_time(10, 39, gbl_timer);
      ch = cpeekc();
   } while (!ch);

   if (hint)
   {
      clrscr();
      hint = 0;
   }

   switch (ch)
   {
      case '1' : if (gameState == MENU) {level = 1;} break;
      case '2' : if (gameState == MENU) {level = 2;} break;
      case '3' : if (gameState == MENU) {level = 3;} break;
      case 'g' : if (gameState != PLAYING)
                 {
                    clrscr();
                    maze_init();
                    maze_draw(get_color(), get_mask());
                    if (level > 1)
                       clrscr();
                    gbl_timer.centis = 0;   // Start game timer
                    gbl_timer.seconds = 0;   // Start game timer
                    gbl_timer_active = 1;
                    gameState = PLAYING;
                 }
                 break;
      case 'r' : if (gameState != MENU) {maze_reset(); gameState = PLAYING;} break;
      case 'x' : hint = 1; gbl_timer.seconds += 10; break;
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


static __interrupt __norbank void timer_isr(void)
{
   if (gbl_timer_active)
   {
      gbl_timer.centis++;
      if (gbl_timer.centis == 100)
      {
         gbl_timer.centis = 0;
         gbl_timer.seconds++;
      }
   }
} // end of timer_isr

int main()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // Hide cursor

   // Configure a one-second timer interrupt
   MMIO(IO_TIMER_0_INT) = (unsigned int) timer_isr;
   MMIO(IO_TIMER_0_PRE) = 100;
   MMIO(IO_TIMER_0_CNT) = 10;

   qmon_srand(time());    // Seed random number generator.
   level = 1;

   gameState = MENU;
   while (1)
   {
      if (game_update())
         break;
   }

   // Disable timer interrupt
   MMIO(IO_TIMER_0_PRE) = 0;
   MMIO(IO_TIMER_0_CNT) = 0;

   MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR;   // Enable cursor

   return 0;
} // end of main

