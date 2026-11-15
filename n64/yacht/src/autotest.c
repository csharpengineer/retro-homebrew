// The emulator test session (built only with -DAUTOTEST). It runs the self
// test, watches a seeded demo game at 8x speed and prints its final board (to
// compare with the SNES), then plays a few human moves against the Skipper,
// photographing each screen. Screenshots go out as hex rows that tests/emu.sh
// turns into PNGs.
#ifdef AUTOTEST
#include "autotest.h"
#include "platform.h"
#include <string.h>

static int step, wait_frames, speed = 1;
static const char *pending;
static bool shot_roll, shot_pick;

static int filled(const game_t *g) {
  int n = 0;
  for (int p = 0; p < 2; p++) for (int c = 0; c < NUM_CATS; c++) n += g->scores[p][c] != EMPTY;
  return n;
}
static bool human_waiting(const app_t *a) {
  const game_t *g = &a->game;
  return a->screen == SCREEN_GAME && !g->over && !player_is_ai(g, g->cur) && !g->tumble_t &&
         (!strcmp(g->status[0], "PRESS A") || !strcmp(g->status[0], "A: HOLD") || !strcmp(g->status[0], "PICK A BOX"));
}
static bool on_title(const app_t *a) { return a->screen == SCREEN_TITLE && !a->title.leaving && a->bright == 15; }

static void press(input_t *in, uint16_t b, int then_wait) { in->new1 = in->held1 = b; wait_frames = then_wait; step++; }

int autotest_input(app_t *a, input_t *in) {
  memset(in, 0, sizeof *in);
  if (wait_frames > 0) { wait_frames--; return speed; }
  switch (step) {
    case 0: {
      selftest_t st;
      run_selftest(&st);
      debugf("SELFTEST run=%d failed=%d\n", st.run, st.failed);
      a->muted = true;                        // the test plays nothing aloud
      audio_capture(TUNE_TITLE, 32000 * 20);   // the title tune as the mixer plays it, past its loop
      wait_frames = 60;
      step++;
      break;
    }
    case 1: pending = "title"; step++; break;
    case 2: a->test_seed = 0x1234; press(in, BTN_DOWN, 3); break;
    case 3: press(in, BTN_DOWN, 3); break;
    case 4: press(in, BTN_A, 0); speed = 8; break;
    case 5:
      if (a->screen == SCREEN_GAME && a->game.over && a->game.ai_step >= 3) {
        char line[160];
        int n = snprintf(line, sizeof line, "BOARD %04X", 0x1234);
        for (int p = 0; p < 2; p++) for (int c = 0; c < NUM_CATS; c++)
          n += snprintf(line + n, sizeof line - n, " %d", a->game.scores[p][c]);
        debugf("%s\n", line);
        pending = "gameover";
        speed = 1;
        step++;
      }
      break;
    case 6: speed = 8; step++; break;
    case 7: if (on_title(a)) { speed = 1; wait_frames = 30; step++; } break;
    case 8: a->test_seed = 0x0042; press(in, BTN_A, 0); break;
    case 9: if (human_waiting(a)) press(in, BTN_A, 0); break;              // first roll
    case 10: if (human_waiting(a)) press(in, BTN_A, 3); break;             // hold die 1
    case 11: press(in, BTN_RIGHT, 3); break;
    case 12: press(in, BTN_RIGHT, 3); break;
    case 13: press(in, BTN_A, 6); break;                                   // hold die 3
    case 14: pending = "hold"; step++; break;
    case 15: press(in, BTN_DOWN, 6); break;                                // to the scorecard
    case 16: pending = "card"; step++; break;
    case 17: press(in, BTN_START, 6); break;
    case 18: pending = "paused"; step++; break;
    case 19: press(in, BTN_B, 0); break;
    case 20: if (on_title(a)) { debugf("AUTOTEST DONE\n"); step++; } break;
    default: break;
  }
  return speed;
}

bool autotest_stop_early(const app_t *a) {
  const game_t *g = &a->game;
  if (step != 5 || a->screen != SCREEN_GAME) return false;
  if (!shot_roll && filled(g) == 6 && g->tumble_t == 10) { shot_roll = true; pending = "demo_roll"; return true; }
  if (!shot_pick && filled(g) >= 15 && g->highlight) { shot_pick = true; pending = "demo_pick"; return true; }
  return false;
}

bool autotest_after_draw(app_t *a, surface_t *disp) {
  (void)a;
  if (!pending) return false;
  rdpq_detach_wait();
  debugf("SHOT %s %d %d\n", pending, disp->width, disp->height);
  static char row[320 * 4 + 2];
  for (int y = 0; y < disp->height; y++) {
    const uint16_t *px = (const uint16_t *)((const uint8_t *)disp->buffer + y * disp->stride);
    for (int x = 0; x < disp->width; x++) {
      static const char HEX[] = "0123456789abcdef";
      uint16_t v = px[x];
      row[x * 4] = HEX[v >> 12]; row[x * 4 + 1] = HEX[(v >> 8) & 15];
      row[x * 4 + 2] = HEX[(v >> 4) & 15]; row[x * 4 + 3] = HEX[v & 15];
    }
    row[disp->width * 4] = '\n';
    row[disp->width * 4 + 1] = 0;
    debugf("R%s", row);
  }
  debugf("ENDSHOT\n");
  pending = NULL;
  display_show(disp);
  return true;
}
#endif
