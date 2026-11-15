// The title scene: a sunset over the sea, a sailboat, gulls and the YACHT logo.
//   title_bg.png 320x240  sky, sun, clouds, islands and the sea (static)
//   wave.png     64x6     a wave-crest strip the game scrolls at several depths
//   boat.png     72x72    the sailboat, bobbed by the game
//   gull.png     32x10    two wing frames, 16x10 each
//   sparkle.png  7x7      a glint on the sun's path
//   logo.png     240x72   the YACHT title
// Also build/gen/title_layout.h.
const path = require('path');
const fs = require('fs');
const { Raster, mix, hex, lerpStops } = require('../lib').raster;
const { writePng, preview, noise, ASSETS, GEN } = require('../lib');

const W = 320, H = 240, HORIZON = 118;
const SUN = { x: 228, y: 104, r: 24 };
const r = new Raster(W, H);

// sky: night blue overhead through violet and rose to gold at the horizon
const skyStops = [[0, hex('#141a44')], [0.35, hex('#3a2a6a')], [0.62, hex('#9a3a6a')], [0.82, hex('#ee6a3c')], [1, hex('#ffc25a')]];
for (let y = 0; y < HORIZON; y++) {
  const c = lerpStops(skyStops, y / (HORIZON - 1));
  for (let x = 0; x < W; x++) {
    const glow = Math.max(0, 1 - Math.hypot(x - SUN.x, (y - SUN.y) * 1.6) / 150);
    r.set(x, y, mix(c, hex('#ffe08a'), glow * glow * 0.6));
  }
}
// a few early stars
for (let i = 0; i < 40; i++) {
  const x = (i * 97 + 13) % W, y = (i * 53 + 7) % 46;
  r.blend(x, y, [255, 240, 220, 255], 0.25 + noise(i, 3, 1, 7) * 0.5);
}
// the sun, with a hazy halo
r.circle(SUN.x, SUN.y, SUN.r + 10, hex('#ffd070', 50));
r.circle(SUN.x, SUN.y, SUN.r + 4, hex('#ffe090', 90));
r.circle(SUN.x, SUN.y, SUN.r, (x, y) => mix(hex('#fff6c8'), hex('#ffb040'), (y - SUN.y + SUN.r) / (2 * SUN.r)));
// thin cloud streaks lit from below
function cloud(cx, cy, w, h, seed) {
  r.shape(cx - w, cy - h, cx + w, cy + h, (x, y) => {
    const d = ((x - cx) / w) ** 2 + ((y - cy) / h) ** 2;
    return d < 1 && noise(x, y * 3, 9, seed) > 0.35 + d * 0.4;
  }, (x, y) => mix(hex('#ffb07a', 200), hex('#6a2a5a', 200), Math.min(1, Math.max(0, (cy - y) / h + 0.5))));
}
cloud(70, 40, 60, 7, 3); cloud(150, 62, 70, 6, 4); cloud(270, 30, 50, 5, 5); cloud(40, 86, 40, 4, 6); cloud(300, 74, 36, 4, 8);
// distant islands
const island = (x0, x1, peak, seed) => r.shape(x0, HORIZON - peak - 2, x1, HORIZON + 1, (x, y) => {
  const t = (x - x0) / (x1 - x0);
  const top = HORIZON - peak * Math.sin(Math.PI * t) ** 0.7 * (0.8 + 0.2 * noise(x, 0, 6, seed));
  return y >= top;
}, (x, y) => mix(hex('#3a1e46'), hex('#5a2a50'), (y - HORIZON + 20) / 20));
island(8, 92, 16, 1); island(70, 128, 9, 2); island(296, 330, 7, 3);

// sea: deep blue, lighter toward the horizon, with the sun's golden path
for (let y = HORIZON; y < H; y++) {
  const t = (y - HORIZON) / (H - HORIZON);
  const base = lerpStops([[0, hex('#c45a5a')], [0.15, hex('#5a3a7a')], [0.5, hex('#1e3070')], [1, hex('#0c1640')]], t);
  for (let x = 0; x < W; x++) {
    const ripple = noise(x * 0.5, y * 3.5, 6, 11) - 0.5;
    const pathW = 8 + t * 46;
    const sunPath = Math.max(0, 1 - Math.abs(x - SUN.x + ripple * 14) / pathW) * (1 - t * 0.6);
    let c = mix(base, hex('#ffd27a'), Math.min(1, sunPath * (0.5 + ripple * 1.6)) * 0.8);
    c = mix(c, hex('#ffffff'), Math.max(0, ripple) * 0.12 * (1 - t));
    r.set(x, y, c);
  }
}
r.rect(0, HORIZON, W, 1, hex('#ffd890', 150));
writePng(path.join(ASSETS, 'title_bg.png'), r);

// wave crest strip, tileable across 64 px
const wave = new Raster(64, 6);
for (let x = 0; x < 64; x++) {
  const y = 2.5 + 1.5 * Math.sin((x / 64) * Math.PI * 4) + Math.sin((x / 64) * Math.PI * 2) * 0.8;
  for (let yy = 0; yy < 6; yy++) {
    const d = Math.abs(yy - y);
    if (d < 1.2) wave.blend(x, yy, [200, 220, 255, 255], (1.2 - d) / 1.2 * (0.4 + 0.6 * Math.abs(Math.sin((x / 64) * Math.PI * 3))));
  }
}
writePng(path.join(ASSETS, 'wave.png'), wave);

// the sailboat, lit by the low sun from the right
const boat = new Raster(72, 72);
boat.polygon([[6, 54], [66, 54], [58, 66], [14, 66]], (x, y) => mix(hex('#6a2a1a'), hex('#2a0e08'), (y - 54) / 12));
boat.rect(10, 54, 54, 2, hex('#e8c890'));
boat.rect(35, 6, 2, 49, hex('#3a2010'));
boat.polygon([[37, 7], [37, 50], [66, 50]], (x, y) => mix(hex('#fff2dc'), hex('#ffb070'), (x - 37) / 29));
boat.polygon([[34, 12], [34, 50], [12, 50]], (x, y) => mix(hex('#f0d8c0'), hex('#c08a7a'), (34 - x) / 22));
boat.polygon([[36, 2], [36, 8], [44, 5]], hex('#d83828'));
writePng(path.join(ASSETS, 'boat.png'), boat);

// gull: two wing frames
const gull = new Raster(32, 10);
const wing = (ox, up) => {
  gull.line(ox + 1, 5 - up, ox + 8, 6, 1.3, hex('#2a1a2a'));
  gull.line(ox + 8, 6, ox + 15, 5 - up, 1.3, hex('#2a1a2a'));
};
wing(0, 3); wing(16, -1);
writePng(path.join(ASSETS, 'gull.png'), gull);

const sp = new Raster(7, 7);
sp.line(3.5, 0, 3.5, 7, 1, hex('#fff8e0'));
sp.line(0, 3.5, 7, 3.5, 1, hex('#fff8e0'));
sp.circle(3.5, 3.5, 1.4, hex('#ffffff'));
writePng(path.join(ASSETS, 'sparkle.png'), sp);

// logo: the SNES glyph shapes, big, gold with a dark outline and a highlight
const src = fs.readFileSync(path.join(__dirname, '../../../../snes/yacht/tools/art/font.js'), 'utf8');
const G = {};
for (const m of src.matchAll(/^\s*(\w):\s*'([.#/]+)'/gm)) G[m[1]] = m[2];
const logo = new Raster(240, 72);
function strokes(ch, ox, oy, s) {
  const rows = G[ch].split('/'), out = [];
  const on = (x, y) => y >= 0 && y < rows.length && x >= 0 && x < 5 && rows[y][x] === '#';
  const p = (x, y) => [ox + (x + 0.5) * s, oy + (y + 0.5) * s];
  for (let y = 0; y < rows.length; y++) for (let x = 0; x < 5; x++) {
    if (!on(x, y)) continue;
    out.push([...p(x, y), ...p(x, y)]);
    if (on(x + 1, y)) out.push([...p(x, y), ...p(x + 1, y)]);
    if (on(x, y + 1)) out.push([...p(x, y), ...p(x, y + 1)]);
    if (on(x + 1, y + 1) && !on(x + 1, y) && !on(x, y + 1)) out.push([...p(x, y), ...p(x + 1, y + 1)]);
    if (on(x - 1, y + 1) && !on(x - 1, y) && !on(x, y + 1)) out.push([...p(x, y), ...p(x - 1, y + 1)]);
  }
  return out;
}
const segs = [];
[...'YACHT'].forEach((ch, i) => segs.push(...strokes(ch, 8 + i * 46, 6, 8)));
const dist = (qx, qy) => Math.min(...segs.map(([x0, y0, x1, y1]) => {
  const dx = x1 - x0, dy = y1 - y0, l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((qx - x0) * dx + (qy - y0) * dy) / l2)) : 0;
  return Math.hypot(qx - x0 - t * dx, qy - y0 - t * dy);
}));
const BODY = 4.4, LINE = 7;
logo.shape(0, 0, 240, 72, (x, y) => dist(x - 2, y - 3) <= LINE, [20, 8, 30, 160]);       // drop shadow
logo.shape(0, 0, 240, 72, (x, y) => dist(x, y) <= LINE, hex('#2a1408'));               // outline
logo.shape(0, 0, 240, 72, (x, y) => dist(x, y) <= BODY, (x, y) =>
  lerpStops([[0, hex('#fff6c0')], [0.45, hex('#ffd050')], [0.55, hex('#e09018')], [1, hex('#ffcc60')]], (y - 6) / 60));
logo.shape(0, 0, 240, 72, (x, y) => dist(x, y) <= BODY && dist(x + 1.6, y + 1.8) > BODY, hex('#fffbe6', 200)); // top-left highlight
writePng(path.join(ASSETS, 'logo.png'), logo);

const pv = new Raster(W, H);
pv.blit(r, 0, 0);
pv.blit(logo, 40, 14);
pv.blit(boat, 52, 112);
for (let i = 0; i < 4; i++) pv.blit(wave, i * 64 + 10, 160);
pv.blit(gull.crop(0, 0, 16, 10), 120, 60);
pv.blit(sp, 226, 150);
preview('title', pv, 2);

fs.writeFileSync(path.join(GEN, 'title_layout.h'), `// generated by tools/art/title.js
#pragma once
#define TITLE_HORIZON ${HORIZON}
#define TITLE_SUN_X ${SUN.x}
`);
