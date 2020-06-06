/*
    MEGA65 bitstream to core file converter v0.0.1
    done by Paul Gardner-Stephen in 2019 and 2020

    How to compile: <compiler> bit2core.c -O3 -o bit2core
    Tested to work with cc and gcc.

    Use this tool to convert a .bit bitstream made by Vivado or ISE into
    a .cor file that you can use as an alternate MEGA65 core:

    Hold the NO SCROLL key on the MEGA65 while powering it on to enter the
    Cores menu. There you can flash a .cor file from the SD card to the
    MEGA65's core Flash Memory. From then on, you can select the core
    when powering on the MEGA65 while holding the NO SCROLL key.

    Important: You need the following Vivado bitstream settings to use a
    .bit file as an input for this tool:

    set_property CONFIG_VOLTAGE 3.3 [current_design]
    set_property CFGBVS VCCO [current_design]
    set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
    set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
    set_property CONFIG_MODE SPIx4 [current_design]
    set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
    set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

    The file hw/xilinx/MEGA65/Vivado/mega65.xdc already contains these
    settings. 

    The ISE equivalent of these settings is already configured in
    the project file hw/xilinx/MEGA65/ISE/QNICE-MEGA65.xise

    Taken by sy2002 in June 2020 from:
    https://github.com/MEGA65/mega65-core/blob/a100863955f5feb67949f872cbb112d81aa7ce1e/src/tools/bit2core.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>

unsigned char bitstream[4*1048576];

int main(int argc,char **argv)
{
  if (argc!=5) {
    fprintf(stderr,"MEGA65 bitstream to core file converter v0.0.1.\n");
    fprintf(stderr,"usage: <foo.bit> <core name> <core version> <out.cor>\n");
    exit(-1);
  }

  FILE *bf=fopen(argv[1],"rb");
  if (!bf) {
    fprintf(stderr,"ERROR: Could not read bitstream file '%s'\n",argv[1]);
    exit(-3);
  }
  int bit_size=fread(bitstream,1,4*1048576,bf);
  fclose(bf);

  printf("Bitstream file is %d bytes long.\n",bit_size);
  if (bit_size<1024||bit_size>(4*1048576-4096)) {
    fprintf(stderr,"ERROR: Bitstream file must be >1K and no bigger than (4MB - 4K)\n");
    exit(-2);
  }

  FILE *of=fopen(argv[4],"wb");
  if (!of) {
    fprintf(stderr,"ERROR: Could not create core file '%s'\n",argv[4]);
    exit(-3);
  }
  // Write magic bytes
  fprintf(of,"MEGA65BITSTREAM0");
  // Write core file name and version
  char header_block[4096-16];
  bzero(header_block,4096-16);
  for(int i=0;(i<32)&&argv[2][i];i++) header_block[i]=argv[2][i];
  for(int i=0;(i<32)&&argv[3][i];i++) header_block[32+i]=argv[3][i];
  fwrite(header_block,4096-16,1,of);
  fwrite(&bitstream[120],bit_size-120,1,of);
  fclose(of);

  printf("Core file written.\n");
  return 0;
} 
