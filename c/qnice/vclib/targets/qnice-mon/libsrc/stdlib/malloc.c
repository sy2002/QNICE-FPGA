#include <stdlib.h>
#include <string.h>

#include "qmon.h"

/* These functions have to allocate properly aligned memory */
/* from the environment and return it (if possible).        */
void *__getcore(size_t);
void __freecore(void *,size_t);


/* Choose this struct that dividing/multiplying by its size */
/* can be done efficiently!                                 */
struct memblock {
    int used;
    size_t size;
    struct memblock *next;
    struct memblock *prev;
};

/* More than THRESHOLD blocks will be allocated/freed separately. */
#ifndef THRESHOLD
#define THRESHOLD 1022
#endif

/* No blocks with less than MIN_REST blocks will be created. */
#ifndef MIN_REST
#define MIN_REST    1
#endif

static struct memblock *first_block,*last_block,*current;
static struct memblock *first_pool,*last_pool;

/* Free all memory pools. May be redundant, if done by the
   environment. */
void _EXIT_1_malloc(void)
{
    struct memblock *p=first_pool,*n;
    while(p){
        n=p->next;
        __freecore(p,(p->size+2)*sizeof(struct memblock));
        p=n;
    }
}

/* Request a new pool of memory and add one block. */
static struct memblock *add_mem(size_t blocks)
{
    struct memblock *new=__getcore((blocks+2)*sizeof(struct memblock));
    if(!new) return 0;
    new->next=0;
    if(!first_pool)
        first_pool=new;
    else
        last_pool->next=new;
    new->prev=last_pool;
    last_pool=new;
    new->size=blocks;
    new++;
    new->size=blocks;
    if(blocks==THRESHOLD){
        /* Large blocks are handled separately. */
        new->next=0;
        if(!first_block)
            first_block=new;
        else
            last_block->next=new;
        new->prev=last_block;
        last_block=new;
    }
    return new;
}

void *malloc(size_t size)
{
    qmon_puts("[malloc]: ENTER, size = ");
    qmon_puthex((int) size);
    qmon_puts(", &current = ");
    qmon_puthex((int) &current);
    qmon_puts(", current = ");
    qmon_puthex((int) current);
    qmon_crlf();
    
    struct memblock *p,*n;
    size=(size+sizeof(struct memblock)-1)/sizeof(struct memblock);

    qmon_puts("[malloc]: size (after calc.) = ");
    qmon_puthex(size);
    qmon_puts(", THRESHOLD = ");
    qmon_puthex(THRESHOLD);
    qmon_crlf();

    if(size>THRESHOLD){
        /* Large blocks get their own pool. */
        if(!(p=add_mem(size))) return 0;
        p->used=1;
        return p+1;
    }
    /* Search for a free block that is large enough. */
    if(!(p=current)){
        if(!(p=add_mem(THRESHOLD))) return 0;
    }else{
        while(p->used||p->size<size){
            p=p->next;
            if(p==0) p=first_block;
            if(!p||p==current){
                if(!(p=add_mem(THRESHOLD))) return 0;
                break;
            }
        }
    }

    /* The next search will start here. */
    current=p;
    qmon_puts("[malloc]: current=p = ");
    qmon_puthex((int) current);
    qmon_crlf();

    if(p->size-size<MIN_REST+1){
        /* Use the entire block for this allocation. */
        p->used=1;
    }else{
        /* Split this block. */
        n=p+1+size;
        n->used=0;
        n->size=p->size-1-size;
        n->prev=p;
        if(n->next=p->next) n->next->prev=n;
        p->next=n;
        p->size=size;
        p->used=1;
        if(last_block==p) last_block=n;
    }
    return p+1;
}

void free(void *adr)
{
    struct memblock *p,*n;
    if(!adr) return;
    p=((struct memblock *)adr)-1;
    if(p->used!=1) exit(EXIT_FAILURE);
    if(p->size>THRESHOLD){
        /* Large blocks are immediately removed and returned */
        /* to the operating system.                          */
        p--;
        if(p->prev)
            p->prev->next=p->next;
        else
            first_pool=p->next;
        if(p->next)
            p->next->prev=p->prev;
        else
            last_pool=p->prev;
        __freecore(p,((p->size+2)*sizeof(struct memblock)));
        return;
    }
    n=p->next;
    if(n&&n==p+1+p->size&&!n->used){
        /* Merge with successor. */
        p->size+=n->size+1;
        if(n->next)
            n->next->prev=p;
        else
            last_block=p;
        p->next=n->next;
        if(current==n) current=p;
    }
    n=p->prev;
    if(n&&p==n+1+n->size&&!n->used){
        /* Merge with predecessor. */
        n->size+=p->size+1;
        if(p->next)
            p->next->prev=n;
        else
            last_block=n;
        n->next=p->next;
        if(current==p) current=n;
    }else
        p->used=0;
}

void *realloc(void *old,size_t nsize)
{
    struct memblock *p,*n;
    void *new;size_t osize;
    if(!old) return malloc(nsize);
    nsize=(nsize+sizeof(struct memblock)-1)/sizeof(struct memblock);
    p=((struct memblock *)old)-1;
    /* Already large enough? */
    if(p->size>=nsize) return old;
    n=p->next;
    if(p->size<=THRESHOLD&&n&&p->size+1+n->size>=nsize&&n==p+1+p->size&&!n->used){
        /* The block can be enlarged. We always use all the */
        /* currently available continuous space.            */
        p->size+=1+n->size;
        if(n->next)
            n->next->prev=p;
        else
            last_block=p;
        p->next=n->next;
        if(current==n) current=p;
        return old;
    }
    /* Sigh, we have to copy... */
    nsize*=sizeof(struct memblock);
    osize=p->size*sizeof(struct memblock);
    if(new=malloc(nsize)){
        memcpy(new,old,osize>nsize?nsize:osize);
        free(old);
    }
    return new;
}

