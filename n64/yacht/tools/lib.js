// Shared helpers for the N64 asset scripts. The drawing canvas and PNG writer
// are the SNES port's (snes/yacht/tools/raster.js, png.js).
const fs = require('fs');
const path = require('path');
const raster = require('../../../snes/yacht/tools/raster');
const png = require('../../../snes/yacht/tools/png');

const ROOT = path.join(__dirname, '..');
const ASSETS = path.join(ROOT, 'build/assets');   // PNG / WAV, converted by the Makefile
const GEN = path.join(ROOT, 'build/gen');         // generated C headers
fs.mkdirSync(ASSETS, { recursive: true });
fs.mkdirSync(GEN, { recursive: true });

function writePng(file, r) { png.write(file, r.w, r.h, Buffer.from(r.data.buffer)); }

// A preview for judging the art: r over a solid background, scaled up k times.
const PREVIEW = path.join(ROOT, "build/preview");
fs.mkdirSync(PREVIEW, { recursive: true });
function preview(name, r, k = 2, bg = [40, 50, 80, 255]) {
  const o = new raster.Raster(r.w * k, r.h * k);
  o.fill(bg);
  for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) {
    const c = r.get(Math.floor(x / k), Math.floor(y / k));
    if (c[3]) o.blend(x, y, c);
  }
  writePng(path.join(PREVIEW, name + ".png"), o);
}

// Smooth value noise in 0..1 (period p pixels), for wood grain, felt and sea.
function noise(x, y, p = 16, seed = 1) {
  const h = (i, j) => {
    let n = (i * 374761393 + j * 668265263 + seed * 2246822519) | 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
  };
  const fx = x / p, fy = y / p, i = Math.floor(fx), j = Math.floor(fy);
  const u = fx - i, v = fy - j, su = u * u * (3 - 2 * u), sv = v * v * (3 - 2 * v);
  const a = h(i, j), b = h(i + 1, j), c = h(i, j + 1), d = h(i + 1, j + 1);
  return a + (b - a) * su + (c - a) * sv + (a - b - c + d) * su * sv;
}

module.exports = { raster, png, writePng, preview, noise, ROOT, ASSETS, GEN };
