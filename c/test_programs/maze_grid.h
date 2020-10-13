#ifndef _MAZE_GRID_H_
#define _MAZE_GRID_H_

enum
{
   DIR_NORTH = 0,
   DIR_EAST,
   DIR_WEST,
   DIR_SOUTH,
   MAX_DIRS,
   VISITED = 7
};

#define MAZE_MASK_CURRENT 0x0001
#define MAZE_MASK_VISITED 0x0002
#define MAZE_MASK_ALL     0x0004
#define MAZE_MASK_END     0x0008

// Draw the entire maze and place cursor at player.
void maze_draw(int color, int mask);

// Generate maze
void maze_init();

int maze_move(int dir);

void maze_reset();

#endif // _MAZE_GRID_H_

