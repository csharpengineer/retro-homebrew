// The phrases the SNES speaks: the Tandy list (tandy1000/yacht/tools/speech.txt)
// with the SNES's own wording from tools/speech_snes.txt laid over it, so the
// voice says the box names this version shows ("Four Alike").
// Run directly, writes build/speech/lines.txt (name|text) for tools/speech.sh.
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean)
  .map((l) => { const [name, text] = l.split('|'); return { name, text }; });

function speechLines() {
  const lines = read(path.join(ROOT, '../../tandy1000/yacht/tools/speech.txt'));
  for (const o of read(path.join(__dirname, 'speech_snes.txt'))) {
    const line = lines.find((l) => l.name === o.name);
    if (!line) throw new Error(`speech_snes.txt: no Tandy phrase named ${o.name}`);
    line.text = o.text;
  }
  return lines;
}

if (require.main === module) {
  fs.mkdirSync(path.join(ROOT, 'build/speech'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, 'build/speech/lines.txt'),
    speechLines().map((l) => `${l.name}|${l.text}`).join('\n') + '\n');
}

module.exports = speechLines;
