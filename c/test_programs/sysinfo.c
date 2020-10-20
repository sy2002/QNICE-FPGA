/*  Dump SYS INFO
 *
 *  done by MJoergen in October 2020
*/

#include <stdio.h>

#include "qmon.h"
#include "sysdef.h"

// convenient mechanism to access QNICE's Memory Mapped IO registers
#define MMIO( __x ) *((unsigned int volatile *) __x )

unsigned int read_sysinfo(unsigned int addr)
{
   MMIO(IO_SYSINFO_ADDR) = addr;
   return MMIO(IO_SYSINFO_DATA);
}

static const char *get_hw_platform()
{
   switch (read_sysinfo(SYSINFO_HW_PLATFORM))
   {
      case SYSINFO_HW_EMU_CONSOLE  : return "Emulator (no VGA)";
      case SYSINFO_HW_EMU_VGA      : return "Emulator with VGA";
      case SYSINFO_HW_EMU_WASM     : return "Emulator on Web Assembly";
      case SYSINFO_HW_NEXYS        : return "Digilent Nexys board";
      case SYSINFO_HW_NEXYS_4DDR   : return "Digilent Nexys 4 DDR";
      case SYSINFO_HW_NEXYS_A7100T : return "Digilent Nexys A7-100T";
      case SYSINFO_HW_MEGA65       : return "MEGA65 board";
      case SYSINFO_HW_MEGA65_R2    : return "MEGA65 Revision 2";
      case SYSINFO_HW_MEGA65_R3    : return "MEGA65 Revision 3";
      case SYSINFO_HW_DE10NANO     : return "DE10 Nano board";
   }
   return "UNKNOWN";
} // get_hw_platform

static const char *get_version()
{
   static char str[8];
   unsigned int version = read_sysinfo(SYSINFO_VERSION);
   snprintf(str, 8, "%u.%u%u", version>>8, (version>>4) & 0xf, version & 0xf);
   return str;
} // get_version

int main()
{
   printf("Hardware platform:  %s\n", get_hw_platform());
   printf("CPU speed:          %u MHz\n", read_sysinfo(SYSINFO_CPU_SPEED));
   printf("CPU register banks: %u\n", read_sysinfo(SYSINFO_CPU_BANKS));
   printf("RAM start address:  0x%04x\n", read_sysinfo(SYSINFO_RAM_START));
   printf("RAM size:           %u kw\n", read_sysinfo(SYSINFO_RAM_SIZE));
   printf("GPU sprites:        %u\n", read_sysinfo(SYSINFO_GPU_SPRITES));
   printf("GPU screen lines:   %u\n", read_sysinfo(SYSINFO_GPU_LINES));
   printf("UART max baudrate:  %u kb/s\n", read_sysinfo(SYSINFO_UART_MAX));
   printf("QNICE version:      %s\n", get_version());
   printf("MMU present:        %s\n", read_sysinfo(SYSINFO_CAP_MMU) ? "Yes" : "No");
   printf("EAE present:        %s\n", read_sysinfo(SYSINFO_CAP_EAE) ? "Yes" : "No");
   printf("FPU present:        %s\n", read_sysinfo(SYSINFO_CAP_FPU) ? "Yes" : "No");
   printf("GPU present:        %s\n", read_sysinfo(SYSINFO_CAP_GPU) ? "Yes" : "No");
   printf("Keyboard present:   %s\n", read_sysinfo(SYSINFO_CAP_KBD) ? "Yes" : "No");
   return 0;
}


