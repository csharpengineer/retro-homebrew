#include "rules.h"

const char *const CAT_NAMES[NUM_CATS] = {
  "Ones", "Twos", "Threes", "Fours", "Fives", "Sixes",
  "Full House", "Four Alike", "Small Str", "Large Str", "Choice", "Yacht",
};

void count_dice(const uint8_t dice[5], uint8_t counts[8]) {
  for (int f = 0; f < 8; f++) counts[f] = 0;
  for (int i = 0; i < 5; i++) if (dice[i] >= 1 && dice[i] <= 6) counts[dice[i]]++;
}

int sum_dice(const uint8_t dice[5]) {
  int s = 0;
  for (int i = 0; i < 5; i++) s += dice[i];
  return s;
}

static bool run(const uint8_t c[8], int from, int len) {
  for (int f = from; f < from + len; f++) if (!c[f]) return false;
  return true;
}

int score_cat(const uint8_t dice[5], int cat) {
  uint8_t c[8];
  count_dice(dice, c);
  if (cat <= CAT_SIXES) return (cat + 1) * c[cat + 1];
  switch (cat) {
    case CAT_FULL: {
      bool three = false, two = false;
      for (int f = 1; f <= 6; f++) { if (c[f] == 3) three = true; if (c[f] == 2) two = true; }
      return three && two ? sum_dice(dice) : 0;
    }
    case CAT_FOUR:
      for (int f = 1; f <= 6; f++) if (c[f] >= 4) return 4 * f;
      return 0;
    case CAT_SMALL:   // poker-dice straight: any four in a row
      for (int f = 1; f <= 3; f++) if (run(c, f, 4)) return 30;
      return 0;
    case CAT_LARGE:   // five in a row
      for (int f = 1; f <= 2; f++) if (run(c, f, 5)) return 40;
      return 0;
    case CAT_CHOICE: return sum_dice(dice);
    case CAT_YACHT:
      for (int f = 1; f <= 6; f++) if (c[f] == 5) return 50;
      return 0;
  }
  return 0;
}

uint16_t rng_next(rng_t *r) {
  r->seed = (uint16_t)(r->seed * 25173u + 13849u);
  return r->seed;
}

int rng_roll1(rng_t *r) {
  return (int)(((uint32_t)rng_next(r) * 6u) >> 16) + 1;
}
