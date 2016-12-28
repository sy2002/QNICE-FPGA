/*
** Header file for the SD-card emulation.
**
** 28-DEC-2016, B. Ulmann fecit
*/

#define SD_ADDR_LO  0xff24
#define SD_ADDR_HI  0xff25
#define SD_DATA_POS 0xff26
#define SD_DATA     0xff27
#define SD_ERROR    0xff28
#define SD_CSR      0xff29

#define SD_SECTOR_SIZE 512

void sd_attach(char *);
void sd_detach();
unsigned int sd_read_register(unsigned int);
void sd_write_register(unsigned int, unsigned int);
