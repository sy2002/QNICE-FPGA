/* 
   FALCO16 v3
*/                                                                             

/* TO DO

- If a FREEREG follows an IC for Q1, the register can be used as temporary.
e.g if we get a = R0 + c, and there's a FREEREG R0 following the IC, we can generate
add r0, [c]
mov [a], r0
instead of
mov r1, r0
add r1, [c]
mov [a], r1

-- floating point capability must also be implemented

- data alignement doesn't work, g1 should be aligned below.
-- Is this supposed to be handled by the assembler?
char global = 4;
int g1 = 5;

-- conditional branching for LONG works, but temporary register handling is not ideal.
   Register are loaded more than required.

-- inline optimization must be done, e.g shift by const, mul/div by 2

-- call ptr not implemented.

-- register parameter passing

-- 1arg operation are currently only using reg arguments

-- could take advantage of [reg+ofs] addressing mode by combining IC

-- IRQs should only save registers which are actually used, in case of function call all regs must be saved
-- implement "naked" keyword for RTOS use.

-- right now lib_mov is done by messing with the IC operands changing them into pointers. It is probably better to
   use ptr_push instead of messign around with val_push.

-- must update arg_push to support double, long long and such, not using more temperary registers

-- compare with KONST not correct when KONST = maxint

*/

#include "supp.h"
#include "vbc.h"

//static char FILE_[]=__FILE__;

/*  Public data that MUST be there.                             */

/* Name and copyright. */
char cg_copyright[]="falco16_v3 code generator v0.1 by Daniel Schoch";

// command line
//--------------
/*  Commandline-flags the code-generator accepts:
    0: just a flag
    VALFLAG: a value must be specified
    STRINGFLAG: a string can be specified
    FUNCFLAG: a function will be called
    apart from FUNCFLAG, all other versions can only be specified once */
int g_flags[MAXGF] = {VALFLAG, VALFLAG, VALFLAG};

/* the flag-name, do not use names beginning with l, L, I, D or U, because
   they collide with the frontend */
char *g_flags_name[MAXGF]={"regs", "rsave", "rtmp"};
/* Description of command line options:
regs=<val>
DEFAULT = 6
Specify the number of registers to use. Must be >=3 and <= 14.
The value should match the actual CPU implementation, the default is 6.
Values < 6 don't make much practical sense since there won't be
enough registers available for efficient code generation.

rsave=<val>
DEFAULT = automatic
0 <= val <= regs-rtmp
Specify the number of non-scratch registers to use.
Non-scratch registers are registers that are saved across
function calls. They are used for efficient register
variable implementation.

rtmp=<val>
DEFAULT = 0
0 <= val <= 3
Specify the number of temporary registers to reserve.
Temporary registers are used by the code generator.
In situation where there is no free register is available
a register must be saved and restored.

/* the results of parsing the command-line-flags will be stored here */
union ppi g_flags_val[MAXGF];



// data types
//======================

/*  CHAR_BIT for the target machine.                            */
zmax char_bit;

/* Typenames (needed because of HAVE_EXT_TYPES). */
char *typname[MAX_TYPE+1];

/*  Alignment-requirements for all types in bytes.              */
zmax align[MAX_TYPE+1];

/*  Alignment that is sufficient for every object.              */
zmax maxalign;

/*  sizes of the basic types (in bytes) */
zmax sizetab[MAX_TYPE+1];

/*  Minimum and Maximum values each type can have.              */
/*  Must be initialized in init_cg().                           */
zmax t_min[MAX_TYPE+1];
zumax t_max[MAX_TYPE+1];
zumax tu_max[MAX_TYPE+1];

// registers
//==========================

/*  Names of all registers. will be initialized in init_cg(),
    register number 0 is invalid, valid registers start at 1 */
char *regnames[MAXR+1];

/*  The Size of each register in bytes.                         */
zmax regsize[MAXR+1];

/*  Specifies which registers may be scratched by functions.    */
int regscratch[MAXR+1];

/*  regsa[reg]!=0 if a certain register is allocated and should */
/*  not be used by the compiler pass.                           */
int regsa[MAXR+1];

/* specifies the priority for the register-allocator, if the same
   estimated cost-saving can be obtained by several registers, the
   one with the highest priority will be used */
int reg_prio[MAXR+1];

/*  a type which can store each register. */
struct Typ *regtype[MAXR+1];

/* an empty reg-handle representing initial state */
struct reg_handle	empty_reg_handle = {0, 0};


/****************************************/
/*  Private data and functions.         */
/****************************************/

#define ISCOMPOSITE(t)	(ISARRAY(t) || ISSTRUCT(t) || ISUNION(t))

// number of registers to use, this can be a ny value from 3 to 14.
// A value < 6 is not recommended as it does not leave any registers for
// efficient code generation.
// The default is 6.
int nregs;

// register names
#define REG_FLAGS	1
#define REG_SP		2
#define REG_R0		3
#define REG_R1		4
#define REG_R2		5
#define REG_R3		6
#define REG_R4		7
#define REG_R5		8
#define REG_R6		9
#define REG_R7		10
#define REG_R8		11
#define REG_R9		12
#define REG_R10		13
#define REG_R11		14
#define REG_R12		15
#define REG_R13		16

// register usage tracking system
// Allocated by ALLOCEG IC
#define TRACK_ALLOCREG	1
// used by IC, not available as temporary
#define TRACK_IC		2
// allocated as temporary by tracker
#define TRACK_TMP		4
// saved 
#define TRACK_SAVED		8
// not usable as indicated by CPU register layout
#define TRACK_OFFLIMITS		16
// dedicated temporary register
#define TRACK_DEDICATED		32
// bits indicating register is used and cannot be used no matter what
#define TRACK_NOGO		(TRACK_IC | TRACK_TMP | TRACK_OFFLIMITS)
int track_status[MAXR+1];

// We provide 3 slots for temporary registers.
// In here we keep track if which slot contains which register.
#define TRACK_SLOTS		3
int track_slot[TRACK_SLOTS];

/* used to initialize regtyp[] */
static struct Typ ltyp = { INT };

/* macros defined by the backend */
// extended data types attribute strings
#define EXTDATA_INTERRUPT	"interrupt"

static char 		*marray[] = {
   "__FALCO16__",
   "__interrupt(x)=__vattr(\"interrupt(\"#x\")\")",
   0
};

/* sections */
#define SEC_TEXT	0		// code
#define SEC_RODATA	1		// constant data
#define SEC_DATA	2		// initialized data
#define SEC_BSS		3		// data initialized to 0
#define SEC_VECTOR	4		// irq vectors
static int		section = -1;
static char 		*sec_textname = "code",
  			*sec_rodataname = "const",
  			*sec_dataname = "idata",
  			*sec_bssname = "zdata",
  			*sec_vectorname = "vector";

/* assembly-prefixes for labels and external identifiers */
static char 		*label_prefix = "p";
static char		*ident_prefix = "_";
static int			label_count;


// assemly data storage strings
static char 		*dct[] = {"", "db", "dw", "dw", "dd", "dd", "dd", "dd", "dd"};


static long		loff;
static long		stackoffset;
static int		newobj;


static long pof2(zumax x)
/*  Yields log2(x)+1 oder 0. */
{
   zumax	p;
   int		ln = 1;
    
   p = ul2zum(1UL);
   while (ln <= 32 && zumleq(p, x)) {
      if (zumeqto(x, p)) return ln;
      ln++; p = zumadd(p, p);
   }
   return 0;
}

static long const_get(struct obj *x, int typ, int n)
{
   long	       ret;
   
   eval_const(&x->val, typ);
   ret = (vmax >> (n * char_bit)) & 0xffff;
   
   return ret;
}   

static long ofs_get(struct obj *x)
{
   long	    ret;
   
   ret = 0;
   if (x->flags & VAR) {
      if (x->v->offset < 0) {
         ret = (long)(loff-(x->v->offset+2)+(x->val.vmax))-stackoffset+2;
      } else {
         ret = (long)((x->v->offset)+(x->val.vmax)-stackoffset);
      }
   }  
   return ret;
}


static void emit_object(FILE *f, struct obj *x, int n, int typ)
{
   long		ofs;

// calculate offset into stack
   ofs = ofs_get(x);

// access mode
   eval_const(&x->val, typ);

   if (x->flags & REG) {
      if (x->flags & DREFOBJ) {
// register pointer '[reg+ofs]'
         emit(f, "[%s+%ld]", regnames[x->reg], n);
      } else {
// register 'reg'
         emit(f, "%s", regnames[x->reg]);
      }
   } else if (x->flags & KONST) {
      if (x->flags & VARADR) {
// This is the special case for which the address of a constant must be generated.
// KONST| VARADR is never generated by the front-end, but it's a modified
// object by the back-end. The address of a constant is used for FLOAT/DOUBLE
// library call operations involving a constant. An address to a constant is generated by
// placing the constant into section SEC_RODATA and generating a pointer to
// the object.
// NOT COMPLETE, must have some kind of konst counter.
// 1st nject konst into ROM section         
         emit(f, "__KONST_");
      } else if (x->flags & DREFOBJ) {
// constant address, e.g. mov [123], r0
         emit(f, "[%ld]", const_get(x, typ, n));      
      } else {
// regular KONST value
         emit(f, "%ld", const_get(x, typ, n));
      }
   } else if (x->flags & VAR) {
// REGULAR VARIABLE ACCESS      
      if (isauto(x->v->storage_class)) {
         if (x->flags & VARADR) {
// this is a special case not generated by the front-end, it's a modified object
// by the back end needing to generate the address of a auto variable.
// This is used by 'ptr_push'. What eventually must be generated is
// mov reg, sp
// add reg, ofs+n
// Since this is the emit_object function we only generate sp here, the
// add reg, ofs+n must be generated by the callee.
            emit(f, "sp");
         } else {
// stack based value '[sp+ofs]'      
            emit(f, "[sp+%ld]", (long)ofs + n);
         } 
      } else if (isextern(x->v->storage_class)) {
         if (x->flags & VARADR) {
// address of global variable
            emit(f, "%s%s+%ld", ident_prefix, (long)x->v->identifier, (long)x->val.vmax + n);
         } else {
// value of global '[ident+ofs]'        
            emit(f, "[%s%s+%ld]", ident_prefix, (long)x->v->identifier, (long)x->val.vmax + n);
         }
      } else if (isstatic(x->v->storage_class)) {
         if (x->flags & VARADR) {
// address of static variable         
            emit(f, "%s%ld+%ld", label_prefix, (long)x->v->offset, (long)x->val.vmax + n);
         } else {
// value of static variable         
            emit(f, "[%s%ld+%ld]", label_prefix, (long)x->v->offset, (long)x->val.vmax + n);
         }
      } else terror("-- emit_object: unexpected storage class");
   } else {   
      terror("-- emit_object: unexpected access mode");
   }  
}

/*
Load a temporary ptr register to be used by the main emit_load
function.
returns 1, if code was generated to load the pointer.
returns 0, if no code was necessary since no temporary ptr is required.
*/
static int emit_tmpptr(FILE *f, struct obj *x, int n)
{
   struct AddressingMode *am;
   char		*regptr_name;
   int		ret;

   ret = 0;
   am = x->am;
   if (am && am->regptr) {
      ret = 1;
      regptr_name =  regnames[x->am->regptr];         
      if (n == 0) {
	 emit(f, "\tmov\t%s, ", regptr_name);
         emit_object(f, x, 0, POINTER);
	 emit(f, "\n");
      } else {
	  //  emit(f, "\tadd\t%s, %d\n", regptr_name, n);
      }    
   }
   return ret;
}


// Generate code to perform a given operation.
// The code generated is:
//    op  t, s
// typ = operand type (e.g CHAR, POINTER, INT ...)
// n   = the offset when dealing with multi-world objects (e.g long, float)
// EITHER t OR s MUST BE A REGISTER!
// For the non-register operand, temporaries are used and loaded
// according to am-data.
static void emit_op(FILE *f, struct obj *t, struct obj *s, int typ, int n, char *op)
{
   long		ofs;
   char		*mode;

// calculate offset into stack
   ofs = ofs_get(t);

// determine access mode (8-bit or 16-bit instruction)
   mode = "";
   if (sizetab[typ&NQ] == 1) mode = ".8";

   if (emit_tmpptr(f, s, n)) {
// we use a temporary pointer and it's loaded in register s->am->regptr
// Now we have to generate the code to load the data using the temporary pointer.      
      emit(f, "\t%s%s\t%s, [%s+%d]\n", op, mode, regnames[t->reg], regnames[s->am->regptr], n);      
   } else if (emit_tmpptr(f, t, n)) {
// get value into target register
      emit(f, "\t%s%s\t[%s+%d], %s\n", op, mode, regnames[t->am->regptr], n, regnames[s->reg]);      
   } else {
      emit(f, "\t%s%s\t", op, mode);
      emit_object(f, t, n, typ);
      emit(f, ", ");
      emit_object(f, s, n, typ);
      emit(f, "\n");
   }      
}

// Generate register loading code in the following format:
//    op  reg, x
// Meaning it is always code generated, which loads into a register.
// typ = operand type (e.g CHAR, POINTER, INT ...)
// n   = the offset when dealing with multi-world objects (e.g long, float)
static void emit_load(FILE *f, int reg, struct obj *s, int typ, int n, char *op)
{
   struct obj	*x;
   int		ofs;

// if target register is blank, we quit
   if (reg == 0) return;

   x = mymalloc(sizeof(struct obj));

// build a target register object
   x->flags = REG;
   x->reg = reg;
   x->dtyp = 0;
   x->v = 0;
   x->am = 0;

// generate operation
   emit_op(f, x, s, typ, n, op);
// we have to take care of the speical case of address of auto variable
   if ((s->flags & (VAR|VARADR)) == (VAR|VARADR)) {
      if (isauto(s->v->storage_class)) {
// calculate offset into stack
         ofs = ofs_get(s) + n;
         if (ofs) {       
	 emit(f, "\tadd\t%s, %d\n", regnames[reg], ofs);
         } 
      }
   }

   myfree(x);
}
 
// Generate the following code:
//    mov t, reg
// typ = operand type (e.g CHAR, POINTER, INT ...)
// n   = the offset when dealing with multi-world objects (e.g long, float)
static void emit_store(FILE *f, struct obj *t, int reg, int typ, int n)
{
   struct obj	*x;

// if source register is blank, we quit
   if (reg == 0) return;

   x = mymalloc(sizeof(struct obj));

// build a source register object
   x->flags = REG;
   x->reg = reg;
   x->dtyp = 0;
   x->v = 0;
   x->am = 0;

// generate operation
   emit_op(f, t, x, typ, n, "mov");

   myfree(x);
}

void am_alloc(struct obj *x)
{
// if no object, return
   if (x == 0) return;
// if already allocated, return
   if (x->am) return;

   x->am = mymalloc(sizeof(struct AddressingMode));
   x->am->regptr = 0;
   x->am->regval[0] = 0;
   x->am->regval[1] = 0;
}

// Compare if 2 objects are the same.
int obj_eq(struct obj *x1, struct obj *x2)
{
   int		ret;

// we assume the objects are equal to start with
   ret = 1;

   if (x1==0 || x2==0) {
      ret = 0;
   } else {
      if (x1->flags != x2->flags) ret = 0;
      if (x1->reg != x2->reg) ret = 0;
   }

   return ret;
}

/*
Initialize register tracking system.
The tracking systemis is used to keep track of what register is used and holds
what at any given time. Depending on availability, temporary registers can be
allocated with best efficiency.
*/
static void track_init(void)
{
   int		i;

// pre-fill
   for(i = 1; i <= MAXR; i++) {
// clear all unnecessary bits
      track_status[i] &= (TRACK_OFFLIMITS | TRACK_DEDICATED);
   }

// all slots are empty at the beginning.
   for (i = 0; i < TRACK_SLOTS; i++) {
// indicate slot is not used      
     track_slot[i] = 0;
   }
}


// Mark any register used by the IC
static void track_obj_claim(struct obj *x)
{
// analyze object and flag already used registers as 'no-go'
   if (x && (x->flags & REG)) {
      track_status[x->reg] |= TRACK_IC;
   }
}

/* 
Allocate the required temporary registers
to be able to generate code for the given IC.
Each operand gets an 'am' datastructure, which
is filled with the temporary registers to use.

And it works like this
z   =   q1 <op> q2
ptr     ptr     ptr
val     val

There's only one ptr that satisfies all three operand.
There's only one val that is used for both q1 and z.

So for example in if we have q1(ptr, val) that means:
Use register ptr to get q1 into register val.

Or for z(ptr, val): Use register ptr to store register val
to the target location.
*/


/*
0. determine if we need to free previously allocated temps
a. we do this if we got a branch or if the current IC uses any temp reg
1. determine how many temporaries we need
2. check if we can reuse previously reserved temps
3. reserve temps if necessary (and make it smart, pick the ones that are not used in the next IC)
*/

static int track_alloc(FILE *f)
{
   int		reg;
   int		i;
   int		save;

   reg = 0;
   save = 0;
// try to find a register
// If we can't find one, there's some serious issue.
   for (i = 1; i < MAXR+1; i++) {
      if ((track_status[i] & (TRACK_NOGO|TRACK_ALLOCREG|TRACK_SAVED)) == TRACK_ALLOCREG) {
// found a register, but it must be saved, keep looking maybe
// we find a better one, only use this if we haven't found anything useful yet
         if (reg == 0) {
            reg = i;
            save = 1;
         }  
      } else if ((track_status[i] & (TRACK_NOGO|TRACK_ALLOCREG|TRACK_SAVED)) == (TRACK_ALLOCREG|TRACK_SAVED)) {
// found a register, it's in use by ALLOCREG, but it has already been saved
// We use it and quit.
         reg = i;
	 save = 0;
	 break;
      } else if ((track_status[i] & (TRACK_NOGO|TRACK_ALLOCREG|TRACK_SAVED|TRACK_DEDICATED)) == 0) {
// found an unallocated register which is not a dedicated temp, we use it
         reg = i;
	 save = 0;
	 break;
      } else if ((track_status[i] & (TRACK_NOGO|TRACK_DEDICATED)) == TRACK_DEDICATED) {
// found a dedicated temporary, we could use it, but we try to find a better one
         reg = i;
	 save = 0;
      }
   }
   if (reg == 0) terror("-- track_alloc: can't find temporary register");

// flag register as taken
   track_status[reg] |= TRACK_TMP;
   emit(f, "; allocate temporary: %s\n", regnames[reg]);
   if (save) {
      track_status[reg] |= TRACK_SAVED;
// find an unused storage slot
      for (i = 0; i < TRACK_SLOTS; i++) {
         if (!track_slot[i]) break;
      }
      if (i >= TRACK_SLOTS) terror("--track_alloc: out of storage slots");
      track_slot[i] = reg;      
      emit(f, "\tmov\t[_TSLOT+%d], %s\n", i*2, regnames[reg]);
   }

   return reg;
}


/*
Temporary register tracking and assignement.
*/
/*
Check if access to object x requires temporary registers.
Allocate all required temporary registers.
*/
static void track_obj(FILE *f, struct obj *x, int typ)
{
   int		i;
   int		reg, reg2;
   int		need_tmpval;
   int		size;


// object must have 'am' structure.
   am_alloc(x);

// determine if we need to free previously allocated temporaries
// claim registers used by object  
   track_obj_claim(x);
// see if one of them was allocated, and free it if necessary
   for (i = 0; i < TRACK_SLOTS; i++) {
      reg = track_slot[i];
      if ((track_status[reg] & (TRACK_IC|TRACK_SAVED)) == (TRACK_IC|TRACK_SAVED)) {
         track_status[reg] &= ~TRACK_SAVED;
         track_slot[i] = 0;
         emit(f, "; restore temporary\n");
         emit(f, "\tmov\t%s, [_TSLOT+%d]\n", regnames[reg], i*2);
      }
   }

// determine how many temporary registers we need
   need_tmpval = 1;
   if (x && (x->flags & (REG|DREFOBJ)) == REG) need_tmpval = 0;

   if (need_tmpval) {
// we need temporary value register, allocate one
      reg = track_alloc(f);    
// In case this is a 32-bit operand we need 2 temporaries
      size = sizetab[typ&NQ];     
      reg2 = 0;
      if (size == 4) {
         reg2 = track_alloc(f);
      }
      x->am->regval[0] = reg;
      x->am->regval[1] = reg2;
   }

// next step is to check if pointer memory access requires a register
   if (x && (x->flags & (DREFOBJ | VAR | REG)) == (DREFOBJ | VAR)) {
      reg = track_alloc(f);
      x->am->regptr = reg;
   }
}

/*
Check the IC for temporary register requirements.
Allocate all required temporaries and save them if required.
*/
static void track_ic(FILE *f, struct IC *p) 
{
   struct obj	*z;
   struct obj	*q1;
   struct obj	*q2;
   int		i;
   int		reg, reg2;
   int		need_tmpval;
   int		size;
   int		code;

// get objects
   z = &p->z;
   q1 = &p->q1;
   q2 = &p->q2;

// get instruction code
   code = p->code;

// each object must have 'am' structure.
   am_alloc(z);
   am_alloc(q1);
   am_alloc(q2);


// determine if we need to free previously allocated temporaries
// claim registers used by IC   
   track_obj_claim(z);
   track_obj_claim(q1);
   track_obj_claim(q2);

// see if one of them was allocated, and free it if necessary
   for (i = 0; i < TRACK_SLOTS; i++) {
      reg = track_slot[i];
      if ((track_status[reg] & (TRACK_IC|TRACK_SAVED)) == (TRACK_IC|TRACK_SAVED)) {
         track_status[reg] &= ~TRACK_SAVED;
	 track_slot[i] = 0;
	 emit(f, "; restore temporary\n");
	 emit(f, "\tmov\t%s, [_TSLOT+%d]\n", regnames[reg], i*2);
      }
   }

// determine how many temporary registers we need
   need_tmpval = 1;
   if (z && (z->flags & (REG|DREFOBJ)) == REG) need_tmpval = 0;
   if (q1 && (q1->flags & (REG|DREFOBJ)) == REG) need_tmpval = 0;
   if (q2 && (q2->flags & (REG|DREFOBJ)) == REG) need_tmpval = 0;

// if target Z is NOT the same as Q1 we will always need a temporary   
   if (code == ASSIGN || code == CONVERT) {
      ;
   } else if (code == COMPARE) {
// in case of COMPARE we need a temporary if Q1 == KONST
      if (q1 && (q1->flags & KONST) == KONST) need_tmpval = 1;
   } else {
      if (!obj_eq(z, q1)) {
         need_tmpval = 1;
      }
   }

   if (need_tmpval) {
      reg = 0;
// check if we can use target register as temporary
// We can do so if Q2 is not the same as Z      
      if (z) {   
         if (((z->flags & (REG|DREFOBJ)) == REG) && !obj_eq(z, q2)) {
            reg = z->reg;
	    track_status[reg] |= TRACK_TMP;
         } else {
// we need temporary value register, allocate one
            reg = track_alloc(f);
         }
// In case this is a 32-bit operand we need 2 temporaries
         size = sizetab[ztyp(p)&NQ];     
         reg2 = 0;
         if (size >= 4) {
            reg2 = track_alloc(f);
         }
         z->am->regval[0] = reg;
         z->am->regval[1] = reg2;
      }
// Q1 need the same temp as Z, but maybe only 16-bit
      if (q1) {
         if (!reg) {
	    reg = track_alloc(f);
         }
         q1->am->regval[0] = reg;
         if (sizetab[q1typ(p)&NQ] <= 2) {
            reg2 = 0;
         }
        q1->am->regval[1] = reg2;
      }
   }

// next step is to check if pointer memory access requires a register
   reg = 0; 
   if (z && (z->flags & (DREFOBJ | VAR | REG)) == (DREFOBJ | VAR)) {
      if (!reg) reg = track_alloc(f);
      z->am->regptr = reg;
   } 
   if (q1 && (q1->flags & (DREFOBJ | VAR | REG)) == (DREFOBJ | VAR)) {
      if (!reg) reg = track_alloc(f);
      q1->am->regptr = reg;
   } 
   if (q2 && (q2->flags & (DREFOBJ | VAR | REG)) == (DREFOBJ | VAR)) {
      if (!reg) reg = track_alloc(f);
      q2->am->regptr = reg;
   }

}

static void track_release(void)
{
   int		i;

   for (i = 1; i <= MAXR; i++) {
      track_status[i] &= ~(TRACK_TMP|TRACK_IC);
   }
}

/*
Restores all saved temporary registers.
This must be executed before any branch, call
or function exit.
*/
static void track_restore(FILE *f)
{
   int		i;

   track_release();
   for (i = 0; i < TRACK_SLOTS; i++) {
      if (track_slot[i]) {
         track_status[track_slot[i]] &= ~(TRACK_SAVED);
	 emit(f, "\tmov\t%s, [_TSLOT+%d]\n", regnames[track_slot[i]], i*2);
	 track_slot[i] = 0;
      }
   }
}
// same as above, but don't clear TRACK_SAVED and don't release the temps.
// This is used in branch instructions.
static void track_restore2(FILE *f)
{
   int		i;

   for (i = 0; i < TRACK_SLOTS; i++) {
      if (track_slot[i]) {
	 emit(f, "\tmov\t%s, [_TSLOT+%d]\n", regnames[track_slot[i]], i*2);
      }
   }
}



/* generates the function entry code */
static void cd_function_entry(FILE *f, struct Var *v, long offset)
{
   int		i;

   if (section != SEC_TEXT) {
      emit(f, "\n\tsection\t%s\n", sec_textname);
      section = SEC_TEXT;
   }

   if (v->storage_class == EXTERN) emit(f,"\tpublic\t%s%s\n", ident_prefix, v->identifier);
   emit(f,"%s%s:\n", ident_prefix,v->identifier);

   if (v->vattr && strstr(v->vattr, EXTDATA_INTERRUPT)) {     
// interrupt service routine
      emit(f, "\tpush\tflags\n");
      for (i = REG_R0; i < REG_R0+nregs; i++) {
         emit(f, "\tpush\t%s\n", regnames[i]);
      }
   }   
            
// allocate required stack
   if (offset > 0) emit(f,"\tsub\tsp, %ld\n", offset);

// store non-scratch register used in function
   for (i = 1; i <= MAXR; i++) {
      if (!regsa[i] && !regscratch[i] && regused[i]) {
         emit(f, "\tpush\t%s\n", regnames[i]);
// adjust stack offset
         stackoffset -= 2;
      }
   }
}

/* generates the function exit code */
static void cg_function_exit(FILE *f, struct Var *v, long offset)
{
   int		i;

// restore any saved temporary registers
// I don't think this is necessary as long as we don't have global register variables.
// What does vbcc do? Global regs?
   track_restore(f);

// restore non-scratch register used in function
   for (i = MAXR; i >= 1; i--) {
      if (!regsa[i] && !regscratch[i] && regused[i]) {
         emit(f, "\tpop\t%s\n", regnames[i]);
         stackoffset += 2;
      }
   }

   if (offset > 0) {
      emit(f,"\tadd\tsp, %ld\n", offset);
   }
   
   if (v->vattr && strstr(v->vattr, EXTDATA_INTERRUPT)) {
// interrupt service routine
      for (i = REG_R0+nregs-1; i >= REG_R0; i--) {
         emit(f, "\tpop\t%s\n", regnames[i]);
      }
      emit(f, "\tpop\tflags\n");
      emit(f, "\tiret\n\n");
   } else {   
      emit(f, "\tret\n\n");
   }
}

/* 
some blurp:
There's an IC, which contains a target(z), and 2 sources(q1 and q2).
Macros ztyp, q1typ and q2typ return the type of the operands
e.g. (char, int, short, double, struct, array....).
Also contains the qualifiers UNSIGNED, CONST
Most of the time it's the same for all operands. Exceptions are
CONVERT or adding int to pointer.
Using NU and NQ will remove qualifiers and only leave base type.

Of interest are:
ISPOINTER, ISINT, ISFLOAT, ISFUNC, ISSTRUCT, ISUNION, ISARRAY,
ISSCALAR, ISARITH

Each operand can be one of the following:
----------------------------------------
KONST			constant number
KONST|DREFOBJ		absolute pointer
REG			register
VAR			variable (can be auto, register, static, extern)
VAR|REG			a variable which was put in a register
REG|DREFOBJ		indirect [reg]
VAR|DREFOBJ		indirect [var]
VAR|REG|DREFOBJ		indirect [reg], where the register is a variable
VAR|VARADR		address of a variable

Temporaries generated by the compiler don't have the VAR flag set.
It is only a VAR if it is so in the source code.

Each variable then has information regarding the storage class,
so each VAR is on of the following:
AUTO
REGISTER
STATIC
EXTERN

Macros of interest:
isauto, isextern, isstatic.

*/
/* val_push
Pushing the value of the object onto the stack.
*/
static void val_push(FILE *f, struct obj *x, int typ)
{
// handle required temporaries	   
   track_obj(f, x, typ); 

   emit(f, "; push val\n");
   
// Load Q1 into temporary register val if necessary.
// Automatically use temporary x->am->regptr if necessary.
   emit_load(f, x->am->regval[0], x, typ, 0, "mov");
   emit_load(f, x->am->regval[1], x, typ, 2, "mov");

// emit operation
  if (x->am->regval[1]) {
      emit(f, "\tpush\t%s\n", regnames[x->am->regval[1]]);
      stackoffset -= 2;
   }
   if (x->am->regval[0]) {
// operation is performed on temporaries
      emit(f, "\tpush\t%s\n", regnames[x->am->regval[0]]);
      stackoffset -= 2;
    } else {
// operation is performed directly on target (z == q1 for this to work)
      emit(f, "\tpush\t%s\n", regnames[x->reg]);
      stackoffset -= 2;
   }

// release temporaries
   track_release();
}
/* ptr_push
Pushing the ptr to the object onto the stack.
In case the object is a KONST, a copy of the KONST is made
in romsection and a pointer to the constant is pushed.
WARNING WARNING WARNING
This function MODIFIES the object *x.
*/
static void ptr_push(FILE *f, struct obj *x)
{
// handle required temporaries	   
   track_obj(f, x, POINTER); 

   emit(f, "; push ptr to object\n");
   
// modify the IC such that we can generate code from it

// what we should do here is: if DREFOBJ is set, clear it. If DREFOBJ is not set, set VARADR.
      if (x->flags & DREFOBJ) {
         x->flags &= ~DREFOBJ;
     } else {    
	 x->flags |= VARADR;
      }
      x->dtyp = POINTER;

// Load object into temporary register val if necessary.
// Automatically use temporary x->am->regptr if necessary.
   emit_load(f, x->am->regval[0], x, POINTER, 0, "mov");

// emit operation
   if (x->am->regval[0]) {
// operation is performed on temporaries
      emit(f, "\tpush\t%s\n", regnames[x->am->regval[0]]);
      stackoffset -= 2;
    } else {
// operation is performed directly on target (z == q1 for this to work)
      emit(f, "\tpush\t%s\n", regnames[x->reg]);
      stackoffset -= 2;
   }

// release temporaries
   track_release();
}

/*
Get the object from the stack. It is assumed the object is
located at [sp]. It is subsequently transfered to x
[sp] --> x
This function can be implemented either using 'pop' or using '[sp+xx]'.
Either one has advantage or disadvantage, also depending on CPU
implementation.
*/
void val_pop(FILE *f, struct obj *x, int typ)
{
   emit(f, "; pop val\n");

// handle required temporaries	   
   track_obj(f, x, typ); 
   
// Load [sp] value into temporary register val if necessary.
   if (x->am->regval[0]) {
// operation is performed on temporaries
      emit(f, "\tpop\t%s\n", regnames[x->am->regval[0]]);
      stackoffset += 2;
      if (x->am->regval[1]) {
         emit(f, "\tpop\t%s\n", regnames[x->am->regval[1]]);
         stackoffset += 2;
      }
   } else {
// operation is performed directly on target (z == q1 for this to work)
      emit(f, "\tpop\t%s\n", regnames[x->reg]);
      stackoffset += 2;
   }

// store to target
   emit_store(f, x, x->am->regval[0], typ, 0);
   emit_store(f, x, x->am->regval[1], typ, 2);

// release temporaries
   track_release();
}

/*
Library call for ALU functions.
*/
static void lib_alu(FILE *f, struct IC *p, char *call)
{
   char		*modifier;
   char		*dtype;
   int		size;

   // do some checking first
   if (q1typ(p) != q2typ(p)) terror("--lib_alu: type mismatch");

   modifier = "S";
   if (q1typ(p) & UNSIGNED) {
      modifier = "U";
   }

   switch (q1typ(p)) {
      case CHAR: 
         dtype = "I8"; break;
      case SHORT:
      case INT:
         dtype = "I16"; break;
      case LONG:
         dtype = "I32"; break;
      case FLOAT:
         dtype = "F32"; break;
      case DOUBLE:
         dtype = "F64"; break;
      default:
         dtype = ""; break;
         terror("--lib_alu: data type not supported");
	 break;
   }
// handle required temporaries
// temporary allocation is handled in val_push instead.
// The idea here is to allocate all required temporaries now,
// such that the return value can be easily grabbed.
// This is not implemented right now due to complications.
//   track_ic(f, p);

// push the spaceholder for the result
   size = sizetab[ztyp(p)&NQ];
   if (size <= 2) {
// stack is 2-byte minimum
   if (size < 2) size = 2;
   emit(f, "\tsub\tsp, %d\n", size);
   stackoffset -= size;
// Push all arguments
   val_push(f, &p->q2, q2typ(p));
   val_push(f, &p->q1, q1typ(p));
   } else {
      ptr_push(f, &p->q2);
      ptr_push(f, &p->q1);
   }
   track_restore(f);
// emit call to library function
   emit(f, "\tcall\t_%s_%s%s\n", call, modifier, dtype);

// restore stack state
// use 2*size in case 'val_pop' actually pops,
// use 3*size in case 'val_pop uses [sp+xx]
    emit(f, "\tadd\tsp, %d\n", (int)2*size);
    stackoffset += 2*size;

// last step is to grab the return value
// Return value is at [sp].
   val_pop(f, &p->z, ztyp(p));

} 


/*
Library call for mempry copy functions.
*/
static void lib_mov(FILE *f, struct IC *p)
{

// modify the IC such that we can generate code from it      
   p->q2.flags = KONST;

// Push Q2 (number of bytes to copy)
   emit(f, "; push array size\n");
   val_push(f, &p->q2, INT);
// Push pointer to Q1 (source)
   emit(f, "; push source pointer\n");
   ptr_push(f, &p->q1);
// push pointer to target (Z)
   emit(f, "; push target pointer\n");
   ptr_push(f, &p->z);

   track_restore(f);
// emit call to library function
   emit(f, "\tcall\t_MOV\n");

// stack cleanup, we should use callee clean-up
    emit(f, "\tadd\tsp, %d\n", (int)6);
    stackoffset += 6;
} 
/*

*/
static void cg_assign(FILE *f, struct IC *p)
{
   struct obj	*x;
   int		typ;
   int		size;

// any struct or array goes to library function
// anything > 4 bytes goes to library
// size is only possible with ASSIGN, not CONVERT.
   if (p->code == ASSIGN) {
      size = opsize(p);
      if (size > 4 || ISCOMPOSITE(ztyp(p))) {

         lib_mov(f, p);
         return;
      }
   }

// handle required temporaries   
   track_ic(f, p);

   // We also get here for CONVERT, so test don't work.
  // if (q1typ(p) != ztyp(p)) terror(0);
   emit(f, "; mov\n");

// emit operation
   typ = q1typ(p);
   x = &p->q1;
   if (x->am->regval[0]) {
// operation is performed on temporaries
      emit_load(f, x->am->regval[0], x, typ, 0, "mov");
      emit_load(f, x->am->regval[1], x, typ, 2, "mov");
   } else {
// operation is performed directly, no temporaries involved
      emit_op(f, &p->z, x, typ, 0, "mov");
   }

// check if this is a CONVERT operation and inject sign extension
// if necessary.
   if (p->code == CONVERT) {
// if Q1 is CHAR we need to blow it up to INT      
      if (sizetab[q1typ(p) & NQ] == 1) {
         if (typ & UNSIGNED) {
// clear high byte            
            if (p->z.am->regval[0]) {
	       emit(f, "\tand\t%s, 0xff\n", regnames[p->z.am->regval[0]]);
            } else {
	       emit(f, "\tand\t%s, 0xff\n", regnames[p->z.reg]);
	    }
         } else {
// SXT high byte
            if (p->z.am->regval[0]) {
               emit(f, "\tsxt.8\t%s\n", regnames[p->z.am->regval[0]]);
            } else {
	       emit(f, "\tsxt.8\t%s\n", regnames[p->z.reg]);
	    }
	 }
      }         
// if Z is LONG we need to blow it up from INT to LONG      
      if (sizetab[ztyp(p) & NQ] == 4) {      
         if (typ & UNSIGNED) {
            emit(f, "\tmov\t%s, 0\n", regnames[p->z.am->regval[1]]);
         } else {
            emit(f, "\tmov\t%s, %s\n", regnames[p->z.am->regval[1]], regnames[p->z.am->regval[0]]);
            emit(f, "\tsxt\t%s\n", regnames[p->z.am->regval[1]]);
         } 
      }
   }
// emit store if necessary
   typ = ztyp(p);
   x = &p->z;
   emit_store(f, x, x->am->regval[0], typ, 0);
   emit_store(f, x, x->am->regval[1], typ, 2);

// release temporaries
   track_release();
}   


static void cg_push(FILE *f, struct IC *p)
{
   int		size;

// any object larger than 4 bytes goes to a library function
   size = opsize(p); // might need to use pushsize here instead of opsize?
   if (size > 4 || ISCOMPOSITE(q1typ(p))) {
// allocate required stack
      emit(f, "\tsub\tsp, %d\n", size);
      stackoffset -= size;

// Push Z (number of bytes to push)
      emit(f, "; push array size\n");
// modify z such that it becomes a KONST      
      p->z.flags = KONST;
      val_push(f, &p->z, INT);
// Push pointer to Q1 (source)
      emit(f, "; push source pointer\n");
      ptr_push(f, &p->q1);

// emit call to library function
      emit(f, "\tcall\t_PUSH\n");

// stack cleanup, we should use callee clean-up
      emit(f, "\tadd\tsp, %d\n", (int)4);
      stackoffset += 4;
      return;
   }
// handle required temporaries of 1op instructions	   
  // track_push(f, p); // this must go, needs to be part of val_push

   val_push(f, &p->q1, q1typ(p));

} 

static void cg_call(FILE *f, struct IC *p) 
{
   long		size = pushedargsize(p);
   long		ofs;
   
// calculate offset into stack
   ofs = ofs_get(&p->q1);
   
   emit(f, "; call\n");
  
// restore any temporaries
   track_restore(f);

   if ((p->q1.flags & (VAR|DREFOBJ)) == VAR) {
// call to label      
      emit(f, "\tcall\t%s%s\n", ident_prefix, p->q1.v->identifier);
   } else if ((p->q1.flags & (VAR|DREFOBJ)) == (VAR|DREFOBJ) && p->q1.dtyp == POINTER) {
      terror("-- call:  pointer argument not yet supported");
   } else terror("-- call: unexpected call mode\n");   
   if (size > 0) {
      emit(f,"\tadd\tsp, %ld\n", size);
      stackoffset += size;
   }    
}


static void cg_alu(FILE *f, struct IC *p)
{
   struct obj	*x;
   int		typ;
   int		c;
   char		*instr1, *instr2;

   c = p->code;
   switch (c) {
      case ADD: instr1 = "add"; instr2 = "addc"; break;
      case SUB: instr1 = "sub"; instr2 = "subc"; break;
      case ADDI2P: instr1 = "add"; instr2 = "addc"; break;
      case SUBIFP: instr1 = "sub"; instr2 = "subc"; break;
      case OR: instr1 = instr2 = "or"; break;
      case AND: instr1 = instr2 = "and"; break;
      case XOR: instr1 = instr2 = "xor"; break;
      default: instr1 = "xxx"; break;
   };   
      
   emit(f, "; %s\n", instr1);

   // get type of argument
   typ = ztyp(p);   

// try to get z and q1 the same, if possible
   switch_IC(p); 
// handle required temporaries of 2op instructions	  
   track_ic(f, p);


   if (!ISINT(typ) && !ISPOINTER(typ)) terror("-- addsub: unexpected operands");
 
// Load Q1 into temporary register val if necessary.
// Automatically use temporary x->am->regptr if necessary.
   x = &p->q1;
   emit_load(f, x->am->regval[0], x, typ, 0, "mov");
   emit_load(f, x->am->regval[1], x, typ, 2, "mov");

// emit operation
   x = &p->z;
   if (x->am->regval[0]) {
// operation is performed on temporaries
      emit_load(f, x->am->regval[0], &p->q2, typ, 0, instr1);
      emit_load(f, x->am->regval[1], &p->q2, typ, 2, instr2);
   } else {
// operation is performed directly on target (z == q1 for this to work)
      emit_op(f, x, &p->q2, typ, 0, instr1);
   }

// emit store if necessary
   x = &p->z;
   if (x->am->regval[0]) {
      if (((x->flags & (REG|DREFOBJ)) != REG) && x->reg != x->am->regval[0]) { 
// only write store if target is not a register or in case it is a register it
// is not the same as the source.
         emit_store(f, x, x->am->regval[0], typ, 0);
         emit_store(f, x, x->am->regval[1], typ, 2);
      }
   }
// release temporaries
   track_release();
}                   	 


static void cg_lshift(FILE *f, struct IC *p)
{
// First we check if we can take a short-cut and don't need to
// call the library.
// [not done]

   lib_alu(f, p, "SHL");
}  
      
static void cg_rshift(FILE *f, struct IC *p)
{
// First we check if we can take a short-cut and don't need to
// call the library.
// [not done]

   lib_alu(f, p, "SHR");
}        
        

static void cg_mult(FILE *f, struct IC *p)
{
// First we check if we can take a short-cut and don't need to
// call the library.
// [not done]

   lib_alu(f, p, "MUL");
}        

static void cg_div(FILE *f, struct IC *p)
{
// First we check if we can take a short-cut and don't need to
// call the library.
// [not done]

   lib_alu(f, p, "DIV");
}        

static void cg_mod(FILE *f, struct IC *p)
{
// First we check if we can take a short-cut and don't need to
// call the library.
// [not done]

   lib_alu(f, p, "MOD");
} 
/*
modify IC such that we get
z = q1 xor 0xffff
*/
static void cg_komplement(FILE *f, struct IC *p)
{
   struct obj	*x;

   emit(f, "; komplement\n");

   p->code = XOR;

// change q2 to const 0
   x = &p->q2;
   x->flags = KONST;
   x->reg = 0;
   x->dtyp = 0;
// insert 0xffff
   gval.vmax = -1;
   eval_const(&gval, MAXINT);
   insert_const(&x->val, ztyp(p));

// transfer to alu
   cg_alu(f, p);
}    

/*
modify IC such that we get
z = 0 - q1
*/
static void cg_minus(FILE *f, struct IC *p)
{
   struct obj	*x;

   emit(f, "; minus\n");

   p->code = SUB;
   p->q2 = p->q1;

// change q1 to const 0
   x = &p->q1;
   x->flags = KONST;
   x->reg = 0;
   x->dtyp = 0;
// is this the right way of generating a constant?
   gval.vmax = 0;
   eval_const(&gval, MAXINT);
   insert_const(&x->val, ztyp(p));

// transfer to alu
   cg_alu(f, p);

}    

static void cg_address(FILE *f, struct IC *p)
{
   struct obj	*x;
   int		typ;
   long		ofs;
   int		reg;
   
// calculate offset into stack
   ofs = ofs_get(&p->q1);

// handle required temporaries of 1op instructions	   
   track_ic(f, p);

   emit(f, "; address\n");
   
// emit operation
   typ = ztyp(p);
   x = &p->z;
   reg = x->reg;
   if (x->am->regval[0]) {
      reg = x->am->regval[0];
   }
// emit operation
   emit(f, "\tmov\t%s, sp\n", regnames[reg]);
   if (ofs != 0) emit(f, "\tadd\t%s, %ld\n", regnames[reg], ofs);

// emit store if necessary
   typ = ztyp(p);
   x = &p->z;
   if (x->am->regval[0]) {
      if ((x->flags & (REG|DREFOBJ)) != REG) { 
// only write store if target is not a register 
         emit_store(f, x, x->am->regval[0], typ, 0);
      }
   }
// release temporaries
   track_release();
}

/*
modify IC such that we get
COMPARE q1, 0
*/
static void cg_test(FILE *f, struct IC *p)
{
   struct obj	*x;

   emit(f, "; test\n");

   p->code = COMPARE;

// change q2 to const 0
   x = &p->q2;
   x->flags = KONST;
   x->reg = 0;
   x->dtyp = 0;
// insert 0
   gval.vmax = 0;
   eval_const(&gval, MAXINT);
   insert_const(&x->val, ztyp(p));

}  

/*
Swap operands q1 <-> q2 of an IC. This is used by the branch IC
to map the operation to the available comaprisons.
*/
static void swap_operands(struct IC *p)
{
   struct obj y;
   y = p->q1;
   p->q1 = p->q2;
   p->q2 = y;
}

static void cg_branch_modify(struct IC *cmp, struct IC *p)
{
   int		c;
   int		q2_inc;
   int		swap;
   int		q2_konst;  

   
// grab the branch instruction
   c = p->code;
   
/*
In case Q1 == KONST we need to swap operands, however
this only makes a difference in case Q2 == REG.
This whole logic here might not be necessary if the front-end
always puts KONST in Q2. Test seem to confirm this, however for
the time being we leave the code in.
*/
   if (((cmp->q1.flags & (KONST|DREFOBJ)) == KONST) && ((cmp->q2.flags & (REG|DREFOBJ)) == REG)) {
// swap operands      
      swap_operands(cmp);
// modify branch condition to match operand swap
      switch (c) {
         case BLT: c = BGT; break;
         case BGE: c = BLE; break;
         case BLE: c = BGE; break;
         case BGT: c = BLT; break;
      }
   }

// Check if Q2 is a KONST. If it is we shouldn't swap operands.
   q2_konst = 0;
   if ((cmp->q2.flags & (KONST|DREFOBJ)) == KONST) {
      q2_konst = 1;
   }

// initialize modification falgs
   swap = 0;
   q2_inc = 0;

// decode jump and decide what modifications must be undertaken.
   switch (c) {
// equal ==, generate 'je'
      case BEQ: break;
// not equal !=, generate 'jne'      
      case BNE: break;
// less than '<'
      case BLT: break;
// greater equal '>='      
      case BGE: break;
// less equal '<=' 
// This must be changed into BLT or BGE     
      case BLE:
	 if (q2_konst) {
// Q2 is KONST, can't swap operands but must modify the constant
	    c = BLT;
	    q2_inc = 1;
	 } else {
// must swap operands to map to available comparison instructions
            c = BGE;
	    swap = 1;
	 }   
	 break;
// greater than '>'
      case BGT:
	 if (q2_konst) {
// Q2 is KONST, can't swap operands but must modify the constant
	    c = BGE;
	    q2_inc = 1;
	 } else {
// must swap operands to map to available comparison instructions
            c = BLT;
	    swap = 1;
	 }   
	 break;
   }

/* 
MODIFY IC if neccessary.
Modification looks like this:
If q2_inc == 1, we increment KONST q2 by 1.
If swap == 1, we swap operands.
Either way, we replace the  exisiting condition code with the new one.
*/
   if (swap) swap_operands(cmp);
   if (q2_inc) {
// partial constant
      struct obj *x; 
// increment Q2
      x = &cmp->q2;
// not sure if this is the way I'm supposed to do this
      eval_const(&x->val, q2typ(cmp));
      gval.vmax = zmadd(vmax, 1);
      eval_const(&gval, MAXINT);
      insert_const(&x->val, q2typ(cmp));
   }
// insert new condition code
   p->code = c;
}

//static void cg_branch

static void cg_branch(FILE *f, struct IC *p)
{
   struct IC	*cmp;
   int		c;
// size in bytes   
   long		size;
   int		typ;
   char		*sign;
// jump target
// The target in case the condition is satisfied
   long		target_true;
// the target in case the condition is violated
   long		target_false; 
// partial constant
   struct obj	*x; 
   
      
   if (q1typ(p) != q2typ(p)) terror(0);
 
   emit(f, "; compare\n");
   

// try to find compare IC
   cmp = p->prev;
   while (cmp && cmp->code == FREEREG) cmp = cmp->prev;
   if (!cmp || (cmp->code != COMPARE && cmp->code != TEST)) terror("-- cg_branch: compare not found");   

   typ = q1typ(cmp);
   size = sizetab[typ&NQ];

   if (!ISINT(typ)) terror("-- cg_branch: unexpected object type");
   
// get jump target
   target_true = (long)p->typf;
   target_false = label_count++;

   cg_branch_modify(cmp, p);

// grab the branch instruction
   c = p->code;

// determine sign/unsigned modifier
   sign = "s";
   if (typ & UNSIGNED) {
      sign = "u";
   }

// 1. step we allcoate necessay temporaries	  
   track_ic(f, cmp);

// We need to distinguish different operand sizes
   if (size <= 2) {
// First case takes care of CHAR and INT/SHORT
      x = &cmp->q1;
      emit_load(f, x->am->regval[0], x, typ, 0, "mov");
// emit operation
      if (x->am->regval[0]) {
// operation is performed on temporaries
         emit_load(f, x->am->regval[0], &cmp->q2, typ, 0, "cmp");
      } else {
// operation is performed directly on target (z == q1 for this to work)
         emit_op(f, x, &cmp->q2, typ, 0, "cmp");
      }
// must restore temporaries here,
      track_restore(f);

      switch (c) {
         case BLT:
            emit(f, "\tj%sl\t%s%ld\n", sign, label_prefix, target_true);
	    break;
         case BGE:
            emit(f, "\tj%sge\t%s%ld\n", sign, label_prefix, target_true);
	    break;
         case BEQ:
            emit(f, "\tje\t%s%ld\n", label_prefix, target_true);
	    break;
         case BNE:
            emit(f, "\tjne\t%s%ld\n", label_prefix, target_true);
	    break;
      }

   } else if (size == 4) {
// LONG
      x = &cmp->q1;
      emit_load(f, x->am->regval[0], x, typ, 0, "mov");
      emit_load(f, x->am->regval[1], x, typ, 2, "mov");
// emit operation
      if (x->am->regval[1]) {
// operation is performed on temporaries
         emit_load(f, x->am->regval[1], &cmp->q2, typ, 2, "cmp");
      } else {
// operation is performed directly on target (z == q1 for this to work)
         emit_op(f, x, &cmp->q2, typ, 2, "cmp");
      }
// must restore temporaries here,
      track_restore2(f);// (but don't release)
      switch (c) {
         case BLT:
            emit(f, "\tj%sl\t%s%ld\n", sign, label_prefix, target_true);
            emit(f, "\tjne\t%sn%ld\n", label_prefix, target_false);
	    break;
         case BGE:
            emit(f, "\tj%sl\t%sn%ld\n", sign, label_prefix, target_false);
            emit(f, "\tjne\t%s%ld\n", label_prefix, target_true);
	    break;
         case BEQ:
            emit(f, "\tjne\t%sn%ld\n", label_prefix, target_false);
	    break;
         case BNE:
            emit(f, "\tjne\t%sn%ld\n", label_prefix, target_true);
	    break;
      }
// here we have to reallocate temporary. HOWEVER if done cleverly we don't have
// to reload it, I have to think about the whole thing a litte bit.
  // (reload what is needed, use same temps as above)
 emit_load(f, x->am->regval[0], x, typ, 0, "mov");

      // emit operation
      if (x->am->regval[0]) {
// operation is performed on temporaries
         emit_load(f, x->am->regval[0], &cmp->q2, typ, 0, "cmp");
      } else {
// operation is performed directly on target (z == q1 for this to work)
         emit_op(f, x, &cmp->q2, typ, 0, "cmp");
      }
      track_restore(f); 
     switch (c) {
         case BLT:
            emit(f, "\tjuge\t%s%ld\n", label_prefix, target_true);
	    break;
         case BGE:
            emit(f, "\tjul\t%s%ld\n", label_prefix, target_true);
	    break;
         case BEQ:
            emit(f, "\tje\t%s%ld\n", label_prefix, target_true);
	    break;
         case BNE:
            emit(f, "\tjne\t%s%ld\n", label_prefix, target_true);
	    break;
      }
              
      
   } else {
      terror("branch size not supported");
   }

// emit "not taken" label
   emit(f, "%sn%ld:\n", label_prefix, target_false);

// release temporaries
   track_release();
}

static void cg_setreturn(FILE *f, struct IC *p)
{
   emit(f, "; set return\n");
   
   if (sizetab[ztyp(p)&NQ] > regsize[p->z.reg]) terror("-- cg_setreturn: size mismatch");
   emit_load(f, REG_R0, &p->q1, q1typ(p), 0, "mov");
}

static void cg_getreturn(FILE *f, struct IC *p)
{
   emit(f, "; get return\n");
   
   if (p->q1.reg) {
      emit_store(f, &p->z, p->q1.reg, ztyp(p), 0);
   }
}

static void cg_movefromreg(FILE *f, struct IC *p)
{
   emit_store(f, &p->z, p->q1.reg, ztyp(p), 0);
}

static void cg_movetoreg(FILE *f, struct IC *p)
{
   emit_load(f, p->z.reg, &p->q1, ztyp(p), 0, "mov");
}

/****************************************/
/*  End of private data and functions.  */
/****************************************/

/*  Does necessary initializations for the code-generator. Gets called  */
/*  once at the beginning and should return 0 in case of problems.      */
int init_cg(void)
{
   int		i;
   int		nregs;
   int		rtmp;
   int		rsave;
   
/*  Initialize some values which cannot be statically initialized   */
 /*  because they are stored in the target's arithmetic.             */
   maxalign = l2zm(2L);
   char_bit = l2zm(8L);

   sizetab[0] = 1; typname[0] = "strange"; align[0] = 1;
   sizetab[CHAR] = 1; typname[CHAR] = "char"; align[CHAR] = 1;
   sizetab[SHORT] = 2; typname[SHORT] = "short"; align[SHORT] = 2;
   sizetab[INT] = 2; typname[INT] = "int"; align[INT] = 2;
   sizetab[LONG] = 4; typname[LONG] = "long"; align[LONG] = 2;
   sizetab[LLONG] = 8; typname[LLONG] = "long long"; align[LLONG] = 2;
   sizetab[FLOAT] = 4; typname[FLOAT] = "float"; align[FLOAT] = 2;
   sizetab[DOUBLE] = 8; typname[DOUBLE] = "double"; align[DOUBLE] = 2;
   sizetab[LDOUBLE] = 8; typname[LDOUBLE] = "long double"; align[LDOUBLE] = 2;
   sizetab[VOID] = 0; typname[VOID] = "void"; align[VOID] = 1;
   sizetab[POINTER] = 2; typname[POINTER] = "pointer"; align[POINTER] = 2;
   sizetab[ARRAY] = 0; typname[ARRAY] = "array"; align[ARRAY] = 1;
   sizetab[STRUCT] = 0; typname[STRUCT] = "struct"; align[STRUCT] = 1;
   sizetab[UNION] = 0; typname[UNION] = "union"; align[UNION] = 1;
   sizetab[ENUM] = 2; typname[ENUM] = "enum"; align[ENUM] = 2;
   sizetab[FUNKT] = 0; typname[FUNKT] = "function"; align[FUNKT] = 1;
   sizetab[MAXINT] = 0;

// fill in the default register description
   regnames[0] = "noreg";
   regnames[REG_R0] = "r0";
   regnames[REG_R1] = "r1";
   regnames[REG_R2] = "r2";
   regnames[REG_R3] = "r3";
   regnames[REG_R4] = "r4";   
   regnames[REG_R5] = "r5";
   regnames[REG_R6] = "r6";
   regnames[REG_R7] = "r7";
   regnames[REG_R8] = "r8";
   regnames[REG_R9] = "r9";
   regnames[REG_R10] = "r10";
   regnames[REG_R11] = "r11";
   regnames[REG_R12] = "r12";
   regnames[REG_R13] = "r13";

   for (i = 1; i < MAXR+1; i++) {
      regsize[i] = l2zm(2L);
      regtype[i] = &ltyp;
      regscratch[i] = 1;
      regsa[i] = 0;
      reg_prio[i] = 1;
// private register tracking system
// Indicate register is available as temporary.
      track_status[i] = 0;
   }

// default numbers of registers to use
   nregs = 6;
// check command line flags for number of registers
   if (g_flags[0] & USEDFLAG) {
      nregs = g_flags_val[0].l;
   }
   if (nregs < 3) nregs = 3;
   if (nregs > 14) nregs = 14;  
// limit available registers to 'nregs'
   for (i = REG_R0+nregs; i <= REG_R13; i++) {
      regsa[i] = 1;
      regscratch[i] = 0;
      track_status[i] |= TRACK_OFFLIMITS;
   }

// get the number of temporary registers to reserve
   if (g_flags[2] & USEDFLAG) {
      rtmp = g_flags_val[1].l;
   } else {
      rtmp = 0;
      if (nregs >= 6) rtmp = 1;
      if (nregs >= 9) rtmp = 2;
      if (nregs >= 12) rtmp = 3;
   }
   if (rtmp < 0) rtmp = 0;
   if (rtmp > 3) rtmp = 3;

// remove temporary registers from code generator pool (on the top side)
   for (i = nregs-rtmp; i < nregs; i++) {
      regsa[REG_R0+i] = 1;
      regscratch[REG_R0+i] = 0;
// indicate to tracked that this is a dedicated temporary register
      track_status[REG_R0+i] |= TRACK_DEDICATED;
   }

// get numbers of registers to save across function calls
   if (g_flags[1] & USEDFLAG) {
      rsave = g_flags_val[1].l;
   } else {
      rsave = 0;
// automatically select 
      if (nregs >= 6) rsave = 2;
      if (nregs >= 10) rsave = 4;
   }
   if (rsave < 0) rsave = 0;
   if (rsave > nregs-rtmp) rsave = nregs-rtmp;

   for (i = 0; i < rsave; i++) {
      regscratch[REG_R0+nregs-rtmp-rsave+i] = 0;
   }
   
// SP is special
   regnames[REG_SP] = "sp";
   regscratch[REG_SP] = 0;
   regsa[REG_SP] = 1;
   track_status[REG_SP] |= TRACK_OFFLIMITS;
// and FLAGS is special
   regnames[REG_FLAGS] = "flags";
   regscratch[REG_FLAGS] = 0;
   regsa[REG_FLAGS] = 1;
   track_status[REG_FLAGS] |= TRACK_OFFLIMITS;

// print some status to the screen
   printf("Falco16 CPU information\n");
   printf("   GP registers: %d\n", nregs);
   printf("   temporaries:  %d\n", rtmp);
   printf("   saves:        %d\n", rsave);



  /*  Don't use multiple ccs.   */
  multiple_ccs = 0;

  /*  Initialize the min/max-settings. Note that the types of the     */
  /*  host system may be different from the target system and you may */
  /*  only use the smallest maximum values ANSI guarantees if you     */
  /*  want to be portable.                                            */
  /*  That's the reason for the subtraction in t_min[INT]. Long could */
  /*  be unable to represent -2147483648 on the host system.          */
  t_min[CHAR]=l2zm(-128L);
  t_min[SHORT]=l2zm(-32768L);
  t_min[INT]=t_min(SHORT);
  t_min[LONG]=zmsub(l2zm(-2147483647L),l2zm(1L));
  t_min[LLONG]=zmlshift(l2zm(1L),l2zm(63L));
  t_min[MAXINT]=t_min(LLONG);
  
  t_max[CHAR]=ul2zum(127L);
  t_max[SHORT]=ul2zum(32767UL);
  t_max[INT]=t_max(SHORT);
  t_max[LONG]=ul2zum(2147483647UL);
  t_max[LLONG]=zumrshift(zumkompl(ul2zum(0UL)),ul2zum(1UL));
  t_max[MAXINT]=t_max(LLONG);
  
  tu_max[CHAR]=ul2zum(255UL);
  tu_max[SHORT]=ul2zum(65535UL);
  tu_max[INT]=t_max(UNSIGNED|SHORT);
  tu_max[LONG]=ul2zum(4294967295UL);
  tu_max[LLONG]=zumkompl(ul2zum(0UL));
  tu_max[MAXINT]=t_max(UNSIGNED|LLONG);
  

  target_macros=marray;

// local label counter
  label_count = 0;

  return 1;
}

void init_db(FILE *f)
{
}

int freturn(struct Typ *t)
/*  Returns the register in which variables of type t are returned. */
/*  If the value cannot be returned in a register returns 0.        */
/*  A pointer MUST be returned in a register. The code-generator    */
/*  has to simulate a pseudo register if necessary.                 */
{
   int	       ret;
   int	       p;
   
   ret = 0;
   p = t->flags & NQ;
   
   if (sizetab[p] <= regsize[REG_R0]) ret = REG_R0;
  
   return ret;
}

int reg_pair(int r, struct rpair *p)
/* Returns 0 if the register is no register pair. If r  */
/* is a register pair non-zero will be returned and the */
/* structure pointed to p will be filled with the two   */
/* elements.                                            */
{
  return 0;
}


int regok(int r, int t, int mode)
/*  Returns 0 if register r cannot store variables of   */
/*  type t. If t==POINTER and mode!=0 then it returns   */
/*  non-zero only if the register can store a pointer   */
/*  and dereference a pointer to mode.                  */
{
// simple paramtere check   
   if(r == 0) return 0;

// if floating point, we don't keep them in registers at all
   if (ISFLOAT(t)) return 0;

// Must be integer or pointer, keep them in register if possible. 
   t &= NQ;
   if (sizetab[t] <= regsize[r]) return 1;
   
   return 0;
}

int dangerous_IC(struct IC *p)
/*  Returns zero if the IC p can be safely executed     */
/*  without danger of exceptions or similar things.     */
/*  vbcc may generate code in which non-dangerous ICs   */
/*  are sometimes executed although control-flow may    */
/*  never reach them (mainly when moving computations   */
/*  out of loops).                                      */
/*  Typical ICs that generate exceptions on some        */
/*  machines are:                                       */
/*      - accesses via pointers                         */
/*      - division/modulo                               */
/*      - overflow on signed integer/floats             */
{

  return 0;
}

int must_convert(int src, int dst, int const_expr)
{
   int		srcp = src & NQ;
   int		dstp = dst & NQ;

   if (ISINT(src) && ISINT(dst)) {
      if (sizetab[srcp] >= sizetab[dstp]) return 0;
     // if (sizetab[srcp] == 1 && sizetab[dstp] == 2) return 0;        
   } else if (ISINT(src) && ISPOINTER(dst)) {
      if (sizetab[srcp] >= sizetab[dstp]) return 0;
     // if (sizetab[srcp] == 1 && sizetab[dstp] == 2) return 0;        
   } else if (ISPOINTER(src) && ISINT(dst)) {
      if (sizetab[srcp] >= sizetab[dstp]) return 0;
    //  if (sizetab[srcp] == 1 && sizetab[dstp] == 2) return 0;        
   } 
   
// no conversion when src and dst are same type   
   if (src == dst) return 0;

   
   return 1;
}

/* Return name of library function, if this node should be
   implemented via libcall. */
char *use_libcall(np p)
{

/*
   following operations go into library

N - native
L - library call (some paramters are implemented native)
A - library call (all the time)
X - not supported
- - not valid (not generated by front-end)
? - what to do?

            CHAR  SHORT/INT  LONG  LLONG  FLOAT  DOUBLE  LDOUBLE

CMP          N        N        N     X      ?      X       X
OR           N        N        N     X      -      -       -
XOR          N        N        N     X      -      -       -
AND          N        N        N     X      -      -       -
LSHIFT       L        L        L     X      -      -       -
RSHIFT       L        L        L     X      -      -       -
ADD          N        N        N     X      A      X       X
SUB          N        N        N     X      A      X       X
MULT         L        L        L     X      A      X       X
DIV          L        L        L     X      A      X       X
MOD          L        L        L     X      A      X       X
*/

   static char	fname[16];
   char		*ret;
   int		f;
   char		*sign;
   char		*dtype;
   int		code;

   if(p->flags>=EQUAL&&p->flags<=GREATEREQ){
   extern struct Typ *arith_typ();
    struct Typ *t=arith_typ(p->left->ntyp,p->right->ntyp);
    f=t->flags&NU;
    freetyp(t);
    if((f&NQ)==LLONG){
      sprintf(fname,"__cmp%s%sll",ename[p->flags],(f&UNSIGNED)&&p->flags!=EQUAL&&p->flags!=INEQUAL?"u":"");
      ret=fname;
    }else if((f&NQ)==FLOAT){
      sprintf(fname,"__cmp%s%sf",ename[p->flags],(f&UNSIGNED)&&p->flags!=EQUAL&&p->flags!=INEQUAL?"u":"");
      ret=fname;
    }else if((f&NQ)==DOUBLE||(f&NQ)==LDOUBLE){
      sprintf(fname,"__cmp%s%sd",ename[p->flags],(f&UNSIGNED)&&p->flags!=EQUAL&&p->flags!=INEQUAL?"u":"");
      ret=fname;
    }
   }else{
// get code of operation
      code = p->flags;
// get data type
      f = p->ntyp->flags & NU;

      sign = "s";
      if (f & UNSIGNED) {
         sign = "u";
      }

      switch (f & NQ) {
         case CHAR: dtype = "i8"; break;
         case SHORT:
         case INT: dtype = "i16"; break;
         case LONG: dtype = "i32"; break;
         case FLOAT: dtype = "f32"; break;
         case DOUBLE: dtype = "f64"; break;
         default: dtype = ""; break;
            terror("--use_libcall: data type not supported");
	    break;
      }
// default is no function
      ret = 0;
      switch (code) {
         case LSHIFT: sprintf(fname, "__shl_%s%s", sign, dtype); ret = fname; break;
         case RSHIFT: sprintf(fname, "__shr_%s%s", sign, dtype); ret = fname; break;
         case ADD:
	    if (ISFLOAT(f)) { sprintf(fname, "__add_%s", dtype); ret = fname; }
	    break;
	 case SUB:
	    if (ISFLOAT(f)) { sprintf(fname, "__sub_%s", dtype); ret = fname; }
	    break;
	 case MINUS:
	    if (ISFLOAT(f)) { sprintf(fname, "__neg_%s", dtype); ret = fname; }
	    break;
	 case MULT: sprintf(fname, "__mul_%s%s", sign, dtype); ret = fname; break;
	 case DIV:
	    sprintf(fname, "__div_%s%s", sign, dtype); ret = fname;
	    break;
	 case MOD:
	    sprintf(fname, "__mod_%s%s", sign, dtype); ret = fname;
	    break;
      }
   }
  
   if(ret){
/* declare function if necessary */
      struct struct_declaration *sd;struct Typ *t;
      if(!find_ext_var(ret)){
         sd = mymalloc(sizeof(*sd));
         sd->count = 0;
         t = new_typ();
         t->flags = FUNKT;
         t->exact = add_sd(sd, FUNKT);
         t->next = clone_typ(p->ntyp);
         add_var(ret, t, EXTERN, 0);
      }
   }
   return ret;
}



void gen_ds(FILE *f, zmax size, struct Typ *t)
/*  This function has to create <size> bytes of storage */
/*  initialized with zero.                              */
{
   if (newobj) {
      emit(f, "\tdb\tdup(%ld, 0)\n", zm2l(size));
   } else {
      emit (f, "-- somehting's wrong\n");
   }     
   newobj = 0;
}

void gen_align(FILE *f, zmax align)
/*  This function has to make sure the next data is     */
/*  aligned to multiples of <align> bytes.              */
{
   int p;
   p = p; 
}

void gen_var_head(FILE *f, struct Var *v)
/*  This function has to create the head of a variable  */
/*  definition, i.e. the label and information for      */
/*  linkage etc.                                        */
{
   int		constflag;

   if (v->clist) constflag = is_const(v->vtyp);
   if (v->storage_class == STATIC) {
      if ((v->vtyp->flags&NQ) == FUNKT) return;
      if (v->clist && (!constflag) && section != SEC_DATA) {
         emit(f, "\n\tsection\t%s\n", sec_dataname);
         if (f) section = SEC_DATA;
      }
      if (v->clist && constflag && section != SEC_RODATA) {
         emit(f, "\n\tsection\t%s\n", sec_rodataname);
         if (f) section = SEC_RODATA;
      }
      if (!v->clist && section != SEC_BSS) {
         emit(f, "\n\tsection\t%s\n", sec_bssname);
         if (f) section = SEC_BSS;
      }
      emit(f, "%s%ld:", label_prefix, zm2l(v->offset));

      newobj = 1;
   }
   if (v->storage_class == EXTERN) {
      if (v->flags & (DEFINED|TENTATIVE)) {
         if (v->clist && (!constflag) && section != SEC_DATA) {
            emit(f, "\n\tsection\t%s\n", sec_dataname);
            if (f) section=SEC_DATA;
         }
         if (v->clist && constflag && section != SEC_RODATA) {
            emit(f, "\n\tsection\t%s\n", sec_rodataname); 
            if(f) section = SEC_RODATA;
         }
         if (!v->clist && section != SEC_BSS) {
            emit(f, "\n\tsection\t%s\n", sec_bssname);
            if (f) section = SEC_BSS;
         }
         emit(f, "\tpublic\t%s%s\n", ident_prefix, v->identifier);
         emit(f, "%s%s:", ident_prefix, v->identifier);
         newobj = 1;
      }
   }
}

void gen_dc(FILE *f, int t, struct const_list *p)
/*  This function has to create static storage          */
/*  initialized with const-list p.                      */
{
   emit(f, "\t%s\t", dct[t&NQ]);
   if (!p->tree) {
      if ((t&NQ) == FLOAT || (t&NQ) == DOUBLE) {
         emit(f, "-- floating point not supported\n");
      } else {
	 emitval(f, &p->val, t&NU);
      }
   } else {
         emit(f, "-- gen_dc: what the hell\n");
   }
   emit(f, "\n");
   newobj = 0;
}


/*  The main code-generation routine.                   */
/*  f is the stream the code should be written to.      */
/*  p is a pointer to a doubly linked list of ICs       */
/*  containing the function body to generate code for.  */
/*  v is a pointer to the function.                     */
/*  offset is the size of the stackframe the function   */
/*  needs for local variables.                          */

void gen_code(FILE *f, struct IC *p, struct Var *v, zmax offset)
/*  The main code-generation.                                           */
{
   struct IC	*head;
   int		c;
  
   if (DEBUG&1) printf("gen_code()\n");
   
   loff = ((zm2l(offset) + 1) / 2) * 2;
   stackoffset = 0;
   cd_function_entry(f, v, loff);
   
// initialize temporary register tracking
   track_init();

   head = p;
   for(; p; p = p->next){
// print: this doesn't work right, due to emit buffer
   printic(f, p);
   emit(f, "; stackoffset: %d\n", stackoffset);

// get operation code      
      c = p->code;
      
      switch (c) {
         case NOP: 
            break;
            
         case ASSIGN:
	 case CONVERT:
            cg_assign(f, p);
            break; 
         
         case LSHIFT:
            cg_lshift(f, p);
            break;
         case RSHIFT:
            cg_rshift(f, p);
            break;
            
         case ADD:
         case ADDI2P:
         case SUB:
         case SUBIFP:
         case OR:
         case XOR:
         case AND:
            cg_alu(f, p);
            break;
         
         case MULT:
            cg_mult(f, p);
            break;

         case DIV:
            cg_div(f, p);
            break;

         case MOD:
            cg_mod(f, p);
            break;
         
         case KOMPLEMENT:
            cg_komplement(f, p);
            break;

         case MINUS:
            cg_minus(f, p);
            break;
            
         case ADDRESS:
            cg_address(f, p);
            break;   
            
         case TEST:
// change TEST into COMPARE
            cg_test(f, p);
            break;
	 
         case COMPARE:
// This is handled by the branch IC. Nothing to do here.
            break;     
               
         case LABEL:
// must restore all temporaries before any label
// This is not good, as vbcc seems to be generating more labels than necessaty,
// pretty much defeating our clever system. We must do some more processing here.
            track_restore(f);
            emit(f, "%s%ld:\n", label_prefix, (long)p->typf);
            break;
            
         case BEQ:
         case BNE:
         case BLT:
         case BGE:
         case BLE:
         case BGT:
            cg_branch(f, p);
            break;      
         case BRA:
// restore temporaries
            track_restore(f);
            emit(f, "\tjmp\t%s%ld\n", label_prefix, (long)p->typf);
            break;
               
         case PUSH:
            cg_push(f, p);
            break;

         case CALL:
            cg_call(f, p);
            break;
            
         case SETRETURN:
            cg_setreturn(f, p);
            break;   

         case GETRETURN:
            cg_getreturn(f, p);
            break;
            
         case ALLOCREG:
// register is being used, indicate it can only be used if saved
            track_status[p->q1.reg] |= TRACK_ALLOCREG;
            break;
            
         case FREEREG:
// register is again free
            track_status[p->q1.reg] &= ~(TRACK_ALLOCREG);
            break; 
        
         case MOVEFROMREG:
            cg_movefromreg(f, p);       
	    break;
            
         case MOVETOREG:
	    cg_movetoreg(f, p);
            break;
            
            
         default:
            emit(f, "unhandled IC\n");
      }
      emit(f, "\n");   
   }   
   cg_function_exit(f, v, loff);

}

int shortcut(int code, int typ)
{
   if (sizetab[typ&NQ] > 2) return 0;
   return 1;
}


void cleanup_cg(FILE *f)
{
}
void cleanup_db(FILE *f)
{

}
