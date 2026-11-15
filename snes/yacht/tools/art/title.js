// Title screen art: a sunset over the sea.
//   backdrop  sky gradient, one color per scanline by HDMA (lines 0-127)
//   BG2       clouds (scroll slowly), sun with halo, island on the horizon
//   BG1       the sea, lines 128-223; three glitter colors cycle at run time
//   sprites   YACHT logo, sailboat, gulls, menu cursor die
const gfx = require('../snesgfx');
const { Raster, mix, lerpStops, hex } = require('../raster');
const C = require('./common');

const W = 256, H = 224, HORIZON = 128;

// ---------------------------------------------------------------- sky
const SKY = [
  [0.00, hex('#120e38')], [0.30, hex('#3a2466')], [0.55, hex('#8a3a74')],
  [0.75, hex('#d0605e')], [0.90, hex('#f39a52')], [1.00, hex('#ffd889')],
];
const sky = (y) => lerpStops(SKY, Math.min(1, Math.max(0, y / (HORIZON - 1))));
const skyLines = [];
for (let y = 0; y < HORIZON; y++) skyLines.push(gfx.snap(sky(y)));
C.writeBin('title_sky.hdma', C.colorGradientHdma(skyLines));

// Draw a coverage shape composited over the sky, opaque where covered.
function overSky(r, cover, color) {
  for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
    const k = cover(x, y);
    if (k <= 0) continue;
    const base = r.get(x, y)[3] ? r.get(x, y) : sky(y);
    const col = typeof color === 'function' ? color(x, y) : color;
    const m = mix(base, col, Math.min(1, k * ((col[3] ?? 255) / 255)));
    r.set(x, y, [m[0], m[1], m[2], 255]);
  }
}
// 4x4 supersampled coverage of inside(x, y).
const cov = (inside) => (x, y) => {
  let n = 0;
  for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) n++;
  return n / 16;
};

// ---------------------------------------------------------------- BG2: clouds (rows 0-71)
const clouds = new Raster(W, 72);
const CLOUDS = [
  // [cx, cy, width, height]
  [40, 22, 70, 10], [150, 14, 90, 9], [214, 40, 60, 8], [96, 50, 80, 9], [10, 60, 40, 6], [190, 62, 50, 6],
];
function cloudInside(cx, cy, w, h) {
  const puffs = [];
  let seed = cx * 7 + cy * 13;
  const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  for (let i = 0; i < 7; i++) {
    const px = cx + (rnd() - 0.5) * w * 0.8, py = cy - rnd() * h * 0.6;
    puffs.push([px, py, w * (0.18 + rnd() * 0.16), h * (0.5 + rnd() * 0.5)]);
  }
  return (x, y) => {
    if (y > cy + h * 0.35) return false;          // flat bottoms
    for (const dx of [0, -W, W]) {
      const xx = x + dx;
      if (((xx - cx) / (w / 2)) ** 2 + ((y - cy) / (h * 0.45)) ** 2 <= 1) return true;
      for (const [px, py, rx, ry] of puffs) if (((xx - px) / rx) ** 2 + ((y - py) / ry) ** 2 <= 1) return true;
    }
    return false;
  };
}
for (const [cx, cy, w, h] of CLOUDS) {
  const top = cy - h * 1.2, bot = cy + h * 0.35;
  overSky(clouds, cov(cloudInside(cx, cy, w, h)), (x, y) => {
    const t = Math.min(1, Math.max(0, (y - top) / (bot - top)));
    // lit from below by the low sun: lavender tops, glowing peach undersides
    return lerpStops([[0, hex('#6c4c8e')], [0.55, hex('#c7708a')], [0.85, hex('#ffb07a')], [1, hex('#ffd9a0')]], t);
  });
}

// ---------------------------------------------------------------- BG2: sun, halo, island (rows 72-127)
const sunR = new Raster(W, 56);    // y offset 72
const SUN_X = 176, SUN_Y = 120 - 72, SUN_RAD = 24;
// (overSky composites against sky(y), which needs the real y)
function overSkyAt(r, yoff, cover, color) {
  for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
    const k = cover(x, y);
    if (k <= 0) continue;
    const base = r.get(x, y)[3] ? r.get(x, y) : sky(y + yoff);
    const col = typeof color === 'function' ? color(x, y) : color;
    const m = mix(base, col, Math.min(1, k));
    r.set(x, y, [m[0], m[1], m[2], 255]);
  }
}
sunR.fill([0, 0, 0, 0]);
overSkyAt(sunR, 72, (x, y) => {
  const d = Math.hypot(x + 0.5 - SUN_X, y + 0.5 - SUN_Y);
  const k = d > SUN_RAD - 0.5 && d < SUN_RAD + 16 ? Math.pow(1 - (d - SUN_RAD) / 16, 1.4) * 0.7 : 0;
  return k < 0.16 ? 0 : k;
}, hex('#ffe6a8'));
overSkyAt(sunR, 72, cov((x, y) => Math.hypot(x - SUN_X, y - SUN_Y) <= SUN_RAD), (x, y) => {
  const t = Math.hypot(x - SUN_X, y - SUN_Y - 6) / (SUN_RAD + 6);
  return lerpStops([[0, hex('#fffbe6')], [0.55, hex('#ffe9a0')], [1, hex('#ffb54d')]], t);
});
// thin cloud bars across the sun's face
for (const [by, bx0, bx1] of [[SUN_Y - 6, SUN_X - 30, SUN_X + 34], [SUN_Y + 3, SUN_X - 40, SUN_X + 18]]) {
  overSkyAt(sunR, 72, cov((x, y) => y >= by && y < by + 2.2 && x > bx0 && x < bx1 &&
    Math.abs(x - (bx0 + bx1) / 2) < (bx1 - bx0) / 2 - Math.abs(y - by) * 6), hex('#e8806a'));
}
// island with two palms, on the horizon at the left
const ISLE = hex('#2a1838');
overSkyAt(sunR, 72, cov((x, y) => {
  const yy = y + 72;
  const hill = HORIZON - 1 - 9 * Math.exp(-(((x - 46) / 22) ** 2)) - 5 * Math.exp(-(((x - 78) / 14) ** 2));
  return yy >= hill && yy < HORIZON;
}), ISLE);
function palm(r, bx, by, lean) {
  for (let i = 0; i < 18; i++) {
    const t = i / 18, x = bx + lean * t * t * 10, y = by - t * 22;
    r.circle(x, y - 72, 1.1, ISLE);
  }
  const tx = bx + lean * 10, ty = by - 22 - 72;
  for (const [ax, ay] of [[-9, 3], [-6, -3], [0, -5], [7, -2], [9, 4], [4, 5], [-3, 6]]) {
    r.line(tx, ty, tx + ax, ty + ay, 1.4, ISLE);
    r.line(tx + ax * 0.7, ty + ay * 0.7, tx + ax, ty + ay + 1.5, 1.0, ISLE);
  }
}
palm(sunR, 40, HORIZON - 9, -0.6);
palm(sunR, 52, HORIZON - 8, 0.8);

// ---------------------------------------------------------------- BG1: sea (rows 128-223)
const SEA_H = H - HORIZON;
const sea = new Raster(W, SEA_H);
const SPARK = [hex('#ff00ff'), hex('#00ffff'), hex('#ffff00')];   // markers for the cycling colors
for (let y = 0; y < SEA_H; y++) {
  const t = y / (SEA_H - 1);
  const depth = Math.pow(t, 0.8);
  const base = lerpStops([[0, hex('#c87a72')], [0.06, hex('#8a4c78')], [0.3, hex('#4a3a78')], [0.6, hex('#1e3266')], [1, hex('#0c1a3c')]], depth);
  // perspective: waves get longer and taller toward the viewer
  const freq = (2 * Math.PI) / (16 + t * 112);
  for (let x = 0; x < W; x++) {
    const w1 = Math.sin(x * freq * 4 + y * 1.7) * 0.5 + Math.sin(x * freq * 2.5 - y * 0.9 + 1.3) * 0.5;
    const crest = Math.max(0, w1 - 0.55) * 2.2;
    const trough = Math.max(0, -w1 - 0.6) * 1.5;
    let c = mix(base, mix(hex('#ffb88a'), hex('#7aa0d8'), Math.min(1, t * 1.6)), crest * (0.18 + t * 0.32));
    c = mix(c, hex('#050a20'), trough * 0.35);
    sea.set(x, y, [c[0], c[1], c[2], 255]);
  }
}
// sun glitter path under the sun: short dashes, widening toward the viewer
let gs = 99;
const grnd = () => ((gs = (gs * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
for (let y = 1; y < SEA_H; y += 1) {
  const t = y / SEA_H;
  const spread = 6 + t * 46;
  const n = Math.round(1 + t * 3);
  for (let i = 0; i < n; i++) {
    if (grnd() > 0.55) continue;
    const x = SUN_X + (grnd() - 0.5) * 2 * spread * (0.4 + grnd() * 0.6);
    const len = 1 + Math.round(grnd() * (2 + t * 6));
    const m = SPARK[Math.floor(grnd() * 3)];
    for (let k = 0; k < len; k++) sea.set(Math.round(x) + k, y, m);
  }
}
// horizon line glow
for (let x = 0; x < W; x++) sea.set(x, 0, mix(hex('#ffd38a'), sea.get(x, 0), Math.abs(x - SUN_X) / 200));

// ---------------------------------------------------------------- quantize BGs
// BG palettes 2-4 (CGRAM 32-79); palettes 0-1 belong to the text layer.
const cloudPal = C.quantizedPal ? null : gfx.fitPalette(clouds, 16);
const sunPal = gfx.fitPalette(sunR, 16);
const seaPal = gfx.fitPalette(sea, 16, SPARK.map((c) => c.slice(0, 3)));

const keys = new Map(), tiles = [];
gfx.tilemap(new Raster(8, 8), [[0, 0, 0]], 4, { keys, tiles });             // tile 0: empty
const bg2Top = gfx.tilemap(clouds, cloudPal, 4, { keys, tiles, flip: true, pal: 2 });
const bg2Bot = gfx.tilemap(sunR, sunPal, 4, { keys, tiles, flip: true, pal: 3 });
const bg1Sea = gfx.tilemap(sea, seaPal, 4, { keys, tiles, flip: true, pal: 4 });
const fullMap = (rowsBefore, map) => {
  const m = new Array(32 * 32).fill(0);
  map.forEach((v, i) => { m[rowsBefore * 32 + i] = v; });
  return gfx.mapBytes(m);
};
const bg2Map = new Array(32 * 32).fill(0);
bg2Top.map.forEach((v, i) => { bg2Map[i] = v; });
bg2Bot.map.forEach((v, i) => { bg2Map[9 * 32 + i] = v; });
C.writeBin('title_bg.chr', Buffer.concat(tiles));
C.writeBin('title_bg1.map', fullMap(16, bg1Sea.map));
C.writeBin('title_bg2.map', gfx.mapBytes(bg2Map));
if (tiles.length > 1024) throw new Error(`title uses ${tiles.length} BG tiles`);

// ---------------------------------------------------------------- sprites
const sheet = new C.SpriteSheet();

// Logo: YACHT in chunky gold letters with a navy outline and a drop shadow.
// Body colors are indexed by (vertical level, diagonal band) so the game can
// run a glint across the letters by brightening one band at a time.
const LW = 224, LH = 64;
const mask = new Float32Array(LW * LH);
function strokeMask(x0, y0, x1, y1, wdt) {
  const tmp = new Raster(LW, LH);
  tmp.line(x0, y0, x1, y1, wdt, [255, 255, 255, 255]);
  for (let i = 0; i < LW * LH; i++) mask[i] = Math.max(mask[i], tmp.data[i * 4 + 3] / 255);
}
function arcMask(cx, cy, r, a0, a1, wdt) {
  const steps = 40;
  for (let i = 0; i < steps; i++) {
    const t0 = a0 + ((a1 - a0) * i) / steps, t1 = a0 + ((a1 - a0) * (i + 1)) / steps;
    strokeMask(cx + r * Math.cos(t0), cy + r * Math.sin(t0), cx + r * Math.cos(t1), cy + r * Math.sin(t1), wdt);
  }
}
const SW = 9, TOP = 10, BOT = 50;
let lx = 8;
// Y
strokeMask(lx + 4, TOP + 4, lx + 18, TOP + 22, SW); strokeMask(lx + 32, TOP + 4, lx + 18, TOP + 22, SW);
strokeMask(lx + 18, TOP + 22, lx + 18, BOT - 4, SW); lx += 42;
// A
strokeMask(lx + 2, BOT - 4, lx + 17, TOP + 4, SW); strokeMask(lx + 32, BOT - 4, lx + 17, TOP + 4, SW);
strokeMask(lx + 9, TOP + 27, lx + 25, TOP + 27, SW - 2); lx += 42;
// C
arcMask(lx + 18, (TOP + BOT) / 2, 15, Math.PI * 0.28, Math.PI * 1.72, SW); lx += 38;
// H
strokeMask(lx + 4, TOP + 4, lx + 4, BOT - 4, SW); strokeMask(lx + 30, TOP + 4, lx + 30, BOT - 4, SW);
strokeMask(lx + 4, (TOP + BOT) / 2, lx + 30, (TOP + BOT) / 2, SW - 1); lx += 42;
// T
strokeMask(lx + 2, TOP + 4, lx + 36, TOP + 4, SW); strokeMask(lx + 19, TOP + 4, lx + 19, BOT - 4, SW);
const on = (x, y) => x >= 0 && y >= 0 && x < LW && y < LH && mask[y * LW + x] >= 0.5;
const LOGO_LEVELS = [hex('#fff4c0'), hex('#ffcf5a'), hex('#e88a24')];   // top, mid, bottom
const logoPal = [[0, 0, 0], hex('#0e0c2a').slice(0, 3), hex('#2a1236').slice(0, 3)];
for (let lv = 0; lv < 3; lv++) for (let b = 0; b < 4; b++) logoPal.push(LOGO_LEVELS[lv].slice(0, 3));
logoPal.push(hex('#ffffff').slice(0, 3));               // 15: top edge highlight
const logo = new Raster(LW, LH);
const logoIdx = new Uint8Array(LW * LH);
for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) {
  let v = 0;
  if (on(x, y)) {
    if (!on(x, y - 1) || !on(x, y - 2)) v = 15;
    else {
      const lv = y < TOP + 16 ? 0 : y < TOP + 28 ? 1 : 2;
      const band = Math.floor((x + y) / 6) & 3;
      v = 3 + lv * 4 + band;
    }
  } else {
    let near = false;
    for (let dy = -2; dy <= 2 && !near; dy++) for (let dx = -2; dx <= 2 && !near; dx++) if (dx * dx + dy * dy <= 5 && on(x + dx, y + dy)) near = true;
    if (near) v = 1;
    else if (on(x - 3, y - 3) || on(x - 2, y - 3) || on(x - 3, y - 2)) v = 2;
  }
  logoIdx[y * LW + x] = v;
  if (v) logo.set(x, y, [...logoPal[v], 255]);
}
// encode logo cells straight from the index grid (palette is exact)
const logoParts = C.cutMeta(sheet, logo, logoPal, 32, LW / 2, 0);   // offsets from the center: dx must fit a signed byte

// Sailboat, lit from the right by the sun.
const boat = new Raster(64, 64);
const SAIL_HI = hex('#fff1d6'), SAIL_MID = hex('#f2c9a0'), SAIL_SH = hex('#b88a8c'), RIM = hex('#ffb060');
boat.polygon([[30, 4], [30, 44], [6, 44]], (x, y) => mix(SAIL_SH, SAIL_MID, Math.min(1, (x - 6) / 26)));      // mainsail
boat.polygon([[33, 8], [33, 44], [54, 44]], (x, y) => mix(SAIL_MID, SAIL_HI, Math.min(1, (x - 33) / 14)));    // jib
boat.line(53, 44, 33, 9, 1.2, RIM);
boat.line(31.5, 2, 31.5, 47, 1.6, hex('#5a3418'));                                                            // mast
boat.polygon([[31, 2], [39, 4], [31, 6]], hex('#e0303c'));                                                    // pennant
boat.polygon([[4, 46], [60, 46], [54, 54], [10, 54]], (x, y) => mix(hex('#3a1a2a'), hex('#1a0c1c'), (y - 46) / 8));   // hull
boat.line(6, 47.5, 58, 47.5, 1.4, hex('#ffcf5a'));                                                            // gold stripe
boat.line(10, 55, 54, 55, 1.0, hex('#ffe0b0', 160));                                                          // waterline glint
const boatPal = gfx.fitPalette(boat, 16);
const boatParts = C.cutMeta(sheet, boat, boatPal, 32);

// Gulls (2 frames) and the cursor die, sharing one palette.
const misc = new Raster(64, 16);
const GULL = hex('#2c1838');
// wings up
misc.line(2, 9, 7, 5, 1.4, GULL); misc.line(7, 5, 8, 9, 1.3, GULL);
misc.line(8, 9, 9, 5, 1.3, GULL); misc.line(9, 5, 14, 9, 1.4, GULL);
// wings level
misc.line(18, 7, 24, 8, 1.4, GULL); misc.line(24, 8, 30, 7, 1.4, GULL); misc.circle(24, 8.5, 1.1, GULL);
// cursor die, 14x14, showing a gold pip
misc.roundRect(33, 1, 14, 14, 3, hex('#5a1e28'));
misc.roundRect(33, 1, 13, 13, 3, (x, y) => mix(hex('#fffaf0'), hex('#d8c8b0'), (x - 33 + y - 1) / 26));
misc.circle(39.5, 7.5, 2.2, hex('#d02434'));
const miscPal = gfx.fitPalette(misc, 16);
const gullUp = sheet.add(misc, 0, 0, 16, miscPal);
const gullLevel = sheet.add(misc, 16, 0, 16, miscPal);
const cursorDie = sheet.add(misc, 32, 0, 16, miscPal);

C.writeBin('title_spr.chr', sheet.bytes());
let inc = '';
inc += C.metaAsm('MetaLogo', logoParts, 0, 2);
inc += C.metaAsm('MetaBoat', boatParts, 1, 2);
inc += `MetaGullUp:\n  .db 1\n  .db 0, 0, ${gullUp & 255}, ${(2 << 4) | (2 << 1) | (gullUp >> 8)}, 0\n`;
inc += `MetaGullLevel:\n  .db 1\n  .db 0, 0, ${gullLevel & 255}, ${(2 << 4) | (2 << 1) | (gullLevel >> 8)}, 0\n`;
inc += `MetaCursor:\n  .db 1\n  .db 0, 0, ${cursorDie & 255}, ${(3 << 4) | (2 << 1) | (cursorDie >> 8)}, 0\n`;
C.writeInc('title_meta.inc', inc);

// Palettes for colors 32-255 (BG palettes 2-7, sprite palettes 0-7).
const cg = new Array(256).fill([0, 0, 0]);
const put = (base, pal) => pal.forEach((c, i) => { cg[base + i] = c; });
put(32, cloudPal); put(48, sunPal); put(64, seaPal);
put(128, logoPal); put(144, boatPal); put(160, miscPal);
C.writeBin('title.pal', gfx.paletteBytes(cg.slice(32), 224));
// logo glint colors per level (normal, bright) for the runtime sweep
const lvl = (c) => gfx.toBGR555(...c.slice(0, 3));
const bright = (c) => lvl(mix(c, hex('#ffffff'), 0.6));
C.writeInc('title_consts.inc', [
  `.DEFINE TITLE_SPARK_COLOR ${64 + 1}`,
  ...LOGO_LEVELS.map((c, i) => `.DEFINE LOGO_LV${i} $${lvl(c).toString(16)}\n.DEFINE LOGO_LV${i}_HI $${bright(c).toString(16)}`),
  `.DEFINE SPARK_A $${lvl(hex('#ffd27a')).toString(16)}`,
  `.DEFINE SPARK_B $${lvl(hex('#fff8e0')).toString(16)}`,
  `.DEFINE SPARK_C $${lvl(hex('#b0606a')).toString(16)}`,
  '',
].join('\n'));

// Sea sway: 64 phases x 96 lines of signed horizontal offsets. Two swells at
// different speeds; the swing grows from 1 px at the horizon to 6 px up close.
const waves = Buffer.alloc(64 * 96);
for (let p = 0; p < 64; p++) for (let i = 0; i < 96; i++) {
  const t = i / 95, amp = 0.8 + t * t * 5.5;
  const a = (2 * Math.PI * p) / 64;
  const v = amp * (0.65 * Math.sin(a + i * (0.55 - t * 0.35)) + 0.35 * Math.sin(2 * a - i * 0.21 + 1.1));
  waves.writeInt8(Math.round(v), p * 96 + i);
}
C.writeBin('title_waves.bin', waves);

// Sine table for bobbing and flight paths: 256 entries, -127..127.
const sine = Buffer.alloc(256);
for (let i = 0; i < 256; i++) sine.writeInt8(Math.round(127 * Math.sin((2 * Math.PI * i) / 256)), i);
C.writeBin('sine.bin', sine);

// ---------------------------------------------------------------- preview
const pv = new Raster(W, H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) pv.set(x, y, [...(y < HORIZON ? skyLines[y] : [0, 0, 0]), 255]);
pv.blit(C.quantized(clouds, cloudPal), 0, 0);
pv.blit(C.quantized(sunR, sunPal), 0, 72);
const seaQ = C.quantized(sea, seaPal);
// show the glitter in its three run-time colors
for (let y = 0; y < seaQ.h; y++) for (let x = 0; x < seaQ.w; x++) {
  const i = gfx.indexOf(sea.get(x, y), seaPal);
  if (i >= 1 && i <= 3) seaQ.set(x, y, [...[hex('#ffd27a'), hex('#fff8e0'), hex('#b0606a')][i - 1].slice(0, 3), 255]);
}
pv.blit(seaQ, 0, HORIZON);
pv.blit(logo, 16, 14);
pv.blit(C.quantized(boat, boatPal), 34, 104);
pv.blit(C.quantized(misc.crop(0, 0, 16, 16), miscPal), 120, 70);
pv.blit(C.quantized(misc.crop(16, 0, 16, 16), miscPal), 140, 62);
C.previewPng('title.png', pv);
C.previewPng('title_3x.png', C.scale(pv, 3));
console.log(`title: ${tiles.length} BG tiles, ${sheet.bytes().length / 32} sprite tiles`);
