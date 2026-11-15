// Reads the tunes from the Tandy source (tandy1000/yacht/src/data.asm) and turns them
// into the sound driver's streams. The Tandy ticked at 72.8 Hz and so does the
// driver, so note lengths carry over unchanged.
//   stream bytes: note len | $80 len (rest) | $81 instrument | $FF end
const fs = require('fs');
const path = require('path');
const { INST } = require('./instruments');

const SRC = path.join(__dirname, '../../../tandy1000/yacht/src/data.asm');
const NAMES = ['C', 'Cs', 'D', 'Ds', 'E', 'F', 'Fs', 'G', 'Gs', 'A', 'As', 'B'];

// N_A2 is note 1 (MIDI 45) through N_D6 = 42, as in tandy1000/yacht/tools/gen_notes.js.
function noteIndex(name) {
  const m = /^N_([A-G]s?)(\d)$/.exec(name);
  if (!m) throw new Error('bad note ' + name);
  return 12 * (Number(m[2]) + 1) + NAMES.indexOf(m[1]) - 44;
}

function parse() {
  // only the music part of data.asm: from its heading to the next section
  const all = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);
  const from = all.findIndex((l) => l.startsWith('; ---- Music'));
  let to = all.findIndex((l, i) => i > from && /^section/i.test(l.trim()));
  if (to < 0) to = all.length;
  const lines = all.slice(from, to);
  const equ = {}, macros = {}, labels = {}, tables = {};
  let macro = null, label = null;
  const value = (tok) => {
    tok = tok.trim();
    if (/^N_/.test(tok)) return noteIndex(tok);
    if (tok in equ) return equ[tok];
    if (/^[0-9A-F]+h$/i.test(tok)) return parseInt(tok, 16);
    if (/^\d+$/.test(tok)) return Number(tok);
    throw new Error('unknown value ' + tok);
  };
  const emit = (bytes) => {
    if (macro) macros[macro].push(...bytes);
    else if (label) labels[label].push(...bytes);
  };
  for (let raw of lines) {
    if (/^; Loudness/.test(raw)) break;   // the tunes end here; player state follows
    const line = raw.replace(/;.*/, '').trim();
    if (!line) continue;
    let m;
    if ((m = /^(\w+)\s+equ\s+(\w+)/i.exec(line))) { equ[m[1]] = value(m[2]); continue; }
    if ((m = /^%macro\s+(\w+)/.exec(line))) { macro = m[1]; macros[macro] = []; continue; }
    if (/^%endmacro/.test(line)) { macro = null; continue; }
    if ((m = /^(\w+):\s*dw\s+(.*)$/.exec(line))) { tables[m[1]] = m[2].split(',').map((s) => s.trim()); label = null; continue; }
    if ((m = /^(\w+):\s*(db\s+.*)?$/.exec(line))) {
      label = m[1]; labels[label] = [];
      if (m[2]) emit(m[2].slice(3).split(',').map(value));
      continue;
    }
    if ((m = /^db\s+(.*)$/.exec(line))) { emit(m[1].split(',').map(value)); continue; }
    if (/^\w+$/.test(line) && macros[line]) { emit(macros[line]); continue; }
    if (/^(section|%include|resb|\w+\s+res[bw])/.test(line)) { label = null; continue; }
  }
  return { equ, labels, tables };
}

// Converts Tandy (note, length) pairs into a driver stream on an instrument.
function stream(pairs, inst) {
  const out = [0x81, inst];
  for (let i = 0; i < pairs.length; i += 2) {
    if (pairs[i] === 0xFF) break;
    const note = pairs[i], len = pairs[i + 1];
    if (note === 0) out.push(0x80, len);
    else out.push(note, len);
  }
  out.push(0xFF);
  return out;
}
function length(pairs) {
  let t = 0;
  for (let i = 0; i < pairs.length && pairs[i] !== 0xFF; i += 2) t += pairs[i + 1];
  return t;
}

// Tunes in driver order: title, score, bad, good, yacht, win, lose.
const ORDER = ['tune_title', 'tune_score', 'tune_bad', 'tune_good', 'tune_yacht', 'tune_win', 'tune_lose'];
const VOICE_INST = [INST.lead, INST.bass, INST.pluck];

function build() {
  const { labels, tables } = parse();
  const tunes = ORDER.map((name, id) => {
    const t = tables[name];
    if (!t) throw new Error('missing ' + name);
    const chans = t.map((lab, v) => (lab === '0' ? null : stream(labels[lab], id === 1 && v === 0 ? INST.bell : VOICE_INST[v])));
    while (chans.length < 4) chans.push(null);
    if (id === 0) {
      // the title gets a soft shaker on the off-beats, as long as the melody
      const ticks = length(labels[t[0]]);
      const hat = [0x81, INST.hat];
      for (let i = 0; i < ticks / 10; i++) hat.push(i % 2 ? 26 : 22, 10);
      hat.push(0xFF);
      chans[3] = hat;
    }
    return { chans, loop: id === 0 };
  });
  // Sound effects (channels 4 and 5), in audio.s order: tick, select, roll, hold, score.
  const sfx = [
    [[0x81, INST.tick, 31, 3, 0xFF], null],
    [[0x81, INST.bell, 32, 4, 37, 8, 0xFF], null],
    [rattle(1), rattle(7)],
    [null, [0x81, INST.tick, 23, 3, 0xFF]],
    [[0x81, INST.bell, 37, 5, 41, 9, 0xFF], null],
  ];
  return { tunes, sfx };
}

// Dice clattering on felt: short noise taps of shifting pitch, about as long
// as the tumble on screen.
function rattle(seed) {
  let s = seed;
  const rnd = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  const out = [0x81, INST.rattle];
  let t = 0;
  while (t < 28) {
    const len = 2 + Math.floor(rnd() * 3);
    out.push(14 + Math.floor(rnd() * 10), len);
    if (rnd() < 0.3) out.push(0x80, 1);
    t += len + 1;
  }
  out.push(0xFF);
  return out;
}

module.exports = { build, parse, noteIndex };
