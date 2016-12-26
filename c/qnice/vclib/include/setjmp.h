
#ifndef __SETJMP_H
#define __SETJMP_H 1

#error setjmp.h has to be overridden by a machine-specific version!

typedef int jmp_buf[<fill in as needed>];

int setjmp (jmp_buf);
void longjmp (jmp_buf, int);

#endif

