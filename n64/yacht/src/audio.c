// Music, sound effects and voice through libdragon's mixer. The tunes and
// effects are rendered by tools/audio.js, the voice by tools/speech.sh.
#include <libdragon.h>
#include "platform.h"

enum { CH_MUSIC, CH_VOICE, CH_SFX, CH_ROLL, NUM_CH };

static const char *const TUNE_FILES[NUM_TUNES] = { "title", "score", "bad", "good", "yacht", "win", "lose" };
static const char *const SFX_FILES[NUM_SFX] = { "tick", "select", "roll", "hold" };
static const char *const VOICE_FILES[NUM_VOICES] = {
  "yacht", "fullhouse", "four", "straight", "youwin", "skipper", "tie", "welcome", "p1wins", "p2wins",
};
static wav64_t *tune[NUM_TUNES], *sfx[NUM_SFX], *voice[NUM_VOICES];

static wav64_t *load(const char *kind, const char *name) {
  char path[48];
  snprintf(path, sizeof path, "rom:/%s%s.wav64", kind, name);
  return wav64_load(path, NULL);
}

void audio_setup(void) {
  audio_init(32000, 4);
  mixer_init(NUM_CH);
  for (int i = 0; i < NUM_TUNES; i++) tune[i] = load("tune_", TUNE_FILES[i]);
  for (int i = 0; i < NUM_SFX; i++) sfx[i] = load("sfx_", SFX_FILES[i]);
  for (int i = 0; i < NUM_VOICES; i++) voice[i] = load("v_", VOICE_FILES[i]);
  wav64_set_loop(tune[TUNE_TITLE], true);   // only the title tune loops
}

void audio_event(const event_t *e, bool muted) {
  switch (e->type) {
    case EV_TUNE: wav64_play(tune[e->a], CH_MUSIC); break;
    case EV_STOP_MUSIC: mixer_ch_stop(CH_MUSIC); break;
    case EV_SFX: wav64_play(sfx[e->a], e->a == SFX_ROLL ? CH_ROLL : CH_SFX); break;
    case EV_VOICE: if (!muted) wav64_play(voice[e->a], CH_VOICE); break;   // sound off silences the voice
    default: break;
  }
}

// Levels leave headroom for voice, music and an effect at once.
#define VOL_MUSIC 0.6f
#define VOL_DUCKED 0.22f
static int was_muted = -1;
static float music_vol = -1;

void audio_frame(bool muted) {
  if (muted) {
    if (mixer_ch_playing(CH_VOICE)) mixer_ch_stop(CH_VOICE);
    if (was_muted != 1) for (int c = 0; c < NUM_CH; c++) mixer_ch_set_vol(c, 0, 0);
    was_muted = 1;
    music_vol = 0;
  } else {
    if (was_muted != 0) {
      mixer_ch_set_vol(CH_VOICE, 0.85f, 0.85f);
      mixer_ch_set_vol(CH_SFX, 0.55f, 0.55f);
      mixer_ch_set_vol(CH_ROLL, 0.65f, 0.65f);
      mixer_ch_set_vol(CH_MUSIC, VOL_MUSIC, VOL_MUSIC);
      music_vol = VOL_MUSIC;
      was_muted = 0;
    }
    // the music ducks, over about a tenth of a second, while a voice line plays
    float m = mixer_ch_playing(CH_VOICE) ? VOL_DUCKED : VOL_MUSIC;
    if (m != music_vol) { mixer_ch_set_vol_ramp(CH_MUSIC, m, m, 3200); music_vol = m; }
  }
  mixer_try_play();
}

bool audio_voice_busy(void) { return mixer_ch_playing(CH_VOICE); }
