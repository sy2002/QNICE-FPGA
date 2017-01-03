/*
** Header file for the VGA and PS2/USB keyboard emulation.
**
** done by sy2002 in December 2016 .. Januar 2017
*/

#ifndef _QEMU_VGA
#define _QEMU_VGA

#include "SDL.h"

#define VGA_CURSOR_BLINK_SPEED 500  //milliseconds between cursor on/off

typedef int (vga_tft)(void*);

unsigned int vga_read_register(unsigned int address);
void vga_write_register(unsigned int address, unsigned int value);

unsigned int kbd_read_register(unsigned int address);
void kbd_write_register(unsigned int address, unsigned int value);

int vga_init();
void vga_shutdown();
int vga_create_thread(vga_tft thread_func, void* param);
int vga_main_loop();
void vga_clear_screen();

#endif