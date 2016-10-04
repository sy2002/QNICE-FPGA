
#include "supp.h"


static debug_prints = 0;

static char FILE_[]=__FILE__;

/* Name and copyright. */
char cg_copyright[]="vbcc code-generator for Pokemon Mini V0.019 (c) in 2011 by zoranc";


/*  Commandline-flags the code-generator accepts:
    0: just a flag
    VALFLAG: a value must be specified
    STRINGFLAG: a string can be specified
    FUNCFLAG: a function will be called
    apart from FUNCFLAG, all other versions can only be specified once */
int g_flags[MAXGF]= { FUNCFLAG, STRINGFLAG, STRINGFLAG, STRINGFLAG };

/* the flag-name, do not use names beginning with l, L, I, D or U, because
   they collide with the frontend */
char *g_flags_name[MAXGF] = { "h", "ram-vars", "id", "name" };

/* the results of parsing the command-line-flags will be stored here */
union ppi g_flags_val[MAXGF];

#define HELP_DUMP      (g_flags[0]&USEDFLAG)
#define RAM_VARS_ADDR  ((g_flags[1]&USEDFLAG)?address_number(g_flags_val[1].p):0x14E0)
#define GAME_ID        ((g_flags[2]&USEDFLAG)?g_flags_val[2].p:"PKCC")
#define GAME_NAME      ((g_flags[3]&USEDFLAG)?g_flags_val[3].p:"PokeCCbyZC")



/*  Alignment-requirements for all types in bytes.              */
zmax align[MAX_TYPE+1];

/*  Alignment that is sufficient for every object.              */
zmax maxalign;

/*  Sizes of all elementary types in bytes.                     */
zmax sizetab[MAX_TYPE+1];

/*  Minimum and Maximum values each type can have.              */
/*  Must be initialized in init_cg().                           */
zmax t_min[MAX_TYPE+1];
zumax t_max[MAX_TYPE+1];
zumax tu_max[MAX_TYPE+1];

/*  CHAR_BIT of the target machine.                             */
zmax char_bit;

/*  Names of all registers.                                     */
char *regnames[]={"noreg","x","y", "ba", "hl"};
char *regnames_low[]={"noreg","noreg","noreg", "a", "l"};
char *regnames_high[]={"noreg","noreg","noreg", "b", "h"};

/*  The Size of each register in bytes.                         */
zmax regsize[MAXR+1];

/*  Type which can store each register. */
struct Typ *regtype[MAXR+1];

/*  regsa[reg]!=0 if a certain register is allocated and should */
/*  not be used by the compiler pass.                           */
int regsa[MAXR+1];

/*  Specifies which registers may be scratched by functions.    */
int regscratch[MAXR+1]={0,1,1};


/****************************************/
/*  Some private data and functions.    */
/****************************************/

static long malign[MAX_TYPE+1]=  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
static long msizetab[MAX_TYPE+1]={0,1,1,2,4,4,4,8,8,0,2,0,0,0,2,0};

struct Typ ityp={SHORT},ltyp={LONG};

static int ix = 1,iy = 2;
static int q1reg,q2reg,zreg;
static int ba = 3,hl = 4;               /*  temporary gprs */


/* return-instruction */
static char *ret;

static char *marray[]={"__POKEMINI__",0};

#define isreg(x) ((p->x.flags&(REG|DREFOBJ))==REG)
#define isconst(x) ((p->x.flags&(KONST|DREFOBJ))==KONST)

#define ISLWORD(t) ((t&NQ)==LONG||(t&NQ)==FLOAT)
#define ISHWORD(t) ((t&NQ)==INT)


/* assembly-prefixes for labels and external identifiers */
static char *labprefix="vbcc___l",*idprefix="";

/* has to be 4 bytes long */
static char game_id[10] = "PKCC";
/* can be up to 12 bytes long */
static char game_name[20] = "PokeCCbyZC";

static void emit_irq_vectors(FILE *f);
static void emit_unised_irq_labels(FILE *f);
static int used_interrupt[26];
static char *int_handler_prefix="vbcc___interrupt_handler_";

static int start_ram_vars = 0x14E0;
static int ram_rom_distance = 0x11D0;
static int end_ram_vars;
static int last_was_rom = 1;
static int ram_vars_initialized = 0;

/* Names of target-specific variable attributes.                */
char *g_attr_name[]={"__interrupt", "__rom", "__align8", "__align64", 0};
#define INTERRUPT 1
#define ROM 2
#define ALIGN8 4
#define ALIGN64 8

#include "emit.h"


#define dt(t) (((t)&UNSIGNED)?udt[(t)&NQ]:sdt[(t)&NQ])
static char *sdt[MAX_TYPE+1]={"??","c","s","i","l","ll","f","d","ld","v","p"};
static char *udt[MAX_TYPE+1]={"??","uc","us","ui","ul","ull","f","d","ld","v","p"};


//static char *ccs[]={"eq","ne","lt","ge","le","gt",""};
static char *ccs2[]={"nz","z","ge","l","g","le",""};
//static char *uccs2[]={"nzb","zb","ge","l","g","le",""};
static char *uccs2[]={"nz","z","nc","c","c","nc",""};
//static char *uccs2[]={"nzb","zb","no","o","ns","s",""};
static char *logicals[]={"or","xor","and"};
static char *arithmetics[]={"slw","srw","add","sub","mullw","divw","mod"};

static void emit_obj(FILE *f,struct obj *p,int t);

static long localsize, rsavesize, /*argsize,*/ pushed;

#define NOT_IMP() not_implemented((f),(__LINE__))
void not_implemented(FILE *f, int line)
{
	emit(f, ";\tNOT IMPLEMENTED: %s LINE: %d !!!\n", __FILE__, line);
}

/* calculate the actual current offset of an object relativ to the
 stack-pointer; we use a layout like this:
 ------------------------------------------------
 | arguments to this function                   |
 ------------------------------------------------
 | return-address [size=3]                      |
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
		off=localsize+rsavesize+3-off-zm2l(maxalign);
	}

	off+=pushed;

	off+=zm2l(o->val.vmax);

	return off;
}

static void emit_irq_vectors(FILE *f)
{
	int i;
	for(i=0; i<26; i++)
	{
		emit(f, ".orgfill 0x%x\n", 0x2102 + 6 * i);
		emit(f, "\tjmp\t%s%d\n", int_handler_prefix, i);
	}
	
	used_interrupt[0] = 1;
}

static void emit_unised_irq_labels(FILE *f)
{
	int i;
	for(i=0; i<26; i++)
	{
		if(!used_interrupt[i])
			emit(f, "%s%d:\n", int_handler_prefix, i);
	}
}

char *flags_verbose(int flags, char *str)
{
	static char *flag_str[] = {"KONST", "VAR", "", "", "", "DREFOBJ", "REG", "VARADR"};
	int i;
	
	strcpy(str, "");
	
	for(i=0; i<8; i++)
	{
		if(flags & (1 << i))
		{
			if(strlen(str)!=0 && strlen(flag_str[i])!=0)
				strcat(str, "|");
			strcat(str, flag_str[i]);
		}
	}
	
	return str;
}

/* generate code to load the address of a variable into register r */
static void load_address(FILE *f,int r,struct obj *o,int type)
/*  Generates code to load the address of a variable into register r.   */
{
  char str[100];
  if(debug_prints)
   	emit(f, ";\tload_address(reg:%s, flags:%s, type:%s)\n", regnames[r], flags_verbose(o->flags, str), typname[type&NQ]);
  if(!(o->flags&VAR)) ierror(0);
  if(o->v->storage_class==AUTO||o->v->storage_class==REGISTER)
  {
    long off=real_offset(o);
    emit(f,"\tmov\t%s,sp\n",regnames[r]);
    if(off)
      emit(f,"\tadd\t%s,%ld\n",regnames[r],off);
  }
  else
  {
    emit(f,"\tmov\t%s,",regnames[r]);
    emit_obj(f,o,type);
    emit(f,"\n");
  }
}
/* Generates code to load a memory object into register r. tmp is a
 general purpose register which may be used. tmp can be r. */
static void load_reg(FILE *f, int r, struct obj *o, int type, int type2)
{
  char str[100];
  if(debug_prints)
    emit(f, ";\tload_reg(reg:%s, flags:%s, type:%s, type2:%s)\n", regnames[r], flags_verbose(o->flags, str), typname[type&NQ], (type2&NQ)?typname[type2&NQ]:"");
  type&=NU;
  if(o->flags&VARADR)
  {
    load_address(f,r,o,POINTER);
  }
  else
  {
    if((o->flags&(REG|DREFOBJ))==REG&&o->reg==r)
      return;
    if( msizetab[(type&NQ)] == 1 && 
         !((o->flags==VAR) /*&& (o->v->storage_class==AUTO||o->v->storage_class==REGISTER)*/))
    {
    	/* TODO */
    	/* optimise this like in the store_reg() */
		int is_16_reg = ((o->flags&(REG|DREFOBJ)) == REG) && msizetab[type2&NQ] == 2;
		if(r == ba || r == hl)
    	{
			/* handle case of transfer 16-bit reg -> 8-bit reg*/
			emit(f,"\tmov\t%s,",is_16_reg?regnames[r]:regnames_low[r]);
			emit_obj(f,o,type);
			emit(f,"\n");
		}
		else if(r==ix && ((o->flags&(REG|DREFOBJ)) == REG))
		{
			if(!is_16_reg)
				emit(f, "\tmov\t%s, 0\n", regnames_high[o->reg]); // or maybe expand sign?
			emit(f, "\tmov\tx,");
			emit_obj(f,o,type);
			emit(f,"\n");
		}
		else
			NOT_IMP();
    }
    else
    {
		if((o->flags==VAR) && type==ARRAY)
		{
			emit(f,"\tmov\t%s,",regnames[r]);
			o->flags |= VARADR;
			emit_obj(f,o,type);
			o->flags &= ~VARADR;
			emit(f,"\n");
		}
		else
		{
			emit(f,"\tmov\t%s,",regnames[r]);
			emit_obj(f,o,type);
			emit(f,"\n");
		}
    }
  }
}

static int free_index_reg()
{
	if(!regs[ix]) return ix;
	if(!regs[iy]) return iy;
	return 0;
}

/*  Generates code to store register r into memory object o. */
static void store_reg(FILE *f,int r,struct obj *o,int type)
{
	char str[100];
    if(debug_prints)
    	emit(f, ";\tstore_reg(reg:%s, flags:%s, type:%s)\n", regnames[r], flags_verbose(o->flags, str), typname[type&NQ]);
	type&=NQ;
   if( msizetab[(type&NQ)] == 1 )
   {
    	if(r == ba)
    	{
			if((o->flags==VAR) && (o->v->storage_class==AUTO||o->v->storage_class==REGISTER))
			{
				int ind_reg = free_index_reg();
				long off = real_offset(o);
				
				if(off == 0)
				{
					emit(f, "\tinc\tsp\n");
					emit(f, "\tpush\ta\n");
				}
				else if(ind_reg)
				{
					emit(f, "\tmov\t%s,sp\n", regnames[ind_reg]);
					emit(f, "\tmov\t[%s+%ld],%s\n", regnames[ind_reg], off, regnames_low[r]);
				}
				else
				{
					emit(f,"\tmov\thl,sp\n");
					emit(f,"\tadd\thl,%ld\n",off);
					emit(f,"\tmov\t[hl],%s\n", regnames_low[r]);
				}
			}
			else
			{
				emit(f,"\tmov\t");
				emit_obj(f,o,type);
				emit(f,",%s\n",regnames_low[r]);
			}
		}
		else if(r==ix && (o->flags==VAR))
		{
			emit(f, "\tmov\thl,");
			emit_obj(f,o,type);
			emit(f, "\n");
			emit(f, "\tmov\th, 0\n"); // maybe extend sign?
			emit(f, "\tmov\tx,hl\n");
		}
		else
			NOT_IMP();
   }
	else
	{
		emit(f,"\tmov\t");
		emit_obj(f,o,type);
		emit(f,",%s\n",regnames[r]);
	}
}


/* Does some pre-processing like fetching operands from memory to
 registers etc. */
static struct IC *preload(FILE *f,struct IC *p)
{
  int r;

  if(debug_prints)
    emit(f, ";\tpreload() - start\n");
  
  if(isreg(q1))
    q1reg=p->q1.reg;
  else
    q1reg=0;
  
  if(isreg(q2))
    q2reg=p->q2.reg;
  else
    q2reg=0;
  
  if(isreg(z) && ADD <= p->code && p->code <= SUB)
  {
    zreg=p->z.reg;
  }
  else
  {
    /*
    if(ISFLOAT(ztyp(p)))
      zreg=f1;
    else
    */
      zreg=ba;
  }
  if((p->q1.flags&(DREFOBJ|REG))==DREFOBJ&&!p->q1.am)
  {
    if(debug_prints)
      emit(f, ";\tpreload() - q1\n");
    p->q1.flags&=~DREFOBJ;
    load_reg(f,hl,&p->q1,POINTER,0);
    p->q1.reg=hl;
    p->q1.flags|=(REG|DREFOBJ);
	 p->q1.flags&=~KONST;
  }
  if(p->q1.flags/* &&LOAD_STORE */&&!isreg(q1))
  {
    if(debug_prints)
      emit(f, ";\tpreload() - q1a\n");
    /*
    if(ISFLOAT(q1typ(p)))
      q1reg=f1;
    else
    */
      q1reg=ba;
    load_reg(f,q1reg,&p->q1,q1typ(p),0);
    p->q1.reg=q1reg;
    p->q1.flags=REG;
  }
  
  if((p->q2.flags&(DREFOBJ|REG))==DREFOBJ&&!p->q2.am)
  {
    if(debug_prints)
      emit(f, ";\tpreload() - q2\n");
    p->q2.flags&=~DREFOBJ;
    load_reg(f,hl,&p->q2,POINTER, 0);
    p->q2.reg=hl;
    p->q2.flags|=(REG|DREFOBJ);
	 p->q1.flags&=~KONST;
  }
  if(p->q2.flags/* &&LOAD_STORE */&&!isreg(q2))
  {
    if(debug_prints)
      emit(f, ";\tpreload() - q2a\n");
    /*
    if(ISFLOAT(q2typ(p)))
      q2reg=f2;
    else
    */
      q2reg=hl;
    load_reg(f,q2reg,&p->q2,q2typ(p), 0);
    p->q2.reg=q2reg;
    p->q2.flags=REG;
  }
  
  if(debug_prints)
    emit(f, ";\tpreload() - end\n");
  
  return p;
}

/* save the result (in zreg) into p->z */
void save_result(FILE *f,struct IC *p)
{
  char str[100];
  if(debug_prints)
   	emit(f, ";\tsave_result(flags:%s)\n", flags_verbose(p->z.flags, str));
  if((p->z.flags&(REG|DREFOBJ))==DREFOBJ&&!p->z.am){
    p->z.flags&=~DREFOBJ;
    load_reg(f,hl,&p->z,POINTER, 0);
    p->z.reg=hl;
    p->z.flags|=(REG|DREFOBJ);
	p->z.flags&=~KONST;
  }
  if(isreg(z)){
    if(p->z.reg!=zreg)
      emit(f,"\tmov\t%s,%s\n",regnames[p->z.reg],regnames[zreg]);
  }else{
    store_reg(f,zreg,&p->z,ztyp(p));
  }
}

/* prints an object */
static void emit_obj(FILE *f,struct obj *p,int t)
{
	/*
	if(p->am){
	if(p->am->flags&GPR_IND) emit(f,"(%s,%s)",regnames[p->am->offset],regnames[p->am->base]);
	if(p->am->flags&IMM_IND) emit(f,"(%ld,%s)",p->am->offset,regnames[p->am->base]);
	return;
	}
	*/
	if((p->flags&(KONST|DREFOBJ))==(KONST|DREFOBJ))
	{
		emitval(f,&p->val,p->dtyp&NU);
		return;
	}
	if((p->flags&DREFOBJ)||(p->flags&(VAR|VARADR))==VAR) emit(f,"[");
	if(p->flags&REG)
	{
		emit(f,"%s",regnames[p->reg]);
	}
	else if(p->flags&VAR) 
	{
		//emit(f,"{%d,%d}", p->v->storage_class, p->flags);
		if(p->v->storage_class==AUTO||p->v->storage_class==REGISTER)
			emit(f,"sp+%ld",real_offset(p));
		else
		{
			//emit(f,"[");
			if(!zmeqto(l2zm(0L),p->val.vmax))
			{
				emitval(f,&p->val,LONG);
				emit(f,"+");
			}
			if(p->v->storage_class==STATIC)
			{
				emit(f,"%s%ld",labprefix,zm2l(p->v->offset));
			}
			else
			{
				emit(f,"%s%s",idprefix,p->v->identifier);
			}
			//emit(f,"]");
		}
	}
	if(p->flags&KONST)
	{
		emitval(f,&p->val,t&NU);
	}
	if((p->flags&DREFOBJ)||(p->flags&(VAR|VARADR))==VAR) emit(f,"]");
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

/* emit a logical instruction */
static void emit_logical(FILE *f, int c, struct obj *q, int t)
{
	if(zreg==ba)
	{
		emit(f, "\tpush\t%s\n", regnames[q->reg]);
		emit(f, "\tmov\thl,sp\n");
		emit(f, "\t%s\ta,[hl]\n", logicals[c-OR]);
		emit(f, "\txchg\ta,b\n");
		emit(f, "\tinc\thl\n");
		emit(f, "\t%s\ta,[hl]\n", logicals[c-OR]);
		emit(f, "\txchg\ta,b\n");
		emit(f, "\tpop\t%s\n", regnames[q->reg]);
	}
	else
	{
		NOT_IMP();
		emit(f,";\t%s\t%s,",logicals[c-OR],regnames[zreg]);
		emit_obj(f,q,t);
		emit(f,"\n");
	}
}

/* emit a shift instruction */
static void emit_shift(FILE *f, int c, struct obj *q, int t)
{
	int l1, l2, l3;
	l1 = ++label;
	l2 = ++label;
	l3 = ++label;
	if(zreg==ba)
	{
		emit(f, "\tcmp\t%s,16\n",regnames[q->reg]); 
		emit(f, "\tjc\t%s%d\n",labprefix,l1);
		if(c == RSHIFT && !(t&UNSIGNED))
			emit(f, "\tmov\tba,0xffff\n");
		else
			emit(f, "\tmov\tba, 0\n");
		emit(f, "\tjmp\t%s%d\n",labprefix,l3);
		emit(f, "%s%d:\n",labprefix,l1);
		emit(f, "\tcmp\t%s,0\n",regnames[q->reg]); 
		emit(f, "\tjz\t%s%d\n",labprefix,l3);
		emit(f, "%s%d:\n",labprefix,l2);
		if(c == LSHIFT)
		{
			emit(f, "\tshl\ta\n");
			emit(f, "\trolc\tb\n");
		}
		else
		{
			if (t&UNSIGNED)
				emit(f, "\tshr\tb\n");
			else
				emit(f, "\tsar\tb\n");
			emit(f, "\trorc\ta\n");
		}
		emit(f, "\tdec\t%s\n", regnames[q->reg]);
		emit(f, "\tjnz\t%s%d\n",labprefix,l2);
		emit(f, "%s%d:\n",labprefix,l3);
	}
	else
	{
		NOT_IMP();
		emit(f,";\t%s\t%s,", arithmetics[c-LSHIFT], regnames[zreg]);
		emit_obj(f,q,t);
		emit(f,"\n");
	}
}
static void emit_move_array(FILE *f, struct obj *z, struct obj *q, int size)
{
	int l1;
	l1 = ++label;
	emit(f,"\tmov\thl,%d\n", size);
	if(regs[ix])
	{
		pushed+=2;
		emit(f, "\tpush\tx\n");
	}
	if(regs[iy])
	{
		pushed+=2;
		emit(f, "\tpush\ty\n");
	}
	load_reg(f, iy, q, POINTER, 0);
	z->flags |= VARADR;
	load_reg(f, ix, z, POINTER, 0);
	z->flags &= ~VARADR;
	
	emit(f, "%s%d:\n",labprefix,l1);
	emit(f, "\tmov\t[x],[y]\n");
	emit(f, "\tinc\tx\n");
	emit(f, "\tinc\ty\n");
	emit(f, "\tdec\thl\n");
	emit(f, "\tjnzb\t%s%d\n",labprefix,l1);
	
	if(regs[iy])
	{
		pushed-=2;
		emit(f, "\tpop\ty\n");
	}
	if(regs[ix])
	{
		pushed-=2;
		emit(f, "\tpop\tx\n");
	}
}

/* generates the function entry code */
static void function_top(FILE *f,struct Var *v,long offset)
{
  emit(f,"\n");
  rsavesize=0;
  if(v->storage_class==EXTERN)
  {
    /*
    if((v->flags&(INLINEFUNC|INLINEEXT))!=INLINEFUNC)
      emit(f,";\t.global\t%s%s\n",idprefix,v->identifier);
	*/
    emit(f,"%s%s:\n",idprefix,v->identifier);
  }
  else
    emit(f,"%s%ld:\n",labprefix,zm2l(v->offset));
  if(offset)
    emit(f,"\tsub\tsp,%ld\n", offset);
}

/* generates the function exit code */
static void function_bottom(FILE *f,struct Var *v,long offset)
{
  if(offset)
    emit(f,"\tadd\tsp,%ld\n", offset);
  emit(f,ret);
}

int address_number(char *str)
{
	if(strncmp(str, "0x", 2)==0)
		return strtol(str, 0, 16);
	else
		return atoi(str);
}

/****************************************/
/*  End of private data and functions.  */
/****************************************/

void help(char *str)
{
	printf("Parameters:\n");
	printf("  -help             This help screen \n");
	printf("  -ram-vars=<ADDR>  Address from which will start ram variables. \n");
	printf("                        Default value is 0x14E0 \n");
	printf("  -id=<ID_STR>      Identificatior of the game. Maximum 4 characters long.\n");
	printf("  -name=<NAME_STR>  Name of the game. Maximum 12 characters. \n");	
	fflush(stdout);
	exit(0);
}

int reg_pair(int r,struct rpair *p)
/* Returns 0 if the register is no register pair. If r  */
/* is a register pair non-zero will be returned and the */
/* structure pointed to p will be filled with the two   */
/* elements.                                            */
{
   return 0;
}


int init_cg(void)
/*  Does necessary initializations for the code-generator. Gets called  */
/*  once at the beginning and should return 0 in case of problems.      */
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
	for(i=1;i<=MAXR;i++)
	{
		regsize[i]=l2zm(2L);regtype[i]=&ityp;
	}   

	/*  Initialize the min/max-settings. Note that the types of the     */
	/*  host system may be different from the target system and you may */
	/*  only use the smallest maximum values ANSI guarantees if you     */
	/*  want to be portable.                                            */
	/*  That's the reason for the subtraction in t_min[INT]. Long could */
	/*  be unable to represent -2147483648 on the host system.          */
	t_min[CHAR]=l2zm(-128L);
	t_min[SHORT]=l2zm(-32768L);
	t_min[INT]=t_min[SHORT];
	t_min[LONG]=zmsub(l2zm(-2147483647L),l2zm(1L));
	t_min[LLONG]=zmlshift(l2zm(1L),l2zm(63L));
	t_min[MAXINT]=t_min(LLONG);
	t_max[CHAR]=ul2zum(127L);
	t_max[SHORT]=ul2zum(32767UL);
	t_max[INT]=t_max[SHORT];
	t_max[LONG]=ul2zum(2147483647UL);
	t_max[LLONG]=zumrshift(zumkompl(ul2zum(0UL)),ul2zum(1UL));
	t_max[MAXINT]=t_max(LLONG);
	tu_max[CHAR]=ul2zum(255UL);
	tu_max[SHORT]=ul2zum(65535UL);
	tu_max[INT]=tu_max[SHORT];
	tu_max[LONG]=ul2zum(4294967295UL);
	tu_max[LLONG]=zumkompl(ul2zum(0UL));
	tu_max[MAXINT]=t_max(UNSIGNED|LLONG);

	start_ram_vars = RAM_VARS_ADDR;

	memset(game_id, 0, sizeof(game_id));
	strncpy(game_id, GAME_ID, 4);

	memset(game_name, 0, sizeof(game_id));
	strncpy(game_name, GAME_NAME, 12);

	target_macros=marray;

	for(i=0; i<26; i++)
		used_interrupt[i] = 0;

	return 1;
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

int freturn(struct Typ *t)
/*  Returns the register in which variables of type t are returned. */
/*  If the value cannot be returned in a register returns 0.        */
{
   int f=t->flags&NQ;
   if(ISSCALAR(f)&&((f&NQ)==INT||(f&NQ)==SHORT||f==CHAR))
      return ix;
   return 0;
}

int regok(int r,int t,int mode)
/*  Returns 0 if register r cannot store variables of   */
/*  type t. If t==POINTER and mode!=0 then it returns   */
/*  non-zero only if the register can store a pointer   */
/*  and dereference a pointer to mode.                  */
{
   if(!ISSCALAR(t)) return 0;
   return 1;
}

int shortcut(int c,int t)
{
	/* TODO */
	/* enable those for more optimised code */
	/*if(c==COMPARE||c==AND||c==OR||c==XOR) return 1;*/
	return 0;
}


int must_convert(int o,int t,int const_expr)
/*  Returns zero if code for converting np to type t    */
/*  can be omitted.                                     */
{
   int op=o&NQ,tp=t&NQ;
   if(op==tp) return 0;
   if(ISHWORD(op)&&ISHWORD(tp)) return 0;
   if(ISFLOAT(op)||ISFLOAT(tp)) return 1;
   if(ISLWORD(op)&&ISLWORD(tp)) return 0;
   return 1;
}

void gen_ds(FILE *f,zmax size,struct Typ *t)
/*  This function has to create <size> bytes of storage */
/*  initialized with zero.                              */
{
  /*
  if(newobj&&section!=SPECIAL)
    emit(f,"%ld\n",zm2l(size));
  else
    emit(f,"\t.space\t%ld\n",zm2l(size));
  newobj=0;
  */
  int i;
  int num_per_line = 16;
  for(i=0; i<size; ++i)
  {
     if(i % num_per_line == 0)
     emit(f, "\t.db\t");
   if(i % num_per_line == num_per_line - 1 || i == size - 1)
       emit(f, "0\n");
     else
       emit(f, "0, ");
  }
}

void gen_dc(FILE *f,int t,struct const_list *p)
/*  This function has to create static storage          */
/*  initialized with const-list p.                      */
{
  if((t&NQ)==CHAR || (t&NQ)==SHORT)
    emit(f,"\t.db\t");
  else if((t&NQ)==INT || (t&NQ)==POINTER)
    emit(f,"\t.dw\t");
  else
    emit(f,";\tdc.%s %d\t",dt(t&NQ), t&NQ);
    
  if(!p->tree)
  {
    /*
    if(ISFLOAT(t))
    {
      // auch wieder nicht sehr schoen und IEEE noetig
      unsigned char *ip;
      ip=(unsigned char *)&p->val.vdouble;
      emit(f,"0x%02x%02x%02x%02x",ip[0],ip[1],ip[2],ip[3]);
      if((t&NQ)!=FLOAT)
      {
        emit(f,",0x%02x%02x%02x%02x",ip[4],ip[5],ip[6],ip[7]);
      }
    }
    else
    */
	 emitval(f,&p->val,t&NU);
	 if((t&NQ)==CHAR && 0x20 <= p->val.vchar && p->val.vchar <=0x7f)
		emit(f, "\t; '%c'", (char)p->val.vchar);
  }
  else
  {
    emit_obj(f,&p->tree->o,t&NU);
  }
  emit(f,"\n");
  //newobj=0;
}

void gen_var_head(FILE *f,struct Var *v)
/*  This function has to create the head of a variable  */
/*  definition, i.e. the label and information for      */
/*  linkage etc.                                        */
{
  int constflag = 0;
  char *sec;
  if(v->clist) constflag=is_const(v->vtyp);
  
  if(v->tattr&ALIGN8)
  {
		emit(f, "\t.align\t8\n");
		/*
		emit(f, "\t.equ\tvbcc___unaligned_address .\n");
		emit(f, "\t.equ\tvbcc___unaligned_address2 (vbcc___unaligned_address + 7)\n");
		emit(f, "\t.equ\tvbcc___unaligned_address3 (vbcc___unaligned_address2 & 7)\n");
		emit(f, "\t.equ\tvbcc___unaligned_address4 (vbcc___unaligned_address2 - vbcc___unaligned_address3)\n");
		emit(f, "\t.org\tvbcc___unaligned_address4\n");
		*/
  }
  
  if(v->tattr&ALIGN64)
  {
		emit(f, "\t.align\t64\n");
		/*
		emit(f, "\t.equ\tvbcc___unaligned_address .\n");
		emit(f, "\t.equ\tvbcc___unaligned_address2 (vbcc___unaligned_address + 63)\n");
		emit(f, "\t.equ\tvbcc___unaligned_address3 (vbcc___unaligned_address2 & 63)\n");
		emit(f, "\t.equ\tvbcc___unaligned_address4 (vbcc___unaligned_address2 - vbcc___unaligned_address3)\n");
		emit(f, "\t.org\tvbcc___unaligned_address4\n");
		*/
  }
  
  if(/*(v->tattr&ROM) ||*/ /*constflag*/ is_const(v->vtyp))
  {
	//emit(f, "\n\t; CONST\n");
	if(!last_was_rom)
	{
		emit(f, "\t.equ\tvbcc___saved_rom_shadow .\n");
		emit(f, "\t.org\tvbcc___saved_rom_shadow - %d\n", ram_rom_distance);
		emit(f, "\t.equ\tvbcc___saved_ram_addr .\n");
		emit(f, "\t.org\tvbcc___saved_rom_addr\n");
		last_was_rom = 1;
	}
  }
  else
  {
	//emit(f, "; in ram!!!  %s%ld:  %s%s: \n",labprefix,zm2l(v->offset), idprefix,v->identifier);
	if(last_was_rom)
	{
		emit(f, "\t.equ\tvbcc___saved_rom_addr .\n");
		if(!ram_vars_initialized)
		{
			emit(f, "\t.org\t%d\n", start_ram_vars);
			emit(f, "\t.equ\tvbcc___saved_ram_addr .\n");
			ram_vars_initialized = 1;
		}
		else
		{
			emit(f, "\t.org\tvbcc___saved_ram_addr\n");
		}
		last_was_rom = 0;
	}
	else
	{
		emit(f, "\t.equ\tvbcc___saved_rom_shadow .\n");
		emit(f, "\t.org\tvbcc___saved_rom_shadow - %d\n", ram_rom_distance);
		emit(f, "\t.equ\tvbcc___saved_ram_addr .\n");
	}
  }
  
  if(v->storage_class==STATIC)
  {
    if(!ISFUNC(v->vtyp->flags))
	{
		/*
		if(!special_section(f,v)){
		  if(v->clist&&(!constflag||(g_flags[2]&USEDFLAG))&&section!=DATA){emit(f,dataname);if(f) section=DATA;}
		  if(v->clist&&constflag&&!(g_flags[2]&USEDFLAG)&&section!=RODATA){emit(f,rodataname);if(f) section=RODATA;}
		  if(!v->clist&&section!=BSS){emit(f,bssname);if(f) section=BSS;}
		}
		if(v->clist||section==SPECIAL){
		  gen_align(f,falign(v->vtyp));
		  emit(f,"%s%ld:\n",labprefix,zm2l(v->offset));
		}else
		  emit(f,"\t.lcomm\t%s%ld,",labprefix,zm2l(v->offset));
		newobj=1;
		*/
		emit(f,"%s%ld:\n",labprefix,zm2l(v->offset));
	}
  }
  if(v->storage_class==EXTERN)
  {
    //emit(f,"\t.globl\t%s%s\n",idprefix,v->identifier);
    if(v->flags&(DEFINED|TENTATIVE)){
      /*
      if(!special_section(f,v)){
        if(v->clist&&(!constflag||(g_flags[2]&USEDFLAG))&&section!=DATA){emit(f,dataname);if(f) section=DATA;}
        if(v->clist&&constflag&&!(g_flags[2]&USEDFLAG)&&section!=RODATA){emit(f,rodataname);if(f) section=RODATA;}
        if(!v->clist&&section!=BSS){emit(f,bssname);if(f) section=BSS;}
      }
      if(v->clist||section==SPECIAL){
        gen_align(f,falign(v->vtyp));
        emit(f,"%s%s:\n",idprefix,v->identifier);
      }else
        emit(f,"\t.global\t%s%s\n\t.%scomm\t%s%s,",idprefix,v->identifier,(USE_COMMONS?"":"l"),idprefix,v->identifier);
      newobj=1;
      */
      emit(f,"%s%s:\n",idprefix,v->identifier);
    }
  }
  if(!last_was_rom)
  {
	emit(f, "\t.org\tvbcc___saved_ram_addr + %d\n", ram_rom_distance);	
  }
}

static int init_dump = 0;


/*  The main code-generation routine.                   */
/*  f is the stream the code should be written to.      */
/*  p is a pointer to a doubly linked list of ICs       */
/*  containing the function body to generate code for.  */
/*  v is a pointer to the function.                     */
/*  offset is the size of the stackframe the function   */
/*  needs for local variables.                          */
void gen_code(FILE *f,struct IC *p,struct Var *v,zmax offset)
{
    int c, t, t2, i, cmp_type = 0;
    struct IC *m;

	if(!init_dump)
	{
		init_dump = 1;
		emit_start(f);
	}
	
	if(strcmp(v->identifier,"main")==0)
	{
		emit_end(f);
	}
		
    localsize=(zm2l(offset));
    for(m=p;m;m=m->next)
    {
		c=m->code;t=m->typf&NU;
		/* convert MULT/DIV/MOD with powers of two */
		if((t&NQ)<=LONG&&(m->q2.flags&(KONST|DREFOBJ))==KONST&&(t&NQ)<=LONG&&(c==MULT||((c==DIV||c==MOD)&&(t&UNSIGNED)))){
		  eval_const(&m->q2.val,t);
		  i=pof2(vmax);
		  if(i){
			if(c==MOD){
			  vmax=zmsub(vmax,l2zm(1L));
			  m->code=AND;
			}else{
			  vmax=l2zm(i-1);
			  if(c==DIV) m->code=RSHIFT; else m->code=LSHIFT;
			}
			c=m->code;
			gval.vmax=vmax;
			eval_const(&gval,MAXINT);
			if(c==AND){
			  insert_const(&m->q2.val,t);
			}else{
			  insert_const(&m->q2.val,INT);
			  m->typf2=INT;
			}
		  }
		}
        //if(c==CALL&&argsize<zm2l(m->q2.val.vmax)) argsize=zm2l(m->q2.val.vmax);
    }
 	//emit(f, ";%s\n", v->identifier);
	
	if(v->tattr&INTERRUPT)
	{
		char *p;
		
		for(p = v->identifier; *p; ++p)
			if(isdigit(*p))
				break;
		if(!*p)
		{
			fprintf(stderr, "ERROR: Interrupt routine with no interrupt number!\n");
		}
		else
		{
			int num = atoi(p);
			if(used_interrupt[num])
			{
				fprintf(stderr, "ERROR: Interrupt %d defined twice!\n", num);
			}
			else
			{
				used_interrupt[num] = 1;
				emit(f, "%s%d:\n", int_handler_prefix, num);
				
				emit(f, "\tpushax\n");
				ret="\tpopax\n\treti\n";
			}
		}
	}
	else
		ret="\tret\n";
 
    function_top(f,v,localsize);
    pushed=0;
 	

    for(;p;p=p->next)
    {
		if(debug_prints)
		{
			fprintf(f,";;;;");
			pric2(f,p);
		}
		
		c=p->code;
		t=p->typf&NU;
		t2=p->typf2&NU;
		
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
		if(c==BRA){
		  /*
		  if(t==exit_label)
			emit(f,ret);
		  else
		  */
			emit(f,"\tjmp\t%s%d\n",labprefix,t);
		  continue;
		}
		if(c>=BEQ&&c<BRA){
			int tmp_label = ++label;
			/* FIXME */
			/* some of the comparissions can be also 16-bit jumps */
			if(debug_prints)
				emit(f, "; t: 0x%x (0x%x)  so: ", cmp_type, UNSIGNED);
			if(cmp_type&UNSIGNED)
			{
				if(debug_prints)
					emit(f, "UNSIGNED\n");
				if(c < BLE)
				{
					emit(f,"\tj%s\t%s%d\n",uccs2[c-BEQ],labprefix,tmp_label);
					emit(f,"\tjmp\t%s%d\n",labprefix,t);
				}
				else
				{
					if(c==BLE)
					{
						emit(f,"\tjz\t%s%d\n",labprefix,t);
						emit(f,"\tj%s\t%s%d\n",uccs2[c-BEQ],labprefix,t);
					}
					else /* BGT */
					{
						emit(f,"\tjz\t%s%d\n",labprefix,tmp_label);
						emit(f,"\tj%s\t%s%d\n",uccs2[c-BEQ],labprefix,t);
					}
				}
			}
			else
			{
				if(debug_prints)
					emit(f, "SIGNED\n");
				emit(f,"\tj%s\t%s%d\n",ccs2[c-BEQ],labprefix,tmp_label);
				emit(f,"\tjmp\t%s%d\n",labprefix,t);
			}
			emit(f,"%s%d:\n",labprefix,tmp_label);
			continue;
		}
		if(c==MOVETOREG){
		  load_reg(f,p->z.reg,&p->q1,regtype[p->z.reg]->flags, 0);
		  continue;
		}
		if(c==MOVEFROMREG){
		  store_reg(f,p->z.reg,&p->q1,regtype[p->z.reg]->flags);
		  continue;
		}
		if(c==CALL){					
			if((p->q1.flags & (VAR|DREFOBJ)) == VAR &&
				p->q1.v->fi &&
				p->q1.v->fi->inline_asm)
			{
				emit_inline_asm(f,p->q1.v->fi->inline_asm);
			}
			else
			{
				emit(f,"\tcall\t");
				if(p->q1.v->storage_class==STATIC)
				{
					emit(f,"%s%ld",labprefix,zm2l(p->q1.v->offset));
				}
				else
				{
					emit(f,"%s%s",idprefix,p->q1.v->identifier);
				}
				emit(f,"\n");
			}		  
			if(pushed != 0)
				emit(f,"\tadd\tsp,%ld\n", pushed);			
			pushed = 0;
			continue;
		}
		
		if(c==ADDRESS)
		{
			if(isreg(z))
				zreg=p->z.reg;
			else
				zreg=ba;
			load_address(f,zreg,&p->q1,POINTER);
			save_result(f,p);
			continue;
		}
			 
		p=preload(f,p);
		c=p->code;
		
		if(c==SUBPFP) c=SUB;
		if(c==ADDI2P) c=ADD;
		if(c==SUBIFP) c=SUB;
		
		if(c==CONVERT)
		{
			/* FIXME */
			if(ISFLOAT(q1typ(p))||ISFLOAT(ztyp(p))) ierror(0);
			load_reg(f,zreg,&p->q1,t, t2);
			if(sizetab[q1typ(p)&NQ]<sizetab[ztyp(p)&NQ] && (ztyp(p)&NQ&POINTER)!=POINTER)
			{
				if(zreg == ba && msizetab[q1typ(p)&NQ] == 1)
				{
					if(q1typ(p)&UNSIGNED)
						emit(f,"\tmov\tb,0\n");
					else
						emit(f,"\tex\tba,a\n",dt(q1typ(p)),regnames[zreg]);
				}
				else
					NOT_IMP();
			}
			save_result(f,p);
			continue;
		}
		
		if(c==SETRETURN){
		  load_reg(f,p->z.reg,&p->q1,t, 0);
		  continue;
		}
		
		if(c==GETRETURN){
		  if(p->q1.reg){
			zreg=p->q1.reg;
			save_result(f,p);
		  }else
			p->z.flags=0;
		  continue;
		}
	 
		if(c==ASSIGN)
		{
			if(debug_prints)
				emit(f,"; ASSIGN start\n");
			if(t==0) 
				ierror(0);
			if(t==ARRAY)
			{
				emit_move_array(f, &p->z, &p->q1, p->q2.val.vmax);
			}
			else
			{
				load_reg(f,zreg,&p->q1,t, 0);
				save_result(f,p);
			}
			if(debug_prints)
				emit(f,"; ASSIGN end\n");
			continue;
		}
		
		if(c==PUSH)
		{
			if(t==0) ierror(0);
			pushed+=zm2l(p->q2.val.vmax);
			//emit(f,"\tmov\t[sp+%ld],",pushed);
			emit(f, "\tpush\t");
			emit_obj(f,&p->q1,t);
			emit(f,"\n");
			continue;
		}
		
		if(c==LABEL) 
		{
			emit(f,"%s%d:\n",labprefix,t);
			continue;
		}

		if(c==KOMPLEMENT)
		{
			load_reg(f,ba,&p->q1,t, 0);
			emit(f,"\tnot\ta\n");
			emit(f,"\tnot\tb\n");
			save_result(f,p);
			continue;
		}
		
		if(c==MINUS)
		{
			load_reg(f,ba,&p->q1,t, 0);
			emit(f,"\tmov\thl,0\n");
			emit(f,"\tsub\thl,ba\n");
			emit(f,"\tmov\tba,hl\n");
			save_result(f,p);
			continue;
		}
		
		if(c==TEST)
		{
			if(q1reg != ba)
			{
				emit(f, "\tmov\tba,");
				emit_obj(f,&p->q1,t);
				emit(f, "\n");
			}
			emit(f,"\tcmp\t%s,0\n", (msizetab[(t&NQ)]==1)?"a":"ba");
			continue;
		}
		
		if(c==COMPARE)
		{
			cmp_type = t;
			if(q1reg != ba)
			{
				emit(f, "\tmov\tba,");
				emit_obj(f,&p->q1,t);
				emit(f, "\n");
			}
			emit(f,"\tcmp\t%s,", (msizetab[(t&NQ)]==1)?"a":"ba");
			emit_obj(f,&p->q2,t);
			emit(f,"\n");
			continue;
		}
    
		if((c>=OR&&c<=AND)||(c>=LSHIFT&&c<=MOD))
		{
			load_reg(f, zreg, &p->q1, t, 0);
			if(c>=OR&&c<=AND)
			{
				emit_logical(f, c, &p->q2, t);
			}
			else if(c>=LSHIFT&&c<=RSHIFT)
			{
				emit_shift(f, c, &p->q2, t);
			}
			else if(c==MULT)
			{
				load_reg(f, ba, &p->q1, t, 0);
				load_reg(f, hl, &p->q2, t, 0);
				emit(f, "\tcall\tvbcc___mul16x16_16\n");
			}
			else if(DIV <=c && c <=MOD)
			{
				load_reg(f, ba, &p->q1, t, 0);
				load_reg(f, hl, &p->q2, t, 0);
				emit(f, "\tcall\tvbcc___div_mod16x16_16\n");
				if(c==MOD)
					emit(f, "\tmov\tba, hl\n");
			}
			else
			{
				if(zreg != ba)
					emit(f, "\tmov\tba,%s\n", regnames[zreg]);
				emit(f,"\t%s\t%s,",arithmetics[c-LSHIFT],regnames[ba]);
				emit_obj(f,&p->q2,t);
				emit(f,"\n");
				if(zreg != ba)
					emit(f, "\tmov\t%s,ba\n", regnames[zreg]);
			}
			save_result(f,p);
			continue;
		}
		 
		fprintf(f,";\tNOT IMPLEMENTED INSTRUCTION >>> %s <<< (code:%d)\n", ename[p->code], p->code);
		fprintf(f,";;;;");
		pric2(f,p);
    }

    function_bottom(f,v,localsize);
}

void cleanup_cg(FILE *f)
{
}

void init_db(FILE *f)
{
}
void cleanup_db(FILE *f)
{
} 
