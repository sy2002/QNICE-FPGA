/* 
**  QNICE emulator -- this emulator was written as a proof of concept for the
** QNICE processor. In most cases Thomas' Perl based emulator will be used. :-)
**
** B. Ulmann, 16-AUG-2006...03-SEP-2006...04-NOV-2006...29-JUN-2007...
**            16-DEC-2007...03-JUN-2008...28-DEC-2014...
**            xx-AUG-2015...xx-MAY-2016...
**
*/

#define USE_UART

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include "ide_simulation.h"

#ifdef USE_UART
#include "uart.h"

unsigned int uart_read_register(uart *, int);
void uart_write_register(uart *, unsigned int, unsigned int);
void uart_hardware_initialization(uart *);
void uart_run_down();
#endif

/*
** Some preliminaries...
*/

#ifndef NULL
# define NULL 0
#endif

#ifndef TRUE
# define TRUE 1
# define FALSE !TRUE
#endif

#define STRING_LENGTH          132
#define MEMORY_SIZE            65536
#define REGMEM_SIZE            4096

/* The top most 245 words of memory are reserverd for memory mapped IO devices */
#define IO_AREA_START          0xff00
#define SWITCH_REG             0xff12
#define UART0_BASE_ADDRESS     0xff20
#define IDE_BASE_ADDRESS       0xffe0

#define CYC_LO                 0xff17 /* Cycle counter low, middle, high word and state register */
#define CYC_MID                0xff18
#define CYC_HI                 0xff19
#define CYC_STATE              0xff1a

#define EAE_OPERAND_0          0xff1b
#define EAE_OPERAND_1          0xff1c
#define EAE_RESULT_LO          0xff1d
#define EAE_RESULT_HI          0xff1e
#define EAE_CSR                0xff1f

#define NO_OF_INSTRUCTIONS     19
#define NO_OF_ADDRESSING_MODES 4
#define READ_MEMORY            0 /* This and the following constants are used to control the access_xxx functions */
#define WRITE_MEMORY           1

/* The following constants form a bit mask to allow the exclusion of several bits */
#define MODIFY_ALL             0x0
#define DO_NOT_MODIFY_CARRY    0x1
#define DO_NOT_MODIFY_X        0x2
#define DO_NOT_MODIFY_OVERFLOW 0x4

#define GENERIC_BRANCH_OPCODE  0xf /* All branches share this common opcode */

typedef struct statistic_data
{
  unsigned int instruction_frequency[NO_OF_INSTRUCTIONS], /* Count the number of executions per instruction */
    addressing_modes[2][NO_OF_ADDRESSING_MODES],          /* 0 -> read, 1 -> write */
    memory_accesses[2];                                   /* 0 -> read, 1 -> write */
} statistic_data;

int gbl$memory[MEMORY_SIZE], gbl$registers[REGMEM_SIZE], gbl$debug = FALSE, gbl$verbose = FALSE,
    gbl$normal_operands[] = {2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2}, gbl$gather_statistics = FALSE, 
    gbl$ctrl_c = FALSE, gbl$breakpoint = -1, gbl$cycle_counter_state = 0, gbl$eae_operand_0 = 0,
    gbl$eae_operand_1 = 0, gbl$eae_result_lo = 0, gbl$eae_result_hi = 0, gbl$eae_csr = 0;

unsigned long long gbl$cycle_counter = 0l; /* This cycle counter is effectively an instruction counter... */

char *gbl$normal_mnemonics[] = {"MOVE", "ADD", "ADDC", "SUB", "SUBC", "SHL", "SHR", "SWAP", 
                                "NOT", "AND", "OR", "XOR", "CMP", "rsrvd", "HALT"},
     *gbl$branch_mnemonics[] = {"ABRA", "ASUB", "RBRA", "RSUB"}, 
     *gbl$sr_bits = "1XCZNVIM",
     *gbl$addressing_mnemonics[] = {"rx", "@rx", "@rx++", "@--rx"};

statistic_data gbl$stat;

#ifdef USE_UART
uart gbl$first_uart;
#endif

/*
**
*/
static void signal_handler_ctrl_c(int signo)
{
  gbl$ctrl_c = TRUE;
}

/*
** upstr converts a string into upper case.
*/
void upstr(char *string)
{
  while (*string)
  {
    if (*string >= 'a' && *string <= 'z')
      *string += -'a' + 'A';
    string++;
  }
}

/*
** char_in returns TRUE if the character char is an element of string.
*/
int char_in(char c, char *string)
{
  int i;

  for (i = 0; i < strlen(string); i++)
    if (c == string[i])
      return TRUE;

  return FALSE;
}

/*
** Local variant of strtok, just better. :-) The first call expects the string to be tokenized as its first argument.
** All subsequent calls only require the second argument to be set. If there is nothing left to be tokenized, a zero pointer
** will be returned. In contrast to strtok this routine will not alter the string to be tokenized since it 
** operates on a local copy of this string.
*/
char *tokenize(char *string, char *delimiters)
{
  static char local_copy[STRING_LENGTH], *position;
  char *token;

  if (string) /* Initial call, create a copy of the string pointer */
  {
    strcpy(local_copy, string);
    position = local_copy;
  }
  else /* Subsequent call, scan local copy until a delimiter character will be found */
  {
    while (*position && char_in(*position, delimiters)) /* Skip delimiters if there are any at the beginning of the string */
      position++;

    token = position; /* Now we are at the beginning of a token (or the end of the string :-) ) */
    while (*position)
    {
      position++;
      if (!*position || char_in(*position, delimiters)) /* Delimiter found */
      {
        if (*position)
          *position++ = (char) 0; /* Split string copy */
        return token;
      }
    }
  }

  return NULL;
}

/*
** str2int converts a string in base 16 or base 10 notation to an unsigned integer value.
** Base 16 values require a prefix "0x" or "$" while base 10 value do not require any prefix.
*/
unsigned int str2int(char *string)
{
  int value;
  
  if (!string || !*string) /* An empty string is treated as a zero */
    return 0;

  if (!strncmp(string, "0X", 2) || !strncmp(string, "0x", 2))
    sscanf(string + 2, "%x", &value);
  else if (*string == '$')
    sscanf(string + 1, "%x", &value);
  else
    sscanf(string, "%d", &value);

  return value;
}

/*
** Does exactly what is expected. :-)
*/
void chomp(char *string)
{
  if (string[strlen(string) - 1] == '\n')
    string[strlen(string) - 1] = (char) 0;
}

/*
** Return the content of a register addressed by its 4 bit register address. The routine takes care of the
** necessary bank switching logic.
*/
unsigned int read_register(unsigned int address)
{
  address &= 0xf;
  if (address & 0x8) /* Upper half -> always bank 0 */
    return gbl$registers[address] | (address == 0xe ? 1 : 0); /* The LSB of SR is always 1! */

  return gbl$registers[address | ((read_register(14) >> 4) & 0xFF0)];
}

/*
** Change the contents of a register with provision for bank switching logic.
*/
void write_register(unsigned int address, unsigned int value)
{
  address &= 0xf;
  value   &= 0xffff;

  if ((gbl$debug))
    printf("\twrite_register: address = %04X, value = %02X\n\r", address, value);

  if (address & 0x8)
    gbl$registers[address] = value | (address == 14 ? 1 : 0); /* Ensure that LSB will always be set. */
  else /* Take bank switching into account! */
    gbl$registers[address | ((read_register(14) >> 4) & 0xFF0)] = value;
}

/*
**  The following function performs all memory access operations necessary for executing code in the 
** emulator. Support routines like dump, etc. may access memory directly, but in this case be aware
** of the fact that no IO device emulation will take place!
**
*/
unsigned int access_memory(unsigned int address, unsigned int operation, unsigned int value)
{
  int eae$temp;

  address &= 0xffff;
  value   &= 0xffff;

  if (gbl$gather_statistics)
    gbl$stat.memory_accesses[operation]++;

  if (operation == READ_MEMORY)
  {
    if (address < IO_AREA_START)
      value = gbl$memory[address];
    else /* IO area */
    {
      value = 0;
      if ((gbl$debug))
        printf("\tread_memory: IO-area access at 0x%04X: 0x%04X\n\r", address, value);

      if (address >= UART0_BASE_ADDRESS && address < UART0_BASE_ADDRESS + 8) /* Some UART0 operation */
        value = uart_read_register(&gbl$first_uart, address - UART0_BASE_ADDRESS);
      else if (address >= IDE_BASE_ADDRESS && address < IDE_BASE_ADDRESS + 16) /* Some IDE operation */
        value = readIDEDeviceRegister(address - IDE_BASE_ADDRESS);
      else if (address == SWITCH_REG) /* Read the switch register */
        value = gbl$memory[SWITCH_REG];
      else if (address == CYC_LO) /* Read low word of the cycle (instruction) counter. */
        value = gbl$cycle_counter;
      else if (address == CYC_MID)
        value = gbl$cycle_counter >> 16;
      else if (address == CYC_HI)
        value = gbl$cycle_counter >> 24;
      else if (address == CYC_STATE)
        value = gbl$cycle_counter_state & 0x0003;
      else if (address == EAE_OPERAND_0)
        value = gbl$eae_operand_0;
      else if (address == EAE_OPERAND_1)
        value = gbl$eae_operand_1;
      else if (address == EAE_RESULT_LO)
        value = gbl$eae_result_lo;
      else if (address == EAE_RESULT_HI)
        value = gbl$eae_result_hi;
      else if (address == EAE_CSR)
        value = gbl$eae_csr;
    }
  }
  else if (operation == WRITE_MEMORY)
  {
    if (address < IO_AREA_START)
      gbl$memory[address] = value;
    else /* IO area */
    {
      if ((gbl$debug))
        printf("\twrite_memory: IO-area access at 0x%04X: 0x%04X\n\r", address, value);

      if (address >= UART0_BASE_ADDRESS && address < UART0_BASE_ADDRESS + 8) /* Some UART0 operation */
      {
        if ((gbl$debug))
          printf("\twrite uart register: %04X, %02X\n\t", address, value & 0xff);
        uart_write_register(&gbl$first_uart, address - UART0_BASE_ADDRESS, value & 0xff);
      }
      else if (address >= IDE_BASE_ADDRESS && address < IDE_BASE_ADDRESS + 16) /* Some IDE operation */
        writeIDEDeviceRegister(address - IDE_BASE_ADDRESS, value);
      else if (address == SWITCH_REG) /* Read the switch register */
        gbl$memory[SWITCH_REG] = value;
      else if (address == CYC_STATE)
      {
        if (value & 0x0001) /* Reset and start counting. */
        {
          gbl$cycle_counter = 0l;
          gbl$cycle_counter_state = 0x0002;
        }
      }
      else if (address == EAE_OPERAND_0)
        gbl$eae_operand_0 = value;
      else if (address == EAE_OPERAND_1)
        gbl$eae_operand_1 = value;
      else if (address == EAE_CSR)
      {
        switch(gbl$eae_csr = value)
        {
          case 0: /* Unsigned multiplication */
            eae$temp = gbl$eae_operand_0 * gbl$eae_operand_1; /* Since both operands are 16 bit, it is naturally unsigned. */
            gbl$eae_result_lo = eae$temp & 0xffff;
            gbl$eae_result_hi = (eae$temp >> 16) & 0xffff;
            break;
          case 1: /* Signed multiplication */
            if (gbl$eae_operand_0 & 0x8000) gbl$eae_operand_0 |= 0xffffffffffff8000; /* Perform a sign extension */
            if (gbl$eae_operand_1 & 0x8000) gbl$eae_operand_1 |= 0xffffffffffff8000;
            eae$temp = gbl$eae_operand_0 * gbl$eae_operand_1; /* Now, it is a signed operation. */
            gbl$eae_result_lo = eae$temp & 0xffff;
            gbl$eae_result_hi = (eae$temp >> 16) & 0xffff;
            break;
          case 2: /* Unsigned division */
            gbl$eae_result_lo = gbl$eae_operand_0 / gbl$eae_operand_1;
            gbl$eae_result_hi = gbl$eae_operand_0 % gbl$eae_operand_1;
            break;
          case 3: /* Signed division */
            gbl$eae_result_hi = gbl$eae_operand_0 % gbl$eae_operand_1;
            if (gbl$eae_operand_0 & 0x8000) gbl$eae_operand_0 |= 0xffffffffffff8000; /* Perform a sign extension */
            if (gbl$eae_operand_1 & 0x8000) gbl$eae_operand_1 |= 0xffffffffffff8000;
            gbl$eae_result_lo = gbl$eae_operand_0 / gbl$eae_operand_1;
            break;
          default:
            printf("Illegal opcode for the EAE detected - continuing anyway...\n");
        }

        gbl$eae_csr &= 0x7fff; /* Clear the busy bit just in case... */
      }
    }
  }
  else
  {
    printf("Illegal operation code in access_memory!\n");
    exit(-1);
  }

  return value & 0xffff;
}

/*
** reset the processor state, registers, memory.
*/
void reset_machine()
{
  unsigned int i;

  /* Reset main memory and registers */
  for (i = 0; i < IO_AREA_START; access_memory(i++, WRITE_MEMORY, 0));
  for (i = 0; i < REGMEM_SIZE; gbl$registers[i++] = 0);

  /* Reset statistics counters */
  for (i = 0; i < NO_OF_INSTRUCTIONS; gbl$stat.instruction_frequency[i++] = 0);
  for (i = 0; i < NO_OF_ADDRESSING_MODES; i++)
    gbl$stat.addressing_modes[0][i] = gbl$stat.addressing_modes[1][i] = 0;
  gbl$stat.memory_accesses[0] = gbl$stat.memory_accesses[1] = 0;

  if (gbl$debug || gbl$verbose)
    printf("\treset_machine: done\n");
}

/*
** Decode an operand specified by a 6 bit mask. Returns TRUE if the next word will be a constant, so this can
** be skipped in the next disassemble step.
*/
int decode_operand(unsigned int operand, char *string)
{
  int mode, regaddr;

  mode = operand & 0x3;
  regaddr = (operand >> 2) & 0xf;
  *string = (char) 0;

  if (!mode)
  {
    sprintf(string, "R%02d", regaddr);
    return FALSE;
  }

  if (mode == 1) /* @Rxx */
    sprintf(string, "@R%02d", regaddr);
  else if (mode == 2)
  {
    sprintf(string, "@R%02d++", regaddr);
    if (regaddr == 0xf) /* PC relative addressing */
      return TRUE;
  }
  else /* mode == 3 */
    sprintf(string, "@--R%02d", regaddr);

  return FALSE;
}

/*
** Disassemble the contents of a memory region
*/
void disassemble(unsigned int start, unsigned int stop)
{
  unsigned int i, opcode, instruction, j;
  int skip_addresses;
  char scratch[STRING_LENGTH], operands[STRING_LENGTH], mnemonic[STRING_LENGTH];

  printf("Disassembled contents of memory locations %04x - %04x:\n", start, stop);
  for (i = start, skip_addresses = 0; i <= stop || skip_addresses; i++)
  {
    opcode = (instruction = access_memory(i, READ_MEMORY, 0) & 0xffff) >> 12;
    if (skip_addresses) /* Do not decode this machine word -- since it was used in @R15++! */
    {
      skip_addresses--;
      printf("%04X: %04X\n", i, instruction);
      continue;
    }

    *operands = (char) 0;
    if (opcode < GENERIC_BRANCH_OPCODE) /* Normal instruction */
    {
      if (opcode == 0xd) /* This one is reserved for future use! */
      {
        strcpy(mnemonic, "RSRVD");
        *operands = (char) 0;
      }
      else
      {
        strcpy(mnemonic, gbl$normal_mnemonics[opcode]);
        if (gbl$normal_operands[opcode]) /* At least one operand */
        {
          if ((skip_addresses = decode_operand((instruction >> 6) & 0x3f, scratch))) /* Constant used! */
            sprintf(scratch, "0x%04X", access_memory(i + 1, READ_MEMORY, 0));
          strcpy(operands, scratch);
        }
  
        if (gbl$normal_operands[opcode] == 2) /* Decode second operand */
        {
          if ((j = decode_operand(instruction & 0x3f, scratch)))
            sprintf(scratch, "0x%04X", access_memory(i + skip_addresses + j, READ_MEMORY, 0));
          skip_addresses += j;
          strcat(operands, ", ");
          strcat(operands, scratch);
        }
      }
    }
    else if (opcode == GENERIC_BRANCH_OPCODE) /* Branch or Subroutine call */
    {
      strcpy(mnemonic, gbl$branch_mnemonics[(instruction >> 4) & 0x3]);
      if ((skip_addresses  = decode_operand((instruction >> 6) & 0x3f, scratch)))
        sprintf(scratch, "0x%04X", access_memory(i + 1, READ_MEMORY, 0));
      sprintf(operands, "%s, %s%c", scratch, (instruction >> 3) & 1 ? "!" : "", gbl$sr_bits[instruction & 0x7]);
    }
    else
    {
      strcpy(mnemonic, "???");
      *operands = (char) 0;
    }

    printf("%04X: %04X %-6s\t%s\n", i, instruction, mnemonic, operands);
  }
}

/*
** Read a source operand specified by mode and regaddr. If suppress_increment is set (all instructions with only
** one argument should do this!), the autoincrement will not be executed since this will be the task of 
** the operand update step. If this is necessary, mode == 2 can be used as a condition for this.
** Predecrement will be executed always, postincrement only conditionally.
*/
unsigned int read_source_operand(unsigned int mode, unsigned int regaddr, int suppress_increment)
{
  unsigned int source;

  if (gbl$debug)
    printf("\tread_source_operand: mode=%01X, reg=%01X, skip_increment=%d\n\r", mode, regaddr, suppress_increment);

  switch (mode) /* Mode bits of source operand */
  {
    case 0: /* Rxx */
      source = read_register(regaddr);
      break;
    case 1: /* @Rxx */
      source = access_memory(read_register(regaddr), READ_MEMORY, 0);
      break;
    case 2: /* @Rxx++ */
      source = access_memory(read_register(regaddr), READ_MEMORY, 0);
      if (!suppress_increment)
        write_register(regaddr, read_register(regaddr) + 1);
      break;
    case 3: /* @--Rxx */
      write_register(regaddr, read_register(regaddr) - 1);
      source = access_memory(read_register(regaddr), READ_MEMORY, 0);
      break;
    default:
      printf("Internal error, fetch operand!\n");
      exit(-1);
  }

  if (gbl$gather_statistics)
    gbl$stat.addressing_modes[0][mode]++;

  if (gbl$debug)
    printf("\tread_source_operand: value=%04X, r15=%04X\n\r", source, read_register(15));
  return source & 0xffff;
}

/*
** This is the counterpart function to read_source_operand. The major difference (apart from writing instead of reading :-) )
** is that predecrements can be suppressed, autoincrements will be executed always.
*/
void write_destination(unsigned int mode, unsigned int regaddr, unsigned int value, int suppress_decrement)
{
  if (gbl$debug)
    printf("\twrite_operand: mode=%01X, reg=%01X, value=%04X, skip_increment=%d\n\r", mode, regaddr, value, suppress_decrement);

  value &= 0xffff;
  switch (mode)
  {
    case 0: /* rxx */
      write_register(regaddr, value);
      break;
    case 1: /* @Rxx */
      access_memory(read_register(regaddr), WRITE_MEMORY, value);
      break;
    case 2: /* @Rxx++ */
      access_memory(read_register(regaddr), WRITE_MEMORY, value);
      write_register(regaddr, read_register(regaddr) + 1);
      break;
    case 3: /* @--Rxx */
      if (!suppress_decrement)
        write_register(regaddr, read_register(regaddr) - 1);
      access_memory(read_register(regaddr), WRITE_MEMORY, value);
      break;
    default:
      printf("Internal error, write operand!\n");
      exit(-1);
  }

  if (gbl$gather_statistics)
    gbl$stat.addressing_modes[1][mode]++;

  if (gbl$debug)
    printf("\twrite_destination: r15=%04X\n\r", read_register(15));
}

/*
** The following function updates the lower six bits of the status register R14 according to 
** the result of some machine instruction. Please keep in mind that the destination (result)
** parameter may occupy 17 bits (including the carry)! Do not truncate this parameter prior
** to calling this routine!
*/
void update_status_bits(unsigned int destination, unsigned int source_0, unsigned int source_1, unsigned int control_bitmask)
{
  unsigned int sr_bits;

  sr_bits = 1; /* LSB is always set (for unconditional branches and subroutine calls) */
  if (((destination & 0xffff) == 0xffff) & !(control_bitmask & DO_NOT_MODIFY_X)) /* X */
    sr_bits |= 0x2;
  if ((destination & 0x10000) && !(control_bitmask & DO_NOT_MODIFY_CARRY)) /* C */
    sr_bits |= 0x4;
  if (!(destination & 0xffff)) /* Z */
    sr_bits |= 0x8;
  if (destination & 0x8000) /* N */
    sr_bits |= 0x10;
  if (((!(source_0 & 0x8000) && !(source_1 & 0x8000) && (destination & 0x8000)) ||
      ((source_0 & 0x8000) && (source_1 & 0x8000) && !(destination & 0x8000))) && !(control_bitmask & DO_NOT_MODIFY_OVERFLOW))
    sr_bits |= 0x20;

  write_register(14, (read_register(14) & 0xffc0) | (sr_bits & 0x3f));
}

/*
** The following function executes a single QNICE instruction. The return value will be TRUE if an illegal instruction is found.
*/
int execute()
{
  unsigned int instruction, address, opcode, source_mode, source_regaddr, destination_mode, destination_regaddr,
    source_0, source_1, destination, scratch, i, debug_address, temp_flag, sr_bits;

  int condition, cmp_0, cmp_1;

  if (gbl$cycle_counter_state & 0x0002)
    gbl$cycle_counter++; /* Increment cycle counter which is an instruction counter in the emulator as opposed to the hardware. */

  debug_address = address = read_register(15); /* Get current PC */
  opcode = ((instruction = access_memory(address++, READ_MEMORY, 0)) >> 12 & 0Xf);
  write_register(15, address); /* Update program counter */

  if (gbl$debug || gbl$verbose)
    printf("execute: %04X %04X %s\n\r", debug_address, instruction, 
           opcode == GENERIC_BRANCH_OPCODE ? gbl$branch_mnemonics[(instruction >> 4) & 0x3] 
                                           : gbl$normal_mnemonics[opcode]);

  source_mode = (instruction >> 6) & 0x3;
  source_regaddr = (instruction >> 8) & 0xf;

  destination_mode = instruction & 0x3;
  destination_regaddr = (instruction >> 2) & 0xf;

  /* Update the statistics counters */
  if (opcode < GENERIC_BRANCH_OPCODE && gbl$gather_statistics)
    gbl$stat.instruction_frequency[opcode]++;
  else if (opcode == GENERIC_BRANCH_OPCODE && gbl$gather_statistics)
    gbl$stat.instruction_frequency[opcode + ((instruction >> 4) & 0x3)]++;

  switch (opcode)
  {
    case 0: /* MOVE */
      destination = read_source_operand(source_mode, source_regaddr, FALSE);
      update_status_bits(destination, destination, destination, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, FALSE);
      break;
    case 1: /* ADD */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 + source_1;
      update_status_bits(destination, source_0, source_1, MODIFY_ALL); 
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 2: /* ADDC */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 + source_1 + ((read_register(14) >> 2) & 1); /* Take carry into account */
      update_status_bits(destination, source_0, source_1, MODIFY_ALL);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 3: /* SUB */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 - source_1;
      update_status_bits(destination, source_0, source_1, MODIFY_ALL);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 4: /* SUBC */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 - source_1 - ((read_register(14) >> 2) & 1); /* Take carry into account */
      update_status_bits(destination, source_0, source_1, MODIFY_ALL);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 5: /* SHL */
      source_0 = read_source_operand(source_mode, source_regaddr, FALSE);
      destination = read_source_operand(destination_mode, destination_regaddr, TRUE);
      for (i = 0; i < source_0; i++)
      {
        temp_flag = (destination & 0x8000) >> 13;
        destination = (destination << 1) | ((read_register(14) >> 1) & 1);          /* Fill with X bit */
      }
      write_register(14, (read_register(14) & 0xfffb) | temp_flag);                 /* Shift into C bit */
      write_destination(destination_mode, destination_regaddr, destination, FALSE);
      break;
    case 6: /* SHR */
      scratch = source_0 = read_source_operand(source_mode, source_regaddr, FALSE);
      destination = read_source_operand(destination_mode, destination_regaddr, TRUE);
      for (i = 0; i < source_0; i++)
      {
        temp_flag = (destination & 1) << 1;
        destination = ((destination >> 1) & 0xffff) | ((read_register(14) & 4) << 13);  /* Fill with C bit */
      }
      write_register(14, (read_register(14) & 0xfffd) | temp_flag);                     /* Shift into X bit */
      write_destination(destination_mode, destination_regaddr, destination, FALSE);
      break;
    case 7: /* SWAP */
      source_0 = read_source_operand(source_mode, source_regaddr, FALSE);
      destination = (source_0 >> 8) | ((source_0 << 8) & 0xff00);
      update_status_bits(destination, source_0, source_0, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, FALSE);
      break;
    case 8: /* NOT */
      source_0 = read_source_operand(source_mode, source_regaddr, FALSE);
      destination = ~source_0 & 0xffff;
      update_status_bits(destination, source_0, source_0, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, FALSE);
      break;
    case 9: /* AND */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 & source_1;
      update_status_bits(destination, source_0, source_1, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 10: /* OR */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 | source_1;
      update_status_bits(destination, source_0, source_1, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 11: /* XOR */
      source_1 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_0 = read_source_operand(destination_mode, destination_regaddr, TRUE);
      destination = source_0 ^ source_1;
      update_status_bits(destination, source_0, source_1, DO_NOT_MODIFY_CARRY | DO_NOT_MODIFY_OVERFLOW);
      write_destination(destination_mode, destination_regaddr, destination, TRUE);
      break;
    case 12: /* CMP */
      source_0 = read_source_operand(source_mode, source_regaddr, FALSE);
      source_1 = read_source_operand(destination_mode, destination_regaddr, FALSE);

      /* CMP does NOT use the standard logic for setting the SR bits - this is done explicitly in the following: */
      sr_bits = 1; /* Take care of the LSB of SR which must be 1. */

      if (source_0 == source_1) sr_bits |= 0x0008;
      if (source_0 > source_1) sr_bits |= 0x0010;

      /* Ugly but it works: Convert the unsigned int source_0/1 to signed ints with possible sign extension: */
      cmp_0 = source_0;
      cmp_1 = source_1;

      if (source_0 & 0x8000) cmp_0 |= 0xffff0000;
      if (source_1 & 0x8000) cmp_1 |= 0xffff0000;
      if (cmp_0 > cmp_1) sr_bits |= 0x0020;

      write_register(14, (read_register(14) & 0xffc0) | (sr_bits & 0x3f));
      break;
    case 13: /* Reserved */
      printf("Attempt to execute the reserved instruction...\n");
      return 1;
    case 14: /* HALT */
      printf("HALT instruction executed at address %04X.\n\n", debug_address);
      return TRUE;
    case 15: /* Branch or subroutine call */
      /* Determine destination address in case the branch/subroutine instruction will be performed */
      destination = read_source_operand(source_mode, source_regaddr, FALSE); /* Perform autoincrement since no write back occurs! */

      /* Determine which SR bit to use, etc. */
      condition = (read_register(14) >> (instruction & 0x7)) & 1;
      if (instruction & 0x0008) /* Invert bit to be checked? */
        condition = 1 - condition;

      /* Now it is time to determine which branch resp. subroutine call type to execute if the condition is satisfied */
      if (condition)
      {
        switch((instruction >> 4) & 0x3)
        {
          case 0: /* ABRA */
            write_register(15, destination);
            break;
          case 1: /* ASUB */
            write_register(13, read_register(13) - 1);
            access_memory(read_register(13), WRITE_MEMORY, read_register(15));
            write_register(15, destination);
            break;
          case 2: /* RBRA */
            write_register(15, (read_register(15) + destination) & 0xffff);
            break;
          case 3: /* RSUB */
            write_register(13, read_register(13) - 1);
            access_memory(read_register(13), WRITE_MEMORY, read_register(15));
            write_register(15, (read_register(15) + destination) & 0xffff);
            break;
        }
      }
      /* We must increment the PC in case of a constant destination address even if the branch is not taken! */
// NO, we must not since the PC has already been incremented during the fetch operation!
//      else if (source_mode == 0x2 && source_regaddr == 0xf) /* This is mode @R15++ */
//        write_register(15, read_register(15) + 1);

      break;
    default:
      printf("PANIK: Illegal instruction found: Opcode %0X at address %04X.\n", opcode, address);
      return TRUE;
  }

  if (read_register(15) == gbl$breakpoint)
  {
    printf("Breakpoint reached: %04X\n", address);
    return TRUE;
  }


/*  write_register(15, read_register(15) + 1); */ /* Update program counter */
  return FALSE; /* No HALT instruction executed */
}

void run()
{
  gbl$ctrl_c = FALSE;
  uart_hardware_initialization(&gbl$first_uart);
  gbl$gather_statistics = TRUE;
  while (!execute() && !gbl$ctrl_c);
  if (gbl$ctrl_c)
    printf("\n\tAborted by CTRL-C!\n");
  gbl$gather_statistics = FALSE;
  uart_run_down();
}

void print_statistics()
{
  unsigned int i, value;

  for (i = value = 0; i < NO_OF_INSTRUCTIONS; value += gbl$stat.instruction_frequency[i++]);
  if (!value)
    printf("No statistics have been gathered so far!\n");
  else
  {
    printf("\n%d memory reads, %d memory writes and\n%d instructions have been executed so far:\n\n\
INSTR ABSOLUTE RELATIVE INSTR ABSOLUTE RELATIVE\n\
-----------------------------------------------\n", 
           gbl$stat.memory_accesses[READ_MEMORY], gbl$stat.memory_accesses[WRITE_MEMORY], value);
    for (i = 0; i < NO_OF_INSTRUCTIONS; i++)
      printf("%s%-4s: %8d (%5.2f%%)\t",
             !(i & 1) && i ? "\n" : "", /* New line every second round */
             i < GENERIC_BRANCH_OPCODE ? gbl$normal_mnemonics[i]
                                       : gbl$branch_mnemonics[i - GENERIC_BRANCH_OPCODE],
             gbl$stat.instruction_frequency[i],
             (float) (100 * gbl$stat.instruction_frequency[i]) / (float) value);

    for (i = value = 0; i < NO_OF_ADDRESSING_MODES; i++)
      value += gbl$stat.addressing_modes[0][i] + gbl$stat.addressing_modes[1][i];
    if (!value)
      printf("\n\nThere have not been any memory references so far!\n");
    else
    {
      printf("\n\n     READ ACCESSES                   WRITE ACCESSES\n\
MODE   ABSOLUTE RELATIVE        MODE   ABSOLUTE RELATIVE\n\
-----------------------------------------------------------\n");
      for (i = 0; i < NO_OF_ADDRESSING_MODES; i++)
        printf("%-5s: %8d (%5.2f%%) \t%-5s: %8d (%5.2f%%)\n", 
               gbl$addressing_mnemonics[i], gbl$stat.addressing_modes[0][i],
                 (float) (100 * gbl$stat.addressing_modes[0][i]) / (float) value, 
               gbl$addressing_mnemonics[i], gbl$stat.addressing_modes[1][i],
                 (float) (100 * gbl$stat.addressing_modes[1][i]) / (float) value);
    }
    printf("\n");
  }
}

int load_binary_file(char *file_name)
{
  unsigned int address;
  char scratch[STRING_LENGTH], *token;
  FILE *handle;

  if (!(handle = fopen(file_name, "r")))
  {
    printf("Unable to open file >>%s<<\n", file_name);
    return -1;
  }
  else
  {
    fgets(scratch, STRING_LENGTH, handle);
    upstr(scratch);
    chomp(scratch);
    while(!feof(handle))
    {
      tokenize(scratch, NULL);
      if (!(token = tokenize(NULL, " ")))
        break;
      address = str2int(token);
      if (address >= MEMORY_SIZE)
      {
        printf("Address out of range in load file: >>%s<<\n", scratch);
        return -1;
      }

      if (!(token = tokenize(NULL, " ")))
      {
        printf("Illegal line in load file! Line: >>%s<<\n", scratch);
        return -1;
      }
      access_memory(address, WRITE_MEMORY, str2int(token));

      fgets(scratch, STRING_LENGTH, handle);
      upstr(scratch);
      chomp(scratch);
    }
    fclose(handle);
  }

  return 0;
}

void dump_registers()
{
  unsigned int i, value;

  printf("Register dump: BANK = %02x, SR = ", read_register(14) >> 8);
  for (i = 7, value = read_register(14); i + 1; i--)
    printf("%c", value & (1 << i) ? gbl$sr_bits[i] : '_');

  printf("\n");
  for (i = 0; i < 0x10; i++)
  {
    if (!(i % 4)) /* New row */
      printf("\n\tR%02d-R%02d: ", i, i + 3);

    printf("%04x ", read_register(i));
  }
  printf("\n\n");
}

int main(int argc, char **argv)
{
  char command[STRING_LENGTH], *token, *delimiters = " ,", scratch[STRING_LENGTH];
  unsigned int start, stop, i, address, value, last_command_was_step = 0;
  FILE *handle;

  signal(SIGINT, signal_handler_ctrl_c);
  reset_machine();
  initializeIDEDevice();

  if (argc > 1)
  {
    if (!strcmp(argv[1], "-h"))
      printf("\nUsage:\n\
	\"qnice\" without arguments will start an interactive session\n\
	\"qnice -h\" will print this help text\n\
	\"qnice <file.bin>\" will run in batch mode and print statistics\n\n");
    else /* Assume that the first argument is a file name */
    {
      if (load_binary_file(argv[1]))
        return -1;

      run();
      print_statistics();
    }

  }

  for (;;)
  {
    printf("Q> ");
    fgets(command, STRING_LENGTH, stdin);
    chomp(command);
    if (feof(stdin)) 
      return 0;

    if (last_command_was_step && !strlen(command)) /* If STEP was the last command and this is empty, perform the next step. */
      strcpy(command, "STEP");

//    upstr(command);

    last_command_was_step = 0;
    tokenize(command, NULL); /* Initialize tokenizing */
    if ((token = tokenize(NULL, delimiters)))
    {
      upstr(token);
      if (!strcmp(token, "QUIT") || !strcmp(token, "EXIT"))
        return 0;
      else if (!strcmp(token, "CB"))
        gbl$breakpoint = -1;
      else if (!strcmp(token, "SB"))
        printf("Breakpoint set to %04X\n", gbl$breakpoint = str2int(tokenize(NULL, delimiters)));
      else if (!strcmp(token, "DUMP"))
      {
        start = str2int(tokenize(NULL, delimiters));
        stop  = str2int(tokenize(NULL, delimiters));
        for (i = start; i <= stop; i++)
        {
          if (!((i - start) % 8)) /* New row */
            printf("\n%04x: ", i);

          printf("%04x ", access_memory(i, READ_MEMORY, 0));
        }
        printf("\n");
      }
      else if (!strcmp(token, "SAVE")) /* Create a loadable binary file with data from memory */
      {
        if (!(token = tokenize(NULL, delimiters)))
          printf("SAVE expects at least a filename as its 1st parameter!\n");
        else
        {
          if (!(handle = fopen(token, "w")))
            printf("Unable to create file >>%s<<\n", token);
          else
          {
            start = str2int(tokenize(NULL, delimiters));
            stop  = str2int(tokenize(NULL, delimiters));
            for (i = start; i <= stop; i++)
              fprintf(handle, "0x%04X 0x%04X\n", i, access_memory(i, READ_MEMORY, 0));

            fclose(handle);
          }
        }
      }
      else if (!strcmp(token, "LOAD")) /* Load expects a file with a row format like "<addr> <value>\n", etc. */
      {
        if (!(token = tokenize(NULL, delimiters)))
          printf("LOAD expects a filename as its 1st parameter!\n");
        else
          load_binary_file(token);
      }
      else if (!strcmp(token, "RDUMP"))
        dump_registers();
      else if (!strcmp(token, "SET"))
      {
        token = tokenize(NULL, delimiters);
        value = str2int(tokenize(NULL, delimiters));
        if (*token == 'R') /* Set a register */
          write_register(str2int(token + 1), value);
        else
          access_memory(str2int(token), WRITE_MEMORY, value & 0xffff);
      }
      else if (!strcmp(token, "RESET"))
        reset_machine();
      else if (!strcmp(token, "DEBUG"))
      {
        if ((gbl$debug = TRUE - gbl$debug))
          printf("New mode: verbose\n");
        else
          printf("New mode: quiet\n");
      }
      else if (!strcmp(token, "VERBOSE"))
      {
        if ((gbl$verbose = TRUE - gbl$verbose))
          printf("New mode: verbose\n");
      }
      else if (!strcmp(token, "DIS"))
      {
        start = str2int(tokenize(NULL, delimiters));
        disassemble(start, str2int(tokenize(NULL, delimiters)));
      }
      else if (!strcmp(token, "STAT"))
        print_statistics();
      else if (!strcmp(token, "STEP"))
      {
        last_command_was_step = 1;
        if ((token = tokenize(NULL, delimiters)))
          write_register(15, str2int(token));
        execute();
      }
      else if (!strcmp(token, "SWITCH"))
      {
        if ((token = tokenize(NULL, delimiters)))
          access_memory(SWITCH_REG, WRITE_MEMORY, str2int(token));

        printf("Switch register contains: %04X\n", access_memory(SWITCH_REG, READ_MEMORY, 0));
      }
      else if (!strcmp(token, "RUN"))
      {
        if ((token = tokenize(NULL, delimiters)))
          write_register(15, str2int(token));
        run();
      }
      else if (!strcmp(token, "HELP"))
        printf("\n\
CB                             Clear Breakpoint\n\
DEBUG                          Toggle debug mode (for development only)\n\
DIS  <START>, <STOP>           Disassemble a memory region\n\
DUMP <START>, <STOP>           Dump a memory area, START and STOP can be\n\
                               hexadecimal or plain decimal\n\
LOAD <FILENAME>                Loads a binary file into main memory\n\
QUIT/EXIT                      Stop the emulator and return to the shell\n\
RESET                          Reset the whole machine\n\
RDUMP                          Print a register dump\n\
RUN [<ADDR>]                   Run a program beginning at ADDR\n\
SET <REG|ADDR> <VALUE>         Either set a register or a memory cell\n\
SAVE <FILENAME> <START> <STOP> Create a loadable binary file\n\
SB <ADDR>                      Set breakpoint to an address\n\
STAT                           Displays some execution statistics\n\
STEP [<ADDR>]                  Executes a single instruction at address\n\
                               ADDR. If not address is specified the current\n\
                               program counter will be used instead.\n\
                               If the last command was step, an empty command\n\
                               string will perform the next step!\n\
SWITCH [<VALUE>]               Set the switch register to a value\n\
VERBOSE                        Toggle verbosity mode\n\
");
      else
        printf("main: Unknown command >>%s<<\n", token);
    }
  }
}
