#include <stdio.h>
#include <sysdef.h>

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static unsigned int counter;

static __interrupt __norbank void isr(void)
{
   counter++;
}

int main()
{
   // Configure a one-second timer interrupt
   MMIO(IO_TIMER_0_INT) = (unsigned int) isr;
   MMIO(IO_TIMER_0_PRE) = 100;
   MMIO(IO_TIMER_0_CNT) = 1000;

   while (1)
   {
      printf("%u\n", counter);

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

   return 0;
}

