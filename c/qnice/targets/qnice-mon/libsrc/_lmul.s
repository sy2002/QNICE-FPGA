# Wrapper for Monitor's MTH$MULU32 function to be used by VBCC
# when performing 32bit to 32bit multiplications
# done by sy2002 in November 2016

    .text
    .global ___mulint32

___mulint32:

    MOVE    @R13++, R10
    MOVE    @R13, R11
    SUB     1, R13
    ASUB    0x0032, 1
    MOVE    @R13++, R15

    .type   ___mulint32, @function
    .size   ___mulint32, $-___mulint32
    .global ___mulint32
