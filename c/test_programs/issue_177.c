// This is a small test program to test Issue #177.
// When compiled without optimization, it generates incorrect assembly.
// When compiled with optimization, it generates correct assembly.
//
// Details:
// https://github.com/sy2002/QNICE-FPGA/issues/177

#include <sysdef.h>

long a = 0;
long b = 0;

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

static __interrupt void isr(void)
{
   if (!a)
      return;
   b += 1;
}

int main()
{
   // Enable timer interrupt @ 10000 Hz
   MMIO(IO_TIMER_0_INT) = (unsigned int) isr;

   return 0;
}

