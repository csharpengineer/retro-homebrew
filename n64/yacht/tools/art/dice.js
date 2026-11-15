// Die faces for the 3D dice, their soft shadow, and the small 2D die used as the
// menu cursor and the rolls-left counter.
//   die1-6.png     32x32: the faces, ivory with recessed pips
//   shadow.png     48x24: soft dark ellipse (alpha)
//   mini_die.png   16x16: a little die showing five
const path = require('path');
const { Raster, mix, hex } = require('../lib').raster;
const { writePng, preview, ASSETS } = require('../lib');

const S = 32;
// Pip centres on a 3x3 grid, per face.
const PIPS = {
  1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]],
  4: [[0, 0], [2, 0], [0, 2], [2, 2]], 5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
  6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]],
};

function face(n, size = S) {
  const r = new Raster(size, size);
  const k = size / 32;
  // ivory body, lighter in the middle, darkening into the rounded edges
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const u = (x + 0.5) / size * 2 - 1, v = (y + 0.5) / size * 2 - 1;
    const edge = Math.max(Math.abs(u), Math.abs(v));
    const corner = Math.hypot(Math.max(0, Math.abs(u) - 0.55), Math.max(0, Math.abs(v) - 0.55)) / 0.45;
    const e = Math.min(1, Math.max(0, (Math.max(edge, corner) - 0.72) / 0.28));
    const base = mix(hex('#fffaf0'), hex('#efe4cc'), (u + v + 2) / 4 * 0.6);
    r.set(x, y, mix(base, hex('#b8a888'), e * e));
  }
  const pip = n === 1 ? { dark: hex('#8e1414'), mid: hex('#c42a22'), rad: 5.2 } : { dark: hex('#141418'), mid: hex('#2c2c34'), rad: 3.3 };
  const step = 9 * k, off = size / 2 - step;
  for (const [gx, gy] of PIPS[n]) {
    const cx = off + gx * step, cy = off + gy * step, rad = pip.rad * k;
    r.circle(cx + 0.6 * k, cy + 0.8 * k, rad + 0.6 * k, [255, 255, 255, 120]);   // lit lower rim of the hollow
    r.circle(cx, cy, rad, pip.mid);
    r.circle(cx - 0.5 * k, cy - 0.6 * k, rad * 0.7, pip.dark);                  // shadowed upper inside
  }
  return r;
}

for (let n = 1; n <= 6; n++) writePng(path.join(ASSETS, `die${n}.png`), face(n));

const sh = new Raster(48, 24);
for (let y = 0; y < 24; y++) for (let x = 0; x < 48; x++) {
  const d = Math.hypot((x + 0.5 - 24) / 22, (y + 0.5 - 12) / 10);
  const a = Math.max(0, 1 - d);
  sh.set(x, y, [0, 0, 0, Math.round(170 * a * a * (3 - 2 * a))]);
}
writePng(path.join(ASSETS, 'shadow.png'), sh);

// mini die: a face with a darker side showing, for a little depth
const mini = new Raster(16, 16);
mini.roundRect(1, 2, 14, 14, 3, hex('#9c8c70'));
const f = face(5, 13);
mini.blit(f, 1, 1);
writePng(path.join(ASSETS, 'mini_die.png'), mini);

const pv = new Raster(6 * 36 + 60, 60);
for (let n = 1; n <= 6; n++) pv.blit(face(n), (n - 1) * 36 + 2, 2);
pv.blit(sh, 2, 36);
pv.blit(mini, 60, 40);
preview('dice', pv, 3, [30, 110, 60, 255]);
