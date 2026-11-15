// Checks the ROM image the Super EverDrive will load: size, LoROM header, checksum.
const fs = require('fs');
const rom = fs.readFileSync(process.argv[2]);
const errs = [];
const H = 0x7FC0;
if (rom.length !== 524288) errs.push(`size ${rom.length}, want 524288 (no copier header)`);
const title = rom.slice(H, H + 21).toString('latin1');
if (title !== 'YACHT'.padEnd(21)) errs.push(`title "${title}"`);
const fields = [
  [0x15, 0x20, 'map mode'], [0x16, 0x02, 'cart type'], [0x17, 0x09, 'ROM size'],
  [0x18, 0x01, 'SRAM size'], [0x19, 0x01, 'country'],
];
for (const [off, want, name] of fields) {
  if (rom[H + off] !== want) errs.push(`${name} $${rom[H + off].toString(16)}, want $${want.toString(16)}`);
}
const comp = rom.readUInt16LE(H + 0x1C), sum = rom.readUInt16LE(H + 0x1E);
if (((comp + sum) & 0xFFFF) !== 0xFFFF) errs.push(`checksum $${sum.toString(16)} and complement $${comp.toString(16)} don't pair`);
let total = 0;
for (const b of rom) total = (total + b) & 0xFFFF;
if (total !== sum) errs.push(`checksum $${sum.toString(16)}, computed $${total.toString(16)}`);
const reset = rom.readUInt16LE(0x7FFC);
if (reset < 0x8000) errs.push(`reset vector $${reset.toString(16)}`);
if (errs.length) { console.error('checkrom: ' + errs.join('; ')); process.exit(1); }
console.log(`checkrom: OK (${rom.length} bytes, checksum $${sum.toString(16)})`);
