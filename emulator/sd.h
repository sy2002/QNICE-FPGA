/*
** Header file for the SD-card emulation.
**
** 28-DEC-2016, B. Ulmann fecit
*/

#define SD_BASE_ADDRESS 0xff24
#define SD_NUMBER_OF_REGISTERS 6

#define SD_ADDR_LO  0
#define SD_ADDR_HI  1
#define SD_DATA_POS 2
#define SD_DATA     3
#define SD_ERROR    4
#define SD_CSR      5

#define SD_SECTOR_SIZE 512

void sd_attach(char *);
void sd_detach();
unsigned int sd_read_register(unsigned int);
void sd_write_register(unsigned int, unsigned int);
