// Turns the screenshots in an autotest log (SHOT name w h / R<hex row>... /
// ENDSHOT, RGBA5551 pixels) into PNGs: build/shots/<name>.png and a 2x copy
// in build/shots/big/.  Usage: node tools/shots.js <log>
const fs = require('fs');
const path = require('path');
const png = require('../../../snes/yacht/tools/png');

const OUT = path.join(__dirname, '../build/shots');
fs.mkdirSync(path.join(OUT, 'big'), { recursive: true });
const lines = fs.readFileSync(process.argv[2], 'latin1').split(/\r?\n/);
let shot = null;
const names = [];
for (const line of lines) {
  let m;
  if ((m = /^SHOT (\S+) (\d+) (\d+)/.exec(line))) { shot = { name: m[1], w: +m[2], h: +m[3], rows: [] }; continue; }
  if (shot && line.startsWith('R')) { shot.rows.push(line.slice(1)); continue; }
  if (shot && line.startsWith('ENDSHOT')) {
    const { w, h } = shot;
    const rgba = Buffer.alloc(w * h * 4);
    for (let y = 0; y < Math.min(h, shot.rows.length); y++) for (let x = 0; x < w; x++) {
      const v = parseInt(shot.rows[y].substr(x * 4, 4), 16) || 0;
      const i = (y * w + x) * 4;
      rgba[i] = ((v >> 11) & 31) * 255 / 31; rgba[i + 1] = ((v >> 6) & 31) * 255 / 31;
      rgba[i + 2] = ((v >> 1) & 31) * 255 / 31; rgba[i + 3] = 255;
    }
    png.write(path.join(OUT, shot.name + '.png'), w, h, rgba);
    const big = Buffer.alloc(w * h * 16);
    for (let y = 0; y < h * 2; y++) for (let x = 0; x < w * 2; x++)
      rgba.copy(big, (y * w * 2 + x) * 4, ((y >> 1) * w + (x >> 1)) * 4, ((y >> 1) * w + (x >> 1)) * 4 + 4);
    png.write(path.join(OUT, 'big', shot.name + '.png'), w * 2, h * 2, big);
    names.push(shot.name);
    shot = null;
  }
}
console.log('shots: ' + (names.join(' ') || 'none'));
