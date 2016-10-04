/*  C src backend for vbcc
*/

/* buil-time configurable options: */
#define SCHAR_REGS 64
#define UCHAR_REGS 64
#define SSHORT_REGS 64
#define USHORT_REGS 64
#define SINT_REGS 64
#define UINT_REGS 64
#define SLONG_REGS 64
#define ULONG_REGS 64
#define SLLONG_REGS 64
#define ULLONG_REGS 64
#define FLOAT_REGS 64
#define DOUBLE_REGS 64
#define LDOUBLE_REGS 64
#define POINTER_REGS 64

#include "dt.h"

/* internally used by the backend */
#define FIRST_SCHAR 1
#define LAST_SCHAR (FIRST_SCHAR+SCHAR_REGS)
#define FIRST_UCHAR (LAST_SCHAR+1)
#define LAST_UCHAR (FIRST_UCHAR+UCHAR_REGS)

#define FIRST_SSHORT (LAST_UCHAR+1)
#define LAST_SSHORT (FIRST_SSHORT+SSHORT_REGS)
#define FIRST_USHORT (LAST_SSHORT+1)
#define LAST_USHORT (FIRST_USHORT+USHORT_REGS)

#define FIRST_SINT (LAST_USHORT+1)
#define LAST_SINT (FIRST_SINT+SINT_REGS)
#define FIRST_UINT (LAST_SINT+1)
#define LAST_UINT (FIRST_UINT+UINT_REGS)

#define FIRST_SLONG (LAST_UINT+1)
#define LAST_SLONG (FIRST_SLONG+SLONG_REGS)
#define FIRST_ULONG (LAST_SLONG+1)
#define LAST_ULONG (FIRST_ULONG+ULONG_REGS)

#define FIRST_SLLONG (LAST_ULONG+1)
#define LAST_SLLONG (FIRST_SLLONG+SLLONG_REGS)
#define FIRST_ULLONG (LAST_SLLONG+1)
#define LAST_ULLONG (FIRST_ULLONG+ULLONG_REGS)

#define FIRST_FLOAT (LAST_ULLONG+1)
#define LAST_FLOAT (FIRST_FLOAT+FLOAT_REGS)

#define FIRST_DOUBLE (LAST_FLOAT+1)
#define LAST_DOUBLE (DOUBLE_FLOAT+DOUBLE_REGS)

#define FIRST_LDOUBLE (LAST_DOUBLE+1)
#define LAST_LDOUBLE (LDOUBLE_FLOAT+LDOUBLE_REGS)

#define FIRST_POINTER (LAST_LDOUBLE+1)
#define LAST_POINTER (POINTER_FLOAT+POINTER_REGS)


/*  This struct can be used to implement machine-specific           */
/*  addressing-modes.                                               */
/*  Currently possible are (const,gpr) and (gpr,gpr)                */
struct AddressingMode{
  int dummy;
};

/*  The number of registers of the target machine.                  */
#define MAXR LAST_POINTER

/*  Number of commandline-options the code-generator accepts.       */
#define MAXGF 20

/*  If this is set to zero vbcc will not generate ICs where the     */
/*  target operand is the same as the 2nd source operand.           */
/*  This can sometimes simplify the code-generator, but usually     */
/*  the code is better if the code-generator allows it.             */
#define USEQ2ASZ 1

/*  This specifies the smallest integer type that can be added to a */
/*  pointer.                                                        */
#define MINADDI2P CHAR

/*  If the bytes of an integer are ordered most significant byte    */
/*  byte first and then decreasing set BIGENDIAN to 1.              */
#define BIGENDIAN 1

/*  If the bytes of an integer are ordered lest significant byte    */
/*  byte first and then increasing set LITTLEENDIAN to 1.           */
#define LITTLEENDIAN 0

/*  Note that BIGENDIAN and LITTLEENDIAN are mutually exclusive.    */

/*  If switch-statements should be generated as a sequence of       */
/*  SUB,TST,BEQ ICs rather than COMPARE,BEQ ICs set this to 1.      */
/*  This can yield better code on some machines.                    */
#define SWITCHSUBS 0

/*  In optimizing compilation certain library memcpy/strcpy-calls   */
/*  with length known at compile-time will be inlined using an      */
/*  ASSIGN-IC if the size is less or equal to INLINEMEMCPY.         */
/*  The type used for the ASSIGN-IC will be UNSIGNED|CHAR.          */
#define INLINEMEMCPY 1024

/*  Parameters are sometimes passed in registers without __reg.     */
#define HAVE_REGPARMS 0

/*  Parameters on the stack should be pushed in order rather than   */
/*  in reverse order.                                               */
#define ORDERED_PUSH FIXED_SP

/* we only need the standard data types (no bit-types, different pointers
   etc.) */
#undef HAVE_EXT_TYPES
#undef HAVE_TGT_PRINTVAL

/* we do not need extra elements in the IC */
#undef HAVE_EXT_IC

/* we do not use unsigned int as size_t (but unsigned long, the default) */
#undef HAVE_INT_SIZET

/* we do not need register-pairs */
#undef HAVE_REGPAIRS

