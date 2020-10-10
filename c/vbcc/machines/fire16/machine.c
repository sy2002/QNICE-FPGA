/*
 * Backend for the Fire16 iCE40 SoftCore
 * (c) 2019 by Sylvain Munaut
 */

#define DBG

#include "supp.h"

static char FILE_[]=__FILE__;
/*  Public data that MUST be there.                             */

/* Name and copyright. */
char cg_copyright[]="vbcc code-generator for fire16 v0.1 (c) 2019 by Sylvain Munaut";

/*  Commandline-flags the code-generator accepts                */
char *g_flags_name[MAXGF]={"tiny-dmem", "tiny-pmem"};
int g_flags[MAXGF]={0, 0};
union ppi g_flags_val[MAXGF];

/*  Extended type names */
char *typname[]={"n/a", "char","short","int","long","long long",
                 "float","double","long double","void",
                 "dmem-pointer","pmem-pointer",
                 "array","struct","union","enum","function"};

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
struct reg_handle empty_reg_handle={0};

/* Names of target-specific variable attributes.                */
char *g_attr_name[]={0};


/****************************************/
/*  Private data and functions.         */
/****************************************/

/* alignment of basic data-types, used to initialize align[] */
static long malign[MAX_TYPE+1]   = {0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
/* sizes of basic data-types, used to initialize sizetab[] */
static long msizetab[MAX_TYPE+1] = {0,1,1,1,2,4,2,4,4,1,1,1,1,1,1,1,1,1,1};

/* Macros */
static char *marray[] = {
	"__pmem=__attr(\"pmem\")",
	0
};

/* Register types */
struct Typ ityp={SHORT}, ltyp={LONG};

/* Registers num */
enum {
	R_NONE = 0,
	R_R0, R_R1, R_R2, R_R3, R_R4, R_R5, R_R6, R_R7,
	R_R8, R_R9, R_RA, R_RB, R_RC, R_RD, R_RE, R_RF,
	R_S0, R_S1, R_S2, R_S3, R_S4, R_S5, R_S6, R_S7,
	R_S8, R_S9, R_SA, R_SB, R_SC, R_SD, R_SE, R_SF,
	R_R0P, R_R2P, R_R4P, R_R6P, R_R8_P, R_RAP, R_RCP, R_REP,
	R_S0P, R_S2P, R_S4P, R_S6P, R_S8_P, R_SAP, R_SCP, R_SEP,
	R_A, R_X, R_Y, R_I
};

#define isgpr(r) ((r) >= R_R0 && (r) <= R_SEP)

/* Identifier prefixes */
static const char *idprefix="_", *labprefix="l";

#define isreg(x) (((x)->flags&(REG|DREFOBJ))==REG)
#define isconst(x) (((x)->flags&(KONST|DREFOBJ))==KONST)

#define ISTSHORT(t) (((t)&NQ)==CHAR || ((t)&NQ)==SHORT || ((t)&NQ)==INT || ((t)&NQ)==DPOINTER || ((t)&NQ)==PPOINTER)
#define ISTLONG(t)  (((t)&NQ)==LONG || ((t)&NQ)==FLOAT)

#define STR_PMEM "pmem"

#define TINY_DMEM (g_flags[0] & USEDFLAG)
#define TINY_PMEM (g_flags[1] & USEDFLAG)
#define TINY_IMM(i) ( (((i) & 0xff00) == 0xff00) || (((i) & 0xff00) == 0x0000) )

static char *sym_name(struct Var *var)
{
	static char sym[128];	/* fixme ? */

	if (isstatic(var->storage_class))
		snprintf(sym, sizeof(sym)-1, "%s%ld", labprefix, zm2l(var->offset));
	else
		snprintf(sym, sizeof(sym)-1, "%s%s", idprefix, var->identifier);

	return sym;
}

static long const2long(struct obj *o, int dtyp)
{
	if (!(o->flags & KONST))
		ierror(0);
	eval_const(&o->val, dtyp);
	return zm2l(vmax);
}

struct gc_state
{
	FILE *f;

	int reg_busy[MAXR+1];	/* Track used registers */

	int op_save;		/* Saved register to restore before op end */
	long val_rv;		/* Return Value immediate (must be small enough) */
	int reg_rv;		/* Return Value register, 0=none */
	int reg_lw;		/* Register written in the last emitted op code */

	int s_argsize;
	int s_localsize;
	int s_savesize;

	int cmp_signed;		/* Last comparison was signed */
	int cmp_cur_z;		/* Current state of z flag */
};

static int
_gc_find_reg(struct gc_state *gc, int pair)
{
	int min, max, r;

	min = pair ? R_R0P : R_R0;
	max = pair ? R_SEP : R_SF;

	/* Try for a scratch reg first */
	for (r=min; r<=max; r++)
		if (!gc->reg_busy[r] && !regsa[r] && regscratch[r])
			return r;

	/* Ok ... anything will do */
	for (r=min; r<=max; r++)
		if (!gc->reg_busy[r] && !regsa[r])
			return r;

	/* Nothing :/ */
	return 0;
}


/* Stack layout: (grows toward 0)
 *
 *       ,------------------------------------------------,
 *   Y   | (next available word)                          |  <- Y pointer
 *       | arguments to called functions [size=s_argsize] |
 *       | local variables [size=s_localsize]             |
 *       | saved register [size=s_savesize]               |
 *       | return-address save [size=1]                   |
 *   Y+N | arguments to this function [size=?]            |
 *       `------------------------------------------------'
 */
static long
_gc_real_offset(struct gc_state *gc, struct Var *v, long add_offset)
{
	long off = zm2l(v->offset);

	if (off < 0) {
		/* function parameter */
		off = gc->s_localsize + gc->s_savesize + 1 - (off + zm2l(maxalign));
	}

	off += gc->s_argsize;
	off += add_offset;
	off += 1; /* Because we point to the next available word */

	return off;
}

#define _gc_emit(gc, ...) do {		\
	(gc)->reg_lw = 0;		\
	emit((gc)->f,  __VA_ARGS__ );	\
} while (0)

static void
_gc_emit_nop(struct gc_state *gc)
{
	gc->reg_lw = 0;
	gc->cmp_cur_z = 0;
	emit(gc->f, "\tnop\n" );
}

/* Emit a IMM opcode prefix if the constant requires it */
static long
_gc_emit_imm(struct gc_state *gc, long v)
{
	v = v & 0xffff;

	if ((v & 0xff00) == 0) {
		return v;
	} else if ((v & 0xff00) == 0xff00) {
		return - ((v ^ 0xffff) + 1);
	} else {
		gc->reg_lw = 0;
		emit(gc->f, "\timm\t$%d\n", (v >> 8) & 0xff);
		return v & 0xff;
	}
}

/* Emit movs between any register pairs and any single GPR & A */
static void
_gc_emit_mov(struct gc_state *gc, int dst, int src)
{
	if (src == dst)
		return;

	if ((src == gc->reg_lw) && isgpr(src))
		emit(gc->f, "\tnop\n");

	emit(gc->f, "\tmov\t%s, %s\n", regnames[dst], regnames[src]);

	BSET(regs_modified, dst);

	gc->reg_lw = isgpr(dst) ? dst : 0;
}

/* Emit opcode and checks for depencies */
static void
_gc_emit_alu(struct gc_state *gc, const char *opcode,
             int dst, int src1, int src2, long imm)
{
	int dep1 = (src1 == gc->reg_lw) && isgpr(src1);
	int dep2 = (src2 == gc->reg_lw) && isgpr(src2);
	char dst_str[16], *op1_str, op2_str[16], imm_str[16];

	if ((dep1 || dep2) && (src1 != R_I) && (src2 != R_I))
		emit(gc->f, "\tnop\n");

	if ((src1 == R_I) || (src2 == R_I)) {
		imm = _gc_emit_imm(gc, imm);
		if ((dst && (dst != R_A)) ||
		    ((src1 != R_I) && (src1 != R_A)) ||
		    ((src2 != R_I) && (src2 != R_A))) {
			emit(gc->f, "\timm\t$%d\n", imm);
			snprintf(imm_str, sizeof(imm_str)-1, "%s", regnames[R_I]);
		} else {
			snprintf(imm_str, sizeof(imm_str)-1, "$%ld", imm);
		}
	}

	dst_str[0] = op2_str[0] = 0;
	op1_str = (src1 != R_I) ? regnames[src1] : imm_str;
	if (dst)  snprintf(dst_str, sizeof(dst_str)-1, "%s, ", regnames[dst]);
	if (src2) snprintf(op2_str, sizeof(op2_str)-1, ", %s", (src2 != R_I) ? regnames[src2] : imm_str);

	emit(gc->f, "\t%s\t%s%s%s\n", opcode, dst_str, op1_str, op2_str);

	BSET(regs_modified, dst);

	gc->reg_lw = isgpr(dst) ? dst : 0;
	gc->cmp_cur_z = gc->reg_lw;
}

static void
_gc_move_gpr(struct gc_state *gc, int dst, int src)
{
	struct rpair rp_src, rp_dst;
	int ip_src, ip_dst;

	if (src == dst)
		return;

	ip_dst = reg_pair(dst, &rp_dst);
	ip_src = reg_pair(src, &rp_src);
	if ((regsize[dst] != regsize[src]) || (ip_dst != ip_src))
		ierror(0);	/* Shouldn't happen */

	if (ip_dst) {
		if (gc->reg_lw == rp_src.r1) {
			_gc_emit_mov(gc, R_A, rp_src.r2);
			_gc_emit_mov(gc, rp_dst.r2, R_A);
			_gc_emit_mov(gc, R_A, rp_src.r1);
			_gc_emit_mov(gc, rp_dst.r1, R_A);
		} else {
			_gc_emit_mov(gc, R_A, rp_src.r1);
			_gc_emit_mov(gc, rp_dst.r1, R_A);
			_gc_emit_mov(gc, R_A, rp_src.r2);
			_gc_emit_mov(gc, rp_dst.r2, R_A);
		}
	} else {
		/* _gc_emit_mov will handle if src or dst is R_A */
		_gc_emit_mov(gc, R_A, src);
		_gc_emit_mov(gc, dst, R_A);
	}
}

static void
_gc_store_to_mem(struct gc_state *gc, int val_reg, int dtyp,
                 long ptr_const, int ptr_reg, struct Var *var)
{
	struct rpair rp;
	char *opcode;
	int tiny;
	int is_pair;

	if (dtyp == DPOINTER) {
		opcode = "std";
		tiny = TINY_DMEM;
	} else if (dtyp == PPOINTER) {
		opcode = "stp";
		tiny = TINY_PMEM;
	} else {
		ierror(0);
	}

	is_pair = reg_pair(val_reg, &rp);

	if (var)
	{
		/* Variable */
		if (isauto(var->storage_class)) {
			/* Stack variable always in data mem */
			if (dtyp != DPOINTER)
				ierror(1);

			long sp_offset = _gc_real_offset(gc, var, ptr_const);

			if (sp_offset <= 15) {
				/* Offset is small enough for indexed Y access */
				if (is_pair) {
					/* 32 bit */
					_gc_emit_mov(gc, R_A, rp.r1);
					_gc_emit(gc, "\t%s\tA, [Y++, $%d]\n", opcode, sp_offset);
					_gc_emit_mov(gc, R_A, rp.r2);
					_gc_emit(gc, "\t%s\tA, [Y--, $%d]\n", opcode, sp_offset);
				} else {
					/* 16 bit */
					_gc_emit_mov(gc, R_A, val_reg);
					_gc_emit(gc, "\t%s\tA, [Y, $%d]\n", opcode, sp_offset);
				}
			} else {
				/* Offset is too large ... load address in A and fall back to code below */
				_gc_emit(gc, "\tmov\tA, Y\n");
				_gc_emit(gc, "\tadd A, A, $%d\n", sp_offset);
				ptr_reg = R_A;
			}
		} else if (isextern(var->storage_class) || isstatic(var->storage_class)) {
			/* Symbol name */
			char *sym = sym_name(var);

			/* Make access using absolute immediate addressing */
			if (reg_pair(val_reg, &rp)) {
				/* 32 bit */
				_gc_emit_mov(gc, R_A, rp.r1);
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const);
				_gc_emit_mov(gc, R_A, rp.r2);
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const+1);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const+1);
			} else {
				/* 16 bit */
				_gc_emit_mov(gc, R_A, val_reg);
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const);
			}
		} else {
			ierror(0);
		}
	}

	if (ptr_reg)
	{
		/* Register pointer */
		_gc_emit_mov(gc, R_A, ptr_reg);
		_gc_emit_mov(gc, R_X, R_A);

		if (is_pair) {
			/* 32 bit */
			_gc_emit_mov(gc, R_A, rp.r1);
			_gc_emit(gc, "\t%s\tA, [X++]\n", opcode);
			_gc_emit_mov(gc, R_A, rp.r2);
			_gc_emit(gc, "\t%s\tA, [X--]\n", opcode);
		} else {
			/* 16 bit */
			_gc_emit_mov(gc, R_A, val_reg);
			_gc_emit(gc, "\t%s\tA, [X]\n", opcode);
		}
	}

	if (!ptr_reg && !var)
	{
		/* Constant immediate pointer */
		if (is_pair) {
			/* 32 bit access */
			_gc_emit_mov(gc, R_A, rp.r1);
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? (ptr_const+0) : _gc_emit_imm(gc, ptr_const+0));
			_gc_emit_mov(gc, R_A, rp.r2);
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? (ptr_const+1) : _gc_emit_imm(gc, ptr_const+1));
		} else {
			/* 16 bit access */
			_gc_emit_mov(gc, R_A, val_reg);
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? ptr_const : _gc_emit_imm(gc, ptr_const));
		}
	}
}

static void
_gc_load_from_mem(struct gc_state *gc, int val_reg, int dtyp,
                 long ptr_const, int ptr_reg, struct Var *var)
{
	struct rpair rp;
	char *opcode;
	int tiny;
	int is_pair;

	if (dtyp == DPOINTER) {
		opcode = "ldd";
		tiny = TINY_DMEM;
	} else if (dtyp == PPOINTER) {
		opcode = "ldp";
		tiny = TINY_PMEM;
	} else {
		ierror(0);
	}

	is_pair = reg_pair(val_reg, &rp);

	if (var)
	{
		/* Variable */
		if (isauto(var->storage_class)) {
			/* Stack variable always in data mem */
			if (dtyp != DPOINTER)
				ierror(1);

			long sp_offset = _gc_real_offset(gc, var, ptr_const);

			if (sp_offset <= 15) {
				/* Offset is small enough for indexed Y access */
				if (is_pair) {
					/* 32 bit */
					_gc_emit(gc, "\t%s\tA, [Y++, $%d]\n", opcode, sp_offset);
					_gc_emit_mov(gc, rp.r1, R_A);
					_gc_emit(gc, "\t%s\tA, [Y--, $%d]\n", opcode, sp_offset);
					_gc_emit_mov(gc, rp.r2, R_A);
				} else {
					/* 16 bit */
					_gc_emit(gc, "\t%s\tA, [Y, $%d]\n", opcode, sp_offset);
					_gc_emit_mov(gc, val_reg, R_A);
				}
			} else {
				/* Offset is too large ... load address in A and fall back to code below */
				_gc_emit(gc, "\tmov\tA, Y\n");
				_gc_emit(gc, "\tadd A, A, $%d\n", sp_offset);
				ptr_reg = R_A;
			}
		} else if (isextern(var->storage_class) || isstatic(var->storage_class)) {
			/* Symbol name */
			char *sym = sym_name(var);

			/* Make access using absolute immediate addressing */
			if (is_pair) {
				/* 32 bit */
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const);
				if (dtyp == PPOINTER) _gc_emit_nop(gc);
				_gc_emit_mov(gc, rp.r1, R_A);
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const+1);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const+1);
				if (dtyp == PPOINTER) _gc_emit_nop(gc);
				_gc_emit_mov(gc, rp.r2, R_A);
			} else {
				/* 16 bit */
				if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ptr_const);
				_gc_emit(gc, "\t%s\tA, [$(lo(%s+%d))]\n", opcode, sym, ptr_const);
				if (dtyp == PPOINTER) _gc_emit_nop(gc);
				_gc_emit_mov(gc, val_reg, R_A);
			}
		} else {
			ierror(0);
		}
	}

	if (ptr_reg)
	{
		/* Register pointer */
		_gc_emit_mov(gc, R_A, ptr_reg);
		_gc_emit_mov(gc, R_X, R_A);

		if (is_pair) {
			/* 32 bit access */
			_gc_emit(gc, "\t%s\tA, [X++]\n", opcode);
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc, rp.r1, R_A);
			_gc_emit(gc, "\t%s\tA, [X--]\n", opcode);
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc, rp.r2, R_A);
		} else {
			/* 16 bit access */
			_gc_emit(gc, "\t%s\tA, [X]\n", opcode);
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc, val_reg, R_A);
		}
	}

	if (!ptr_reg && !var)
	{
		/* Constant immediate pointer */
		if (is_pair) {
			/* 32 bit access */
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? (ptr_const+0) : _gc_emit_imm(gc, ptr_const+0));
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc, rp.r1, R_A);
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? (ptr_const+1) : _gc_emit_imm(gc, ptr_const+1));
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc,rp.r2, R_A);
		} else {
			/* 16 bit access */
			_gc_emit(gc, "\t%s\tA, [$%d]\n", opcode,
				tiny ? ptr_const : _gc_emit_imm(gc, ptr_const));
			if (dtyp == PPOINTER) _gc_emit_nop(gc);
			_gc_emit_mov(gc, val_reg, R_A);
		}
	}
}

/* Selects a register for the result to be computed in */
static int
_gc_store_sel(struct IC *p)
{
	int t;

	/* Register destination ? */
	if (isreg(&p->z))
		return p->z.reg;

	/* If not, use the scratch registers as temporaries */
	/* (ideally we should find some free scratch ones and use that
	 *  instead of having 'reserved' ones ...) */
	t = ztyp(p) & NQ;
	if (ISSCALAR(t) && (msizetab[t] == 1))
		return R_RF;
	if (ISSCALAR(t) && (msizetab[t] == 2))
		return R_REP;

	/* Couldn't find a fit ? */
	ierror(0);
}

static void
_gc_op_pre(struct gc_state *gc, struct IC *p, int n_op,
           int *r_z, int *r_q1, int *r_q2, long *k)
{
	int is32b;
	int t = q1typ(p) & NQ;
	int z;

	/* Init */
	gc->op_save = 0;

	/* Type */
	if (ISSCALAR(t) && (msizetab[t] == 1))
		is32b = 0;
	else if (ISSCALAR(t) && (msizetab[t] == 2))
		is32b = 1;
	else
		ierror(0);

	/* Where to place the destination ? */
	if (r_z && isreg(&p->z))
		z = p->z.reg;
	else
		z = is32b ? R_REP : R_RF;	/* R_A is needed for the store_op */

	if (r_z) *r_z = z;

	/* Where can we load q1 ? */
	if (isreg(&p->q1))
		*r_q1 = p->q1.reg;
	else if (isconst(&p->q1)) {
		*r_q1 = R_I;
		*k = const2long(&p->q1, q1typ(p));
	} else {
		if (isreg(&p->q2) || isconst(&p->q2) || (n_op < 2))
			*r_q1 = R_A;
		else
			*r_q1 = z;
	}

	/* q2 ? */
	if (n_op != 2)
		return;

	if (isreg(&p->q2))
		*r_q2 = p->q2.reg;
	else if (isconst(&p->q2)) {
		*r_q2 = R_I;
		*k = const2long(&p->q2, q2typ(p));
	} else if (*r_q1 != z) {
		*r_q2 = z;
	} else if (!is32b) {
		*r_q2 = (*r_q1 == R_A) ? R_RE : R_A;
	} else if (z != R_REP) {
		*r_q2 = R_REP;
	} else {
		/* At this point we have nowhere safe to load a 32b q2 :/ */
		*r_q2 = _gc_find_reg(gc, 1);
		if (!*r_q2)
			*r_q2 = R_RCP;
		gc->op_save = !regscratch[*r_q2] ? *r_q2 : 0;
	}

	if (gc->op_save) {
		struct rpair rp;
		reg_pair(gc->op_save, &rp);
		_gc_emit_mov(gc, R_A, rp.r1);
		_gc_emit(gc, "\tstd\tA, [Y--]\n");
		_gc_emit_mov(gc, R_A, rp.r2);
		_gc_emit(gc, "\tstd\tA, [Y--]\n");
	}
}

static void
_gc_op_post(struct gc_state *gc, struct IC *p)
{
	if (gc->op_save) {
		struct rpair rp;
		reg_pair(gc->op_save, &rp);
		_gc_emit(gc, "\tldd\tA, [Y++, $1]\n");
		_gc_emit_mov(gc, rp.r2, R_A);
		_gc_emit(gc, "\tldd\tA, [Y++, $1]\n");
		_gc_emit_mov(gc, rp.r1, R_A);
	}

	gc->op_save = 0;
}

/* Load an object into a register */
static void
_gc_load_op(struct gc_state *gc, struct obj *q, int dst, int typf)
{
	struct rpair rp;

	/* Source already in register ? */
	if (isreg(q))
	{
		_gc_move_gpr(gc, dst, q->reg);
		return;
	}

	/* Is this a dereference ? */
	if (q->flags & DREFOBJ)
	{
		long ptr_imm = 0;
		int ptr_reg = 0;

		if (q->flags & KONST) {
			/* Constant address load */
			ptr_imm = const2long(q, pointer_type(q->v->vtyp));
		} else if (q->flags & REG) {
			/* Dereference value in register */
			ptr_reg = q->reg;
		} else {
			/* Load variable content */
			ptr_reg = R_A;
			_gc_load_from_mem(gc, R_A, pointer_type(q->v->vtyp), zm2l(zl2zm(q->val.vlong)), 0, q->v);
		}

		/* Execute dereference */
		_gc_load_from_mem(gc, dst, q->dtyp, ptr_imm, ptr_reg, NULL);
	}
	else
	{
		if (q->flags & KONST) {
			/* Constant load */
			long k = const2long(q, typf);

			if (reg_pair(dst, &rp)) {
				/* 32 bit */
				long v = k & 0xffff;
				v = _gc_emit_imm(gc, v);
				_gc_emit(gc, "\tmov\tA, $%d\n", v);
				_gc_emit_mov(gc, rp.r1, R_A);
				v = (k >> 16) & 0xffff;
				v = _gc_emit_imm(gc, v);
				_gc_emit(gc, "\tmov\tA, $%d\n", v);
				_gc_emit_mov(gc, rp.r2, R_A);
			} else {
				/* 16 bit */
				k = _gc_emit_imm(gc, k);
				_gc_emit(gc, "\tmov\tA, $%d\n", k);
				_gc_emit_mov(gc, dst, R_A);
			}
		} else if (q->flags & VARADR) {
			/* Variable address load */
			int tiny = (pointer_type(q->v->vtyp) == DPOINTER) ? TINY_DMEM : TINY_PMEM;
			long ofs = zm2l(zl2zm(q->val.vlong));
			char *sym = sym_name(q->v);

			if (!tiny) _gc_emit(gc, "\timm\t$(hi(%s+%d))\n", sym, ofs);
			_gc_emit(gc, "\tmov\tA, [$(lo(%s+%d))]\n", sym, ofs);
			_gc_emit_mov(gc, dst, R_A);
		} else if (!(q->flags & REG)) {
			/* Variable load */
			_gc_load_from_mem(gc, dst, pointer_type(q->v->vtyp), zm2l(zl2zm(q->val.vlong)), 0, q->v);
		}
	}
}

/* Store a register into its final destination */
static void
_gc_store_op(struct gc_state *gc, struct obj *z, int src, int typf)
{
	struct rpair rp;
	int reg;

	/* Register destination ? */
	if (isreg(z))
	{
		_gc_move_gpr(gc, z->reg, src);
		return;
	}

	/* Is this a dereference ? */
	if (z->flags & DREFOBJ)
	{
		long ptr_imm = 0;
		int ptr_reg = 0;

		if (z->flags & KONST) {
			/* Constant address load */
			ptr_imm = const2long(z, pointer_type(z->v->vtyp));
		} else if (z->flags & REG) {
			/* Dereference value in register */
			ptr_reg = z->reg;
		} else {
			/* Load variable content */
			ptr_reg = R_A;
			_gc_load_from_mem(gc, R_A, pointer_type(z->v->vtyp), zm2l(zl2zm(z->val.vlong)), 0, z->v);
		}

		/* Execute dereference */
		_gc_store_to_mem(gc, src, z->dtyp, ptr_imm, ptr_reg, NULL);
	}
	else if (z->flags & VAR)
	{
		/* Variable store */
		_gc_store_to_mem(gc, src, pointer_type(z->v->vtyp), zm2l(zl2zm(z->val.vlong)), 0, z->v);
	}
	else
	{
		/* huh ? */
		ierror(0);
	}
}


static void
gc_func_begin(struct gc_state *gc,
              FILE *f, struct IC *p, struct Var *v, zmax offset)
{
	int i;

	/* Reset state */
	memset(gc, 0x00, sizeof(struct gc_state));

	gc->f = f;

	/* Init register usage */
	for (i=1; i<=MAXR; i++)
		gc->reg_busy[i] = regsa[i];

	/* Section and symbol setup */
	if (isextern(v->storage_class))
		emit(f, "\t.text\n%s%s:\n", idprefix, v->identifier);
	else
		emit(f, "\t.text\n%s%d:\n", labprefix, zm2l(v->offset));

	/* Debug */
#ifdef DBG
	emit(gc->f, "\t; Function prologue\n");
#endif

	/* Function prologue */
		/* Save return address */
	emit(f, "\tmov\tA, X\n");
	emit(f, "\tstd\tA, [Y--]\n");

		/* Save all registers need saving */
	for (i=1; i<=MAXR; i++) {
		if (regused[i] && !regscratch[i] && !regsa[i])
		{
			struct rpair rp;
			if (reg_pair(i, &rp)) {
				if (!regused[rp.r1]) {
					emit(f, "\tmov\tA, %s\n", regnames[rp.r1]);
					emit(f, "\tstd\tA, [Y--]\n");
					gc->s_savesize += 1;
				}
				if (!regused[rp.r2]) {
					emit(f, "\tmov\tA, %s\n", regnames[rp.r2]);
					emit(f, "\tstd\tA, [Y--]\n");
					gc->s_savesize += 1;
				}
			} else {
				emit(f, "\tmov\tA, %s\n", regnames[i]);
				emit(f, "\tstd\tA, [Y--]\n");
				gc->s_savesize += 1;
			}
		}
	}

		/* Adjust SP for local variables */
	gc->s_localsize = zm2l(offset);

	if (gc->s_localsize <= 2) {
		for (i=0; i<gc->s_localsize; i++)
			emit(f, "\tldd\tA, [Y--]\n");	/* Useless op */
	} else {
		emit(f, "\tmov\tA, Y\n");
		emit(f, "\tadd\tA, A, $%d\n", -gc->s_localsize);
		emit(f, "\tmov\tY, A\n");
	}

	/* Modifieds regs in all cases */
	BSET(regs_modified, R_A);
	BSET(regs_modified, R_X);
	BSET(regs_modified, R_Y);
}

static void
gc_func_end(struct gc_state *gc,
            FILE *f, struct IC *p, struct Var *v, zmax offset)
{
	int i;

	/* Debug */
#ifdef DBG
	emit(gc->f, "\n\t; Function epilogue\n");
#endif

	/* Function epilogue */
		/* Re-adjust SP */
	if (gc->s_localsize <= 2) {
		for (i=0; i<gc->s_localsize; i++)
			emit(f, "\tldd\tA, [Y++]\n");	/* Useless op */
	} else {
		emit(f, "\tmov\tA, Y\n");
		emit(f, "\tadd\tA, A, $%d\n", gc->s_localsize);
		emit(f, "\tmov\tY, A\n");
	}

		/* Restore saved registers */
	for (i=MAXR; i>=1; i--) {
		if (regused[i] && !regscratch[i] && !regsa[i])
		{
			struct rpair rp;
			if (reg_pair(i, &rp)) {
				if (!regused[rp.r2]) {
					emit(f, "\tldd\tA, [Y++, $1]\n");
					emit(f, "\tmov\t%s, A\n", regnames[rp.r2]);
				}
				if (!regused[rp.r1]) {
					emit(f, "\tldd\tA, [Y++, $1]\n");
					emit(f, "\tmov\t%s, A\n", regnames[rp.r1]);
				}
			} else {
				emit(f, "\tldd\tA, [Y++, $1]\n");
				emit(f, "\tmov\t%s, A\n", regnames[i]);
			}
		}
	}

		/* Return address */
	emit(f, "\tldd\tA, [Y++, $1]\n");
	emit(f, "\tmov\tX, A\n");

		/* Return value */
	emit(f, "\tbax\n");
	if (gc->reg_rv)
		emit(f, "\tmov\tA, %s\n", regnames[gc->reg_rv]);
	else
		emit(f, "\tmov\tA, $%d\n", gc->val_rv);

	/* Bit of spacing */
	emit(gc->f, "\n\n");
}

static void
gc_func_assign(struct gc_state *gc, struct IC *node)
{
	/* FIXME: Only works for size=1 | size=2 ... */
	int v_reg;

	if (isreg(&node->q1)) {
		v_reg = node->q1.reg;
	} else {
		v_reg = _gc_store_sel(node);
		_gc_load_op(gc, &node->q1, v_reg, q1typ(node));
	}

	_gc_store_op(gc, &node->z, v_reg, ztyp(node));
}

static void
gc_func_convert(struct gc_state *gc, struct IC *node)
{
	struct rpair rp;
	int qt = q1typ(node) & NQ;
	int zt = ztyp(node)  & NQ;
	int sext = !(q1typ(node) & UNSIGNED);
	int v_reg;

	if ((zt == LONG) && (qt >= CHAR) && (qt <= INT)) {
		/* Convert from short to long */
		v_reg = _gc_store_sel(node);

		if (!reg_pair(v_reg, &rp))
			ierror(0);

		_gc_load_op(gc, &node->q1, rp.r1, q1typ(node));

		if (sext) {
			_gc_emit_alu(gc, "rol", R_A, rp.r1, 0, 0);
			_gc_emit_alu(gc, "and", R_A, R_A, R_I, 1);
			_gc_emit_alu(gc, "sub", R_A, R_A, R_I, 0);
			_gc_emit_mov(gc, rp.r2, R_A);
		} else {
			_gc_emit(gc, "\tmov\tA, $0\n");
			_gc_emit_mov(gc, rp.r2, R_A);
		}
	} else if ((zt >= CHAR) && (zt <= INT) && (qt == LONG)) {
		/* Convert from long to short */
		if (isreg(&node->q1)) {
			/* Long already in register, so get the LSB from pair and do store */
			if (!reg_pair(node->q1.reg, &rp))
				ierror(0);

			v_reg = rp.r1;
		} else {
			/* Perform a load as if it was a short. Because of Little-Endian, it works */
			v_reg = _gc_store_sel(node);
			_gc_load_op(gc, &node->q1, v_reg, q1typ(node));
		}
	} else if (ISPOINTER(zt) && ISPOINTER(qt)) {
		/* No way to convert between pointer types to different spaces ... */
		ierror(1);
	} else {
		/* Shouldn't happen, all other conversions are lib_call */
		ierror(0);
	}

	_gc_store_op(gc, &node->z, v_reg, ztyp(node));
}

static void
gc_func_alu_2op(struct gc_state *gc, struct IC *node)
{
	const char *opcode, *opcode2;
	struct rpair rpz, rp1, rp2;
	int regz, reg1, reg2, regt;
	long k;
	int is32b, issub, isadd;

	is32b = ISTLONG(ztyp(node));
	isadd = (node->code == ADD) || (node->code == ADDI2P);
	issub = (node->code == SUB) || (node->code == SUBIFP) || (node->code == SUBPFP);

	/* Load operands */
	_gc_op_pre(gc, node, 2, &regz, &reg1, &reg2, &k);

	if (!isreg(&node->q1) && !isconst(&node->q1))
		_gc_load_op(gc, &node->q1, reg1, q1typ(node));

	if (!isreg(&node->q2) && !isconst(&node->q2))
		_gc_load_op(gc, &node->q2, reg2, q2typ(node));

	/* We can only have immediate in reg2. Also 'sub' is swapped vs hw */
	if (issub) {
		if (reg2 == R_I) {
			node->code = ADD;
			k = -k;
		} else {
			regt = reg1;
			reg1 = reg2;
			reg2 = regt;
		}
	} else if (reg1 == R_I) {
		regt = reg1;
		reg1 = reg2;
		reg2 = regt;
	}

	/* Solve reg-pairs */
	reg_pair(regz, &rpz);
	reg_pair(reg1, &rp1);
	reg_pair(reg2, &rp2);

	if (reg2 == R_I)
		rp2.r1 = rp2.r2 = R_I;

	/* Select opcode */
	switch (node->code) {
	case OR:  opcode = "or";  opcode2 = "or";   break;
	case XOR: opcode = "xor"; opcode2 = "xor";   break;
	case AND: opcode = "and"; opcode2 = "and";   break;
	case ADD: opcode = "add"; opcode2 = "addcy"; break;
	case SUB: opcode = "sub"; opcode2 = "subcy"; break;
	case ADDI2P: opcode = "add"; opcode2 = NULL; break;
	case SUBIFP: opcode = "sub"; opcode2 = NULL; break;
	case SUBPFP: opcode = "sub"; opcode2 = NULL; break;
	default: ierror(0);
	}

	/* Do the operation */
	if (is32b) {
		if (regz == reg1) {
			if (reg2 == R_I) {
				/* 1 single GPR (reg1 == regz) and one immediate */
				_gc_emit_alu(gc, opcode,  rpz.r1, rp1.r1, R_I, k & 0xffff);
				_gc_emit_alu(gc, opcode2, rpz.r2, rp1.r2, R_I, (k >> 16) & 0xffff);
			} else {
				/* 2 different GPRs, reg1 == regz */
				_gc_emit_mov(gc, R_A, rp2.r1);
				_gc_emit_alu(gc, opcode,  rpz.r1, rp1.r1, R_A, 0);
				_gc_emit_mov(gc, R_A, rp2.r2);
				_gc_emit_alu(gc, opcode2, rpz.r2, rp1.r2, R_A, 0);
			}
		} else if (regz == reg2) {
			/* 2 different GPRs, reg2 == regz */
			_gc_emit_mov(gc, R_A, rp1.r1);
			_gc_emit_alu(gc, opcode,  rpz.r1, R_A, rp2.r1, 0);
			_gc_emit_mov(gc, R_A, rp1.r2);
			_gc_emit_alu(gc, opcode2, rpz.r2, R_A, rp2.r2, 0);
		} else if (reg2 == R_I) {
			/* 2 different GPRs and one immediate */
			_gc_emit_mov(gc, R_A, rp1.r1);
			_gc_emit_alu(gc, opcode,  rpz.r1, R_A, rp2.r1, k & 0xffff);
			_gc_emit_mov(gc, R_A, rp1.r2);
			_gc_emit_alu(gc, opcode2, rpz.r2, R_A, rp2.r2, (k >> 16) & 0xffff);
		} else {
			/* 3 different GPRs pair */
			_gc_emit_mov(gc, R_A, rp1.r1);
			_gc_emit_alu(gc, opcode,  R_A, R_A, rp2.r1, 0);
			_gc_emit_mov(gc, rpz.r1, R_A);
			_gc_emit_mov(gc, R_A, rp1.r2);
			_gc_emit_alu(gc, opcode2, R_A, R_A, rp2.r2, 0);
			_gc_emit_mov(gc, rpz.r2, R_A);
		}
	} else {
		/* Count GPRs */
		int ngpr = isgpr(regz) + isgpr(reg1) + isgpr(reg2);

		/* Detect INC / DEC */
		if ((reg2 == R_I) && ((k == 1) || (k == -1)) && (isadd || issub))
		{
			opcode = ((k == -1) ^ (node->code == SUB)) ? "dec" : "inc";

			if ((regz == reg1) || (regz == R_A) || (reg1 == R_A)) {
				_gc_emit_alu(gc, opcode, regz, reg1, 0, 0);
			} else {
				_gc_emit_alu(gc, opcode, R_A, reg1, 0, 0);
				_gc_emit_mov(gc, regz, R_A);
			}
		}

		/* Classic ALU */
		else if (ngpr < 2) {
			_gc_emit_alu(gc, opcode, regz, reg1, reg2, k);
		} else if (ngpr == 2) {
			if (regz == R_A) {
				_gc_emit_mov(gc, R_A, reg1);
				_gc_emit_alu(gc, opcode, R_A, R_A, reg2, k);
			} else if ((regz == reg1) || (regz == reg2)) {
				_gc_emit_alu(gc, opcode, regz, reg1, reg2, k);
			} else {
				_gc_emit_alu(gc, opcode, R_A, reg1, reg2, k);
				_gc_emit_mov(gc, regz, R_A);
			}
		} else {
			if (regz == reg1) {
				_gc_emit_mov(gc, R_A, reg2);
				_gc_emit_alu(gc, opcode, regz, regz, R_A, 0);
			} else if (regz == reg2) {
				_gc_emit_mov(gc, R_A, reg1);
				_gc_emit_alu(gc, opcode, regz, regz, R_A, 0);
			} else {
				_gc_emit_mov(gc, R_A, reg1);
				_gc_emit_alu(gc, opcode, R_A, R_A, reg2, 0);
				_gc_emit_mov(gc, regz, R_A);
			}
		}
	}

	/* Store result */
	_gc_store_op(gc, &node->z, regz, ztyp(node));

	/* Allow 'test' optimization */
	gc->cmp_cur_z = regz;

	/* Clean up */
	_gc_op_post(gc, node);
}

static void
gc_func_not(struct gc_state *gc, struct IC *node)
{
	struct rpair rp;
	int l_reg, z_reg, is32b;

	z_reg = _gc_store_sel(node);
	is32b = reg_pair(z_reg, &rp);
	l_reg = (is32b || (isreg(&node->q1) && (node->q1.reg != z_reg))) ? z_reg : R_A;

	_gc_load_op(gc, &node->q1, l_reg, q1typ(node));

	if (is32b) {
		_gc_emit(gc, "\tmov\tA, $0xffff\n");
		_gc_emit_alu(gc, "xor", rp.r1, rp.r1, R_A, 0);
		_gc_emit_alu(gc, "xor", rp.r2, rp.r2, R_A, 0);
	} else {
		_gc_emit_alu(gc, "xor", z_reg, l_reg, R_I, 0xffff);
	}

	_gc_store_op(gc, &node->z, z_reg, ztyp(node));
}

static void
gc_func_neg(struct gc_state *gc, struct IC *node)
{
	struct rpair rp;
	int l_reg, z_reg, is32b;

	z_reg = _gc_store_sel(node);
	is32b = reg_pair(z_reg, &rp);
	l_reg = (is32b || (isreg(&node->q1) && (node->q1.reg != z_reg))) ? z_reg : R_A;

	_gc_load_op(gc, &node->q1, l_reg, q1typ(node));

	if (is32b) {
		_gc_emit(gc, "\tmov\tA, $0\n");
		_gc_emit_alu(gc, "sub",  rp.r1, rp.r1, R_A, 0);
		_gc_emit_alu(gc, "subcy", rp.r2, rp.r2, R_A, 0);
	} else {
		_gc_emit_alu(gc, "sub", z_reg, l_reg, R_I, 0);
	}

	_gc_store_op(gc, &node->z, z_reg, ztyp(node));
}

static void
gc_func_shift(struct gc_state *gc, struct IC *node)
{
	/* FIXME */
}

static void
gc_func_allocreg(struct gc_state *gc, struct IC *node)
{
	struct rpair rp;
	int reg = node->q1.reg;

	if (reg_pair(reg, &rp)) {
		gc->reg_busy[rp.r1] = 1;
		gc->reg_busy[rp.r2] = 1;
	}
	gc->reg_busy[reg] = 1;
}

static void
gc_func_freereg(struct gc_state *gc, struct IC *node)
{
	int reg = node->q1.reg;
	if (regsa[reg])
		return;

	if (reg_pair(reg, &rp)) {
		gc->reg_busy[rp.r1] = 0;
		gc->reg_busy[rp.r2] = 0;
	}
	gc->reg_busy[reg] = 0;
}

static void
gc_func_cmp_test(struct gc_state *gc, struct IC *node)
{
	struct rpair rp1, rp2;
	int reg1, reg2;
	long k;
	int istest, is32b;

	istest = (node->code == TEST);
	is32b = ISTLONG(q1typ(node));

	/* Can this be optimized out ? */
	if (istest && isreg(&node->q1) && (node->q1.reg == gc->cmp_cur_z))
		return;

	/* Load operands */
	_gc_op_pre(gc, node, istest?1:2, NULL, &reg1, &reg2, &k);

	if (!isreg(&node->q1) && !isconst(&node->q1))
		_gc_load_op(gc, &node->q1, reg1, q1typ(node));

	if (!istest && !isreg(&node->q2) && !isconst(&node->q2))
		_gc_load_op(gc, &node->q2, reg2, q2typ(node));

	reg_pair(reg1, &rp1);
	reg_pair(reg2, &rp2);

	if (reg2 == R_I)
		rp2.r1 = rp2.r2 = R_I;

	/* Do the compare */
	if (is32b) {
		/* 32b compare */
		if (istest) {
			_gc_emit_mov(gc, R_A, rp1.r2);
			_gc_emit_alu(gc, "or", R_A, R_A, rp1.r1, 0);
		} else {
			_gc_emit_mov(gc, R_A, rp1.r1);
			_gc_emit_alu(gc, "sub", R_A, R_A, rp2.r1, k & 0xffff);
			_gc_emit_mov(gc, R_A, rp1.r2);
			_gc_emit_alu(gc, "subcy", R_A, R_A, rp2.r2, (k >> 16) & 0xffff);
		}
	} else {
		/* 16b compare */
		if (node->code == TEST) {
			_gc_emit_alu(gc, "test", 0, reg1, R_I, 0xffff);
		} else {
			_gc_emit_alu(gc, "cmp", 0, reg1, reg2, k);
		}
	}

	/* Clean up */
	_gc_op_post(gc, node);
}

static void
gc_func_branch(struct gc_state *gc, struct IC *node)
{
	const char *cc, *ecc;
	char label[16];

	/* If q1 exists, it's the result of an lib_call compare */
	if (node->q1.flags) {
		int r;
		if (isreg(&node->q1)) {
			r = node->q1.reg;
		} else {
			_gc_load_op(gc, &node->q1, R_A, q1typ(node));
			r = R_A;
		}
		_gc_emit_alu(gc, "cmp", 0, r, -1, 0);
		gc->cmp_signed = 1;
	}

	/* Select condition code */
	switch (node->code) {
		case BRA: ecc = NULL; cc = ""; break;
		case BEQ: ecc = NULL; cc = ".z"; break;
		case BNE: ecc = NULL; cc = ".nz"; break;
		case BLT: ecc = gc->cmp_signed ? "gt" : "hi"; cc = ".z"; break;
		case BGE: ecc = gc->cmp_signed ? "gt" : "hi"; cc = ".nz"; break;
		case BLE: ecc = gc->cmp_signed ? "ge" : "hs"; cc = ".z"; break;
		case BGT: ecc = gc->cmp_signed ? "ge" : "hs"; cc = ".nz"; break;
		default: ierror(0);
	}

	if (ecc)
		_gc_emit(gc, "\tcc\t%s\n", ecc);

	snprintf(label, sizeof(label)-1, "%s%d", labprefix, node->typf);
	_gc_emit(gc, "\timm\t$hi(%s)\n", label);
	_gc_emit(gc, "\tba%s\t$lo(%s)\n", cc, label);
	_gc_emit_nop(gc);
}

static void
gc_func_label(struct gc_state *gc, struct IC *node)
{
	_gc_emit(gc, "%s%d:\n", labprefix, node->typf);
}

static void
gc_func_call(struct gc_state *gc, struct IC *node)
{
	if ((node->q1.flags & (VAR | DREFOBJ)) == VAR &&
	     node->q1.v->fi && node->q1.v->fi->inline_asm)
	{
		emit_inline_asm(gc->f, node->q1.v->fi->inline_asm);
	}
	else if (node->q1.flags & DREFOBJ)
	{
		/* Function pointer */
		if (node->q1.dtyp != PPOINTER)
			ierror(1);

		if (node->q1.flags & KONST) {
			/* Constant, do immediate jump */
			long k = const2long(&node->q1, node->q1.dtyp);
			k = _gc_emit_imm(gc, k);
			_gc_emit(gc, "\tbal\t$%d\n", k);
		} else {
			/* Load variable into A */
			if (node->q1.flags & REG)
				_gc_emit_mov(gc, R_A, node->q1.reg);
			else
				_gc_load_from_mem(gc, R_A, pointer_type(node->q1.v->vtyp), zm2l(zl2zm(node->q1.val.vlong)), 0, node->q1.v);

			/* Do the jump */
			_gc_emit_mov(gc, R_X, R_A);
			_gc_emit(gc, "\tbalx\tX\n");
		}

		_gc_emit_nop(gc);
	}
	else
	{
		char *sym = sym_name(node->q1.v);

		if (!TINY_PMEM) _gc_emit(gc, "\timm\t$(hi(%s))\n", sym);
		_gc_emit(gc, "\tbal\t$(lo(%s))\n", sym);

		_gc_emit_nop(gc);
	}

	/* FIXME: fixup stack pointer after the call ?!? */
}

static void
gc_func_push(struct gc_state *gc, struct IC *node)
{
	/* FIXME */
}

static void
gc_func_getreturn(struct gc_state *gc, struct IC *node)
{
	int dst_reg;

	/* Is it relevant at all ? */
	if (!node->q1.reg) {
		ierror(0);
		return;
	}

	/* Is the target a register ? */
	if (isreg(&node->z))
	{
		/* Yes, need move */
		_gc_move_gpr(gc, node->z.reg, node->q1.reg);
	} else {
		/* Nope, not supported */
		ierror(0);
	}
}

static void
gc_func_setreturn(struct gc_state *gc, struct IC *node)
{
	int src_reg;

	/* Is it relevant at all ? */
	if (!node->z.reg) {
		ierror(0);
		return;
	}

	/* Special case for small constants */
	if ((node->z.reg == R_A) && isconst(&node->q1)) {
		gc->val_rv = const2long(&node->q1, q1typ(node));
		return;
	}

	/* Load value into register */
	src_reg = node->z.reg;
	_gc_load_op(gc, &node->q1, src_reg, q1typ(node));

	/* If the target is R_A, we need to defer */
	if (node->z.reg == R_A) {
		if ((regscratch[src_reg] || regsa[src_reg]) && (src_reg != R_A)) {
			gc->reg_rv = src_reg;
		} else {
			_gc_emit_mov(gc, R_A, src_reg);
			_gc_emit_mov(gc, R_R0, R_A);
			gc->reg_rv = R_R0;
			gc->reg_lw = R_R0;
			BSET(regs_modified, R_R0);
		}
	} else {
		_gc_move_gpr(gc, node->z.reg, src_reg);
	}
}

static void
gc_func_movefromreg(struct gc_state *gc, struct IC *node)
{
	_gc_store_op(gc, &node->z, node->q1.reg, ztyp(node));
}

static void
gc_func_movetoreg(struct gc_state *gc, struct IC *node)
{
	_gc_load_op(gc, &node->q1, node->z.reg, q1typ(node));
}

static void
gc_func_address(struct gc_state *gc, struct IC *node)
{
	long sp_offset;

	/* q1 is always an 'auto' (stack object) */
	if (ztyp(node) != DPOINTER)
		ierror(1);

	if (!isauto(node->q1.v->storage_class))
		ierror(0);

	/* Compute real offset */
	sp_offset = _gc_real_offset(gc, node->q1.v, zm2l(zl2zm(node->q1.val.vlong)));

	_gc_emit_mov(gc, R_A, R_Y);
	_gc_emit_alu(gc, "add", R_A, R_A, R_I, sp_offset);

	/* Store it where we were asked */
	_gc_store_op(gc, &node->z, R_A, ztyp(node));
}

static void
gc_func_ic(struct gc_state *gc, struct IC *node)
{
	/* If nop, abort early */
	if (node->code == NOP)
		return;

	/* Un-needed converts */
	if (node->code == CONVERT && !must_convert(node->typf,node->typf2,0)) {
		node->code = ASSIGN;
		node->q2.val.vmax = sizetab[node->typf&NQ];
	}

	/* Debug */
#ifdef DBG
	emit(gc->f, "\n\t; %s\n", ename[node->code]);
#endif

	/* Main dispatch */
#define GC_OP(c,n) case c: gc_func_ ## n (gc, node); break;

	switch (node->code)
	{
	GC_OP(ASSIGN,		assign)
	GC_OP(CONVERT,		convert)
	GC_OP(OR,		alu_2op)
	GC_OP(XOR,		alu_2op)
	GC_OP(AND,		alu_2op)
	GC_OP(ADD,		alu_2op)
	GC_OP(SUB,		alu_2op)
	GC_OP(KOMPLEMENT,	not)
	GC_OP(MINUS,		neg)
	GC_OP(LSHIFT,		shift)
	GC_OP(RSHIFT,		shift)
	GC_OP(ALLOCREG, 	allocreg)
	GC_OP(FREEREG,		freereg)
	GC_OP(COMPARE,		cmp_test)
	GC_OP(TEST,		cmp_test)
	GC_OP(BEQ ... BRA,	branch)
	GC_OP(LABEL,		label)
	GC_OP(CALL,		call)
	GC_OP(PUSH,		push)
	GC_OP(GETRETURN,	getreturn)
	GC_OP(SETRETURN,	setreturn)
	GC_OP(MOVEFROMREG,	movefromreg)
	GC_OP(MOVETOREG,	movetoreg)
	GC_OP(ADDRESS,		address)
	GC_OP(ADDI2P,		alu_2op)
	GC_OP(SUBIFP,		alu_2op)
	GC_OP(SUBPFP,		alu_2op)

		/* Those are always handled with libcall */
	case MULT:
	case DIV:
	case MOD:
	default:
		break;//ierror(0);
	}

#undef GC_OP
}


/****************************************/
/*  End of private fata and functions.  */
/****************************************/

/*  Does necessary initializations for the code-generator. Gets called  */
/*  once at the beginning and should return 0 in case of problems.      */
int init_cg(void)
{
	int i, j;

	/* Macros */
	target_macros = marray;

	/* Alignement / size for types */
	stackalign = l2zm(1L);
	maxalign   = l2zm(1L);
	char_bit   = l2zm(16L);

	for (i=0; i<=MAX_TYPE; i++) {
		sizetab[i]=l2zm(msizetab[i]);
		align[i]=l2zm(malign[i]);
	}

	/* Registers */
	regnames[0] = "noreg";

		/* Defaults */
	memset(regscratch, 0x00, sizeof(regscratch));
	memset(regsa,      0x00, sizeof(regsa));
	memset(reg_prio,   0x00, sizeof(reg_prio));

		/* GPRs rX:  1-16 */
	for (i=0; i<16; i++)
	{
		j = R_R0 + i;
		regnames[j] = mymalloc(3);
		sprintf(regnames[j], "r%x", i);
		regsize[j] = l2zm(1L);
		regtype[j] = &ityp;
	}

		/* GPRs sX: 17-32 */
	for (i=0; i<16; i++)
	{
		j = R_S0 + i;
		regnames[j] = mymalloc(3);
		sprintf(regnames[j], "s%x", i);
		regsize[j] = l2zm(1L);
		regtype[j] = &ityp;
	}

		/* GPRs pair rXp: 33-40 */
	for (i=0; i<8; i++)
	{
		j = R_R0P + i;
		regnames[j] = mymalloc(3);
		sprintf(regnames[j], "r%xp", 2*i);
		regsize[j] = l2zm(2L);
		regtype[j] = &ltyp;
	}

		/* GPRs pair sXp: 41-48 */
	for (i=0; i<8; i++)
	{
		j = R_S0P + i;
		regnames[j] = mymalloc(3);
		sprintf(regnames[j], "s%xp", 2*i);
		regsize[j] = l2zm(2L);
		regtype[j] = &ltyp;
	}

		/* Use the first 8 registers as scratch
		 * registers */
	for (i=0; i<8; i++) {
		regscratch[R_R0 + i] = 1;
		regscratch[R_S0 + i] = 1;
	}

	for (i=0; i<4; i++) {
		regscratch[R_R0P + i] = 1;
		regscratch[R_S0P + i] = 1;
	}

		/* Code gen internally uses re/rf pair */
	regsa[R_RE] = regsa[R_RF] = regsa[R_REP] = 1;

		/* Priority */
	/* FIXME: TODO */

		/* SPRs: 49-51 */
	regnames[R_A] = "A";
	regsize[R_A]  = l2zm(1L);
	regtype[R_A]  = &ityp;
	regsa[R_A]    = 1;		/* Special, used by codegen */

	regnames[R_X] = "X";
	regsize[R_X]  = l2zm(1L);
	regtype[R_X]  = &ityp;
	regsa[R_X]    = 1;		/* Link Register */

	regnames[R_Y] = "Y";
	regsize[R_Y]  = l2zm(1L);
	regtype[R_Y]  = &ityp;
	regsa[R_Y]    = 1;		/* Used as Stack pointer */

	regnames[R_I] = "I";
	regsize[R_I]  = l2zm(1L);
	regtype[R_I]  = &ityp;
	regsa[R_I]    = 1;		/* Virtual Immediate register */

	/*  Initialize the min/max-settings. Note that the types of the     */
	/*  host system may be different from the target system and you may */
	/*  only use the smallest maximum values ANSI guarantees if you     */
	/*  want to be portable.                                            */
	/*  That's the reason for the subtraction in t_min[INT]. Long could */
	/*  be unable to represent -2147483648 on the host system.          */
	t_min[CHAR]=l2zm(-32768L);
	t_min[SHORT]=l2zm(-32768L);
	t_min[INT]=t_min[SHORT];
	t_min[LONG]=zmsub(l2zm(-2147483647L),l2zm(1L));
	t_min[LLONG]=zmlshift(l2zm(1L),l2zm(63L));
	t_min[MAXINT]=t_min(LLONG);
	t_max[CHAR]=ul2zum(32767UL);
	t_max[SHORT]=ul2zum(32767UL);
	t_max[INT]=t_max[SHORT];
	t_max[LONG]=ul2zum(2147483647UL);
	t_max[LLONG]=zumrshift(zumkompl(ul2zum(0UL)),ul2zum(1UL));
	t_max[MAXINT]=t_max(LLONG);
	tu_max[CHAR]=ul2zum(65535UL);
	tu_max[SHORT]=ul2zum(65535UL);
	tu_max[INT]=tu_max[SHORT];
	tu_max[LONG]=ul2zum(4294967295UL);
	tu_max[LLONG]=zumkompl(ul2zum(0UL));
	tu_max[MAXINT]=t_max(UNSIGNED|LLONG);

	/* Built-ins */
#define UINT	(UNSIGNED|INT)
#define ULONG	(UNSIGNED|LONG)
#define ULLONG	(UNSIGNED|LLONG)

		/* 16 bit ops: lsl/lsr + mul/div/mod done in libcall */
	declare_builtin("__lslint16",  INT,  INT,  R_R0, INT,  R_R1, 1, 0);
	declare_builtin("__lsrint16",  INT,  INT,  R_R0, INT,  R_R1, 1, 0);
	declare_builtin("__lsruint16", UINT, UINT, R_R0, INT,  R_R1, 1, 0);

	declare_builtin("__mulint16",  INT,  INT,  R_R0, INT,  R_R1, 1, 0);
	declare_builtin("__divint16",  INT,  INT,  R_R0, INT,  R_R1, 1, 0);
	declare_builtin("__divuint16", UINT, UINT, R_R0, UINT, R_R1, 1, 0);
	declare_builtin("__modint16",  INT,  INT,  R_R0, INT,  R_R1, 1, 0);
	declare_builtin("__moduint16", UINT, UINT, R_R0, UINT, R_R1, 1, 0);

		/* 32 bit ops: lsl/lsr + mul/div/mod done in libcall */
	declare_builtin("__lslint32",  LONG,  LONG,  R_R0P, INT,   R_R2,  1, 0);
	declare_builtin("__lsrint32",  LONG,  LONG,  R_R0P, INT,   R_R2,  1, 0);
	declare_builtin("__lsruint32", ULONG, ULONG, R_R0P, INT,   R_R2,  1, 0);

	declare_builtin("__mulint32",  LONG,  LONG,  R_R0P, LONG,  R_R2P, 1, 0);
	declare_builtin("__divint32",  LONG,  LONG,  R_R0P, LONG,  R_R2P, 1, 0);
	declare_builtin("__divuint32", ULONG, ULONG, R_R0P, ULONG, R_R2P, 1, 0);
	declare_builtin("__modint32",  LONG,  LONG,  R_R0P, LONG,  R_R2P, 1, 0);
	declare_builtin("__moduint32", ULONG, ULONG, R_R0P, ULONG, R_R2P, 1, 0);

		/* 64 bits ops: everything done in libcall */
	declare_builtin("__orint64",   LLONG,  LLONG, 0,  LLONG,  0, 1, 0);
	declare_builtin("__eorint64",  LLONG,  LLONG, 0,  LLONG,  0, 1, 0);
	declare_builtin("__andint64",  LLONG,  LLONG, 0,  LLONG,  0, 1, 0);

	declare_builtin("__lslint64",  LLONG,  LLONG,  0, INT,    0, 1, 0);
	declare_builtin("__lsrint64",  LLONG,  LLONG,  0, INT,    0, 1, 0);
	declare_builtin("__lsruint64", ULLONG, ULLONG, 0, INT,    0, 1, 0);

	declare_builtin("__addint64",  LLONG,  LLONG, 0,  LLONG,  0, 1, 0);
	declare_builtin("__subint64",  LLONG,  LLONG, 0,  LLONG,  0, 1, 0);

	declare_builtin("__mulint64",  LLONG,  LLONG,  0, LLONG,  0, 1, 0);
	declare_builtin("__divint64",  LLONG,  LLONG,  0, LLONG,  0, 1, 0);
	declare_builtin("__divuint64", ULLONG, ULLONG, 0, ULLONG, 0, 1, 0);
	declare_builtin("__modint64",  LLONG,  LLONG,  0, LLONG,  0, 1, 0);
	declare_builtin("__moduint64", ULLONG, ULLONG, 0, ULLONG, 0, 1, 0);

	declare_builtin("__negint64",  LLONG,  LLONG,  0, 0,      0, 1, 0);
	declare_builtin("__notint64",  LLONG,  LLONG,  0, 0,      0, 1, 0);

	declare_builtin("__cmpint64",  INT,    LLONG,  0, LLONG,  0, 1, 0);
	declare_builtin("__cmpuint64", INT,    ULLONG, 0, ULLONG, 0, 1, 0);

		/* 64 bits conversions */
	declare_builtin("__uint64touint16", ULLONG,  UINT, R_R0,  0, 0, 1, 0);
	declare_builtin("__uint64tosint16", ULLONG,   INT, R_R0,  0, 0, 1, 0);
	declare_builtin("__uint64touint32", ULLONG, ULONG, R_R0P, 0, 0, 1, 0);
	declare_builtin("__uint64tosint32", ULLONG,  LONG, R_R0P, 0, 0, 1, 0);

	declare_builtin("__sint64touint16",  LLONG,  UINT, R_R0,  0, 0, 1, 0);
	declare_builtin("__sint64tosint16",  LLONG,   INT, R_R0,  0, 0, 1, 0);
	declare_builtin("__sint64touint32",  LLONG, ULONG, R_R0P, 0, 0, 1, 0);
	declare_builtin("__sint64tosint32",  LLONG,  LONG, R_R0P, 0, 0, 1, 0);

	declare_builtin("__uint16touint64",  UINT, ULLONG, 0, 0, 0, 1, 0);
	declare_builtin("__sint16touint64",   INT, ULLONG, 0, 0, 0, 1, 0);
	declare_builtin("__uint32touint64", ULONG, ULLONG, 0, 0, 0, 1, 0);
	declare_builtin("__sint32touint64",  LONG, ULLONG, 0, 0, 0, 1, 0);

	declare_builtin("__uint16tosint64",  UINT,  LLONG, 0, 0, 0, 1, 0);
	declare_builtin("__sint16tosint64",   INT,  LLONG, 0, 0, 0, 1, 0);
	declare_builtin("__uint32tosint64", ULONG,  LLONG, 0, 0, 0, 1, 0);
	declare_builtin("__sint32tosint64",  LONG,  LLONG, 0, 0, 0, 1, 0);

		/* Float / Int conversions */
			/* int16 */
	declare_builtin("__sint16toflt32", FLOAT,  INT,  R_R0,  0, 0, 1, 0);
	declare_builtin("__uint16toflt32", FLOAT,  UINT, R_R0,  0, 0, 1, 0);
	declare_builtin("__sint16toflt64", DOUBLE, INT,  R_R0,  0, 0, 1, 0);
	declare_builtin("__uint16toflt64", DOUBLE, UINT, R_R0,  0, 0, 1, 0);

	declare_builtin("__flt32tosint16", INT,  FLOAT,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__flt32touint16", UINT, FLOAT,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__flt64tosint16", INT,  DOUBLE, 0,     0, 0, 1, 0);
	declare_builtin("__flt64touint16", UINT, DOUBLE, 0,     0, 0, 1, 0);

			/* int32 */
	declare_builtin("__sint32toflt32", FLOAT,  LONG,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__uint32toflt32", FLOAT,  ULONG, R_R0P, 0, 0, 1, 0);
	declare_builtin("__sint32toflt64", DOUBLE, LONG,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__uint32toflt64", DOUBLE, ULONG, R_R0P, 0, 0, 1, 0);

	declare_builtin("__flt32tosint32", LONG,  FLOAT,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__flt32touint32", ULONG, FLOAT,  R_R0P, 0, 0, 1, 0);
	declare_builtin("__flt64tosint32", LONG,  DOUBLE, 0,     0, 0, 1, 0);
	declare_builtin("__flt64touint32", ULONG, DOUBLE, 0,     0, 0, 1, 0);

			/* int64 */
	declare_builtin("__sint64toflt32", FLOAT,  LLONG,  0, 0, 0, 1, 0);
	declare_builtin("__uint64toflt32", FLOAT,  ULLONG, 0, 0, 0, 1, 0);
	declare_builtin("__sint64toflt64", DOUBLE, LLONG,  0, 0, 0, 1, 0);
	declare_builtin("__uint64toflt64", DOUBLE, ULLONG, 0, 0, 0, 1, 0);

	declare_builtin("__flt32tosint64", LLONG,  FLOAT,  0, 0, 0, 1, 0);
	declare_builtin("__flt32touint64", ULLONG, FLOAT,  0, 0, 0, 1, 0);
	declare_builtin("__flt64tosint64", LLONG,  DOUBLE, 0, 0, 0, 1, 0);
	declare_builtin("__flt64touint64", ULLONG, DOUBLE, 0, 0, 0, 1, 0);

		/* Inter-Float conversions */
	declare_builtin("__flt32toflt64", DOUBLE, FLOAT,  0, 0, 0, 1, 0);
	declare_builtin("__flt64toflt32", FLOAT,  DOUBLE, 0, 0, 0, 1, 0);

		/* Floating point math */
			/* float */
	declare_builtin("__addflt32", FLOAT, FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);
	declare_builtin("__subflt32", FLOAT, FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);
	declare_builtin("__mulflt32", FLOAT, FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);
	declare_builtin("__divflt32", FLOAT, FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);
	declare_builtin("__negflt32", FLOAT, FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);

	declare_builtin("__cmpflt32", INT,   FLOAT, R_R0P, FLOAT, R_R2P, 1, 0);

			/* double */
	declare_builtin("__addflt64", DOUBLE, DOUBLE, 0, DOUBLE, 0, 1, 0);
	declare_builtin("__subflt64", DOUBLE, DOUBLE, 0, DOUBLE, 0, 1, 0);
	declare_builtin("__mulflt64", DOUBLE, DOUBLE, 0, DOUBLE, 0, 1, 0);
	declare_builtin("__divflt64", DOUBLE, DOUBLE, 0, DOUBLE, 0, 1, 0);
	declare_builtin("__negflt64", DOUBLE, DOUBLE, 0, DOUBLE, 0, 1, 0);

	declare_builtin("__cmpflt64", INT,    DOUBLE, 0, DOUBLE, 0, 1, 0);

#undef UINT
#undef ULONG
#undef ULLONG

	return 1;
}

void cleanup_cg(FILE *f)
{
	/* Nothing to do */
}

/*  Returns the register in which variables of type t are returned. */
/*  If the value cannot be returned in a register returns 0.        */
int freturn(struct Typ *t)
{
	int f = t->flags & NQ;

	/* Any scalar that fits in 16 bits uses A as return register */
	if (ISSCALAR(f) && (msizetab[f] == 1))
		return R_A;

	/* Any scalar that fits in 32 bits used R0/R1 as return register */
	if (ISSCALAR(f) && (msizetab[f] == 2))
		return R_R0P;
}

/*  Returns 0 if register r cannot store variables of   */
/*  type t. If t==POINTER and mode!=0 then it returns   */
/*  non-zero only if the register can store a pointer   */
/*  and dereference a pointer to mode.                  */
int regok(int r, int t, int mode)
{
	if (r == 0)
		return 0;

	if (ISTSHORT(t)) {
		if (r >= R_R0 && r <= R_RF)
			return 1;
		if (r >= R_S0 && r <= R_SF)
			return 1;
		if (r == R_A || r == R_X || r == R_Y)
			return 1;
	}

	if (ISTLONG(t)) {
		if (r >= R_R0P && r <= R_REP)
			return 1;
		if (r >= R_S0P && r <= R_SEP)
			return 1;
	}

	return 0;
}

int dangerous_IC(struct IC *p)
{
	/* Only memory accesses are 'dangerous' */
	int c=p->code;
	if((p->q1.flags&DREFOBJ)||(p->q2.flags&DREFOBJ)||(p->z.flags&DREFOBJ))
		return 1;
	return 0;
}

/*  Returns zero if code for converting np to type t    */
/*  can be omitted.                                     */
int must_convert(int o,int t, int const_expr)
{
	int op=o&NQ,tp=t&NQ;

	if (op==tp) return 0;

	if (ISPOINTER(op) && ISPOINTER(tp))
		return 1; /* No conversion actually possible between pointer types ! */

	if (ISTSHORT(op) && ISTSHORT(tp))
		return 0; /* All 'short' types are compatible */

	return 1;
}

int shortcut(int code, int t)
{
	t &= NQ;
	if (t == CHAR || t == SHORT || t == INT)
		return 1;
	return 0;
}

void gen_code(FILE *f, struct IC *p, struct Var *v, zmax offset)
{
	struct gc_state gc;
	struct IC *node;

	gc_func_begin(&gc, f, p, v, offset);
	for (node=p; node; node=node->next)
		gc_func_ic(&gc, node);
	gc_func_end(&gc, f, p, v, offset);
}

void gen_ds(FILE *f, zmax size, struct Typ *t)
{
	long s = zm2l(size);
	emit(f, "\t.space %ld\n", s);
}

void gen_align(FILE *f, zmax align)
{
	long a = zm2l(align);

	if (a > 1)
		emit(f, "\t.align %ld\n", a);
}

void gen_var_head(FILE *f, struct Var *v)
{
	const char*section_names[] = { /* bit 2: pmem, bit 1: init, bit 0: const */
		"bss", NULL, "data", "rodata",
		"pmem_bss", NULL, "pmem_data", "pmem_rodata",
	};
	int section_type;
	struct Typ *tv;
	char *attr;

	tv = v->vtyp;
	while (tv->flags==ARRAY)
		tv = tv->next;
	attr = tv->attr;

	if (isstatic(v->storage_class) || isextern(v->storage_class))
	{
		/* Select section */
		section_type  = (attr && strstr(attr, STR_PMEM)) ? 4 : 0;
		section_type |= v->clist ? 2 : 0;
		section_type |= (v->clist && is_const(v->vtyp)) ? 1 : 0;

		emit(f, "\t.section %s\n", section_names[section_type]);

		/* Symbol name */
		if (isstatic(v->storage_class))
			emit(f, "%s%ld:\n", labprefix, zm2l(v->offset));
		else
			emit(f, "%s%s:\n", idprefix, v->identifier);

		/* FIXME: export global symbols */
	}
	else
	{
		ierror(0);
	}
}

void gen_dc(FILE *f, int t, struct const_list *p)
{
	const char *dct[] = { "", "byte", "short",  "short", "long", "long", "long", "long" };
	int tb;

	if (ISPOINTER(t))
		t = UNSIGNED|SHORT;
	tb = t & NQ;

	if (tb > LDOUBLE)
		ierror(0);

	emit(f, "\t.%s\t", dct[t&NQ]);

	if (!p->tree)
	{
		if (ISFLOAT(tb)) {
			unsigned char *ip;
			emit(f,"0x%02x%02x%02x%02x",ip[0],ip[1],ip[2],ip[3]);
			if(tb != FLOAT){
				emit(f,",0x%02x%02x%02x%02x",ip[4],ip[5],ip[6],ip[7]);
			}
		} else if (tb == LLONG) {
			/* Init */
			zumax tmp;
			eval_const(&p->val,t);
			tmp = vumax;

			/* Lower 32b */
			vumax = zumand(tmp,ul2zum(0xffffffff));
			gval.vulong = zum2zul(vumax);
			emitval(f, &gval, UNSIGNED|LONG);

			emit(f, ",");

			/* Upper 32b */
			vumax = zumand(zumrshift(vumax,ul2zum(32UL)),ul2zum(0xffffffff));
			gval.vulong = zum2zul(vumax);
			emitval(f, &gval, UNSIGNED|LONG);
		} else {
			emitval(f, &p->val, (t&NU)|UNSIGNED);
		}
	}
	else
	{
		if ((p->tree->o.flags & (VAR | VARADR)) == (VAR | VARADR)) {
			emit(f, "%s", sym_name(p->tree->o.v));
		} else {
			/* Not supported ... no idea what to do here */
			ierror(0);
		}
	}

	emit(f,"\n");
}

void init_db(FILE *f)
{
	/* not supported */
}

void cleanup_db(FILE *f)
{
	/* not supported */
}

/* Return name of library function, if this node should be
   implemented via libcall. */
char *use_libcall(int c,int t,int t2)
{
	static const char *names[] = { "na", "int16", "int16", "int16", "int32", "int64", "flt32", "flt64" };
	static const struct {
		int code;
		int use_sign;
		int types;
	} lib_ops[] = {
#define TB(x) (1 << (x))
		{ OR,      0, TB(LLONG) },
		{ XOR,     0, TB(LLONG) },
		{ AND,     0, TB(LLONG) },
		{ LSHIFT,  0, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) | TB(LONG) | TB(INT) | TB(SHORT) | TB(CHAR) },
		{ RSHIFT,  1, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) | TB(LONG) | TB(INT) | TB(SHORT) | TB(CHAR) },
		{ ADD,     0, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) },
		{ SUB,     0, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) },
		{ MULT,    0, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) | TB(LONG) | TB(INT) | TB(SHORT) | TB(CHAR) },
		{ DIV,     1, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) | TB(LONG) | TB(INT) | TB(SHORT) | TB(CHAR) },
		{ MOD,     1, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) | TB(LONG) | TB(INT) | TB(SHORT) | TB(CHAR) },
		{ COMPARE, 1, TB(DOUBLE) | TB(FLOAT) | TB(LLONG) },
		{ -1 }
	};
#undef TB
	static char fname[20];
	const char *n, *n2, *s, *s2;
	int i;

	/* We don't really support long doubles */
	if (t==LDOUBLE)  t=DOUBLE;
	if (t2==LDOUBLE) t2=DOUBLE;

	/* Safety */
	if (((t&NQ) < CHAR) || ((t&NQ) > DOUBLE))
		return NULL;
	if ((t2&NQ) > DOUBLE)
		return NULL;

	/* Get name string for t/t2 and sign char */
	n  = names[t  & NQ]; s  = ISFLOAT(t)  ? "" : ((t  & UNSIGNED) ? "u" : "s");
	n2 = names[t2 & NQ]; s2 = ISFLOAT(t2) ? "" : ((t2 & UNSIGNED) ? "u" : "s");

	/* Conversions */
	if (c == CONVERT)
	{
		/* Build name */
		snprintf(fname, sizeof(fname)-1, "__%s%sto%s%s", s, n, s2, n2);

		/* All conversion with float are library */
		if (ISFLOAT(t) || ISFLOAT(t2))
			return fname;

		/* No match */
		return NULL;
	}

	/* Scan for supported operations */
	for (i=0; lib_ops[i].code > 0; i++)
	{
		/* Match op */
		if (lib_ops[i].code != c)
			continue;

		/* Supported type ? */
		if ((lib_ops[i].types & (1 << (t&NQ))) == 0)
			return NULL;

		/* Build name */
		if (lib_ops[i].use_sign)
			snprintf(fname, sizeof(fname)-1, "__%s%s%s", ename[c], s, n);
		else
			snprintf(fname, sizeof(fname)-1, "__%s%s", ename[c], n);

		return fname;
	}

	return NULL;
}

/* Returns 0 if the register is no register pair. If r  */
/* is a register pair non-zero will be returned and the */
/* structure pointed to p will be filled with the two   */
/* elements.                                            */
int reg_pair(int r,struct rpair *p)
{
	if ((r >= R_R0P) && (r <= R_REP))
	{
		p->r1 = R_R0 + 2 * (r -  R_R0P);
		p->r2 = R_R1 + 2 * (r -  R_R0P);
		return 1;
	}

	if ((r >= R_S0P) && (r <= R_SEP))
	{
		p->r1 = R_S0 + 2 * (r -  R_S0P);
		p->r2 = R_S1 + 2 * (r -  R_S0P);
		return 1;
	}

	return 0;
}

int reg_parm(struct reg_handle *p, struct Typ *t,int vararg,struct Typ *d)
{
	int f = t->flags & NQ;

	/* Exclusions */
	if (!ISSCALAR(f)) return 0;
	if (p->gpr >= 4 || vararg) return 0;
	if (f==LLONG || f==DOUBLE || f==LDOUBLE) return 0;

	/* Pairs (possibly 'loosing' one reg if misaligned) */
	if (f==LONG || f==FLOAT) {
		p->gpr += (p->gpr & 1);	/* align */
		if (p->gpr >= 4)
			return 0;
		p->gpr += 2;
		return R_R0P + (p->gpr / 2) - 1;
	}

	/* Normal */
	return R_R0 + p->gpr++;
}

int pointer_type(struct Typ *p)
{
	while (ISARRAY(p->flags))
		p=p->next;
	if (ISFUNC(p->flags))
		return PPOINTER;
	if (p->attr && strstr(p->attr, STR_PMEM))
		return PPOINTER;
	return DPOINTER;
}

void conv_typ(struct Typ *p)
{
	char *attr;
	while(p) {
		if (ISPOINTER(p->flags)) {
			p->flags = ((p->flags&~NU)|POINTER_TYPE(p->next));
			if(attr=p->next->attr){
				if(strstr(attr,STR_PMEM))
					p->flags=((p->flags&~NU)|PPOINTER);
			}
		}
		p=p->next;
	}
}

/* Below is mostly copied from supp.c */
void printval(FILE *f,union atyps *p,int t)
{
	t&=NU;
	if(t==CHAR){fprintf(f,"C");vmax=zc2zm(p->vchar);printzm(f,vmax);}
	if(t==(UNSIGNED|CHAR)){fprintf(f,"UC");vumax=zuc2zum(p->vuchar);printzum(f,vumax);}
	if(t==SHORT){fprintf(f,"S");vmax=zs2zm(p->vshort);printzm(f,vmax);}
	if(t==(UNSIGNED|SHORT)){fprintf(f,"US");vumax=zus2zum(p->vushort);printzum(f,vumax);}
	if(t==FLOAT){fprintf(f,"F");vldouble=zf2zld(p->vfloat);printzld(f,vldouble);}
	if(t==DOUBLE){fprintf(f,"D");vldouble=zd2zld(p->vdouble);printzld(f,vldouble);}
	if(t==LDOUBLE){fprintf(f,"LD");printzld(f,p->vldouble);}
	if(t==INT){fprintf(f,"I");vmax=zi2zm(p->vint);printzm(f,vmax);}
	if(t==(UNSIGNED|INT)){fprintf(f,"UI");vumax=zui2zum(p->vuint);printzum(f,vumax);}
	if(t==LONG){fprintf(f,"L");vmax=zl2zm(p->vlong);printzm(f,vmax);}
	if(t==(UNSIGNED|LONG)){fprintf(f,"UL");vumax=zul2zum(p->vulong);printzum(f,vumax);}
	if(t==LLONG){fprintf(f,"LL");vmax=zll2zm(p->vllong);printzm(f,vmax);}
	if(t==(UNSIGNED|LLONG)){fprintf(f,"ULL");vumax=zull2zum(p->vullong);printzum(f,vumax);}
	if(t==MAXINT){fprintf(f,"M");printzm(f,p->vmax);}
	if(t==(UNSIGNED|MAXINT)){fprintf(f,"UM");printzum(f,p->vumax);}
	if(t==DPOINTER){fprintf(f,"Pd");vumax=zul2zum(p->vushort);printzum(f,vumax);}
	if(t==PPOINTER){fprintf(f,"Pp");vumax=zul2zum(p->vushort);printzum(f,vumax);}
}

void emitval(FILE *f,union atyps *p,int t)
{
	t&=NU;
	if(t==CHAR){vmax=zc2zm(p->vchar);emitzm(f,vmax);}
	if(t==(UNSIGNED|CHAR)){vumax=zuc2zum(p->vuchar);emitzum(f,vumax);}
	if(t==SHORT){vmax=zs2zm(p->vshort);emitzm(f,vmax);}
	if(t==(UNSIGNED|SHORT)){vumax=zus2zum(p->vushort);emitzum(f,vumax);}
	if(t==FLOAT){vldouble=zf2zld(p->vfloat);emitzld(f,vldouble);}
	if(t==DOUBLE){vldouble=zd2zld(p->vdouble);emitzld(f,vldouble);}
	if(t==LDOUBLE){emitzld(f,p->vldouble);}
	if(t==INT){vmax=zi2zm(p->vint);emitzm(f,vmax);}
	if(t==(UNSIGNED|INT)){vumax=zui2zum(p->vuint);emitzum(f,vumax);}
	if(t==LONG){vmax=zl2zm(p->vlong);emitzm(f,vmax);}
	if(t==(UNSIGNED|LONG)){vumax=zul2zum(p->vulong);emitzum(f,vumax);}
	if(t==LLONG){vmax=zll2zm(p->vllong);emitzm(f,vmax);}
	if(t==(UNSIGNED|LLONG)){vumax=zull2zum(p->vullong);emitzum(f,vumax);}
	if(t==MAXINT){emitzm(f,p->vmax);}
	if(t==(UNSIGNED|MAXINT)){emitzum(f,p->vumax);}
	if(t==DPOINTER){vumax=zus2zum(p->vushort);emitzum(f,vumax);}
	if(t==PPOINTER){vumax=zus2zum(p->vushort);emitzum(f,vumax);}
}

void insert_const(union atyps *p,int t)
{
	if(!p) ierror(0);
	t&=NU;
	if(t==CHAR) {p->vchar=vchar;return;}
	if(t==SHORT) {p->vshort=vshort;return;}
	if(t==INT) {p->vint=vint;return;}
	if(t==LONG) {p->vlong=vlong;return;}
	if(t==LLONG) {p->vllong=vllong;return;}
	if(t==MAXINT) {p->vmax=vmax;return;}
	if(t==(UNSIGNED|CHAR)) {p->vuchar=vuchar;return;}
	if(t==(UNSIGNED|SHORT)) {p->vushort=vushort;return;}
	if(t==(UNSIGNED|INT)) {p->vuint=vuint;return;}
	if(t==(UNSIGNED|LONG)) {p->vulong=vulong;return;}
	if(t==(UNSIGNED|LLONG)) {p->vullong=vullong;return;}
	if(t==(UNSIGNED|MAXINT)) {p->vumax=vumax;return;}
	if(t==FLOAT) {p->vfloat=vfloat;return;}
	if(t==DOUBLE) {p->vdouble=vdouble;return;}
	if(t==LDOUBLE) {p->vldouble=vldouble;return;}
	if(t==DPOINTER) {p->vushort=vushort;return;}
	if(t==PPOINTER) {p->vushort=vushort;return;}
}

void eval_const(union atyps *p,int t)
{
	int f=t&NQ;
	if(!p) ierror(0);
	if(f==MAXINT||(f>=CHAR&&f<=LLONG)){
		if(!(t&UNSIGNED)){
			if(f==CHAR) vmax=zc2zm(p->vchar);
			else if(f==SHORT)vmax=zs2zm(p->vshort);
			else if(f==INT)  vmax=zi2zm(p->vint);
			else if(f==LONG) vmax=zl2zm(p->vlong);
			else if(f==LLONG) vmax=zll2zm(p->vllong);
			else if(f==MAXINT) vmax=p->vmax;
			else ierror(0);
			vumax=zm2zum(vmax);
			vldouble=zm2zld(vmax);
		}else{
			if(f==CHAR) vumax=zuc2zum(p->vuchar);
			else if(f==SHORT)vumax=zus2zum(p->vushort);
			else if(f==INT)  vumax=zui2zum(p->vuint);
			else if(f==LONG) vumax=zul2zum(p->vulong);
			else if(f==LLONG) vumax=zull2zum(p->vullong);
			else if(f==MAXINT) vumax=p->vumax;
			else ierror(0);
			vmax=zum2zm(vumax);
			vldouble=zum2zld(vumax);
		}
	}else{
		if(ISPOINTER(f)){
			vumax=zus2zum(p->vushort);
			vmax=zum2zm(vumax);vldouble=zum2zld(vumax);
		}else{
			if(f==FLOAT) vldouble=zf2zld(p->vfloat);
			else if(f==DOUBLE) vldouble=zd2zld(p->vdouble);
			else vldouble=p->vldouble;
			vmax=zld2zm(vldouble);
			vumax=zld2zum(vldouble);
		}
	}
	vfloat=zld2zf(vldouble);
	vdouble=zld2zd(vldouble);
	vuchar=zum2zuc(vumax);
	vushort=zum2zus(vumax);
	vuint=zum2zui(vumax);
	vulong=zum2zul(vumax);
	vullong=zum2zull(vumax);
	vchar=zm2zc(vmax);
	vshort=zm2zs(vmax);
	vint=zm2zi(vmax);
	vlong=zm2zl(vmax);
	vllong=zm2zll(vmax);
}
