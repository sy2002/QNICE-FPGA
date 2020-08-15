/*
** Timer unit.
**
** B. Ulmann fecit  26-JUL-2020, 27-JUL-2020
**
**  Basically, the hardware timer module works as follows:
**
**  - The 100 kHz timer clock is divided by a pre-scaler which is configured by writing into the TIMER_x_PRE register.
**  - The subdivided clock signal is then fed to a counter. When this counter reaches the value stored in the
**    register TIMER_x_CNT, an interrupt will be issued.
**  - The register TIMER_x_INT contains the address of the interrupt service routine to be called.
**
**  In order to activate one of the (currently) four timers all of its three registers must be different from zero!
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
    *interrupt_request,                                         // This is mapped to the interrupt_request flag in qnice.c
    *interrupt_address,                                         // This is mapped to the interrupt_address in the emulator
    id[NUMBER_OF_TIMERS];                                       // Timer id for each thread

struct timespec requested[NUMBER_OF_TIMERS], remaining[NUMBER_OF_TIMERS];

pthread_t thread_list[NUMBER_OF_TIMERS];

void initializeTimerModule(unsigned int *request, unsigned int *address) {
    interrupt_request = request;
    interrupt_address = address;

    for (unsigned int i = 0; i < NUMBER_OF_TIMERS * 3; timer_registers[i++] = 0);

    for (unsigned int i = 0; i < NUMBER_OF_TIMERS; i++) {
        thread_list[i] = (pthread_t) 0;
        id[i] = i;
    }
}

unsigned int readTimerDeviceRegister(unsigned int address) {
    return timer_registers[address];
}

void writeTimerDeviceRegister(unsigned int address, unsigned int value) {
    int i;

    unsigned long long duration;
#ifdef DEBUG
    printf("timer: write access at address %04X.\n", address);
#endif

    timer_registers[address] = value;

    i = (int) (address / REG_PER_TIMER);    // Which timer was accessed?

    if (timer_registers[i * REG_PER_TIMER + REG_PRE] && 
        timer_registers[i * REG_PER_TIMER + REG_CNT] && 
        timer_registers[i * REG_PER_TIMER + REG_INT]) {
        if (thread_list[i]) {   // If the timer is being reconfigured, cancel and recreate it
            if (pthread_cancel(thread_list[i])) {
              perror("[0] timer could not be removed!");
              exit(-1);
            }

            if (pthread_join(thread_list[i], NULL)) {
                perror("[1] timer could not be removed!");
                exit(-1);
            }
        }

        duration = timer_registers[i * REG_PER_TIMER + REG_CNT] * timer_registers[i * REG_PER_TIMER + REG_PRE] * 10000; // In ns
        requested[i].tv_nsec = duration - ((int) (duration / 1e9) * 1e9);
        requested[i].tv_sec  = (int) (duration / 1e9);
#ifdef DEBUG
        printf("\t%d : %d\n", timer_registers[i * REG_PER_TIMER + REG_CNT], timer_registers[i * REG_PER_TIMER + REG_PRE]);
        printf("\tTimer %d was off, will now be activated for %ld s, %ld ns.\n", i, requested[i].tv_sec, requested[i].tv_nsec);
#endif
        pthread_create(thread_list + i, NULL, (void *) timer, (void *) (id + i));
    } else {
        if (thread_list[i]) {
#ifdef DEBUG
            printf("\tTimer %d was on, will now be deactivated.\n", i);
#endif
            if (pthread_cancel(thread_list[i])) {
              perror("[0] timer could not be removed");
              exit(-1);
            }

            if (pthread_join(thread_list[i], NULL)) {
                perror("[1] timer could not be removed");
                exit(-1);
            }
        }
    }
}

void timer(unsigned int *id) {  // This implements one of n timers.
    for (;;) {
#ifdef DEBUG
        printf("\t\tTimer %d instantiated. Interval = %ld s, %ld ns\n", *id, requested[*id].tv_sec, requested[*id].tv_nsec);
#endif
        nanosleep(&requested[*id], &remaining[*id]);
#ifdef DEBUG
        printf("\t\tTimer %d triggered: INT = %04X.\n", *id, timer_registers[*id * REG_PER_TIMER + REG_INT]);;
#endif

        *interrupt_address = timer_registers[*id * REG_PER_TIMER + REG_INT];
        *interrupt_request = TRUE;
    }
}
