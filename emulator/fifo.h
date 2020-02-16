/*
** Header file for the FIFO
**
** done by sy2002 in February 2020
**
*/

#ifndef _QEMU_FIFO_H
#define _QEMU_FIFO_H

struct fifo_type_s
{
    unsigned int size;      //overall size of FIFO < sizeof (unsigned int)
    unsigned int count;     //amount of data
    unsigned int head;      //position where the next push puts data to
    unsigned int tail;      //position where the net pull gets data from
    int* data;              //data buffer
};

typedef struct fifo_type_s fifo_t;

fifo_t*     fifo_init(unsigned int size);
void        fifo_free(fifo_t* fifo);
void        fifo_clear(fifo_t* fifo);
void        fifo_push(fifo_t* fifo, int data);
int         fifo_pull(fifo_t* fifo);

#endif