/* $VER: vlink ldscript.h V0.13 (02.11.10)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2010 Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2010 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


struct ScriptFunc {
  char *name;
  int (*funcptr)(struct GlobalVars *,lword,lword *);
  /* returns 0 when result is relocatable and NOT absolute */
};

struct ScriptCmd {
  char *name;
  uint32_t flags;
  void (*cmdptr)(struct GlobalVars *);
};

#define SCMDF_SECDEF 1      /* valid in section definitions only */
#define SCMDF_GLOBAL 2      /* valid everywhere */
#define SCMDF_PAREN 0x2000  /* has arguments in parentheses */
#define SCMDF_SEMIC 0x4000  /* followed by a semicolon (PROVIDE) */
#define SCMDF_IGNORE 0x8000 /* parser flag: ignore when not allowed */


#ifndef LDSCRIPT_C
extern struct ScriptFunc ldFunctions[];
extern struct ScriptCmd ldCommands[];
#endif
