// Scoring and the dice generator, against hand-worked values and the self test.
#include "check.h"
#include "../../src/core/rules.h"
#include "../../src/core/game.h"

static int sc(int a, int b, int c, int d, int e, int cat) {
  uint8_t dice[5] = { (uint8_t)a, (uint8_t)b, (uint8_t)c, (uint8_t)d, (uint8_t)e };
  return score_cat(dice, cat);
}

int main(void) {
  // upper boxes: face x count
  CHECK(sc(1, 1, 2, 3, 4, CAT_ONES) == 2, "ones");
  CHECK(sc(6, 6, 6, 2, 1, CAT_SIXES) == 18, "sixes");
  CHECK(sc(2, 3, 4, 5, 6, CAT_ONES) == 0, "no ones");
  // full house: exactly 3+2, scores the sum; five alike is not one
  CHECK(sc(3, 3, 3, 5, 5, CAT_FULL) == 19, "full house");
  CHECK(sc(5, 3, 5, 3, 3, CAT_FULL) == 19, "full house any order");
  CHECK(sc(3, 3, 3, 3, 5, CAT_FULL) == 0, "four and one");
  CHECK(sc(1, 1, 1, 1, 1, CAT_FULL) == 0, "five alike is no full house");
  // four alike: 4 x face, five alike counts
  CHECK(sc(4, 4, 4, 4, 1, CAT_FOUR) == 16, "four alike");
  CHECK(sc(5, 5, 5, 5, 5, CAT_FOUR) == 20, "five alike counts as four");
  CHECK(sc(4, 4, 4, 1, 1, CAT_FOUR) == 0, "three is not four");
  // straights: small any four in a row (30), large five (40)
  CHECK(sc(1, 2, 3, 4, 6, CAT_SMALL) == 30, "1-4 small");
  CHECK(sc(6, 2, 3, 4, 5, CAT_SMALL) == 30, "2-5 small");
  CHECK(sc(3, 4, 4, 5, 6, CAT_SMALL) == 30, "3-6 small with a pair");
  CHECK(sc(1, 2, 3, 5, 6, CAT_SMALL) == 0, "gap");
  CHECK(sc(2, 3, 4, 5, 6, CAT_LARGE) == 40, "2-6 large");
  CHECK(sc(5, 4, 3, 2, 1, CAT_LARGE) == 40, "1-5 large");
  CHECK(sc(1, 2, 3, 4, 6, CAT_LARGE) == 0, "not five in a row");
  CHECK(sc(1, 3, 5, 2, 6, CAT_CHOICE) == 17, "choice");
  CHECK(sc(2, 2, 2, 2, 2, CAT_YACHT) == 50, "yacht");
  CHECK(sc(2, 2, 2, 2, 3, CAT_YACHT) == 0, "not a yacht");

  // the generator: seed*25173 + 13849 mod 65536
  rng_t r = { 1234 };
  CHECK(rng_next(&r) == (uint16_t)(1234u * 25173u + 13849u), "first value");
  r.seed = 0;
  CHECK(rng_next(&r) == 13849, "from zero");
  r.seed = 0xFFFF;   // r*6 >> 16 + 1 stays within 1-6 at the top of the range
  for (int i = 0; i < 70000; i++) { int f = rng_roll1(&r); if (f < 1 || f > 6) { CHECK(0, "roll %d", f); break; } }

  // the on-screen self test: 23 checks, none failing
  selftest_t st;
  run_selftest(&st);
  CHECK(st.run == 23, "self test runs %d checks", st.run);
  CHECK(st.failed == 0, "self test has %d failures", st.failed);
  DONE();
}
