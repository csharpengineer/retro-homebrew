// Scoring, dice and the random number generator. Pure C: no libdragon, so the
// same code runs in the native tests (tests/) and on the N64.
#pragma once
#include <stdint.h>
#include <stdbool.h>

enum {
  CAT_ONES, CAT_TWOS, CAT_THREES, CAT_FOURS, CAT_FIVES, CAT_SIXES,
  CAT_FULL, CAT_FOUR, CAT_SMALL, CAT_LARGE, CAT_CHOICE, CAT_YACHT,
  NUM_CATS
};
#define EMPTY (-1)

// Box names as the scorecard and status line show them.
extern const char *const CAT_NAMES[NUM_CATS];

// counts[f] = how many dice show face f (1-6); counts[0] and counts[7] stay 0.
void count_dice(const uint8_t dice[5], uint8_t counts[8]);
int sum_dice(const uint8_t dice[5]);
// What the dice would score in a box (SNES rules.s ScoreCat).
int score_cat(const uint8_t dice[5], int cat);

// The SNES generator: seed = seed*25173 + 13849 (mod 65536).
typedef struct { uint16_t seed; } rng_t;
uint16_t rng_next(rng_t *r);
int rng_roll1(rng_t *r);   // 1-6: ((r*6) >> 16) + 1
