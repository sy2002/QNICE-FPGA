/* This programm emulates an IDE controller of a compact flash card (cf) in True IDE mode.
*
* Following restrictions apply to this simulation:
* ---	The simulation doesn't care about the mapping between the I/O IDE registers in the hosts main memory
*	and his internal registers (in other words the physical connection). The I/O registers of the host are
*	not used. A read or write to the hosts registers results in a direct read or write of the internal drive 
*	registers. The signal management nessecary to provide this in reality is ignored.
*---	A IDE controller can have more than one device attached. 
*	The device selection is done by setting the DEV bit (bit 4) of the SDH_REGISTER. Anyway the registers are 
*   	always written to any attached drive. The drives embbeded controller then decides wether to take action or 
*   	not. The DEV bit is expected to be set to 0 and is further ignored. It is always assumed that device0 
*	should execute the given commands.
*---	The Simulator does not support Power Management Features: The device is always expected to be powered up. 
*	Other modes like Sleep Mode are not supported. The power up itself, which does a lot of things like 
*	internal diagnostic, is not simulated either. Only the register initialization must be done by calling 
*	initializeIDEDevice() once. The qnice simulator should do this before interpreting any assembler code.
*---	Only a small subset of the possible and partly required (at least by the cf or ATA specification) 
*	commands are supported:
* 		Read Sector(s)
*       Read Verify
* 		Request Sense
*		Write Sector(s) 
*       Write Verify 
*---	The BSY bit is set like in a real drive although you can never verify that in assembler: when the next 
*	assembler directive is interpreted the BSY bit has been reset to zero (we would need multithreading to
*	implement it otherwise). Anyway the BSY bit should always been checked in the assembler code because with
*	a real drive it may take some time until a command is executed or aborted and the BSY bit is reseted to 0.
*---	Currently only CHS addressing is supported even though according to cf spec LBA should be supported too. 
* @Author: Kai Lutterbeck
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "ide_simulation.h"

#undef DEBUG

/*	A 32MB Compact Flash Card (CF) is defined because available memory is limited.
*   The numbers for CHS are from the SanDisc CF specifiction. CFs from other vendors may 
*   have a diffrent partitioning. */
#define NO_OF_CYLINDERS                	490
#define NO_OF_HEADS                       4
#define NO_OF_SECTORS                    32
#define NO_OF_BYTES_PER_SECTOR    		512
#define MAX_SECTORS_PER_ACCESS			256

//All registers are 8bit long except the data register which is 16bit long.
#define NO_OF_INTERNAL_IDE_REGISTERS 	12
#define DATA_REGISTER         	         0 //this is the only 16bit register
#define ERROR_REGISTER         	         1
#define FEATURES_REGISTER         	 	 2
#define SECTOR_COUNT_REGISTER          	 3
#define SECTOR_NUMBER_REGISTER         	 4
#define CYLINDER_LOW_REGISTER         	 5
#define CYLINDER_HIGH_REGISTER         	 6
#define SDH_REGISTER         	         7  //"Sector Size, Drive, Head Register" aka "Device/Head Register"
#define STATUS_REGISTER         	     8
#define COMMAND_REGISTER         	 	 9
#define ALTERNATE_STATUS_REGISTER   	10
#define DEVICE_CONTROL_REGISTER       	11

#define READ_MODE   TRUE
#define WRITE_MODE  FALSE
/*All information in the ide_device struct are specific for one device.*/
typedef struct ide_device
{
	int device[NO_OF_CYLINDERS][NO_OF_HEADS][NO_OF_SECTORS][NO_OF_BYTES_PER_SECTOR],
		registers[NO_OF_INTERNAL_IDE_REGISTERS], 
		buffer[NO_OF_BYTES_PER_SECTOR],
		current_cylinder,
		current_head,
		current_sector,
		no_sectors_to_access,
		sector_count, 
		pio_datain_in_progress,
		pio_dataout_in_progress,
		no_of_bytes_transfered,
		buffer_filled,
		extended_error_code;
} ide_device;

ide_device gbl$device0;


void writeRegister(unsigned int address, unsigned int value);
void writeDataRegister(unsigned int value);
unsigned int readRegister(unsigned int address);
unsigned int readDataRegister();

void executeCommand();
void handleReadWriteSectors(int isReadMode, int isVerifyOnly); 
void verifyReadSectors();
void prepareNextSectorForPIO(int isReadMode, int isVerifyOnly);




/* Just writes the value to the register. Ensures register size (8 or 16 bits) 
 * and validity of array position. */
void writeRegister(unsigned int address, unsigned int value) 
{
	if (address == DATA_REGISTER)  	/*Data register is 16 bits long */
		value &= 0xffff;  				
	else 							/*All other registers are 8 bits long */
		value &= 0xff;				
	
	if (address < NO_OF_INTERNAL_IDE_REGISTERS) {
		gbl$device0.registers[address] = value;
	} else {
		printf("writeRegister: Illegal address during write: %x!\n Internal register array out of bound.\n",
		 address);
		exit(-1);
	}	
}


/* Just reads the value from the register. Ensures register size (8 or 16 bits) 
 * and validity of array position. */
unsigned int readRegister(unsigned int address) 
{
	unsigned int returnValue;
	if (address < NO_OF_INTERNAL_IDE_REGISTERS) {
		returnValue = gbl$device0.registers[address];
	} else {
		printf("readRegister: Illegal address during read: %x!\n Internal register array out of bound.\n",
		 address);
		exit(-1);
	}	
	//is paranoia epidemic?
	if (address == DATA_REGISTER)  	/*Data register is 16 bits long */
		returnValue &= 0xffff;  				
	else 							/*All other registers are 8 bits long */
		returnValue &= 0xff;
	
	return returnValue;			
}


/* Selects the correct register to write to from the hosts I/O register address
 * The result of writing to the
 * Command register while the BSY bit is equal to one or the DRQ bit is equal to one is unpredictable and may
 * result in data corruption. Writes to other command block registers are ignored by the device when BSY is set 
 * except for writing the reset flag to the Device Control Register, which immediately results in a software reset.
 */
void writeIDEDeviceRegister(unsigned int address, unsigned int value) 
{
	/*write access is ignored except for the Device Control Register when BSY is set 
	    (although this can never happen in non multithreaded simulation) */
	if ( (!(readRegister(STATUS_REGISTER) & 0x80)) || address == 8) {
#ifdef DEBUG
		printf("writeIDEDeviceRegister: write to register '%X' with value '%X' requested.\n", address, value);
#endif
		switch(address)
		{
			case 0: 
				writeDataRegister(value);
				break;
			case 1: 
				writeRegister(FEATURES_REGISTER,value);
				break;         	         
			case 2: 
				writeRegister(SECTOR_COUNT_REGISTER,value);
				break;           	 
			case 3: 
				writeRegister(SECTOR_NUMBER_REGISTER,value);
				break;            
			case 4: 
				writeRegister(CYLINDER_LOW_REGISTER,value);
				break;          
			case 5: 
				writeRegister(CYLINDER_HIGH_REGISTER,value);
				break;           	 
			case 6: 
				writeRegister(SDH_REGISTER,value | 0xA0); // bit 5 and 7 must always be set 
				break;           	 
			case 7: 
				writeRegister(COMMAND_REGISTER,value);
				executeCommand ();
				break;           	         
			case 8: 
				writeRegister(DEVICE_CONTROL_REGISTER,value);
				//software reset immediately results after writing reset flag to the Device Control Register
				if (readRegister(DEVICE_CONTROL_REGISTER) & 0x04) {
				  initializeIDEDevice();	
				}
				break;           	               	               	    
			default:
				printf("writeIDEDeviceRegister: Illegal register access in write mode at address: %x!\n", address);
				exit(-1);
		}
	} else {
#ifdef DEBUG
		printf("writeIDEDeviceRegister: write to register '%X' with value '%X' ignored because drive is busy.\n", 
			address, value);
#endif
	}
}

/* Selects the correct register to read from according to the hosts I/O register read */
unsigned int readIDEDeviceRegister(unsigned int address) {
	unsigned int returnCode;
#ifdef DEBUG
	printf("readIDEDeviceRegister: read of register '%X' requested.\n", address);
#endif
	switch(address)
	{
		case 0: 
			returnCode = readDataRegister();
			break;
		case 1: 
			returnCode = readRegister(ERROR_REGISTER);
			break;         	         
		case 2: 
			returnCode = readRegister(SECTOR_COUNT_REGISTER);
			break;           	 
		case 3: 
			returnCode = readRegister(SECTOR_NUMBER_REGISTER);
			break;            
		case 4: 
			returnCode = readRegister(CYLINDER_LOW_REGISTER);
			break;          
		case 5: 
			returnCode = readRegister(CYLINDER_HIGH_REGISTER);
			break;           	 
		case 6: 
			returnCode = readRegister(SDH_REGISTER);
			break;           	 
		case 7: 
			returnCode = readRegister(STATUS_REGISTER);
			break;           	         
		case 8: 
			returnCode = readRegister(ALTERNATE_STATUS_REGISTER);
			break;            	               	      
		default:
			printf("readIDEDeviceRegister: Illegal register access in read mode at address: %x!\n", address);
			exit(-1);
	    }
#ifdef DEBUG
	printf("readIDEDeviceRegister: read from register '%X' returns value '%X'.\n", address, returnCode);	
#endif
	return returnCode;
}

/* Executes the command written to the COMMAND_REGISTER */
void executeCommand () 
{
#ifdef DEBUG
	printf("Execution of command '%X' requested.\n",readRegister(COMMAND_REGISTER));
#endif
		
	//each command sets the drive status to busy as long as DRQ is not set
	if (!(readRegister(STATUS_REGISTER) & 0x08))
	{
		//Setting BSY (Bit 7) - No other bits in this register are valid when this bit is set.
		writeRegister(STATUS_REGISTER, readRegister(STATUS_REGISTER) | 0x80);   
		//Setting BSY(Bit 7) - No other bits in this register are valid when this bit is set.
		writeRegister(ALTERNATE_STATUS_REGISTER, readRegister(ALTERNATE_STATUS_REGISTER) | 0x80);  
	}
	
	switch(readRegister(COMMAND_REGISTER))
	{
		case 0x03: 
			/* 	Request sense - cf specific command ... but maybe helpful. 
			*	Request sense is not part of the ATA-3 specification and is not supported by IDE hard disks. 
			*	It is part the CFA Feature Set //(CFA = The CompactFlash Association that created the 
			*	specification for compact flash memory that uses the ATA interface) that was first mentioned 
			*	and integrated in the ATA-4 specification. It returns an extended error code for the last 
			*	issued command in the error register. Request sense can be called multiple times and will 
			*	always return the extended error code of the last issued command that was not request sense
			*	command itself */
			
			//Setting the extended error code
			writeRegister(ERROR_REGISTER, gbl$device0.extended_error_code); 
			//Setting DRDY and DSC and clearing BSY 
			writeRegister(STATUS_REGISTER, 0x50);   
			writeRegister(ALTERNATE_STATUS_REGISTER, 0x50); 
			break;
		case 0x20: //Read Sector(s) with retries
			//Executed the same way as 0x21, because we wan't have any trouble with invalid sectors :-)
			handleReadWriteSectors(READ_MODE, FALSE);
			break;
		case 0x21: //Read Sector(s) without retries
			handleReadWriteSectors(READ_MODE, FALSE);
			break;    
		case 0x30: //Write Sector(s) with retries
			//Executed the same way as 0x31, because we wan't have any trouble with invalid sectors :-)
			handleReadWriteSectors(WRITE_MODE, FALSE);
			break;
		case 0x31: //Write Sector(s) without retries
			handleReadWriteSectors(WRITE_MODE, FALSE);
			break; 
		case 0x40: //Read Verify Sector(s) with retries
			//Executed the same way as 0x41, because we wan't have any trouble with invalid sectors :-)
			handleReadWriteSectors(READ_MODE, TRUE);
			break;
		case 0x41: //Read Verify Sector(s) without retries
            /* This command is identical to the Read Sectors command, except that DRQ is never set and no
            *  data is transferred to the host. See method verifySectors for more information.
            */            
			handleReadWriteSectors(READ_MODE, TRUE);
			break; 
 		case 0x3C: //Write Verify
            /* This command is similar to the Write Sector(s) command, except each sector is verified
             * immediately after being written. This command has the same protocol as the Write Sector(s)
             * command. So we can execute is the same way as 0x31 because write errors can't happen in simulation.
             */            
			handleReadWriteSectors(WRITE_MODE, FALSE);
			break; 		
		default:
#ifdef DEBUG
			printf("executeCommand: Unknown or unimplemented command: %x!\n", readRegister(COMMAND_REGISTER));
#endif
			//Setting ABRT (Command aborted)
			writeRegister(ERROR_REGISTER, 0x04); 
			//Extended error code: invalid command
			gbl$device0.extended_error_code=0x20;  
			//Setting DRDY, DSC and ERR and clearing BSY
			writeRegister(STATUS_REGISTER, 0x51);    
			writeRegister(ALTERNATE_STATUS_REGISTER, 0x51);  
	}
}


void handleReadWriteSectors(int isReadMode, int isVerifyOnly) {
	int error = FALSE;
	/*	reset error register - it still may contain extended error codes or flags from 
		last command execution. */
	writeRegister(ERROR_REGISTER, 0x00);
	
	/*check addressing mode  - only CHS is supported 
	  We have to exit here because a controller should support both modes and for this reason 
	  no error code or behavior is defined
	*/
	if ((readRegister(SDH_REGISTER) & 0x40))  { 
		//LBA (bit 6) is set.
		printf("LBA addressing is currently not supported!\n");
		exit(-1);
	}
	
	//begin determine parameters
	
	//determine starting cylinder 
	gbl$device0.current_cylinder = 
		(readRegister(CYLINDER_HIGH_REGISTER)<<8) 
		| readRegister(CYLINDER_LOW_REGISTER);
	
	//determine starting head - lower 4 bits of SDH Register
	gbl$device0.current_head = readRegister(SDH_REGISTER) & 0xf;
	
	//determine starting sector
	gbl$device0.current_sector = readRegister(SECTOR_NUMBER_REGISTER);
	
	//determine numbers of sectors to read or write
	gbl$device0.no_sectors_to_access = readRegister(SECTOR_COUNT_REGISTER);
		//Zero in sector count means maximum block read or write
	if (gbl$device0.no_sectors_to_access == 0) 
		gbl$device0.no_sectors_to_access = MAX_SECTORS_PER_ACCESS;
	//end determine parameterss
#ifdef DEBUG
	printf("handleReadWriteSectors: Parameters found:\nCylinder: %i\nHead: %i\nSector: %i\n", 
		gbl$device0.current_cylinder, gbl$device0.current_head, gbl$device0.current_sector);
#endif
	//check if parameters are valid
	if ( gbl$device0.current_cylinder == 0 || gbl$device0.current_cylinder > NO_OF_CYLINDERS ||
		 gbl$device0.current_head == 0 || gbl$device0.current_head > NO_OF_HEADS ||
		 gbl$device0.current_sector == 0 || gbl$device0.current_sector > NO_OF_SECTORS) {
#ifdef DEBUG
			printf("handleReadWriteSectors: Invalid parameter(s):\nCylinder: %x\nHead: %x\nSector: %x\n", 
				gbl$device0.current_cylinder, gbl$device0.current_head, gbl$device0.current_sector);
#endif
			//Setting ABRT (Command aborted)
			writeRegister(ERROR_REGISTER, 0x04); 
			//Extended error code: invalid address
			gbl$device0.extended_error_code=0x21;  
			//Setting DRDY, DSC and ERR and clearing BSY
			writeRegister(STATUS_REGISTER, 0x51);    
			writeRegister(ALTERNATE_STATUS_REGISTER, 0x51);  
			error = TRUE;	
	}
	
	if (! error) {
        if (isReadMode) {
            if (isVerifyOnly) {
                verifyReadSectors();
            } else {
                gbl$device0.pio_datain_in_progress=TRUE;
                gbl$device0.pio_dataout_in_progress=FALSE;
                gbl$device0.sector_count=0;
                prepareNextSectorForPIO(READ_MODE,FALSE);
            }
            
        } else {
            gbl$device0.pio_datain_in_progress=FALSE;
            gbl$device0.pio_dataout_in_progress=TRUE;
            gbl$device0.sector_count=0;
            prepareNextSectorForPIO(WRITE_MODE,FALSE);
        }
	}
}

/*Prepares the next sector for pio if there is one or finshes command excecution*/
void prepareNextSectorForPIO(int isReadMode, int isVerifyOnly) {
	if (gbl$device0.sector_count<gbl$device0.no_sectors_to_access) {
		int error = FALSE;
		
		//set BSY bit and clear DRQ. When this method is called by handleReadWriteSectors this step is redundant.
		writeRegister(STATUS_REGISTER, 0x80);
		
		//when not the start sector is transfered we have to increase current sector
		if (gbl$device0.sector_count > 0) { 
			//check if increasing the sector would cross a head boundary  
			if ((gbl$device0.current_sector + 1) > NO_OF_SECTORS){
				//setting sector to first sector of the new head
				gbl$device0.current_sector = 1;
				//check if increasing the head would cross a cylinder boundary
				if ((gbl$device0.current_head + 1) > NO_OF_HEADS){
					//go to the first head of the next cylinder
					gbl$device0.current_head = 1;
					gbl$device0.current_cylinder++;
					//if going to the next cylinder reaches end of disk read must be aborted!
					if (gbl$device0.current_cylinder > NO_OF_CYLINDERS) {
#ifdef DEBUG
						printf("prepareNextSectorForPIO: Invalid address:\nCylinder: %x\nHead: %x\nSector: %x\n", 
							gbl$device0.current_cylinder, gbl$device0.current_head, 
							gbl$device0.current_sector);
#endif
						//Setting ABRT (Command aborted)
						writeRegister(ERROR_REGISTER, 0x04); 
						//in this case CHS-Registers should contain the address the access error occured at
						writeRegister(SDH_REGISTER, (gbl$device0.current_head & 0xf) |
													  (readRegister(SDH_REGISTER) & 0xf0));
						writeRegister(SECTOR_NUMBER_REGISTER, gbl$device0.current_sector & 0xff);
						writeRegister(CYLINDER_HIGH_REGISTER, (gbl$device0.current_cylinder >> 8) & 0xff);
						writeRegister(CYLINDER_LOW_REGISTER, gbl$device0.current_cylinder & 0x00ff);
						//Extended error code: invalid address
						gbl$device0.extended_error_code=0x21;  
						//Setting DRDY, DSC and ERR and clearing BSY
						writeRegister(STATUS_REGISTER, 0x51);    
						writeRegister(ALTERNATE_STATUS_REGISTER, 0x51);  
						error = TRUE;	
					}
				} else {
					gbl$device0.current_head++;
				}
			} else {
				gbl$device0.current_sector++;
			}			
		} //end of increasing sector
		
		if (! error) {
			if (isReadMode) {
			    //fill read buffer with next sector
				int i;
				for (i=0; i<NO_OF_BYTES_PER_SECTOR; i++) {
					gbl$device0.buffer[i] = 
						gbl$device0.device[gbl$device0.current_cylinder-1][gbl$device0.current_head-1]
						[gbl$device0.current_sector-1][i];
				}
				gbl$device0.no_of_bytes_transfered=0;
				gbl$device0.buffer_filled=TRUE;
			} else {
				//clear buffer
				int i;
				for (i=0; i<NO_OF_BYTES_PER_SECTOR; i++) {
					gbl$device0.buffer[i] = 0;
				}
				gbl$device0.no_of_bytes_transfered=0;
			}
			if (! isVerifyOnly) {
                //signal for host to start data transfer
                writeRegister(STATUS_REGISTER, 0x08);
                writeRegister(ALTERNATE_STATUS_REGISTER, 0x08);
            }
		}
	} else {
		//All sectors have been transfered. End of read or write command execution.
		gbl$device0.extended_error_code=0x00;
		gbl$device0.buffer_filled=FALSE;
		gbl$device0.pio_datain_in_progress=FALSE;
		gbl$device0.pio_dataout_in_progress=FALSE;
		
		//At end of command CHS-Registers should contain the address of the last sector read or written
		writeRegister(SDH_REGISTER, (gbl$device0.current_head & 0xf) |
									  (readRegister(SDH_REGISTER) & 0xf0));
		writeRegister(SECTOR_NUMBER_REGISTER, gbl$device0.current_sector & 0xff);
		writeRegister(CYLINDER_HIGH_REGISTER, (gbl$device0.current_cylinder >> 8) & 0xff);
		writeRegister(CYLINDER_LOW_REGISTER, gbl$device0.current_cylinder & 0x00ff);
		writeRegister(STATUS_REGISTER, 0x50);  
		writeRegister(ALTERNATE_STATUS_REGISTER, 0x50);
	}
}


unsigned int readDataRegister(){
	unsigned int returnCode;
	if (! gbl$device0.pio_datain_in_progress) {
		returnCode = readRegister(DATA_REGISTER);
	} else {
		//expecting 256 reads in a row. 
		if (gbl$device0.no_of_bytes_transfered < NO_OF_BYTES_PER_SECTOR && gbl$device0.buffer_filled) {
			//write bytes to the Data Register before read.
			writeRegister(DATA_REGISTER, (gbl$device0.buffer[gbl$device0.no_of_bytes_transfered+1]<<8) 
											| gbl$device0.buffer[gbl$device0.no_of_bytes_transfered]);
			returnCode = readRegister(DATA_REGISTER);
			//prepare for next read
			gbl$device0.no_of_bytes_transfered += 2;
#ifdef DEBUG
			printf("readDataRegister: Bytes transfered: %i\n", gbl$device0.no_of_bytes_transfered);	
#endif
			//check if last two bytes of the sector were transfered
			if (gbl$device0.no_of_bytes_transfered==NO_OF_BYTES_PER_SECTOR)	{
				//prepare next sector
				gbl$device0.sector_count+=1;
				prepareNextSectorForPIO(READ_MODE, FALSE);
			}					
		} else {
			//should never happen
			printf("readDataRegister: unexpected branch!\n");
			exit(-1);
		}
	}	
	return returnCode;
}

void writeDataRegister(unsigned int value){
	if (! gbl$device0.pio_dataout_in_progress) {
		writeRegister(DATA_REGISTER,value);
	} else {
		//expecting 256 writes in a row. 
		if (gbl$device0.no_of_bytes_transfered < NO_OF_BYTES_PER_SECTOR) {
			//write bytes to the buffer
			gbl$device0.buffer[gbl$device0.no_of_bytes_transfered]=value & 0xff;
			gbl$device0.buffer[gbl$device0.no_of_bytes_transfered+1]= (value >> 8) & 0xff;
			//prepare for next write
			gbl$device0.no_of_bytes_transfered += 2;
#ifdef DEBUG
			printf("writeDataRegister: Bytes transfered: %i\n", gbl$device0.no_of_bytes_transfered);
#endif
			//check if last two bytes of the sector were transfered
			if (gbl$device0.no_of_bytes_transfered==NO_OF_BYTES_PER_SECTOR)	{
				//write buffer to sector
				int i;
				for (i=0; i<NO_OF_BYTES_PER_SECTOR; i++) {
					gbl$device0.device[gbl$device0.current_cylinder-1][gbl$device0.current_head-1]
						[gbl$device0.current_sector-1][i] = gbl$device0.buffer[i];
				}
				//prepare next sector for write
				gbl$device0.sector_count+=1;
				prepareNextSectorForPIO(WRITE_MODE, FALSE);
			}					
		} else {
			//should never happen
			printf("readDataRegister: unexpected branch!\n");
			exit(-1);
		}
	}
} 


//Initializes the ide device to indicate a ready device (simulates power on or reset of ide device)
void initializeIDEDevice() {	
		gbl$device0.extended_error_code=0x00;  //extended error code: no error detected
		gbl$device0.buffer_filled=FALSE;
		gbl$device0.pio_datain_in_progress=FALSE;
		gbl$device0.pio_dataout_in_progress=FALSE;
		int i;
		for (i=0; i<NO_OF_BYTES_PER_SECTOR; i++) {
			gbl$device0.buffer[i] = 0;
		}
		gbl$device0.current_cylinder=0;
		gbl$device0.current_head=0;
		gbl$device0.current_sector=0;
		gbl$device0.no_sectors_to_access=0;
		gbl$device0.sector_count=0; 
		gbl$device0.no_of_bytes_transfered=0;

		//Reset registers
		writeRegister(DATA_REGISTER, 0x0000);
		writeRegister(ERROR_REGISTER, 0x00);
		writeRegister(FEATURES_REGISTER, 0x00);
		writeRegister(SECTOR_COUNT_REGISTER, 0x00);
		writeRegister(SECTOR_NUMBER_REGISTER, 0x00);
		writeRegister(CYLINDER_LOW_REGISTER, 0x00);
		writeRegister(CYLINDER_HIGH_REGISTER, 0x00);
		writeRegister(COMMAND_REGISTER, 0x00);
	
		//	Bits 7 and 5 of the SDH_REGISTER are always set due to backward compatibility reasons
		writeRegister(SDH_REGISTER, 0xA0);   
		
		/*	Bit 6 (DRDY) of the STATUS_REGISTER is set to indicate that drive is ready for command execution. 
		*	According to the cf standard bit 4 is set when a cf card is ready (drive seek complete flag in 
		*	ATA specification) 	*/
		writeRegister(STATUS_REGISTER, 0x50);  
		
		writeRegister(COMMAND_REGISTER, 0x00);
		
		// 	see STATUS_REGISTER for settings of ALTERNATE_STATUS_REGISTER
		writeRegister(ALTERNATE_STATUS_REGISTER, 0x50);
		
		/* 	Only bits 1 and 2 of the DEVICE_CONTROL_REGISTER are used in the cf specification. 
		*	If bit 2 is set, interrupts are disabled. Because we do not want to use interrupts 
		*	the bit is preallocated.
		*	If bit 1 is written the cf card is reseted. All other bits are always zero anyway. 	*/
		writeRegister(DEVICE_CONTROL_REGISTER, 0x02);		
}


/* 
*  When the requested sectors have been verified, the cf clears BSY. Upon command completion, the Command Block Registers contain the
*  cylinder, head, and sector number of the last sector verified.
*  If an error occurs, the Read Verify Command terminates at the sector where the error occurs. The
*  Command Block Registers contain the cylinder, head and sector number of the sector where the
*  error occurred. The Sector Count Register contains the number of sectors not yet verified.
*/
void verifyReadSectors() {
    //repeat until all sectors have been checked or command is finished or aborted. In the last two cases, the BSY won't be set anymore.
    do {
        prepareNextSectorForPIO(READ_MODE, TRUE);
        gbl$device0.sector_count+=1;
    }while ( gbl$device0.sector_count <= gbl$device0.no_sectors_to_access && 
                (readRegister(STATUS_REGISTER) & 0x80) > 0) ;
    
    /* If an error occured the number of unverified sectors have to be written to the Sector Count Register
     * All other register have been filled correctly by error handling of the prepareNextSectorForPIO method. 
     * If no error occured all registers and the BSY flag have been set correctly by the prepareNextSectorForPIO method.
    */
    if ((readRegister(STATUS_REGISTER) & 0x01) != 0) {
        int unverifiedSectors = gbl$device0.no_sectors_to_access - gbl$device0.sector_count;
#ifdef DEBUG
	printf("verifySectors: An access error has been detected during verify sectors at sector: %i\n%i sectors remain unverified:\n",
                gbl$device0.sector_count, unverifiedSectors);
#endif
        
        //transform 256 unverified sectors to zero
        if (unverifiedSectors==MAX_SECTORS_PER_ACCESS)
             unverifiedSectors=0x00;   
        
        writeRegister(SECTOR_COUNT_REGISTER, unverifiedSectors & 0xff);        
    }
    
}

/* 
*  For testing purposes only - will be removed at end of development
* Test to read two sectors from the device and check Status Register conditions*/
void testMe() {	
    //Test write verify
    writeIDEDeviceRegister(6,0xA2);
	writeIDEDeviceRegister(5,0x00);
	writeIDEDeviceRegister(4,0x80);
	writeIDEDeviceRegister(3,0x02);
	writeIDEDeviceRegister(2,0x02);
	writeIDEDeviceRegister(7,0x41);
    if (readIDEDeviceRegister(7) == 0x50) {
			printf("\nRead Verify Command successful completed!\n");
    }
    
    
	int i;
	// writes two sectors starting from  Cylinder:128, Head:2, Sector:2
	writeIDEDeviceRegister(6,0xA2);
	writeIDEDeviceRegister(5,0x00);
	writeIDEDeviceRegister(4,0x80);
	writeIDEDeviceRegister(3,0x02);
	writeIDEDeviceRegister(2,0x02);
	writeIDEDeviceRegister(7,0x31);
	
	
	if ((readIDEDeviceRegister(7)& 0x08) > 0) {
		printf("Ready for write!\n");
		writeIDEDeviceRegister(0,('e' << 8) | 'T');
		writeIDEDeviceRegister(0,('t' << 8) | 's');
		for (i=0;i<254;i++){
			writeIDEDeviceRegister(0,0x0000);
		}
		if ((readIDEDeviceRegister(7)& 0x08) > 0)
			printf("Still ready for write!\n");
		writeIDEDeviceRegister(0,('e' << 8) | 'M');
		int i;
		for (i=0;i<255;i++){
			writeIDEDeviceRegister(0,0x0000);
		}
	}
	
	
	
	// reads two sectors starting from  Cylinder:128, Head:2, Sector:2
	
	writeIDEDeviceRegister(6,0xA2);
	writeIDEDeviceRegister(5,0x00);
	writeIDEDeviceRegister(4,0x80);
	writeIDEDeviceRegister(3,0x02);
	writeIDEDeviceRegister(2,0x02);
	writeIDEDeviceRegister(7,0x21);
	
	if ((readIDEDeviceRegister(7)& 0x08) > 0) {
		printf("Ready for read!\n");
		int sec[512], sec2[512];
		for (i=0; i<256; i++) {
			int x = readIDEDeviceRegister(0);
			sec [i*2] = x & 0xff;
			sec [(i * 2) + 1] = (x >> 8) & 0xff;
		}
		for (i=0; i<256; i++) {
			int x = readIDEDeviceRegister(0);
			sec2[i*2] = x & 0xff;
			sec2[(i * 2) + 1] = (x >> 8) & 0xff;
		}
		if (readIDEDeviceRegister(7) == 0x50) {
			printf("\nRead Command successful completed!\n");
			printf("Read from IDE-Device: %c%c%c%c %c%c\n",sec[0],sec[1],sec[2],sec[3],sec2[0],sec[1]);
			printf("Test %i and %i should be 0\n",sec[4],sec[511]);
		} else {
			printf("Read Command successful completed!\n");
		}
	} else {
		printf("Something is wrong!\n");
	}
}

