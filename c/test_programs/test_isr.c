// This program is a test for writing ISR's in pure C.
//
// Compile with the command "qvc test_isr.c"
//
// The program runs for a few seconds, and should then print the result
// count=30000
// sum=50744
//
// While running, the program displays a pattern of alternating lines on the
// VGA screen. There should be no flickering in this pattern.


#include <stdio.h>
#include <sysdef.h>
#include "qmon.h"    // Random generator

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

unsigned int count = 0;
unsigned int sum = 0;

static __interrupt void isr(void)
{
   // Do some calculations that use the EAE.
   sum += qmon_rand();
   count += 1;
} // isr

int main()
{
   // Enable timer interrupt @ 10000 Hz
   MMIO(IO_TIMER_0_INT) = (unsigned int) isr;
   MMIO(IO_TIMER_0_PRE) = 10;
   MMIO(IO_TIMER_0_CNT) = 1;

   // Initialize random number
   qmon_srand(1);

   // Enable user palette
   MMIO(VGA_PALETTE_OFFS) = VGA_PALETTE_OFFS_USER;
   MMIO(VGA_PALETTE_ADDR) = VGA_PALETTE_OFFS_USER+16;

   while (1)
   {
      if (count >= 30000)
         break;

      // Set background colour using the EAE
      MMIO(IC_CSR) |= IC_BLOCK_INTERRUPTS;
      MMIO(VGA_PALETTE_DATA) = MMIO(VGA_SCAN_LINE)*65;
      MMIO(IC_CSR) &= IC_BLOCK_INTERRUPTS_INVERT;

      if (MMIO(IO_UART_SRA) & 1)
      {
         unsigned int tmp = MMIO(IO_UART_RHRA);
         break;
      }
      if (MMIO(IO_KBD_STATE) & KBD_NEW_ANY)
      {
         unsigned int tmp = MMIO(IO_KBD_DATA);
         break;
      }
   }

   // Disable timer interrupt
   MMIO(IO_TIMER_0_PRE) = 0;
   MMIO(IO_TIMER_0_CNT) = 0;

   printf("count=%u\n", count);
   printf("sum=%u\n", sum);

   return 0;
}

