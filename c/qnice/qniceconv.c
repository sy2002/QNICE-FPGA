#include <stdio.h>
#include <stdlib.h>

main(int argc,char **argv)
{
  int addr;

  if(argc!=2||sscanf(argv[1],"%i",&addr)!=1){
    fprintf(stderr,"usage: %s <addr>\n",argv[0]?argv[0]:"qnice_conv");
    exit(EXIT_FAILURE);
  }

  while(!feof(stdin)){
    int c;
    c = getchar()&0xff;
    c |= (getchar()&0xff)<<8;

    fprintf(stdout,"0x%04X 0x%04X\n",addr++,c);
  }
}
