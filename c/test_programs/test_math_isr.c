// This is a test program to verify that math operations are interrupt safe.
//
// The program runs for approximately 10 seconds and can be interrupted by
// pressing any key.
//
// The expected output (when running on the hardware) is:
//   Finished!
//   cycles       = 7665 (ca.)
//   loop_count   = 712451 (ca.)
//   isr_count    = 500000
//   error_count1 = 0
//   error_count2 = 0
//   isr_results  = 68041169, 135708334, 203148773, 269872203, 336269884, 404026614, 470963936,
//
// The idea in the program is to generate random numbers (which use the EAE) in the ISR,
// and to sum the results of these together, so the calculation can be verified.
// In the main loop various math operations are performed in such a way so that the
// results can be verified.

#include <stdio.h>
#include <qmon.h>

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

volatile unsigned long isr_sum = 0;
volatile unsigned long isr_count = 0;

#define NUM_RESULTS 7
volatile unsigned long isr_results[NUM_RESULTS];
volatile unsigned int  isr_enabled = 0;

static __interrupt void isr(void)
{
   if (isr_enabled)
   {
      isr_count += 1;

      // Do some calculations that use the EAE.
      isr_sum += qmon_rand();

      if ((isr_count & 0xFFF) == 0xFFF)
      {
         int index = isr_count >> 12;
         if (index < NUM_RESULTS)
         {
            isr_results[index] = isr_sum;
         }
      }
   }
} // isr

int main()
{
   // Enable timer interrupt @ 50000 Hz
   MMIO(IO_TIMER_0_INT) = (unsigned int) isr;
   MMIO(IO_TIMER_0_PRE) = 1;
   MMIO(IO_TIMER_0_CNT) = 1;

   // Initialize random number
   qmon_srand(1);

   unsigned long loop_count = 0;

   unsigned int cycles = MMIO(IO_CYC_MID);

   isr_enabled = 1;

   unsigned int error_count1 = 0;
   unsigned int error_count2 = 0;

   while (isr_count < 500000)
   {
      ++loop_count;

      // Generate two different numbers
      unsigned int o11 = loop_count + 1;
      unsigned int o21 = loop_count + 2;

      // Calculate the product using two different methods
      unsigned long r1 = qmon_mulu(o11, o21);
      unsigned long e1 = ((unsigned long) o11) * ((unsigned long) o21); // Calls ___mulint32

      // Compare the result
      if (r1 != e1)
      {
         ++error_count1;
      }

      unsigned int o12 = loop_count & 0xFF;
      unsigned int o22 = (loop_count+1) & 0xFF;

      if (o22)
      {
         unsigned int r2 = (o12*o22) / o22;  // Two inline assembly operations using EAE
         unsigned int e2 = o12;

         if (r2 != e2)
         {
            ++error_count2;
         }
      }

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

   isr_enabled = 0;

   cycles = MMIO(IO_CYC_MID) - cycles;

   printf("Finished!\n");
   printf("cycles       = %u\n", cycles);
   printf("loop_count   = %lu\n",loop_count);
   printf("isr_count    = %lu\n",isr_count);
   printf("error_count1 = %u\n", error_count1);
   printf("error_count2 = %u\n", error_count2);
   printf("isr_results  = ");
   for (int i=0; i<NUM_RESULTS; ++i)
   {
      printf("%lu, ", isr_results[i]);
   }
   printf("\n");

   // Disable timer interrupt
   MMIO(IO_TIMER_0_PRE) = 0;
   MMIO(IO_TIMER_0_CNT) = 0;

   return 0;
}

