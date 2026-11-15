// Turns Raster art into SNES data: BGR555 palettes, planar 2bpp/4bpp tiles,
// and tilemaps with duplicate and mirrored tiles folded together.
const toBGR555 = (r, g, b) => ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3);

// Rounds a color to what the SNES can show (5 bits per channel).
const snap = (c) => c.slice(0, 3).map((v) => ((Math.round(v) >> 3) << 3) | (Math.round(v) >> 5));

function paletteBytes(pal, n = pal.length) {
  const b = Buffer.alloc(n * 2);
  for (let i = 0; i < n; i++) {
    const c = pal[i] || [0, 0, 0];
    b.writeUInt16LE(toBGR555(c[0], c[1], c[2]), i * 2);
  }
  return b;
}

// Median cut over the opaque pixels. Index 0 is kept for transparency; colors in
// `fixed` take the next slots. Returns exactly n colors.
function fitPalette(raster, n, fixed = []) {
  const px = [];
  for (let y = 0; y < raster.h; y++) for (let x = 0; x < raster.w; x++) {
    const c = raster.get(x, y);
    if (c[3] >= 128) px.push(snap(c));
  }
  const want = n - 1 - fixed.length;
  let boxes = px.length ? [px] : [];
  while (boxes.length < want) {
    let bi = -1, bestRange = 0, bestCh = 0;
    boxes.forEach((b, i) => {
      if (b.length < 2) return;
      for (let ch = 0; ch < 3; ch++) {
        let lo = 255, hi = 0;
        for (const p of b) { lo = Math.min(lo, p[ch]); hi = Math.max(hi, p[ch]); }
        if (hi - lo > bestRange) { bestRange = hi - lo; bi = i; bestCh = ch; }
      }
    });
    if (bi < 0) break;
    const b = boxes[bi].sort((p, q) => p[bestCh] - q[bestCh]);
    const mid = b.length >> 1;
    boxes.splice(bi, 1, b.slice(0, mid), b.slice(mid));
  }
  const pal = [[0, 0, 0], ...fixed.map(snap)];
  for (const b of boxes) {
    const avg = [0, 0, 0];
    for (const p of b) for (let ch = 0; ch < 3; ch++) avg[ch] += p[ch];
    pal.push(snap(avg.map((v) => v / b.length)));
  }
  while (pal.length < n) pal.push([0, 0, 0]);
  return pal.slice(0, n);
}

// Nearest palette index for a pixel; transparent pixels are index 0.
function indexOf(c, pal) {
  if (c[3] < 128) return 0;
  let best = 1, bd = Infinity;
  for (let i = 1; i < pal.length; i++) {
    const p = pal[i];
    // weighted distance, green matters most to the eye
    const d = 3 * (c[0] - p[0]) ** 2 + 4 * (c[1] - p[1]) ** 2 + 2 * (c[2] - p[2]) ** 2;
    if (d < bd) { bd = d; best = i; }
  }
  return best;
}

// Index grid for an 8x8 tile at (tx, ty) in pixels.
function tileIndices(raster, pal, tx, ty) {
  const t = new Uint8Array(64);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) t[y * 8 + x] = indexOf(raster.get(tx + x, ty + y), pal);
  return t;
}

function encodeTile(idx, bpp) {
  const out = Buffer.alloc(bpp * 8);
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 8; x++) {
      const v = idx[y * 8 + x], bit = 0x80 >> x;
      if (v & 1) out[y * 2] |= bit;
      if (v & 2) out[y * 2 + 1] |= bit;
      if (bpp === 4) {
        if (v & 4) out[16 + y * 2] |= bit;
        if (v & 8) out[16 + y * 2 + 1] |= bit;
      }
    }
  }
  return out;
}

// All 8x8 tiles of the raster, left to right, top to bottom.
function encodeTiles(raster, pal, bpp) {
  const parts = [];
  for (let ty = 0; ty < raster.h; ty += 8)
    for (let tx = 0; tx < raster.w; tx += 8) parts.push(encodeTile(tileIndices(raster, pal, tx, ty), bpp));
  return Buffer.concat(parts);
}

// Sprite sheets: tiles laid out for 16x16 or 32x32 sprites in a 16-tile-wide VRAM
// grid. `cells` is a list of [x, y] pixel positions of each sprite in the raster.
function encodeSprites(raster, pal, bpp, size, cells) {
  const per = size / 8;
  const grid = [];
  cells.forEach(([sx, sy], n) => {
    const baseCol = (n * per) % 16, baseRow = Math.floor((n * per) / 16) * per;
    for (let r = 0; r < per; r++) for (let c = 0; c < per; c++) {
      grid[(baseRow + r) * 16 + baseCol + c] = encodeTile(tileIndices(raster, pal, sx + c * 8, sy + r * 8), bpp);
    }
  });
  const blank = Buffer.alloc(bpp * 8);
  const out = [];
  for (let i = 0; i < grid.length; i++) out.push(grid[i] || blank);
  return Buffer.concat(out);
}

const flipH = (t) => { const o = new Uint8Array(64); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) o[y * 8 + x] = t[y * 8 + 7 - x]; return o; };
const flipV = (t) => { const o = new Uint8Array(64); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) o[y * 8 + x] = t[(7 - y) * 8 + x]; return o; };

// Builds unique tiles and a tilemap (16-bit entries) for the whole raster.
// opts: flip (fold mirrored tiles), base (first tile number), pal (palette
// number 0-7), prio (priority bit), tiles/keys (existing set to extend).
function tilemap(raster, pal, bpp, opts = {}) {
  const base = opts.base || 0, palBits = (opts.pal || 0) << 10, prio = opts.prio ? 0x2000 : 0;
  const keys = opts.keys || new Map();
  const tiles = opts.tiles || [];
  const map = [];
  for (let ty = 0; ty < raster.h; ty += 8) {
    for (let tx = 0; tx < raster.w; tx += 8) {
      const t = tileIndices(raster, pal, tx, ty);
      const variants = opts.flip
        ? [[t, 0], [flipH(t), 0x4000], [flipV(t), 0x8000], [flipH(flipV(t)), 0xC000]]
        : [[t, 0]];
      let entry = -1;
      for (const [v, bits] of variants) {
        const k = v.join(',');
        if (keys.has(k)) { entry = keys.get(k) | bits; break; }
      }
      if (entry < 0) {
        const num = base + tiles.length;
        keys.set(t.join(','), num);
        tiles.push(encodeTile(t, bpp));
        entry = num;
      }
      map.push(entry | palBits | prio);
    }
  }
  return { tiles: Buffer.concat(tiles), map, keys, tileList: tiles };
}

function mapBytes(map) {
  const b = Buffer.alloc(map.length * 2);
  map.forEach((v, i) => b.writeUInt16LE(v, i * 2));
  return b;
}

module.exports = { toBGR555, snap, paletteBytes, fitPalette, indexOf, encodeTiles, encodeSprites, tilemap, mapBytes, tileIndices, encodeTile };
