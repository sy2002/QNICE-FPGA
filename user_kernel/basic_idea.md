#define LIBCALL(x, y)   RSUB x, y
#define SYSCALL(x)      INT x

User mode:
        INT SYSMULU or shorter SYSCALL(SYSMUL)
        ...

SYSMULU RSUB MULU
        RTI

Kernel mode:
        RSUB MULU
        ...

MULU    DO_SOMETHING_COOL
        ...
        RET
