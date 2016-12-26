/* 
   FALCO16 v3
*/

/*#include "supp.h"*/
#include "dt.h"


/*  This struct can be used to implement machine-specific           */
/*  addressing-modes.                                               */
struct AddressingMode {
// register to be used as temporary pointer   
   int			regptr;
// register to be used as temporary value
// We support long and float and therfore need potentially 2 registers   
   int			regval[2];
};

/*  The number of registers of the target machine.                  */
#define MAXR		16

/*  Number of commandline-options the code-generator accepts.       */
#define MAXGF		3

/*  If this is set to zero vbcc will not generate ICs where the     */
/*  target operand is the same as the 2nd source operand.           */
/*  This can sometimes simplify the code-generator, but usually     */
/*  the code is better if the code-generator allows it.             */
#define USEQ2ASZ 1

/*  This specifies the smallest integer type that can be added to a */
/*  pointer.                                                        */
#define MINADDI2P INT

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
#define INLINEMEMCPY 4

/*  Parameter push order */
#undef ORDERED_PUSH

/*  Parameters are sometimes passed in registers without __reg.     */
//#define HAVE_REGPARMS 1
#undef HAVE_REGPARMS

/* use library calls for some basic ICs */
#define HAVE_LIBCALLS 1

/*  Structure for reg_parm().                                       */
struct reg_handle{
    unsigned long gregs;
    unsigned long fregs;
};


/* we do not need register-pairs */
#undef HAVE_REGPAIRS

/* select size_t. unsigned int or unsigned long, the default */
#undef HAVE_INT_SIZET

/* size of buffer for asm-output, this can be used to do
   peephole-optimizations of the generated assembly-output */
#define EMIT_BUF_LEN 1024 /* should be enough */
/* number of asm-output lines buffered */
#define EMIT_BUF_DEPTH 1

/*  We have no asm_peephole to optimize assembly-output */
#define HAVE_TARGET_PEEPHOLE 0


/*  We have some target-specific variable attributes.               */
#undef HAVE_TARGET_ATTRIBUTES

/* We have target-specific pragmas */
#undef HAVE_TARGET_PRAGMAS

/*  We keep track of all registers modified by a function.          */
#undef HAVE_REGS_MODIFIED

/* We have a implement our own cost-functions to adapt 
   register-allocation */
#undef HAVE_TARGET_RALLOC


/* we do not have a mark_eff_ics function, this is used to prevent
   optimizations on code which can already be implemented by efficient
   assembly */
#undef HAVE_TARGET_EFF_IC

/* we do need extra elements in the IC */
#define HAVE_EXT_IC 1
struct Regtmp {
// register number   
   int		reg;
// must be saved before used?
   int		save;
};
#define MAX_TMPREG		3
struct ext_ic {
// temporary ptr register to use with this IC
   struct Regtmp	reg_tmp[MAX_TMPREG];
};

/* We have extended types! What we have to do to support them:      */
/* - #define HAVE_EXT_TYPES
   - #undef all standard types
   - #define all standard types plus new types
   - write eval_const and insert_const
   - write typedefs for zmax and zumax
   - define atyps union
   - write typname[]
   - write conv_typ()
   - optionally #define ISPOINTER, ISARITH, ISINT etc.
   - optionally #define HAVE_TGT_PRINTVAL and write printval
   - optionally #define POINTER_TYPE
   - optionally #define HAVE_TGT_FALIGN and write falign
   - optionally #define HAVE_TGT_SZOF and write szof
   - optionally add functions for attribute-handling
*/
#undef HAVE_TGT_PRINTVAL
#undef HAVE_EXT_TYPES



