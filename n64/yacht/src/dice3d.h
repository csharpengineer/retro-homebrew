// The five dice as lit, textured 3D cubes on the felt, with the tumble.
#pragma once
#include "core/game.h"

// Draws the dice (and their shadows) as the game state has them this frame.
// t counts frames, for the idle sway.
void dice_draw(const game_t *g, uint32_t t);
