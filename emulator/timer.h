/*
** Header file for the interrupt timers.
**
** 26-JUL-2020, B. Ulmann fecit
*/

#include <pthread.h>

#define TIMER_BASE_ADDRESS  0xFF30
#define TIMER_NUMBER_OF     4

#define TIMER_0_PRE         0
#define TIMER_0_CNT         1
#define TIMER_0_INT         2
#define TIMER_1_PRE         3
#define TIMER_1_CNT         4
#define TIMER_1_INT         5
#define TIMER_2_PRE         6
#define TIMER_2_CNT         7
#define TIMER_2_INT         8
#define TIMER_3_PRE         9
#define TIMER_3_CNT         10
#define TIMER_3_INT         11

unsigned int readTimerDeviceRegister(unsigned int);
void writeTimerDeviceRegister(unsigned int, unsigned int);
void attach_control_lines(unsigned int *, unsigned int *);
