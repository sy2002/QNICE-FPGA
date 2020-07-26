/*
** Header file for the interrupt timers.
**
** 26-JUL-2020, B. Ulmann fecit
*/

#include <pthread.h>

#define TIMER_BASE_ADDRESS  0xFF30

unsigned int readTimerDeviceRegister(unsigned int);
