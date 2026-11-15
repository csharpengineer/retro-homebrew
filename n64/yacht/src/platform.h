// The N64 side of the game's events and input: sound, controllers, rumble, save.
#pragma once
#include "core/game.h"

void audio_setup(void);
void audio_event(const event_t *e, bool muted);
void audio_frame(bool muted);      // ducking and mixing; call every frame
bool audio_voice_busy(void);
#ifdef AUTOTEST
void audio_capture(int tune, int samples);
#endif

void input_setup(void);
void input_read(input_t *in);      // polls the controllers
uint16_t input_held_at_boot(void);
void rumble(int port, int frames);
void rumble_frame(void);

void save_load(uint16_t *best, bool *muted);
void save_store(uint16_t best, bool muted);
