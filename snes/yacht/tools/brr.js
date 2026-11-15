// BRR, the SNES sound chip's sample format: 9-byte blocks of 16 samples.
// The decoder follows the DSP's integer math; the encoder tries every filter
// and shift for each block and keeps the one that decodes closest to the input.

function clamp16(v) { return v < -32768 ? -32768 : v > 32767 ? 32767 : v; }

// One sample through the DSP: nibble n (-8..7), shift, filter, previous two outputs.
function decodeSample(n, shift, filter, p1, p2) {
  let s = shift <= 12 ? (n << shift) >> 1 : (n < 0 ? -2048 : 0);
  const q2 = p2 >> 1;
  switch (filter) {
    case 1: s += p1 >> 1; s += (-p1) >> 5; break;
    case 2: s += p1; s -= q2; s += q2 >> 4; s += (p1 * -3) >> 6; break;
    case 3: s += p1; s -= q2; s += (p1 * -13) >> 7; s += (q2 * 3) >> 4; break;
  }
  s = clamp16(s);
  return ((s << 1) << 16) >> 16;      // the DSP keeps 15 bits, doubled
}

function decode(buf) {
  const out = [];
  let p1 = 0, p2 = 0;
  for (let b = 0; b + 9 <= buf.length; b += 9) {
    const h = buf[b], shift = h >> 4, filter = (h >> 2) & 3;
    for (let i = 0; i < 16; i++) {
      const byte = buf[b + 1 + (i >> 1)];
      let n = i & 1 ? byte & 15 : byte >> 4;
      if (n > 7) n -= 16;
      const s = decodeSample(n, shift, filter, p1, p2);
      out.push(s);
      p2 = p1;
      p1 = s;
    }
  }
  return Int16Array.from(out);
}

// Encodes one block; returns { bytes, err, p1, p2 }.
function encodeBlock(src, shift, filter, p1, p2) {
  const bytes = Buffer.alloc(9);
  bytes[0] = (shift << 4) | (filter << 2);
  let err = 0;
  for (let i = 0; i < 16; i++) {
    let best = 0, bestS = 0, bestE = Infinity;
    for (let n = -8; n <= 7; n++) {
      const s = decodeSample(n, shift, filter, p1, p2);
      const e = (s - src[i]) ** 2;
      if (e < bestE) { bestE = e; best = n; bestS = s; }
    }
    err += bestE;
    bytes[1 + (i >> 1)] |= i & 1 ? best & 15 : (best & 15) << 4;
    p2 = p1;
    p1 = bestS;
  }
  return { bytes, err, p1, p2 };
}

// samples: Int16Array. opts.loop marks the sample as looping from opts.loopStart
// (a multiple of 16; the loop block uses filter 0 so it decodes the same every pass).
function encode(samples, opts = {}) {
  const n = Math.max(16, Math.ceil(samples.length / 16) * 16);
  const src = new Int16Array(n);
  src.set(samples.subarray(0, n));
  const loopBlock = opts.loop ? Math.floor((opts.loopStart || 0) / 16) : -1;
  const blocks = [];
  let p1 = 0, p2 = 0;
  for (let b = 0; b < n / 16; b++) {
    const chunk = src.subarray(b * 16, b * 16 + 16);
    let best = null;
    const filters = b === 0 || b === loopBlock || opts.filter0 ? [0] : [0, 1, 2, 3];
    for (const f of filters) {
      for (let sh = 0; sh <= 12; sh++) {
        const r = encodeBlock(chunk, sh, f, p1, p2);
        if (!best || r.err < best.err) best = r;
      }
    }
    blocks.push(best.bytes);
    p1 = best.p1;
    p2 = best.p2;
  }
  const last = blocks[blocks.length - 1];
  last[0] |= 1;                       // end
  if (opts.loop) last[0] |= 2;        // loop
  return Buffer.concat(blocks);
}

module.exports = { encode, decode, decodeSample };
