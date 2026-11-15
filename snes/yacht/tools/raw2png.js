// Converts the raw RGB frames saved by tests/lib.lua shot() into PNGs.
// Usage: node tools/raw2png.js build/shots
// Also writes a 3x copy of each into <dir>/big/ for looking at details.
const fs = require('fs');
const path = require('path');
const png = require('./png');

const dir = process.argv[2];
for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith('.raw')) continue;
  const buf = fs.readFileSync(path.join(dir, f));
  const nl = buf.indexOf(10);
  const [w, h] = buf.slice(0, nl).toString().split(' ').map(Number);
  const rgb = buf.slice(nl + 1);
  const rgba = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    rgba[i * 4] = rgb[i * 3];
    rgba[i * 4 + 1] = rgb[i * 3 + 1];
    rgba[i * 4 + 2] = rgb[i * 3 + 2];
    rgba[i * 4 + 3] = 255;
  }
  png.write(path.join(dir, f.replace(/\.raw$/, '.png')), w, h, rgba);
  const S = 3, big = Buffer.alloc(w * h * 4 * S * S);
  for (let y = 0; y < h * S; y++) {
    for (let x = 0; x < w * S; x++) {
      const from = (Math.floor(y / S) * w + Math.floor(x / S)) * 4;
      rgba.copy(big, (y * w * S + x) * 4, from, from + 4);
    }
  }
  fs.mkdirSync(path.join(dir, 'big'), { recursive: true });
  png.write(path.join(dir, 'big', f.replace(/\.raw$/, '.png')), w * S, h * S, big);
  fs.unlinkSync(path.join(dir, f));
}
