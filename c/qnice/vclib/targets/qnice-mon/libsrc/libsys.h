#define __mon_reset(x) ((__fp)0)(x)
#define __mon_getc(x) ((__fp)2)(x)
#define __mon_putc(x) ((__fp)4)(x)
#define __mon_exit(x) ((__fp)0x16)(x)


typedef int (*__fp)();
