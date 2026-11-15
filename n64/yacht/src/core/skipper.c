#include "skipper.h"
#include "rules.h"

// What each box typically earns (Tandy ai_expect).
static const int8_t EXPECT[12] = { 2, 5, 8, 11, 14, 17, 15, 12, 8, 8, 21, 6 };

static bool scores_now(const uint8_t dice[5], const bool open[12], int cat) {
  return open[cat] && score_cat(dice, cat) > 0;
}

bool skipper_satisfied(const uint8_t dice[5], const bool open[12]) {
  if (scores_now(dice, open, CAT_YACHT) || scores_now(dice, open, CAT_LARGE)) return true;
  // a small straight is enough only once the large box is filled: with four in
  // a row held he can still roll for five
  if (scores_now(dice, open, CAT_SMALL) && !open[CAT_LARGE]) return true;
  if (scores_now(dice, open, CAT_FULL)) return true;
  return open[CAT_FOUR] && score_cat(dice, CAT_FOUR) >= 20;
}

int skipper_pick(const uint8_t dice[5], const bool open[12]) {
  int best_v = -32768, best_c = 0;
  for (int c = 0; c < NUM_CATS; c++) {
    if (!open[c]) continue;
    int v = score_cat(dice, c) - EXPECT[c];
    if (v > best_v) { best_v = v; best_c = c; }
  }
  return best_c;
}

static void hold_all(const uint8_t dice[5], uint8_t held[5], int face) {
  for (int i = 0; i < 5; i++) if (dice[i] == face) held[i] = 1;
}
static void hold_one(const uint8_t dice[5], uint8_t held[5], int face) {
  for (int i = 0; i < 5; i++) if (dice[i] == face) { held[i] = 1; return; }
}

void skipper_holds(const uint8_t dice[5], const bool open[12], uint8_t held[5]) {
  uint8_t c[8];
  for (int i = 0; i < 5; i++) held[i] = 0;
  count_dice(dice, c);
  int distinct = 0;
  for (int f = 1; f <= 6; f++) if (c[f]) distinct++;

  // chase a straight: keep one of each face in the run of five (large box open)
  // or four (only the small one) worth the most: faces * 2, plus 1 when it
  // already holds four in a row; ties keep the lower run
  if (distinct >= 4 && (open[CAT_SMALL] || open[CAT_LARGE])) {
    int len = open[CAT_LARGE] ? 5 : 4, best_f = 1, best_w = 0;
    for (int first = 1; first + len <= 7; first++) {
      int w = 0;
      for (int f = first; f < first + len; f++) if (c[f]) w += 2;
      for (int s = first; s + 4 <= first + len; s++)
        if (c[s] && c[s + 1] && c[s + 2] && c[s + 3]) { w++; break; }
      if (w > best_w) { best_w = w; best_f = first; }
    }
    for (int f = best_f; f < best_f + len; f++) if (c[f]) hold_one(dice, held, f);
    return;
  }

  // two pairs chase a full house
  if (open[CAT_FULL]) {
    int pairs = 0;
    for (int f = 1; f <= 6; f++) if (c[f] == 2) pairs++;
    if (pairs == 2) {
      for (int f = 1; f <= 6; f++) if (c[f] == 2) hold_all(dice, held, f);
      return;
    }
  }

  // keep the most promising group of matching dice
  int best_w = 0, best_f = 0;
  for (int f = 1; f <= 6; f++) {
    if (!c[f]) continue;
    int w = c[f] * 8 + f + (open[f - 1] ? 6 : 0);
    if (w > best_w) { best_w = w; best_f = f; }
  }
  if (best_f && (c[best_f] >= 2 || best_f >= 5)) hold_all(dice, held, best_f);
}
