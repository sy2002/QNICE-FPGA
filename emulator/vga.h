/*
** Header file for the VGA and PS2/USB keyboard emulation.
**
** done by sy2002 in December 2016 .. Januar 2017
*/

#ifndef _QEMU_VGA
#define _QEMU_VGA

#include <stdbool.h>
#include "SDL.h"

#define VGA_CURSOR_BLINK_SPEED 500  //milliseconds between cursor on/off

typedef int (vga_tft)(void*);

unsigned int    vga_read_register(unsigned int address);
void            vga_write_register(unsigned int address, unsigned int value);

unsigned int    kbd_read_register(unsigned int address);
void            kbd_write_register(unsigned int address, unsigned int value);

int             vga_init();
void            vga_shutdown();
void            vga_create_font_cache();
int             vga_create_thread(vga_tft thread_func, const char* thread_name, void* param);
void            vga_clear_screen();
void            vga_refresh_rendering();
void            vga_render_to_pixelbuffer(int x, int y, Uint8 c);
void            vga_render_cursor();
void            vga_render_speedwin(const char* message);
void            vga_print(int x, int y, char* s);
void            vga_one_iteration_keyboard();
void            vga_one_iteration_screen();

#if defined(USE_VGA) && !defined(__EMSCRIPTEN__)
int             vga_main_loop();
bool            vga_timebase_thread_running;
int             vga_timebase_thread(void* param);
#endif

#endif