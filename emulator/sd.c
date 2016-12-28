/*
** SD-card emulator.
**
** 28-DEC-2016, B. Ulmann fecit
*/

#include "sd.h"
#include <stdio.h>
#include <stdlib.h>

#define DEBUG
#define VERBOSE

FILE *image;

unsigned static int sd_addr_lo = 0, sd_addr_hi = 0, sd_data_pos = 0, sd_error = 0, sd_csr = 0,
  sd_data[SD_SECTOR_SIZE];

void sd_attach(char *filename)
{
#ifdef DEBUG
  printf("sd_init: Open >>%s<<\n", filename);
#endif

  if (!(image = fopen(filename, "rb")))
  {
    printf("Unable to attach SD-card image file >>%s<<!\n", filename);
    exit(-1);
  }
}

void sd_detach()
{
  fclose(image);
}

void sd_write_register(unsigned int address, unsigned int value)
{
#ifdef DEBUG
  printf("sd_write_register(%04X, %04X)\n", address & 0xffff, value & 0xffff);
#endif
  switch (address)
  {
    case SD_ADDR_LO:
      sd_addr_lo = value & 0xffff;
      break;
    case SD_ADDR_HI:
      sd_addr_hi = value & 0xffff;
      break;
    case SD_DATA_POS:
      sd_data_pos = value & 0x01ff;
      break;
    case SD_DATA:
      sd_data[sd_data_pos & 0x01ff] = value & 0xffff;
      break;
    case SD_CSR:
      if ((value & 0xffff) == 1) /* Read 512 bytes from the block addressed by the current LBA. */
      {
#ifdef DEBUG
        printf("SD: Read block %08X.\n", (sd_addr_lo & 0xffff) | ((sd_addr_hi & 0xfff) << 16));
#endif
        fseek(image, (sd_addr_lo & 0xffff) | ((sd_addr_hi & 0xfff) << 16), SEEK_SET);
        fread(sd_data, SD_SECTOR_SIZE, 1, image);
      }
      else if ((value & 0xffff) == 2) /* Write 512 bytes to the block address by the current LBA. */
      {
#ifdef DEBUG
        printf("SD: Write block %08X.\n", (sd_addr_lo & 0xffff) | ((sd_addr_hi & 0xfff) << 16));
#endif
        fseek(image, (sd_addr_lo & 0xffff) | ((sd_addr_hi & 0xfff) << 16), SEEK_SET);
        fwrite(sd_data, SD_SECTOR_SIZE, 1, image);
      }

      sd_csr = 0x8000;
      break;
    default:
#ifdef VERBOSE
      printf("sd_write_register: attempt to write illegal register %04X <- %04X.\n", address & 0xffff, value & 0xffff);
#endif
  }
}

unsigned int sd_read_register(unsigned int address)
{
  unsigned int value;

  switch (address)
  {
    case SD_ADDR_LO:
      value = sd_addr_lo;
      break;
    case SD_ADDR_HI:
      value = sd_addr_hi;
      break;
    case SD_DATA_POS:
      value = sd_data_pos;
      break;
    case SD_DATA:
      value = sd_data[sd_data_pos & 0x01ff] & 0xffff;
#ifdef DEBUG
      printf("SD: Read from buffer [%05X]: %04X\n", sd_data_pos & 0x01ff, value);
#endif
      break;
    case SD_ERROR:
      value = sd_error;
      break;
    case SD_CSR: /* More or less a dummy operation as there is no room for errors in the emulation. :-) */
#ifdef DEBUG
      printf("sd_read_register: CSR\n");
#endif
      value = sd_csr;
      sd_csr = 0;
      break;
    default:
#ifdef VERBOSE
      printf("sd_read_register: attempt to read illegal register %04X.\n", address);
#endif
  }

#ifdef DEBUG
  printf("sd_read_register(%04X) -> %04X\n", address & 0xffff, value & 0xffff);
#endif

  return value & 0xffff;
}
