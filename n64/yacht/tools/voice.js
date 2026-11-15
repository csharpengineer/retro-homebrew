// The voice clips. The phrases are the SNES port's (Tandy list with "Four
// alike!"); tools/speech.sh renders them with Windows speech into build/speech.
// This trims the silence, adds a short fade, normalizes and writes
// build/assets/v_<name>.wav for audioconv64.
//   node tools/voice.js --lines   prints name|text for speech.sh
const fs = require('fs');
const path = require('path');
const speechLines = require('../../../snes/yacht/tools/speech_lines');
const { ASSETS, ROOT } = require('./lib');

const lines = speechLines();
if (process.argv[2] === '--lines') {
  process.stdout.write(lines.map((l) => `${l.name}|${l.text}`).join('\n') + '\n');
  process.exit(0);
}

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, rate = 0, data = null;
  while (p + 8 <= b.length) {
    const id = b.toString('latin1', p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === 'fmt ') rate = b.readUInt32LE(p + 12);
    if (id === 'data') data = b.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size & 1);
  }
  const s = new Float64Array(data.length / 2);
  for (let i = 0; i < s.length; i++) s[i] = data.readInt16LE(i * 2) / 32768;
  return { rate, s };
}

for (const { name } of lines) {
  const { rate, s } = readWav(path.join(ROOT, 'build/speech', name + '.wav'));
  const thr = 0.01;
  let a = 0, z = s.length - 1;
  while (a < z && Math.abs(s[a]) < thr) a++;
  while (z > a && Math.abs(s[z]) < thr) z--;
  a = Math.max(0, a - Math.round(rate * 0.01));
  z = Math.min(s.length - 1, z + Math.round(rate * 0.04));
  const clip = s.slice(a, z + 1);
  let peak = 0;
  for (const v of clip) peak = Math.max(peak, Math.abs(v));
  const k = 0.9 / (peak || 1), fade = Math.round(rate * 0.005);
  const b = Buffer.alloc(44 + clip.length * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + clip.length * 2, 4); b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24);
  b.writeUInt32LE(rate * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
  b.write('data', 36); b.writeUInt32LE(clip.length * 2, 40);
  for (let i = 0; i < clip.length; i++) {
    const env = Math.min(1, i / fade, (clip.length - 1 - i) / fade);
    b.writeInt16LE(Math.round(clip[i] * k * env * 32767), 44 + i * 2);
  }
  fs.writeFileSync(path.join(ASSETS, 'v_' + name + '.wav'), b);
}
