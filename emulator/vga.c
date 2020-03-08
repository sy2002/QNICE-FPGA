/*
** QNICE VGA and PS2/USB keyboard Emulator
**
** done by sy2002 in December 2016 .. January 2017
** emscripten/WebGL version in February and March 2020
*/

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "fifo.h"
#include "vga.h"
#include "vga_font.h"

#include "../dist_kit/sysdef.h"

/* Currently, this is not threadsafe at all and therefore subject to strange
   things (though everything is obviously working very fine currently).
   To make this correct, all accesses to register variables throughout the
   whole code needs to be packed in the SDL equivalent of critical sections. */

//in native VGA mode (no emscripten): stabilize display thread to ~60 FPS
const unsigned long stable_fps_ms = 16; 

static Uint16   vram[65535];
static Uint16   vga_state;
static Uint16   vga_x;
static Uint16   vga_y;
static Uint16   vga_offs_display;
static Uint16   vga_offs_rw;

static Uint16   kbd_state;
static Uint16   kbd_data;
const  Uint16   kbd_fifo_size = 100;
fifo_t*         kbd_fifo;

#ifdef __EMSCRIPTEN__
const Uint16    display_dx  = 960;      //the hardware runs at a 1.8 : 1 ratio, see screenshots on GitHub
const Uint16    display_dy  = 534;
//const Uint16    display_dx  = 960;
//const Uint16    display_dy  = 600;
#else
const Uint16    display_dx  = 1280;     //1.8 : 1 ratio
const Uint16    display_dy  = 712;
//const Uint16    display_dx  = 1280;
//const Uint16    display_dy  = 800;
#endif
const Uint16    render_dx   = 640;
const Uint16    render_dy   = 480;
const Uint16    screen_dx   = 80;
const Uint16    screen_dy   = 40;
const Uint16    font_dx     = QNICE_FONT_CHAR_DX_BITS;
const Uint16    font_dy     = QNICE_FONT_CHAR_DY_BYTES;
const float     zoom_x      = (float) display_dx / (float) render_dx;
const float     zoom_y      = (float) display_dy / (float) render_dy;
static Uint32   font[font_dx * font_dy * QNICE_FONT_CHARS];

static bool     cursor = false;

//data structures for rendering on screen
SDL_Window*          win;
SDL_Renderer*        renderer;
SDL_Texture*         screen_texture;
Uint32*              screen_pixels;

SDL_Event            event;
bool                 event_quit;

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

//    printf("%i\n", keycode);

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
                vga_render_to_pixelbuffer(vga_x, vga_y, (Uint8) value);
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

    vga_state = vga_x = vga_y = vga_offs_display = vga_offs_rw = 0;

    kbd_state = KBD_LOCALE_DE; //for now, we hardcode german keyboard layout
    kbd_data = 0;

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
    create_win_flags |=  SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_RESIZABLE;
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

    vga_create_font_cache();    
    vga_clear_screen();
    return 1;
}

void vga_create_font_cache()
{
    const Uint32 green = 0x0000ff00;
    for (int i = 0; i < QNICE_FONT_CHARS; i++)
        for (int char_y = 0; char_y < font_dy; char_y++)
            for (int char_x = 0; char_x < font_dx; char_x++)
                font[i * font_dx * font_dy + char_y * font_dx + char_x] = qnice_font[i * font_dy + char_y] & (128 >> char_x) ? green : 0;
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

/* For performance reasons, during normal operation, the vram is not completely rendered, but only the
   region that changed while writing a char using the respective registers.
   vga_refresh_rendering is used to restore the vram on screen (inside the pixelbuffer), e.g. to restore
   the background after having shown the speed change window or the speedstats */
void vga_refresh_rendering()
{
    for (int y = 0; y < screen_dy; y++)
        for (int x = 0; x < screen_dx; x++)
            vga_render_to_pixelbuffer(x, y, vram[y * screen_dx + x + vga_offs_display]);
}

void vga_render_to_pixelbuffer(int x, int y, Uint8 c)
{
    if (x < 0 || x >= screen_dx || y < 0 || y >= screen_dy)
        return;

    unsigned long scr_offs = y * font_dy * render_dx + x * font_dx;
    unsigned long fnt_offs = font_dx * font_dy * c;
    for (int char_y = 0; char_y < font_dy; char_y++)
    {
        for (int char_x = 0; char_x < font_dx; char_x++)
            screen_pixels[scr_offs + char_x] = font[fnt_offs + char_x]; 
        scr_offs += render_dx;
        fnt_offs += font_dx;
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
            SDL_Rect cursor_rect = {vga_x * font_dx * zoom_x, vga_y * font_dy * zoom_y, font_dx * zoom_x, font_dy * zoom_y};
            SDL_RenderFillRect(renderer, &cursor_rect);
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
    SDL_UpdateTexture(screen_texture, NULL, screen_pixels, render_dx * sizeof(Uint32));
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
