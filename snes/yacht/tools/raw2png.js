// Converts the raw RGB frames saved by tests/lib.lua shot() into PNGs.
// Usage: node tools/raw2png.js build/shots
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
  fs.unlinkSync(path.join(dir, f));
}
