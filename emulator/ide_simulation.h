#ifndef TRUE
# define TRUE 1
# define FALSE !TRUE
#endif

#define IDE_BASE_ADDRESS        0xffe0
#define IDE_NUMBER_OF_REGISTERS 16

void writeIDEDeviceRegister(unsigned int address, unsigned int value);
unsigned int readIDEDeviceRegister(unsigned int address);
void initializeIDEDevice();

//For testing purposes only - will be removed at end of development
void testMe();
