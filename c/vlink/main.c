/* $VER: vlink main.c V0.15a (09.12.15)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2015  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2015 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#define MAIN_C
#include "vlink.h"

struct GlobalVars gvars;



static char *get_option_arg(int argc,char *argv[],int *i)
/* get pointer to the string, which either directly follows the option
   character or is stored in the next argument */
{
  if (argv[*i][2])
    return &argv[*i][2];
  else {
    if (++*i<argc) {
      /* another option? */
      if (argv[*i][0]!='-' || isdigit((unsigned char)argv[*i][1]))
        return argv[*i];
    }
    --*i;
  }
  error(5,argv[*i][1]);
  return NULL;  /* not reached */
}


static char *get_arg(int argc,char *argv[],int *i)
{
  if ((*i+1)<argc && *argv[*i+1]!='-')
    return argv[++*i];
  error(34,argv[*i]);  /* option requires argument */
  return NULL;  /* not reached */
}


static lword get_assign_arg(int argc,char *argv[],int *i,
                            char *name,size_t len)
{
  char *p = get_arg(argc,argv,i);
  char *n = name;
  lword val;

  while (--len && *p!='\0' && *p!='=')
    *n++ = *p++;
  *n = '\0';
  if (n == name) {
    error(34,argv[*i]);  /* option requires argument */
    return 0;  /* not reached */
  }
  if (*p++ != '=') {
    error(130,argv[*i-1]);  /* bad assignment */
    return 0;  /* not reached */
  }
  if (sscanf(p,"%lli",&val) != 1) {
    error(130,argv[*i-1]);  /* bad assignment */
    return 0;  /* not reached */
  }
  return val;
}


static void  ReadListFile(struct GlobalVars *gv,char *name,uint16_t flags)
/* read a file, which contains a list of object file names */
{
  FILE *f;
  struct InputFile *ifn;
  int c;
  char buf[256],*n=NULL;

  if (f = fopen(name,"r")) {
    do {
      int len = 0;

      c = fgetc(f);
      if (c == '\"') {  /* read file name in quotes */
        n = buf;
        len = 0;
        while ((c = fgetc(f))!=EOF && c!='\"') {
          if (len < 255) {
            len++;
            *n++ = c;
          }
        }
      }
      else if (c > ' ') {
        if (n == NULL) {
          n = buf;
          len = 0;
        }
        if (len < 255) {
          len++;
          *n++ = c;
        }
      }
      if (c<=' ' && n) {  /* file name ends here */
        *n = 0;
        ifn = alloc(sizeof(struct InputFile));
        ifn->name = allocstring(buf);
        ifn->lib = FALSE;
        ifn->flags = flags;
        addtail(&gv->inputlist,&ifn->n);
        n = NULL;
      }
    }
    while (c != EOF);
    fclose(f);
  }
  else
    error(8,name);  /* cannot open */
}


static uint16_t chk_flags(char *s)
/* check for input-file flags */
{
  if (!strcmp(s+5,"deluscore"))
    return IFF_DELUNDERSCORE;

  else if (!strcmp(s+5,"adduscore"))
    return IFF_ADDUNDERSCORE;

  error(2,s);
  return 0;
}


static int flavours_cmp(const void *f1,const void *f2)
{
  return strcmp(*(char **)f1,*(char **)f2);
}


void cleanup(struct GlobalVars *gv)
{
  exit(gv->returncode);
}


int main(int argc,char *argv[])
{
  struct GlobalVars *gv = &gvars;
  int i,j;
  char *buf;
  struct LibPath *libp;
  struct InputFile *ifn;
  bool stdlib = TRUE;
  int so_version = 0;   /* minum version for shared objects */
  uint16_t flags = 0;   /* input file flags */

  /* initialize and set default values */
  memset(gv,0,sizeof(struct GlobalVars));
  initlist(&gv->libpaths);
  initlist(&gv->rpaths);
  gv->dynamic = TRUE;  /* link with dynamic libraries first */
  gv->interp_path = DEFAULT_INTERP_PATH;
  gv->soname = NULL;
  gv->endianess = -1;  /* endianess is unknown */

#ifdef DEFTARGET
  for (j=0; fff[j]; j++) {
    if (!strcmp(fff[j]->tname,DEFTARGET)) {
      gv->dest_format = (uint8_t)j;
      break;
    }
  }
  if (fff[j] == NULL) {
    fprintf(stderr,"Configuration warning: Selected default target "
            "\"%s\" is not included.\nThe current default target "
            "is \"%s\".\n",DEFTARGET,fff[gv->dest_format]->tname);
    printf("\n");
  }
#endif

  initlist(&gv->inputlist);
  initlist(&gv->lnksec);
  gv->dest_name = "a.out";
  gv->maxerrors = DEF_MAXERRORS;
  gv->reloctab_format = RTAB_UNDEF;
  gv->osec_base_name = NULL;

  if (argc<2 || (argc==2 && *argv[1]=='?')) {
    show_usage();
    exit(EXIT_SUCCESS);
  }

  for (i=1; i<argc; i++) {

    if (*argv[i] == '-') {  /* option detected */
      switch (argv[i][1]) {

        case 'b':  
          if (!strcmp(&argv[i][2],"aseoff")) {  /* set base-relative offset */
            long bo;

            sscanf(get_arg(argc,argv,&i),"%li",&bo);
            fff[gv->dest_format]->baseoff = bo;
          }
          else {  /* select target format */
            if (buf = get_option_arg(argc,argv,&i)) {
              /* for compatibility with older vlink versions,
                 elf32amiga is automatically converted into elf32powerup
                 and amigaos into amigahunk */
              if (!strcmp(buf,"elf32amiga"))
                buf = "elf32powerup";
              else if (!strcmp(buf,"amigaos"))
                buf = "amigahunk";
              for (j=0; fff[j]; j++) {
                if (!strcmp(fff[j]->tname,buf))
                  break;
              }
              if (fff[j])
                gv->dest_format = (uint8_t)j;
              else
                error(9,buf);  /* invalid target format */
            }
          }
          break;

        case 'c':
          if (!strncmp(&argv[i][2],"lr-",3))
            flags &= ~(chk_flags(argv[i]));   /* -clr-flags */
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'd':
          if (!argv[i][2] || argv[i][2]=='c' || argv[i][2]=='p')
            gv->alloc_common = TRUE;  /* force alloc. of common syms. */
          else if (argv[i][2] == 'a')
            gv->alloc_addr = TRUE;  /* force alloc. of address syms. */
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'e':
          if (!strcmp(&argv[i][2],"xport-dynamic"))
            gv->dyn_exp_all = TRUE;  /* export all globals as dynamic */
          else  /* defines entry point */
            gv->entry_name = get_option_arg(argc,argv,&i);
          break;

        case 'f':
          if (!strcmp(&argv[i][2],"ixunnamed")) {
            gv->fix_unnamed = TRUE;  /* assign a name to unnamed sections */
          }
          else {  /* set a flavour */
            char *name,**fl;

            if (name = get_option_arg(argc,argv,&i)) {
              if (fl = gv->flavours.flavours) {
                char **tmp = alloc((gv->flavours.n_flavours+1)*sizeof(char *));

                memcpy(tmp,fl,gv->flavours.n_flavours*sizeof(char *));
                free(fl);
                fl = tmp;
              }
              else
                fl = alloc(sizeof(char *));
              fl[gv->flavours.n_flavours++] = name;
              gv->flavours.flavours = fl;
              gv->flavours.flavours_len += strlen(name) + 1;
            }
          }
          break;

        case 'h':
          if (!strcmp(&argv[i][2],"unkattr")) {
            struct SecAttrOvr *sao;
            char secname[64];
            lword val;

            val = get_assign_arg(argc,argv,&i,secname,64);
            sao = addsecattrovr(gv,secname,SAO_MEMFLAGS);
            sao->memflags = (uint32_t)val;
          }
          else {
            if (argv[i][2] == '\0') {
              show_usage();      /* help text */
              exit(EXIT_SUCCESS);
            }
            else
              error(2,argv[i]);  /* unrecognized option */
          }
          break;

        case 'i':
          if (!strcmp(&argv[i][2],"nterp"))
            gv->interp_path = get_arg(argc,argv,&i);
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'l':  /* library specifier */
          if (buf = get_option_arg(argc,argv,&i)) {
            ifn = alloc(sizeof(struct InputFile));
            ifn->name = buf;
            ifn->lib = TRUE;
            ifn->dynamic = gv->dynamic;
            ifn->so_ver = so_version;
            so_version = 0;
            ifn->flags = flags;
            addtail(&gv->inputlist,&ifn->n);
          }
          break;

        case 'm':
          if (!strcmp(&argv[i][2],"inalign")) {
            long a;

            sscanf(get_arg(argc,argv,&i),"%li",&a);
            gv->min_alignment = (uint8_t)a;
          }
          else if (!strcmp(&argv[i][2],"rel"))
            gv->auto_merge = TRUE;
          else if (!strcmp(&argv[i][2],"ultibase"))
            gv->multibase = TRUE;
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'n':
          if (!argv[i][2])
            gv->no_page_align = TRUE;
          else if (!strcmp(&argv[i][2],"ostdlib"))
            stdlib = FALSE;
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'o':  /* set output file name */
          if (!strncmp(&argv[i][2],"sec=",4) && argv[i][6]!='\0') {
            /* defines a base name of the sections to output */
            gv->osec_base_name = &argv[i][6];
            gv->output_sections = TRUE;  /* output each section as a file */
          }
          else if (!strcmp(&argv[i][2],"sec"))
            gv->output_sections = TRUE;  /* output each section as a file */
          else
            gv->dest_name = get_option_arg(argc,argv,&i);
          break;

        case 'q':  /* force relocations into final executable */
          gv->keep_relocs = TRUE;
          break;

        case 'r':  /* output is an relocatable object again */
          if (!argv[i][2]) {
            gv->dest_object = TRUE;
          }
          else if (!strcmp(&argv[i][2],"path")) {
            if (buf = get_arg(argc,argv,&i)) {
              libp = alloc(sizeof(struct LibPath));
              libp->path = buf;
              addtail(&gv->rpaths,&libp->n);
            }
          }
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 's':
          switch (argv[i][2]) {
            case '\0':  /* strip all symbols */
              gv->strip_symbols = STRIP_ALL;
              break;
            case 'c':   /* -sc force small code */
              gv->small_code = TRUE;
              break;
            case 'd':   /* -d force small data */
              gv->small_data = TRUE;
              break;
            case 'e':
              if (!strncmp(&argv[i][3],"t-",2))  /* -set-flags */
                flags |= chk_flags(argv[i]);
              else
                error(2,argv[i]);  /* unrecognized option */
              break;
            case 'h':   /* -shared */
              if (!strcmp(&argv[i][3],"ared"))
                gv->dest_sharedobj = TRUE;
              else
                error(2,argv[i]);  /* unrecognized option */
              break;
            case 'o':   /* -soname <real name> */
              if (!strcmp(&argv[i][3],"name"))
                gv->soname = get_arg(argc,argv,&i);
              else
                error(2,argv[i]);  /* unrecognized option */
              break;
            case 't':   /* -static */
              if (!strcmp(&argv[i][3],"atic"))
                gv->dynamic = FALSE;
              else
                error(2,argv[i]);  /* unrecognized option */
              break;
            default:
              error(2,argv[i]);  /* unrecognized option */
              break;
          }
          break;

        case 't':  /* trace file accesses */
          if (!strcmp(&argv[i][2],"extbaserel"))
            gv->textbaserel = TRUE;
          else if (!strncmp(&argv[i][2],"os-",3)) {
            /* -tos-options for targets ataritos and aoutmint */
            if (!strcmp(&argv[i][5],"flags")) {
              long fl;

              sscanf(get_arg(argc,argv,&i),"%li",&fl);
              gv->tosflags = fl;
            }
            else if (!strcmp(&argv[i][5],"fastload"))
              gv->tosflags |= 1;
            else if (!strcmp(&argv[i][5],"fastram"))
              gv->tosflags |= 2;
            else if (!strcmp(&argv[i][5],"fastalloc"))
              gv->tosflags |= 4;
            else if (!strcmp(&argv[i][5],"private"))
              gv->tosflags &= ~0x30;
            else if (!strcmp(&argv[i][5],"global"))
              gv->tosflags |= 0x10;
            else if (!strcmp(&argv[i][5],"super"))
              gv->tosflags |= 0x20;
            else if (!strcmp(&argv[i][5],"readable"))
              gv->tosflags |= 0x30;
            else if (!strcmp(&argv[i][5],"textbased"))
              gv->textbasedsyms = 1;
            else
              error(2,argv[i]);  /* unrecognized option */
          }
          else if (!argv[i][2])
            gv->trace_file = stderr;
          else
            error(2,argv[i]);  /* unrecognized option */
          break;

        case 'u':  /* mark symbol as undefined */
          if (buf = get_option_arg(argc,argv,&i))
            add_symnames(&gv->undef_syms,buf);
          break;

        case 'v':  /* show version and target info */
          show_version();
          printf("Standard library path: "
#ifdef LIBPATH
                 LIBPATH
#endif
                 "\nDefault target: %s\n"
                 "Supported targets:",fff[gv->dest_format]->tname);
          for (j=0; fff[j]; j++)
            printf(" %s",fff[j]->tname);
          printf("\n");
          exit(EXIT_SUCCESS);

        case 'w':  /* suppress warnings */
          gv->dontwarn = TRUE;
          break;

        case 'x':  /* discard all local symbols */
          gv->discard_local = DISLOC_ALL;
          break;

        case 'y':  /* trace all accesses on a specific symbol */
          if (gv->trace_syms == NULL)
            gv->trace_syms = alloc_hashtable(TRSYMHTABSIZE);
          if (buf = get_option_arg(argc,argv,&i)) {
            struct SymNames **chain = 
                            &gv->trace_syms[elf_hash(buf)%TRSYMHTABSIZE];
            while (*chain)
              chain = &(*chain)->next;
            *chain = alloczero(sizeof(struct SymNames));
            (*chain)->name = buf;
          }
          break;

        case 'B':  /* set link mode */
          if (buf = get_option_arg(argc,argv,&i)) {
            if (!strcmp(buf,"static")) {
              gv->dynamic = FALSE;
            }
            else if (!strcmp(buf,"dynamic")) {
              gv->dynamic = TRUE;
            }
            else if (!strcmp(buf,"shareable")) {
              gv->dest_sharedobj = TRUE;
            }
            else if (!strcmp(buf,"forcearchive")) {
              gv->whole_archive = TRUE;
            }
            else if (!strcmp(buf,"symbolic")) {
              ;  /* don't know, what this means... */
            }
            else {
              error(3,buf);  /* unknown link mode */
            }
          }
          break;

        case 'C':  /* select con-/destructor type */
          if (buf = get_option_arg(argc,argv,&i)) {
            if (!strcmp(buf,"gnu")) {
              gv->collect_ctors_type = CCDT_GNU;
            }
            else if (!strcmp(buf,"vbcc")) {
              gv->collect_ctors_type = CCDT_VBCC;
            }
            else if (!strcmp(buf,"vbccelf")) {
              gv->collect_ctors_type = CCDT_VBCC_ELF;
            }
            else if (!strcmp(buf,"sasc")) {
              gv->collect_ctors_type = CCDT_SASC;
            }
            else  /* @@@ print error message */
              gv->collect_ctors_type = CCDT_NONE;
          }
          break;

        case 'E':  /* set endianess */
          switch (argv[i][2]) {
            case 'B':
              gv->endianess = _BIG_ENDIAN_;
              break;
            case 'L':
              gv->endianess = _LITTLE_ENDIAN_;
              break;
            default:
              error(2,argv[i]);  /* unrecognized option */
              break;
          }
          break;

        case 'F':  /* read a file with object file names */
          if (buf = get_option_arg(argc,argv,&i))
            ReadListFile(gv,buf,flags);
          break;

        case 'L':  /* new library search path */
          if (buf = get_option_arg(argc,argv,&i)) {
            libp = alloc(sizeof(struct LibPath));
            libp->path = buf;
            addtail(&gv->libpaths,&libp->n);
          }
          break;

        case 'M':  /* mapping output */
          gv->map_file = stdout;
          break;

        case 'P':  /* protect symbol against stripping */
          if (buf = get_option_arg(argc,argv,&i))
            add_symnames(&gv->prot_syms,buf);
          break;

        case 'R':  /* use short form for relocations */
          if (buf = get_option_arg(argc,argv,&i)) {
            if (!strcmp(buf,"std"))
              gv->reloctab_format = RTAB_STANDARD;
            else if (!strcmp(buf,"add"))
              gv->reloctab_format = RTAB_ADDEND;
            else if (!strcmp(buf,"short"))
              gv->reloctab_format = RTAB_SHORTOFF;
            else
              error(123,buf);  /* unknown reloc table format ignored */
          }
          break;

        case 'S':  /* strip debugger symbols */
          gv->strip_symbols = STRIP_DEBUG;
          break;

        case 'T':  /* read linker script file or set text address */
          if (!strcmp(&argv[i][2],"text")) {
            if (i+1 < argc)
              sscanf(argv[++i],"%lli",&gv->start_addr);
            else
              error(5,'T');  /* option requires argument */
          }
          else if (buf = get_option_arg(argc,argv,&i)) {
            if (gv->ldscript = mapfile(buf))
              gv->scriptname = buf;
            else
              error(8,buf);
          }
          break;

        case 'V':  /* set minimum version for next shared object */
          if (buf = get_option_arg(argc,argv,&i))
            so_version = atoi(buf);
          break;

        case 'X':  /* discard temporary local symbols only */
          gv->discard_local = DISLOC_TMP;
          break;

        default:
          error(2,argv[i]);  /* unrecognized option */
          break;
      }
    }

    else {  /* normal input file name */
      ifn = alloc(sizeof(struct InputFile));
      ifn->name = argv[i];
      ifn->lib = FALSE;
      ifn->flags = flags;
      addtail(&gv->inputlist,&ifn->n);
    }
  }

  /* add default library search path at the end of the list */
  if (stdlib) {
#ifdef LIBPATH
    libp = alloc(sizeof(struct LibPath));
    libp->path = LIBPATH;  /* default search path */
    addtail(&gv->libpaths,&libp->n);
#endif
  }

  /* allocate flavour path buffer and sort flavours */
  gv->flavours.flavour_dir = alloc(gv->flavours.flavours_len + 1);
  if (gv->flavours.n_flavours > 1) {
    qsort((void *)gv->flavours.flavours, gv->flavours.n_flavours,
          sizeof(char **), flavours_cmp);
  }

  /* link them... */
  linker_init(gv);
  linker_load(gv);     /* load all objects and libraries and their symbols */
  linker_resolve(gv);  /* resolve symbol references */
  linker_relrefs(gv);  /* find all relative references between sections */
  linker_dynprep(gv);  /* prepare for dynamic linking */
  linker_join(gv);     /* join sections with same name and type */
  linker_mapfile(gv);  /* mapfile output */
  linker_copy(gv);     /* copy section contents and fix symbol offsets */
  linker_relocate(gv); /* relocate addresses in joined sections */
  linker_write(gv);    /* write output file in selected target format */
  linker_cleanup(gv);

  cleanup(gv);
  return 0;
}
