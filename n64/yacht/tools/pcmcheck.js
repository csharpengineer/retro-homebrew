// Checks the title tune as the N64 mixer really played it (the PCM lines the
// autotest build logs) against the notes: for each instrument, rendered on its
// own by tools/audio.js, it finds where that part lines up in the capture at
// several points, through the loop. Every part must line up within 10 ms of the
// others and match clearly, or the music would sound out of step.
// Also writes build/capture.wav to listen to.   Usage: node tools/pcmcheck.js <log>
const fs = require('fs');
const path = require('path');
const { render, RATE, n64Tunes } = require('./audio');
const ROOT = path.join(__dirname, '..');

const cap = [];
let rate = 0;
for (const l of fs.readFileSync(process.argv[2], 'latin1').split(/\r?\n/)) {
  const m = /^PCM \d+ (\d+)/.exec(l);
  if (m) rate = +m[1];
  else if (rate && l.startsWith('A'))
    for (let i = 1; i + 4 <= l.length; i += 4) { let v = parseInt(l.substr(i, 4), 16); if (v >= 32768) v -= 65536; cap.push(v / 32768); }
}
if (!cap.length) { console.log('no PCM capture in the log'); process.exit(1); }

const out = Buffer.alloc(44 + cap.length * 2);
out.write('RIFF', 0); out.writeUInt32LE(36 + cap.length * 2, 4); out.write('WAVEfmt ', 8); out.writeUInt32LE(16, 16);
out.writeUInt16LE(1, 20); out.writeUInt16LE(1, 22); out.writeUInt32LE(rate, 24); out.writeUInt32LE(rate * 2, 28);
out.writeUInt16LE(2, 32); out.writeUInt16LE(16, 34); out.write('data', 36); out.writeUInt32LE(cap.length * 2, 40);
cap.forEach((v, i) => out.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(v * 32768))), 44 + i * 2));
fs.writeFileSync(path.join(ROOT, 'build/capture.wav'), out);

// onset envelope: summed absolute change per 64-sample hop
const HOP = 64;
const env = (s) => { const e = []; for (let i = 0; i + HOP <= s.length; i += HOP) { let a = 0; for (let k = 1; k < HOP; k++) a += Math.abs((s[i + k] || 0) - (s[i + k - 1] || 0)); e.push(a); } return e; };
const ce = env(cap);
const POINTS = [0.5, 4, 8, 12, 16.5, 18.5].filter((s) => (s + 1) * rate < cap.length);
let ok = true;
const lags = [];
n64Tunes().tunes[0].chans.forEach((ch, ci) => {
  if (!ch) return;
  const mix = [];
  const L = Math.round(render(ch, mix));
  for (let k = L; k < mix.length; k++) mix[k - L] = (mix[k - L] || 0) + mix[k];   // fold the tail, as the loop does
  mix.length = L;
  for (let k = 0; k < L; k++) mix[L + k] = mix[k];                                   // and repeat it
  const se = env(mix);
  const row = [];
  for (const sec of POINTS) {
    const c0 = Math.round((sec * RATE) / HOP), W = 500;
    let best = -1, bl = 0;
    for (let lag = -40; lag <= 40; lag++) {
      let xy = 0, xx = 0, yy = 0;
      for (let k = 0; k < W; k++) { const x = ce[c0 + k] || 0, y = se[c0 + k + lag] || 0; xy += x * y; xx += x * x; yy += y * y; }
      const r = xy / Math.sqrt(xx * yy || 1);
      if (r > best) { best = r; bl = lag; }
    }
    lags.push({ ci, sec, lag: bl * HOP, r: best });
    row.push(`${sec}s ${bl * HOP}/${best.toFixed(2)}`);
  }
  console.log(`  part ${ci}: ${row.join('  ')}`);
});
for (const sec of POINTS) {
  const at = lags.filter((l) => l.sec === sec), lo = Math.min(...at.map((l) => l.lag)), hi = Math.max(...at.map((l) => l.lag));
  if (hi - lo > 320) { console.log(`  parts apart by ${hi - lo} samples at ${sec}s`); ok = false; }
  for (const l of at) if (l.r < 0.5) { console.log(`  part ${l.ci} hardly matches at ${sec}s (${l.r.toFixed(2)})`); ok = false; }
}
process.exit(ok ? 0 : 1);
