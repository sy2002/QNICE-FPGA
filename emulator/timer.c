/*
** Timer unit.
**
** 26-JUL-2020, B. Ulmann fecit
*/

#include "timer.h"

unsigned int timer_registers[TIMER_NUMBER_OF * 3];  // Global register variables
unsigned int *interrupt_request,                    // This is mapped to the interrupt_request flag in the emulator
             *interrupt_address;                    // This is mapped to the interrupt_address in the emulator

void attach_control_lines(unsigned int *request, unsigned int *address) {
    interrupt_request = request;
    interrupt_address = address;
}

unsigned int readTimerDeviceRegister(unsigned int address) {
    return 0; // Todo: Shut up and write some code! :-)
}

void writeTimerDeviceRegister(unsigned int address, unsigned int value) {
    // Todo: Write some more code... :-)
}
