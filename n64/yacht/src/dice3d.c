// Each die is a cube drawn with rdpq triangles: the faces turned toward the
// camera, textured with the face art and lit by the shade colour. Its
// orientation is: camera tilt * its own resting yaw * the tumble spin * the
// rotation that brings the face it shows to the top.
#include "dice3d.h"
#include "gfx.h"
#include "gen/layout.h"
#include <math.h>

typedef struct { float m[3][3]; } mat3;
typedef struct { float x, y, z; } vec3;

static mat3 mul(mat3 a, mat3 b) {
  mat3 r;
  for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++)
    r.m[i][j] = a.m[i][0] * b.m[0][j] + a.m[i][1] * b.m[1][j] + a.m[i][2] * b.m[2][j];
  return r;
}
static vec3 apply(mat3 a, vec3 v) {
  return (vec3){ a.m[0][0] * v.x + a.m[0][1] * v.y + a.m[0][2] * v.z,
                 a.m[1][0] * v.x + a.m[1][1] * v.y + a.m[1][2] * v.z,
                 a.m[2][0] * v.x + a.m[2][1] * v.y + a.m[2][2] * v.z };
}
static mat3 rot_x(float a) { float c = cosf(a), s = sinf(a); return (mat3){ { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } } }; }
static mat3 rot_y(float a) { float c = cosf(a), s = sinf(a); return (mat3){ { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } } }; }
static mat3 rot_z(float a) { float c = cosf(a), s = sinf(a); return (mat3){ { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } } }; }
// Rotation by angle a about unit axis k (Rodrigues).
static mat3 rot_axis(vec3 k, float a) {
  float c = cosf(a), s = sinf(a), t = 1 - c;
  return (mat3){ { { t * k.x * k.x + c, t * k.x * k.y - s * k.z, t * k.x * k.z + s * k.y },
                   { t * k.x * k.y + s * k.z, t * k.y * k.y + c, t * k.y * k.z - s * k.x },
                   { t * k.x * k.z - s * k.y, t * k.y * k.z + s * k.x, t * k.z * k.z + c } } };
}

// Camera space: x right, y down, z into the screen. Face v of the cube faces
// these local directions (opposite faces add up to 7):
//   1 -y (top)  6 +y   2 -z   5 +z   3 +x   4 -x
// Each face is a quad: normal, then corners in texture order (s,t) = (0,0) (1,0) (1,1) (0,1).
static const vec3 FACE[7][5] = {
  { { 0 } },
  { { 0, -1, 0 }, { -1, -1, -1 }, { 1, -1, -1 }, { 1, -1, 1 }, { -1, -1, 1 } },
  { { 0, 0, -1 }, { -1, 1, -1 }, { 1, 1, -1 }, { 1, -1, -1 }, { -1, -1, -1 } },
  { { 1, 0, 0 }, { 1, -1, -1 }, { 1, 1, -1 }, { 1, 1, 1 }, { 1, -1, 1 } },
  { { -1, 0, 0 }, { -1, -1, 1 }, { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, -1 } },
  { { 0, 0, 1 }, { 1, 1, 1 }, { -1, 1, 1 }, { -1, -1, 1 }, { 1, -1, 1 } },
  { { 0, 1, 0 }, { -1, 1, 1 }, { 1, 1, 1 }, { 1, 1, -1 }, { -1, 1, -1 } },
};

// The rotation that turns face v to the top (-y).
static mat3 rest(int v) {
  switch (v) {
    case 6: return rot_x((float)M_PI);
    case 2: return rot_x(-(float)M_PI / 2);
    case 5: return rot_x((float)M_PI / 2);
    case 3: return rot_z(-(float)M_PI / 2);
    case 4: return rot_z((float)M_PI / 2);
    default: return rot_x(0);
  }
}

#define HALF 12.5f          // half the die's edge, in pixels
#define FOCAL 340.0f        // perspective strength
#define TILT 0.46f          // camera looks down at the felt (radians from straight on)

static uint32_t hash(uint32_t x) {
  x ^= x >> 16; x *= 0x7feb352d; x ^= x >> 15; x *= 0x846ca68b; x ^= x >> 16;
  return x;
}
static float frand(uint32_t h) { return (h & 0xFFFF) / 65535.0f; }

typedef struct { float sx, sy, depth; mat3 m; int face; bool held; float lift; } die_view_t;

static void draw_die(const die_view_t *d) {
  static const vec3 LIGHT = { -0.42f, -0.78f, -0.46f };   // toward the light: up, left, toward us
  rdpq_set_mode_standard();
  rdpq_mode_combiner(RDPQ_COMBINER_TEX_SHADE);
  rdpq_mode_filter(FILTER_BILINEAR);
  rdpq_mode_persp(true);
  rdpq_mode_antialias(AA_STANDARD);
  for (int f = 1; f <= 6; f++) {
    vec3 n = apply(d->m, FACE[f][0]);
    if (n.z >= -0.02f) continue;                 // facing away
    float lit = 0.5f + 0.62f * fmaxf(0, n.x * LIGHT.x + n.y * LIGHT.y + n.z * LIGHT.z);
    if (lit > 1) lit = 1;
    float r = lit, gr = lit, b = lit;
    float v[4][9];
    for (int i = 0; i < 4; i++) {
      vec3 p = apply(d->m, FACE[f][i + 1]);
      float z = p.z * HALF, k = FOCAL / (FOCAL + z);
      v[i][0] = d->sx + p.x * HALF * k;
      v[i][1] = d->sy + p.y * HALF * k;
      v[i][2] = r; v[i][3] = gr; v[i][4] = b; v[i][5] = 1;
      v[i][6] = (i == 1 || i == 2) ? 32 : 0;
      v[i][7] = (i >= 2) ? 32 : 0;
      v[i][8] = k;
    }
    rdpq_sprite_upload(TILE0, art.die[f], NULL);
    rdpq_triangle(&TRIFMT_SHADE_TEX, v[0], v[1], v[2]);
    rdpq_triangle(&TRIFMT_SHADE_TEX, v[0], v[2], v[3]);
  }
}

void dice_draw(const game_t *g, uint32_t t) {
  die_view_t dv[5];
  mat3 cam = rot_x(TILT);
  for (int i = 0; i < 5; i++) {
    die_view_t *d = &dv[i];
    uint32_t h = hash(i * 7919u + g->tumble_seq * 104729u);
    float yaw = (frand(hash(i + 1)) - 0.5f) * 0.5f;       // each die rests a little askew
    float x = DIE_X[i], y = DIE_Y[i], lift = 0;
    int face = g->dice[i];
    mat3 spin = rot_x(0);
    bool tumbling = g->tumble_t && !g->held[i];
    if (face == 0) {
      // not rolled yet this turn: dice lie tipped over, showing one edge
      face = (i % 6) + 1;
      spin = rot_axis((vec3){ 0.7071f, 0, 0.7071f }, 0.55f + 0.1f * i);
    }
    if (tumbling) {
      float k = g->tumble_t / (float)TUMBLE_FRAMES;   // 1 at the throw, 0 at rest
      float ax = frand(h) - 0.5f, ay = frand(h >> 8) - 0.5f, az = frand(h >> 16) - 0.5f;
      float len = sqrtf(ax * ax + ay * ay + az * az) + 1e-4f;
      spin = rot_axis((vec3){ ax / len, ay / len, az / len }, k * k * (9.0f + 4.0f * frand(h >> 4)));
      // thrown in from the left, bouncing to a stop
      x -= k * k * (40 + 20 * frand(h >> 12));
      y += k * (frand(h >> 20) - 0.5f) * 16;
      lift = fabsf(sinf(k * 3.0f * (float)M_PI)) * 22 * k;
    }
    if (g->held[i] && g->dice[i]) lift = 4;
    d->m = mul(cam, mul(rot_y(yaw), mul(spin, rest(face))));
    d->sx = x;
    d->sy = y - lift;
    d->depth = y;
    d->face = face;
    d->held = g->held[i] && g->dice[i];
    d->lift = lift;
    (void)t;
  }
  // shadows first, smaller and fainter as a die rises; held dice glow gold instead
  rdpq_set_mode_standard();
  rdpq_mode_combiner(RDPQ_COMBINER1((0, 0, 0, PRIM), (TEX0, 0, PRIM, 0)));
  rdpq_mode_blender(RDPQ_BLENDER_MULTIPLY);
  rdpq_mode_filter(FILTER_BILINEAR);
  for (int i = 0; i < 5; i++) {
    float s = 1.0f - dv[i].lift / 40.0f;
    if (dv[i].held) {
      rdpq_set_prim_color(RGBA32(255, 200, 60, 255));
      for (int k = 0; k < 2; k++)   // twice: the shadow art is soft, the glow should read
        rdpq_sprite_blit(art.shadow, dv[i].sx, dv[i].depth + 6, &(rdpq_blitparms_t){
          .cx = 24, .cy = 12, .scale_x = 1.25f, .scale_y = 1.6f });
    }
    rdpq_set_prim_color(RGBA32(0, 0, 0, (int)(255 * s)));
    rdpq_sprite_blit(art.shadow, dv[i].sx + 3, dv[i].depth + 14, &(rdpq_blitparms_t){
      .cx = 24, .cy = 12, .scale_x = 0.85f * s, .scale_y = 0.85f * s });
  }
  // back row first
  int order[5] = { 0, 1, 2, 3, 4 };
  for (int a = 0; a < 5; a++) for (int b = a + 1; b < 5; b++)
    if (dv[order[b]].depth < dv[order[a]].depth) { int tmp = order[a]; order[a] = order[b]; order[b] = tmp; }
  for (int k = 0; k < 5; k++) draw_die(&dv[order[k]]);
}
