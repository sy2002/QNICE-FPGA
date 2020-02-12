/*
** QNICE VGA and PS2/USB keyboard Emulator
**
** done by sy2002 in December 2016 .. Januar 2017
*/

#include <stdbool.h>
#include <string.h>
#include "vga.h"
#include "vga_font.h"
#include "../dist_kit/sysdef.h"

/* Currently, this is not threadsafe at all and therefore subject to strange
   things (though everything is obviously working very fine currently).
   To make this correct, all accesses to register variables throughout the
   whole code needs to be packed in the SDL equivalent of critical sections. */

static Uint16   vram[65535];
static Uint16   vga_state;
static Uint16   vga_x;
static Uint16   vga_y;
static Uint16   vga_offs_display;
static Uint16   vga_offs_rw;

static Uint16   kbd_state;
static Uint16   kbd_data;

const int screen_dx = 80;
const int screen_dy = 40;
const int font_dx = QNICE_FONT_CHAR_DX_BITS;
const int font_dy = QNICE_FONT_CHAR_DY_BYTES;

static bool cursor = false;

SDL_Window* win;
SDL_Renderer* renderer;
SDL_Texture* font_tex;
SDL_Event event;
bool event_quit;

unsigned long sdl_ticks_prev;
unsigned long sdl_ticks_curr;
unsigned long fps_framecounter; 
unsigned int fps;
char fps_print_buffer[12];

unsigned int kbd_read_register(unsigned int address)
{
    switch (address)
    {
        case IO_KBD_STATE:
            return kbd_state;

        case IO_KBD_DATA:
            kbd_state &= 0xFFFC; //clear new key indicators
            return kbd_data;
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
        kbd_state |= KBD_ALT;
        alt_pressed = true;
    }
    else
    {
        kbd_state &= ~KBD_ALT;
        alt_pressed = false;
    }

    if (keycode > 0 && keycode < 128)
    {
        kbd_data = keycode;

        if (shift_pressed)
        {
            if (keycode >= 'a' && keycode <= 'z')
                kbd_data -= 32; //to upper
            else switch (keycode)
            {
                case '1': kbd_data = '!';   break;
                case '2': kbd_data = '"';   break;
                case '3': kbd_data = 0xA7;  break;
                case '4': kbd_data = '$';   break;
                case '5': kbd_data = '%';   break;
                case '6': kbd_data = '&';   break;
                case '7': kbd_data = '/';   break;
                case '8': kbd_data = '(';   break;
                case '9': kbd_data = ')';   break;
                case '0': kbd_data = '=';   break;
            }
        }

        //CTRL + <letter> "overwrites" any other behaviour to 1 .. 26
        if (ctrl_pressed && keycode >= 'a' && keycode <= 'z')
            kbd_data = keycode - 96; // a = 1, b = 2, ...

        /* For avoiding race conditions, this needs to be the last statement
           within this if branch and this is also the reason, why in the
           following else branch the KBD_NEW_SPECIAL assignment is done like
           it is done including the not so nice goto statement:
           As soon as the flag is set, the CPU in the parallel thread is
           likely to read the data. */
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

        //see description above at KBD_NEW_ASCII
        kbd_state |= KBD_NEW_SPECIAL;
    }
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
        case VGA_CHAR:          return vram[((vga_y * screen_dx + vga_x) & 0x0FFF) + vga_offs_rw] & 0x00FF;
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
            break;

        case VGA_OFFS_DISPLAY:  vga_offs_display = value;   break;
        case VGA_OFFS_RW:       vga_offs_rw = value;        break;        

        /* As you can see in "write_vga_registers" in file "vga_textmode.vhd" of hardware
           revision V1.41, there are some distinct - and from my today's one year later view
           *strange* - things happening when it comes to handling coordinate overflows.
           To be truly compatible to the hardware, we need to emulate this behaviour. */
        case VGA_CR_X:          vga_x = value & 0x00FF;     break;
        case VGA_CR_Y:          vga_y = value & 0x007F;     break;
        case VGA_CHAR:          vram[((vga_y * screen_dx + vga_x) & 0x0FFF) + vga_offs_rw] = value; break;
    }
}

int vga_setup_emu()
{
    win = SDL_CreateWindow("QNICE Emulator", 100, 100, 640, 480, SDL_WINDOW_OPENGL);
    if (win)
    {
        renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
        if (renderer)
        {
            font_tex = vga_create_font_texture(renderer);
            if (font_tex)
                return 1;
            else
            {
                printf("Unable to create font texture: %s\n", SDL_GetError());
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

    vga_state = vga_x = vga_y = vga_offs_display = vga_offs_rw = 0;
    vga_clear_screen();

    kbd_state = KBD_LOCALE_DE; //for now, we hardcode german keyboard layout
    kbd_data = 0;

    sdl_ticks_prev = SDL_GetTicks();
    fps = fps_framecounter = 0;

    return vga_setup_emu();
}

void vga_shutdown()
{
    SDL_DestroyTexture(font_tex);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);
    SDL_Quit();
}

int vga_create_thread(vga_tft thread_func, void* param)
{
    SDL_Thread* mlt = SDL_CreateThread(thread_func, "main_loop", param);
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
    for (int i = 0; i < 65535; i++)
        vram[i] = ' ';
    vga_state &= ~(VGA_BUSY | VGA_CLR_SCRN);
}

void vga_print(int x, int y, bool absolute, char* s)
{
    int offs = absolute ? 0 : vga_offs_rw;
    for (int i = 0; i < strlen(s); i++)
        vram[y * screen_dx + x + offs + i] = s[i];
}    

SDL_Texture* vga_create_font_texture()
{

    SDL_Surface* surface = SDL_CreateRGBSurface(0, 8, QNICE_FONT_SIZE, 32, 0, 0, 0, 0);
    if (surface)
    {
        for (int i = 0; i < QNICE_FONT_CHARS; i++)
            for (int char_y = 0; char_y < font_dy; char_y++)
                for (int char_x = 0; char_x < font_dx; char_x++)
                {                        
                    Uint32 y_coord = i * font_dy + char_y;
                    Uint32* target_pixel = (Uint32*) ((Uint8*) surface->pixels + y_coord * surface->pitch + char_x * sizeof *target_pixel);
                    *target_pixel = qnice_font[y_coord] & (128 >> char_x) ? 0x0000ff00 : 0;
                }
        SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
        SDL_FreeSurface(surface);        
        if (texture)
            return texture;
    }

    return 0;
}

void vga_render_vram()
{
    SDL_Rect font_rect = {0, 0, font_dx, font_dy};
    SDL_Rect screen_rect = {0, 0, font_dx, font_dy};

    for (int y = 0; y < screen_dy; y++)
        for (int x = 0; x < screen_dx; x++)
        {
            font_rect.y = vram[y * screen_dx + x + vga_offs_display] * font_dy;
            screen_rect.x = x * font_dx;
            screen_rect.y = y * font_dy;
            SDL_RenderCopy(renderer, font_tex, &font_rect, &screen_rect);
        }
}

void vga_render_cursor()
{
    static Uint32 milliseconds;
    if (vga_state & VGA_EN_HW_CURSOR)
    {
        if (SDL_GetTicks() > milliseconds + VGA_CURSOR_BLINK_SPEED)
        {
            cursor = !cursor;
            milliseconds = SDL_GetTicks();
        }

        if (cursor)
        {
            SDL_Rect font_rect = {0, 0x11 * font_dy, font_dx, font_dy};  //0x11 is the char used as cursor
            SDL_Rect screen_rect = {vga_x * font_dx, vga_y * font_dy, font_dx, font_dy};
            SDL_RenderCopy(renderer, font_tex, &font_rect, &screen_rect);
        }    
    }
}

void vga_one_iteration_keyboard()
{
    while (SDL_PollEvent(&event))
    {
        if (event.type == SDL_QUIT)
            event_quit = true;

        if (event.type == SDL_KEYDOWN)
        {
            SDL_Keycode keycode = ((SDL_KeyboardEvent*) &event)->keysym.sym;
            SDL_Keymod keymod = SDL_GetModState();
            kbd_handle_keydown(keycode, keymod);
        }
    }
}

void vga_one_iteration_screen()
{
    SDL_RenderClear(renderer);  
    vga_render_vram();
    vga_render_cursor();

#ifdef VGA_SHOW_FPS
    fps_framecounter++;
    sdl_ticks_curr = SDL_GetTicks();
    if (sdl_ticks_curr - sdl_ticks_prev > 1000)
    {
        sdl_ticks_prev = sdl_ticks_curr;
        fps = fps_framecounter;
        fps_framecounter = 0;
    }

    sprintf(fps_print_buffer, "FPS: %d", fps);
    vga_print(80 - strlen(fps_print_buffer), 0, false, fps_print_buffer);
#endif

    SDL_RenderPresent(renderer);
}

int vga_main_loop()
{
    event_quit = false;
    while (!event_quit)
    {
        vga_one_iteration_keyboard();
        vga_one_iteration_screen();
    }
    return 1;
}
