// Game screen art: a captain's table.
//   BG2      mahogany planks, with the soft shadows of everything lying on them
//   BG1      parchment scorecard (left), felt dice tray and brass-rimmed plaques (right)
//   sprites  dice (6 faces, held versions with a HOLD tag, 3 tumble frames),
//            die shadow, die selector, roll pips
const gfx = require('../snesgfx');
const { Raster, mix, lerpStops, hex } = require('../raster');
const C = require('./common');

const W = 256, H = 224;
// Layout (also used by game.s through game_consts.inc)
const CARD = { x: 2, y: 4, w: 148, h: 210 };
const BANNER = { x: 154, y: 2, w: 100, h: 20 };
const TRAY = { x: 154, y: 24, w: 100, h: 90 };
const PLAQUE = { x: 154, y: 116, w: 100, h: 104 };
// sprite positions of the five dice (the die body sits 3 px in, 1 px down)
const DIE_X = [157, 189, 221, 173, 205], DIE_Y = [34, 34, 34, 70, 70];   // centered in the felt

// Deterministic noise, tileable with period p.
function noise(x, y, p = 16, seed = 1) {
  const h = (a, b) => {
    let n = (((a % p) + p) % p) * 374761393 + (((b % p) + p) % p) * 668265263 + seed * 2654435761;
    n = (n ^ (n >>> 13)) * 1274126177;
    return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
  };
  return h(x, y);
}

// ---------------------------------------------------------------- BG2: wood
const wood = new Raster(W, H);
const PLANK = 28;
for (let y = 0; y < H; y++) {
  const plank = Math.floor(y / PLANK), py = y % PLANK;
  const tone = [hex('#6a3420'), hex('#5c2c1a'), hex('#73391f'), hex('#552814')][plank % 4];
  for (let x = 0; x < W; x++) {
    // grain: long wavy lines, repeating every 64 px across so tiles repeat
    const g = Math.sin((x / 64) * 2 * Math.PI * 2 + py * 0.9 + plank * 1.7) * 0.5 +
      Math.sin((x / 64) * 2 * Math.PI + py * 0.35 + plank) * 0.5;
    let c = mix(tone, hex('#2e140a'), Math.max(0, g - 0.45) * 0.9);
    c = mix(c, hex('#8a4a2a'), Math.max(0, -g - 0.7) * 1.2);
    if (py === 0) c = hex('#1e0c06');                  // gap between planks
    if (py === 1) c = mix(c, hex('#9a5a36'), 0.35);    // lit plank edge
    // nail heads every 64 px
    const nx = ((x + plank * 32) % 64) - 6;
    if ((py === 5 || py === PLANK - 6) && nx >= 0 && nx < 2) c = hex('#2a1810');
    wood.set(x, y, c);
  }
}
// shadows of the card and panels on the table
function dropShadow(r, box, dx, dy, rad) {
  const s = new Raster(W, H);
  s.roundRect(box.x + dx, box.y + dy, box.w, box.h, rad, [0, 0, 0, 255]);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const a = s.get(x, y)[3] / 255;
    if (a > 0) { const c = r.get(x, y); r.set(x, y, mix(c, hex('#140804'), 0.55 * a)); }
  }
}
for (const b of [CARD, BANNER, TRAY, PLAQUE]) dropShadow(wood, b, 3, 4, 6);

// ---------------------------------------------------------------- BG1: card, tray, plaques
const card = new Raster(W, H);
// parchment with darker edges and alternating row bands
const ROW0 = 24, ROWH = 16, RULE_L = 87, RULE_M = 116;
card.roundRect(CARD.x, CARD.y, CARD.w, CARD.h, 6, (x, y) => {
  const ex = Math.min(x - CARD.x, CARD.x + CARD.w - x), ey = Math.min(y - CARD.y, CARD.y + CARD.h - y);
  const edge = Math.max(0, 1 - Math.min(ex, ey) / 10);
  let c = mix(hex('#f4e7c6'), hex('#d7bf8c'), edge * 0.8 + noise(x, y, 16, 3) * 0.12);
  const row = Math.floor((y - ROW0 + 4) / ROWH);
  if (y >= ROW0 - 4 && row >= 0 && row < 12 && row % 2 === 1) c = mix(c, hex('#d9c290'), 0.35);
  if (y < ROW0 - 5) c = mix(c, hex('#b48a52'), 0.45);                            // header band
  if (y >= ROW0 - 4 && (y - ROW0 + 4) % ROWH === 0 && x > CARD.x + 4 && x < CARD.x + CARD.w - 4)
    c = mix(c, hex('#a88a5c'), 0.5);                                               // row rules
  // column rules: just right of the box names (columns 1-10) and in the gap between the
  // players' columns (text columns 11-13 and 15-17), so the names sit between them
  if ((x === RULE_L || x === RULE_M) && y > CARD.y + 3 && y < CARD.y + CARD.h - 4) c = mix(c, hex('#a88a5c'), 0.6);
  return c;
});
// a red-inked border line inside the card edge
card.shape(CARD.x, CARD.y, CARD.x + CARD.w, CARD.y + CARD.h, (x, y) => {
  const ix = x - CARD.x - 3.5, iy = y - CARD.y - 3.5, w = CARD.w - 7, h = CARD.h - 7;
  const inside = ix >= 0 && iy >= 0 && ix <= w && iy <= h;
  const nearEdge = ix < 1.1 || iy < 1.1 || ix > w - 1.1 || iy > h - 1.1;
  return inside && nearEdge;
}, hex('#9a3a2a'));

// brass-rimmed panels
function brassPanel(r, b, fill) {
  r.roundRect(b.x, b.y, b.w, b.h, 6, (x, y) => mix(hex('#f6dc8a'), hex('#8a5a1c'), (y - b.y) / b.h));
  r.roundRect(b.x + 1, b.y + 1, b.w - 2, b.h - 2, 5, (x, y) => mix(hex('#e8c060'), hex('#a8762a'), (x - b.x + y - b.y) / (b.w + b.h)));
  r.roundRect(b.x + 3, b.y + 3, b.w - 6, b.h - 6, 4, hex('#5a3a12'));
  r.roundRect(b.x + 4, b.y + 4, b.w - 8, b.h - 8, 3, fill);
}
const felt = (x, y) => {
  const t = Math.hypot((x - (TRAY.x + TRAY.w / 2)) / TRAY.w, (y - (TRAY.y + TRAY.h / 2)) / TRAY.h);
  let c = mix(hex('#2a8048'), hex('#12482a'), Math.min(1, t * 1.6));
  c = mix(c, hex('#0c3a20'), noise(x, y, 8, 7) * 0.25);
  // inner shadow along the top and left
  const it = y - (TRAY.y + 4), il = x - (TRAY.x + 4);
  if (it < 4) c = mix(c, hex('#082414'), (4 - it) / 6);
  if (il < 3) c = mix(c, hex('#082414'), (3 - il) / 6);
  return c;
};
const navy = (x, y) => mix(hex('#222c54'), hex('#1a2246'), (y - PLAQUE.y) / PLAQUE.h + noise(x, y, 8, 5) * 0.1);
brassPanel(card, TRAY, felt);
brassPanel(card, BANNER, (x, y) => mix(hex('#2c386a'), hex('#1a2244'), (y - BANNER.y) / BANNER.h));
brassPanel(card, PLAQUE, navy);
// thin brass divider in the plaque between the rolls row and the totals
for (let x = PLAQUE.x + 10; x < PLAQUE.x + PLAQUE.w - 10; x++) {
  card.set(x, PLAQUE.y + 22, hex('#c89a3a'));
  card.set(x, PLAQUE.y + 23, hex('#3a2a10'));
  card.set(x, PLAQUE.y + 64, hex('#c89a3a'));
  card.set(x, PLAQUE.y + 65, hex('#3a2a10'));
}

// split BG1 by palette: the card (palette 3), the tray (4), banner + plaque (5)
const region = (b, src) => {
  const r = new Raster(W, H);
  for (let y = b.y; y < b.y + b.h; y++) for (let x = b.x; x < b.x + b.w; x++) r.set(x, y, src.get(x, y));
  return r;
};
const cardR = region(CARD, card), trayR = region(TRAY, card), plaqueR = region({ x: 154, y: 0, w: 102, h: 224 }, card);
for (let y = TRAY.y; y < TRAY.y + TRAY.h; y++) for (let x = TRAY.x; x < TRAY.x + TRAY.w; x++) plaqueR.set(x, y, [0, 0, 0, 0]);

const woodPal = gfx.fitPalette(C.dither(wood, 8), 16);
const cardPal = gfx.fitPalette(cardR, 16);
const trayPal = gfx.fitPalette(trayR, 16);
const plaquePal = gfx.fitPalette(plaqueR, 16);

// Tilemaps: BG1 is assembled tile by tile, taking each tile from whichever
// region covers it (they never share a tile).
const keys = new Map(), tiles = [];
gfx.tilemap(new Raster(8, 8), [[0, 0, 0]], 4, { keys, tiles });
const woodMap = gfx.tilemap(C.dither(wood, 8), woodPal, 4, { keys, tiles, flip: true, pal: 2 }).map;
const cardMap = gfx.tilemap(cardR, cardPal, 4, { keys, tiles, flip: true, pal: 3 }).map;
const trayMap = gfx.tilemap(trayR, trayPal, 4, { keys, tiles, flip: true, pal: 4 }).map;
const plaqueMap = gfx.tilemap(plaqueR, plaquePal, 4, { keys, tiles, flip: true, pal: 5 }).map;
const bg1 = cardMap.map((v, i) => (trayMap[i] & 0x3FF ? trayMap[i] : plaqueMap[i] & 0x3FF ? plaqueMap[i] : v));
const full = (m) => { const o = new Array(1024).fill(0); m.forEach((v, i) => { o[i] = v; }); return gfx.mapBytes(o); };
C.writeBin('game_bg.chr', Buffer.concat(tiles));
C.writeBin('game_bg1.map', full(bg1));
C.writeBin('game_bg2.map', full(woodMap));
if (tiles.length > 1024) throw new Error(`game screen uses ${tiles.length} BG tiles`);

// ---------------------------------------------------------------- dice
const PIPS = { 1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
  5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]] };
// Renders a die (26 px, rounded) rotated by `ang`, centered at (cx, cy).
function drawDie(r, cx, cy, face, ang, held) {
  const S = 26, half = S / 2, cos = Math.cos(ang), sin = Math.sin(ang);
  const body0 = held ? hex('#fff6d0') : hex('#fffdf6'), body1 = held ? hex('#e8c46a') : hex('#cfc6b8');
  const local = (x, y) => [(x - cx) * cos + (y - cy) * sin, -(x - cx) * sin + (y - cy) * cos];
  const inRound = (u, v, h, rad) => {
    const qx = Math.max(Math.abs(u) - (h - rad), 0), qy = Math.max(Math.abs(v) - (h - rad), 0);
    return qx * qx + qy * qy <= rad * rad;
  };
  // outline
  r.shape(cx - 20, cy - 20, cx + 20, cy + 20, (x, y) => { const [u, v] = local(x, y); return inRound(u, v, half + 1, 6); },
    held ? hex('#7a4a10') : hex('#3a3040'));
  // body with light from the top-left and a soft bevel
  r.shape(cx - 20, cy - 20, cx + 20, cy + 20, (x, y) => { const [u, v] = local(x, y); return inRound(u, v, half, 5); }, (x, y) => {
    const [u, v] = local(x + 0.5, y + 0.5);
    const t = Math.min(1, Math.max(0, (u + v + S) / (2 * S)));
    let c = mix(body0, body1, t * 0.9);
    const edge = half - Math.max(Math.abs(u), Math.abs(v));
    if (edge < 2.2) c = mix(c, u + v < 0 ? hex('#ffffff') : body1, 0.5);
    return c;
  });
  for (const [gx, gy] of PIPS[face]) {
    const pu = (gx - 1) * 7, pv = (gy - 1) * 7;
    const one = face === 1;
    const rad = one ? 3.6 : 2.4;
    const ink = one ? hex('#c8202c') : hex('#1c1a30');
    r.shape(cx - 20, cy - 20, cx + 20, cy + 20, (x, y) => { const [u, v] = local(x, y); return (u - pu) ** 2 + (v - pv) ** 2 <= rad * rad; }, (x, y) => {
      const [u, v] = local(x + 0.5, y + 0.5);
      return (u - pu) + (v - pv) > rad * 0.6 ? mix(ink, hex('#ffffff'), 0.25) : ink;   // a glint in each pip
    });
  }
}
function tag(r, ox, oy) {   // tiny HOLD tag under a held die
  r.roundRect(ox + 4, oy + 26, 24, 6, 2, hex('#c8202c'));
  const L = { H: ['1.1', '111', '1.1'], O: ['111', '1.1', '111'], L: ['1..', '1..', '111'], D: ['11.', '1.1', '11.'] };
  let x = ox + 7;
  for (const ch of 'HOLD') {
    L[ch].forEach((row, yy) => [...row].forEach((p, xx) => { if (p === '1') r.set(x + xx, oy + 27 + yy, hex('#fff6d0')); }));
    x += 5;
  }
}

const sheet = new C.SpriteSheet();
const dieR = new Raster(32 * 16, 32);
const diePal = [[0, 0, 0]];
const cells = [];
for (let f = 1; f <= 6; f++) drawDie(dieR, (f - 1) * 32 + 16, 14, f, 0, false);
for (let f = 1; f <= 6; f++) { drawDie(dieR, (f + 5) * 32 + 16, 14, f, 0, true); tag(dieR, (f + 5) * 32, 0); }
[[3, 0.35], [5, 0.8], [2, 1.2]].forEach(([f, a], i) => drawDie(dieR, (12 + i) * 32 + 16, 15, f, a, false));
// shadow (opaque, felt-colored: dice only ever sit on the felt) and the selector frame
dieR.ellipse(15 * 32 + 16, 26, 13, 4, hex('#0c3a1e'));
const normalPal = gfx.fitPalette(dieR.crop(0, 0, 32 * 6, 32), 16);
const heldPal = gfx.fitPalette(dieR.crop(32 * 6, 0, 32 * 6, 32), 16);
const tumblePal = normalPal;
const dieTiles = [];
for (let i = 0; i < 6; i++) dieTiles.push(sheet.add(dieR, i * 32, 0, 32, normalPal));
for (let i = 6; i < 12; i++) dieTiles.push(sheet.add(dieR, i * 32, 0, 32, heldPal));
for (let i = 12; i < 15; i++) dieTiles.push(sheet.add(dieR, i * 32, 0, 32, tumblePal));

const misc = new Raster(64, 32);
misc.ellipse(16, 26, 13, 4, hex('#0c3a1e'));                      // die shadow
// selector: four gold corner brackets
for (const [sx, sy] of [[1, 1], [30, 1], [1, 30], [30, 30]]) {
  const dx = sx < 16 ? 1 : -1, dy = sy < 16 ? 1 : -1;
  misc.line(32 + sx, sy, 32 + sx + dx * 7, sy, 2.2, hex('#ffd24a'));
  misc.line(32 + sx, sy, 32 + sx, sy + dy * 7, 2.2, hex('#ffd24a'));
}
const miscPal = gfx.fitPalette(misc, 16);
const shadowTile = sheet.add(misc, 0, 0, 32, miscPal);
const selTile = sheet.add(misc, 32, 0, 32, miscPal);
// roll pip icon: a small die, lit (palette 3) or spent (palette 4 is a dim copy)
const pip = new Raster(16, 16);
pip.roundRect(2, 2, 12, 12, 3, hex('#3a3040'));
pip.roundRect(2, 2, 11, 11, 3, (x, y) => mix(hex('#fffdf6'), hex('#cfc6b8'), (x + y - 4) / 22));
pip.circle(7.5, 7.5, 1.8, hex('#c8202c'));
const pipPal = gfx.fitPalette(pip, 16);
const pipDim = pipPal.map((c, i) => (i ? mix([...c, 255], hex('#141a34'), 0.65).slice(0, 3) : c));
const pipTile = sheet.add(pip, 0, 0, 16, pipPal);

C.writeBin('game_spr.chr', sheet.bytes());
const cg = new Array(256).fill([0, 0, 0]);
const put = (base, pal) => pal.forEach((c, i) => { cg[base + i] = c; });
put(32, woodPal); put(48, cardPal); put(64, trayPal); put(80, plaquePal);
put(128, normalPal); put(144, heldPal); put(160, miscPal); put(176, pipPal); put(192, pipDim);
C.writeBin('game.pal', gfx.paletteBytes(cg.slice(32), 224));
C.writeInc('game_consts.inc', [
  `.DEFINE TILE_DIE ${dieTiles[0]}`, `.DEFINE TILE_DIE_HELD ${dieTiles[6]}`, `.DEFINE TILE_TUMBLE ${dieTiles[12]}`,
  `.DEFINE TILE_SHADOW ${shadowTile}`, `.DEFINE TILE_SELECT ${selTile}`, `.DEFINE TILE_PIP ${pipTile}`,
  '; die tiles for face n: TILE_DIE + DieTileStep * (n-1), see DieTiles in game.s',
  '',
].join('\n'));
C.writeInc('game_dice.inc', [
  'DieTiles:     .dw ' + dieTiles.slice(0, 6).join(', '),
  'DieTilesHeld: .dw ' + dieTiles.slice(6, 12).join(', '),
  'TumbleTiles:  .dw ' + dieTiles.slice(12, 15).join(', '),
  'DieX:         .db ' + DIE_X.join(', '),
  'DieY:         .db ' + DIE_Y.join(', '),
  '',
].join('\n'));

// ---------------------------------------------------------------- preview
const pv = new Raster(W, H);
pv.blit(C.quantized(C.dither(wood, 8), woodPal), 0, 0);
pv.blit(C.quantized(cardR, cardPal), 0, 0);
pv.blit(C.quantized(trayR, trayPal), 0, 0);
pv.blit(C.quantized(plaqueR, plaquePal), 0, 0);
for (let i = 0; i < 5; i++) {
  pv.blit(C.quantized(misc.crop(0, 0, 32, 32), miscPal), DIE_X[i], DIE_Y[i] + 2);
  const held = i === 1;
  pv.blit(C.quantized(dieR.crop(((held ? 6 : 0) + [4, 2, 6, 6, 1][i] - 1) * 32, 0, 32, 32), held ? heldPal : normalPal), DIE_X[i], DIE_Y[i] - (held ? 3 : 0));
}
pv.blit(C.quantized(misc.crop(32, 0, 32, 32), miscPal), DIE_X[2], DIE_Y[2]);
C.previewPng('game.png', pv);
C.previewPng('game_3x.png', C.scale(pv, 3));
C.previewPng('dice_3x.png', C.scale(C.quantized(dieR, normalPal), 3));
console.log(`game: ${tiles.length} BG tiles, ${sheet.bytes().length / 32} sprite tiles`);
