/*
**  QNICE assembler: This program reads QNICE assembler code from a file and generates, as expected from an assembler :-), 
** valid machine code based on this input.
**
** B. Ulmann, JUN-2007, DEC-2007, APR-2008, AUG-2015, DEC-2015, JAN-2016
**
** Known bugs:
**
**   04-JUN-2008: Line numbers in error messages are sometimes a bit off reality (up to -5 has been observed)
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h> /* For malloc.  */
#include <ctype.h>  /* For isdigit. */

#ifndef TRUE
# define TRUE 1
# define FALSE !TRUE
#endif

#undef  VERBOSE
#undef  DEBUG

#define STRING_LENGTH  255
#define MAX_DW_ENTRIES 255

#define COMMENT_CHAR ';'

#define INSTRUCTION$NORMAL    0
#define INSTRUCTION$BRANCH    1
#define INSTRUCTION$DIRECTIVE 2

#define OPERAND$ILLEGAL   -1 /* An illegal operand was found */
#define OPERAND$MISSING   0
#define OPERAND$LABEL_EQU 1  /* Such an operand can be resolved only during the second pass */
#define OPERAND$CONSTANT  2  /* Constants can be resolved immediately in the first pass */
#define OPERAND$RXX       3
#define OPERAND$AT_RXX    4
#define OPERAND$AT_RXX_PP 5
#define OPERAND$AT_MM_RXX 6

#define STATE$INITIAL          0
#define STATE$FINISHED         1
#define STATE$LABELS_MISSING   2
#define STATE$NOTHING_YET_DONE 3

typedef struct _data_entry
{
  char source[STRING_LENGTH],  /* Original source line for printout */
    label[STRING_LENGTH],      /* Name of a label if there was one */
    mnemonic[STRING_LENGTH],   /* Undecoded mnemonic */
    src_op[STRING_LENGTH],     /* Source operand */
    dest_op[STRING_LENGTH],    /* Destination operand */
    dw_data[STRING_LENGTH],    /* Arguments of a .DW-directive */
    error_text[STRING_LENGTH]; /* Text of error message if something went wrong during assembly */
  int address,                 /* Memory address for this instruction/directive */
    export,                    /* Is the label to be exported? */
    number_of_words,           /* How many words of data are necessary for this line? */
    *data,                     /* Pointer to a list of number_of_words-ints holding the resulting data */
    opcode, opcode_type,       /* Which opcode and which type* */
    src_op_type,               /* If the source operand is a constant, it will be stored here */
    dest_op_type,              /* The same holds true for the destination */
    src_op_code,               /* The six bits describing the first operand */
    dest_op_code,              /* The six bits describing the second operand */
    state;                     /* STATE$FINISHED, STATE$LABELS_MISSING */
  struct _data_entry *next;
} data_structure;

typedef struct _equ_entry
{
  char name[STRING_LENGTH];
  int value;
  struct _equ_entry *next;
} equ_structure;

/*
** Global variables:
*/

data_structure *gbl$data = 0;
equ_structure  *gbl$equs = 0;

/*
** Expand all tabs by blanks, assuming that tab stops occur every eight columns.
*/
void expand_tabs(char *dst, char *src)
{
  int i;

  i = 0;
  while (*src)
  {
    i++;
    if (*src != '\t')
      *dst++ = *src++;
    else
    {
      *dst++ = ' ';
      for ( ; (i % 8); i++, *dst++ = ' ');
      src++;
    }
  }

  *dst = (char) 0;
}

/*
** Convert a string to uppercase.
*/
void string2upper(char *string)
{
  while (*string)
  {
    *string = (char) toupper((int) *string);
    string++;
  }
}

/*
** Convert a sequence of ASCII chars to a value.
*/
unsigned int ascii2value(char *string)
{
  unsigned int result = 0;

  string++; /* Skip leading single quote */
  while (*string != '\'') /* We can rely on a trailing single quote */
  {
    result <<= 8;
    result += *string++;
  }

  return result & 0xffff;
}

/*
** Convert a sequence of '0' and '1' to a value.
*/
unsigned int binstr2value(char *string)
{
  unsigned int result = 0;

  while (*string)
  {
    result <<= 1;
    if (*string++ == '1')
      result += 1;
  }

  return result & 0xffff;
}

/*
** Translate a mnemonic to its corresponding opcode. If mnemonic does not match, FALSE will be returned, otherwise it's TRUE.
*/
int translate_mnemonic(char *string, int *opcode, int *type)
{
  int i;
  static char *normal_mnemonics[] = {"MOVE", "ADD", "ADDC", "SUB", "SUBC", "SHL", "SHR", "SWAP", 
                              "NOT", "AND", "OR", "XOR", "CMP", "RSRVD", "HALT", 0},
    *branch_mnemonics[] = {"ABRA", "ASUB", "RBRA", "RSUB", 0},
    *directives[] = {".ORG", ".ASCII_W", ".ASCII_P", ".EQU", ".BLOCK", ".DW", 0};

  if (!string)
    return FALSE;
  
  string2upper(string);

  for (i = 0; normal_mnemonics[i]; i++) /* First try the "normal" mnemonics, i.e. no branches */
    if (!strcmp(string, normal_mnemonics[i]))
    {
      *type = INSTRUCTION$NORMAL;
      *opcode = i;
      return TRUE;
    }
  
  for (i = 0; branch_mnemonics[i]; i++) /* Now try the branches */
    if (!strcmp(string, branch_mnemonics[i]))
    {
      *type = INSTRUCTION$BRANCH;
      *opcode = i;
      return TRUE;
    }
  
  for (i = 0; directives[i]; i++)
    if (!strcmp(string, directives[i]))
    {
      *type = INSTRUCTION$DIRECTIVE;
      *opcode = i;
      return TRUE;
    }
  
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
    while (*position && strchr(delimiters, *position)) /* Skip delimiters if there are any at the beginning of the string */
      position++;

    token = position; /* Now we are at the beginning of a token (or the end of the string :-) ) */

    if (*position == '\'') /* Special case: Strings delimited by single quotes won't be split! */
    {
      position++;
      while (*position && *position != '\'')
        position++;
    }

    while (*position)
    {
      position++;
      if (!*position || strchr(delimiters, *position)) /* Delimiter found */
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
**  replace_extension replaces the extension of a file name with another extension. If there is no extension in the input string 
** then the new extension is just concatenated to the input name.
*/
void replace_extension(char *destination, char *source, char *new_extension)
{
  char *delimiter;
  
  strcpy(destination, source);
  if (!(delimiter = strrchr(destination, '.'))) /* No delimiter found */
    strcat(destination, ".");
  else
    *(delimiter + 1) = (char) 0;

  strcat(destination, new_extension);
}

/*
**  Print a simple usage text.
*/
void print_help()
{
  printf("\nUsage:\nqasm <source_file> [<output_file> [<listing_file>]]\n\n");
}

/*
** Does exactly what you would expect. :-)
*/
void chomp(char *string)
{
  if (string[strlen(string) - 2] == 0xa || string[strlen(string) - 2] == 0xd)
    string[strlen(string) - 2] = (char) 0;
  else if (string[strlen(string) - 1] == 0xa || string[strlen(string) - 1] == 0xd)
    string[strlen(string) - 1] = (char) 0;
}

/*
** Remove TABs from the source code
*/
void remove_tabs(char *cp)
{
  while (*cp++)
    if (*cp == 0x9)
      *cp = ' ';
}

/*
** The two following functions remove_trailing_blanks and remove_leading_blanks do exactly what you would expect. :-)
*/
void remove_trailing_blanks (char *cp)
{
  int i;

  for (i = strlen (cp) - 1; i >= 0 && (*(cp + i) == '\t' || *(cp + i) == ' '); *(cp + i--) = 0);
}

void remove_leading_blanks (char *string)
{
  char *cp;
  
  cp = string;
  while (*cp == ' ' || *cp == '\t')
    cp++;

  while ((*string++ = *cp++)); /* 26.07.2015: strcpy on Mac OS X 10.10.3 traps when copying a string partially to itself... */
}

/*
**  find_label searches for a given label and returns its address by a pointer. The return value of the function denotes
** success (0) or failure (-1).
*/
int find_label(char *name, int *address)
{
  data_structure *entry;
  
  for (entry = gbl$data; entry; entry = entry->next)
    if (!strcmp(entry->label, name))
    {
      *address = entry->address & 0xffff;
      return 0;
    }
  
  return -1; /* No corresponding label found! */
}

/*
**  search_equ_list searches the list of currently known EQUs for a given entry. It returns -1 if nothing could be found,
** 0 otherwise. The result is returned via the second char-pointer.
*/
int search_equ_list(char *name, int *value)
{
  equ_structure *entry;
  
  for (entry = gbl$equs; entry; entry = entry->next)
    if (!strcmp(entry->name, name))
    {
      *value = entry->value;
      return 0;
    }
    
  return -1;
}

/*
**  insert_into_equ_list inserts a new entry into the list of currently known EQUs. If the insert was successful, 0 will be 
** returned. -1 denotes a memory problem, 1 denotes a duplicate entry!
*/
int insert_into_equ_list(char *name, int value)
{
  int i;
  equ_structure *entry;
  static equ_structure *last;
  
#ifdef DEBUG
  printf("insert_into_equ_list: >>%s<< = %d/%04X\n", name, value, value);
#endif
  if (!(entry = (equ_structure *) malloc(sizeof(equ_structure))))
  {
    printf("insert_into_equ_list: Out of memory!\n");
    return -1;
  }
  
  strcpy(entry->name, name);
  entry->value = value;
  entry->next = (equ_structure *) 0;
  
  if (!gbl$equs) /* This will be the very first entry in the list! */
    gbl$equs = last = entry;
  else /* Not the first entry -> append to the end of the list */
  {
    if (!search_equ_list(name, &i))
      return 1;
    last = last->next = entry;
  }
  
  return 0;
}

/*
**  Read the complete source file into a simlpe linked list. This list will be
** the basis for all of the following operations and will eventually contain
** the source code as well as the corresponding binary data.
*/
int read_source(char *file_name)
{
  int counter;
  char line[STRING_LENGTH];
  FILE *handle;
  data_structure *entry, *previous;
  
  if (!(handle = fopen(file_name, "r")))
  {
    printf("read_source: Unable to open source file >>%s<<!\n", file_name);
    return -1;
  }
    
  for (previous = (data_structure *) 0, counter = 0;; counter++)
  {
    fgets(line, STRING_LENGTH, handle);
    if (feof(handle))
      break;
      
    chomp(line);
    remove_trailing_blanks(line);
    
    if (!(entry = (data_structure *) malloc(sizeof(data_structure)))) /* Get some memory for the line read */
    {
      fclose(handle);
      printf("read_source: Out of memory!\n");
      return -1;
    }
    
    if (!gbl$data) /* First element in list? */
      gbl$data = entry;

    /* Populate new entry */
    entry->address = entry->opcode = entry->opcode_type = -1;
    entry->src_op_type = entry->dest_op_type = OPERAND$MISSING;
    entry->number_of_words = entry->src_op_code = entry->dest_op_code = 0;
    entry->data = (int *) 0;
    *(entry->label) = *(entry->mnemonic) = *(entry->src_op) = *(entry->dest_op) = *(entry->error_text) = (char) 0;
    entry->next = (data_structure *) 0;
    
    strcpy(entry->source, line); /* Remember the source code line for later analysis and print out */
    
    if (previous) /* This is not the first element in the list */
      previous = previous->next = entry;
    else
      previous = gbl$data;
  }
  
  fclose(handle);
  
#ifdef VERBOSE
  printf("read_source: %d lines read\n", counter);
#endif
  
  return 0;
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
  else if (!strncmp(string, "-0X", 3) || !strncmp(string, "-0x", 3))
  {
    sscanf(string + 3, "%x", &value);
    value = -value & 0xffff;
  }
  else if (!strncmp(string, "0B", 2) || !strncmp(string, "0b", 2))
    value = binstr2value(string + 2);
  else if (!strncmp(string, "-0B", 3) || !strncmp(string, "-0b", 3))
    value = -binstr2value(string + 3) & 0xffff;
  else if (*string == '$')
    sscanf(string + 1, "%x", &value);
  else if (*string == '\'' && *(string + strlen(string) - 1) == '\'')
    value = ascii2value(string);
  else
    sscanf(string, "%d", &value);

  return value;
}

/*
**  decode_operand decodes a given operand. Its return value is the type of the operand, the pointer *op_code will be used to 
** return the six (!) bits describing the operand.
*/
int decode_operand(char *operand, int *op_code)
{
  int value, auto_increment, i, flag;
  char *p;
  
  if ((char) toupper((int) *operand) == 'R') /* Maybe a simple register */
  {
    flag = 1; /* Pretend it is a register number what follows */
    for (i = 1; i < strlen(operand) - 1; i++)
      if (!isdigit(*(operand + i)))
        flag = 0;

    if (flag) /* OK - it looks like a register description */
    {
      value = str2int(operand + 1);
      if (value < 0 || value > 15) /* Maybe it wasn't a register but a label? */
        return OPERAND$LABEL_EQU;
      
      *op_code = value << 2;
      return OPERAND$RXX;
    }
    else
    {
      *op_code = 0x3e;
      return OPERAND$LABEL_EQU;
    }
  }
  else if (!strncmp(operand, "@R", 2)) /* Simple indirect addressing */
  {
    if ((auto_increment = (operand[strlen(operand) - 1] == '+' && operand[strlen(operand) - 2] == '+')))
      operand[strlen(operand) - 2] = (char) 0;
      
    value = str2int(operand + 2);
    if (value < 0 || value > 15)
      return OPERAND$ILLEGAL;
    
    if (auto_increment)
    {
      *op_code = value << 2 | 2;
      return OPERAND$AT_RXX;
    }
    else
    {
      *op_code = value << 2 | 1;
      return OPERAND$AT_RXX_PP;
    }
  }
  else if (!strncmp(operand, "@--R", 4)) /* Indirect addressing with predecrement */
  {
    value = str2int(operand + 4);
    if (value < 0 || value > 15)
      return OPERAND$ILLEGAL;
      
    *op_code = value << 2 | 3;
    return OPERAND$AT_MM_RXX;
  }
  /* Constants can be of the form 0x..., 0b..., -0x..., -0b..., or '...' */
  else if (isdigit(*operand) || *operand == '\'' || *operand == '-') 
  {
    *op_code = 0x3e;
    return OPERAND$CONSTANT;
  }
  
  *op_code = 0x3e;
  return OPERAND$LABEL_EQU; /* Such an operand can only be resolved during the second pass! */
}

/*
**  assemble does all the real work of the assembler. It reads the source contained in the linked list and fills the 
** corresponding elements of the list with addresses and data words as applicable.
*/
int assemble()
{
  int opcode, type, line_counter, address = 0, i, j, error_counter = 0, number_of_operands, negate, flag, value, size,
    special_char, org_found = 0;
  char line[STRING_LENGTH], label[STRING_LENGTH], *p, *delimiters = " ,", *token, *sr_bits = "1XCZNVIM";
  data_structure *entry;

  /* First pass: */
#ifdef DEBUG
  printf("assemble: Starting first pass.\n");
#endif
  for (line_counter = 1, entry = gbl$data; entry; entry = entry->next, line_counter++)
  {
    strcpy(line, entry->source);           /* Get a local copy of the line and clean it up */
    entry->state = STATE$NOTHING_YET_DONE; /* Still a lot to do */
    if ((p = strchr(line, COMMENT_CHAR)))  /* Remove everything after the start of a comment */
      *p = (char) 0;
    remove_leading_blanks(line);
    remove_trailing_blanks(line);
    remove_tabs(line);
    
    if (!strlen(line)) /* Skip empty lines */
      continue;
      
    tokenize(line, (char *) 0); /* Initialize tokenizing */
    token = tokenize((char *) 0, delimiters);
    strcpy(label, token); /* Make a copy of the token in case it is a label to avoid implicit conversion to upper case */
    
    if (translate_mnemonic(token, &opcode, &type)) /* First token is a mnemonic or a directive */
      strcpy(entry->mnemonic, token);
    else /* If the first token is neither a mnemonic nor an opcode, assume it is a label */
    {
      if (label[strlen(label) - 1] == '!') /* This label should be exported! */
      {
        label[strlen(label) - 1] = (char) 0;
        entry->export = 1;
      }

      strcpy(entry->label, label);
      token = tokenize((char *) 0, delimiters); /* Next token has to be a valid mnemonic or directive */
      if (!translate_mnemonic(token, &opcode, &type))
      {
        sprintf(entry->error_text, "Line %d: No valid mnemonic/directive found (%s)!", line_counter, entry->source);
        printf("assemble: %s\n", entry->error_text);
        entry->opcode = entry->opcode_type = -1;
        error_counter++;
        continue;
      }
      strcpy(entry->mnemonic, token);
    }

    entry->opcode = opcode;
    entry->opcode_type = type;
    entry->address = address;
    
    if (entry->opcode_type == INSTRUCTION$DIRECTIVE) /* A directive - do something... */
    {
      address--;
      
      /* If the directive .ORG was found, it is now time to change the address */
      if (!strcmp(entry->mnemonic, ".ORG"))
      {
        entry->state = STATE$FINISHED;
        token = tokenize((char *) 0, delimiters); /* Get new address */
        entry->address = -1;
        address = str2int(token) - 1; /* - 1 since the address will be incremented later */
      }
      else if (!strcmp(entry->mnemonic, ".DW"))
      {
        i = 0;
        if (!(p = strstr(line, ".DW"))) /* Upper case/lower case */
          p = strstr(line, ".dw");
        p += strlen(".DW") + 1;
        remove_leading_blanks(p);
        strcpy(entry->dw_data, p);

        while ((token = tokenize((char *) 0, delimiters))) /* How many words do we have to reserve? */
          i++;

        if (!(entry->data = (int *) malloc(i * sizeof(int))))
        {
          printf("assemble (.DW): Out of memory, could not allocate %d words of memory!", (int) strlen(p));
          return -1;
        }

        entry->number_of_words = i;
        address += i;
      }
      else if (!strcmp(entry->mnemonic, ".ASCII_W") || !strcmp(entry->mnemonic, ".ASCII_P"))
      {
        /*
        **  .ASCII_W expects a string of ASCII characters which will be stored one character per word (only the low byte
        ** of each word is used, the upper byte is 0). The string will be automatically terminated by a zero-word (quite
        ** compatible with the standard way of life in C.
        **
        **  .ASCII_P works quite like .ASCII_W but no terminating zero word will be written (thus the P -> Plain).
        **
        **  Both variants can deal with the special character '\n' which will be translated to CR/LF.
        */

        /* ASCII constants are enclosed in double quotes! */
        if (!strcmp(entry->mnemonic, ".ASCII_W"))
        {
          if(!(p = strstr(line, ".ASCII_W")))
            p = strstr(line, ".ascii_w");
        }
        else
        { 
          if(!(p = strstr(line, ".ASCII_P")))
            p = strstr(line, ".ascii_p");
        }
        p += strlen(".ASCII_W") + 1; /* Get begin of argument, including blanks, so no tokenize! */

        remove_leading_blanks(p);
        if (*p++ != '"') /* No double quote found! */
        {
          sprintf(entry->error_text, "Line %d: Did not find opening double quote!", line_counter);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
          continue;
        }

        if (!(entry->data = (int *) malloc(strlen(p) * sizeof(int) + 1))) /* Maybe one word too much due to trailing " */
        {
          printf("assemble (.ASCII_W/.ASCII_P): Out of memory, could not allocate %d words of memory!", (int) strlen(p));
          return -1;
        }
        
        for (special_char = i = 0; i < strlen(p) && *(p + i) != '"'; i++, address++)
        {
          if (*(p + i) == '\\')
            special_char = 1;
          else if (special_char && *(p + i) == 'n')
          {
            *(entry->data + i - 1) = (char) 13;
            *(entry->data + i)     = (char) 10;
            special_char = 0;
          }
          else if (special_char && *(p + i) != 'n')
          {
            *(entry->data + i - 1) = *(p + i - 1);
            *(entry->data + i)     = *(p + i);
          }
          else
          {
            special_char = 0;
            *(entry->data + i) = 0xff & *(p + i);
          }
        }

        if (!strcmp(entry->mnemonic, ".ASCII_W")) /* No terminating zero word in case of .ASCII_P. */
        {
          *(entry->data + i) = 0;
          address++;
        }

        if (*(p + i) != '"')
        {
          sprintf(entry->error_text, "Line %d: WARNING - Did not find closing double quote!", line_counter);
          printf("assembler: %s\n", entry->error_text);
        }

        entry->number_of_words = i;
        if (!strcmp(entry->mnemonic, ".ASCII_W"))
          entry->number_of_words++;

        entry->state = STATE$FINISHED;
      }
      else if (!strcmp(entry->mnemonic, ".BLOCK")) /* .BLOCK expects one argument being the size of the block to be reserved */
      {
        token = tokenize((char *) 0, delimiters); /* Get size of block */
        if (search_equ_list(token, &size)) /* Returns -1 if nothing is found */
          size = str2int(token); 

        if (!(entry->data = (int *) malloc(size * sizeof(int))))
        {
          printf("assemble (.BLOCK): Out of memory, could not allocate %d words of memory!", (int) strlen(p));
          return -1;
        }

        for (i = 0; i < size; i++, address++)
          *(entry->data + i) = 0;

        entry->number_of_words = size;
        entry->state = STATE$FINISHED;
      }
      else if (!strcmp(entry->mnemonic, ".EQU")) /* Introduce a string which will equal some value */
      {
        token = tokenize((char *) 0, delimiters);
        if (insert_into_equ_list(entry->label, str2int(token)))
        {
          /*
          **  Design bug: Since an EQU does not get a corresponding code entry, the following
          ** error message will only printed to stdout but not occur in the resulting listing!
          */
          sprintf(entry->error_text, "Line %d: Duplicate equ-entry '%s'.", line_counter, entry->label);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
        }
	    *(entry->label) = (char) 0;
        entry->state = STATE$FINISHED;
        entry->address = -1;
      }
      else
      {
        sprintf(entry->error_text, "Line %d: Unknown directive >>%s<<. Very strange!", line_counter, entry->mnemonic);
        printf("assemble: %s\n", entry->error_text);
        error_counter++;
        continue;
      }
    }
    else if (entry->opcode_type == INSTRUCTION$NORMAL) /* A simple mnemonic */
    {
      entry->number_of_words = 1; /* At least one word to hold the instruction! */
      number_of_operands = entry->opcode == 0xe ? 0 : 2; /* All instructions except HALT require two operands. */

      if (number_of_operands) /* Read operands. */
      {
        if (!(token = tokenize((char *) 0, delimiters)))
        {
          sprintf(entry->error_text, "Line %d: No first operand found! (%s)", line_counter, entry->source);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
          continue;
        }
        strcpy(entry->src_op, token);
        
        /* Determine type of first operand. */
        if ((entry->src_op_type = decode_operand(entry->src_op, &entry->src_op_code)) == OPERAND$ILLEGAL)
        {
          sprintf(entry->error_text, "Line %d: Illegal first operand! (%s)", line_counter, entry->source);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
          continue;
        }
        
        if (entry->src_op_type == OPERAND$CONSTANT || entry->src_op_type == OPERAND$LABEL_EQU)
        {
          entry->number_of_words++;
          address++;
        }

        if (number_of_operands > 1)
        {
          if (!(token = tokenize((char *) 0, delimiters)))
          {
            sprintf(entry->error_text, "Line %d: No second operand found! (%s)", line_counter, entry->source);
            printf("assemble: %s\n", entry->error_text);
            error_counter++;
            continue;
          }
          strcpy(entry->dest_op, token);
          
          /* Determine the type of the second operand. */
          if ((entry->dest_op_type = decode_operand(entry->dest_op, &entry->dest_op_code)) == OPERAND$ILLEGAL)
          {
            sprintf(entry->error_text, "Line %d: Illegal second operand! (%s)", line_counter, entry->source);
            printf("assemble: %s\n", entry->error_text);
            error_counter++;
            continue;
          }
          
          if ((entry->dest_op_type == OPERAND$CONSTANT || entry->dest_op_type == OPERAND$LABEL_EQU) && 
              strcmp(entry->mnemonic, "CMP")) /* A constant as destination is OK only for CMP! */
          {
            entry->number_of_words++;
            address++;
            sprintf(entry->error_text, "Line %d: A constant as destination operand ('%s') may not be what you wanted.", 
                    line_counter, entry->dest_op);
            printf("assemble: %s\n", entry->error_text);
            /* This is just a warning, so no increment of error_counter is necessary! */
          }
        }
      }

      if (!(entry->data = (int *) malloc(entry->number_of_words * sizeof(int))))
      {
        printf("assemble: Out of memory, could not allocate %d words of memory!", (int) strlen(p));
        return -1;
      }

      entry->data[0] = (entry->opcode << 12 | ((entry->src_op_code & 0x3f) << 6) | ((entry->dest_op_code) & 0x3f)) & 0xffff;

      i = 1;
      if (entry->src_op_type == OPERAND$CONSTANT) 
        *(entry->data + i++) = str2int(entry->src_op) & 0xffff;
        
      if (entry->dest_op_type == OPERAND$CONSTANT)
        *(entry->data + i) = str2int(entry->dest_op) & 0xffff;
    }
    else if (entry->opcode_type == INSTRUCTION$BRANCH) /* Ups, a branch! */
    {
      entry->number_of_words = 1; /* At least one word to hold the instruction! */

      /* A branch always has two operands! */
      if (!(token = tokenize((char *) 0, delimiters)))
      {
        sprintf(entry->error_text, "Line %d: No first branch operand found! (%s)", line_counter, entry->source);
        printf("assemble: %s\n", entry->error_text);
        error_counter++;
        continue;
      }
      strcpy(entry->src_op, token);

      if (!(token = tokenize((char *) 0, delimiters)))
      {
        sprintf(entry->error_text, "Line %d: No second branch operand found! (%s)", line_counter, entry->source);
        printf("assemble: %s\n", entry->error_text);
        error_counter++;
        continue;
      }
      strcpy(entry->dest_op, token);

      /* Now we have both operands of the branch and the branch itself as well. Decode the first operand. */
      if ((entry->src_op_type = decode_operand(entry->src_op, &entry->src_op_code)) == OPERAND$ILLEGAL)
      {
        sprintf(entry->error_text, "Line %d: Illegal first operand! (%s)", line_counter, entry->source);
        printf("assemble: %s\n", entry->error_text);
        error_counter++;
        continue;
      }

      /* Now decode the second operand: Is it negated? Which flag is it? */
      p = entry->dest_op;
      if ((negate = (*(entry->dest_op) == '!')))
        p++;
        
      for (flag = 0; sr_bits[flag]; flag++)
        if (sr_bits[flag] == *p)
          break;
          
      if (flag > 7)
      {
        sprintf(entry->error_text, "Line %d: Illegal condition flag! (%s)", line_counter, entry->source);
        printf("assemble: %s\n", entry->error_text);
        error_counter++;
        continue;
      }
      
      /* Now prepare for memory allocation and construction of the instruction itself. */
      if (entry->src_op_type == OPERAND$CONSTANT || entry->src_op_type == OPERAND$LABEL_EQU)
      {
        entry->number_of_words++;
        address++;
      }

      if (!(entry->data = (int *) malloc(entry->number_of_words * sizeof(int))))
      {
        printf("assemble: Out of memory, could not allocate %d words of memory!", (int) strlen(p));
        return -1;
      }

      /* Assemble the instruction itself */
      entry->data[0] = (0xf000 | 
                        ((entry->src_op_code & 0x3f) << 6) | ((entry->opcode & 3) << 4) | ((negate & 1) << 3) | (flag & 0x7)) 
                         & 0xffff;

      if (entry->src_op_type == OPERAND$CONSTANT) /* Labels are no constants in this context since they are not known in advance */
/*        entry->data[1] = (str2int(entry->src_op) - address - 1) & 0xffff; This was the old behaviour */ 
        entry->data[1] = str2int(entry->src_op) & 0xffff;
    }
    else 
    {
      sprintf(entry->error_text, "Line %d: Unknown opcode type %d! Very strange error!", line_counter, entry->opcode_type);
      printf("assemble: %s\n", entry->error_text);
      error_counter++;
    }
    address++;
  }
  
  /* Second pass: */
#ifdef DEBUG
  printf("assemble: Starting second pass.\n");
#endif
  for (entry = gbl$data; entry; entry = entry -> next)
  {
    i = 1; /* Index for data word array */
    if (entry->src_op_type == OPERAND$LABEL_EQU) /* Still unresolved label or equ! */
    {
      value = 0;
      if (search_equ_list(entry->src_op, &value))
        if (find_label(entry->src_op, &value))
        {
          sprintf(entry->error_text, "Line %d: Unresolved label or equ >>%s<<!", line_counter, entry->src_op);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
          continue;
        }

      if (entry->opcode_type == INSTRUCTION$BRANCH && *entry->mnemonic == 'R') /* Relative branch or subroutine call */
        entry->data[i++] = (value - entry->address - 2) & 0xffff; /* - 2 since address is a constant and occupies the next cell */
      else
        entry->data[i++] = value;
    }
  
    if (entry->dest_op_type == OPERAND$LABEL_EQU) /* Still unresolved label or equ! */
    {
      value = 0;
      if (search_equ_list(entry->dest_op, &value))
        if (find_label(entry->dest_op, &value))
        {
          sprintf(entry->error_text, "Line %d: Unresolved label or equ >>%s<<!", line_counter, entry->dest_op);
          printf("assemble: %s\n", entry->error_text);
          error_counter++;
          continue;
        }
        
      entry->data[i] = value;
    }

    if (!strcmp(entry->mnemonic, ".DW")) /* Postprocessing for .DW-directive */
    {
      i = 0;
      tokenize(entry->dw_data, (char *) 0); /* Initialize tokenizing */
      while ((token = tokenize((char *) 0, delimiters))) /* Resolve every single parameter */
      {
        if (search_equ_list(token, &value)) /* Returns -1 if unsuccessful */
          if (find_label(token, &value)) /* Also returns -1 if unsuccessful */
            value = str2int(token); /* Neither a EQU nor a LABEL... */

        *(entry->data + i++) = value;
      }
    }
  }

  return error_counter;
}

/*
**  write_result scans the complete linked list containing the source code as well as the resulting binary code and creates a 
** (binary) output file and the corresponting listing file.
**
**  A .def-file will be written if there is at least one label that has been flagged to be exported which is denoted by an
** exclamationmark following the label name ("L MOVE R0, R1" will generate a label "L" which will not be exported, while
** "L! MOVE R0, R1" will generate a label "L" that will be listed in the .def-file).
*/
int write_result(char *output_file_name, char *listing_file_name, char *def_file_name)
{
  int line_counter, i;
  char address_string[STRING_LENGTH], data_string[STRING_LENGTH], line[STRING_LENGTH], second_word[STRING_LENGTH];
  FILE *output_handle, /* file handle for binary output data */
    *listing_handle, *def_handle = (FILE *) 0;
  data_structure *entry;
  equ_structure *equ;
  
  if (!(output_handle = fopen(output_file_name, "w")))
  {
    printf("write_result: Unable to open output file >>%s<<!\n", output_file_name);
    return -1;
  }
  
  if (!(listing_handle = fopen(listing_file_name, "w")))
  {
    printf("write_result: Unable to open listing file >>%s<<!\n", listing_file_name);
    return -1;
  }

  for (entry = gbl$data, line_counter = 0; entry; entry = entry->next)
  {
    /* Write listing */
    if (*(entry->error_text)) /* If there was an error, print it preceeding the erroneous line */
      fprintf(listing_handle, "\n*** %s ***\n", entry->error_text);

    *address_string = *data_string = *second_word = (char) 0;
    if (entry->address != -1)
    {
      sprintf(address_string, "%04X", entry->address & 0xffff);
      if (entry->number_of_words)
        sprintf(data_string, "%04X", entry->data[0] & 0xffff);
    }

    if (entry->number_of_words == 2) /* Many instructions require two words, but should be displayed in a single line */
      sprintf(second_word, "%04X", entry->data[1] & 0xffff);

    expand_tabs(line, entry->source);
    fprintf(listing_handle, "%06d  %4s  %4s  %4s  %s\n", ++line_counter, address_string, data_string, second_word, line);
    if (entry->address != -1) /* Write binary data */
      fprintf(output_handle, "0x%4s 0x%4s\n", address_string, data_string);

    for (i = 1; i < entry->number_of_words; i++) /* If there is additional data as in .ASCII_W, write it */
    {
      if (entry->number_of_words > 2)
        fprintf(listing_handle, "        %04X  %04X\n", entry->address + i, entry->data[i]);
      fprintf(output_handle, "0x%04X 0x%04X\n", entry->address + i, entry->data[i]);
    }
  }
  
  /* Generate a list of defined EQUs */
  fprintf(listing_handle, 
    "\n\nEQU-list:\n--------------------------------------------------------------------------------------------------------");
  for (i = 0, equ = gbl$equs; equ; equ = equ->next, i++)
  {
    if (!(i % 3))
      fprintf(listing_handle, "\n");
    fprintf(listing_handle, "%-24s: 0x%04X    ", equ->name, equ->value & 0xffff);
  }
  
  /* Generate a list of labels as well as the definition file */
  
  fprintf(listing_handle, 
    "\n\nLabel-list:\n--------------------------------------------------------------------------------------------------------");
  for (i = 0, entry = gbl$data; entry; entry = entry->next)
  {
    if(!*(entry->label))
      continue;
    
    if (!(i++ % 3))
      fprintf(listing_handle, "\n");
    fprintf(listing_handle, "%-24s: 0x%04X    ", entry->label, entry->address & 0xffff);

    if (entry->export)
    {
      if (!def_handle)
      {
        if (!(def_handle = fopen(def_file_name, "w")))
        {
          printf("write result: Unable to open definition file >>%s<<\n", def_file_name);
          return -1;
        }

        fprintf(def_handle, ";;\n\
;; This is an automatically generated definition file!\n\
;; Do NOT change manually!\n\
;;\n");
      }

      fprintf(def_handle, "%-30s\t.EQU\t0x%04X\n", entry->label, entry->address & 0xffff);
    }
  }
  fprintf(listing_handle, "\n");

  fclose(output_handle);
  fclose(listing_handle);
  fclose(def_handle);
  
  return 0;
}

int main(int argc, char **argv)
{
  int rc;
  char *source_file_name, output_file_name[STRING_LENGTH], listing_file_name[STRING_LENGTH], def_file_name[STRING_LENGTH];
    
  if (argc < 2 || argc > 4)
    print_help();
  else
  {
    source_file_name = argv[1];
    *output_file_name = *listing_file_name = *def_file_name = (char) 0;
    
    if (argc > 2) /* Output file name explicitly stated */
    {
      strcpy(output_file_name, argv[2]);
      if (argc > 3) /* Listing file name explicitly stated */
        strcpy(listing_file_name, argv[3]);
    }

    if (!*output_file_name)
      replace_extension(output_file_name, source_file_name, "bin");

    replace_extension(def_file_name, output_file_name, "def");
      
    if (!*listing_file_name)
        replace_extension(listing_file_name, output_file_name, "lis");

#ifdef VERBOSE
    printf("Reading >>%s<<, writing >>%s<< (bin) and >>%s<< (lis).\n",
      source_file_name, output_file_name, listing_file_name);
#endif

    if ((rc = read_source(source_file_name)))
      return rc;
    
    if ((rc = assemble()) > 0)
    {
      printf("main: There were %d errors during assembly! No files written!\n", rc);
      return rc;
    }
    else if (rc < 0)
    {
      printf("main: There was an unrecoverable error during assembly (%d)! No files written!\n", rc);
      return rc;
    }
    
    if ((rc = write_result(output_file_name, listing_file_name, def_file_name)))
      return rc;
  }

  return 0;
}
