#include "dt.h"

//bez speciálních adresních modu
struct AddressingMode {
    int never_used;
};

struct reg_handle {
  int gpr;
};

// sem nacpat počet registrů, ale co SP, PC a Zero reg? To jsou spec. registry
// které kompilátor nemůže jen tak používat
#define MAXR 16

// počet argumentů, nemám žádné ale doku tvrdí že t i tak musí být MAXGF 1
#define MAXGF 1

//může být druhý operand IC stejný jako cíl? 0-ano 1-ne
#define USEQ2ASZ 0

//A co mám jako kurva dát sem?! Zkusím CHAR když to nebude fungovat dej tam INT!
#define MINADDI2P CHAR

// další wtf! Moje arch tohle neřeší, tak tam prostě prskneme malého indiána
#define BIGENDIAN 0
#define LITTLEENDIAN 1

//switche chci compilovat na COMPARE/BEQ nikoliv na SUB/TEST/BEQ
#define SWITCHSUBS 0

// obšlehnuto z generic, tady toho je vůbec hodně obšlehnutého
#define INLINEMEMCPY 1024

// reverse argument push order
//#define ORDERED_PUSH 0

// argumenty klidně do registrů
#define HAVE_REGPARMS 1

//nemám registrové páry
#undef HAVE_REGPAIRS

//nó, ale zvhledem k tomu že long a int je na mej arch stejný tak je to asi k prdu ale budiž
#undef HAVE_INT_SIZET

// a teď ty sračky pro peephole optimalizace, ty dělat nebudu tak jsem tohle obšlehl z generic

/* size of buffer for asm-output, this can be used to do
   peephole-optimizations of the generated assembly-output */
#define EMIT_BUF_LEN 1024 /* should be enough */
/* number of asm-output lines buffered */
#define EMIT_BUF_DEPTH 4
/*  We have no asm_peephole to optimize assembly-output */
#define HAVE_TARGET_PEEPHOLE 0


// tohle je zatím k hovnu později se to ale může hodit
#define HAVE_TARGET_ATTRIBUTES
#define HAVE_TARGET_PRAGMAS

#undef HAVE_REGS_MODIFIED //nepodporuji interprocedural register allocation

//tohle je dobrý pro CPU s registrama co mají pevně danou funkci, moje arch je ortogonální až běda tak to nemusím řešit
#undef HAVE_TARGET_RALLOC

// pro mě zbytečné, je to pro aptimalizaci
#undef HAVE_EXT_IC

//tohle je sranda, doku se tu odkazuje na kapitolu která není napsaná, nicméně, externí typy nepotřebujeme
#undef HAVE_EXT_TYPES

#undef HAVE_TGT_PRINTVAL //tohle je stejná  sračka jako ta vejš, kdo ví k čemu to je ale nechci to

// no, nemám páru jak to nastavit tak je to obšlehnuté
#define JUMP_TABLE_DENSITY 0.8
#define JUMP_TABLE_LENGTH 12

/* toto je pro variable lenght arrays (nutno použít -c99) zatím to jebu, spousta architektur to taky nemá
#define ALLOCVLA_REG <reg>
#define ALLOCVLA_INLINEASM <inline asm>
#define FREEVLA_REG <reg>
#define FREEVLA_INLINEASM <inline asm>
#define OLDSPVLA_INLINEASM <inline asm>
#define FPVLA_REG <reg>
*/

//tohle je pro nahrazení složitějších operací voláím do knihoven - super věc ale zatím to jebu a budu generovat makra
#undef HAVE_LIBCALLS

// who cares?
#define AVOID_FLOAT_TO_UNSIGNED 1
#define AVOID_UNSIGNED_TO_FLOAT 1
