const test = require('node:test');
const assert = require('node:assert');
const brr = require('../brr');

function sine(freq, rate, n, amp) {
  const s = new Int16Array(n);
  for (let i = 0; i < n; i++) s[i] = Math.round(amp * Math.sin((2 * Math.PI * freq * i) / rate));
  return s;
}

function snr(a, b) {
  let sig = 0, err = 0;
  for (let i = 0; i < a.length; i++) { sig += a[i] * a[i]; err += (a[i] - b[i]) ** 2; }
  return 10 * Math.log10(sig / Math.max(err, 1));
}

test('BRR round trip of a 1 kHz sine keeps SNR above 30 dB', () => {
  const src = sine(1000, 32000, 3200, 20000);
  const enc = brr.encode(src);
  assert.strictEqual(enc.length % 9, 0);
  assert.strictEqual(enc.length / 9, 200);
  const dec = brr.decode(enc);
  assert.strictEqual(dec.length, src.length);
  const q = snr(src, dec);
  assert.ok(q > 30, `SNR ${q.toFixed(1)} dB`);
});

test('only the last block carries the end flag', () => {
  const enc = brr.encode(sine(440, 32000, 160, 8000));
  const blocks = enc.length / 9;
  for (let b = 0; b < blocks - 1; b++) assert.strictEqual(enc[b * 9] & 1, 0, `block ${b}`);
  assert.strictEqual(enc[(blocks - 1) * 9] & 1, 1);
});

test('looped samples set the loop flag on the last block', () => {
  const enc = brr.encode(sine(500, 32000, 64, 8000), { loop: true });
  assert.strictEqual(enc[enc.length - 9] & 3, 3);
});

test('short input is padded to whole blocks', () => {
  const enc = brr.encode(new Int16Array(20));
  assert.strictEqual(enc.length, 18);
});
