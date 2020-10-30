// A simple tennis-game
//
// Compile with "qvc tennis.c sprite.c conio.c tennis_player.c tennis_sprite.c tennis_ball.c -O3"
// Use the arrow keys to move the player.
// Press Q or <ESC> to quit the game.

#include "tennis.h"

/* Define some useful constants */
const int CHAR_WIDTH    = 8;       // pixels
const int SCREEN_WIDTH  = 80;      // characters
const int SCREEN_HEIGHT = 40;      // characters
const int BAR_POS_CH    = 40;      // characters
const int BAR_HEIGHT_CH = 8;       // characters
const int BAR_LEFT      = 320;     // pixels
const int BAR_MIDDLE    = 324;     // pixels
const int BAR_RIGHT     = 328;     // pixels
const int BAR_TOP       = 384;     // pixels
const int PLAYER_SPEED  = 2;       // pixels/frame
const int PLAYER_RADIUS = 16;      // pixels
const int SCREEN_LEFT   = 8;       // pixels
const int SCREEN_RIGHT  = 632;     // pixels
const int SCREEN_BOTTOM = 480;     // pixels
const int SCREEN_TOP    = 12;      // pixels
const int WHITE_SQUARE  = PAL_FG_YELLOW + PAL_BG_YELLOW + ' ';  // palette and character
const int BALL_RADIUS   = 8;       // pixels
const int SPRITE_RADIUS = 16;      // pixels
const int VEL_SCALE     = 512;
const int POS_SCALE     = 32;
const int GRAVITY       = 12;      // pixels/frame^2


/* Forward declarations */
void player_init();
void player_draw();
int  player_update();

void ball_init();
void ball_draw();
int  ball_update();

/*
 * This function is called once at start of the program
 */
static void game_init()
{
   MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR;  // hide cursor
   MMIO(VGA_STATE) |= VGA_EN_SPRITE;      // enable sprites
   qmon_vga_cls();                        // clear screen
   sprite_clear_all();                    // clear any previous sprites

   player_init();
   ball_init();

   /* Draw playing field */
   for (int x=0; x<SCREEN_WIDTH; ++x)
   {
      cputcxy(x, 0, WHITE_SQUARE);
   }
   for (int y=0; y<SCREEN_HEIGHT; ++y)
   {
      cputcxy(0, y, WHITE_SQUARE);
      cputcxy(SCREEN_WIDTH-1, y, WHITE_SQUARE);
   }
   for (int y=SCREEN_HEIGHT-BAR_HEIGHT_CH; y<SCREEN_HEIGHT; ++y)
   {
      cputcxy(BAR_POS_CH, y, WHITE_SQUARE);
   }
} // end of game_init


/*
 * This function is called once at the end of the program
 */
static void game_exit()
{
   MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR;   // show cursor
   MMIO(VGA_STATE) &= ~VGA_EN_SPRITE;     // disable sprites
   qmon_vga_cls();                        // clear screen
   sprite_clear_all();                    // clear any previous sprites
} // end of game_exit


/*
 * This function is called once per frame, i.e. 60 times a second
 */
static void game_draw()
{
   player_draw();
   ball_draw();
} // end of game_draw


/*
 * This function is called once per frame, i.e. 60 times a second
 */
static int game_update()
{
   if (player_update())
      return 1;
   if (ball_update())
   {
      ball_init();
   }
   return 0;
} // end of game_update


/*
 * The main entry point
 */
int main()
{
   game_init();

   /* This is the main game loop */
   while (1)
   {
      /* Wait while screen is being rendered */
      while (MMIO(VGA_SCAN_LINE) < 480) {}

      game_draw();

      if (game_update())
         break;

      if (MMIO(IO_UART_SRA) & 1)
      {
         unsigned int tmp = MMIO(IO_UART_RHRA);
         break;
      }

      /* Wait until screen porch is finished */
      while (MMIO(VGA_SCAN_LINE) >= 480) {}
   }

   game_exit();

   return 0;
} // end of main

