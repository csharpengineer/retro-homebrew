// The game state machine, driven frame by frame like the console does.
#include "check.h"
#include <string.h>
#include "../../src/core/game.h"

static app_t A;
static input_t IN;
static event_t LOG[4096];
static int nlog;

// One frame with the given new presses on controllers 1 and 2.
static void frame2(uint16_t p1, uint16_t p2) {
  IN.new1 = p1; IN.new2 = p2;
  IN.held1 = p1; IN.held2 = p2;
  app_frame(&A, &IN);
  for (int i = 0; i < A.nev && nlog < 4096; i++) LOG[nlog++] = A.ev[i];
  A.nev = 0;
}
static void frame(uint16_t p1) { frame2(p1, 0); }
static void wait(int n) { while (n--) frame(0); }
static void press(uint16_t b) { frame(b); frame(0); }
static bool logged(int type, int a) {
  for (int i = 0; i < nlog; i++) if (LOG[i].type == type && LOG[i].a == a) return true;
  return false;
}
static bool status_is(int line, const char *s) { return strcmp(A.game.status[line], s) == 0; }

static bool wait_until(bool (*fn)(void), int max) {
  for (int i = 0; i < max; i++) { if (fn()) return true; frame(0); }
  return fn();
}
static bool human_waiting(void) {
  return A.screen == SCREEN_GAME && !A.game.over && !player_is_ai(&A.game, A.game.cur) &&
         A.game.tumble_t == 0 && (status_is(0, "PRESS A") || status_is(0, "A: HOLD") || status_is(0, "PICK A BOX"));
}
static bool on_title(void) { return A.screen == SCREEN_TITLE && !A.title.leaving; }
static bool game_over_shown(void) { return A.screen == SCREEN_GAME && A.game.over; }
static bool human_or_over(void) { return human_waiting() || game_over_shown(); }

// From power-on: pick a menu line (0 Skipper, 1 two players, 2 demo) with a fixed seed.
static void start_game(int line, uint16_t seed) {
  app_init(&A, 0, false, 0);
  memset(&IN, 0, sizeof IN);
  nlog = 0;
  A.test_seed = seed;
  wait(30);
  for (int i = 0; i < line; i++) press(BTN_DOWN);
  press(BTN_A);
  for (int i = 0; i < 40 && A.screen != SCREEN_GAME; i++) frame(0);
}

// The SNES demo boards for these seeds, recorded from snes/yacht/build/yacht.sfc in Mesen.
static const struct { uint16_t seed; int16_t s[2][12]; } GOLDEN[] = {
  { 0x1234, { { 1, 4, 0, 12, 0, 12, 26, 20, 30, 40, 24, 0 }, { 3, 6, 9, 8, 0, 18, 28, 8, 30, 40, 23, 0 } } },
  { 0x0042, { { 2, 4, 3, 12, 10, 24, 7, 24, 30, 0, 21, 0 }, { 1, 2, 3, 12, 10, 18, 19, 0, 30, 40, 22, 0 } } },
  { 0xBEEF, { { 1, 2, 0, 8, 15, 0, 24, 12, 30, 40, 23, 0 }, { 1, 0, 3, 0, 10, 12, 21, 0, 30, 40, 21, 0 } } },
  { 0x7777, { { 2, 4, 3, 8, 15, 18, 26, 8, 30, 40, 23, 0 }, { 1, 4, 6, 16, 15, 18, 22, 24, 30, 40, 25, 0 } } },
  { 0x0001, { { 2, 8, 3, 0, 0, 18, 19, 24, 30, 40, 29, 0 }, { 2, 2, 9, 12, 10, 12, 22, 24, 30, 0, 16, 0 } } },
};

static void test_demo_matches_snes(void) {
  for (unsigned k = 0; k < sizeof GOLDEN / sizeof GOLDEN[0]; k++) {
    start_game(2, GOLDEN[k].seed);
    CHECK(A.game.mode == MODE_DEMO, "line 2 is the demo");
    int scored_tunes = 0;
    for (int f = 0; f < 40000 && !A.game.over; f++) {
      int before = nlog;
      frame(0);
      // every score gets its sound: 0 is the bad tune, the special boxes speak
      for (int i = before; i < nlog; i++) {
        if (LOG[i].type != EV_TUNE || A.game.over) continue;
        int cat = A.game.last_cat, s = A.game.last_score, t = LOG[i].a;
        scored_tunes++;
        if (s == 0) CHECK(t == TUNE_BAD, "zero score should play the bad tune");
        else if (cat == CAT_YACHT) CHECK(t == TUNE_YACHT, "yacht tune");
        else if (cat == CAT_FULL || cat == CAT_FOUR || cat == CAT_SMALL || cat == CAT_LARGE) CHECK(t == TUNE_GOOD, "good tune for box %d", cat);
        else CHECK(t == TUNE_SCORE, "score tune for box %d", cat);
      }
    }
    CHECK(A.game.over, "demo %04X finished", GOLDEN[k].seed);
    CHECK(scored_tunes == 24, "demo %04X: %d score sounds, want 24", GOLDEN[k].seed, scored_tunes);
    for (int p = 0; p < 2; p++) for (int c = 0; c < 12; c++)
      CHECK(A.game.scores[p][c] == GOLDEN[k].s[p][c], "demo %04X player %d box %d: %d, SNES had %d",
            GOLDEN[k].seed, p, c, A.game.scores[p][c], GOLDEN[k].s[p][c]);
    CHECK(A.best == 0, "the demo must not set the best score");
    CHECK(wait_until(on_title, 600), "demo returns to the title by itself");
  }
}

static void test_controls(void) {
  start_game(0, 0x1234);
  CHECK(A.game.mode == MODE_SKIPPER, "line 0 plays the Skipper");
  CHECK(wait_until(human_waiting, 200), "first human turn");
  CHECK(status_is(0, "PRESS A") && status_is(1, "TO ROLL"), "roll prompt");
  CHECK(!strcmp(A.game.banner, "YOUR TURN"), "banner says YOUR TURN");
  press(BTN_DOWN);
  CHECK(A.game.focus == 0, "Down before the first roll stays on the dice");
  press(BTN_A);
  wait_until(human_waiting, 100);
  CHECK(A.game.rolls_left == 2, "A made the first roll");
  CHECK(status_is(0, "A: HOLD") && status_is(1, "Z: ROLL"), "status after a roll");
  for (int i = 0; i < 5; i++) CHECK(A.game.dice[i] >= 1 && A.game.dice[i] <= 6, "die %d rolled", i);
  press(BTN_A);
  CHECK(A.game.held[0] == 1 && A.game.rolls_left == 2, "A holds instead of rolling");
  press(BTN_A);
  CHECK(A.game.held[0] == 0, "A again releases");
  press(BTN_RIGHT);
  press(BTN_A);
  CHECK(A.game.die_sel == 1 && A.game.held[1] == 1, "Right then A holds die 2");
  press(BTN_LEFT); press(BTN_LEFT);
  CHECK(A.game.die_sel == 4, "Left wraps round");
  int kept = A.game.dice[1];
  press(BTN_Z);
  wait_until(human_waiting, 100);
  CHECK(A.game.rolls_left == 1 && A.game.dice[1] == kept && A.game.held[1], "Z rolls and the held die stays");
  press(BTN_DOWN);
  CHECK(A.game.focus == 1 && status_is(0, "PICK A BOX") && status_is(2, "B: BACK"), "card offers B back");
  int c0 = A.game.cursor;
  press(BTN_DOWN);
  CHECK(A.game.cursor == c0 + 1, "Down moves the card cursor");
  press(BTN_UP); press(BTN_UP);
  CHECK(A.game.cursor == 11, "Up wraps to Yacht");
  press(BTN_B);
  CHECK(A.game.focus == 0, "B goes back to the dice");
  press(BTN_R);
  wait_until(human_waiting, 100);
  CHECK(A.game.rolls_left == 0 && A.game.focus == 1, "last roll moves to the card");
  CHECK(status_is(2, ""), "no B: BACK with no rolls left");
  press(BTN_B);
  CHECK(A.game.focus == 1, "B does nothing with no rolls left");
  press(BTN_A);   // focus is still card; A here holds nothing: it scores
  CHECK(A.game.scores[0][11] != EMPTY, "A scored the box under the cursor");
  CHECK(wait_until(human_waiting, 3000), "the Skipper played and it's our turn again");
  CHECK(A.game.cur == 0, "back to player 1");
  int filled = 0;
  for (int c = 0; c < 12; c++) filled += A.game.scores[1][c] != EMPTY;
  CHECK(filled == 1, "the Skipper scored one box");
}

static void test_pause(void) {
  start_game(0, 0x0042);
  wait_until(human_waiting, 200);
  press(BTN_START);
  CHECK(A.game.paused && A.bright == 7 && status_is(0, "PAUSED"), "Start pauses");
  nlog = 0;
  press(BTN_A);
  CHECK(A.muted && logged(EV_SAVE, 0) && status_is(2, "A: SOUND OFF"), "A in the pause turns the sound off and saves");
  press(BTN_A);
  CHECK(!A.muted, "and on again");
  press(BTN_START);
  CHECK(!A.game.paused && A.bright == 15 && status_is(0, "PRESS A"), "Start resumes");
  press(BTN_START);
  press(BTN_B);
  CHECK(wait_until(on_title, 100), "B in the pause quits to the title");
  CHECK(A.best == 0, "quitting doesn't touch the best score");
}

// Plays a whole game for the humans, always scoring the first open box.
static void play_out(void) {
  for (int guard = 0; guard < 200 && !A.game.over; guard++) {
    if (!wait_until(human_or_over, 4000)) break;
    if (A.game.over) break;
    if (A.game.rolls_left == 3) { press(BTN_A); wait_until(human_waiting, 100); }
    if (A.game.focus == 0) press(BTN_DOWN);
    press(BTN_A);
  }
  wait_until(game_over_shown, 4000);
}

static void test_full_game_vs_skipper(void) {
  start_game(0, 0xBEEF);
  play_out();
  CHECK(A.game.over, "game over reached");
  CHECK(A.best == player_total(&A.game, 0), "best is the human's total (%d vs %d)", A.best, player_total(&A.game, 0));
  CHECK(logged(EV_SAVE, 0), "a new best is saved");
  int want = A.game.tot[0] > A.game.tot[1] ? V_YOUWIN : A.game.tot[0] < A.game.tot[1] ? V_SKIPPER : V_TIE;
  wait(5);
  CHECK(logged(EV_VOICE, want), "the result is spoken");
  press(BTN_A);
  CHECK(A.game.over && A.screen == SCREEN_GAME, "A is locked out for a moment");
  wait(40);
  press(BTN_A);
  CHECK(wait_until(on_title, 100), "A returns to the title");
}

static void test_two_players(void) {
  // with controller 2 plugged in, player 2 plays only on it
  start_game(1, 0x7777);
  IN.p2_present = true;
  CHECK(A.game.mode == MODE_TWO, "line 1 is two players");
  wait_until(human_waiting, 200);
  CHECK(!strcmp(A.game.banner, "PLAYER 1"), "banner PLAYER 1");
  frame2(0, BTN_A); frame(0);
  CHECK(A.game.rolls_left == 3, "controller 2 can't roll for player 1");
  press(BTN_A); wait_until(human_waiting, 100);
  press(BTN_DOWN); press(BTN_A);
  wait_until(human_waiting, 600);
  CHECK(A.game.cur == 1 && !strcmp(A.game.banner, "PLAYER 2"), "player 2's turn");
  press(BTN_A);
  CHECK(A.game.rolls_left == 3, "controller 1 can't roll for player 2");
  frame2(0, BTN_A); frame(0);
  wait_until(human_waiting, 100);
  CHECK(A.game.rolls_left == 2, "controller 2 rolls for player 2");
  // without it, controller 1 plays both
  start_game(1, 0x7777);
  IN.p2_present = false;
  wait_until(human_waiting, 200);
  press(BTN_A); wait_until(human_waiting, 100);
  press(BTN_DOWN); press(BTN_A);
  wait_until(human_waiting, 600);
  CHECK(A.game.cur == 1, "player 2's turn");
  press(BTN_A); wait_until(human_waiting, 100);
  CHECK(A.game.rolls_left == 2, "controller 1 rolls for player 2 when alone");
  // two players: the best is the higher total
  play_out();
  int hi = A.game.tot[0] > A.game.tot[1] ? A.game.tot[0] : A.game.tot[1];
  CHECK(A.best == hi, "two-player best is the higher total");
}

static void test_title(void) {
  app_init(&A, 77, false, 0);
  memset(&IN, 0, sizeof IN);
  nlog = 0;
  for (int i = 0; i < A.nev; i++) LOG[nlog++] = A.ev[i];
  A.nev = 0;
  CHECK(logged(EV_TUNE, TUNE_TITLE) && logged(EV_VOICE, V_WELCOME), "title tune and welcome at power-on");
  press(BTN_UP);
  CHECK(A.title.sel == MENU_SOUND, "Up wraps to the sound line");
  nlog = 0;
  press(BTN_A);
  CHECK(A.muted && logged(EV_SAVE, 0) && A.screen == SCREEN_TITLE, "A on the sound line toggles it and stays");
  press(BTN_A);
  CHECK(!A.muted, "and back on");
  // idle for 20 seconds starts the demo
  for (int i = 0; i < 1300 && A.screen == SCREEN_TITLE; i++) frame(0);
  CHECK(A.screen == SCREEN_GAME && A.game.mode == MODE_DEMO, "idle title starts the demo");
  // any button in the demo returns to the title, without the welcome again
  wait(60);
  nlog = 0;
  press(BTN_B);
  CHECK(wait_until(on_title, 400), "a button ends the demo");
  CHECK(!logged(EV_VOICE, V_WELCOME), "welcome only on the first visit");
  CHECK(A.best == 77, "best score kept");
}

static void test_selftest(void) {
  app_init(&A, 0, false, BTN_L | BTN_R);
  CHECK(A.screen == SCREEN_SELFTEST && A.selftest.run == 23 && A.selftest.failed == 0, "L+R at power-on runs the self test");
  app_init(&A, 0, false, BTN_L);
  CHECK(A.screen == SCREEN_TITLE, "L alone goes to the title");
}

int main(void) {
  test_demo_matches_snes();
  test_controls();
  test_pause();
  test_full_game_vs_skipper();
  test_two_players();
  test_title();
  test_selftest();
  DONE();
}
