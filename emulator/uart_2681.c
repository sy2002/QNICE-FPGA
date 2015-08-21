/*
**  This module implements the emulation of a 2681 UART which will be eventually used in the actual hardware implementation
** of QNICE.
**
** 02-JUN-2008, B. Ulmann fecit.
** 03-AUG-2015, B. Ulmann Changed from curses to select-calls.
*/

#undef TEST /* Define to perform stand alone test */
#define VERBOSE
#define DEBUG

#include "uart_2681.h"
#include <stdio.h>

#include <unistd.h>
#include <stdlib.h>
#include <termios.h>

/* Ugly global variable to hold the original tty state in order to restore it during rundown */
struct termios tty_state_old, tty_state;

unsigned int uart_read_register(uart_2681 *state, unsigned int address)
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
      /* Check if there is a character in the input buffer */
      if ((ret_val = select(1, &fd, NULL, NULL, &tv)) == -1)
      {
        /* Don't stop here as it might be caused by a catched CTRL-C signal! */
      }
      else if (!ret_val) /* No data available */
        state->sra &= 0xfe;
      else /* Data available */
        state->sra |= 1;

      value = state->sra;
      break;
    case BRG_TEST:
      value = state->brg_test;
      break;
    case RHRA:
      if ((ret_val = select(1, &fd, NULL, NULL, &tv)) == -1)
      {
        /* Don't stop here as it might be caused by a catched CTRL-C signal! */
      }
      else if (!ret_val) /* No data available */
        state->rhra = 0;
      else /* Data available */
        state->rhra = getchar() & 0xff;

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

void uart_write_register(uart_2681 *state, unsigned int address, unsigned int value)
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

void uart_hardware_initialization(uart_2681 *state)
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

  state->sra = state->srb = state->brg_test = state->rhra = state->ipcr = state->isr = state->ctu = state->ctl = 
  state->x_x_test = state->rhrb = state->input_ports = state->start_counter = state->stop_counter =
  state->csra = state->cra = state->thra = state->acr = state->imr = state->crur = state->ctlr = state->csrb = state->crb =
  state->thrb = state->opcr = state->set_output_port = state->reset_output_port = (unsigned int) 0;
}

void uart_run_down()
{
  /* Reset the terminal to its original settings */
  tcsetattr(STDIN_FILENO, TCSANOW, &tty_state_old);
}

/*
** The main function serves test purposes only and will be invisible under normal circumstances.
*/

#ifdef TEST
int main()
{
  uart_2681 my_uart;
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
