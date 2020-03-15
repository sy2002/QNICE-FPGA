/*
** This module implements the emulation of a generic UART which will be eventually used
** in the actual hardware implementation of QNICE.
**
** 02-JUN-2008, B. Ulmann fecit.
** 03-AUG-2015, B. Ulmann Changed from curses to select-calls.
** 28-DEC-2015, B. Ulmann Adapted to the current FPGA-implementation.
** FEB-2020, sy2002 added non-blocking multithreaded version for the VGA emulator
*/

#undef TEST /* Define to perform stand alone test */
#define VERBOSE

#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>

#include "uart.h"

#ifdef USE_VGA
# include <poll.h>
# include "fifo.h"
fifo_t*             uart_fifo; 
bool                uart_getchar_thread_running;  //flag to safely free the FIFO's memory
extern bool         gbl$cpu_running;              //the getchar thread stops when the CPU stops

/* Needs to be as large as the maximum amount of words that can be pasted while doing
   copy/paste in the M/L mode. Reason: The uart thread might pick up the data slower,
   than the operating systemm is pasting the data into the window. For being on the
   safe side, we chose double the size of the current size of 32k words */
const unsigned int  uart_fifo_size = 2*32*1024;
#endif

/* Ugly global variable to hold the original tty state in order to restore it during rundown */
struct termios tty_state_old, tty_state;
enum uart_status_t uart_status = uart_undef;

unsigned int uart_read_register(uart *state, unsigned int address)
{
  unsigned int value;
  char last_character;
  fd_set fd;
  struct timeval tv;
  int ret_val;

  /* Initialize data structures for following select calls */
  FD_ZERO(&fd);
  FD_SET(STDIN_FILENO, &fd);
  tv.tv_sec = 0;
  tv.tv_usec = 1000; /* Wait 1 ms */

  switch (address)
  {
    case MR1A:
    /* case MR2A: */
      value = state->mr1a;
      break;
    case SRA:
#ifndef USE_VGA
      /* Check if there is a character in the input buffer */
      if ((ret_val = select(1, &fd, NULL, NULL, &tv)) == -1)
      {
        /* Don't stop here as it might be caused by a catched CTRL-C signal! */
      }
      else if (!ret_val) /* No data available */
        state->sra &= 0xfe; /* Do not touch the transmit-ready bit! */
      else /* Data available */
        state->sra |= 1;
#else
      if (uart_fifo->count)
        state->sra |= 1;
      else
        state->sra &= 0xfe;
#endif
      value = state->sra;
      break;
    case BRG_TEST:
      value = state->brg_test;
      break;
    case RHRA:
#ifndef USE_VGA
      if ((ret_val = select(1, &fd, NULL, NULL, &tv)) == -1)
      {
        /* Don't stop here as it might be caused by a catched CTRL-C signal! */
      }
      else if (!ret_val) /* No data available */
        state->rhra = 0;
      else /* Data available */
        state->rhra = getchar() & 0xff;
#else
      if (uart_fifo->count)
        state->rhra = fifo_pull(uart_fifo);
      else
        state->rhra = 0;
#endif
      value = state->rhra;
      break;
    case IPCR:
      value = state->ipcr;
      break;
    case ISR:
      value = state->isr;
      break;
    case CTU:
      value = state->ctu;
      break;
    case CTL:
      value = state->ctl;
      break;
    case MR1B:
    /* case MR2B: */
      value = state->mr1b;
      break;
    case SRB:
      value = state->srb;
      break;
    case X_X_TEST:
      value = state->x_x_test;
      break;
    case RHRB:
      value = state->rhrb;
      break;
    case INPUT_PORTS:
      value = state->input_ports;
      break;
    case START_COUNTER:
      value = state->start_counter;
      break;
    case STOP_COUNTER:
      value = state->stop_counter;
      break;
    default:
#ifdef VERBOSE
      printf("uart_read_register: attempt to read illegal register %d!\n", address);
#endif
      value = 0xff;
  }

  return value & 0xff;
}

void uart_write_register(uart *state, unsigned int address, unsigned int value)
{
  value &= 0xff;
  switch (address)
  {
    case MR1A:
    /* case MR1B: */
      state->mr1a = value;
      break;
    case CSRA:
      state->csra = value;
      break;
    case CRA:
      state->cra = value;
      break;
    case THRA:
      state->thra = value;
      putchar((int) value);
      fflush(stdout);
      break;
    case ACR:
      state->acr = value;
      break;
    case IMR:
      state->imr = value;
      break;
    case CRUR:
      state->crur = value;
      break;
    case CTLR:
      state->ctlr = value;
      break;
    case CSRB:
      state->csrb = value;
      break;
    case CRB:
      state->crb = value;
      break;
    case THRB:
      state->thrb = value;
      break;
    case OPCR:
      state->opcr = value;
      break;
    case SET_OUTPUT_PORT:
      state->set_output_port = value;
      break;
    case RESET_OUTPUT_PORT:
      state->reset_output_port = value;
      break;
    default:
#ifdef VERBOSE
      printf("uart_write_register: attempt to write into illegal register %d!", address);
#endif
  }
}

#ifdef USE_VGA
void uart_fifo_init()
{
  uart_fifo = fifo_init(uart_fifo_size);
}

void uart_fifo_free()
{
  fifo_free(uart_fifo);
}

int uart_getchar_thread(void* param)
{
  //wait unti CPU is running (it is started in main thread after uart_getchar_thread_running = true)
  while (!gbl$cpu_running)
    usleep(10000);

  struct pollfd fds = {.fd = 0, .events = POLLIN}; // 0 means STDIN
  int ret_val;

  uart_getchar_thread_running = true;
  while (gbl$cpu_running)
  {
      ret_val = poll(&fds, 1, 5); //timeout = 5ms
      if (ret_val)
        fifo_push(uart_fifo, getchar() & 0xff);
  }
  uart_getchar_thread_running = false;
  return 1;
}
#endif

void uart_hardware_initialization(uart *state)
{
  /* Turn off buffering on STDIN and save original state for later */
  tcgetattr(STDIN_FILENO, &tty_state_old);
  tty_state = tty_state_old;
  tty_state.c_lflag &= ~ICANON;
  tty_state.c_lflag &= ~ECHO;
  tcsetattr(STDIN_FILENO, TCSANOW, &tty_state);

  /*
  ** bit 1, 0: 11 -> 8 bits/character
  ** bit 2   : 0  -> even parity
  ** bit 4, 3: 10 -> no parity
  ** bit 5   : 0  -> error mode char
  ** bit 6   : 0  -> RxRDY
  ** bit 7   : 0  -> no RxRTS control
  */
  state->mr1a = state->mr1b = 0x13;

  state->sra = 0x0002; /* Transmit ready - since this is a simulation, this is always true. */

  state->srb = state->brg_test = state->rhra = state->ipcr = state->isr = state->ctu = state->ctl = 
  state->x_x_test = state->rhrb = state->input_ports = state->start_counter = state->stop_counter =
  state->csra = state->cra = state->thra = state->acr = state->imr = state->crur = state->ctlr = state->csrb = state->crb =
  state->thrb = state->opcr = state->set_output_port = state->reset_output_port = (unsigned int) 0;

  uart_status = uart_init;
}

void uart_run_down()
{
  /* Reset the terminal to its original settings */
  tcsetattr(STDIN_FILENO, TCSANOW, &tty_state_old);
  uart_status = uart_rundown;
}

/*
** The main function serves test purposes only and will be invisible under normal circumstances.
*/

#ifdef TEST
int main()
{
  uart my_uart;
  unsigned int sra, rhra = 0, i;

  /* Initialize UART (hardware reset) */
  uart_hardware_initialization(&my_uart);

  /* First simple test: Write the characters A to Z followed by CR/LF/LF to the first emulated serial line */
  for (i = 'A'; i <= 'Z'; i++)
    uart_write_register(&my_uart, THRA, i);
  uart_write_register(&my_uart, THRA, 10);
  uart_write_register(&my_uart, THRA, 13);

  /* Second simple test: Read characters from the first simulated serial line and echo them, 'q' will quit */
  for (; rhra != 'q';)
  {
    do
    {
      sra = uart_read_register(&my_uart, SRA);
    } while (!(sra & 1));
    rhra = uart_read_register(&my_uart, RHRA);
    uart_write_register(&my_uart, THRA, rhra);
  }

  uart_run_down();
  return 0;
}
#endif
