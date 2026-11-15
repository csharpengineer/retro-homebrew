#include "game.h"
#include "skipper.h"
#include <stdio.h>
#include <string.h>

enum { P_FADEIN, P_HUMAN, P_ROLL, P_AI, P_SCORED, P_PAUSE, P_OVER, P_FADEOUT };
enum { AI_ROLL, AI_AFTER_ROLL, AI_SCORE };

#define VOICE_WAIT_MAX 360

static void emit(app_t *a, int type, int x, int y) {
  if (a->nev < MAX_EVENTS) a->ev[a->nev++] = (event_t){ (uint8_t)type, (uint8_t)x, (uint8_t)y };
}

static void status(game_t *g, const char *l1, const char *l2, const char *l3) {
  snprintf(g->status[0], sizeof g->status[0], "%s", l1);
  snprintf(g->status[1], sizeof g->status[1], "%s", l2);
  snprintf(g->status[2], sizeof g->status[2], "%s", l3);
}

bool player_is_ai(const game_t *g, int p) {
  return g->mode == MODE_DEMO || (g->mode == MODE_SKIPPER && p == 1);
}

const char *player_name(const game_t *g, int p, bool short_name) {
  if (g->mode == MODE_SKIPPER) {
    if (short_name) return p ? "SKP" : "YOU";
    return p ? "THE SKIPPER" : "YOU";
  }
  if (short_name) return p ? "P2" : "P1";
  return p ? "PLAYER 2" : "PLAYER 1";
}

int player_total(const game_t *g, int p) {
  int t = 0;
  for (int c = 0; c < NUM_CATS; c++) if (g->scores[p][c] != EMPTY) t += g->scores[p][c];
  return t;
}

static void open_boxes(const game_t *g, bool open[NUM_CATS]) {
  for (int c = 0; c < NUM_CATS; c++) open[c] = g->scores[g->cur][c] == EMPTY;
}

static int first_open(const game_t *g) {
  for (int c = 0; c < NUM_CATS; c++) if (g->scores[g->cur][c] == EMPTY) return c;
  return 0;
}

// The next open box up (dir -1) or down (+1), wrapping round.
static int next_open(const game_t *g, int from, int dir) {
  int c = from;
  for (int i = 0; i < NUM_CATS; i++) {
    c = (c + dir + NUM_CATS) % NUM_CATS;
    if (g->scores[g->cur][c] == EMPTY) return c;
  }
  return from;
}

static bool board_full(const game_t *g) {
  for (int p = 0; p < 2; p++)
    for (int c = 0; c < NUM_CATS; c++) if (g->scores[p][c] == EMPTY) return false;
  return true;
}

// The controller the player on turn uses (SNES TurnPad): in a two-player game
// player 2 has controller 2 when it is plugged in; otherwise either works.
static uint16_t turn_pad(const game_t *g, const input_t *in) {
  if (g->mode != MODE_TWO) return in->new1 | in->new2;
  if (g->cur == 1 && in->p2_present) return in->new2;
  return in->new1;
}
// The controller to rumble: player 2's in a two-player game, otherwise the
// one the human last pressed.
static int turn_port(const game_t *g, const input_t *in) {
  if (g->mode == MODE_TWO) return g->cur == 1 && in->p2_present ? 1 : 0;
  return g->port;
}

static void human_status(game_t *g) {
  if (g->focus) status(g, "PICK A BOX", "A: SCORE", g->rolls_left ? "B: BACK" : "");
  else if (g->rolls_left == 3) status(g, "PRESS A", "TO ROLL", "");
  else status(g, "A: HOLD", "Z: ROLL", "");
}

static void pause_status(app_t *a) {
  status(&a->game, "PAUSED", "B: QUIT", a->muted ? "A: SOUND OFF" : "A: SOUND ON");
}

static void begin_exit(app_t *a) {
  emit(a, EV_STOP_MUSIC, 0, 0);
  a->game.phase = P_FADEOUT;
  a->bright = 15;
}

static void start_turn(app_t *a) {
  game_t *g = &a->game;
  memset(g->dice, 0, sizeof g->dice);
  memset(g->held, 0, sizeof g->held);
  g->rolls_left = 3;
  g->focus = 0;
  g->die_sel = 0;
  g->cursor = (uint8_t)first_open(g);
  g->highlight = false;
  g->last_cat = -1;
  // the Skipper's turns say SKIPPER, in the demo too (SNES StatusSkipper)
  if (player_is_ai(g, g->cur)) snprintf(g->banner, sizeof g->banner, "SKIPPER");
  else if (g->mode == MODE_SKIPPER) snprintf(g->banner, sizeof g->banner, "YOUR TURN");
  else snprintf(g->banner, sizeof g->banner, "%s", g->cur ? "PLAYER 2" : "PLAYER 1");
  if (player_is_ai(g, g->cur)) {
    status(g, "THE SKIPPER", "IS ROLLING", "");
    g->phase = P_AI;
    g->ai_step = AI_ROLL;
    g->wait = 25;
  } else {
    human_status(g);
    g->phase = P_HUMAN;
  }
}

static void start_roll(app_t *a) {
  game_t *g = &a->game;
  g->rolls_left--;
  emit(a, EV_SFX, SFX_ROLL, 0);
  g->tumble_t = TUMBLE_FRAMES;
  g->tumble_seq++;
  g->roll_ret = g->phase;
  g->phase = P_ROLL;
}

// One frame of tumbling: every fourth frame each loose die gets a fresh face,
// six times in all; the last one stays (SNES RollDice).
static void roll_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  if ((g->tumble_t & 3) == 0)
    for (int i = 0; i < 5; i++) if (!g->held[i]) g->dice[i] = (uint8_t)rng_roll1(&a->rng);
  if (--g->tumble_t) return;
  g->phase = g->roll_ret;
  if (g->phase == P_AI) {
    g->ai_step = AI_AFTER_ROLL;
    g->wait = 41;
    return;
  }
  if (g->mode != MODE_DEMO) emit(a, EV_RUMBLE, turn_port(g, in), 8);
  if (g->rolls_left == 0) { g->focus = 1; g->highlight = true; }
  human_status(g);
}

static void apply_score(app_t *a, int cat) {
  game_t *g = &a->game;
  int s = score_cat(g->dice, cat);
  g->scores[g->cur][cat] = (int16_t)s;
  g->highlight = false;
  g->rolls_left = 3;
  g->last_cat = (int8_t)cat;
  g->last_score = (int16_t)s;
  char line[16];
  snprintf(line, sizeof line, "+ %d", s);
  status(g, CAT_NAMES[cat], line, "");
  g->phase = P_SCORED;
  g->ai_step = 0;
  g->wait = 0;
}

// The reaction to a score: a tune and, for the special boxes, a voice line.
static void score_sound(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  int cat = g->last_cat, s = g->last_score;
  if (s == 0) { emit(a, EV_TUNE, TUNE_BAD, 0); return; }
  switch (cat) {
    case CAT_YACHT:
      emit(a, EV_TUNE, TUNE_YACHT, 0);
      emit(a, EV_VOICE, V_YACHT, 0);
      if (!player_is_ai(g, g->cur)) emit(a, EV_RUMBLE, turn_port(g, in), 40);
      break;
    case CAT_FULL: emit(a, EV_TUNE, TUNE_GOOD, 0); emit(a, EV_VOICE, V_FULL, 0); break;
    case CAT_FOUR: emit(a, EV_TUNE, TUNE_GOOD, 0); emit(a, EV_VOICE, V_FOUR, 0); break;
    case CAT_SMALL:
    case CAT_LARGE: emit(a, EV_TUNE, TUNE_GOOD, 0); emit(a, EV_VOICE, V_STRAIGHT, 0); break;
    default: emit(a, EV_TUNE, TUNE_SCORE, 0); break;
  }
}

static void game_over(app_t *a) {
  game_t *g = &a->game;
  g->tot[0] = (int16_t)player_total(g, 0);
  g->tot[1] = (int16_t)player_total(g, 1);
  // best score: human totals only, never the demo
  if (g->mode != MODE_DEMO) {
    int t = g->mode == MODE_SKIPPER ? g->tot[0] : (g->tot[0] > g->tot[1] ? g->tot[0] : g->tot[1]);
    if (t > a->best) { a->best = (uint16_t)t; emit(a, EV_SAVE, 0, 0); }
  }
  g->result = g->tot[0] == g->tot[1] ? RESULT_TIE : g->tot[0] > g->tot[1] ? RESULT_P0 : RESULT_P1;
  g->over = true;
  g->phase = P_OVER;
  g->ai_step = 0;
  g->wait = 0;
}

static void game_over_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  switch (g->ai_step) {
    case 0: case 1: g->ai_step++; return;   // the screen shows before the sound starts
    case 2: {
      int tune, voice;
      if (g->result == RESULT_TIE) { tune = TUNE_GOOD; voice = V_TIE; }
      else if (g->result == RESULT_P0) { tune = TUNE_WIN; voice = g->mode == MODE_SKIPPER ? V_YOUWIN : V_P1WINS; }
      else if (g->mode == MODE_SKIPPER) { tune = TUNE_LOSE; voice = V_SKIPPER; }
      else { tune = TUNE_WIN; voice = V_P2WINS; }
      emit(a, EV_TUNE, tune, 0);
      emit(a, EV_VOICE, voice, 0);
      g->wait = g->mode == MODE_DEMO ? 330 : 30;
      g->ai_step = 3;
      return;
    }
    default:
      if (g->mode == MODE_DEMO) {
        if (g->quit || --g->wait <= 0) begin_exit(a);
        return;
      }
      if (g->wait > 0) { g->wait--; return; }
      if ((in->new1 | in->new2) & (BTN_A | BTN_START)) begin_exit(a);
  }
}

static void after_score(app_t *a) {
  game_t *g = &a->game;
  if (board_full(g)) { game_over(a); return; }
  g->cur ^= 1;
  start_turn(a);
}

static void human_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  uint16_t pad = turn_pad(g, in);
  if (g->mode != MODE_TWO && (in->new1 | in->new2)) g->port = in->new1 ? 0 : 1;
  if (pad & BTN_START) {
    g->paused = true;
    a->bright = 7;
    pause_status(a);
    g->phase = P_PAUSE;
    return;
  }
  if (g->focus == 0) {
    if (pad & (BTN_Z | BTN_R)) {
      if (g->rolls_left) start_roll(a);
    } else if (pad & BTN_A) {
      if (g->rolls_left == 3) start_roll(a);
      else if (g->rolls_left) {   // holding is refused before the first roll and after the last
        g->held[g->die_sel] ^= 1;
        emit(a, EV_SFX, SFX_HOLD, 0);
      }
    } else if (pad & BTN_LEFT) {
      g->die_sel = (uint8_t)((g->die_sel + 4) % 5);
      emit(a, EV_SFX, SFX_TICK, 0);
    } else if (pad & BTN_RIGHT) {
      g->die_sel = (uint8_t)((g->die_sel + 1) % 5);
      emit(a, EV_SFX, SFX_TICK, 0);
    } else if (pad & (BTN_UP | BTN_DOWN)) {
      if (g->rolls_left != 3) { g->focus = 1; g->highlight = true; human_status(g); }
    }
    return;
  }
  if (pad & BTN_UP) {
    g->cursor = (uint8_t)next_open(g, g->cursor, -1);
    emit(a, EV_SFX, SFX_TICK, 0);
  } else if (pad & BTN_DOWN) {
    g->cursor = (uint8_t)next_open(g, g->cursor, 1);
    emit(a, EV_SFX, SFX_TICK, 0);
  } else if (pad & BTN_B) {
    if (g->rolls_left) { g->focus = 0; g->highlight = false; human_status(g); }
  } else if (pad & BTN_A) {
    apply_score(a, g->cursor);
  }
}

static void ai_frame(app_t *a) {
  game_t *g = &a->game;
  if (g->quit) { begin_exit(a); return; }
  if (g->wait > 0) { g->wait--; return; }
  bool open[NUM_CATS];
  open_boxes(g, open);
  switch (g->ai_step) {
    case AI_ROLL: start_roll(a); break;
    case AI_AFTER_ROLL:
      if (g->rolls_left == 0 || skipper_satisfied(g->dice, open)) {
        g->cursor = (uint8_t)skipper_pick(g->dice, open);
        g->highlight = true;
        g->wait = 33;
        g->ai_step = AI_SCORE;
      } else {
        skipper_holds(g->dice, open, g->held);
        emit(a, EV_SFX, SFX_HOLD, 0);
        g->wait = 37;
        g->ai_step = AI_ROLL;
      }
      break;
    case AI_SCORE: apply_score(a, g->cursor); break;
  }
}

static void scored_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  if (g->quit) { begin_exit(a); return; }
  switch (g->ai_step) {
    case 0:   // the score shows for a frame, then the sound starts
      score_sound(a, in);
      g->wait = 58;
      g->ai_step = 1;
      break;
    case 1:
      if (--g->wait > 0) break;
      g->voice_wait = VOICE_WAIT_MAX;
      g->ai_step = 2;
      break;
    default:
      if (in->voice_busy && --g->voice_wait > 0) break;
      after_score(a);
  }
}

static void pause_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  uint16_t pad = in->new1 | in->new2;
  if (pad & BTN_START) {
    g->paused = false;
    a->bright = 15;
    human_status(g);
    g->phase = P_HUMAN;
  } else if (pad & BTN_B) {
    g->paused = false;
    begin_exit(a);   // quitting never touches the best score
  } else if (pad & BTN_A) {
    a->muted = !a->muted;
    emit(a, EV_SAVE, 0, 0);
    emit(a, EV_SFX, SFX_TICK, 0);
    pause_status(a);
  }
}

static void game_frame(app_t *a, const input_t *in) {
  game_t *g = &a->game;
  if (g->mode == MODE_DEMO && (in->new1 | in->new2) && g->phase != P_FADEIN && g->phase != P_FADEOUT)
    g->quit = true;
  switch (g->phase) {
    case P_FADEIN:
      if (a->bright < 15) { a->bright++; break; }
      start_turn(a);
      break;
    case P_HUMAN: human_frame(a, in); break;
    case P_ROLL:
      roll_frame(a, in);
      if (g->phase == P_AI && g->quit) begin_exit(a);
      break;
    case P_AI: ai_frame(a); break;
    case P_SCORED: scored_frame(a, in); break;
    case P_PAUSE: pause_frame(a, in); break;
    case P_OVER: game_over_frame(a, in); break;
    case P_FADEOUT:
      if (a->bright > 0) a->bright--;
      else g->done = true;
      break;
  }
}

static void game_start(app_t *a, int mode) {
  game_t *g = &a->game;
  memset(g, 0, sizeof *g);
  g->mode = (uint8_t)mode;
  for (int p = 0; p < 2; p++) for (int c = 0; c < NUM_CATS; c++) g->scores[p][c] = EMPTY;
  g->last_cat = -1;
  g->phase = P_FADEIN;
  a->bright = 0;
  a->screen = SCREEN_GAME;
}

// ---------------------------------------------------------------- title

static const uint8_t MENU_MODE[3] = { MODE_SKIPPER, MODE_TWO, MODE_DEMO };

static void title_enter(app_t *a) {
  memset(&a->title, 0, sizeof a->title);
  a->screen = SCREEN_TITLE;
  a->bright = 0;
  emit(a, EV_TUNE, TUNE_TITLE, 0);
  if (!a->welcomed) {          // only on the first visit, even when the sound is off
    a->welcomed = true;
    emit(a, EV_VOICE, V_WELCOME, 0);
  }
}

static void title_frame(app_t *a, const input_t *in) {
  title_t *t = &a->title;
  if (t->leaving) {
    if (a->bright > 0) { a->bright--; return; }
    emit(a, EV_STOP_MUSIC, 0, 0);
    uint16_t seed = a->test_seed ? a->test_seed : (uint16_t)(a->entropy ^ a->frame);
    a->rng.seed = seed ? seed : 1234;
    game_start(a, t->choice);
    return;
  }
  a->bright = t->t < 15 ? (uint8_t)t->t : 15;
  t->t++;
  uint16_t held = in->held1 | in->held2;
  uint32_t e = (uint32_t)a->entropy + held;
  a->entropy = (uint16_t)(e + a->frame + (e >> 16));
  if (held) t->idle = 0;
  else if (++t->idle >= TITLE_IDLE_FRAMES) { t->choice = MODE_DEMO; t->leaving = true; return; }
  uint16_t pad = in->new1 | in->new2;
  if (pad & BTN_UP) {
    t->sel = (uint8_t)((t->sel + MENU_LINES - 1) % MENU_LINES);
    emit(a, EV_SFX, SFX_TICK, 0);
  } else if (pad & BTN_DOWN) {
    t->sel = (uint8_t)((t->sel + 1) % MENU_LINES);
    emit(a, EV_SFX, SFX_TICK, 0);
  } else if (pad & (BTN_A | BTN_START)) {
    if (t->sel == MENU_SOUND) {
      a->muted = !a->muted;
      emit(a, EV_SAVE, 0, 0);
      emit(a, EV_SFX, SFX_TICK, 0);
    } else {
      t->choice = MENU_MODE[t->sel];
      emit(a, EV_SFX, SFX_SELECT, 0);
      t->leaving = true;
    }
  }
}

// ---------------------------------------------------------------- self test

// The scoring cases of YACHT /T (Tandy game.asm selftest), with the straight
// cases redone for the SNES v1.1 straights.
static const struct { uint8_t d[5]; uint8_t cat; uint8_t want; } CASES[] = {
  { { 1, 1, 2, 3, 4 }, CAT_ONES, 2 },    { { 6, 6, 6, 2, 1 }, CAT_SIXES, 18 },
  { { 3, 3, 3, 5, 5 }, CAT_FULL, 19 },   { { 3, 3, 3, 3, 5 }, CAT_FULL, 0 },
  { { 1, 1, 1, 1, 1 }, CAT_FULL, 0 },    { { 4, 4, 4, 4, 1 }, CAT_FOUR, 16 },
  { { 5, 5, 5, 5, 5 }, CAT_FOUR, 20 },   { { 4, 4, 4, 1, 1 }, CAT_FOUR, 0 },
  { { 1, 2, 3, 4, 5 }, CAT_SMALL, 30 },  { { 3, 4, 1, 6, 5 }, CAT_SMALL, 30 },
  { { 1, 2, 3, 5, 6 }, CAT_SMALL, 0 },   { { 2, 3, 4, 5, 6 }, CAT_LARGE, 40 },
  { { 1, 2, 3, 4, 5 }, CAT_LARGE, 40 },  { { 1, 2, 3, 4, 6 }, CAT_LARGE, 0 },
  { { 1, 3, 5, 2, 6 }, CAT_CHOICE, 17 }, { { 2, 2, 2, 2, 2 }, CAT_YACHT, 50 },
  { { 2, 2, 2, 2, 3 }, CAT_YACHT, 0 },
};

void run_selftest(selftest_t *st) {
  st->run = st->failed = 0;
  for (unsigned i = 0; i < sizeof CASES / sizeof CASES[0]; i++) {
    st->run++;
    if (score_cat(CASES[i].d, CASES[i].cat) != CASES[i].want) st->failed++;
  }
  // the dice: 6000 rolls from seed 1234, each face 880-1120 times
  rng_t r = { 1234 };
  int n[7] = { 0 };
  for (int i = 0; i < 6000; i++) n[rng_roll1(&r)]++;
  for (int f = 1; f <= 6; f++) {
    st->run++;
    if (n[f] < 880 || n[f] > 1120) st->failed++;
  }
}

// ---------------------------------------------------------------- app

void app_init(app_t *a, uint16_t best, bool muted, uint16_t held1) {
  memset(a, 0, sizeof *a);
  a->best = best;
  a->muted = muted;
  if ((held1 & (BTN_L | BTN_R)) == (BTN_L | BTN_R)) {
    a->screen = SCREEN_SELFTEST;
    a->bright = 15;
    run_selftest(&a->selftest);
    return;
  }
  title_enter(a);
}

void app_frame(app_t *a, const input_t *in) {
  a->frame++;
  switch (a->screen) {
    case SCREEN_TITLE: title_frame(a, in); break;
    case SCREEN_GAME:
      game_frame(a, in);
      if (a->game.done) title_enter(a);
      break;
    default: break;
  }
}
