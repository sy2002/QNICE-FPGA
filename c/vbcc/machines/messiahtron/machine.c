/*  Example backend for vbcc, it models a generic 32bit RISC or CISC
CPU.

Configurable at build-time are:
- number of (32bit) general-purpose-registers
- number of (64bit) floating-point-registers
- number of (8bit) condition-code-registers
- mechanism for stack-arguments (moving ot fixed sp)

It allows to select as run-time-options:
- two- or three-address code
- memory operands or load-store-architecture
- number of register-arguments
- number of caller-save-registers
*/                                                                             

#include "../../supp.h"

static char FILE_[]=__FILE__;

/*  Public data that MUST be there.                             */

/* Name and copyright. */
char cg_copyright[]="vbcc Messiahtron code-generator "__DATE__" (c) in 2008 by Andrew Price";

/*  Commandline-flags the code-generator accepts:
0: just a flag
VALFLAG: a value must be specified
STRINGFLAG: a string can be specified
FUNCFLAG: a function will be called
apart from FUNCFLAG, all other versions can only be specified once */
int g_flags[MAXGF]={0,0,
VALFLAG,VALFLAG,VALFLAG,
0,0,
VALFLAG,VALFLAG,0};

/* the flag-name, do not use names beginning with l, L, I, D or U, because
they collide with the frontend */
char *g_flags_name[MAXGF]={"three-addr","load-store",
"volatile-gprs","volatile-fprs","volatile-ccrs",
"imm-ind","gpr-ind",
"gpr-args","fpr-args","use-commons"};

/* the results of parsing the command-line-flags will be stored here */
union ppi g_flags_val[MAXGF];

/*  Alignment-requirements for all types in bytes.              */
zmax align[MAX_TYPE+1];

/*  Alignment that is sufficient for every object.              */
zmax maxalign;

/*  CHAR_BIT for the target machine.                            */
zmax char_bit;

/*  sizes of the basic types (in bytes) */
zmax sizetab[MAX_TYPE+1];

/*  Minimum and Maximum values each type can have.              */
/*  Must be initialized in init_cg().                           */
zmax t_min[MAX_TYPE+1];
zumax t_max[MAX_TYPE+1];
zumax tu_max[MAX_TYPE+1];

/*  Names of all registers. will be initialized in init_cg(),
register number 0 is invalid, valid registers start at 1 */
char *regnames[MAXR+1];

/*  The Size of each register in bytes.                         */
zmax regsize[MAXR+1];

/*  a type which can store each register. */
struct Typ *regtype[MAXR+1];

/*  regsa[reg]!=0 if a certain register is allocated and should */
/*  not be used by the compiler pass.                           */
int regsa[MAXR+1];

/*  Specifies which registers may be scratched by functions.    */
int regscratch[MAXR+1];

/* specifies the priority for the register-allocator, if the same
estimated cost-saving can be obtained by several registers, the
one with the highest priority will be used */
int reg_prio[MAXR+1];

/* an empty reg-handle representing initial state */
struct reg_handle empty_reg_handle={0,0};

/* Names of target-specific variable attributes.                */
char *g_attr_name[]={"__interrupt",0};


/****************************************/
/*  Private data and functions.         */
/****************************************/

#define THREE_ADDR (g_flags[0]&USEDFLAG)
#define LOAD_STORE (g_flags[1]&USEDFLAG)
//#define VOL_FIXED   NUM_FIXED
#define VOL_16BIT   ((g_flags[3]&USEDFLAG)?g_flags_val[3].l:NUM_16BIT/2)
#define VOL_32BIT   ((g_flags[4]&USEDFLAG)?g_flags_val[4].l:NUM_32BIT/2)
#define VOL_64BIT   ((g_flags[4]&USEDFLAG)?g_flags_val[5].l:NUM_64BIT/2)
#define VOL_8BIT   ((g_flags[4]&USEDFLAG)?g_flags_val[6].l:NUM_8BIT/2)
#define IMM_IND    ((g_flags[5]&USEDFLAG)?1:0)
#define GPR_IND    ((g_flags[6]&USEDFLAG)?2:0)
//#define ARGS8   ((g_flags[7]&USEDFLAG)?g_flags_val[7].l:1)
//#define ARGS16   ((g_flags[7]&USEDFLAG)?g_flags_val[7].l:0)
//#define ARGS32   ((g_flags[7]&USEDFLAG)?g_flags_val[7].l:0)
//#define ARGS64   ((g_flags[7]&USEDFLAG)?g_flags_val[7].l:0)
// #define FPR_ARGS   ((g_flags[8]&USEDFLAG)?g_flags_val[8].l:0)
//#define USE_COMMONS (g_flags[9]&USEDFLAG)


/* alignment of basic data-types, used to initialize align[] */
static long malign[MAX_TYPE+1]={1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
/* sizes of basic data-types, used to initialize sizetab[] */
static long msizetab[MAX_TYPE+1]={0,1,2,4,4,8,4,8,8,0,4,0,0,0,4,0};

/* used to initialize regtyp[] */
static struct Typ llong={LLONG},ltyp={LONG},lshort={SHORT},lchar={CHAR};

/* macros defined by the backend */
static char *marray[]={"__section(x)=__vattr(\"section(\"#x\")\")",
"__GENERIC__",
0};

/* special registers */
static int sp;                     /*  Stackpointer                        */
static int t8bit1,t8bit2;               /*  temporary gprs */
static int t16bit1,t16bit2;
static int t32bit1,t32bit2;
static int t64bit1,t64bit2;

#define dt(t) (((t)&UNSIGNED)?udt[(t)&NQ]:sdt[(t)&NQ])
static char *sdt[MAX_TYPE+1]={"??","c","s","i","l","ll","f","d","ld","v","p"};
static char *udt[MAX_TYPE+1]={"??","uc","us","ui","ul","ull","f","d","ld","v","p"};

/* sections */
#define DATA 0
#define BSS 1
#define CODE 2
#define RODATA 3
#define SPECIAL 4

static long stack;
static int stack_valid;
static int section=-1,newobj;
static char *codename=".resetlocals\n;code\n",
*dataname=";data\n",
*bssname=";bss\n",
*rodataname=";read only data\n";

/* return-instruction */
static char *ret;

/* label at the end of the function (if any) */
static int exit_label;

/* assembly-prefixes for labels and external identifiers */
static char *labprefix="l",*idprefix="_";

/* variables to keep track of the current stack-offset in the case of
a moving stack-pointer */
static long loff,stackoffset,notpopped,dontpop,maxpushed,stack;
static pushorder=2;

static long localsize,rsavesize,argsize;

/* pushed on the stack by a callee, no pop needed */
static void callee_push(long l)
{
}

static void push(long l)
{
	stackoffset-=l;
	if(stackoffset<maxpushed)
		maxpushed=stackoffset;
}
static void pop(long l)
{
	stackoffset+=l;
}

static void emit_obj(FILE *f,struct obj *p,int t);

/* calculate the actual current offset of an object relativ to the
stack-pointer; we use a layout like this:
------------------------------------------------
| arguments to this function                   |
------------------------------------------------
| return-address [size=4]                      |
------------------------------------------------
| caller-save registers [size=rsavesize]       |
------------------------------------------------
| local variables [size=localsize]             |
------------------------------------------------
| arguments to called functions [size=argsize] |
------------------------------------------------
All sizes will be aligned as necessary.
In the case of FIXED_SP, the stack-pointer will be adjusted at
function-entry to leave enough space for the arguments and have it
aligned to 16 bytes. Therefore, when calling a function, the
stack-pointer is always aligned to 16 bytes.
For a moving stack-pointer, the stack-pointer will usually point
to the bottom of the area for local variables, but will move while
arguments are put on the stack.

This is just an example layout. Other layouts are also possible.
*/

static long real_offset(struct obj *o)
{
	long off=zm2l(o->v->offset);
	if(off<0){
		/* function parameter */
		off=localsize+rsavesize+4-off-zm2l(maxalign);
	}

	off+=4;

	off+=stackoffset;
	off+=zm2l(o->val.vmax);
	return off;
}

/*  Initializes an addressing-mode structure and returns a pointer to
that object. Will not survive a second call! */
static struct obj *cam(int flags,int base,long offset)
{
	static struct obj obj;
	static struct AddressingMode am;
	obj.am=&am;
	am.flags=flags;
	am.base=base;
	am.offset=offset;
	return &obj;
}

/* changes to a special section, used for __section() */
static int special_section(FILE *f,struct Var *v)
{
	char *sec;
	if(!v->vattr) return 0;
	sec=strstr(v->vattr,"section(");
	if(!sec) return 0;
	sec+=strlen("section(");
	emit(f,"; section");
	while(*sec&&*sec!=')') emit_char(f,*sec++);
	emit(f,"\n");
	if(f) section=SPECIAL;
	return 1;
}

/* generate code to load the address of a variable into register r */
static void load_address(FILE *f,int r,struct obj *o,int type)
/*  Generates code to load the address of a variable into register r.   */
{
	if(!(o->flags&VAR))
		ierror(0);
	if(o->v->storage_class==AUTO||o->v->storage_class==REGISTER)
	{
		long off=real_offset(o);
		emit(f,"\tmov\t%s %s ; load_address %s\n",regnames[r],regnames[sp],dt(POINTER));
		if(off)
		{
			emit(f,"\tmov\tb30 %ld ; %s\n",off,dt(POINTER));
			emit(f,"\tsub\t%s b30 ; %s\n",regnames[r],dt(POINTER));
		}
	}
	else
	{
		emit(f,"\tmov\t%s ",regnames[r]);
		emit_obj(f,o,type);
		emit(f," ;%s\n", dt(POINTER));
	}
}
/* Generates code to load a memory object into register r. tmp is a
general purpose register which may be used. tmp can be r. */
static void load_reg(FILE *f,int r,struct obj *o,int type)
{
	type&=NU;
	if(o->flags&VARADR)
	{
		load_address(f,r,o,POINTER);
	}
	else
	{
		if((o->flags&(REG|DREFOBJ))==REG&&o->reg==r)
			return;
		if((o->flags&VAR)&&!(o->flags&REG))
		{
			if(o->v->storage_class==AUTO||o->v->storage_class==REGISTER)
			{
				unsigned long offset = real_offset(o);
				if(offset == 0)
				{
					emit(f,"\tmov\t%s\t[z2] ;%s\n",regnames[r],dt(type));
				}
				else
				{
					emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
					emit(f,"\tmov\tb29\tz2\n");
					emit(f,"\tsub\tb29\tb28\n");
					if(ISFLOAT(type))
						emit(f,"\tmovf\t%s\t[b29] ;%s\n",regnames[r],dt(type));
					else if((type & UNSIGNED) || type == POINTER || type == STRUCT)
						emit(f,"\tmov\t%s\t[b29] ;%s\n",regnames[r],dt(type));
					else
						emit(f,"\tmovs\t%s\t[b29] ;%s\n",regnames[r],dt(type));
				}

				return;
			}
		}

		if(ISFLOAT(type))
			emit(f,"\tmovf \t%s ",regnames[r]);
		else if((type & UNSIGNED) || type == POINTER || type == STRUCT)
			emit(f,"\tmov \t%s ",regnames[r]);
		else
			emit(f,"\tmovs \t%s ",regnames[r]);
		emit_obj(f,o,type);
		emit(f," ;%s\n",dt(type));
	}
}

/*  Generates code to store register r into memory object o. */
static void store_reg(FILE *f,int r,struct obj *o,int type)
{
	type&=NQ;

	if((o->flags&VAR)&&!(o->flags&REG))
	{

		if(o->v->storage_class==AUTO||o->v->storage_class==REGISTER)
		{
			unsigned long offset = real_offset(o);

			if(offset == 0)
			{
				if(ISFLOAT(type))
					emit(f,"\tmovf\t[z2]\t%s ;%s\n",regnames[r],dt(type));
				else if((type & UNSIGNED) || type == POINTER || type == STRUCT)
					emit(f,"\tmov\t[z2]\t%s ;%s\n",regnames[r],dt(type));
				else
					emit(f,"\tmovs\t[z2]\t%s ;%s\n",regnames[r],dt(type));
			}
			else
			{
				emit(f,"\tmov\tb28\t%ld ; mov to stack\n", offset);
				emit(f,"\tmov\tb29\tz2\n");
				emit(f,"\tsub\tb29\tb28\n");
				if(ISFLOAT(type))
					emit(f,"\tmovf\t[b29]\t%s ;%s\n",regnames[r],dt(type));
				else if((type & UNSIGNED) || type == POINTER || type == STRUCT)
					emit(f,"\tmov\t[b29]\t%s ;%s\n",regnames[r],dt(type));
				else
					emit(f,"\tmovs\t[b29]\t%s ;%s\n",regnames[r],dt(type));
			}
			return;
		}
	}
	if(r == 0)
		emit(f, ";");

	if(ISFLOAT(type))
		emit(f,"\tmovf\t");
	else if(type & UNSIGNED)
		emit(f,"\tmov\t");
	else
		emit(f,"\tmovs\t");

	emit_obj(f,o,type);
	emit(f,"\t%s ;%s\n",regnames[r],dt(type));
}

/*  Yields log2(x)+1 or 0. */
static long pof2(zumax x)
{
	zumax p;int ln=1;
	p=ul2zum(1L);
	while(ln<=32&&zumleq(p,x)){
		if(zumeqto(x,p)) return ln;
		ln++;p=zumadd(p,p);
	}
	return 0;
}

static struct IC *preload(FILE *,struct IC *);

static void function_top(FILE *,struct Var *,long);
static void function_bottom(FILE *f,struct Var *,long);

#define isreg(x) ((p->x.flags&(REG|DREFOBJ))==REG)
#define isconst(x) ((p->x.flags&(KONST|DREFOBJ))==KONST)

static int q1reg,q2reg,zreg;

/* Does some pre-processing like fetching operands from memory to
registers etc. */
static struct IC *preload(FILE *f,struct IC *p)
{
	int r;

	if(isreg(q1))
		q1reg=p->q1.reg;
	else
		q1reg=0;

	if(isreg(q2))
		q2reg=p->q2.reg;
	else
		q2reg=0;

//	emit(f," ; Preload register type %d\t%d z:%d\t%d\t ", q1typ(p), q1typ(p) & NQ, ztyp(p), ztyp(p) & NQ);

	if(isreg(z))
	{
		zreg=p->z.reg;
//		emit(f," is a reg ");
	}
	else
	{
		if((ztyp(p) & NQ) == CHAR)
		{
//			emit(f," is a 8 bit reg (1) ");
			zreg=t8bit1;
		}
		else if((ztyp(p) & NQ) == SHORT)
		{
//			emit(f," is a 16 bit reg (1) ");
			zreg=t16bit1;
		}
		else if((ztyp(p) & NQ) == LDOUBLE || (ztyp(p) & NQ) == LLONG || (ztyp(p) & NQ) == DOUBLE)
		{
//			emit(f," is a 64 bit reg (1) ");
			zreg=t64bit1;
		}
		else
		{
//			emit(f," is a 32 bit reg (1) ");
			zreg=t32bit1;
		}
	}

	if((p->q1.flags&(DREFOBJ|REG))==DREFOBJ&&!p->q1.am){
		p->q1.flags&=~DREFOBJ;
		if((q1typ(p) & NQ) == CHAR)
		{
			load_reg(f,t8bit1,&p->q1,q1typ(p));
			p->q1.reg=t8bit1;
//			emit(f," is a 8 bit reg (2) ");
		}
		else if((q1typ(p) & NQ) == SHORT)
		{
			load_reg(f,t16bit1,&p->q1,q1typ(p));
			p->q1.reg=t16bit1;
//			emit(f," is a 16 bit reg (2) ");
		}
		else if((q1typ(p) & NQ) == LDOUBLE || (q1typ(p) & NQ) == LLONG || (q1typ(p) & NQ) == DOUBLE)
		{
			load_reg(f,t64bit1,&p->q1,q1typ(p));
			p->q1.reg=t64bit1;
//			emit(f," is a 64 bit reg (2) ");
		}
		else
		{
			load_reg(f,t32bit1,&p->q1,q1typ(p));
			p->q1.reg=t32bit1;
//			emit(f," is a 32 bit reg (2) ");
		}
		p->q1.flags|=(REG|DREFOBJ);
	}
	if(p->q1.flags&&LOAD_STORE&&!isreg(q1)){
		if((q1typ(p) & NQ) == CHAR)
		{
			q1reg=t8bit1;
//			emit(f," is a 8 bit reg (3) ");
		}
		else if((q1typ(p) & NQ) == SHORT)
		{
			q1reg=t16bit1;
//			emit(f," is a 16 bit reg (3) ");
		}
		else if((q1typ(p) & NQ) == LDOUBLE || (q1typ(p) & NQ) == LLONG || (q1typ(p) & NQ) == DOUBLE)
		{
			q1reg=t64bit1;
//			emit(f," is a 64 bit reg (3) ");
		}
		else
		{
			q1reg=t32bit1;
//			emit(f," is a 32 bit reg (3) ");
		}
		load_reg(f,q1reg,&p->q1,q1typ(p));
		p->q1.reg=q1reg;
		p->q1.flags=REG;
	}

	if((p->q2.flags&(DREFOBJ|REG))==DREFOBJ&&!p->q2.am){
		p->q2.flags&=~DREFOBJ;
		if((q1typ(p) & NQ) == CHAR)
		{
			load_reg(f,t8bit1,&p->q2,q2typ(p));
			p->q2.reg=t8bit1;
//			emit(f," is a 8 bit reg (4) ");
		}
		else if((q1typ(p) & NQ) == SHORT)
		{
			load_reg(f,t16bit1,&p->q2,q2typ(p));
			p->q2.reg=t16bit1;
//			emit(f," is a 16 bit reg (4) ");
		}
		else if((q1typ(p) & NQ) == LDOUBLE || (q1typ(p) & NQ) == LLONG || (q1typ(p) & NQ) == DOUBLE)
		{
			load_reg(f,t64bit1,&p->q2,q2typ(p));
			p->q2.reg=t64bit1;
//			emit(f," is a 64 bit reg (4) ");
		}
		else
		{
			load_reg(f,t32bit1,&p->q2,q2typ(p));
			p->q2.reg=t32bit1;
//			emit(f," is a 32 bit reg (4) ");
		}

		p->q2.flags|=(REG|DREFOBJ);
	}
	if(p->q2.flags&&LOAD_STORE&&!isreg(q2)){
		if((q1typ(p) & NQ) == CHAR)
		{
			q2reg=t8bit1;
//			emit(f," is a 8 bit reg (5) ");
		}
		else if((q1typ(p) & NQ) == SHORT)
		{
			q2reg=t16bit1;
//			emit(f," is a 16 bit reg (5) ");
		}
		else if((q1typ(p) & NQ) == LDOUBLE || (q1typ(p) & NQ) == LLONG || (q1typ(p) & NQ) == DOUBLE)
		{
			q2reg=t64bit1;
//			emit(f," is a 64 bit reg (5) ");
		}
		else
		{
			q2reg=t32bit1;
//			emit(f," is a 32 bit reg (5) ");
		}

		load_reg(f,q2reg,&p->q2,q2typ(p));
		p->q2.reg=q2reg;
		p->q2.flags=REG;
	}

//	emit(f,"\n");
	return p;
}

/* save the result (in zreg) into p->z */
void save_result(FILE *f,struct IC *p)
{
	if((p->z.flags&(REG|DREFOBJ))==DREFOBJ&&!p->z.am){
		p->z.flags&=~DREFOBJ;
		if((p->typf & NQ) == CHAR)
		{
			load_reg(f,t8bit2,&p->z,POINTER);
			p->z.reg=t8bit2;
		}
		else if((p->typf & NQ) == SHORT)
		{
			load_reg(f,t16bit2,&p->z,POINTER);
			p->z.reg=t16bit2;
		}
		else if((p->typf & NQ) == LDOUBLE || (p->typf & NQ) == LLONG || (p->typf & NQ) == DOUBLE)
		{
			load_reg(f,t64bit2,&p->z,POINTER);
			p->z.reg=t64bit2;
		}
		else
		{
			load_reg(f,t32bit2,&p->z,POINTER);
			p->z.reg=t32bit2;
		}
		p->z.flags|=(REG|DREFOBJ);
		//printf("setting reg to %s\n", regnames[p->z.reg]);
	}

	if(isreg(z)){
		if(p->z.reg!=zreg)
			emit(f,"\tmov\t%s %s ;%s\n",regnames[p->z.reg],regnames[zreg],dt(ztyp(p)));
	}else{
		store_reg(f,zreg,&p->z,ztyp(p));
	}
}

/* prints an object */
static void emit_obj(FILE *f,struct obj *p,int t)
{
	//printf("type = %i\n", t);
	if((p->flags&(DREFOBJ|KONST))==(DREFOBJ|KONST))
	{
		emitval(f,&p->val,p->dtyp&NU);
		return;
	}
	if((p->flags&(DREFOBJ|REG))==(DREFOBJ|REG))
		emit(f,"[");

	if((p->flags&VAR)&&!(p->flags&REG))
	{
		if(!zmeqto(l2zm(0L),p->val.vmax))
		{
			emitval(f,&p->val,LONG);
			emit(f,"+");
		}
		if(p->v->storage_class==STATIC)
		{
			emit(f,"%s%ld", labprefix, zm2l(p->v->offset));
		}
		else
		{
			if(t == FUNKT)
				emit(f,"%s%s", idprefix, p->v->identifier);
			else if(p->flags&VARADR)
				emit(f,"%s%s", idprefix, p->v->identifier);
			else
				emit(f,"[%s%s]", idprefix, p->v->identifier);
		}
	}
	if(p->flags&REG)
	{
		emit(f, "%s", regnames[p->reg]);
	}
	if(p->flags&KONST)
	{
		if(ISFLOAT(t))
		{
			//			case FLOAT:
			char *values = (char *)&p->val.vfloat;
			// swap the order
			char tmp = values[0];
			values[0] = values[3];
			values[3] = tmp;
			tmp = values[1];
			values[1] = values[2];
			values[2] = tmp;

			emit(f, "0x%1X", *(unsigned int *)values);
			//				break;

			//			case DOUBLE:
			//				fprintf(fp, "[double #%08X]", obj->val.vdouble);
			//			emit(f,"0f%e",/*labprefix,*/p->val.vfloat);
			//			emit(f,"0f");
			//			emitval(f,&p->val,t&NU);
		}
		else if(t & UNSIGNED)
		{
			//			emit(f, "0u");
			emitval(f,&p->val,t&NU);
		}
		else
		{
			emit(f,"0s");
			emitval(f,&p->val,t&NU);
		}
	}
	if((p->flags&(DREFOBJ|REG))==(DREFOBJ|REG))
		emit(f,"]");
}

/*  Test if there is a sequence of FREEREGs containing FREEREG reg.
Used by peephole. */
static int exists_freereg(struct IC *p,int reg)
{
	while(p&&(p->code==FREEREG||p->code==ALLOCREG))
	{
		if(p->code==FREEREG&&p->q1.reg==reg)
			return 1;
		p=p->next;
	}
	return 0;
}

/* search for possible addressing-modes */
static void peephole(struct IC *p)
{
	int c,c2,r;
	struct IC *p2;
	struct AddressingMode *am;

	for(;p;p=p->next)
	{
		c=p->code;
		if(c != FREEREG && c != ALLOCREG && (c != SETRETURN || !isreg(q1) || p->q1.reg != p->z.reg))
			exit_label=0;
		if(c==LABEL)
			exit_label=p->typf;

		/* Try const(reg) */
		if(IMM_IND&&(c==ADDI2P||c==SUBIFP)&&isreg(z)&&(p->q2.flags&(KONST|DREFOBJ))==KONST)
		{
			int base;zmax of;struct obj *o;
			eval_const(&p->q2.val,p->typf);
			if(c==SUBIFP) of=zmsub(l2zm(0L),vmax); else of=vmax;
			if(1/*zmleq(l2zm(-32768L),vmax)&&zmleq(vmax,l2zm(32767L))*/)
			{
				r=p->z.reg;
				if(isreg(q1))
					base=p->q1.reg;
				else
					base=r;
				o=0;
				for(p2=p->next;p2;p2=p2->next)
				{
					c2=p2->code;
					if(c2==CALL||c2==LABEL||(c2>=BEQ&&c2<=BRA))
						break;
					if(c2!=FREEREG&&(p2->q1.flags&(REG|DREFOBJ))==REG&&p2->q1.reg==r)
						break;
					if(c2!=FREEREG&&(p2->q2.flags&(REG|DREFOBJ))==REG&&p2->q2.reg==r)
						break;
					if(c2!=CALL&&(c2<LABEL||c2>BRA)/*&&c2!=ADDRESS*/)
					{
						if(!p2->q1.am&&(p2->q1.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->q1.reg==r)
						{
							if(o) break;
							o=&p2->q1;
						}
						if(!p2->q2.am&&(p2->q2.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->q2.reg==r)
						{
							if(o) break;
							o=&p2->q2;
						}
						if(!p2->z.am&&(p2->z.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->z.reg==r)
						{
							if(o) break;
							o=&p2->z;
						}
					}
					if(c2==FREEREG||(p2->z.flags&(REG|DREFOBJ))==REG)
					{
						int m;
						if(c2==FREEREG)
							m=p2->q1.reg;
						else
							m=p2->z.reg;
						if(m==r)
						{
							if(o)
							{
								o->am=am=mymalloc(sizeof(*am));
								am->flags=IMM_IND;
								am->base=base;
								am->offset=zm2l(of);
								if(isreg(q1))
								{
									p->code=c=NOP;p->q1.flags=p->q2.flags=p->z.flags=0;
								}
								else
								{
									p->code=c=ASSIGN;p->q2.flags=0;
									p->typf=p->typf2;p->q2.val.vmax=sizetab[p->typf2&NQ];
								}
							}
							break;
						}
						if(c2!=FREEREG&&m==base)
							break;
						continue;
					}
				}
			}
		}
		/* Try reg,reg */
		if(GPR_IND&&c==ADDI2P&&isreg(q2)&&isreg(z)&&(isreg(q1)||p->q2.reg!=p->z.reg))
		{
			int base,idx;struct obj *o;
			r=p->z.reg;idx=p->q2.reg;
			if(isreg(q1)) base=p->q1.reg; else base=r;
			o=0;
			for(p2=p->next;p2;p2=p2->next)
			{
				c2=p2->code;
				if(c2==CALL||c2==LABEL||(c2>=BEQ&&c2<=BRA))
					break;
				if(c2!=FREEREG&&(p2->q1.flags&(REG|DREFOBJ))==REG&&p2->q1.reg==r)
					break;
				if(c2!=FREEREG&&(p2->q2.flags&(REG|DREFOBJ))==REG&&p2->q2.reg==r)
					break;
				if((p2->z.flags&(REG|DREFOBJ))==REG&&p2->z.reg==idx&&idx!=r)
					break;

				if(c2!=CALL&&(c2<LABEL||c2>BRA)/*&&c2!=ADDRESS*/)
				{
					if(!p2->q1.am&&(p2->q1.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->q1.reg==r)
					{
						if(o||(q1typ(p2)&NQ)==LLONG) break;
						o=&p2->q1;
					}
					if(!p2->q2.am&&(p2->q2.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->q2.reg==r)
					{
						if(o||(q2typ(p2)&NQ)==LLONG) break;
						o=&p2->q2;
					}
					if(!p2->z.am&&(p2->z.flags&(REG|DREFOBJ))==(REG|DREFOBJ)&&p2->z.reg==r)
					{
						if(o||(ztyp(p2)&NQ)==LLONG) break;
						o=&p2->z;
					}
				}
				if(c2==FREEREG||(p2->z.flags&(REG|DREFOBJ))==REG)
				{
					int m;
					if(c2==FREEREG)
						m=p2->q1.reg;
					else
						m=p2->z.reg;
					if(m==r)
					{
						if(o)
						{
							o->am=am=mymalloc(sizeof(*am));
							am->flags=GPR_IND;
							am->base=base;
							am->offset=idx;
							if(isreg(q1))
							{
								p->code=c=NOP;p->q1.flags=p->q2.flags=p->z.flags=0;
							}
							else
							{
								p->code=c=ASSIGN;p->q2.flags=0;
								p->typf=p->typf2;p->q2.val.vmax=sizetab[p->typf2&NQ];
							}
						}
						break;
					}
					if(c2!=FREEREG&&m==base) break;
					continue;
				}
			}
		}
	}
}

static void pr(FILE *f,struct IC *p)
{
	int i;
	for(;pushorder>2;pushorder>>=1)
	{
		for(i=1;i<=8;i++)
		{
			if(regs[i]&pushorder)
			{
				if(p->code==PUSH||p->code==CALL)
				{
					//emit(f,"\tmovl\t%ld(%s),%s\n",loff-4-stackoffset,regnames[sp],regnames[i]);
				}
				else
				{
					emit(f,"\tpop\t%s\n",regnames[i]);
					pop(4);
				}
				regs[i]&=~pushorder;
			}
		}
	}
	for(i=1;i<=8;i++)
		if(regs[i]&2) regs[i]&=~2;
}

/* generates the function entry code */
static void function_top(FILE *f,struct Var *v,long offset)
{
	rsavesize=0;
	if(!special_section(f,v)&&section!=CODE){emit(f,codename);if(f) section=CODE;} 
	if(v->storage_class==EXTERN)
	{
		if((v->flags&(INLINEFUNC|INLINEEXT))!=INLINEFUNC)
			emit(f,".global ");
		//      emit(f,"\t.global\t%s%s\n",idprefix,v->identifier);
		emit(f,"%s%s:\n",idprefix,v->identifier);
	}
	else
		emit(f,"%s%ld:\n",labprefix,zm2l(v->offset));

	// reserve enough in stack for local functions
	if(offset > 0)
	{
		emit(f,"\tmov\tb28\t%d\n", offset);
		emit(f,"\tadd\tz2\tb28 ;reserve %d on stack\n", offset);
	}
}
/* generates the function exit code */
static void function_bottom(FILE *f,struct Var *v,long offset)
{
	// reserve enough in stack for local functions
	if(offset > 0)
	{
		emit(f,"\tmov\tb28\t%d\n", offset);
		emit(f,"\tsub\tz2\tb28 ;reserve %d on stack\n", offset);
	}

	emit(f,ret);
}

/****************************************/
/*  End of private data and functions.  */
/****************************************/

/*  Does necessary initializations for the code-generator. Gets called  */
/*  once at the beginning and should return 0 in case of problems.      */
int init_cg(void)
{
	int i;
	/*  Initialize some values which cannot be statically initialized   */
	/*  because they are stored in the target's arithmetic.             */
	maxalign=l2zm(1L);
	char_bit=l2zm(8L);

	for(i=0;i<=MAX_TYPE;i++)
	{
		sizetab[i]=l2zm(msizetab[i]);
		align[i]=l2zm(malign[i]);
	}

	regnames[0]="noreg";
	regtype[0]=mymalloc(sizeof(struct Typ));
	//	for(i=FIRST_FIXED;i<=LAST_FIXED;i++)
	//	{
	//		regnames[i]=mymalloc(10);
	//		sprintf(regnames[i],"b%d",(i-FIRST_FIXED) + 27);
	//		regsize[i]=4;
	//		regtype[i]=&ltyp;
	//	}

	// static struct Typ lltype={LLONG},ltyp={LONG},lshort={SHORT},lchar={CHAR};

	for(i=FIRST_16BIT;i<=LAST_16BIT;i++)
	{
		regnames[i]=mymalloc(10);
		sprintf(regnames[i],"a%d",i-FIRST_16BIT);
		regsize[i]=2;
		regtype[i]=mymalloc(sizeof(struct Typ));
	}

	for(i=FIRST_32BIT;i<=LAST_32BIT;i++)
	{
		regnames[i]=mymalloc(10);
		sprintf(regnames[i],"b%d",(i-FIRST_32BIT) + 5);
		regsize[i]=4;
		regtype[i]=mymalloc(sizeof(struct Typ));
	}

	for(i=FIRST_64BIT;i<=LAST_64BIT;i++)
	{
		regnames[i]=mymalloc(10);
		sprintf(regnames[i],"c%d",(i-FIRST_64BIT) + 9);
		regsize[i]=8;
		regtype[i]=mymalloc(sizeof(struct Typ));
	}

	for(i=FIRST_8BIT;i<=LAST_8BIT;i++)
	{
		regnames[i]=mymalloc(10);
		sprintf(regnames[i],"h%d",(i-FIRST_8BIT));
		regsize[i]=1;
		//regtype[i]=&lchar;
		regtype[i]=mymalloc(sizeof(struct Typ));
	}

	regnames[STACK_POINTER]=mymalloc(10);
	sprintf(regnames[STACK_POINTER],"z2");
	regsize[STACK_POINTER]=4;
	regtype[STACK_POINTER]=&ltyp;
	regtype[STACK_POINTER]=mymalloc(sizeof(struct Typ));

	/*  Use multiple ccs.   */
	multiple_ccs=0;

	/*  Initialize the min/max-settings. Note that the types of the     */
	/*  host system may be different from the target system and you may */
	/*  only use the smallest maximum values ANSI guarantees if you     */
	/*  want to be portable.                                            */
	/*  That's the reason for the subtraction in t_min[INT]. Long could */
	/*  be unable to represent -2147483648 on the host system.          */
	t_min[CHAR]=l2zm(-128L);
	t_min[SHORT]=l2zm(-32768L);
	t_min[INT]=zmsub(l2zm(-2147483647L),l2zm(1L));
	t_min[LONG]=t_min(INT);
	t_min[LLONG]=zmlshift(l2zm(1L),l2zm(63L));
	t_min[MAXINT]=t_min(LLONG);
	t_max[CHAR]=ul2zum(127L);
	t_max[SHORT]=ul2zum(32767UL);
	t_max[INT]=ul2zum(2147483647UL);
	t_max[LONG]=t_max(INT);
	t_max[LLONG]=zumrshift(zumkompl(ul2zum(0UL)),ul2zum(1UL));
	t_max[MAXINT]=t_max(LLONG);
	tu_max[CHAR]=ul2zum(255UL);
	tu_max[SHORT]=ul2zum(65535UL);
	tu_max[INT]=ul2zum(4294967295UL);
	tu_max[LONG]=t_max(UNSIGNED|INT);
	tu_max[LLONG]=zumkompl(ul2zum(0UL));
	tu_max[MAXINT]=t_max(UNSIGNED|LLONG);

	for(i=FIRST_16BIT;i<=LAST_16BIT-VOL_16BIT;i++)
		regscratch[i]=1;
	for(i=FIRST_32BIT;i<=LAST_32BIT-VOL_32BIT;i++)
		regscratch[i]=1;
	for(i=FIRST_64BIT;i<=LAST_64BIT-VOL_64BIT;i++)
		regscratch[i]=1;
	for(i=FIRST_8BIT;i<=LAST_8BIT-VOL_8BIT;i++)
		regscratch[i]=1;

	/*  Reserve a few registers for use by the code-generator.      */
	/*  This is not optimal but simple.                             */
	sp=STACK_POINTER;
	t8bit1=FIRST_8BIT;
	t8bit2=FIRST_8BIT+1;
	t16bit1=FIRST_16BIT;
	t16bit2=FIRST_16BIT+1;
	t32bit1=FIRST_32BIT;
	t32bit2=FIRST_32BIT+1;
	t64bit1=FIRST_64BIT;
	t64bit2=FIRST_64BIT+1;
	regsa[t8bit1]=regsa[t8bit2]=1;
	regsa[t16bit1]=regsa[t16bit2]=1;
	regsa[t32bit1]=regsa[t32bit2]=1;
	regsa[t64bit1]=regsa[t64bit2]=1;
	regsa[sp]=1;
	regscratch[t8bit1]=regscratch[t8bit2]=0;
	regscratch[t16bit1]=regscratch[t16bit2]=0;
	regscratch[t32bit1]=regscratch[t32bit2]=0;
	regscratch[t64bit1]=regscratch[t64bit2]=0;
	regscratch[sp]=0;

	//	for(i=FIRST_FIXED;i<=LAST_FIXED-VOL_FIXED;i++)
	//		regscratch[i]=1;
	target_macros=marray;

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
	if(ISSTRUCT(t->flags)||ISUNION(t->flags)) 
		return 0;
	if(t->size == 1)
		return FIRST_8BIT+3;
	if(t->size == 2)
		return FIRST_16BIT+3;
	if(t->size == 4)
		return FIRST_32BIT+3;
	if(t->size == 8)
		return FIRST_64BIT+3;

	return 0;
}

int reg_pair(int r,struct rpair *p)
/* Returns 0 if the register is no register pair. If r  */
/* is a register pair non-zero will be returned and the */
/* structure pointed to p will be filled with the two   */
/* elements.                                            */
{
	return 0;
}

/* estimate the cost-saving if object o from IC p is placed in
register r */
int cost_savings(struct IC *p,int r,struct obj *o)
{
	int c=p->code;
	if(o->flags&VKONST)
	{
		if(!LOAD_STORE)
			return 0;
		if(o==&p->q1&&p->code==ASSIGN&&(p->z.flags&DREFOBJ))
			return 4;
		else
			return 2;
	}
	if(o->flags&DREFOBJ)
		return 4;
	if(c==SETRETURN&&r==p->z.reg&&!(o->flags&DREFOBJ))
		return 3;
	if(c==GETRETURN&&r==p->q1.reg&&!(o->flags&DREFOBJ))
		return 3;
	return 2;
}

int regok(int r,int t,int mode)
/*  Returns 0 if register r cannot store variables of   */
/*  type t. If t==POINTER and mode!=0 then it returns   */
/*  non-zero only if the register can store a pointer   */
/*  and dereference a pointer to mode.                  */
{
	if(r==0)
		return 0;
	t&=NQ;

	if(r>=FIRST_8BIT&&r<=LAST_8BIT)
	{
//		printf("8 bit register: ");
		if(t == CHAR)
		{
//			printf(" can fit\n");
			return 1;
		}
//		else
//			printf(" can't fit\n");
	}
	else if(r>=FIRST_16BIT&&r<=LAST_16BIT)
	{
//		printf("16 bit register: ");
		if(t == SHORT)
		{
//			printf(" can fit\n");
			return 1;
		}
//		else
//			printf(" can't fit\n");
	}
	else if(r>=FIRST_32BIT&&r<=LAST_32BIT)
	{
//		printf("32 bit register: ");
		if(t == INT || t == LONG || t == FLOAT
			||t == POINTER)
		{
//			printf(" can fit\n");
			return 1;
		}
//		etse
//			printf(" can't fit\n");
	}
	else if(r>=FIRST_64BIT&&r<=LAST_64BIT)
	{
//		printf("64 bit register: ");
		if(t == LDOUBLE || t == DOUBLE || t == LLONG)
		{
//			printf(" can fit\n");
			return 1;
		}
//		else
//			printf(" can't fit\n");;
	}

	return 0;


	/*#define CHAR 1
	#define SHORT 2
	#define INT 3
	#define LONG 4
	#define LLONG 5
	#define FLOAT 6
	#define DOUBLE 7
	#define LDOUBLE 8
	#define VOID 9
	#define POINTER 10
	#define ARRAY 11
	#define STRUCT 12
	#define UNION 13
	#define ENUM 14*/
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
	int c=p->code;
	if((p->q1.flags&DREFOBJ)||(p->q2.flags&DREFOBJ)||(p->z.flags&DREFOBJ))
		return 1;
	if((c==DIV||c==MOD)&&!isconst(q2))
		return 1;
	return 0;
}

int must_convert(int o,int t,int const_expr)
/*  Returns zero if code for converting np to type t    */
/*  can be omitted.                                     */
/*  On the PowerPC cpu pointers and 32bit               */
/*  integers have the same representation and can use   */
/*  the same registers.                                 */
{
	int op=o&NQ,tp=t&NQ;

	if(op == LONG || op == POINTER)
		op = INT;

	if(tp==LONG || tp ==POINTER)
		tp = INT;

	if(op == tp) // same type
		if((o & NQ)== (t & NQ)) // same signess
			return 0; // no code needed

	return 1;
}

void gen_ds(FILE *f,zmax size,struct Typ *t)
/*  This function has to create <size> bytes of storage */
/*  initialized with zero.                              */
{
	if(newobj&&section!=SPECIAL)
		emit(f," data %ld\n",zm2l(size));
	else
		emit(f," data %ld\n",zm2l(size));
	newobj=0;
}

void gen_align(FILE *f,zmax align)
/*  This function has to make sure the next data is     */
/*  aligned to multiples of <align> bytes.              */
{
	if(zm2l(align)>1)
		emit(f,"; NOT IMPLEMENTED - \t.align\t%d\n", align);
}

void gen_var_head(FILE *f,struct Var *v)
/*  This function has to create the head of a variable  */
/*  definition, i.e. the label and information for      */
/*  linkage etc.                                        */
{
	int constflag;
	char *sec;
	if(v->clist) constflag=is_const(v->vtyp);
	if(v->storage_class==STATIC)
	{
		if(ISFUNC(v->vtyp->flags))
			return;
		if(!special_section(f,v))
		{
			if(v->clist&&(!constflag||(g_flags[2]&USEDFLAG))&&section!=DATA){emit(f,dataname);if(f) section=DATA;}
			if(v->clist&&constflag&&!(g_flags[2]&USEDFLAG)&&section!=RODATA){emit(f,rodataname);if(f) section=RODATA;}
			if(!v->clist&&section!=BSS){emit(f,bssname);if(f) section=BSS;}
		}
		if(v->clist||section==SPECIAL)
		{
			gen_align(f,falign(v->vtyp));
			emit(f,"%s%ld:\n",labprefix,zm2l(v->offset));
		}
		else
			emit(f,"\t.lcomm\t%s%ld,",labprefix,zm2l(v->offset));
		newobj=1;
	}
	if(v->storage_class==EXTERN)
	{
		//  emit(f,"\t.globl\t%s%s\n",idprefix,v->identifier);
		if(v->flags&(DEFINED|TENTATIVE))
		{
			if(!special_section(f,v))
			{
				if(v->clist&&(!constflag||(g_flags[2]&USEDFLAG))&&section!=DATA)
				{
					emit(f,dataname);
					if(f)
						section=DATA;
				}
				if(v->clist&&constflag&&!(g_flags[2]&USEDFLAG)&&section!=RODATA)
				{
					emit(f,rodataname);
					if(f)
						section=RODATA;
				}
				if(!v->clist&&section!=BSS)
				{
					emit(f,bssname);
					if(f)
						section=BSS;
				}
			}
			if(v->clist||section==SPECIAL)
			{
				gen_align(f,falign(v->vtyp));
				//        emit(f,"%s%s:\n",idprefix,v->identifier);
			}
			else
				emit(f,".global %s%s:",/*(USE_COMMONS?"":"l"),*/idprefix,v->identifier);
			newobj=1;
		}
	}
}

void gen_dc(FILE *f,int t,struct const_list *p)
/*  This function has to create static storage          */
/*  initialized with const-list p.                      */
{
	//emit(f,"\tdc.%s\t",dt(t&NQ));
	int o = t&NQ;
	int size = 4;
	if(o == CHAR)
		size = 1;
	if(o == SHORT)
		size = 2;
	if(o == LLONG || t == DOUBLE)
		size = 8;

	emit(f,"\tdata\t%i\t",size);
	if(!p->tree)
	{
		if(ISFLOAT(t))
		{
			/*  auch wieder nicht sehr schoen und IEEE noetig   */
			unsigned char *ip;
			ip=(unsigned char *)&p->val.vdouble;
			emit(f,"0x%02x%02x%02x%02x",ip[0],ip[1],ip[2],ip[3]);
			if((t&NQ)!=FLOAT){
				emit(f,",0x%02x%02x%02x%02x",ip[4],ip[5],ip[6],ip[7]);
			}
		}
		else if(o & UNSIGNED)
		{
			emitval(f,&p->val,t);
		}
		else
		{
			emit(f, "0s");
			emitval(f,&p->val,t);
		}
	}
	else
	{
		emit_obj(f,&p->tree->o,t);
	}
	emit(f,"\n");
	newobj=0;
}


/*  The main code-generation routine.                   */
/*  f is the stream the code should be written to.      */
/*  p is a pointer to a doubly linked list of ICs       */
/*  containing the function body to generate code for.  */
/*  v is a pointer to the function.                     */
/*  offset is the size of the stackframe the function   */
/*  needs for local variables.                          */

void gen_code(FILE *f,struct IC *p,struct Var *v,zmax offset)
/*  The main code-generation.                                           */
{
	int c,t,i,lastcomp=0;
	struct IC *m;
	argsize=0;
	if(DEBUG&1)
		printf("gen_code()\n");
	for(c=1;c<=MAXR;c++)
		regs[c]=regsa[c];
	maxpushed=0;

	/*FIXME*/
	ret="\tret\n";

	struct IC *p_test = 0;
	char test_handled = 0;
	int test_reg = 0;
	int test_reg2 = 0;

	for(m=p;m;m=m->next)
	{
		c=m->code;t=m->typf;
		if(c==ALLOCREG)
		{
			regs[m->q1.reg]=1;
			continue;
		}
		if(c==FREEREG)
		{
			regs[m->q1.reg]=0;
			continue;
		}

		/* convert MULT/DIV/MOD with powers of two */
		if((t&NQ)<=LONG&&(m->q2.flags&(KONST|DREFOBJ))==KONST&&(t&NQ)<=LONG&&(c==MULT||((c==DIV||c==MOD)&&(t&UNSIGNED))))
		{
			eval_const(&m->q2.val,t);
			i=pof2(vmax);
			if(i)
			{
				if(c==MOD)
				{
					vmax=zmsub(vmax,l2zm(1L));
					m->code=AND;
				}
				else
				{
					vmax=l2zm(i-1);
					if(c==DIV)
						m->code=RSHIFT;
					else
						m->code=LSHIFT;
				}
				c=m->code;
				gval.vmax=vmax;
				eval_const(&gval,MAXINT);
				if(c==AND)
				{
					insert_const(&m->q2.val,t);
				}
				else
				{
					insert_const(&m->q2.val,INT);
					p->typf2=INT;
				}
			}
		}
#if FIXED_SP
		if(c==CALL&&argsize<zm2l(m->q2.val.vmax))
			argsize=zm2l(m->q2.val.vmax);
#endif
	}
	peephole(p);

	for(c=1;c<=MAXR;c++)
	{
		if(regsa[c]||regused[c])
		{
			BSET(regs_modified,c);
		}
	}

	localsize=(zm2l(offset)+3)/4*4;
#if FIXED_SP
	/*FIXME: adjust localsize to get an aligned stack-frame */
#endif

	function_top(f,v,localsize);

	stackoffset=notpopped=dontpop=0;

	for(;p;p=p->next)
	{
		c=p->code;t=p->typf;
		if(c==NOP)
		{
			p->z.flags=0;
			continue;
		}

		if(c==ALLOCREG)
		{
			regs[p->q1.reg]=1;
			continue;
		}

		if(c==FREEREG)
		{
			regs[p->q1.reg]=0;
			continue;
		}
		if(c==LABEL)
		{
			emit(f,"%s%d:\n",labprefix,t);
			continue;
		}

		if(notpopped&&!dontpop)
		{
			if(c==LABEL||c==COMPARE||c==TEST||c==BRA)
			{
				emit(f,"\taddl\t$%ld,%%esp\n",notpopped);
				pop(notpopped);
				notpopped=0;
			}
		}
		if(c==BRA)
		{
			emit(f,"\tmov b29 %s%d\n", labprefix, t);
			emit(f,"\tjmp\tb29\n");

			//emit(f,"\tmov b29\t");
			//if(isreg(q1)){
			//emit_obj(f,&p->q1,0);
			//emit(f,",");
			//}
			//emit(f,"%s%d;\n",labprefix,t);
			continue;
		}

		if(c==MOVETOREG)
		{
			//printf("reg: %s\n", regnames[p->z.reg]);
			if(p->z.reg <= MAXR)
				load_reg(f,p->z.reg,&p->q1,regtype[p->z.reg]->flags);
			else
				emit(f," ; move non existant reg in to %s\n",regnames[p->q1.reg]);
			continue;
		}
		if(c==MOVEFROMREG)
		{
			//			printf("reg: %s\n", regnames[p->z.reg]);
			if(p->z.reg <= MAXR)
				store_reg(f, p->z.reg, &p->q1, regtype[p->z.reg]->flags);
			continue;
		}
		if((c==ASSIGN||c==PUSH)&&((t&NQ)>POINTER||((t&NQ)==CHAR&&zm2l(p->q2.val.vmax)!=1)))
		{
			ierror(0);
		}
		p=preload(f,p);
		c=p->code;
		if(c==SUBPFP)
			c=SUB;
		if(c==ADDI2P)
			c=ADD;
		if(c==SUBIFP)
			c=SUB;
		if(c==CONVERT)
		{
			load_reg(f,zreg,&p->q1,p->typf2);
			if(ISFLOAT(p->typf)) // convert to float
			{
				if(ISFLOAT(p->typf2)) // from float
				{					
					//					emit(f,"\tmovf\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
				}
				else if(!(p->typf2 & UNSIGNED)) // from signed
				{
					//					emit(f,"\tmovs\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
					emit(f,"\tstf\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
				else if(p->typf2 & UNSIGNED) // from unsigned
				{
					//					emit(f,"\tmov\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
					emit(f,"\tutf\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
			}
			else if(!(p->typf & UNSIGNED)) // convert to signed
			{
				if(ISFLOAT(p->typf2)) // from float
				{
					//					emit(f,"\tmovf\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
					emit(f,"\tfts\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
				else if(!(p->typf2 & UNSIGNED)) // from signed
				{
					//					emit(f,"\tmovs\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
				}
				else if(p->typf2 & UNSIGNED) // from unsigned
				{
					//					emit(f,"\tmov\t%s\t", regnames[zreg]);
					//					emit_obj(f,&p->q1,p->typf2);
//					emit(f,"\n\tuts\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
			}
			else if(p->typf & UNSIGNED) // convert to unsigned
			{
				if(ISFLOAT(p->typf2)) // from float
				{
					//					emit(f,"\tmovf\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
					emit(f,"\tftu\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
				else if(!(p->typf2 & UNSIGNED)) // from signed
				{
					//					emit(f,"\tmovs\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
//					emit(f,"\tstu\t%s ;%s\n",regnames[zreg],dt(q1typ(p)));
				}
				else if(p->typf2 & UNSIGNED) // from unsigned
				{
					//					emit(f,"\tmov\t%s\t%s\n", regnames[zreg], regnames[p->q1.reg]);
				}
			}
			save_result(f,p);
			continue;
		}
		if(c==KOMPLEMENT)
		{
			load_reg(f,zreg,&p->q1,t);
			emit(f,"\tcpl.%s\t%s\n",dt(t),regnames[zreg]);
			save_result(f,p);
			continue;
		}
		if(c==SETRETURN)
		{
			load_reg(f,p->z.reg,&p->q1,t);
			BSET(regs_modified,p->z.reg);
			continue;
		}
		if(c==GETRETURN)
		{
			if(p->q1.reg)
			{
				zreg=p->q1.reg;
				save_result(f,p);
			}
			else
				p->z.flags=0;
			continue;
		}
		if(c==CALL)
		{
			int reg;
			/*FIXME*/
#if 0      
			if(stack_valid&&(p->q1.flags&(VAR|DREFOBJ))==VAR&&p->q1.v->fi&&(p->q1.v->fi->flags&ALL_STACK))
			{
				if(framesize+zum2ul(p->q1.v->fi->stack1)>stack)
					stack=framesize+zum2ul(p->q1.v->fi->stack1);
			}else
				stack_valid=0;
#endif
			if((p->q1.flags&(VAR|DREFOBJ))==VAR&&p->q1.v->fi&&p->q1.v->fi->inline_asm)
			{
				emit_inline_asm(f,p->q1.v->fi->inline_asm);
			}
			else
			{
				emit(f, "\tmov\tb29\t");
				emit_obj(f,&p->q1,t);
				emit(f,"\n");
				emit(f,"\tcall\tb29\n");
			}
			/*FIXME*/
#if FIXED_SP
			pushed-=zm2l(p->q2.val.vmax);
#endif
			if((p->q1.flags&(VAR|DREFOBJ))==VAR&&p->q1.v->fi&&(p->q1.v->fi->flags&ALL_REGS))
			{
				bvunite(regs_modified,p->q1.v->fi->regs_modified,RSIZE);
			}
			else
			{
				int i;
				for(i=1;i<=MAXR;i++)
				{
					if(regscratch[i]) BSET(regs_modified,i);
				}
			}
			continue;
		}
		if(c==ASSIGN||c==PUSH)
		{
			if(t==0)
				ierror(0);
			if(c==PUSH)
			{
				emit(f,"\tpush\t"/*,dt(t)*/);
				emit_obj(f,&p->q1,t);
				emit(f,"\n");
				push(zm2l(p->q2.val.vmax));
				continue;
			}
			if(c==ASSIGN)
			{
				load_reg(f,zreg,&p->q1,t);
				if(q2reg != 0)
					load_reg(f,q2reg,&p->q2,t);
				save_result(f,p);
			}
			continue;
		}
		if(c==ADDRESS)
		{
			load_address(f,zreg,&p->q1,POINTER);
			save_result(f,p);
			continue;
		}
		if(c==MINUS)
		{
			load_reg(f,zreg,&p->q1,t);
			emit(f,"\tneg\t%s ; %s\n",dt(t),regnames[zreg]);
			save_result(f,p);
			continue;
		}
		if(c >= BEQ && c < BRA)
		{

			char *ccu[]={"cmp","nequ","gt","!gte","gte","!gt"};
			char *ccs[]={"cmps","nequs","gts","!gtes","gtes","!gts"};
			char *ccf[]={"cmpf","nequf","gtf","!gtef","gtef","!gtf"};
			if(p_test == 0)
			{
				printf("Calling %s without a test!\n",ccs[c-BEQ]);
				emit(f,"Calling %s without a test!\n",ccs[c-BEQ]);
				continue;
			}

			struct IC *p_old = p;
			p = p_test;
			t=p->typf;

			if(test_handled == 0)
			{
				if(ISFLOAT(t))
				{
					if(isreg(q2))
					{
						char instruction[10];
						sprintf(instruction, "%s", ccf[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[test_reg],regnames[test_reg2]);
						}
						else
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[test_reg2],regnames[test_reg]);

						save_result(f,p);
					}
					else
					{
						if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
						{
							unsigned long offset = real_offset(&p->q2);
							if(offset == 0)
							{
								emit(f,"\tmovf\tb28\t[z2]\n");
							}
							else
							{
								emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
								emit(f,"\tmov\tb29\tz2\n");
								emit(f,"\tsub\tb29\tb28\n");
								emit(f,"\tmovf\tb28\t[b29]\n");
							}
						}
						else
						{
							emit(f,"\tmovf\tb28\t");
							emit_obj(f,&p->q2,t);
							emit(f,"\n");
						}

						char instruction[10];
						sprintf(instruction, "%s", ccf[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\tb28\n",instruction,regnames[test_reg]);
						}
						else
							emit(f,"\n\t%s\tb28\t%s\n",instruction,regnames[test_reg]);
					}
				}
				else if(t & UNSIGNED)
				{
					if(isreg(q2))
					{
						char instruction[10];
						sprintf(instruction, "%s", ccu[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[test_reg2],regnames[test_reg]);
						}
						else
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[test_reg],regnames[test_reg2]);
						save_result(f,p);
						continue;
					}
					else
					{
						if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
						{
							unsigned long offset = real_offset(&p->q2);
							if(offset == 0)
							{
								emit(f,"\tmov\tb28\t[z2]\n");
							}
							else
							{
								emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
								emit(f,"\tmov\tb29\tz2\n");
								emit(f,"\tsub\tb29\tb28\n");
								emit(f,"\tmov\tb28\t[b29]\n");
							}
						}
						else
						{
							emit(f,"\tmov\tb28\t");
							emit_obj(f,&p->q2,t);
							emit(f,"\n");
						}

						char instruction[10];
						sprintf(instruction, "%s", ccu[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\tb28\n",instruction,regnames[test_reg]);
						}
						else
							emit(f,"\n\t%s\tb28\t%s\n",instruction,regnames[test_reg]);
					}
				}
				else
				{
					if(isreg(q2))
					{
						char instruction[10];
						sprintf(instruction, "%s", ccs[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[test_reg],regnames[test_reg2]);
						}
						else
							emit(f,"\n\t%s\t%s\t%s\n",instruction,regnames[p->q2.reg],regnames[test_reg]);

						save_result(f,p);
						continue;
					}
					else
					{
						if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
						{
							unsigned long offset = real_offset(&p->q2);
							if(offset == 0)
							{
								emit(f,"\tmovs\tb28\t[z2]\n");
							}
							else
							{
								emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
								emit(f,"\tmov\tb29\tz2\n");
								emit(f,"\tsub\tb29\tb28\n");
								emit(f,"\tmovs\tb28\t[b29]\n");
							}
						}
						else
						{
							emit(f,"\tmovs\tb28\t");
							emit_obj(f,&p->q2,t);
							emit(f,"\n");
						}

						char instruction[10];
						sprintf(instruction, "%s", ccs[c-BEQ]);
						if(instruction[0] == '!')
						{
							instruction[0] = ' ';
							emit(f,"\n\t%s\t%s\tb28\n",instruction,regnames[test_reg]);
						}
						else
							emit(f,"\n\t%s\tb28\t%s\n",instruction,regnames[test_reg]);
					}
				}

				//emit(f,"\tj%s\t",ccs[c-BEQ]);
				//if(isreg(q1))
				//{
				//emit_obj(f,&p->q1,0);
				//emit(f,",");
				//}
				//emit(f,"%s%d ;\n",labprefix,t);

				// next

			}
			else
			{
				if(p_old->code == BEQ)
				{
					emit(f,"\n\trz\t%s\n",regnames[test_reg]);
				}
				else if(p_old->code == BNE)
				{
					emit(f,"\n\trnz\t%s\n",regnames[test_reg]);
				}
				else
					emit(f,"not sure what to do with %d\n", p_old->code);
			}

			p = p_old;
			t=p->typf;

			test_handled = 0;

			emit(f,"\tmov\tb28\t%s%d\n",labprefix,t);
			emit(f,"\tjnz\tz0\tb28\n");
			continue;
		}	
		if(c==TEST)
		{
			// printf("found test");
/*			emit(f,"\ttst\t");
			if(multiple_ccs)
				emit(f,"%s,",regnames[zreg]);
			emit_obj(f,&p->q1,t);
			emit(f," ; %s\n",dt(t));
			if(multiple_ccs)
				save_result(f,p); */

			test_reg = zreg;
			test_reg2 = q2reg;

			if(!isreg(q1))
					load_reg(f,test_reg,&p->q1,t);

			p_test = p;
			test_handled = 1;

			continue;
		}
		if(c==COMPARE)
		{
			test_reg = zreg;
			test_reg2 = q2reg;
			
			if(!isreg(q1))
					load_reg(f,zreg,&p->q1,t);

			p_test = p;
			test_handled = 0;
//			emit(f, "; compare %s\n", regnames[zreg]);
			continue;
		}
		if(c==OR)
		{
			emit(f,"\tmov\tb28\t");
			emit_obj(f,&p->q2,t);

			emit(f,"\n\tor\t%s b28\n",/*dt(t),*/regnames[zreg]);
			save_result(f,p);
			continue;
		}
		if(c==XOR)
		{
			emit(f,"\tmov\tb28\t");
			emit_obj(f,&p->q2,t);

			emit(f,"\n\txor\t%s b28\n",/*dt(t),*/regnames[zreg]);
			save_result(f,p);
			continue;
		}
		if(c==AND)
		{
			emit(f,"\tmov\tb28\t");
			emit_obj(f,&p->q2,t);

			emit(f,"\n\tand\t%s b28\n",/*dt(t),*/regnames[zreg]);
			save_result(f,p);
			continue;
		}

		if(c==LSHIFT)
		{
			emit(f,"\tmov\tb28\t");
			emit_obj(f,&p->q2,t);

			emit(f,"\n\tsal\t%s b28\n",/*dt(t),*/regnames[zreg]);
			save_result(f,p);
			continue;
		}

		if(c==RSHIFT)
		{
			emit(f,"\tmov\tb28\t");
			emit_obj(f,&p->q2,t);

			emit(f,"\n\tsar\t%s b28\n",/*dt(t),*/regnames[zreg]);
			save_result(f,p);
			continue;
		}

		if(c==ADD) ///////////////////////////////////////// ADDITION
		{
			if(!isreg(q1))
				load_reg(f,zreg,&p->q1,t);

			if(p->q2.flags&KONST)
			{
				if(ISFLOAT(t))
				{
					char *ds = (char *)&p->q2.val.vfloat;
					char tmp = ds[0];
					ds[0] = ds[3];
					ds[3] = tmp;
					tmp = ds[1];
					ds[1] = ds[2];
					ds[2] = tmp;

					if((*(float *)ds) == 1.0f)
					{
						emit(f,"\tincf\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
				else if(t & UNSIGNED)
				{
					if(*(unsigned int *)&p->q2.val == 1)
					{
						emit(f,"\tinc\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
				else
				{
					if(*(unsigned int *)&p->q2.val == 1)
					{
						emit(f,"\tincs\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
			}

			if(ISFLOAT(t))
			{
				if(isreg(q2))
				{
					emit(f,"\n\taddf\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovf\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovf\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovf\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\taddf\t%s b28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else if(t & UNSIGNED)
			{
				if(isreg(q2))
				{
					emit(f,"\n\tadd\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmov\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmov\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmov\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tadd\t%s b28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else
			{
				if(isreg(q2))
				{
					emit(f,"\n\tadds\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovs\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovs\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovs\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tadds\t%s b28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
		}

		if(c==SUB)
		{
			if(!isreg(q1))
				load_reg(f,zreg,&p->q1,t);

			if(p->q2.flags&KONST)
			{
				if(ISFLOAT(t))
				{
					char *ds = (char *)&p->q2.val.vfloat;
					char tmp = ds[0];
					ds[0] = ds[3];
					ds[3] = tmp;
					tmp = ds[1];
					ds[1] = ds[2];
					ds[2] = tmp;

					if((*(float *)ds) == 1.0f)
					{
						emit(f,"\tdecf\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
				else if(t & UNSIGNED)
				{
					if(*(unsigned int *)&p->q2.val == 1)
					{
						emit(f,"\tdec\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
				else
				{
					if(*(unsigned int *)&p->q2.val == 1)
					{
						emit(f,"\tdecs\t%s\n", regnames[zreg]);
						save_result(f,p);
						continue;
					}
				}
			}
			if(ISFLOAT(t))
			{
				if(isreg(q2))
				{
					emit(f,"\n\tsubf\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovf\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovf\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovf\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tsubf\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else if(t & UNSIGNED)
			{
				if(isreg(q2))
				{
					emit(f,"\n\tsub\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmov\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmov\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmov\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tsub\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else
			{
				if(isreg(q2))
				{
					emit(f,"\n\tsubs\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovs\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovs\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovs\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tsubs\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
		}

		if(c==MULT)
		{
			if(ISFLOAT(t))
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmulf\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovf\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovf\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovf\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmulf\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else if(t & UNSIGNED)
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmul\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmov\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmov\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmov\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmul\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmuls\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovs\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovs\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovs\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmuls\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}

			continue;
		}

		if(c==DIV)
		{
			if(ISFLOAT(t))
			{
				if(isreg(q2))
				{
					emit(f,"\n\tdivf\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovf\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovf\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovf\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tdivf\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else if(t & UNSIGNED)
			{
				if(isreg(q2))
				{
					emit(f,"\n\tdiv\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmov\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmov\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmov\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tdiv\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else
			{
				if(isreg(q2))
				{
					emit(f,"\n\tdivs\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovs\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovs\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovs\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tdivs\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
		}

		if(c==MOD)
		{
			if(ISFLOAT(t))
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmodf\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovf\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovf\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovf\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmodf\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else if(t & UNSIGNED)
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmod\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmov\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmov\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmov\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmod\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
			else
			{
				if(isreg(q2))
				{
					emit(f,"\n\tmods\t%s\t%s\n",/*dt(t),*/regnames[zreg],regnames[p->q2.reg]);
					save_result(f,p);
					continue;
				}

				if(((p->q2.flags&VAR)&&!(p->q2.flags&REG)) && (p->q2.v->storage_class==AUTO||p->q2.v->storage_class==REGISTER))
				{
					unsigned long offset = real_offset(&p->q2);
					if(offset == 0)
					{
						emit(f,"\tmovs\tb28\t[z2]\n");
					}
					else
					{
						emit(f,"\tmov\tb28\t%ld ; get from stack\n", offset);
						emit(f,"\tmov\tb29\tz2\n");
						emit(f,"\tsub\tb29\tb28\n");
						emit(f,"\tmovs\tb28\t[b29]\n");
					}
				}
				else
				{
					emit(f,"\tmovs\tb28\t");
					emit_obj(f,&p->q2,t);
					emit(f,"\n");
				}

				emit(f,"\n\tmods\t%s\tb28\n",/*dt(t),*/regnames[zreg]);
				save_result(f,p);
				continue;
			}
		}

		pric2(stdout,p);
		ierror(0);
	}
	function_bottom(f,v,localsize);
	if(stack_valid)
	{
		if(!v->fi)
			v->fi=new_fi();
		v->fi->flags|=ALL_STACK;
		v->fi->stack1=stack;
	}
	emit(f," ; stacksize=%lu%s\n",zum2ul(stack),stack_valid?"":"+??");
}

int shortcut(int code,int typ)
{
	return 1;
}

int reg_parm(struct reg_handle *m, struct Typ *t,int vararg,struct Typ *d)
{
	int f;
	f=t->flags&NQ;
	if(f==CHAR)
	{
		if(m->regs8>=NUM_8BIT)
			return 0;
		else
			return FIRST_8BIT+m->regs8++;
	}
	if(f==SHORT)
	{
		if(m->regs16>=NUM_16BIT)
			return 0;
		else
			return FIRST_16BIT+m->regs16++;
	}
	if(f==INT || f==LONG || f==POINTER || f==FLOAT)
	{
		if(m->regs32>=NUM_32BIT)
			return 0;
		else
			return FIRST_32BIT+m->regs32++;
	}
	if(f==DOUBLE || f==LDOUBLE || f==LLONG){
		if(m->regs64>=NUM_64BIT)
			return 0;
		else
			return FIRST_64BIT+m->regs64++;
	}
	return 0;
}

int handle_pragma(const char *s)
{
	return 0;
}

void cleanup_cg(FILE *f)
{
	if(!f)
		return;

}

void cleanup_db(FILE *f)
{
	if(f)
		section=-1;
}

/*
C registers:
b28 - temp - store var during calculation/comparison
b29 - temp - store address during jump
b30 - temp store address of parameters
b31 - temp store addresses to jump to

a0 - 16 bit					4
a1 - 16 bit					5
a2 - 16 bit					6
a3 - 16 bit					7
a4 - 16 bit					8
a5 - 16 bit					9
a6 - 16 bit					10
a7 - 16 bit					11
a8 - 16 bit					12
a9 - 16 bit					13
b5 - 32 bit					14
b6 - 32 bit					15
b7 - 32 bit					16
b8 - 32 bit					17
b9 - 32 bit					18
b10 - 32 bit					19
b11 - 32 bit					20
b12 - 32 bit					21
b13 - 32 bit					22
b14 - 32 bit					23
b15 - 32 bit					24
b16 - 32 bit					25
b17 - 32 bit					26
c9  - 64 bit					27
c10 - 64 bit					28
c11 - 64 bit					29
c12 - 64 bit					30
c13 - 64 bit					31

h0 - 8bit					32
h1 - 8bit					33
h2 - 8bit					34
h3 - 8bit					35
*/
