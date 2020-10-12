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

// Draw the current square as 3x3 characters.
void maze_drawPos(int sq, int level, int hint);

// Draw the entire maze and place cursor at player.
void maze_draw(int level, int hint);

// Generate maze
void maze_init();

int maze_move(int dir);

void maze_reset();

#endif // _MAZE_GRID_H_

