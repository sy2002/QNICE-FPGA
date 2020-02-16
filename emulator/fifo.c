/*
** Very simple FIFO
**
** Originally intended use-case is keyboard FIFO for the UART in VGA mode and for SDL keyboard
**
** done by sy2002 in February 2020
**
*/

#include <stdio.h>
#include <stdlib.h>

#include "fifo.h"

fifo_t* fifo_init(unsigned int size)
{
    fifo_t* fifo = malloc(sizeof(fifo_t));
    if (fifo && (fifo->data = malloc(size * sizeof(int))))
    {
        fifo->size = size;
        fifo_clear(fifo);
        return fifo;
    }
    else
    {
        printf("Out of memory error (fifo.c: fifo_init)\n");
        exit(1);
        return 0;
    }
}

void fifo_free(fifo_t* fifo)
{
    free(fifo->data);
    free(fifo);
}

void fifo_clear(fifo_t* fifo)
{
    fifo->head = fifo->tail = fifo->count = 0;
}

void fifo_push(fifo_t* fifo, int data)
{
    if (fifo->count < fifo->size)
    {
        fifo->data[fifo->head] = data;
        fifo->count++;
        if (fifo->head < (fifo->size - 1))
            fifo->head++;
        else
            fifo->head = 0;
    }
}

int fifo_pull(fifo_t* fifo)
{
    int retval = 0;
    if (fifo->count)
    {
        retval = fifo->data[fifo->tail];
        fifo->count--;
        if (fifo->tail < (fifo->size - 1))
            fifo->tail++;
        else
            fifo->tail = 0;
    }
    return retval;
}
