
MEMORY
{
ram: org = 0x10000, l = 0x10000

}


SECTIONS
{
        .text : { *(.text) } > ram
        .dtors : { *(.dtors) } > ram
        .ctors : { *(.ctors) } > ram
	/* .data: { *(.data) } > ram AT> rom */
        .data : { *(.data) } > ram
	.bss: { *(.bss) } > ram


	/* for initialization of data 
        __DS = ADDR(.data);
	__DE = __NDS + SIZEOF(.data);
	__DI = LOADADDR(.data);
        */
	
	__BS = ADDR(.bss);
	__BE = ADDR(.bss) + SIZEOF(.bss);
	
}

