// Builds build/YACHT.DSK, a 360K FAT12 floppy image holding the game files.
const fs = require('fs');
const SEC = 512, SPC = 2, RES = 1, NF = 2, ROOT = 112, TOT = 720, SPF = 2;
const d = Buffer.alloc(TOT * SEC);
fs.readFileSync('build/boot.bin').copy(d, 0);
const fat = Buffer.alloc(SPF * SEC);
fat[0] = 0xfd; fat[1] = 0xff; fat[2] = 0xff;
const set = (c, v) => {
  const o = Math.floor(c * 1.5);
  if (c & 1) { fat[o] = (fat[o] & 0x0f) | ((v & 0xf) << 4); fat[o + 1] = v >> 4; }
  else { fat[o] = v & 0xff; fat[o + 1] = (fat[o + 1] & 0xf0) | (v >> 8); }
};
const rootOff = (RES + NF * SPF) * SEC, dataOff = rootOff + ROOT * 32, cs = SPC * SEC;
let next = 2, ei = 0;
const now = new Date();
function entry(name, attr, clus, size) {
  const e = d.subarray(rootOff + ei * 32, rootOff + ei * 32 + 32); ei++;
  e.write(name, 'latin1'); e[11] = attr;
  e.writeUInt16LE((now.getHours() << 11) | (now.getMinutes() << 5), 22);
  e.writeUInt16LE(((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate(), 24);
  e.writeUInt16LE(clus, 26); e.writeUInt32LE(size, 28);
}
entry('YACHT      ', 0x08, 0, 0);
const files = [['build/YACHT.COM', 'YACHT   COM'], ['build/YACHT.SPK', 'YACHT   SPK'], ['tools/README.TXT', 'README  TXT']];
for (const [file, name] of files) {
  const b = fs.readFileSync(file), need = Math.ceil(b.length / cs), first = next;
  for (let i = 0; i < need; i++) set(next + i, i === need - 1 ? 0xfff : next + i + 1);
  b.copy(d, dataOff + (next - 2) * cs);
  next += need;
  entry(name, 0x20, first, b.length);
}
for (let i = 0; i < NF; i++) fat.copy(d, (RES + i * SPF) * SEC);
fs.writeFileSync('build/YACHT.DSK', d);
console.log('disk built,', next - 2, 'of 354 clusters used');
