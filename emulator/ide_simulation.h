#ifndef TRUE
# define TRUE 1
# define FALSE !TRUE
#endif


void writeIDEDeviceRegister(unsigned int address, unsigned int value);
unsigned int readIDEDeviceRegister(unsigned int address);
void initializeIDEDevice();

//For testing purposes only - will be removed at end of development
void testMe();

