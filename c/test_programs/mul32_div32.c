/*
    Development testbed for switching the 32bit integer math from
    VBCC's built in routines to hardware accelerated EAE.

    IMPORTANT: Do not build with optmiziations on, otherwise the
    compiler will take care, that there is no multiplication at runtime
    at all!

    done by sy2002 in November 2016

    Performance built-in routines: 2.510 CPU cycles
    Performance EAE:                  XX CPU cycles 
*/

#if __STDC_VERSION__ != 199901L
#error This program needs C99 to compile. Use the -c99 VBCC switch.
#endif

#include <stdio.h>

int main()
{
    long a = 239197600;
    long b = 23;

#ifdef __QNICE__
    *((unsigned int*) 0xFF1A) |= 1; /* reset cycle counter */ 
#endif

    long res_div = a / b;
    long res_mod = a % b;

#ifdef __QNICE__
    unsigned long cycles = *((unsigned long*) 0xFF17); /* read the lower 32 bit of the cycle counter */
    printf("Calculation duration: %lu CPU cycles\r\n", cycles);
#endif    

    printf("%ld / %ld = %ld\r\n%ld %% %ld = %ld\r\n", a, b, res_div, a, b, res_mod);
}