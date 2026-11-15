// The emulator test build (make AUTOTEST=1, tests/emu.sh): plays a scripted
// session by itself and prints results and screenshots over the ISViewer log.
// In the normal build these do nothing.
#pragma once
#include <libdragon.h>
#include "core/game.h"

#ifdef AUTOTEST
int autotest_input(app_t *a, input_t *in);          // fills in presses; returns game steps this frame
bool autotest_stop_early(const app_t *a);           // stop stepping to photograph this moment
bool autotest_after_draw(app_t *a, surface_t *disp);   // true: it showed the frame itself
#else
static inline int autotest_input(app_t *a, input_t *in) { (void)a; (void)in; return 1; }
static inline bool autotest_stop_early(const app_t *a) { (void)a; return false; }
static inline bool autotest_after_draw(app_t *a, surface_t *disp) { (void)a; (void)disp; return false; }
#endif
