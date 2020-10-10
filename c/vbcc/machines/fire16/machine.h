/* 
 * Backend for the Fire16 iCE40 SoftCore
 * (c) 2019 by Sylvain Munaut
 */

#include "dt.h"


/*  This struct can be used to implement machine-specific           */
/*  addressing-modes.                                               */
struct AddressingMode {
	int not_used_yet;	// FIXME
};

/*  The number of registers of the target machine.                  */
	/* - 16 rN GPR + 8 pairs
	 * - 16 sN GPR + 8 pairs
	 * - A, X, Y, I
	 */
#define MAXR 52

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

/*  This specifies the smallest integer type that can be added to a */
/*  pointer.                                                        */
#define MAXADDI2P INT

/*  If the bytes of an integer are ordered most significant byte    */
/*  byte first and then decreasing set BIGENDIAN to 1.              */
#define BIGENDIAN 0

/*  If the bytes of an integer are ordered lest significant byte    */
/*  byte first and then increasing set LITTLEENDIAN to 1.           */
#define LITTLEENDIAN 1

/*  Note that BIGENDIAN and LITTLEENDIAN are mutually exclusive.    */

/*  If switch-statements should be generated as a sequence of       */
/*  SUB,TST,BEQ ICs rather than COMPARE,BEQ ICs set this to 1.      */
/*  This can yield better code on some machines.                    */
#define SWITCHSUBS 0

/*  In optimizing compilation certain library memcpy/strcpy-calls   */
/*  with length known at compile-time will be inlined using an      */
/*  ASSIGN-IC if the size is less or equal to INLINEMEMCPY.         */
/*  The type used for the ASSIGN-IC will be UNSIGNED|CHAR.          */
#define INLINEMEMCPY 16

/*  Parameters are sometimes passed in registers without __reg.     */
#define HAVE_REGPARMS 1

/*  Structure for reg_parm().                                       */
struct reg_handle{
    unsigned long gpr;
};

/*  We have register pairs.                                         */
#define HAVE_REGPAIRS 1

/*  We use unsigned int as size_t rather than unsigned long which   */
/*  is the default setting.                                         */
#define HAVE_INT_SIZET 1

/*  We have asm_peephole to optimize assembly-output */
#define HAVE_TARGET_PEEPHOLE 0	/* FIXME: not yet */

/*  We have some target-specific variable attributes.               */
#define HAVE_TARGET_ATTRIBUTES 1

/* We do not have target-specific pragmas */
#undef HAVE_TARGET_PRAGMAS

/*  We keep track of all registers modified by a function.          */
#define HAVE_REGS_MODIFIED 1

/* We have a implement our own cost-functions to adapt
   register-allocation */
#if 0 /* FIXME */
#define HAVE_TARGET_RALLOC 1
#define cost_move_reg(x,y)  XXX
#define cost_load_reg(x,y)  XXX
#define cost_save_reg(x,y)  XXX
#define cost_pushpop_reg(x) XXX
#endif

/* we do not have a mark_eff_ics function, this is used to prevent
   optimizations on code which can already be implemented by efficient
   assembly */
#undef HAVE_TARGET_EFF_IC

/* we do not need extra elements in the IC */
#undef HAVE_EXT_IC

/* we need extended types (for pmem/dmem pointers) */
#define HAVE_EXT_TYPES 1

#undef CHAR
#undef SHORT
#undef INT
#undef LONG
#undef LLONG
#undef FLOAT
#undef DOUBLE
#undef LDOUBLE
#undef VOID
#undef POINTER
#undef ARRAY
#undef STRUCT
#undef UNION
#undef ENUM
#undef FUNKT
#undef BOOL
#undef MAXINT
#undef MAX_TYPE

#define CHAR 1
#define SHORT 2
#define INT 3
#define LONG 4
#define LLONG 5
#define FLOAT 6
#define DOUBLE 7
#define LDOUBLE 8
#define VOID 9
#define DPOINTER 10
#define PPOINTER 11
#define ARRAY 12
#define STRUCT 13
#define UNION 14
#define ENUM 15
#define FUNKT 16
#define BOOL 17
#define MAXINT 18
#define MAX_TYPE MAXINT

#define POINTER_TYPE(x) pointer_type(x)
extern int pointer_type();
#define ISPOINTER(x) ((x&NQ)>=DPOINTER&&(x&NQ)<=PPOINTER)
#define ISSCALAR(x) ((x&NQ)>=CHAR&&(x&NQ)<=PPOINTER)
#define ISINT(x) ((x&NQ)>=CHAR&&(x&NQ)<=LLONG)
#define PTRDIFF_T(x) (INT)

typedef zllong zmax;
typedef zullong zumax;

union atyps{
  zchar vchar;
  zuchar vuchar;
  zshort vshort;
  zushort vushort;
  zint vint;
  zuint vuint;
  zlong vlong;
  zulong vulong;
  zllong vllong;
  zullong vullong;
  zmax vmax;
  zumax vumax;
  zfloat vfloat;
  zdouble vdouble;
  zldouble vldouble;
};


/* we need our own printval */
#define HAVE_TGT_PRINTVAL 1

/* we want to replace some ICs with libcalls */
#define HAVE_LIBCALLS 1

/* we much prefer BNE */
#define HAVE_WANTBNE 1

/* size of buffer for asm-output */
#define EMIT_BUF_LEN 1024 /* should be enough */

/* number of asm-output lines buffered */
#define EMIT_BUF_DEPTH 4
