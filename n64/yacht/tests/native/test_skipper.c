// The Skipper against a separate reference written from the rules in words
// (the same model as snes/yacht/tests/skipper.lua), on fixed and 3000 random cases.
#include "check.h"
#include <string.h>
#include "../../src/core/rules.h"
#include "../../src/core/skipper.h"

static const int EXPECT[12] = { 2, 5, 8, 11, 14, 17, 15, 12, 8, 8, 21, 6 };

static int ref_score(const int d[5], int cat) {
  uint8_t u[5];
  for (int i = 0; i < 5; i++) u[i] = (uint8_t)d[i];
  return score_cat(u, cat);
}
static bool now(const int d[5], const bool o[12], int c) { return o[c] && ref_score(d, c) > 0; }

static bool ref_satisfied(const int d[5], const bool o[12]) {
  if (now(d, o, 11) || now(d, o, 9) || now(d, o, 6) || (now(d, o, 8) && !o[9])) return true;
  return o[7] && ref_score(d, 7) >= 20;
}

static int ref_pick(const int d[5], const bool o[12]) {
  int bv = -100000, bc = 0;
  for (int c = 0; c < 12; c++) if (o[c] && ref_score(d, c) - EXPECT[c] > bv) { bv = ref_score(d, c) - EXPECT[c]; bc = c; }
  return bc;
}

static void ref_holds(const int d[5], const bool o[12], int h[5]) {
  int c[8] = { 0 }, distinct = 0;
  memset(h, 0, 5 * sizeof(int));
  for (int i = 0; i < 5; i++) c[d[i]]++;
  for (int f = 1; f <= 6; f++) if (c[f]) distinct++;
  if (distinct >= 4 && (o[8] || o[9])) {
    int len = o[9] ? 5 : 4, best = 1, best_n = -1;
    for (int first = 1; first <= 7 - len; first++) {
      int n = 0;
      for (int f = first; f <= first + len - 1; f++) if (c[f]) n += 2;
      for (int s = first; s <= first + len - 4; s++)
        if (c[s] && c[s + 1] && c[s + 2] && c[s + 3]) { n++; break; }
      if (n > best_n) { best = first; best_n = n; }
    }
    for (int f = best; f <= best + len - 1; f++)
      if (c[f]) for (int i = 0; i < 5; i++) if (d[i] == f) { h[i] = 1; break; }
    return;
  }
  if (o[6]) {
    int pairs = 0;
    for (int f = 1; f <= 6; f++) if (c[f] == 2) pairs++;
    if (pairs == 2) {
      for (int i = 0; i < 5; i++) if (c[d[i]] == 2) h[i] = 1;
      return;
    }
  }
  int bw = 0, bf = 0;
  for (int f = 1; f <= 6; f++) if (c[f]) {
    int w = c[f] * 8 + f + (o[f - 1] ? 6 : 0);
    if (w > bw) { bw = w; bf = f; }
  }
  if (c[bf] >= 2 || bf >= 5) for (int i = 0; i < 5; i++) if (d[i] == bf) h[i] = 1;
}

static uint64_t lcg = 4321;
static int rnd(int n) { lcg = (lcg * 1103515245ull + 12345ull) % 2147483648ull; return (int)((lcg / 65536) % (uint64_t)n); }

static void check_case(const int d[5], const bool o[12], const char *label) {
  uint8_t u[5], held[5];
  int want[5];
  for (int i = 0; i < 5; i++) u[i] = (uint8_t)d[i];
  skipper_holds(u, o, held);
  ref_holds(d, o, want);
  for (int i = 0; i < 5; i++)
    CHECK(held[i] == want[i], "%s dice %d%d%d%d%d: hold die %d = %d, want %d", label, d[0], d[1], d[2], d[3], d[4], i, held[i], want[i]);
  CHECK(skipper_pick(u, o) == ref_pick(d, o), "%s dice %d%d%d%d%d: picked %d, want %d", label, d[0], d[1], d[2], d[3], d[4], skipper_pick(u, o), ref_pick(d, o));
  CHECK(skipper_satisfied(u, o) == ref_satisfied(d, o), "%s dice %d%d%d%d%d: satisfied wrong", label, d[0], d[1], d[2], d[3], d[4]);
}

int main(void) {
  bool all[12], only[12];
  for (int c = 0; c < 12; c++) all[c] = true;
  uint8_t six[5] = { 6, 6, 6, 6, 6 };
  CHECK(skipper_pick(six, all) == CAT_YACHT, "five sixes go in Yacht");
  for (int c = 0; c < 12; c++) only[c] = c == 0;
  uint8_t st[5] = { 2, 3, 4, 5, 6 };
  CHECK(skipper_pick(st, only) == CAT_ONES, "only Ones open");
  for (int c = 0; c < 12; c++) only[c] = c == 8 || c == 9;
  CHECK(skipper_pick(six, only) == CAT_SMALL, "a tie goes to the first box");
  // 1,3,4,5,6 with both straights open keeps 3-6, the small straight he has
  uint8_t d1[5] = { 1, 3, 4, 5, 6 }, h[5];
  skipper_holds(d1, all, h);
  CHECK(!h[0] && h[1] && h[2] && h[3] && h[4], "1,3,4,5,6 should hold 3-6, got %d%d%d%d%d", h[0], h[1], h[2], h[3], h[4]);
  // a small straight stops him only once the large box is filled
  uint8_t d2[5] = { 1, 2, 3, 4, 6 };
  CHECK(!skipper_satisfied(d2, all), "small straight with Large open: keep rolling");
  bool nolarge[12];
  for (int c = 0; c < 12; c++) nolarge[c] = c != CAT_LARGE;
  CHECK(skipper_satisfied(d2, nolarge), "small straight with Large filled: stop");

  for (int n = 1; n <= 3000; n++) {
    int d[5];
    bool o[12], any = false;
    for (int i = 0; i < 5; i++) d[i] = rnd(6) + 1;
    for (int c = 0; c < 12; c++) { o[c] = rnd(3) > 0; any = any || o[c]; }
    if (!any) o[rnd(12)] = true;
    char label[16];
    snprintf(label, sizeof label, "case %d", n);
    check_case(d, o, label);
  }
  DONE();
}
