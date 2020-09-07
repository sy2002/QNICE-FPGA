/*
** Header file for the interrupt timers.
**
** 26-JUL-2020, B. Ulmann fecit
*/

#include <pthread.h>

#define NUMBER_OF_TIMERS    2
#define REG_PER_TIMER       3

#define REG_PRE             0
#define REG_CNT             1
#define REG_INT             2

#define TIMER_0_PRE         0
#define TIMER_0_CNT         1
#define TIMER_0_INT         2
#define TIMER_1_PRE         3
#define TIMER_1_CNT         4
#define TIMER_1_INT         5

unsigned int readTimerDeviceRegister(unsigned int);
void writeTimerDeviceRegister(unsigned int, unsigned int);
void initializeTimerModule(unsigned int *, unsigned int *);
void timer(unsigned int *);
