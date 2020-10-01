/*
** QNICE VGA and PS2/USB keyboard Emulator
**
** done by sy2002 in December 2016 .. January 2017
** emscripten/WebGL version in February and March 2020
**
** Known harmless race-conditions:
** In multithreaded native VGA mode, this codes contains some possibilities for
** harmless race-conditions: Registers are being read or written by the CPU thread
** where in parallel the SDL thread accesses the same memory for the screen or
** for the keyboard. The consequences are minor and cannot be observed by humans
** since their timespan of occurrence is too small and the situation heals itself.
** In this context and for better code readability, we did not prevent these
** harmless race-conditions. If this changes one day, here are the sensitive areas:
** kbd_state, kbd_data, vga_state, vga_x, vga_y, vga_offs_display,
** vga_offs_rw, vram, screen_pixels
*/

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "fifo.h"
#include "vga.h"
#include "vga_font.h"

#include "../dist_kit/sysdef.h"

//in native VGA mode (no emscripten): stabilize display thread to ~60 FPS
const unsigned long stable_fps_ms = 16; 

static Uint16   vram[65535];
static Uint16   sprite_config[0x200];
static Uint32   sprite_palette[0x800];
static Uint16   sprite_bitmap[0x8000];
static Uint16   vga_state;
static Uint16   vga_x;
static Uint16   vga_y;
static Uint16   vga_offs_display;
static Uint16   vga_offs_rw;
static Uint16   vga_adjust_x;
static Uint16   vga_adjust_y;
static Uint16   font_addr;
static Uint16   font_offset;
static Uint16   palette_addr;
static Uint16   palette_offset;
static Uint16   sprite_addr;


static Uint16   kbd_state;
static Uint16   kbd_data;
const  Uint16   kbd_fifo_size = 100;
fifo_t*         kbd_fifo;

#ifdef __EMSCRIPTEN__
    #define display_dx ((Uint16) 960)      //the hardware runs at a 1.8 : 1 ratio, see screenshots on GitHub
    #define display_dy ((Uint16) 534)      //600 would be a 1.6 : 1 ratio
#else
    #define display_dx ((Uint16) 1280)     //1.8 : 1 ratio
    #define display_dy ((Uint16) 712)      //800 would be a 1.6 : 1 ratio
#endif

#define render_dx ((Uint16) 640)
#define render_dy ((Uint16) 480)
#define screen_dx ((Uint16) 80)
#define screen_dy ((Uint16) 40)
#define font_dx   ((Uint16) QNICE_FONT_CHAR_DX_BITS)
#define font_dy   ((Uint16) QNICE_FONT_CHAR_DY_BYTES)

const float     zoom_x      = (float) display_dx / (float) render_dx;
const float     zoom_y      = (float) display_dy / (float) render_dy;

static bool     cursor = false;
static float    cursor_fx, cursor_fy; //compensation factors for non-propotionally resized window

//data structures for rendering on screen
SDL_Window*          win;
SDL_Renderer*        renderer;
SDL_Texture*         screen_texture;
Uint32*              screen_pixels;

SDL_Event            event;
bool                 event_quit;

volatile bool        gbl$rendering = false;
volatile unsigned long gbl$render_start_time = 0;
volatile unsigned long gbl$render_stop_time = 0;
unsigned long        gbl$sdl_ticks;
unsigned long        sdl_ticks_prev;
unsigned long        sdl_ticks_curr;
unsigned long        fps_framecounter; 
unsigned int         fps;
char                 fps_print_buffer[screen_dx];
Uint16               fps_background_save[19];

extern float         gbl$mips;
extern unsigned long gbl$mips_inst_cnt;
extern bool          gbl$shutdown_signal;
extern bool          gbl$speedstats;
bool                 speedstats_rendered;

const unsigned int   speed_change_timer_duration = 3000;    //display duration of speed change in ms
unsigned int         speed_change_timer = 0;
char                 speed_change_msg[screen_dx];

#ifndef __EMSCRIPTEN__
bool                 vga_timebase_thread_running = false;
extern void          gbl_set_target_mips(float new_mips);
extern void          gbl_change_target_mips(float delta);
extern float         gbl$qnice_mips;
extern float         gbl$max_mips;
extern float         gbl$target_mips;
#else
extern unsigned long gbl$ipi_default;
extern unsigned long gbl$instructions_per_iteration;
#endif

unsigned int kbd_read_register(unsigned int address)
{
    switch (address)
    {
        case IO_KBD_STATE:
            return kbd_state;

        case IO_KBD_DATA:
#ifndef __EMSCRIPTEN__        
            kbd_state &= 0xFFFC; //clear new key indicators
            return kbd_data;
#else
            if (kbd_fifo->count)
            {
                //no more keys after this key?
                if (kbd_fifo->count == 1)
                    kbd_state &= 0xFFFC;
                return fifo_pull(kbd_fifo);
            }
#endif
    }

    return 0;
}

void kbd_write_register(unsigned int address, unsigned int value)
{
    switch (address)
    {
        case IO_KBD_STATE:  kbd_state = value;  break;
        case IO_KBD_DATA:   kbd_data = value;   break;
    }
}

void kbd_handle_keydown(SDL_Keycode keycode, SDL_Keymod keymod)
{
    bool shift_pressed;
    bool ctrl_pressed;
    bool alt_pressed;

    if (keymod & KMOD_SHIFT || keymod & KMOD_CAPS)
    {
        kbd_state |= KBD_SHIFT;
        shift_pressed = true;
    }
    else
    {
        kbd_state &= ~KBD_SHIFT;
        shift_pressed = false;
    }

    if (keymod & KMOD_CTRL)
    {
        kbd_state |= KBD_CTRL;
        ctrl_pressed = true;
    }
    else
    {
        kbd_state &= ~KBD_CTRL;
        ctrl_pressed = false;
    }

    if (keymod & KMOD_ALT)
    {
        float delta, sign;

        kbd_state |= KBD_ALT;
        alt_pressed = true;

        const char* hotkeys = "fcvnm";
        if (strchr(hotkeys, keycode))
        {
            switch (keycode)
            {
                case 'f':
                    gbl$speedstats = !gbl$speedstats;                
                    return;

#ifndef __EMSCRIPTEN__
                case 'c':
                    gbl_set_target_mips(gbl$qnice_mips);
                    sprintf(speed_change_msg, "Set target MIPS to QNICE hardware (%.1f MIPS)", gbl$qnice_mips);
                    break;

                case 'v':
                    gbl_set_target_mips(gbl$max_mips);
                    sprintf(speed_change_msg, "Set target MIPS to MAXIMUM");
                    break;

                case 'n':
                case 'm':
                    delta = shift_pressed  ?  1.0 : 0.1;
                    sign  = keycode == 'n' ? -1.0 : 1.0;
                    gbl_change_target_mips(sign * delta);
                    sprintf(speed_change_msg, "Set target MIPS to %.1f MIPS", gbl$target_mips);
                    break;
#else
                case 'c':
                    gbl$instructions_per_iteration = gbl$ipi_default;
                    sprintf(speed_change_msg, "Set instructions per frame to default (%lu)", gbl$ipi_default);
                    break;

                case 'v':
                    sprintf(speed_change_msg, "Current instructions per frame: %lu", gbl$instructions_per_iteration);
                    break;

                case 'n':
                case 'm':
                    delta = shift_pressed  ?  100000 : 2500;
                    if (keycode == 'n')
                    {
                        if (gbl$instructions_per_iteration > delta)
                            gbl$instructions_per_iteration -= delta;
                        else
                            gbl$instructions_per_iteration = 0;
                    }
                    else
                        gbl$instructions_per_iteration += delta;
                    sprintf(speed_change_msg, "Set instructions per frame to %lu", gbl$instructions_per_iteration);
                    break;
#endif
            }
            keycode = 0;
            vga_refresh_rendering();
            speed_change_timer = gbl$sdl_ticks;
        }
    }
    else
    {
        kbd_state &= ~KBD_ALT;
        alt_pressed = false;
    }

    if ((keycode > 0 && keycode < 128) || keycode == 60 || keycode == 94 || keycode == 223 || keycode == 228 || keycode == 246 || keycode == 252)
    {
        kbd_data = keycode;

        if (shift_pressed)
        {
            if (keycode >= 'a' && keycode <= 'z')
                kbd_data -= 32; //to upper
            else switch (keycode)
            {
                //whole mapping table is currently DE keyboard specific
                case '1':   kbd_data = '!';   break;
                case '2':   kbd_data = '"';   break;
                case '3':   kbd_data = 0xA7;  break;
                case '4':   kbd_data = '$';   break;
                case '5':   kbd_data = '%';   break;
                case '6':   kbd_data = '&';   break;
                case '7':   kbd_data = '/';   break;
                case '8':   kbd_data = '(';   break;
                case '9':   kbd_data = ')';   break;
                case '0':   kbd_data = '=';   break;
                case ',':   kbd_data = ';';   break;
                case '.':   kbd_data = ':';   break;
                case '-':   kbd_data = '_';   break;
                case '+':   kbd_data = '*';   break;
                case '#':   kbd_data = 0x27;  break;

                case 60:    kbd_data = 0xB0;  break;
                case 94:    kbd_data = 0x3E;  break;
                case 223:   kbd_data = '?';   break;
                case 228:   kbd_data = 0xC4;  break;
                case 246:   kbd_data = 0xD6;  break;
                case 252:   kbd_data = 0xDC;  break;
            }
        }
        else switch(keycode)
        {
            case 60:    kbd_data = 0x5E;  break;
            case 94:    kbd_data = 0x3C;  break;
            case 223:   kbd_data = 0xDF;  break;
        }

        //CTRL + <letter> "overwrites" any other behaviour to 1 .. 26
        if (ctrl_pressed && keycode >= 'a' && keycode <= 'z')
            kbd_data = keycode - 96; // a = 1, b = 2, ...

#ifdef __EMSCRIPTEN__
        fifo_push(kbd_fifo, kbd_data);
#endif

        /* For avoiding race conditions, this needs to be the last statement
           within this if branch and this is also the reason, why in the
           following else branch the KBD_NEW_SPECIAL assignment is done like
           it is done: As soon as the flag is set,
           the CPU in the parallel thread is likely to read the data. */
        kbd_state |= KBD_NEW_ASCII;
    }
    else
    {
        switch (keycode)
        {
            case SDLK_UP:       kbd_data = KBD_CUR_UP;      break;
            case SDLK_DOWN:     kbd_data = KBD_CUR_DOWN;    break;       
            case SDLK_LEFT:     kbd_data = KBD_CUR_LEFT;    break;       
            case SDLK_RIGHT:    kbd_data = KBD_CUR_RIGHT;   break;      
            case SDLK_PAGEUP:   kbd_data = KBD_PG_UP;       break;      
            case SDLK_PAGEDOWN: kbd_data = KBD_PG_DOWN;     break;    
            case SDLK_HOME:     kbd_data = KBD_HOME;        break;       
            case SDLK_END:      kbd_data = KBD_END;         break;    
            case SDLK_INSERT:   kbd_data = KBD_INS;         break;    
            case SDLK_DELETE:   kbd_data = KBD_DEL;         break;    

            default:
                if (keycode >= SDLK_F1 && keycode <= SDLK_F12)
                    kbd_data = (keycode - 0x4000003A + 1) << 8;
                else
                    return;
        }

#ifdef __EMSCRIPTEN__
        fifo_push(kbd_fifo, kbd_data);
#endif

        //see description above at KBD_NEW_ASCII
        kbd_state |= KBD_NEW_SPECIAL;
    }
}

static Uint32 palette[VGA_PALETTE_OFFS_MAX+1] = {

   0x0080C078, 0x0098A8F8, 0x0028D0D0, 0x00F89030, // Foreground colors
   0x00F8E830, 0x00E8D8B8, 0x00F8C8F0, 0x00F8F8F8,
   0x00000000, 0x00505050, 0x00A82020, 0x002848D0,
   0x00186810, 0x00804818, 0x008020C0, 0x00A0A0A0,

   0x00000000, 0x00505050, 0x00A82020, 0x002848D0, // Background colors
   0x00186810, 0x00804818, 0x008020C0, 0x00A0A0A0,
   0x0080C078, 0x0098A8F8, 0x0028D0D0, 0x00F89030,
   0x00F8E830, 0x00E8D8B8, 0x00F8C8F0, 0x00F8F8F8
};

static unsigned int palette_convert_24_to_15(Uint32 color)
{
   return ((color & 0x01F80000) >> 9)
        + ((color & 0x0000F800) >> 6)
        + ((color & 0x000000F8) >> 3);
}

static Uint32 palette_convert_15_to_24(unsigned int color)
{
   return ((color << 9) & 0x01F80000)
        + ((color << 6) & 0x0000F800)
        + ((color << 3) & 0x000000F8);
}

void vga_render_screen_area(int x_begin, int y_begin, int x_end, int y_end);

static void vga_update_sprite(int sprite)
{
   short pos_x = sprite_config[4*sprite];
   short pos_y = sprite_config[4*sprite+1];

   // Redraw part of screen
   vga_render_screen_area(pos_x/font_dx, pos_y/font_dy, (pos_x+32)/font_dx+1, (pos_y+32)/font_dy+1);
}

static void vga_sprite_write(unsigned int addr, unsigned int data)
{
   if (addr & 0x8000)
   {
      sprite_bitmap[addr & 0x7FFF] = data;

      // Determine which sprites are affected.
      for (int sprite=0; sprite<128; ++sprite)
      {
         unsigned short bitmap_ptr = sprite_config[4*sprite+2] & 0x7FFF;
         if ((addr & 0x7FFF) >= bitmap_ptr && (addr & 0x7FFF)+256 < bitmap_ptr)
         {
            vga_update_sprite(sprite);
         }

      }
   }
   else if (addr & 0x4000)
   {
      if (sprite_palette[addr & 0x07FF] != palette_convert_15_to_24(data))
      {
         sprite_palette[addr & 0x07FF] = palette_convert_15_to_24(data);

         // Determine which sprite is affected.
         int sprite = (addr & 0x07FF)/16;
         vga_update_sprite(sprite);
      }
   }
   else
   {
      // Determine which sprite is affected.
      int sprite = (addr & 0x01FF)/4;

      // Save old position (needed for redraw)
      short old_pos_x = ((short) sprite_config[4*sprite]) / font_dx;
      short old_pos_y = ((short) sprite_config[4*sprite+1]) / font_dy;

      sprite_config[addr & 0x01FF] = data;

      // Get new position
      short pos_x = ((short) sprite_config[4*sprite]) / font_dx;
      short pos_y = ((short) sprite_config[4*sprite+1]) / font_dy;

      if (old_pos_x != pos_x || old_pos_y != pos_y)
      {
         // The sprite position has changed, so we have to "clear" the sprite
         // at the old position, before redrawing at the new position.
         unsigned short old_config = sprite_config[4*sprite+3];   // Store old configuration
         sprite_config[4*sprite+3] = 0;                           // Clear visibility
         // Redraw old part of screen
         vga_render_screen_area(old_pos_x, old_pos_y, old_pos_x+5, old_pos_y+4);
         sprite_config[4*sprite+3] = old_config;                  // Restore old configuration
      }

      // Redraw new part of screen
      vga_render_screen_area(pos_x, pos_y, pos_x+5, pos_y+4);
   }
}

static unsigned int vga_sprite_read(unsigned int addr)
{
   if (addr & 0x8000)
   {
      return sprite_bitmap[addr & 0x7FFF];
   }
   else if (addr & 0x4000)
   {
      return palette_convert_24_to_15(sprite_palette[addr & 0x07FF]);
   }
   else
   {
      return sprite_config[addr & 0x01FF];
   }
}

static unsigned int min(unsigned int a, unsigned int b)
{
   if (a>b)
      return b;
   else
      return a;
}

unsigned int vga_read_register(unsigned int address)
{
    switch (address)
    {
        case VGA_STATE:         return vga_state;
        case VGA_OFFS_DISPLAY:  return vga_offs_display;
        case VGA_OFFS_RW:       return vga_offs_rw;

        /* The hardware is currently as of hardware revision V1.41 returning only part of the
           register bits, so we are emulating this here. See "read_vga_registers" in
           the file "vga_textmode.vhd". */
        case VGA_CR_X:          return vga_x & 0x00FF;
        case VGA_CR_Y:          return vga_y & 0x007F;
        case VGA_CHAR:          return vram[((vga_y * screen_dx + vga_x) & 0x0FFF) + vga_offs_rw];
        case VGA_ADJUST_X:      return vga_adjust_x;
        case VGA_ADJUST_Y:      return vga_adjust_y;

        case VGA_FONT_OFFS:     return font_offset;
        case VGA_FONT_ADDR:     return font_addr;
        case VGA_FONT_DATA:     return qnice_font[font_addr & VGA_FONT_OFFS_MAX];
        case VGA_PALETTE_OFFS:  return palette_offset;
        case VGA_PALETTE_ADDR:  return palette_addr;
        case VGA_PALETTE_DATA:  return palette_convert_24_to_15(palette[palette_addr & VGA_PALETTE_OFFS_MAX]);
        case VGA_SPRITE_ADDR:   return sprite_addr;
        case VGA_SPRITE_DATA:   return vga_sprite_read(sprite_addr++);

        case VGA_SCAN_LINE:     if (gbl$rendering)
                                   return min((gbl$sdl_ticks - gbl$render_start_time) * 525 * 60 / 1000, 479);
                                else
                                   return 480 + min((gbl$sdl_ticks - gbl$render_stop_time) * 525 * 60 / 1000, 524-480);
                                // return (gbl$sdl_ticks * 525 * 60 / 1000) % 525;
    }

    return 0;
}

void vga_write_register(unsigned int address, unsigned int value)
{
    switch (address)
    {
        case VGA_STATE:
            vga_state = (value & ~VGA_BUSY); //bit #9 is read-only, so mask it
            if (value & VGA_CLR_SCRN)
                vga_clear_screen();
            else
                vga_refresh_rendering();
            break;

        case VGA_OFFS_RW:
            vga_offs_rw = value;
            break;        

        case VGA_OFFS_DISPLAY:
            vga_offs_display = value;
            vga_refresh_rendering();
            break;

        /* As you can see in "write_vga_registers" in file "vga_textmode.vhd" of hardware
           revision V1.41, there are some distinct - and from my today's one year later view
           *strange* - things happening when it comes to handling coordinate overflows.
           To be truly compatible to the hardware, we need to emulate this behaviour. */
        case VGA_CR_X:
            vga_x = value & 0x00FF;
            break;

        case VGA_CR_Y:
            vga_y = value & 0x007F;
            break;

        case VGA_CHAR:
            //store character to video ram (vram)
            vram[((vga_y * screen_dx + vga_x) & 0x0FFF) + vga_offs_rw] = value;
            //make sure that the to-be-printed char is within the visible window
            unsigned int print_addr = vga_offs_rw + vga_y * screen_dx + vga_x;
            if (print_addr >= vga_offs_display && print_addr < vga_offs_display + screen_dy * screen_dx)
                vga_render_screen_area(vga_x, vga_y, vga_x+1, vga_y+1);
            break;

        case VGA_ADJUST_X:
            vga_adjust_x = value;
            vga_refresh_rendering();
            break;

        case VGA_ADJUST_Y:
            vga_adjust_y = value;
            vga_refresh_rendering();
            break;

        case VGA_FONT_OFFS:
            font_offset = value;
            vga_refresh_rendering();
            break;

        case VGA_FONT_ADDR:
            font_addr = value;
            break;

        case VGA_FONT_DATA:
            if (font_addr >= VGA_FONT_OFFS_USER && font_addr <= VGA_FONT_OFFS_MAX)
            {
               qnice_font[font_addr] = value;
               vga_refresh_rendering();
            }
            break;

        case VGA_PALETTE_OFFS:
            palette_offset = value;
            vga_refresh_rendering();
            break;

        case VGA_PALETTE_ADDR:
            palette_addr = value;
            break;

        case VGA_PALETTE_DATA:
            if (palette_addr >= VGA_PALETTE_OFFS_USER && palette_addr <= VGA_PALETTE_OFFS_MAX)
            {
               palette[palette_addr] = palette_convert_15_to_24(value);
               vga_refresh_rendering();
            }
            break;

        case VGA_SPRITE_ADDR:
            sprite_addr = value;
            break;

        case VGA_SPRITE_DATA:
            vga_sprite_write(sprite_addr++, value);
            break;
    }
}

int vga_init()
{
#ifndef __EMSCRIPTEN__
    SDL_SetMainReady();
#endif

    if (SDL_Init(SDL_INIT_VIDEO) != 0)
    {
        printf("\nUnable to initialize SDL:  %s\n", SDL_GetError());
        return 0;
    }

#ifdef __EMSCRIPTEN__
    /* The following SDL Hint is necessary due to this issue:
       https://github.com/emscripten-core/emscripten/issues/10746 */
    SDL_SetHint(SDL_HINT_EMSCRIPTEN_ASYNCIFY, "0");
#endif

    vga_state = vga_x = vga_y = vga_offs_display = vga_offs_rw = 0;
    font_addr = font_offset = palette_addr = palette_offset = 0;

    kbd_state = KBD_LOCALE_DE; //for now, we hardcode german keyboard layout
    kbd_data = 0;

    cursor_fx = cursor_fy = 1.0;

#ifdef __EMSCRIPTEN__
    gbl$sdl_ticks = SDL_GetTicks(); //in non-emscripten mode done by vga_timebase_thread
#endif
    fps = fps_framecounter = 0;
    speedstats_rendered = gbl$speedstats;
    
    kbd_fifo = fifo_init(kbd_fifo_size);

    unsigned long pixelheap = render_dx * render_dy * sizeof(Uint32);
    if ((screen_pixels = malloc(pixelheap)) == 0)
    {
        printf("Out of memory. Need %lu bytes of heap.", pixelheap);
        return 0;
    }

    Uint32 create_win_flags = SDL_WINDOW_OPENGL;
#ifndef __EMSCRIPTEN__
    create_win_flags |=  SDL_WINDOW_RESIZABLE;
#endif

    win = SDL_CreateWindow("QNICE Emulator", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, display_dx, display_dy, create_win_flags);
    if (win)
    {
        renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
        if (renderer)
        {
            SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");
            SDL_SetRenderDrawColor(renderer, 0, 255, 0, 0);
            screen_texture = SDL_CreateTexture( renderer,
                                                SDL_PIXELFORMAT_ARGB8888,
                                                SDL_TEXTUREACCESS_STREAMING,
                                                render_dx,
                                                render_dy);
            if (!screen_texture)
            {
                printf("Unable to screen texture: %s\n", SDL_GetError());
                return 0;
            }
        }
        else
        {
            printf("Unable to create renderer: %s\n", SDL_GetError());
            return 0;
        }
    }
    else
    {
        printf("Unable to create window: %s\n", SDL_GetError());
        return 0;
    }

    vga_clear_screen();
    return 1;
}

void vga_shutdown()
{
    fifo_free(kbd_fifo);
    free(screen_pixels);
    SDL_DestroyTexture(screen_texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);
    SDL_Quit();
}

int vga_create_thread(vga_tft thread_func, const char* thread_name, void* param)
{
    SDL_Thread* mlt = SDL_CreateThread(thread_func, thread_name, param);
    if (mlt)
    {
        SDL_DetachThread(mlt);
        return 1;
    }
    else
    {
        printf("\nUnable to create main thread.\n");
        return 0;
    }
}

void vga_clear_screen()
{
    vga_state |= VGA_BUSY | VGA_CLR_SCRN;
    for (Uint32 i = 0; i < 65535; i++)
        vram[i] = ' ';
    for (Uint32 i = 0; i < render_dx * render_dy; i++)
        screen_pixels[i] = 0;
    vga_state &= ~(VGA_BUSY | VGA_CLR_SCRN);
}

/* Prints to pixel buffer without modifying the video ram (vram).
   This means that vga_print must be called upon each render iteration, otherwise nothing is visible */
void vga_print(int x, int y, char* s)
{
    for (int i = 0; i < strlen(s); i++)
        vga_render_to_pixelbuffer(x + i, y, s[i]);
}    

#define VGA_COLOR_BACKGROUND 0x01000000

// arguments are pixel coordinates
static void vga_render_all_sprites(short x_begin, short y_begin, short x_end, short y_end)
{
   for (int i = 127; i >= 0; i--) // Loop over all sprites. Start with lowest priority
   {
      unsigned short csr = sprite_config[4*i+3];
      if (csr & VGA_SPRITE_CSR_VISIBLE)
      {
         unsigned short pos_x      = sprite_config[4*i];
         unsigned short pos_y      = sprite_config[4*i+1];
         unsigned short bitmap_ptr = sprite_config[4*i+2] & 0x7FFF;

         if (csr & VGA_SPRITE_CSR_HICOLOR)
         {
            for (unsigned short y = 0; y < 16; y++)
            {
               for (unsigned short x = 0; x < 16; x++)
               {
                  unsigned short tx = x;
                  unsigned short ty = y;
                  if (csr & VGA_SPRITE_CSR_MIRROR_X)
                     tx = 15-x;
                  if (csr & VGA_SPRITE_CSR_MIRROR_Y)
                     ty = 15-y;

                  unsigned int color = palette_convert_24_to_15(sprite_bitmap[bitmap_ptr + ty*16 + tx]);

                  if (!(color & VGA_COLOR_BACKGROUND))
                  {
                     short pix_x = pos_x + x;
                     short pix_y = pos_y + y;
                     if (pix_x >= x_begin && pix_x < x_end && pix_y >= y_begin && pix_y < y_end)
                     {
                        if (csr & VGA_SPRITE_CSR_BEHIND)
                        {
                           if (screen_pixels[render_dx*pix_y + pix_x] & VGA_COLOR_BACKGROUND)
                              screen_pixels[render_dx*pix_y + pix_x] = color | VGA_COLOR_BACKGROUND;
                        }
                        else
                           screen_pixels[render_dx*pix_y + pix_x] = color;
                     }
                  }
               }
            }
         }
         else
         {
            for (unsigned short y = 0; y < 32; y++)
            {
               for (unsigned short x = 0; x < 32; x++)
               {
                  unsigned short tx = x;
                  unsigned short ty = y;
                  if (csr & VGA_SPRITE_CSR_MIRROR_X)
                     tx = 31-x;
                  if (csr & VGA_SPRITE_CSR_MIRROR_Y)
                     ty = 31-y;

                  unsigned int color_index = (sprite_bitmap[bitmap_ptr + ty*8 + tx/4] >> (4*(~tx & 3))) & 0xF;
                  Uint32 color = sprite_palette[16*i+color_index];

                  if (!(color & VGA_COLOR_BACKGROUND))
                  {
                     short pix_x = pos_x + x;
                     short pix_y = pos_y + y;
                     if (pix_x >= x_begin && pix_x < x_end && pix_y >= y_begin && pix_y < y_end)
                     {
                        if (csr & VGA_SPRITE_CSR_BEHIND)
                        {
                           if (screen_pixels[render_dx*pix_y + pix_x] & VGA_COLOR_BACKGROUND)
                              screen_pixels[render_dx*pix_y + pix_x] = color | VGA_COLOR_BACKGROUND;
                        }
                        else
                           screen_pixels[render_dx*pix_y + pix_x] = color;
                     }
                  }
               }
            }
         }
      }
   }
}

// arguments are character coordinates
void vga_render_screen_area(int x_begin, int y_begin, int x_end, int y_end)
{
    while (gbl$rendering) {}  // To reduce screen flickering

    for (int y = y_begin; y < y_end; y++)
        for (int x = x_begin; x < x_end; x++)
            vga_render_to_pixelbuffer(x, y, vram[y * screen_dx + x + vga_offs_display]);

    if (vga_state & VGA_EN_SPRITE)
       vga_render_all_sprites(x_begin*font_dx, y_begin*font_dy, x_end*font_dx, y_end*font_dy);
}

/* For performance reasons, during normal operation, the vram is not completely rendered, but only the
   region that changed while writing a char using the respective registers.
   vga_refresh_rendering is used to restore the vram on screen (inside the pixelbuffer), e.g. to restore
   the background after having shown the speed change window or the speedstats */
void vga_refresh_rendering()
{
    vga_render_screen_area(0, 0, screen_dx, screen_dy);
}

void vga_render_to_pixelbuffer(int x, int y, Uint16 c)
{
    if (x < 0 || x >= screen_dx || y < 0 || y >= screen_dy)
        return;

    unsigned long scr_offs = (y * font_dy - vga_adjust_y)* render_dx + x * font_dx - vga_adjust_x;
    unsigned long fnt_offs = (font_dy * (c & 0xFF) + font_offset) & VGA_FONT_OFFS_MAX;
    Uint32 fg_col = palette[(palette_offset +      ((c >>  8) & 0xF)) & VGA_PALETTE_OFFS_MAX];
    Uint32 bg_col = palette[(palette_offset + 16 + ((c >> 12) & 0xF)) & VGA_PALETTE_OFFS_MAX] | VGA_COLOR_BACKGROUND;
    for (int char_y = 0; char_y < font_dy; char_y++)
    {
        unsigned int bitmap_row = qnice_font[fnt_offs];
        for (int char_x = 0; char_x < font_dx; char_x++)
            screen_pixels[scr_offs + char_x] = bitmap_row & (128 >> char_x) ? fg_col : bg_col;
        scr_offs += render_dx;
        fnt_offs += 1;
    }
}

void vga_render_cursor()
{
    static Uint32 milliseconds;

    if (vga_state & VGA_EN_HW_CURSOR)
    {
        if (gbl$sdl_ticks > milliseconds + VGA_CURSOR_BLINK_SPEED)
        {
            milliseconds = gbl$sdl_ticks;;
            cursor = !cursor;
        }

        if (cursor)
        {
            SDL_Rect cursor_rect = {
                vga_x * font_dx * zoom_x * cursor_fx,
                vga_y * font_dy * zoom_y * cursor_fy,
                font_dx * zoom_x * cursor_fx,
                font_dy * zoom_y * cursor_fy
            };
            SDL_RenderFillRect(renderer, &cursor_rect);
        }
    }
}

void vga_one_iteration_keyboard()
{
    while (SDL_PollEvent(&event))
    {
        if (event.type == SDL_KEYDOWN)
        {
            SDL_Keycode keycode = ((SDL_KeyboardEvent*) &event)->keysym.sym;
            SDL_Keymod keymod = SDL_GetModState();
            kbd_handle_keydown(keycode, keymod);
        }

        else if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED)
        {
            cursor_fx = event.window.data1 / (float) display_dx;
            cursor_fy = event.window.data2 / (float) display_dy;
        }

        else if (event.type == SDL_QUIT)
            event_quit = true;
    }
}

void vga_render_speedwin(const char* message)
{
    unsigned int x, y, dx, dy;
    char win[screen_dx];    
    char spaces[screen_dx];    

    dx = strlen(message) + 6;
    dy = 5;
    x = screen_dx / 2 - dx / 2;
    y = screen_dy / 2 - dy / 2;

    for (int i = 0; i < dx; spaces[i++] = 0x20);
    spaces[dx] = 0;
    vga_print(x, y, spaces);

    win[0] = 0x20;
    win[1] = 0x86;
    for (int i = 0; i < dx - 3; win[2 + i++] = 0x8A);
    win[dx - 2] = 0x8C;
    win[dx - 1] = 0x20;
    win[dx] = 0;
    vga_print(x, y+1, win);

    win[0] = 0x20;
    win[1] = 0x85;
    win[2] = 0x20;
    for (int i = 0; i < dx; i++)
        win[3 + i] = i < strlen(message) ? message[i] : 0x20;
    win[dx - 2] = 0x85;
    win[dx - 1] = 0x20;
    win[dx] = 0;
    vga_print(x, y+2, win);

    win[0] = 0x20;
    win[1] = 0x83;
    for (int i = 0; i < dx - 3; win[2 + i++] = 0x8A);
    win[dx - 2] = 0x89;
    win[dx - 1] = 0x20;
    win[dx] = 0;
    vga_print(x, y+3, win);
    vga_print(x, y+4, spaces);
}

void vga_one_iteration_screen()
{
    SDL_RenderClear(renderer);  
    
    //calculate FPS
    fps_framecounter++;
#ifdef __EMSCRIPTEN__
    gbl$sdl_ticks = SDL_GetTicks();
#endif
    if (gbl$sdl_ticks - sdl_ticks_prev > 1000)
    {
        sdl_ticks_prev = gbl$sdl_ticks;
        fps = fps_framecounter;
        fps_framecounter = 0;
    }

    //show MIPS and FPS
    if (gbl$speedstats)
    {
        sprintf(fps_print_buffer, "    %.1f MIPS @ %d FPS", gbl$mips, fps);
        vga_print(screen_dx - strlen(fps_print_buffer), 0, fps_print_buffer);
        speedstats_rendered = true;
    }
    else if (speedstats_rendered)
    {
        vga_refresh_rendering();
        speedstats_rendered = false;
    }

    //show speed change window
    if (speed_change_timer > 0)
    {
        if (gbl$sdl_ticks - speed_change_timer < speed_change_timer_duration)
            vga_render_speedwin(speed_change_msg);
        else
        {
            vga_refresh_rendering();
            speed_change_timer = 0;
        }
    }

    //high-performance way of displaying the screen using streaming textures
    gbl$rendering = true;
    gbl$render_start_time = gbl$sdl_ticks;
    SDL_UpdateTexture(screen_texture, NULL, screen_pixels, render_dx * sizeof(Uint32));
    gbl$rendering = false;
    gbl$render_stop_time = gbl$sdl_ticks;
    SDL_RenderCopy(renderer, screen_texture, NULL, NULL);
    vga_render_cursor();    
    SDL_RenderPresent(renderer);
}

#ifndef __EMSCRIPTEN__
int vga_main_loop()
{
    event_quit = false;
    while (!event_quit && !gbl$shutdown_signal)
    {
        unsigned long elapsed_ms = SDL_GetTicks();

        vga_one_iteration_keyboard();
        vga_one_iteration_screen();

        /* do not waste performance by displaying too many FPS: the real performance bottleneck
           is the emulation of the system (i.e. the MIPS), maximizing FPS does not make any sense */
        elapsed_ms = SDL_GetTicks() - elapsed_ms;
        if (elapsed_ms < stable_fps_ms)
            SDL_Delay(stable_fps_ms - elapsed_ms);
    }
    return 1;
}

int vga_timebase_thread(void* param)
{
    vga_timebase_thread_running = true;
    while (!gbl$shutdown_signal)
    {
        gbl$sdl_ticks = SDL_GetTicks();
        SDL_Delay(1);
    }
    vga_timebase_thread_running = false;    
    return 1;
}
#endif
