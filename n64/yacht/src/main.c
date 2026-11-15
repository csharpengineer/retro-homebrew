// YACHT for the Nintendo 64: power-on, the main loop, and the glue between the
// game state machine (src/core) and the console.
#include <libdragon.h>
#include "core/game.h"
#include "gfx.h"
#include "screens.h"
#include "platform.h"
#include "autotest.h"

static app_t app;

static void handle_events(void) {
  for (int i = 0; i < app.nev; i++) {
    const event_t *e = &app.ev[i];
    if (e->type == EV_SAVE) save_store(app.best, app.muted);
    else if (e->type == EV_RUMBLE) rumble(e->a, e->b);
    else audio_event(e, app.muted);
  }
  app.nev = 0;
}

int main(void) {
  debug_init_isviewer();
  dfs_init(DFS_DEFAULT_LOCATION);
  display_init(RESOLUTION_320x240, DEPTH_16_BPP, 3, GAMMA_NONE, FILTERS_RESAMPLE_ANTIALIAS);
  rdpq_init();
#ifdef AUTOTEST
  rdpq_debug_start();   // validates every RDP command; problems go to the log
#endif
  input_setup();
  audio_setup();
  gfx_init();

  uint16_t best;
  bool muted;
  save_load(&best, &muted);
  app_init(&app, best, muted, input_held_at_boot());
  handle_events();
  debugf("YACHT %s\n", VERSION_STR);

  for (uint32_t t = 0;; t++) {
    input_t in;
    input_read(&in);
    in.voice_busy = audio_voice_busy() && !app.muted;
    int steps = autotest_input(&app, &in);
    for (int s = 0; s < steps; s++) {
      app_frame(&app, &in);
      handle_events();
      in.new1 = in.new2 = 0;   // a press counts once
      if (autotest_stop_early(&app)) break;
    }
    surface_t *disp = display_get();
    rdpq_attach(disp, NULL);
    draw_frame(&app, t);
    if (!autotest_after_draw(&app, disp)) rdpq_detach_show();
    audio_frame(app.muted);
    rumble_frame();
  }
}
