// Renders the music and sound effects to WAV (build/assets/tune_*.wav,
// sfx_*.wav) for audioconv64. The notes are the Tandy's, read from
// tandy1000/yacht/src/data.asm by the SNES port's tools/tunes.js (same order,
// instruments and the title's shaker); here a small synth plays them offline at
// 32 kHz instead of the SNES's sound chip.
const path = require('path');
const fs = require('fs');
const tunes = require('../../../snes/yacht/tools/tunes');
const { INST } = require('../../../snes/yacht/tools/instruments');
const { ASSETS } = require('./lib');

const RATE = 32000, TICK = RATE / 72.8;   // the Tandy's player ticked at 72.8 Hz
const INAME = Object.fromEntries(Object.entries(INST).map(([k, v]) => [v, k]));
const freq = (note) => 440 * 2 ** ((note + 44 - 69) / 12);   // note 1 = N_A2 (MIDI 45)

let seed = 1;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff) * 2 - 1;

// One note: returns samples (longer than len when the instrument rings on).
function voice(inst, note, len) {
  const f = freq(note), out = [];
  const add = (n, fn) => { for (let i = 0; i < n; i++) out.push(fn(i / RATE, i)); };
  const rel = (t, d) => (t < d ? 1 : Math.max(0, 1 - (t - d) / 0.06));   // short release after the note
  switch (inst) {
    case 'lead': {   // steel drum: bright partials that die away at different speeds
      const P = [[1, 1, 3], [2, 0.55, 5], [3, 0.12, 7], [4, 0.28, 6], [6, 0.06, 9]];
      add(Math.max(len, 0.5 * RATE), (t) => P.reduce((s, [h, a, d]) => s + a * Math.exp(-d * t) * Math.sin(2 * Math.PI * f * h * t), 0)
        * Math.min(1, t * 400) * 0.32 * rel(t, len / RATE + 0.25));
      break;
    }
    case 'bass':
      add(len + 0.06 * RATE, (t) => (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(4 * Math.PI * f * t) + 0.1 * Math.sin(6 * Math.PI * f * t))
        * Math.min(1, t * 300) * (0.55 + 0.45 * Math.exp(-4 * t)) * 0.38 * rel(t, len / RATE));
      break;
    case 'pluck': {   // Karplus-Strong string
      const n = Math.round(RATE / f), buf = Array.from({ length: n }, () => rnd() * 0.5);
      let p = 0;
      add(Math.max(len, 0.35 * RATE), (t) => {
        const v = buf[p], nx = buf[(p + 1) % n];
        buf[p] = (v + nx) * 0.5 * 0.996;
        p = (p + 1) % n;
        return v * 0.42 * rel(t, len / RATE + 0.15);
      });
      break;
    }
    case 'hat': {   // a soft shaker: high-passed noise, quick decay
      let last = 0;
      add(0.05 * RATE, (t) => { const x = rnd(); const y = x - last; last = x; return y * Math.exp(-70 * t) * 0.09; });
      break;
    }
    case 'bell': {
      const P = [[1, 1, 3], [2.76, 0.45, 5], [5.4, 0.22, 8], [8.93, 0.12, 12]];
      add(0.9 * RATE, (t) => P.reduce((s, [h, a, d]) => s + a * Math.exp(-d * t) * Math.sin(2 * Math.PI * f * h * t), 0) * Math.min(1, t * 600) * 0.3);
      break;
    }
    case 'tick':
      add(0.03 * RATE, (t) => Math.sign(Math.sin(2 * Math.PI * f * t)) * Math.exp(-120 * t) * 0.16);
      break;
    case 'rattle': {   // a die knocking on wood: a damped resonance plus a click of noise
      const fr = 600 + f * 1.5;
      add(0.05 * RATE, (t) => (Math.sin(2 * Math.PI * fr * t) * 0.7 + rnd() * 0.5) * Math.exp(-90 * t) * 0.32);
      break;
    }
  }
  return out;
}

// Plays one driver stream (tools/tunes.js format) into mix, starting at 0.
function render(stream, mix) {
  let inst = 'lead', t = 0;
  for (let i = 0; i < stream.length;) {
    const b = stream[i];
    if (b === 0xFF) break;
    if (b === 0x81) { inst = INAME[stream[i + 1]]; i += 2; continue; }
    const len = stream[i + 1] * TICK;
    if (b !== 0x80) {
      const s = voice(inst, b, len), at = Math.round(t);
      for (let k = 0; k < s.length; k++) mix[at + k] = (mix[at + k] || 0) + s[k];
    }
    t += len;
    i += 2;
  }
  return t;
}

function writeWav(name, s, peak) {
  let max = 0;
  for (const v of s) max = Math.max(max, Math.abs(v || 0));
  const k = max ? peak / max : 0;
  const b = Buffer.alloc(44 + s.length * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + s.length * 2, 4); b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(RATE, 24);
  b.writeUInt32LE(RATE * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
  b.write('data', 36); b.writeUInt32LE(s.length * 2, 40);
  for (let i = 0; i < s.length; i++) b.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round((s[i] || 0) * k * 32767))), 44 + i * 2);
  fs.writeFileSync(path.join(ASSETS, name + '.wav'), b);
}

const NAMES = ['title', 'score', 'bad', 'good', 'yacht', 'win', 'lose'];
const SFX = ['tick', 'select', 'roll', 'hold'];
const built = tunes.build();
built.tunes.forEach((tune, i) => {
  const mix = [];
  let len = 0;
  for (const ch of tune.chans) if (ch) len = Math.max(len, render(ch, mix));
  if (tune.loop) {   // fold the ringing tail back onto the start so the loop is seamless
    const L = Math.round(len);
    for (let k = L; k < mix.length; k++) mix[k - L] = (mix[k - L] || 0) + mix[k];
    mix.length = L;
  }
  writeWav('tune_' + NAMES[i], mix, i === 0 ? 0.55 : 0.7);
});
// sound effects in tunes.js order: tick, select, roll, hold, score (unused)
SFX.forEach((name, i) => {
  const mix = [];
  for (const ch of built.sfx[i]) if (ch) render(ch, mix);
  writeWav('sfx_' + name, mix, name === 'roll' ? 0.6 : 0.5);
});
