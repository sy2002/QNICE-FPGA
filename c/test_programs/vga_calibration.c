/*  VGA Monitor Calibration

    Shows a frame using the large character "X" so that the auto-calibrate
    function of the VGA monitor can work properly.

    How to compile: qvc vga_calibration.c -O3 -c99

    done by sy2002 in June 2020   
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"

//convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

//set cursor position for next printf
void set_cur(unsigned int x, unsigned int y)
{
    /* for printf to work, we need to change the Monitor's cursor variables...
       (see monitor/variables.asm) */
    unsigned int* cursor_x = (unsigned int*) 0xFEEC;
    unsigned int* cursor_y = (unsigned int*) 0xFEED;
    *cursor_x = x;
    *cursor_y = y;

    /* ... as well as the VGA position registers: both types of "memory" need
       to be in sync */
    MMIO(VGA_CR_X) = x;
    MMIO(VGA_CR_Y) = y;
}

void draw_help()
{
    set_cur(5, 4);  printf("QNICE VGA Monitor Calibration Tool - done by sy2002 in June 2020\n");
    set_cur(5, 7);  printf("Activate your monitor's auto calibration function now.\n");
    set_cur(5, 9);  printf("When done, press any key.\n");
}

/* Draw a frame of "X" as it is the largest letter */
void draw_calibration_screen()
{
    qmon_vga_cls();

    for (int x = 0; x < 80; x++)
    {
        MMIO(VGA_CR_X) = x;
        MMIO(VGA_CR_Y) = 0;
        MMIO(VGA_CHAR) = 'X';
        MMIO(VGA_CR_Y) = 39;
        MMIO(VGA_CHAR) = 'X';
        if (x > 0 & x < 79)
        {
            MMIO(VGA_CR_Y) = 1;
            MMIO(VGA_CHAR) = 48 + (x % 10); //ASCII 48 = '0'
        }        
    }

    for (int y = 1; y < 39; y++)
    {
        MMIO(VGA_CR_Y) = y;
        MMIO(VGA_CR_X) = 0;
        MMIO(VGA_CHAR) = 'X';
        MMIO(VGA_CR_X) = 79;
        MMIO(VGA_CHAR) = 'X';
        if (y > 1 & y < 39)
        {
            MMIO(VGA_CR_X) = 1;
            MMIO(VGA_CHAR) = 48 + (y % 10);
        }        
    }
}

void get_input(unsigned int* special_key, unsigned int* ascii_key)
{
    unsigned int state, data;

    //wait until any key is pressed
    do {state = MMIO(IO_KBD_STATE) & (KBD_NEW_SPECIAL | KBD_NEW_ASCII);} while (state == 0);

    //sort it out: standard ascii key or special key?
    data = MMIO(IO_KBD_DATA);
    *special_key = (state == KBD_NEW_SPECIAL) ? data & KBD_SPECIAL : 0;
    *ascii_key   = (state == KBD_NEW_ASCII)   ? data & KBD_ASCII   : 0;
}

int main()
{
    MMIO(VGA_STATE) &= ~VGA_EN_HW_CURSOR; //hide cursor

    draw_calibration_screen();
    draw_help();

    unsigned int special_key, ascii_key;
    get_input(&special_key, &ascii_key);

    MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR; //show cursor
    qmon_vga_cls();
    return 0;
}
