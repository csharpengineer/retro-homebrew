#include "gfx.h"
#include "gen/font.h"
#include <string.h>

art_t art;

static sprite_t *load(const char *name) {
  char path[64];
  snprintf(path, sizeof path, "rom:/%s.sprite", name);
  return sprite_load(path);
}

void gfx_init(void) {
  art.game_bg = load("game_bg");
  art.title_bg = load("title_bg");
  art.logo = load("logo");
  art.boat = load("boat");
  art.gull = load("gull");
  art.wave = load("wave");
  art.sparkle = load("sparkle");
  for (int i = 1; i <= 6; i++) {
    char n[8];
    snprintf(n, sizeof n, "die%d", i);
    art.die[i] = load(n);
  }
  art.shadow = load("shadow");
  art.mini_die = load("mini_die");
  art.font_small = load("font_small");
  art.font_big = load("font_big");
}

void draw_backdrop(sprite_t *s) {
  rdpq_set_mode_copy(false);
  rdpq_sprite_blit(s, 0, 0, NULL);
}

static void alpha_mode(int alpha) {
  rdpq_set_mode_standard();
  rdpq_mode_blender(RDPQ_BLENDER_MULTIPLY);
  if (alpha < 255) {
    rdpq_mode_combiner(RDPQ_COMBINER_TEX_FLAT);
    rdpq_set_prim_color(RGBA32(255, 255, 255, alpha));
  }
}

void draw_sprite(sprite_t *s, float x, float y, int alpha) {
  alpha_mode(alpha);
  rdpq_sprite_blit(s, x, y, NULL);
}

void draw_sprite_part(sprite_t *s, float x, float y, int s0, int t0, int w, int h, int alpha) {
  alpha_mode(alpha);
  rdpq_sprite_blit(s, x, y, &(rdpq_blitparms_t){ .s0 = s0, .t0 = t0, .width = w, .height = h });
}

void fill_box(int x, int y, int w, int h, color_t c) {
  rdpq_set_mode_standard();
  rdpq_mode_combiner(RDPQ_COMBINER_FLAT);
  rdpq_mode_blender(RDPQ_BLENDER_MULTIPLY);
  rdpq_set_prim_color(c);
  rdpq_fill_rectangle(x, y, x + w, y + h);
}

int text_width(const char *s, bool big) {
  return (int)strlen(s) * (big ? FONT_BIG_ADV : FONT_SMALL_ADV);
}

static void glyphs(int x, int y, const char *s, bool big) {
  sprite_t *f = big ? art.font_big : art.font_small;
  int cw = big ? FONT_BIG_W : FONT_SMALL_W, ch = big ? FONT_BIG_H : FONT_SMALL_H;
  int adv = big ? FONT_BIG_ADV : FONT_SMALL_ADV;
  for (; *s; s++, x += adv) {
    int n = (unsigned char)*s - 32;
    if (n <= 0 || n >= 95) continue;
    rdpq_sprite_blit(f, x, y, &(rdpq_blitparms_t){ .s0 = (n % 16) * cw, .t0 = (n / 16) * ch, .width = cw, .height = ch });
  }
}

static int aligned(int x, const char *s, bool big, int align) {
  if (align == ALIGN_CENTER) return x - text_width(s, big) / 2;
  if (align == ALIGN_RIGHT) return x - text_width(s, big);
  return x;
}

void text(int x, int y, const char *s, color_t c, bool big, int align) {
  x = aligned(x, s, big, align);
  rdpq_set_mode_standard();
  rdpq_mode_combiner(RDPQ_COMBINER_TEX_FLAT);
  rdpq_mode_blender(RDPQ_BLENDER_MULTIPLY);
  rdpq_set_prim_color(RGBA32(0, 0, 0, 170));
  glyphs(x + 1, y + 1, s, big);
  rdpq_set_prim_color(c);
  glyphs(x, y, s, big);
}

void ink(int x, int y, const char *s, color_t c, int align) {
  x = aligned(x, s, false, align);
  rdpq_set_mode_standard();
  rdpq_mode_combiner(RDPQ_COMBINER_TEX_FLAT);
  rdpq_mode_blender(RDPQ_BLENDER_MULTIPLY);
  rdpq_set_prim_color(c);
  glyphs(x, y, s, false);
}

void fade_screen(int bright) {
  if (bright >= 15) return;
  fill_box(0, 0, 320, 240, RGBA32(0, 0, 0, (15 - bright) * 255 / 15));
}
