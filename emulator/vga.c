/*
** QNICE VGA Emulator
**
** done by sy2002 in December 2016 .. Januar 2017
*/

#include <stdbool.h>
#include "vga.h"
#include "vga_font.h"

int vga_init()
{
    SDL_SetMainReady();

    if (SDL_Init(SDL_INIT_VIDEO) != 0)
    {
        printf("\nUnable to initialize SDL:  %s\n", SDL_GetError());
        return 0;
    }

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
            for (int char_y = 0; char_y < QNICE_FONT_CHAR_DY_BYTES; char_y++)
                for (int char_x = 0; char_x < QNICE_FONT_CHAR_DX_BITS; char_x++)
                {                        
                    Uint32 y_coord = (i * QNICE_FONT_CHAR_DY_BYTES) + char_y;
                    Uint32* target_pixel = (Uint32*) ((Uint8*) surface->pixels + (y_coord * surface->pitch) + (char_x * sizeof *target_pixel));
                    *target_pixel = qnice_font[y_coord] & (128 >> char_x) ? 0x0000ff00 : 0;
                }
        SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
        if (texture)
            return texture;
        SDL_FreeSurface(surface);
    }

    return 0;
}

int vga_main_loop()
{
    SDL_Window* win = SDL_CreateWindow("QNICE Emulator", 100, 100, 640, 400, SDL_WINDOW_OPENGL);
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

                    SDL_RenderClear(renderer);

                    SDL_Rect font_rect1 = {0, 924, 8, 399};
                    SDL_Rect screen_rect1 = {0, 0, 8, 399};
                    SDL_RenderCopy(renderer, font_tex, &font_rect1, &screen_rect1);

                    SDL_Rect font_rect2 = {0, 924, 8, 399};
                    SDL_Rect screen_rect2 = {8, 0, 8, 399};
                    SDL_RenderCopy(renderer, font_tex, &font_rect2, &screen_rect2);

                    SDL_RenderPresent(renderer);
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
