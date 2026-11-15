// Synthesized instruments: one 64-sample looped cycle each (500 Hz at pitch
// $1000 from 32 kHz), shaped over time by the DSP envelope. Returns the BRR
// samples and the driver's instrument table rows.
const brr = require('./brr');

const CYCLE = 64;
function wave(harmonics, phaseJitter = 0) {
  const s = new Float64Array(CYCLE);
  for (const [h, a] of harmonics) {
    for (let i = 0; i < CYCLE; i++) s[i] += a * Math.sin((2 * Math.PI * h * i) / CYCLE + phaseJitter * h);
  }
  let peak = 0;
  for (const v of s) peak = Math.max(peak, Math.abs(v));
  return Int16Array.from(s, (v) => Math.round((v / peak) * 26000));
}

// ADSR register values: AR 0-15, DR 0-7, SL 0-7, SR 0-31
const adsr = (ar, dr, sl, sr) => [0x80 | (dr << 4) | ar, (sl << 5) | sr];

const saw = [];
for (let h = 1; h <= 10; h++) saw.push([h, (1 / h) * Math.exp(-h / 12)]);
const square = [];
for (let h = 1; h <= 11; h += 2) square.push([h, 1 / h]);

// [name, waveform, envelope, volume, noise]
const DEFS = [
  ['lead', wave([[1, 1], [2, 0.55], [3, 0.12], [4, 0.28], [6, 0.06]]), adsr(15, 4, 3, 17), 0x38, 0], // steel drum
  ['bass', wave([[1, 1], [2, 0.35], [3, 0.1]]), adsr(14, 2, 5, 10), 0x46, 0],
  ['pluck', wave(saw), adsr(15, 6, 1, 18), 0x26, 0],
  ['hat', wave([[1, 1]]), adsr(15, 7, 0, 27), 0x12, 1],
  ['tick', wave(square), adsr(15, 7, 0, 25), 0x2C, 0],
  ['bell', wave([[1, 1], [3, 0.5], [5, 0.25], [8, 0.15]], 0.4), adsr(15, 3, 2, 15), 0x34, 0],
  ['rattle', wave([[1, 1]]), adsr(15, 6, 0, 22), 0x3C, 1],
];
const INST = Object.fromEntries(DEFS.map((d, i) => [d[0], i]));

function build() {
  const samples = [], table = [];
  DEFS.forEach(([, w, env, vol, noise], i) => {
    samples.push(brr.encode(w, { loop: true, loopStart: 0, filter0: true }));
    table.push([i, env[0], env[1], vol, noise, 0, 0, 0]);
  });
  return { samples, table };
}

module.exports = { build, INST };
