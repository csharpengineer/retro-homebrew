// Builds the sound RAM image the CPU uploads at power-on: the driver at $0200,
// then the tables the driver reads at fixed addresses, the streams and samples.
// Writes build/spc/image.bin (starting at $0200).
const fs = require('fs');
const path = require('path');
const instruments = require('./instruments');
const tunes = require('./tunes');

const OUT = path.join(__dirname, '../build/spc');
const BASE = 0x0200, DIR = 0x1000, TUNES = 0x1100, TUNELOOP = 0x1140, SFXTAB = 0x1150, INSTR = 0x1170, PITCH = 0x1200;
const STREAMS = 0x1280, LIMIT = 0xA800, VOICE_BUF = 0xA800, VOICE_SRCN = 63;

const aram = Buffer.alloc(0x10000);
const driver = fs.readFileSync(path.join(OUT, 'driver.bin'));
if (BASE + driver.length > DIR) throw new Error(`driver is ${driver.length} bytes, overlaps the tables`);
driver.copy(aram, BASE);

const w16 = (a, v) => aram.writeUInt16LE(v & 0xFFFF, a);
let next = STREAMS;
const place = (bytes) => { const at = next; Buffer.from(bytes).copy(aram, at); next += bytes.length; return at; };

// pitch table: index = Tandy note number, MIDI = 44 + index; the instruments
// play 500 Hz at pitch $1000
for (let n = 0; n < 64; n++) {
  const f = 440 * Math.pow(2, (44 + n - 69) / 12);
  w16(PITCH + n * 2, Math.min(0x3FFF, Math.round((4096 * f) / 500)));
}

const { tunes: tl, sfx } = tunes.build();
tl.forEach((t, id) => {
  t.chans.forEach((s, c) => w16(TUNES + id * 8 + c * 2, s ? place(s) : 0));
  aram[TUNELOOP + id] = t.loop ? 1 : 0;
});
sfx.forEach((pair, id) => pair.forEach((s, c) => w16(SFXTAB + id * 4 + c * 2, s ? place(s) : 0)));

const { samples, table } = instruments.build();
table.forEach((row, i) => row.forEach((b, j) => { aram[INSTR + i * 8 + j] = b; }));
samples.forEach((s, i) => {
  const at = place(s);
  w16(DIR + i * 4, at);
  w16(DIR + i * 4 + 2, at);          // loops from the start
});
w16(DIR + VOICE_SRCN * 4, VOICE_BUF);
w16(DIR + VOICE_SRCN * 4 + 2, VOICE_BUF);
if (next > LIMIT) throw new Error(`sound data runs to $${next.toString(16)}, past $${LIMIT.toString(16)}`);

fs.writeFileSync(path.join(OUT, 'image.bin'), aram.slice(BASE, next));
console.log(`spc: driver ${driver.length} bytes, image $${BASE.toString(16)}-$${next.toString(16)} (${next - BASE} bytes)`);
