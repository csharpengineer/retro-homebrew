// Controllers 1 and 2 as the game's buttons, the analog stick as a D-pad, and
// the Rumble Pak.
#include <libdragon.h>
#include "platform.h"

static uint16_t map(joypad_buttons_t b) {
  uint16_t m = 0;
  if (b.a) m |= BTN_A;
  if (b.b) m |= BTN_B;
  if (b.z) m |= BTN_Z;
  if (b.start) m |= BTN_START;
  if (b.d_up || b.c_up) m |= BTN_UP;
  if (b.d_down || b.c_down) m |= BTN_DOWN;
  if (b.d_left || b.c_left) m |= BTN_LEFT;
  if (b.d_right || b.c_right) m |= BTN_RIGHT;
  if (b.l) m |= BTN_L;
  if (b.r) m |= BTN_R;
  return m;
}

static uint16_t stick(joypad_port_t p) {
  uint16_t m = 0;
  int y = joypad_get_axis_pressed(p, JOYPAD_AXIS_STICK_Y), x = joypad_get_axis_pressed(p, JOYPAD_AXIS_STICK_X);
  if (y > 0) m |= BTN_UP;
  if (y < 0) m |= BTN_DOWN;
  if (x > 0) m |= BTN_RIGHT;
  if (x < 0) m |= BTN_LEFT;
  return m;
}

void input_setup(void) { joypad_init(); }

uint16_t input_held_at_boot(void) {
  joypad_poll();
  return map(joypad_get_buttons_held(JOYPAD_PORT_1));
}

void input_read(input_t *in) {
  joypad_poll();
  in->new1 = map(joypad_get_buttons_pressed(JOYPAD_PORT_1)) | stick(JOYPAD_PORT_1);
  in->new2 = map(joypad_get_buttons_pressed(JOYPAD_PORT_2)) | stick(JOYPAD_PORT_2);
  in->held1 = map(joypad_get_buttons_held(JOYPAD_PORT_1));
  in->held2 = map(joypad_get_buttons_held(JOYPAD_PORT_2));
  in->p2_present = joypad_is_connected(JOYPAD_PORT_2);
}

static int rumble_left[2];

void rumble(int port, int frames) {
  if (port < 0 || port > 1 || !joypad_get_rumble_supported(port)) return;
  joypad_set_rumble_active(port, true);
  rumble_left[port] = frames;
}

void rumble_frame(void) {
  for (int p = 0; p < 2; p++)
    if (rumble_left[p] && --rumble_left[p] == 0) joypad_set_rumble_active(p, false);
}
