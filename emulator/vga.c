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

int vga_main_loop()
{
    SDL_Window* win = SDL_CreateWindow("QNICE Emulator", 100, 100, 640, 400, SDL_WINDOW_OPENGL);
    if (win)
    {
        SDL_Renderer* renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
        if (renderer)
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
            }
            SDL_DestroyRenderer(renderer);
        }
        SDL_DestroyWindow(win);        
    }
    else
    {
        printf("Could not createt window: %s\n", SDL_GetError());
        return 0;
    }

    return 1;
}
