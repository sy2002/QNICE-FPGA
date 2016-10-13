#ifndef __STDIO_H
#define __STDIO_H 1

#define EOF (-1)

#ifndef BUFSIZ
#define BUFSIZ 1024L
#endif
#define FOPEN_MAX 1024          /*  Does not really matter */

#define _IOFBF 1L
#define _IOLBF 2L
#define _IONBF 3L

#define HASBUF 1L
#define NOBUFMEM 2L

#define SEEK_SET  0
#define SEEK_CUR  1
#define SEEK_END  2

#define _READ 1
#define _WRITE 2
#define _UNBUF 4
#define _EOF 8
#define _ERR 16
#define _READABLE 32
#define _WRITEABLE 64
#define _LINEBUF 128
#define _NOTMYBUF 256
#define _ISTTY 512
/* Define this for CRLF-conversion in text-mode
#define _CLE 16384
*/

#ifdef __BUILD_LIB
#include "libsys.h"
#ifdef HAVE_TTYS
extern int __isatty(int);
#endif
#endif

typedef struct _iobuf
{
    int   filehandle;           /*  filehandle  */
    char *pointer;
    char *base;                 /*  buffer address  */
    struct _iobuf *next;
    struct _iobuf *prev;
    int count;
    int flags;
    int bufsize;
#ifdef _CLE
    int clebuf;                 /* buffered char during CRLF conversion */
#endif
} FILE;

/* Have to be initialized in _main(). */
extern FILE *stdin, *stdout, *stderr;

int _fillbuf(FILE *),_putbuf(int,FILE *),_flushbuf(FILE *);
void _ttyflush(void);

#define L_tmpnam        30
#define TMP_MAX FOPEN_MAX

#define FILENAME_MAX 107

/*
  Adapt corresponding to stddef.h
*/
#ifndef __SIZE_T
#define __SIZE_T 1
#ifdef __SIZE_T_INT
typedef unsigned int size_t;
#else
typedef unsigned long size_t;
#endif
#endif

/*
  Adapt as needed.
*/
#ifndef __FPOS_T
#define __FPOS_T 1
typedef long fpos_t;
#endif

#ifndef __STDARG_H
#include <stdarg.h>
#endif

#undef NULL
#define NULL ((void*)0)

FILE *fopen(const char *,const char *);
FILE *freopen(const char *,const char *,FILE *);
int fflush(FILE *);
int fclose(FILE *);
int rename(const char *,const char *);
int remove(const char *);
FILE *tmpfile(void);
char *tmpnam(char *);
int setvbuf(FILE *,char *,int,size_t);
void setbuf(FILE *,char *);
int fprintf(FILE *, const char *, ...);
int printf(const char *, ...);
int sprintf(char *, const char *,...);
int snprintf(char *,size_t,const char *,...);
/*
  Simple versions of IO functions (see vbcc documentation).
  If versions with __v1 or __v2 are declared they are also used.
*/
int __v0fprintf(FILE *, const char *);
int __v0printf(const char *);
int __v0sprintf(char *, const char *);
int vprintf(const char *,va_list);
int vfprintf(FILE *,const char *,va_list);
int vsprintf(char *,const char *,va_list);
int vsnprintf(char *,size_t,const char *,va_list);
int fscanf(FILE *, const char *, ...);
int scanf(const char *, ...);
int sscanf(const char *, const char *, ...);
int vscanf(const char *,va_list);
int vfscanf(FILE *,const char *,va_list);
int vsscanf(const char *,const char *,va_list);
char *fgets(char *, int, FILE *);
int fputs(const char *, FILE *);
char *gets(char *);
int puts(const char *);
int ungetc(int,FILE *);
size_t fread(void *,size_t,size_t,FILE *);
size_t fwrite(void *,size_t,size_t,FILE *);
int fseek(FILE *,long,int);
void rewind(FILE *);
long ftell(FILE *);
int fgetpos(FILE *,fpos_t *);
int fsetpos(FILE *,const fpos_t *);
void perror(const char *);
int fgetc(FILE *);
int fputc(int,FILE *);
int getchar(void);
int putchar(int);
#ifdef _CLE
int __putc(int,FILE *);
int __getc(FILE *);
#else
#define __putc(x,f) __rawputc((x),(f))
#define __getc(f) __rawgetc(f)
#endif

#define __check(arg,type) (volatile)sizeof((arg)==(type)0)

#define __rawputc(x,p) (((p)->flags|=_WRITE),((--((FILE*)(p))->count>=0&&((x)!='\n'||!(((FILE*)(p))->flags&_LINEBUF)))?(unsigned char)(*((FILE*)(p))->pointer++=(x)):_putbuf((x),p)))
#define putc(x,f) __putc((x),(f))
#define putchar(x) __putc((x),stdout)
#define __rawgetc(p) (__check((p),FILE*),((p)->flags|=_READ),--((FILE*)(p))->count>=0?(unsigned char)*((FILE*)(p))->pointer++:_fillbuf(p))
#define getc(f) __getc(f)
#define getchar() __getc(stdin)

#define feof(p)         (__check((p),FILE*),((FILE*)(p))->flags&_EOF)
#define ferror(p)       (__check((p),FILE*),((FILE*)(p))->flags&_ERR)
#define clearerr(p)     (__check((p),FILE*),((FILE*)(p))->flags&=~(_ERR|_EOF))

#define fsetpos(f,ptr)  fseek((f),*(ptr),SEEK_SET)

#ifdef __VBCC__
#pragma printflike printf
#pragma printflike fprintf
#pragma printflike sprintf
#pragma printflike snprintf
#pragma scanflike scanf
#pragma scanflike fscanf
#pragma scanflike sscanf
#endif

#endif
