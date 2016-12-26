
#ifndef __STRING_H
#define __STRING_H 1

/*
  Adapt according to stddef.h.
*/
#ifndef __SIZE_T
#define __SIZE_T 1
#ifdef __SIZE_T_INT
typedef unsigned int size_t;
#else
typedef unsigned long size_t;
#endif
#endif

#undef NULL
#define NULL ((void *)0)

/*
  Many of these functions should perhaps be implemented as
  inline-assembly or assembly-functions.

  Most suitable are:
  - memcpy
  - strcpy
  - strlen
  - strcmp
  - strcat
*/
void *memcpy(void *,const void *,size_t n);
void *memmove(void *,const void *,size_t);
void *memset(void *,int,size_t);
int memcmp(const void *,const void *,size_t);
void *memchr(const void *,int,size_t);
char *strcat(char *,const char *);
char *strncat(char *,const char *,size_t);
char *strchr(const char *,int);
size_t strcspn(const char *,const char *);
char *strpbrk(const char *,const char *);
char *strrchr(const char *,int);
size_t strspn(const char *,const char *);
char *strstr(const char *,const char *);
char *strtok(char *,const char *);
char *strerror(int);
size_t strlen(const char *);
char *strcpy(char *,const char *);
char *strncpy(char *,const char *,size_t);
int strcmp(const char *,const char *);
int strncmp(const char *,const char *,size_t);
int strcoll(const char *,const char *);
size_t strxfrm(char *,const char *,size_t);

#endif
