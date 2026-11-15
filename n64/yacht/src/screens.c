#include "screens.h"
#include "gfx.h"
#include "dice3d.h"
#include "gen/layout.h"
#include "gen/title_layout.h"
#include <math.h>
#include <stdio.h>

// ---------------------------------------------------------------- title

static const char *const MENU[MENU_LINES] = { "PLAY THE SKIPPER", "TWO PLAYERS", "WATCH A DEMO", NULL };

static void draw_title(const app_t *a, uint32_t t) {
  draw_backdrop(art.title_bg);
  // wave crests: farther rows are slower and fainter
  for (int row = 0; row < 6; row++) {
    int y = TITLE_HORIZON + 6 + row * row * 3 + row * 6;
    float speed = 0.15f + row * 0.18f;
    int off = (int)(t * speed) % 64;
    int alpha = 60 + row * 30;
    for (int x = -off - (row & 1) * 23; x < 320; x += 64) draw_sprite(art.wave, x, y, alpha);
  }
  // glints on the sun's path
  for (int i = 0; i < 5; i++) {
    uint32_t phase = (t / 9 + i * 7) % 11;
    if (phase > 3) continue;
    int sx = TITLE_SUN_X - 20 + (int)((i * 37 + t / 9 * 13) % 40);
    int sy = TITLE_HORIZON + 8 + (int)((i * 23 + t / 9 * 5) % 60);
    draw_sprite(art.sparkle, sx - 3, sy - 3, 255 - (int)phase * 60);
  }
  // the boat, rocking on the swell
  float bob = sinf(t * 0.045f) * 2.2f;
  draw_sprite(art.boat, 4, 96 + bob, 255);
  // two gulls crossing the sky
  for (int i = 0; i < 2; i++) {
    int gx = (int)((t * (0.35f + 0.1f * i) + i * 170)) % 400 - 40;
    int gy = 52 + i * 18 + (int)(sinf(t * 0.03f + i) * 4);
    draw_sprite_part(art.gull, gx, gy, ((t / 10 + i) & 1) * 16, 0, 16, 10, 255);
  }
  draw_sprite(art.logo, 40, 10 + sinf(t * 0.03f) * 1.5f, 255);

  // the menu on a dark panel
  fill_box(84, 134, 152, 74, RGBA32(8, 10, 30, 160));
  for (int i = 0; i < MENU_LINES; i++) {
    char buf[20];
    const char *s = MENU[i];
    if (!s) { snprintf(buf, sizeof buf, "SOUND: %s", a->muted ? "OFF" : "ON"); s = buf; }
    text(108, 139 + i * 17, s, i == a->title.sel ? C_GOLD : C_CREAM, false, ALIGN_LEFT);
  }
  float cb = ((t >> 4) & 1) ? -1 : 0;
  draw_sprite(art.mini_die, 89, 138 + a->title.sel * 17 + cb, 255);
  char best[24];
  snprintf(best, sizeof best, "BEST SCORE  %d", a->best);
  text(160, 212, best, C_SEA, false, ALIGN_CENTER);
  text(14, 222, VERSION_STR, RGBA32(160, 170, 210, 255), false, ALIGN_LEFT);
}

// ---------------------------------------------------------------- game

static void draw_card(const game_t *g) {
  int cx[2] = { CARD_RULE_M - 4, CARD_X + CARD_W - 7 };   // right edges of the score columns
  int name_x[2] = { (CARD_RULE_L + CARD_RULE_M) / 2 + 1, (CARD_RULE_M + CARD_X + CARD_W - 4) / 2 };
  bool preview = !g->over && g->rolls_left != 3;
  for (int p = 0; p < 2; p++)
    ink(name_x[p], CARD_Y + 6, player_name(g, p, true), p == g->cur && !g->over ? C_RED_INK : C_INK, ALIGN_CENTER);
  for (int c = 0; c < NUM_CATS; c++) {
    int y = CARD_ROW0 + c * CARD_ROWH;
    if (g->highlight && c == g->cursor) fill_box(CARD_X + 5, y, CARD_W - 10, CARD_ROWH - 1, RGBA32(255, 196, 40, 120));
    ink(CARD_X + 7, y + 1, CAT_NAMES[c], C_INK, ALIGN_LEFT);
    for (int p = 0; p < 2; p++) {
      char n[8];
      int s = g->scores[p][c];
      if (s != EMPTY) {
        snprintf(n, sizeof n, "%d", s);
        ink(cx[p], y + 1, n, C_INK, ALIGN_RIGHT);
      } else if (preview && p == g->cur) {
        snprintf(n, sizeof n, "%d", score_cat(g->dice, c));
        ink(cx[p], y + 1, n, C_RED_INK, ALIGN_RIGHT);
      }
    }
  }
  ink(CARD_X + 7, CARD_TOTAL_Y + 2, "Total", C_INK, ALIGN_LEFT);
  for (int p = 0; p < 2; p++) {
    char n[8];
    snprintf(n, sizeof n, "%d", player_total(g, p));
    ink(cx[p], CARD_TOTAL_Y + 2, n, C_INK, ALIGN_RIGHT);
  }
  if (!g->over) ink(cx[g->cur] - 26, CARD_TOTAL_Y + 2, ">", C_RED_INK, ALIGN_LEFT);
}

static bool human_on_turn(const game_t *g) { return !player_is_ai(g, g->cur); }

static void draw_tray_marks(const game_t *g, uint32_t t) {
  // HOLD tags under held dice
  for (int i = 0; i < 5; i++)
    if (g->held[i] && g->dice[i]) text(DIE_X[i], DIE_Y[i] + 19, "HOLD", C_GOLD, false, ALIGN_CENTER);
  // the die selector: gold corner brackets, while a human can hold
  if (human_on_turn(g) && g->focus == 0 && g->rolls_left != 3 && g->rolls_left != 0 && !g->tumble_t && !g->over) {
    int x = DIE_X[g->die_sel], y = DIE_Y[g->die_sel] - (g->held[g->die_sel] ? 4 : 0);
    int r = 19 + ((t >> 3) & 1);
    color_t c = C_GOLD;
    fill_box(x - r, y - r, 7, 2, c); fill_box(x - r, y - r, 2, 7, c);
    fill_box(x + r - 7, y - r, 7, 2, c); fill_box(x + r - 2, y - r, 2, 7, c);
    fill_box(x - r, y + r - 2, 7, 2, c); fill_box(x - r, y + r - 7, 2, 7, c);
    fill_box(x + r - 7, y + r - 2, 7, 2, c); fill_box(x + r - 2, y + r - 7, 2, 7, c);
  }
}

static void draw_side(const game_t *g) {
  text(BANNER_X + BANNER_W / 2, BANNER_Y + 2, g->banner, C_GOLD, true, ALIGN_CENTER);
  text(ROLLS_X + 10, ROLLS_Y + 5, "ROLLS", C_CREAM, false, ALIGN_LEFT);
  int left = g->rolls_left == 3 && !g->tumble_t ? 3 : g->rolls_left;
  for (int i = 0; i < 3; i++) draw_sprite(art.mini_die, ROLLS_X + 62 + i * 22, ROLLS_Y + 3, i < left ? 255 : 60);
  static const color_t LINE[3] = { C_WHITE, C_CREAM, C_SEA };
  for (int i = 0; i < 3; i++)
    text(STATUS_X + STATUS_W / 2, STATUS_Y + 4 + i * 14, g->status[i], LINE[i], false, ALIGN_CENTER);
}

static void draw_game_over(const app_t *a) {
  const game_t *g = &a->game;
  fill_box(0, 0, 320, 240, RGBA32(0, 0, 0, 140));
  fill_box(48, 26, 224, 188, RGBA32(10, 16, 44, 240));
  fill_box(48, 26, 224, 2, C_GOLD);
  fill_box(48, 212, 224, 2, C_GOLD);
  text(160, 36, "GAME OVER", C_GOLD, true, ALIGN_CENTER);
  for (int p = 0; p < 2; p++) {
    char n[8];
    snprintf(n, sizeof n, "%d", g->tot[p]);
    text(80, 78 + p * 18, player_name(g, p, false), C_CREAM, false, ALIGN_LEFT);
    text(240, 78 + p * 18, n, C_WHITE, false, ALIGN_RIGHT);
  }
  const char *msg;
  if (g->result == RESULT_TIE) msg = "A TIE!";
  else if (g->result == RESULT_P0) msg = g->mode == MODE_SKIPPER ? "YOU WIN!" : "PLAYER 1 WINS!";
  else msg = g->mode == MODE_SKIPPER ? "THE SKIPPER WINS" : "PLAYER 2 WINS!";
  text(160, 122, msg, C_GREEN, true, ALIGN_CENTER);
  char best[24];
  snprintf(best, sizeof best, "BEST SCORE  %d", a->best);
  text(160, 160, best, C_SEA, false, ALIGN_CENTER);
  if (g->mode != MODE_DEMO) text(160, 186, "PRESS A", C_WHITE, false, ALIGN_CENTER);
}

static void draw_game(const app_t *a, uint32_t t) {
  const game_t *g = &a->game;
  draw_backdrop(art.game_bg);
  draw_card(g);
  draw_side(g);
  dice_draw(g, t);
  draw_tray_marks(g, t);
  if (g->over) draw_game_over(a);
}

// ---------------------------------------------------------------- self test

static void draw_selftest(const app_t *a) {
  rdpq_set_mode_fill(RGBA32(12, 18, 48, 255));
  rdpq_fill_rectangle(0, 0, 320, 240);
  char run[24], failed[24];
  snprintf(run, sizeof run, "%d CHECKS RUN", a->selftest.run);
  snprintf(failed, sizeof failed, "%d FAILED", a->selftest.failed);
  text(160, 60, "YACHT  SELF TEST", C_GOLD, true, ALIGN_CENTER);
  text(160, 110, run, C_CREAM, false, ALIGN_CENTER);
  text(160, 130, failed, a->selftest.failed ? C_RED : C_GREEN, false, ALIGN_CENTER);
  text(160, 200, VERSION_STR, RGBA32(160, 170, 210, 255), false, ALIGN_CENTER);
}

void draw_frame(const app_t *a, uint32_t t) {
  switch (a->screen) {
    case SCREEN_TITLE: draw_title(a, t); break;
    case SCREEN_GAME: draw_game(a, t); break;
    default: draw_selftest(a); break;
  }
  fade_screen(a->bright);
}
