/*
 * A collection of routines to write to VGA screen,
 * Supports a very small subset on the old conio library.
 * done by MJoergen in August 2020
 */

#ifndef __QNICE__
#error This program only runs on QNICE.
#endif

#include "sysdef.h"
#include "qmon.h"          // qmon_vga_cls and qmon_getc

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

void gotoxy(int col, int row)
{
   MMIO(VGA_CR_X) = col;   // VGA cursor X position
   MMIO(VGA_CR_Y) = row;   // VGA cursor Y position
} // gotoxy

void cputcxy(int col, int row, int ch)
{
   gotoxy(col, row);
   MMIO(VGA_CHAR) = ch;    // VGA character to be displayed
} // cputcxy

void cputsxy(int col, int row, const char *str, int color)
{
   while (*str)
   {
      cputcxy(col++, row, (*str) + color);
      str++;
   }
} // cputsxy

void clrscr()
{
    qmon_vga_cls();
} // clrscr

char cgetc()
{
   return qmon_getc();
} // cgetc

long time()
{
   return MMIO(IO_CYC_LO);
} // time

