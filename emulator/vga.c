/*
** QNICE VGA Emulator
**
** done by sy2002 in December 2016 .. Januar 2017
*/

#include <stdbool.h>
#include "vga.h"
#include "vga_font.h"
#include "../dist_kit/sysdef.h"

static Uint16   vram[65535];
static Uint16   vga_state;
static Uint16   vga_x;
static Uint16   vga_y;
static Uint16   vga_offs_display ;
static Uint16   vga_offs_rw;

const int screen_dx = 80;
const int screen_dy = 40;
const int font_dx = QNICE_FONT_CHAR_DX_BITS;
const int font_dy = QNICE_FONT_CHAR_DY_BYTES;

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
        case VGA_STATE:         vga_state = value;          break;
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

int vga_init()
{
    SDL_SetMainReady();

    if (SDL_Init(SDL_INIT_VIDEO) != 0)
    {
        printf("\nUnable to initialize SDL:  %s\n", SDL_GetError());
        return 0;
    }

    vga_state = vga_x = vga_y = vga_offs_display = vga_offs_rw = 0;
    vga_clear_screen();
    return 1;
}

void vga_shutdown()
{
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

SDL_Texture* vga_create_font_texture(SDL_Renderer* renderer)
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

void vga_render_vram(SDL_Renderer* renderer, SDL_Texture* font_tex)
{
    SDL_Rect font_rect = {0, 0, font_dx, font_dy};
    SDL_Rect screen_rect = {0, 0, font_dx, font_dy};

    SDL_RenderClear(renderer);  

    for (int y = 0; y < screen_dy; y++)
        for (int x = 0; x < screen_dx; x++)
        {
            font_rect.y = vram[y * screen_dx + x + vga_offs_display] * font_dy;
            screen_rect.x = x * font_dx;
            screen_rect.y = y * font_dy;
            SDL_RenderCopy(renderer, font_tex, &font_rect, &screen_rect);
        }

    SDL_RenderPresent(renderer);
}

int vga_main_loop()
{
    SDL_Window* win = SDL_CreateWindow("QNICE Emulator", 100, 100, 640, 480, SDL_WINDOW_OPENGL);
    if (win)
    {
        SDL_Renderer* renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
        if (renderer)
        {
            SDL_Texture* font_tex = vga_create_font_texture(renderer);
            if (font_tex)
            {
                SDL_Event e;
                bool quit = false;
                while (!quit)
                {
                    while (SDL_PollEvent(&e))
                    {
                        if (e.type == SDL_QUIT)
                            quit = true;
                    }

                    vga_render_vram(renderer, font_tex);
                }
                SDL_DestroyTexture(font_tex);
                return 1;
            }
            else
            {
                printf("Unable to create font texture: %s\n", SDL_GetError());
                return 0;
            }
            SDL_DestroyRenderer(renderer);
        }
        else
        {
            printf("Unable to create renderer: %s\n", SDL_GetError());
            return 0;
        }
        SDL_DestroyWindow(win);        
    }
    else
    {
        printf("Unable to create window: %s\n", SDL_GetError());
        return 0;
    }
}

void vga_clear_screen()
{
    for (int i = 0; i < 65535; i++)
        vram[i] = ' ';
}
