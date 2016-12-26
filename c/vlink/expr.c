/* $VER: vlink expr.c V0.14a (20.07.12)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2012  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2012 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#define EXPR_C
#include "vlink.h"
#include "ldscript.h"


static struct GlobalVars *gv;
static const char *scriptname;
static int line;
static char *s;
static lword caddr;

static struct Expr *expression(void);



static char *skipblanks(char *sp)
{
  unsigned char c = (unsigned char)*sp;

  while (isspace(c)) {
    if (c == '\n')
      line++;
    c = (unsigned char)*(++sp);
  }
  return sp;
}


void skip(void)
/* skips blanks, tabs, newlines and comments */
{
  s = skipblanks(s);
  while (*s == '/' && *(s+1) == '*') {
    /* skip comment */
    s += 2;
    while (*s && (*s!='*' || *(s+1)!='/')) {
      if (*s=='\n')
        line++;
      s++;
    }
    s += 2;
    s = skipblanks(s);
  }
}


char getchr(void)
{
  char c;

  skip();
  if (c = *s)
    s++;
  return c;
}


void skipblock(int level,char start,char end)
/* skips a block between the two specified start- and end-characters */
{
  char c;

  while (c = getchr()) {
    if (c == start) {
      ++level;
    }
    else if (c == end) {
      if (--level <= 0)
        break;
    }
  }
}


void back(int n)
/* go back n characters */
{
  s -= n;
}


char *gettxtptr(void)
{
  return s;
}


char *getarg(uint8_t mask)
{
/* table of valid characters, */
/* 0=invalid, 1=valid in whole word, 2=valid, but not as first char */
/* 4=symbols for pattern-matching, 11(+16)=valid for file names */
  static uint8_t validchars[256] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,8,0,0,0,8,0,0,0,0,4,8,0,8,1,12, /* * . / */
    2,2,2,2,2,2,2,2,2,2,8,0,0,8,0,4,  /* 0-9 ? */
    8,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  /* A-O */
    1,1,1,1,1,1,1,1,1,1,1,8,0,8,8,1,  /* P-Z _ */
    0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  /* a-o */
    1,1,1,1,1,1,1,1,1,1,1,8,0,8,0,0,  /* p-z */
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
    16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
    16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
    16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
  };
  static char buffer[MAXLEN];
  char *bp = buffer;

  /* try to read next word into buffer */
  skip();
  while (validchars[(unsigned char)*s] & mask) {
    mask |= 2;
    *bp++ = *s++;
    if (bp >= &buffer[MAXLEN-1])
      break;  /* buffer overflow */
  }
  *bp = '\0';

  if (buffer[0])
    return buffer;

  return NULL;  /* no valid word read */
}


char *getquoted(void)
/* return characters between "quotes" */
{
  skip();
  if (*s == '\"') {
    static char buffer[MAXLEN];
    char c,*bp=buffer;

    s++;

    while (c = *s) {
      s++;

      if (c == '\n') {
        line++;
        break;  /* @@@ newline breaks string? */
      }
      else if (c == '\"')
        break;

      *bp++ = c;
      if (bp >= &buffer[MAXLEN-1])
        break;  /* buffer overflow */
    }
    *bp = '\0';
    return buffer;
  }

  return NULL;
}


static struct Expr *new_expr(void)
{
  struct Expr *new = alloc(sizeof(struct Expr));

  new->left = new->right = NULL;
  return new;
}


static void free_expr(struct Expr *tree)
{
  if (tree) {
    free_expr(tree->left);
    free_expr(tree->right);
    free(tree);
  }
}


static struct Expr *primary_expr(void)
{
  lword val = 0;
  int type = ABS;
  struct Expr *new;

  if (*s == '(') {
    s++;
    skip();
    new = expression();
    if (*s != ')')
      error(66,scriptname,line,')');  /* ')' expected */
    else
      s++;
    skip();
    return new;
  }

  if (isdigit((unsigned char)*s)) {
    /* octal, decimal or hex constant */
    if (s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
      s += 2;
      while (isxdigit((unsigned char)*s)) {
        if (*s>='0' && *s<='9')
          val = (val<<4) + *s++ - '0';
        else if (*s>='a' && *s<='f')
          val = (val<<4) + *s++ - 'a' + 10;
        else
          val = (val<<4) + *s++ - 'A' + 10;
      }
    }
    else {
      int base = (*s=='0') ? 8 : 10;

      while (*s>='0' && *s<('0'+base)) {
        val = base*val + *s++ - '0';
      }
    }

    if (toupper((unsigned char)*s) == 'K') {
      val <<= 10;
      s++;
    }
    else if (toupper((unsigned char)*s) == 'M') {
      val <<= 20;
      s++;
    }
  }

  else {
    char *word;

    if (word = getarg(1)) {
      if (word[0]=='.' && word[1]=='\0') {  /* current address symbol '.' */
        if (caddr != -1) {
          if (caddr != -2) {
            val = caddr;
            type = REL;
          }
        }
        else {
          /* Address symbol '.' invalid outside SECTIONS block */
          error(101,scriptname,line);
        }
      }
      else {  /* otherwise it's possibly a function- or symbol-name */
        struct Symbol *sym;

        if (sym = findsymbol(gv,NULL,word)) {
          if (caddr==-1 && sym->type!=SYM_ABS) {
            /* Reference to non-absolute symbol */
            error(102,scriptname,line,sym->name);
          }
          else if (caddr != -2) {
            if (sym->type == SYM_ABS) {
              val = sym->value;
            }
            else if (sym->type==SYM_RELOC && sym->relsect->lnksec!=NULL) {
              val = (lword)sym->relsect->va + sym->value;
              type = REL;
            }
            else {
              /* Symbol is not yet assigned */
              error(106,scriptname,line,sym->name);
            }
          }
        }
        else {
          struct ScriptFunc *sfptr;

          for (sfptr=ldFunctions; sfptr->name; sfptr++) {
            if (!strcmp(sfptr->name,word))
              break;
          }
          if (sfptr->name) {
            if (caddr == -2) {
              if (getchr() == '(')
                skipblock(1,'(',')');
              else
                back(1);
            }
            else if (caddr != -1)
              type = sfptr->funcptr(gv,caddr,&val) ? ABS : REL;
            else
              error(105,scriptname,line);  /* No function-calls allowed here */
          }
          else if (caddr != -2)
            error(104,scriptname,line,word);  /* Unknown symbol or function */
        }
      }
    }
    else
      error(78,scriptname,line);   /* missing argument */
  }

  skip();
  new = new_expr();
  new->type = type;
  new->val = val;
  return new;
}


static struct Expr *unary_expr(void)
{
  struct Expr *new;
  char m;

  if (*s=='+' || *s=='-' || *s=='!' || *s=='~') {
    m = *s++;
    skip();
  }
  else
    return primary_expr();
  if (m == '+')
    return primary_expr();

  new = new_expr();
  new->type = (m=='-') ? NEG : ( (m=='!') ? NOT : CPL );
  new->left = primary_expr();
  return new;
}

static struct Expr *multiplicative_expr(void)
{
  struct Expr *left,*new;
  char m;

  left = unary_expr();
  skip();
  while (*s=='*' || *s=='/' || *s=='%') {
    m = *s++;
    skip();
    new = new_expr();
    new->type = (m=='*') ? MUL : ( (m=='/') ? DIV : MOD );
    new->left = left;
    new->right = unary_expr();
    left = new;
    skip();
  }
  return left;
}

static struct Expr *additive_expr(void)
{
  struct Expr *left,*new;
  char m;

  left = multiplicative_expr();
  skip();
  while (*s=='+' || *s=='-') {
    m = *s++;
    skip();
    new = new_expr();
    new->type = (m=='+') ? ADD : SUB;
    new->left = left;
    new->right = multiplicative_expr();
    left = new;
    skip();
  }
  return left;
}

static struct Expr *shift_expr(void)
{
  struct Expr *left,*new;
  char m;

  left = additive_expr();
  skip();
  while ((s[0]=='<' || s[0]=='>') && s[1]==s[0]) {
    m = *s;
    s += 2;
    skip();
    new = new_expr();
    new->type = (m=='<') ? LSH : RSH;
    new->left = left;
    new->right = additive_expr();
    left = new;
    skip();
  }
  return left;
}

static struct Expr *relational_expr(void)
{
  struct Expr *left,*new;
  char m1,m2=0;

  left = shift_expr();
  skip();
  while ((s[0]=='<' || s[0]=='>') && s[1]!=s[0]) {
    m1 = *s++;
    if (*s == '=')
      m2 = *s++;
    skip();
    new = new_expr();
    if (m1 == '<')
      new->type = m2 ? LEQ : LT;
    else
      new->type = m2 ? GEQ : GT;
    skip();
    new->left = left;
    new->right = shift_expr();
    left = new;
  }
  return left;
}

static struct Expr *equality_expr(void)
{
  struct Expr *left,*new;
  char m;

  left = relational_expr();
  skip();
  while ((s[0]=='!' || s[0]=='=') && s[1]=='=') {
    m = *s;
    s += 2;
    skip();
    new = new_expr();
    new->type = (m=='!') ? NEQ : EQ;
    skip();
    new->left = left;
    new->right = relational_expr();
    left = new;
  }
  return left;
}

static struct Expr *and_expr(void)
{
  struct Expr *left,*new;

  left = equality_expr();
  skip();
  while (s[0]=='&' && s[1]!='&') {
    s++;
    skip();
    new = new_expr();
    new->type = BAND;
    skip();
    new->left = left;
    new->right = equality_expr();
    left = new;
  }
  return left;
}

static struct Expr *exclusive_or_expr(void)
{
  struct Expr *left,*new;

  left = and_expr();
  skip();
  while (*s=='^') {
    s++;
    skip();
    new = new_expr();
    new->type = XOR;
    skip();
    new->left = left;
    new->right = and_expr();
    left = new;
  }
  return left;
}

static struct Expr *inclusive_or_expr(void)
{
  struct Expr *left,*new;

  left = exclusive_or_expr();
  skip();
  while (s[0]=='|' && s[1]!='|') {
    s++;
    skip();
    new = new_expr();
    new->type = BOR;
    skip();
    new->left = left;
    new->right = exclusive_or_expr();
    left = new;
  }
  return left;
}

static struct Expr *logical_and_expr(void)
{
  struct Expr *left,*new;

  left = inclusive_or_expr();
  skip();
  while (s[0]=='&' && s[1]=='&') {
    s += 2;
    skip();
    new = new_expr();
    new->type = LAND;
    skip();
    new->left = left;
    new->right = inclusive_or_expr();
    left = new;
  }
  return left;
}

static struct Expr *expression(void)
{
  struct Expr *left,*new;

  left = logical_and_expr();
  skip();
  while (s[0]=='|' && s[1]=='|') {
    s += 2;
    skip();
    new = new_expr();
    new->type = LOR;
    skip();
    new->left = left;
    new->right = logical_and_expr();
    left = new;
  }
  return left;
}


static int eval_expr(struct Expr *tree,lword *result)
/* evaluate expression tree, returns !0 when result is absolute */
{
  const char *fn = "eval_expr: ";
  int abs = 1;
  int labs=0,rabs=0;
  lword val=0,lval,rval;

  if (tree) {
    if (tree->left) {
      if (!(labs = eval_expr(tree->left,&lval)))
        abs = 0;
    }
    if (tree->right) {
      if (!(rabs = eval_expr(tree->right,&rval)))
        abs = 0;
    }

    switch(tree->type) {
      case ADD:
        val = lval + rval;
        break;
      case SUB:
        val = lval - rval;
        if (!labs && !rabs)
          abs = 1;  /* result is absolute, when both are reloc */
        break;
      case MUL:
        val = lval * rval;
        break;
      case DIV:
        if (rval == 0) {
          error(103,scriptname,line);  /* Division by zero */
          val = 0;
        }
        else
          val = lval / rval;
        break;
      case MOD:
        if (rval == 0) {
          error(103,scriptname,line);  /* Division by zero */
          val = 0;
        }
        else
          val = lval % rval;
        break;
      case NEG:
        val = -lval;
        break;
      case CPL:
        val = ~lval;
        break;
      case LAND:
        val = lval && rval;
        break;
      case LOR:
        val = lval || rval;
        break;
      case BAND:
        val = lval & rval;
        break;
      case BOR:
        val = lval | rval;
        break;
      case XOR:
        val = lval ^ rval;
        break;
      case NOT:
        val = !lval;
        break;
      case LSH:
        val = lval << rval;
        break;
      case RSH:
        val = lval >> rval;
        break;
      case LT:
        val = lval < rval;
        break;
      case GT:
        val = lval > rval;
        break;
      case LEQ:
        val = lval <= rval;
        break;
      case GEQ:
        val = lval >= rval;
        break;
      case NEQ:
        val = lval != rval;
        break;
      case EQ:
        val = lval == rval;
        break;
      case REL:
        abs = 0;
      case ABS:
        val = tree->val;
        break;
      default:
        ierror("%sIllegal tree type %d",fn,tree->type);
        break;
    }
  }
  else
    ierror("%sNULL tree",fn);

  *result = val;
  return abs;
}


int parse_expr(lword current_addr,lword *result)
/* Tries to parse the input stream. Returns !0 for an absolute result.
   If current_addr = -1 then '.' is not defined and only references
   to absolute symbols are allowed.
   If current_addr = -2 then no expression evaluation takes place
   at all. The expression is just skipped. */
{
  lword saved_caddr = caddr;
  struct Expr *tree;
  int abs;

  caddr = current_addr;
  skip();
  tree = expression();
  abs = caddr==-2 ? 1 : eval_expr(tree,result);
  free_expr(tree);
  caddr = saved_caddr;
  return abs;
}


int getlineno(void)
{
  return line;
}


void init_parser(struct GlobalVars *gvptr,const char *scname,
                 const char *base,int lineno)
{
  gv = gvptr;
  scriptname = scname;
  s = (char *)base;
  line = lineno;
}
