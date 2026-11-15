const test = require('node:test');
const assert = require('node:assert');
const speechLines = require('../speech_lines');

test('the SNES says the box names it shows', () => {
  const lines = speechLines();
  const four = lines.find((l) => l.name === 'four');
  assert.strictEqual(four.text, 'Four alike!');
});

test('every Tandy phrase is kept, in the Tandy order', () => {
  const names = speechLines().map((l) => l.name);
  assert.deepStrictEqual(names, ['yacht', 'fullhouse', 'four', 'straight', 'youwin', 'skipper', 'tie',
    'welcome', 'p1wins', 'p2wins']);
  assert.strictEqual(speechLines().find((l) => l.name === 'welcome').text, 'Welcome aboard.');
});
