/*  HDMI Data Enable Tester

    Board revision R2 of the MEGA65 uses an ADV7511 chip to convert the
    natively generated VGA signal into an HDMI signal. The ADV7511 needs a
    "data enable" signal that is high, when valid pixels are delivered.

    This program can be used to find out default values that are better or
    more convenient on your HDMI screen than the ones that are hardcoded in
    the VHDL code in process "write_vga_registers" in "vga_textmode.vhd".

    The signal is being changed in realtime, so watch your HDMI monitor while
    playing with the register values.

    done by sy2002 in June 2020   
*/

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

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
    set_cur(5, 4);  printf("QNICE @ MEGA65 HDMI Data Enable Tester - done by sy2002 in June 2020\n");
    set_cur(5, 6);  printf("Use the function keys to modify the DE registers.\n");
    set_cur(5, 7);  printf("Caution: Your monitor might react weird!\n");

    set_cur(40, 13); printf("F1- F3+\n");
    set_cur(40, 14); printf("F5- F7+\n");
    set_cur(40, 15); printf("F9- F11+\n");
    set_cur(40, 16); printf("F12: Return to defaults\n");
    set_cur(40, 17); printf("ESC: Quit\n");
}

/* Draw a frame of "X" as it is the largest letter, so that we can see
   the effects of our register fiddling on a per pixel granularity. Add
   some x and y position numbers. */
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

//change register and avoid underflow
void change_hdmi_reg(unsigned int reg, int delta)
{
    int tmp = MMIO(reg);
    tmp += delta;
    if (tmp < 0)
        tmp = 0;
    MMIO(reg) = tmp;
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

    do
    {
        set_cur(10, 13); printf("Minimum Valid Column: %u  \n", MMIO(VGA_HDMI_H_MIN));
        set_cur(10, 14); printf("Maximum Valid Column: %u  \n", MMIO(VGA_HDMI_H_MAX));
        set_cur(10, 15); printf("Maximum Valid Row:    %u  \n", MMIO(VGA_HDMI_V_MAX));

        get_input(&special_key, &ascii_key);

        switch (special_key)
        {
            case KBD_F1:  change_hdmi_reg(VGA_HDMI_H_MIN, -1); break;
            case KBD_F3:  change_hdmi_reg(VGA_HDMI_H_MIN, +1); break;            
            case KBD_F5:  change_hdmi_reg(VGA_HDMI_H_MAX, -1); break;
            case KBD_F7:  change_hdmi_reg(VGA_HDMI_H_MAX, +1); break;                        
            case KBD_F9:  change_hdmi_reg(VGA_HDMI_V_MAX, -1); break;
            case KBD_F11: change_hdmi_reg(VGA_HDMI_V_MAX, +1); break;

            case KBD_F12:
                MMIO(VGA_HDMI_H_MIN) = 9;
                MMIO(VGA_HDMI_H_MAX) = 650;
                MMIO(VGA_HDMI_V_MAX) = 480;
                break;
        }
    } while (ascii_key != KBD_ESC);

    MMIO(VGA_STATE) |= VGA_EN_HW_CURSOR; //show cursor
    qmon_vga_cls();
    return 0;
}
