#include "supp.h"
//#define DEBUG_MARK

static char FILE_[]=__FILE__;

//#include "version.h"
char cg_copyright[]="not for public release";

int g_flags[MAXGF]={};
char *g_flags_name[MAXGF]={};
union ppi g_flags_val[MAXGF];

struct reg_handle empty_reg_handle={0};

extern int handle_pragma(const char * c){return 0;}

//support for ISR
char *g_attr_name[] = {"__interrupt", 0};
#define INTERRUPT 1

/*
 * Define registers codes
 */

#define R0 1  //zero register
#define R1 2  //reserved for compiler
#define R2 3  //reserved for compiler
#define R3 4  //reserved for compiler
#define R4 5  //condition codes
#define R5 6  //return value
#define R6 7
#define R7 8
#define R8 9
#define R9 10
#define R10 11
#define R11 12
#define R12 13
#define FP 14 //frame pointer
#define PC 15 //program counter
#define SP 16 //stack pointer

/*
 * Custom function
 */

//evalue compare IC and prepare condition codes in R3 (COMPARE IC is followed by BRANCH allways)
void compare(FILE *f, struct IC *p);
//helper function for loading obj o into register dest_reg
void load_into_reg(FILE *f, int dest_reg, struct obj *o, int type, int tmp_reg);
//store reg into obj o
void store_from_reg(FILE *f, int source_reg, struct obj *o, int type, int tmp_reg, int tmp_reg_b);
//take care about all arithmetic IC
void arithmetic(FILE *f, struct IC *p);
//load constant into register
void load_cons(FILE *f, int reg, long int value);

/*
 * Data Types
 */
zmax char_bit; // CHAR_BIT for the target machine.
zmax align[MAX_TYPE+1]; //  Alignment-requirements for all types in bytes.
zmax maxalign; //  Alignment that is sufficient for every object.
zmax sizetab[MAX_TYPE+1]; //  sizes of the basic types (in bytes)

//  Minimum and Maximum values each type can have.
zmax t_min[MAX_TYPE+1];
zumax t_max[MAX_TYPE+1];
zumax tu_max[MAX_TYPE+1];


/*
 * Register  Set
 */

/*
 * Names of all registers. will be initialized in init_cg(),
 * register number 0 is invalid, valid registers start at 1
 */
char *regnames[MAXR+1];

/*
 *  The Size of each register in bytes.
 */
zmax regsize[MAXR+1];

/*
 *   Specifies which registers may be scratched by functions.
 */
int regscratch[MAXR+1];

/*
 *   a type which can store each register.
 */
struct Typ *regtype[MAXR+1];

/*  regsa[reg]!=0 if a certain register is allocated and should
 *  not be used by the compiler pass.
 */
int regsa[MAXR+1];

/*
 * specifies the priority for the register-allocator, if the same
 * estimated cost-saving can be obtained by several registers, the
 * one with the highest priority will be used
 */
int reg_prio[MAXR+1];


/*
 * Does necessary initializations for the code-generator. Gets called
 * once at the beginning and should return 0 in case of problems.
 */
int init_cg(void){

    #ifdef DEBUG_MARK
    printf("Called init_cg()\n");
    #endif

    int i;

    maxalign=l2zm(1L);
    char_bit=l2zm(32L);

    for(i=0;i<=MAX_TYPE;i++){
        align[i] = l2zm(1L);
        sizetab[i] = l2zm(1L);
    }

    t_min[CHAR] = zmsub(l2zm(-2147483647L),l2zm(1L));
    t_min[SHORT] = t_min[CHAR];
    t_min[INT] = t_min[CHAR];
    t_min[LONG] = t_min[CHAR];
    t_min[LLONG] = t_min[CHAR];
    t_min[MAXINT] = t_min[CHAR];

    t_max[CHAR] = ul2zum(2147483647UL);
    t_max[SHORT] = t_max[CHAR];
    t_max[INT] = t_max[CHAR];
    t_max[LONG] = t_max[CHAR];
    t_max[LLONG] = t_max[CHAR];
    t_max[MAXINT] = t_max[CHAR];

    tu_max[CHAR]=ul2zum(4294967295UL);
    tu_max[SHORT] = tu_max[CHAR];
    tu_max[INT] = tu_max[CHAR];
    tu_max[LONG] = tu_max[CHAR];
    tu_max[LLONG] = tu_max[CHAR];
    tu_max[MAXINT] = tu_max[CHAR];


    regnames[0] = "noreg";
    reg_prio[0] = 0;
    regscratch[0] = 0;
    regsa[0] = 0;

    //zero register
    regnames[1] = "R0";
    reg_prio[1] = 0;
    regscratch[1] = 0;
    regsa[1] = 1;

    //R1 reserved for backed
    regnames[2] = "R1";
    reg_prio[2] = 0;
    regscratch[2] = 0;
    regsa[2] = 1;

    //R2 reserved for backed
    regnames[3] = "R2";
    reg_prio[3] = 0;
    regscratch[3] = 0;
    regsa[3] = 1;

    //R3 reserved for backed
    regnames[4] = "R3";
    reg_prio[4] = 0;
    regscratch[4] = 0;
    regsa[4] = 1;

    //R4 condition codes
    regnames[5] = "R4";
    reg_prio[5] = 0;
    regscratch[5] = 0;
    regsa[5] = 1;

    //R5 return value for function
    regnames[6] = "R5";
    reg_prio[6] = 0;
    regscratch[6] = 0;
    regsa[6] = 1;

    regnames[7] = "R6";
    reg_prio[7] = 0;
    regscratch[7] = 0;
    regsa[7] = 0;

    regnames[8] = "R7";
    reg_prio[8] = 0;
    regscratch[8] = 0;
    regsa[8] = 0;

    regnames[9] = "R8";
    reg_prio[9] = 0;
    regscratch[9] = 0;
    regsa[9] = 0;

    regnames[10] = "R9";
    reg_prio[10] = 0;
    regscratch[10] = 0;
    regsa[10] = 0;

    regnames[11] = "R10";
    reg_prio[11] = 0;
    regscratch[11] = 0;
    regsa[11] = 0;

    regnames[12] = "R11";
    reg_prio[12] = 0;
    regscratch[12] = 0;
    regsa[12] = 0;

    regnames[13] = "R12";
    reg_prio[13] = 0;
    regscratch[13] = 0;
    regsa[13] = 0;

    // Frame pointer
    regnames[FP] = "R13";
    reg_prio[14] = 0;
    regscratch[14] = 0;
    regsa[14] = 1;

    // Program counter
    regnames[15] = "PC";
    reg_prio[15] = 0;
    regscratch[15] = 0;
    regsa[15] = 1;

    // Stack pointer
    regnames[16] = "SP";
    reg_prio[16] = 0;
    regscratch[16] = 0;
    regsa[16] = 1;


    for(i=0;i<=MAXR;i++){
        regsize[i] = l2zm(1L);
    }

    // Use multiple ccs
    multiple_ccs = 0;

    return 1;
}

void cleanup_cg(FILE *f){
    #ifdef DEBUG_MARK
    printf("Called cleanup_cg()\n");
    #endif
}

/*
 * Returns the register in which variables of type t are returned.
 * If the value cannot be returned in a register returns 0.
 */
int freturn(struct Typ *t){
    return R5;
}

/*
 * Returns 0 if register r cannot store variables of
 * type t. If t==POINTER and mode!=0 then it returns
 * non-zero only if the register can store a pointer
 * and dereference a pointer to mode.
 */
int regok(int r,int t,int mode){
    return 1;
}

/*
 *  Returns zero if the IC p can be safely executed
 *  without danger of exceptions or similar things.
 *  vbcc may generate code in which non-dangerous ICs
 *  are sometimes executed although control-flow may
 *  never reach them (mainly when moving computations
 *  out of loops).
 *  Typical ICs that generate exceptions on some
 *  machines are:
 *      - accesses via pointers
 *      - division/modulo
 *      - overflow on signed integer/floats
 */
int dangerous_IC(struct IC *p){
    return 0;
}

/*
 *  Returns zero if code for converting np to type t
 *  can be omitted.
 *  On the PowerPC cpu pointers and 32bit
 *  integers have the same representation and can use
 *  the same registers.
 */
int must_convert(int o,int t,int const_expr){
    return 0;
}

int shortcut(int code,int typ){
    return 0;
}

/*
 *  The main code-generation routine.
 *  f is the stream the code should be written to.
 *  p is a pointer to a doubly linked list of ICs
 *  containing the function body to generate code for.
 *  v is a pointer to the function.
 *  offset is the size of the stackframe the function
 *  needs for local variables.
 */
void gen_code(FILE *f,struct IC *p,struct Var *v,zmax offset){
    #ifdef DEBUG_MARK
    printf("Called gen_code(FILE *f,struct IC *p,struct Var *v,zmax offset)\n");
    printf("\tIdentifier: %s", v->identifier);
    #endif

    //emit function head
    if(v->storage_class==EXTERN){
        if( (v->flags & (INLINEFUNC|INLINEEXT)) != INLINEFUNC ){
            emit(f,".EXPORT \t %s \n",v->identifier);
        }
        emit(f,"%s: \n",v->identifier);
    }
    else{
        emit(f,"L_%ld:\n",zm2l(v->offset));
    }

    //emit function prologue
    emit(f, "\tPUSH \t %s\n", regnames[FP]);  //push FP
    emit(f, "\tOR   \t %s %s %s\n",regnames[R0], regnames[SP], regnames[FP]); //MOVE SP -> FP

    //make space for auto variables at stack
    for(int i = 0; i < zm2l(offset); i++){
        emit(f, "\tDEC \t %s %s\n", regnames[SP], regnames[SP]);
    }

    //store backend registers
    emit(f, "\tPUSH \t R1\n\tPUSH \t R2\n\tPUSH \t R3\n\tPUSH \t R4\n");

    //find used registers
    int saved_regs[7] = {0, 0, 0, 0, 0, 0, 0};

    struct IC *ps = p;
    for(;ps;ps=ps->next){
        if( ((ps->code) != FREEREG) && ((ps->code) != ALLOCREG) ){
            if(((ps->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
                if(((ps->q1.reg) > R5) && ((ps->q1.reg) < FP)){
                    saved_regs[(ps->q1.reg) - 7] = 1;
                }
            }
            if(((ps->q2.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
                if(((ps->q2.reg) > R5) && ((ps->q2.reg) < FP)){
                    saved_regs[(ps->q2.reg) - 7] = 1;
                }
            }
            if(((ps->z.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
                if(((ps->z.reg) > R5) && ((ps->z.reg) < FP)){
                    saved_regs[(ps->z.reg) - 7] = 1;
                }
            }
        }
    }

    //save used registers
    for(int i = 0; i < 7; i++){
        if(saved_regs[i] == 1){
            emit(f, "\tPUSH \t %s\n", regnames[i + 7]);
        }
    }

    //emit function body
    for(;p;p=p->next){
        int c = p->code;

        #ifdef DEBUG_MARK
        emit(f, "\n\t;p->code: %d\n", p->code);
        #endif

        switch(p->code){
            case ASSIGN:
                #ifdef DEBUG_MARK
                printf("\n\tASSIGN\n\tz.flags:%d\tq1.flags:%d\ttypf:%d\n", p->z.flags, p->q1.flags, p->typf);
                #endif

                //we can simplify assign when both operands are in registers
                if((((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG) &&
                   (((p->z.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG) ){
                    emit(f, "\tOR   \t %s %s %s",regnames[R0], regnames[p->q1.reg], regnames[p->z.reg]);
                }

                //this is another optimalization, if have to assign zero; then
                //zero is read from R0 insted pushing constant into register
                else if(
                (((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == KONST) &&
                ((p->q1.val.vmax) == 0)
                ){
                    store_from_reg(f, R0, &(p->z), p->typf, R2, R3);
                }

                else{
                    load_into_reg(f, R1, &(p->q1), p->typf, R2);
                    store_from_reg(f, R1, &(p->z), p->typf, R2, R3);
                }

                break;
            case OR:
                #ifdef DEBUG_MARK
                printf("\n\tOR\n");
                #endif
                arithmetic(f, p);
                break;
            case XOR:
                #ifdef DEBUG_MARK
                printf("\n\tXOR\n");
                #endif
                arithmetic(f, p);
                break;
            case AND:
                #ifdef DEBUG_MARK
                printf("\n\tAND\n");
                #endif
                arithmetic(f, p);
                break;
            case LSHIFT:
                #ifdef DEBUG_MARK
                printf("\n\tLSHIFT\n");
                #endif
                arithmetic(f, p);
                break;
            case RSHIFT:
                #ifdef DEBUG_MARK
                printf("\n\tRSHIFT\n");
                #endif
                arithmetic(f, p);
                break;
            case ADD:
                #ifdef DEBUG_MARK
                printf("\n\tADD\n");
                #endif
                arithmetic(f, p);
                break;
            case SUB:
                #ifdef DEBUG_MARK
                printf("\n\tSUB\n");
                #endif
                arithmetic(f, p);
                break;
            case MULT:
                #ifdef DEBUG_MARK
                printf("\n\tMULT\n");
                #endif
                arithmetic(f, p);
                break;
            case DIV:
                #ifdef DEBUG_MARK
                printf("\n\tDIV\n");
                #endif
                arithmetic(f, p);
                break;
            case MOD:
                #ifdef DEBUG_MARK
                printf("\n\tMOD\n");
                #endif
                arithmetic(f, p);
                break;
            case KOMPLEMENT:
                #ifdef DEBUG_MARK
                printf("\n\tKOMPLEMENT\n");
                #endif
                arithmetic(f, p);
                break;
            case MINUS:
                #ifdef DEBUG_MARK
                printf("\n\tMINUS\n");
                #endif
                arithmetic(f, p);
                break;
            case ADDRESS:
                #ifdef DEBUG_MARK
                printf("\n\tADDRESS\n");
                #endif

                if(
                (((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == VAR) &&
                (((p->q1.v->storage_class) & (AUTO|REGISTER|STATIC|EXTERN)) == AUTO)
                ){
                    if(ISARRAY(p->q1.v->flags)){
                        load_cons(f, R1, zm2l(p->q1.v->offset)+zm2l(p->q1.val.vmax));
                    }
                    else{
                        load_cons(f, R1, zm2l(p->q1.v->offset));
                    }
                    emit(f, "\tADD \t R1 R13 R1\n");
                    store_from_reg(f, R1, &(p->z), p->typf, R2, R3);
                }
                else{
                    ierror(0);
                }

                break;
            case CALL:
                #ifdef DEBUG_MARK
                printf("\n\tCALL\n\tq1.flags: %d\n", p->q1.flags);
                #endif

                if((p->q1.flags & (VAR|DREFOBJ)) == VAR && p->q1.v->fi && p->q1.v->fi->inline_asm){
                    emit_inline_asm(f,p->q1.v->fi->inline_asm);
                }
                else{

                    if(((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == VAR){

                        #ifdef DEBUG_MARK
                        printf("\tq1.v->storage_class: %d\n", p->q1.v->storage_class);
                        #endif

                        switch((p->q1.v->storage_class) & (AUTO|REGISTER|STATIC|EXTERN)){
                            case EXTERN:
                                emit(f, "\tCALL \t %s\n", p->q1.v->identifier);
                                for(int i = 0; i < (p->q2.val.vmax); i++){
                                    emit(f, "\tINC \t %s %s\n", regnames[SP], regnames[SP]);
                                }
                                break;
                            case STATIC:
                                emit(f, "\tCALL \t L_%ld\n", zm2l(p->q1.v->offset));
                                for(int i = 0; i < (p->q2.val.vmax); i++){
                                    emit(f, "\tINC \t %s %s\n", regnames[SP], regnames[SP]);
                                }
                                break;
                            default:
                                #ifdef DEBUG_MARK
                                printf("\tThis is not implemented!\n");
                                #else
                                ierror(0);
                                #endif
                                break;
                        }

                    }
                    else if(((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == (VAR|DREFOBJ)){
                        #ifdef DEBUG_MARK
                        printf("\tq1.v->storage_class: %d\n", p->q1.v->storage_class);
                        #endif                        
                        load_into_reg(f, R1, &(p->q1), p->typf, R3);
                        emit(f, "\tCALLI\t %s\n", regnames[R1]);                        
                        emit(f, "\tINC \t %s %s\n", regnames[SP], regnames[SP]);                        
                    }
                    else{
                        #ifdef DEBUG_MARK
                        printf("\tThis is not implemented!\n");
                        #else
                        ierror(0);
                        #endif
                    }
                }
                break;
            case CONVERT:
                #ifdef DEBUG_MARK
                printf("\n\tCONVERT\n");
                #endif

                break;
            case ALLOCREG:
                #ifdef DEBUG_MARK
                printf("\n\tALLOCREG\n");
                #endif

                regs[p->q1.reg] = 1;
                break;
            case FREEREG:
                #ifdef DEBUG_MARK
                printf("\n\tFREEREG\n");
                #endif

                regs[p->q1.reg] = 0;
                break;
            case COMPARE:
                #ifdef DEBUG_MARK
                printf("\n\tCOMPARE\n");
                #endif

                compare(f, p);
                break;
            case TEST:
                #ifdef DEBUG_MARK
                printf("\n\tTEST\n");
                #endif

                compare(f, p);
                break;
            case LABEL:
                #ifdef DEBUG_MARK
                printf("\n\tLABEL\n");
                #endif

                emit(f,"L_%d:\n",p->typf);
                break;
            case BEQ:
                #ifdef DEBUG_MARK
                printf("\n\tBEQ\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BNE:
                #ifdef DEBUG_MARK
                printf("\n\tBNE\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BLT:
                #ifdef DEBUG_MARK
                printf("\n\tBLT\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BGE:
                #ifdef DEBUG_MARK
                printf("\n\tBGE\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BLE:
                #ifdef DEBUG_MARK
                printf("\n\tBLE\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BGT:
                #ifdef DEBUG_MARK
                printf("\n\tBGT\n");
                #endif

                emit(f, "\tBNZ \t R4 L_%d\n", p->typf);
                break;
            case BRA:
                #ifdef DEBUG_MARK
                printf("\n\tBRA\n");
                #endif

                emit(f, "\tBZ   \t R0 L_%d\n", p->typf);
                break;
            case PUSH:
                #ifdef DEBUG_MARK
                printf("\n\tPUSH\n");
                #endif

                load_into_reg(f, R1, &(p->q1), p->typf, R2);
                emit(f, "\tPUSH \t R1\n");
                break;
            case ADDI2P:
                #ifdef DEBUG_MARK
                printf("\n\tADDI2P\n");
                #endif
                arithmetic(f, p);
                break;
            case SUBIFP:
                #ifdef DEBUG_MARK
                printf("\n\tSUBIFP\n");
                #endif
                arithmetic(f, p);
                break;
            case SUBPFP:
                #ifdef DEBUG_MARK
                printf("\n\tSUBPFP\n");
                #endif
                arithmetic(f, p);
                break;
            case GETRETURN:
                #ifdef DEBUG_MARK
                printf("\n\tGETRETURN\n");
                #endif
                if((p->q1.reg) != 0){
                    store_from_reg(f, p->q1.reg, &(p->z), p->typf, R2, R3);
                }
                else{
                    #ifdef DEBUG_MARK
                    printf("\tq1.reg == 0, didn't know how to dealt with it!");
                    #else
                    ierror(0);
                    #endif
                }
                break;
            case SETRETURN:
                #ifdef DEBUG_MARK
                printf("\n\tSETRETURN\n\tz.flags:%d\n", p->z.flags);
                #endif
                if((p->z.reg) != 0){
                    load_into_reg(f, p->z.reg, &(p->q1), p->typf, R1);
                }
                else{
                    #ifdef DEBUG_MARK
                    printf("\tz.reg == 0, didn't know how to dealt with it!");
                    #else
                    ierror(0);
                    #endif
                }
                break;
            case MOVEFROMREG:
                #ifdef DEBUG_MARK
                printf("\n\tMOVEFROMREG\n");
                #endif

                store_from_reg(f, p->q1.reg, &(p->z), p->typf, R1, R3);
                break;
            case MOVETOREG:
                #ifdef DEBUG_MARK
                printf("\n\tMOVETOREG\n");
                #endif

                load_into_reg(f, p->z.reg, &(p->q1), p->typf, R1);
                break;
            case NOP:
                #ifdef DEBUG_MARK
                printf("\n\tNOP\n");
                #endif
                break;
            default:
                #ifdef DEBUG_MARK
                printf("\tSomething is wrong in gencode()!\n");
                #else
                ierror(0);
                #endif
                break;
        }
    }

    //restore used registers
    for(int i = 6; i >= 0; i--){
        if(saved_regs[i] == 1){
            emit(f, "\tPOP \t %s\n", regnames[i + 7]);
        }
    }

    //restore backend registers
    emit(f, "\tPOP \t R4\n\tPOP \t R3\n\tPOP \t R2\n\tPOP \t R1\n");

    //emit function epilogue
    emit(f, "\tOR  \t %s %s %s\n",regnames[R0], regnames[FP], regnames[SP]); //restore SP from FP
    emit(f, "\tPOP \t %s\n", regnames[FP]); //restore old FP from stack

    //return
    if((v->tattr)&INTERRUPT){
        emit(f, "\tRETI\n");
    }
    else{
        emit(f, "\tRET\n");
    }
}

/*
 *  This function has to create <size> bytes of storage
 *  initialized with zero.
 */
void gen_ds(FILE *f,zmax size,struct Typ *t){
    #ifdef DEBUG_MARK
    printf("Called gen_ds(FILE *f,zmax size,struct Typ *t)\n");
    #endif
    emit(f, "\t.DS \t%ld\n", zm2l(size));
}

/*
 *  This function has to make sure the next data is
 *  aligned to multiples of <align> bytes.
 */
void gen_align(FILE *f,zmax align){}

/*
 *  This function has to create the head of a variable
 *  definition, i.e. the label and information for
 *  linkage etc.
 */
void gen_var_head(FILE *f,struct Var *v){
    #ifdef DEBUG_MARK
    printf("Called gen_var_head(FILE *f,struct Var *v)\n");
    #endif

    switch((v->storage_class) & (STATIC|EXTERN|AUTO|REGISTER)){
        case STATIC:
            #ifdef DEBUG_MARK
            printf("\tHave to emit static variable head.\n");
            #endif
            emit(f,"L_%ld:\n", zm2l(v->offset));
            break;
        case EXTERN:
            #ifdef DEBUG_MARK
            printf("\tHave to emit extern variable head.\n");
            #endif

            if(v->flags&(DEFINED|TENTATIVE)){
                emit(f,".EXPORT \t %s\n", v->identifier);
                emit(f,"%s:\n", v->identifier);
            }
            else{
                emit(f,".IMPORT \t %s\n", v->identifier);
            }
            break;
        default:
            #ifdef DEBUG_MARK
            printf("\tCant generate head, unknown storage class: %d\n", v->storage_class);
            #else
            ierror(0);
            #endif
            break;
    }
}

/*
 *  This function has to create static storage
 *  initialized with const-list p.
 */
void gen_dc(FILE *f,int t,struct const_list *p){
    #ifdef DEBUG_MARK
    printf("Called gen_dc(FILE *f,int t,struct const_list *p)\n");
    #endif

    if(!p->tree){
        if(ISFLOAT(t)){
            emit(f,"\t.DAT \t ");
            emit(f,"0x%x", *(unsigned int*)&p->val);
            emit(f,"\n");
        }
        else{
            emit(f,"\t.DAT \t ");
            emitval(f,&p->val,t&NU);
            emit(f,"\n");
        }
    }
    else{
        emit(f,"\t.DAT \t ");
        struct const_list *p_next = p;
        for(;p_next;p_next=p_next->next){
            emitval(f,&p_next->val,t&NU);
            emit(f, " ");
        }
        emit(f, "\n");
    }
}

//this is for debug, not needed now
void init_db(FILE *f){}
void cleanup_db(FILE *f){}

int reg_parm(struct reg_handle *m, struct Typ *t,int vararg,struct Typ *d){
    //this will put all arguments into stack
    return 0;
}

/*
 * Returns 0 if the register is no register pair. If r
 * is a register pair non-zero will be returned and the
 * structure pointed to p will be filled with the two
 * elements.
 */
int reg_pair(int r,struct rpair *p){
    return 0;
}

void compare(FILE *f, struct IC *p){

    int q1reg = 0;
    int q2reg = 0;

    //load operands into R1 and R2
    if(((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) != REG){
        load_into_reg(f, R1, &(p->q1), p->typf, R3);
        q1reg = R1;
    }
    else{
        q1reg = p->q1.reg;
    }

    if((p->code) != TEST){
        if(((p->q2.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) != REG){
            load_into_reg(f, R2, &(p->q2), p->typf, R3);
            q2reg = R2;
        }
        else{
            q2reg = p->q2.reg;
        }
    }
    else{
        q2reg = R2;
        emit(f, "\tOR  \t %s %s %s\n",regnames[R0], regnames[R0], regnames[R2]);
    }

    //find branch IC
    struct IC *branch_ic;
    branch_ic = p->next;
    while(branch_ic && ((branch_ic->code) == FREEREG) ) {
        branch_ic = branch_ic->next;
    }

    //emit compare code
    if (((p->typf) & FLOAT) == FLOAT || ((p->typf) & DOUBLE) == DOUBLE || ((p->typf) & LDOUBLE) == LDOUBLE){
        switch(branch_ic->code){
            case BEQ:
                emit(f, "\tCMPF \t EQ %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BNE:
                emit(f, "\tCMPF \t NEQ %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BLT:
                emit(f, "\tCMPF \t L %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BGE:
                emit(f, "\tCMPF \t GE %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BLE:
                emit(f, "\tCMPF \t LE %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BGT:
                emit(f, "\tCMPF \t G %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            default:
                ierror(0);
                break;
        }
    }
    else{
        switch(branch_ic->code){
            case BEQ:
                emit(f, "\tCMPI \t EQ %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BNE:
                emit(f, "\tCMPI \t NEQ %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                break;
            case BLT:
                if((p->typf & UNSIGNED) == UNSIGNED){
                    emit(f, "\tCMPI \t LU %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                else{
                    emit(f, "\tCMPI \t L %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                break;
            case BGE:
                if((p->typf & UNSIGNED) == UNSIGNED){
                    emit(f, "\tCMPI \t GEU %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                else{
                    emit(f, "\tCMPI \t GE %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                break;
            case BLE:
                if((p->typf & UNSIGNED) == UNSIGNED){
                    emit(f, "\tCMPI \t LEU %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                else{
                    emit(f, "\tCMPI \t LE %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                break;
            case BGT:
                if((p->typf & UNSIGNED) == UNSIGNED){
                    emit(f, "\tCMPI \t GU %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                else{
                    emit(f, "\tCMPI \t G %s %s R4\n", regnames[q1reg], regnames[q2reg]);
                }
                break;
            default:
                ierror(0);
                break;
        }
    }
}

void load_into_reg(FILE *f, int dest_reg, struct obj *o, int type, int tmp_reg){
    switch((o->flags) & (KONST|VAR|REG|DREFOBJ|VARADR)){
        case KONST:
            load_cons(f, dest_reg, o->val.vmax);
            break;
        case (KONST|DREFOBJ):
            //place memory location constant point to into register
            emit(f, "\tLD  \t ");
            emitval(f, &(o->val), type);
            emit(f, " %s\n", regnames[dest_reg]);
            break;
        case REG:
            //move between registers
            if((o->reg) != dest_reg){
                emit(f, "\tOR  \t %s %s %s\n",regnames[R0], regnames[o->reg], regnames[dest_reg]);
            }
            break;
        case VAR:
            //put value of variable into register

            switch((o->v->storage_class) & (STATIC|EXTERN|AUTO|REGISTER)){
                case STATIC:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s L_%ld\n", regnames[dest_reg], zm2l(o->v->offset));
                        load_cons(f, tmp_reg, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg], regnames[tmp_reg], regnames[tmp_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    }
                    else{
                        emit(f, "\tLD \t L_%ld %s\n", zm2l(o->v->offset), regnames[dest_reg]);
                    }
                    break;
                case EXTERN:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s %s\n", regnames[dest_reg], o->v->identifier);
                        load_cons(f, tmp_reg, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg], regnames[tmp_reg], regnames[tmp_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    }
                    else{
                        emit(f, "\tLD \t %s %s\n", o->v->identifier , regnames[dest_reg]);
                    }
                    break;
                case AUTO:
                    if((o->v->offset) < 0){
                        //this is argument
                        load_cons(f, dest_reg, (zm2l(o->v->offset)/(-1L))+2+zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg],regnames[FP], regnames[tmp_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    }
                    else{
                        //this is auto variable
                        int offset = zm2l(o->v->offset)+zm2l(o->val.vmax);

                        if(offset == 0){
                            emit(f, "\tLDI \t %s %s\n", regnames[FP], regnames[dest_reg]);
                        }
                        else if(offset == 1){
                            emit(f, "\tDEC \t %s %s\n", regnames[FP], regnames[tmp_reg]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                        }
                        else{
                            load_cons(f, dest_reg, offset);
                            emit(f, "\tSUB \t %s %s %s\n", regnames[FP],regnames[dest_reg], regnames[tmp_reg]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                        }

                    }
                    break;
                default:
                    #ifdef DEBUG_MARK
                    printf("\tHave to load variable that is not static, extern or auto, this is not implemented!\n");
                    #else
                    ierror(0);
                    #endif
                    break;
            }

            break;
        case (VAR|REG):
            if((o->reg) != dest_reg){
                emit(f, "\tOR  \t %s %s %s\n", regnames[R0], regnames[o->reg], regnames[dest_reg]);
            }
            break;
        case (REG|DREFOBJ):
            //point into memory with register value

            emit(f, "\tLDI \t %s %s\n", regnames[o->reg], regnames[dest_reg]);
            break;
        case (VAR|DREFOBJ):
            //use variable value as pointer to memory

            switch((o->v->storage_class) & (STATIC|EXTERN|AUTO|REGISTER)){
                case STATIC:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s L_%ld\n", regnames[dest_reg], zm2l(o->v->offset));
                        load_cons(f, tmp_reg, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg], regnames[tmp_reg], regnames[dest_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[dest_reg], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tLD  \t L_%ld %s\n", zm2l(o->v->offset), regnames[tmp_reg]);
                    }
                    emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    break;
                case EXTERN:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s %s\n", regnames[dest_reg], o->v->identifier);
                        load_cons(f, tmp_reg, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg], regnames[tmp_reg], regnames[dest_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[dest_reg], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tLD \t %s %s\n", o->v->identifier , regnames[tmp_reg]);
                    }
                    emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    break;
                case AUTO:
                    if((o->v->offset) < 0){
                        //this is argument
                        load_cons(f, dest_reg, (zm2l(o->v->offset)/(-1L))+2+zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg],regnames[FP], regnames[tmp_reg]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                    }
                    else{
                        //this is auto variable
                        int offset = zm2l(o->v->offset)+zm2l(o->val.vmax);

                        if(offset == 0){
                            emit(f, "\tLDI \t %s %s\n", regnames[FP], regnames[dest_reg]);
                        }
                        else if(offset == 1){
                            emit(f, "\tDEC \t %s %s\n", regnames[FP], regnames[tmp_reg]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                        }
                        else{
                            load_cons(f, dest_reg, offset);
                            emit(f, "\tSUB \t %s %s %s\n", regnames[FP],regnames[dest_reg], regnames[tmp_reg]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
                        }

                    }
                    break;
                default:
                    #ifdef DEBUG_MARK
                    printf("\tHave to load variable that is not static, extern or auto, this is not implemented!\n");
                    #else
                    ierror(0);
                    #endif
                    break;
            }

            emit(f, "\tLDI \t %s %s\n", regnames[dest_reg], regnames[tmp_reg]);
            emit(f, "\tOR  \t R0 %s %s\n", regnames[tmp_reg], regnames[dest_reg]);

            break;
        case (VAR|REG|DREFOBJ):
            if((o->reg) != dest_reg){
                emit(f, "\tOR  \t %s %s %s\n",regnames[R0], regnames[o->reg], regnames[tmp_reg]);
            }
            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[dest_reg]);
            break;
        case (VAR|VARADR):
            //into dest_reg store address of variable
            switch((o->v->storage_class) & (STATIC|EXTERN)){
                case EXTERN:
                    emit(f, "\tMVIA \t %s %s\n", regnames[dest_reg], o->v->identifier);
                    break;
                case STATIC:
                    emit(f, "\tMVIA \t %s L_%ld\n", regnames[dest_reg], zm2l(o->v->offset));
                    break;
                default: //this is pointless storage_class can be only static or extern with VARADR
                    ierror(0);
            }            
            //this is useful when object is array and we want adres of nonfirst element
            if(o->val.vmax > 0){
                load_cons(f, tmp_reg, o->val.vmax);
                emit(f, "\tADD \t %s %s %s\n", regnames[dest_reg], regnames[tmp_reg], regnames[dest_reg]);              
            }
            
            break;
        default:
            #ifdef DEBUG_MARK
            printf("\tSomething is wrong while acuring operand!\n");
            #else
            ierror(0);
            #endif
            break;
    }
}

void store_from_reg(FILE *f, int source_reg, struct obj *o, int type, int tmp_reg, int tmp_reg_b){
    switch((o->flags) & (KONST|VAR|REG|DREFOBJ|VARADR)){
        case KONST:
            //How can I store register into KONST?!
            ierror(0);
            break;
        case (KONST|DREFOBJ):
            //use konstant as pointer into memory
            emit(f, "\tST  \t %s ", regnames[source_reg]);
            emitval(f, &(o->val), type);
            emit(f, "\n");
            break;
        case REG:
            //move from register into register
            if(source_reg != (o->reg)){
                emit(f, "\tOR  \t %s %s %s\n",regnames[R0], regnames[source_reg], regnames[o->reg]);
            }
            break;
        case VAR:
            //load register into variable
            switch((o->v->storage_class) & (STATIC|EXTERN|AUTO|REGISTER)){
                case STATIC:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s L_%ld\n", regnames[tmp_reg], zm2l(o->v->offset));
                        load_cons(f, tmp_reg_b, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg], regnames[tmp_reg_b], regnames[tmp_reg]);
                        emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tST  \t %s L_%ld\n", regnames[source_reg], zm2l(o->v->offset));
                    }
                    break;
                case EXTERN:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s %s\n", regnames[tmp_reg], o->v->identifier);
                        load_cons(f, tmp_reg_b, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg], regnames[tmp_reg_b], regnames[tmp_reg]);
                        emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tST  \t %s %s\n", regnames[source_reg], o->v->identifier);
                    }
                    break;
                case AUTO:
                    if((o->v->offset) < 0){
                        //function argument
                        load_cons(f, tmp_reg, (zm2l(o->v->offset)/(-1L))+2+zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg],regnames[FP], regnames[tmp_reg]);
                        emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    }
                    else{
                        //auto variable
                        int offset = zm2l(o->v->offset)+zm2l(o->val.vmax);
                        if (offset == 0){
                            emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[FP]);
                        }
                        else if(offset == 1){
                            emit(f, "\tDEC \t %s %s\n", regnames[FP], regnames[tmp_reg]);
                            emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                        }
                        else{
                            load_cons(f, tmp_reg, offset);
                            emit(f, "\tSUB \t %s %s %s\n", regnames[FP],regnames[tmp_reg], regnames[tmp_reg]);
                            emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                        }
                    }
                    break;
                default:
                    #ifdef DEBUG_MARK
                    printf("\tHave to store into variable that is not static, extern or auto, this is not implemented!\n");
                    #else
                    ierror(0);
                    #endif
                    break;
            }
            break;
        case (VAR|REG):
            emit(f, "\tOR   \t %s %s %s\n", regnames[R0], regnames[source_reg], regnames[o->reg]);
            break;
        case (REG|DREFOBJ):
            //use value in register as pointer into memory
            emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[o->reg]);
            break;
        case (VAR|DREFOBJ):
            //use value in variable as pointer into memory
            switch((o->v->storage_class) & (STATIC|EXTERN|AUTO|REGISTER)){
                case STATIC:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s L_%ld\n", regnames[tmp_reg], zm2l(o->v->offset));
                        load_cons(f, tmp_reg_b, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg], regnames[tmp_reg_b], regnames[tmp_reg_b]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg_b], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tLD  \t L_%ld %s\n", zm2l(o->v->offset), regnames[tmp_reg]);
                    }
                    emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    break;
                case EXTERN:
                    if(zm2l(o->val.vmax) != 0){
                        emit(f, "\tMVIA \t %s %s\n", regnames[tmp_reg], o->v->identifier);
                        load_cons(f, tmp_reg_b, zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg], regnames[tmp_reg_b], regnames[tmp_reg_b]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg_b], regnames[tmp_reg]);
                    }
                    else{
                        emit(f, "\tLD  \t %s %s\n", o->v->identifier, regnames[tmp_reg] );
                    }
                    emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    break;
                case AUTO:
                    if((o->v->offset) < 0){
                        //function argument
                        load_cons(f, tmp_reg, (zm2l(o->v->offset)/(-1L))+2+zm2l(o->val.vmax));
                        emit(f, "\tADD \t %s %s %s\n", regnames[tmp_reg],regnames[FP], regnames[tmp_reg_b]);
                        emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg_b], regnames[tmp_reg]);
                        emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    }
                    else{
                        //auto variable
                        int offset = zm2l(o->v->offset)+zm2l(o->val.vmax);
                        if(offset == 0){
                            emit(f, "\tLDI \t %s %s\n", regnames[FP], regnames[tmp_reg_b]);
                        }
                        else if(offset == 1){
                            emit(f, "\tDEC \t %s %s\n", regnames[FP], regnames[tmp_reg_b]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg_b], regnames[tmp_reg]);
                        }
                        else{
                            load_cons(f, tmp_reg, offset);
                            emit(f, "\tSUB \t %s %s %s\n", regnames[FP],regnames[tmp_reg], regnames[tmp_reg]);
                            emit(f, "\tLDI \t %s %s\n", regnames[tmp_reg], regnames[tmp_reg_b]);
                        }
                        emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg_b]);
                    }
                    break;
                default:
                    #ifdef DEBUG_MARK
                    printf("\tHave to store into variable that is not static, extern or auto, this is not implemented!\n");
                    #else
                    ierror(0);
                    #endif
                    break;
            }
            break;
        case (VAR|REG|DREFOBJ):
            emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[o->reg]);
            break;
        case (VAR|VARADR): //use variable address as pointer
            switch(o->v->storage_class){
                case STATIC:
                    emit(f, "\tMVIA \t %s L_%ld\n", regnames[tmp_reg], zm2l(o->v->offset));
                    emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    break;
                case EXTERN:
                    emit(f, "\tMVIA \t %s %s\n", regnames[tmp_reg], o->v->identifier);
                    emit(f, "\tSTI \t %s %s\n", regnames[source_reg], regnames[tmp_reg]);
                    break;
                default: //can be only static or extern
                    ierror(0);
                    break;
            }
            break;
        default:
            #ifdef DEBUG_MARK
            printf("\tCant store reg into object, unknown object!\n");
            #else
            ierror(0);
            #endif
            break;
    }
}

void arithmetic(FILE *f, struct IC *p){
    int q1reg = 0;
    int q2reg = 0;

    int zreg = 0;
    int movez = 0;

    int unary = 0;

    int isunsigned = 0;
    if (((p->typf) & UNSIGNED) == UNSIGNED){
        isunsigned = 1;
    }

    if(((p->code) == MINUS) || ((p->code) == KOMPLEMENT)){
        unary = 1;
    }

    //load first operand
    if(((p->q1.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
        q1reg = p->q1.reg;
    }
    else{
        load_into_reg(f, R1, &(p->q1), p->typf, R3);
        q1reg = R1;
    }

    //load second operand
    if(unary != 1){
        if(((p->q2.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
            q2reg = p->q2.reg;
        }
        else{
            load_into_reg(f, R2, &(p->q2), p->typf, R3);
            q2reg = R2;
        }
    }

    //prepare target register
    if(((p->z.flags) & (KONST|VAR|REG|DREFOBJ|VARADR)) == REG){
        zreg = p->z.reg;
    }
    else{
        zreg = R1;
        movez = 1;
    }

    if (((p->typf) & FLOAT) == FLOAT || ((p->typf) & DOUBLE) == DOUBLE || ((p->typf) & LDOUBLE) == LDOUBLE){
        switch(p->code){
            case ADD:
                emit(f, "\tFADD \t ");
                break;
            case SUB:
                emit(f, "\tFSUB \t ");
                break;
            case MULT:
                emit(f, "\tFMUL \t ");
                break;
            case DIV:
                emit(f, "\tFDIV \t ");
                break;
            case MINUS:
                load_cons(f, R2, 0x3f800000);
                emit(f, "\tSUB \t ");
                unary = 0;
                q2reg = R2;
                break;
            default:
                #ifdef DEBUG_MARK
                printf("This is not implemented!\n");
                #else
                ierror(0);
                #endif
                break;
        }
    }
    else{

        //emit instruction opcode
        switch(p->code){
            case OR:
                emit(f, "\tOR  \t ");
                break;
            case XOR:
                emit(f, "\tXOR \t ");
                break;
            case AND:
                emit(f, "\tAND \t ");
                break;
            case LSHIFT:
                emit(f, "\tLSL \t ");
                break;
            case RSHIFT:
                if(isunsigned == 1) {
                    emit(f, "\tLSR \t ");
                }
                else{
                    emit(f, "\tASR \t ");
                }
                break;
            case ADD:
                emit(f, "\tADD \t ");
                break;
            case SUB:
                emit(f, "\tSUB \t ");
                break;
            case MULT:
                if(isunsigned == 1) {
                    emit(f, "\tMULU \t ");
                }
                else{
                    emit(f, "\tMUL \t ");
                }
                break;
            case DIV:
                if(isunsigned == 1) {
                    emit(f, "\tDIVU \t ");
                }
                else{
                    emit(f, "\tDIV \t ");
                }
                break;
            case MOD:
                if(isunsigned == 1) {
                    emit(f, "\tREMU \t ");
                }
                else{
                    emit(f, "\tREM \t ");
                }
                break;
            case ADDI2P:
                emit(f, "\tADD \t ");
                break;
            case SUBIFP:
                emit(f, "\tSUB \t ");
                break;
            case SUBPFP:
                emit(f, "\tSUB \t ");
                break;
            case MINUS:
                emit(f, "\tDEC \t ");
                break;
            case KOMPLEMENT:
                emit(f, "\tNOT \t ");
                break;
            default:
                #ifdef DEBUG_MARK
                printf("\tPassed invalid IC into arithmetic()\n\tp->code: %d\n", p->code);
                #else
                ierror(0);
                #endif
                break;
        }
    }

    //emit instruction arguments
    if(unary != 1){
        emit(f, "%s %s %s\n", regnames[q1reg], regnames[q2reg], regnames[zreg]);
    }
    else{
        emit(f, "%s %s\n", regnames[q1reg], regnames[zreg]);
    }

    if(movez == 1){
        store_from_reg(f, R1, &(p->z), p->typf, R2, R3);
    }
}

void load_cons(FILE *f, int reg, long int value){
    if(value == 0){
        emit(f, "\tOR  \t R0 R0 %s\n", regnames[reg]);
    }
    else if((16777216 > value) && (value > 0)){
        emit(f, "\tMVIA \t %s %ld\n", regnames[reg], value);
    }
    else if (value > 0){
        emit(f, "\t.MVI \t %s %ld\n", regnames[reg], value);
    }
    else{
        emit(f, "\t.MVI \t %s 0x%x\n", regnames[reg], value);
    }
}
