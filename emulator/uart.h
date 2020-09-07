/*
**  This is the header file for the generic UART-emulation for the QNICE-emulator.
**
** 02-JUN-2008, B. Ulmann fecit
** 28-DEC-2016, B. Ulmann Cleanup...
** FEB-2020, sy2002 added non-blocking multithreaded version for the VGA emulator
*/

#include <stdbool.h>

//QNICE-FPGA is currently only emulating registers 1, 2 and 3
#define UART_NUMBER_OF_REGISTERS    4

/* This structure contains all register data of the emulated UART */
typedef struct uart
{
  unsigned int mr1a, sra, brg_test, rhra, ipcr, isr, ctu, ctl, mr1b, srb,
    x_x_test, rhrb, input_ports, start_counter, stop_counter,
    csra, cra, thra, acr, imr, crur, ctlr, csrb, crb, thrb, opcr, 
    set_output_port, reset_output_port;
} uart;

/* The following registers can be read from and partially written to the UART */
#define MR1A          0 /* Read/write */
#define MR2A          0 /* Read/write */
#define SRA           1
#define RHRA          2
#define BRG_TEST      3
#define IPCR          4
#define ISR           5
#define CTU           6
#define CTL           7
#define MR1B          8 /* Read/write */
#define MR2B          8 /* Read/write */
#define SRB           9
#define X_X_TEST      10
#define RHRB          11
#define INPUT_PORTS   13
#define START_COUNTER 14
#define STOP_COUNTER  15

/* The following registers can be written to */
#define CSRA              1
#define CRA               2
#define THRA              3
#define ACR               4
#define IMR               5
#define CRUR              6
#define CTLR              7
#define CSRB              9
#define CRB               10
#define THRB              11
#define OPCR              13
#define SET_OUTPUT_PORT   14
#define RESET_OUTPUT_PORT 15

//flag to ensure restoring a working terminal when closing the emulator by closing the SDL window
enum uart_status_t {uart_undef, uart_init, uart_rundown} uart_status;

unsigned int uart_read_register(uart *, unsigned int);
void uart_write_register(uart *, unsigned int, unsigned int);
void uart_hardware_initialization(uart *);
void uart_run_down();

#ifdef USE_VGA
int  uart_getchar_thread(void* param);
bool uart_getchar_thread_running;
void uart_fifo_init();
void uart_fifo_free();
#endif
