// Drawing helpers on top of libdragon's rdpq: loaded art, text, filled boxes.
#pragma once
#include <libdragon.h>
#include <stdbool.h>

// text alignment: libdragon's ALIGN_LEFT, ALIGN_CENTER, ALIGN_RIGHT (rdpq_text.h)

typedef struct {
  sprite_t *game_bg, *title_bg, *logo, *boat, *gull, *wave, *sparkle;
  sprite_t *die[7];          // faces 1-6
  sprite_t *shadow, *mini_die, *font_small, *font_big;
} art_t;
extern art_t art;

#define C_WHITE   RGBA32(255, 255, 255, 255)
#define C_CREAM   RGBA32(240, 226, 190, 255)
#define C_GOLD    RGBA32(255, 200, 80, 255)
#define C_SEA     RGBA32(140, 210, 255, 255)
#define C_GREEN   RGBA32(120, 230, 130, 255)
#define C_RED     RGBA32(255, 110, 90, 255)
#define C_INK     RGBA32(70, 42, 20, 255)
#define C_RED_INK RGBA32(176, 36, 24, 255)

void gfx_init(void);

// Full-screen opaque picture (copy mode).
void draw_backdrop(sprite_t *s);
// A sprite with alpha, at (x, y), optionally faded (alpha 0-255).
void draw_sprite(sprite_t *s, float x, float y, int alpha);
void draw_sprite_part(sprite_t *s, float x, float y, int s0, int t0, int w, int h, int alpha);
// Translucent filled rectangle.
void fill_box(int x, int y, int w, int h, color_t c);

// Text with a soft drop shadow. x is the left edge, centre or right edge.
void text(int x, int y, const char *s, color_t c, bool big, int align);
int text_width(const char *s, bool big);
// Plain text on a light background (the scorecard): no shadow.
void ink(int x, int y, const char *s, color_t c, int align);

// Darkens the whole frame for fades and the pause (bright 15 = untouched).
void fade_screen(int bright);
