// The Skipper, the computer opponent: the SNES v1.1 logic (snes/yacht/src/skipper.s).
// open[c] is true when box c is still empty for the player on turn.
#pragma once
#include <stdint.h>
#include <stdbool.h>

// True when the dice are good enough to stop rolling.
bool skipper_satisfied(const uint8_t dice[5], const bool open[12]);
// The open box that beats its typical score by the most; ties keep the first.
int skipper_pick(const uint8_t dice[5], const bool open[12]);
// Which dice to keep for the next roll (held[i] = 1), worked out from scratch.
void skipper_holds(const uint8_t dice[5], const bool open[12], uint8_t held[5]);
