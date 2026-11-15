const test = require('node:test');
const assert = require('node:assert');
const { Raster } = require('../raster');
const gfx = require('../snesgfx');

test('toBGR555 packs red low, blue high', () => {
  assert.strictEqual(gfx.toBGR555(255, 0, 0), 0x001F);
  assert.strictEqual(gfx.toBGR555(0, 255, 0), 0x03E0);
  assert.strictEqual(gfx.toBGR555(0, 0, 255), 0x7C00);
});

test('4bpp tile with one pixel of color 1 in the corner', () => {
  const r = new Raster(8, 8);
  const pal = [[0, 0, 0], [255, 255, 255]];
  r.fill([0, 0, 0, 0]);
  r.set(0, 0, [255, 255, 255, 255]);
  const t = gfx.encodeTiles(r, pal, 4);
  assert.strictEqual(t.length, 32);
  assert.strictEqual(t[0], 0x80);
  for (let i = 1; i < 32; i++) assert.strictEqual(t[i], 0, `byte ${i}`);
});

test('2bpp tile planes: color 3 sets both planes', () => {
  const r = new Raster(8, 8);
  const pal = [[0, 0, 0], [255, 0, 0], [0, 255, 0], [0, 0, 255]];
  r.fill([0, 0, 0, 0]);
  r.set(7, 1, [0, 0, 255, 255]);
  const t = gfx.encodeTiles(r, pal, 2);
  assert.strictEqual(t.length, 16);
  assert.strictEqual(t[2], 0x01);
  assert.strictEqual(t[3], 0x01);
});

test('tilemap dedupes repeats and finds horizontal mirrors', () => {
  const r = new Raster(24, 8);
  const pal = [[0, 0, 0], [255, 255, 255]];
  r.fill([0, 0, 0, 0]);
  for (const x0 of [0, 8]) r.set(x0 + 1, 2, [255, 255, 255, 255]);
  r.set(16 + 6, 2, [255, 255, 255, 255]);      // mirror of the first tile
  const { tiles, map } = gfx.tilemap(r, pal, 4, { flip: true });
  assert.strictEqual(tiles.length, 32, 'one unique tile');
  assert.strictEqual(map.length, 3);
  assert.strictEqual(map[0] & 0x3FF, 0);
  assert.strictEqual(map[1], map[0]);
  assert.strictEqual(map[2] & 0x4000, 0x4000, 'third tile is H-flipped');
});

test('fitPalette keeps index 0 for transparency and finds the colors present', () => {
  const r = new Raster(16, 16);
  r.fill([0, 0, 0, 0]);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 16; x++) r.set(x, y, [200, 40, 40, 255]);
  for (let y = 8; y < 16; y++) for (let x = 0; x < 16; x++) r.set(x, y, [40, 40, 200, 255]);
  const pal = gfx.fitPalette(r, 16);
  assert.strictEqual(pal.length, 16);
  const near = (c, t) => Math.abs(c[0] - t[0]) + Math.abs(c[1] - t[1]) + Math.abs(c[2] - t[2]) < 24;
  assert.ok(pal.slice(1).some((c) => near(c, [200, 40, 40])), 'red found');
  assert.ok(pal.slice(1).some((c) => near(c, [40, 40, 200])), 'blue found');
});

test('png writer produces a valid PNG signature', () => {
  const png = require('../png');
  const buf = png.encode(2, 2, Buffer.alloc(16, 255));
  assert.deepStrictEqual([...buf.slice(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
});
