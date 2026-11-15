// The whole game as a state machine advanced one frame (1/60 s) at a time:
// title menu, turns, the Skipper, scoring, pause, game over and the self test.
// It follows SNES Yacht v1.1 (snes/yacht/src/game.s, title.s) frame for frame.
// Pure C: the N64 side feeds it input, plays the events it emits and draws its
// state; the native tests drive it directly.
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "rules.h"

// Buttons, already turned into new presses / held state by the platform.
enum {
  BTN_A = 1 << 0, BTN_B = 1 << 1, BTN_Z = 1 << 2, BTN_START = 1 << 3,
  BTN_UP = 1 << 4, BTN_DOWN = 1 << 5, BTN_LEFT = 1 << 6, BTN_RIGHT = 1 << 7,
  BTN_L = 1 << 8, BTN_R = 1 << 9,
};

typedef struct {
  uint16_t new1, new2;      // pressed this frame, controller 1 / 2
  uint16_t held1, held2;    // held this frame
  bool p2_present;          // a controller is plugged into port 2
  bool voice_busy;          // a voice clip is still playing
} input_t;

// Sounds, in the order of the asset tables (src/audio.c).
enum { SFX_TICK, SFX_SELECT, SFX_ROLL, SFX_HOLD, NUM_SFX };
enum { TUNE_TITLE, TUNE_SCORE, TUNE_BAD, TUNE_GOOD, TUNE_YACHT, TUNE_WIN, TUNE_LOSE, NUM_TUNES };
// Voice clips: the order of tandy1000/yacht/tools/speech.txt.
enum { V_YACHT, V_FULL, V_FOUR, V_STRAIGHT, V_YOUWIN, V_SKIPPER, V_TIE, V_WELCOME,
       V_P1WINS, V_P2WINS, NUM_VOICES };

typedef enum {
  EV_SFX, EV_TUNE, EV_VOICE, EV_STOP_MUSIC,
  EV_RUMBLE,   // a = controller port (0/1), b = frames
  EV_SAVE,     // best score or sound setting changed
} ev_type_t;
typedef struct { uint8_t type, a, b; } event_t;
#define MAX_EVENTS 16

enum { MODE_TWO = 0, MODE_SKIPPER = 1, MODE_DEMO = 2 };
enum { SCREEN_TITLE, SCREEN_GAME, SCREEN_SELFTEST };
enum { RESULT_P0, RESULT_P1, RESULT_TIE };

// Title menu lines.
enum { MENU_SKIPPER, MENU_TWO, MENU_DEMO, MENU_SOUND, MENU_LINES };
#define TITLE_IDLE_FRAMES 1200
#define TUMBLE_FRAMES 24
#define FADE_STEPS 16

typedef struct {
  // game phase (internal step + countdown)
  uint8_t phase, ai_step;
  uint8_t roll_ret;        // the phase a roll goes back to
  int16_t wait;            // frames left in the current pause
  int16_t voice_wait;      // frames left of the voice wait (max 360)
  bool quit;               // demo: a button was pressed / pause: B
  bool paused;

  uint8_t mode, cur;       // game mode, player on turn (0/1)
  int16_t scores[2][NUM_CATS];
  uint8_t dice[5];         // 0 = not rolled yet this turn (drawn tilted)
  uint8_t held[5];
  uint8_t rolls_left;      // 3 before the first roll
  uint8_t focus;           // 0 dice tray, 1 scorecard
  uint8_t die_sel;
  uint8_t cursor;          // scorecard box under the cursor
  bool highlight;          // cursor box highlighted on the card
  uint8_t tumble_t;        // frames of tumble left (0 = still)
  uint8_t tumble_seq;      // counts rolls, so the renderer can vary the spin
  int8_t last_cat;         // the box just scored (-1 none)
  int16_t last_score;
  bool over;               // game over screen showing
  uint8_t result;
  int16_t tot[2];
  bool done;               // finished: the app goes back to the title

  char banner[16];
  char status[3][16];
} game_t;

typedef struct {
  uint8_t sel;
  uint16_t idle;
  uint16_t t;              // frames since the title appeared
  bool leaving;
  uint8_t choice;          // mode picked when leaving
} title_t;

typedef struct {
  int run, failed;
} selftest_t;

typedef struct {
  uint8_t screen;
  uint8_t bright;          // 0 (black) .. 15 (full)
  title_t title;
  game_t game;
  selftest_t selftest;
  rng_t rng;

  // kept for as long as the console is on
  uint16_t best;
  bool muted;
  bool welcomed;
  uint16_t entropy, frame;
  uint16_t test_seed;      // non-zero: games start from this seed (tests)

  // sounds etc. to play: the caller handles them, then sets nev = 0
  event_t ev[MAX_EVENTS];
  int nev;
} app_t;

// held1 = buttons held on controller 1 at power-on (L+R starts the self test).
void app_init(app_t *a, uint16_t best, bool muted, uint16_t held1);
void app_frame(app_t *a, const input_t *in);

// Helpers the renderer and tests share.
int player_total(const game_t *g, int p);
bool player_is_ai(const game_t *g, int p);
const char *player_name(const game_t *g, int p, bool short_name);
void run_selftest(selftest_t *st);
