/*
** Timer unit.
**
** B. Ulmann fecit  26-JUL-2020, 27-JUL-2020
**
**  Basically, the hardware timer module works as follows:
**
**  - The system clock (50 MHz) is divided by a pre-scaler which is configured by writing into the TIMER_x_PRE register.
**  - The subdivided clock signal is then fed to a counter. When this counter reaches the value stored in the
**    register TIMER_x_CNT, an interrupt will be issued.
**  - The register TIMER_x_INT contains the address of the interrupt service routine to be called.
**
**  In order to activate one of the (currently) four timers all of its three registers must be different from zero!
**
**  This timer module simulation ignores the pre-scaler and assumes a resolution of one millisecond, so only 
** the registers TIMER_x_CNT and TIMER_x_INT are actually taken into account although TIMER_x_PRE must be != 0 
** in order to activate the timer.
*/

#undef DEBUG

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include "timer.h"

#ifndef TRUE
# define TRUE 1
# define FALSE !TRUE
#endif

unsigned int timer_registers[NUMBER_OF_TIMERS * REG_PER_TIMER], // Global register variables
             *interrupt_request,                                // This is mapped to the interrupt_request flag in qnice.c
             *interrupt_address,                                // This is mapped to the interrupt_address in the emulator
             *id;                                               // Timer id for each thread

pthread_t *thread_list;

void initializeTimerModule(unsigned int *request, unsigned int *address) {
    interrupt_request = request;
    interrupt_address = address;

    for (unsigned int i = 0; i < NUMBER_OF_TIMERS * 3; timer_registers[i++] = 0);

    if (!(thread_list = malloc(sizeof(pthread_t) * NUMBER_OF_TIMERS))) {
        perror("timer: Out of memory creating the thread_list!");
        exit(-1);
    }

    if (!(id = malloc(sizeof(unsigned int) * NUMBER_OF_TIMERS))) {
        perror("timer: Out of memory creating the ids!");
        exit(-1);
    }

    for (unsigned int i = 0; i < NUMBER_OF_TIMERS; i++) {
        thread_list[i] = (pthread_t) 0;
        id[i] = i;
    }
#ifdef DEBUG
    printf("timer.c initialized.\n");
#endif
}

unsigned int readTimerDeviceRegister(unsigned int address) {
    return timer_registers[address];
}

void writeTimerDeviceRegister(unsigned int address, unsigned int value) {
    timer_registers[address] = value;
#ifdef DEBUG
    printf("timer: Written %04X to register %d\n", value, address);
#endif

    for (unsigned int i = 0; i < NUMBER_OF_TIMERS; i++) {
        if (timer_registers[i * REG_PER_TIMER + REG_PRE] && 
            timer_registers[i * REG_PER_TIMER + REG_CNT] && 
            timer_registers[i * REG_PER_TIMER + REG_INT]) {
            if (!thread_list[i]) {
#ifdef DEBUG
                printf("timer: Timer %d was off, will now be activated.\n", i);
#endif
                pthread_create(thread_list + i, NULL, (void *) timer, (void *) (id + i));
            }
        } else {
            if (thread_list[i]) {
#ifdef DEBUG
                printf("timer: Timer %d was on, will now be deactivated.\n", i);
#endif
                pthread_cancel(thread_list[i]);
                thread_list[i] = 0;
            }
        }
    }
}

void timer(unsigned int *id) {  // This implements one of n timers.
    for (;;) {
        usleep(timer_registers[*id + REG_CNT] * 1000);
#ifdef DEBUG
        printf("\tTimer %d triggered!\n", *id);
#endif

        *interrupt_address = timer_registers[*id + REG_INT];
        *interrupt_request = TRUE;
    }
}
