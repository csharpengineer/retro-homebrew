// A small RGBA canvas for drawing SNES art in code. Shapes are antialiased by
// supersampling coverage; colors are [r, g, b, a] with components 0-255.
class Raster {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.data = new Uint8ClampedArray(w * h * 4);
  }

  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return [0, 0, 0, 0];
    const i = (y * this.w + x) * 4;
    return [this.data[i], this.data[i + 1], this.data[i + 2], this.data[i + 3]];
  }

  set(x, y, c) {
    x |= 0; y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    this.data[i] = c[0]; this.data[i + 1] = c[1]; this.data[i + 2] = c[2]; this.data[i + 3] = c[3] ?? 255;
  }

  // Blends c over the pixel with coverage k (0-1).
  blend(x, y, c, k = 1) {
    x |= 0; y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const a = ((c[3] ?? 255) / 255) * k;
    if (a <= 0) return;
    const i = (y * this.w + x) * 4;
    const da = this.data[i + 3] / 255;
    const oa = a + da * (1 - a);
    for (let j = 0; j < 3; j++) {
      this.data[i + j] = oa > 0 ? (c[j] * a + this.data[i + j] * da * (1 - a)) / oa : 0;
    }
    this.data[i + 3] = oa * 255;
  }

  fill(c) { for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) this.set(x, y, c); }

  rect(x, y, w, h, c) {
    for (let yy = Math.max(0, y); yy < Math.min(this.h, y + h); yy++)
      for (let xx = Math.max(0, x); xx < Math.min(this.w, x + w); xx++) this.blend(xx, yy, c);
  }

  // Fills where inside(px, py) is true, 4x4 supersampled for soft edges.
  // c may be a color or a function (x, y) -> color.
  shape(x0, y0, x1, y1, inside, c) {
    const S = 4;
    for (let y = Math.max(0, Math.floor(y0)); y < Math.min(this.h, Math.ceil(y1)); y++) {
      for (let x = Math.max(0, Math.floor(x0)); x < Math.min(this.w, Math.ceil(x1)); x++) {
        let n = 0;
        for (let sy = 0; sy < S; sy++)
          for (let sx = 0; sx < S; sx++) if (inside(x + (sx + 0.5) / S, y + (sy + 0.5) / S)) n++;
        if (n) this.blend(x, y, typeof c === 'function' ? c(x, y) : c, n / (S * S));
      }
    }
  }

  circle(cx, cy, r, c) {
    this.shape(cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1, (x, y) => (x - cx) ** 2 + (y - cy) ** 2 <= r * r, c);
  }

  ellipse(cx, cy, rx, ry, c) {
    this.shape(cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1,
      (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1, c);
  }

  roundRect(x, y, w, h, r, c) {
    const inside = (px, py) => {
      const qx = Math.max(x + r - px, 0, px - (x + w - r));
      const qy = Math.max(y + r - py, 0, py - (y + h - r));
      return qx * qx + qy * qy <= r * r;
    };
    this.shape(x, y, x + w, y + h, inside, c);
  }

  polygon(pts, c) {
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
    const inside = (px, py) => {
      let ins = false;
      for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const [xi, yi] = pts[i], [xj, yj] = pts[j];
        if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) ins = !ins;
      }
      return ins;
    };
    this.shape(Math.min(...xs), Math.min(...ys), Math.max(...xs) + 1, Math.max(...ys) + 1, inside, c);
  }

  line(x0, y0, x1, y1, width, c) {
    const dx = x1 - x0, dy = y1 - y0, len2 = dx * dx + dy * dy || 1, hw = width / 2;
    const inside = (px, py) => {
      const t = Math.max(0, Math.min(1, ((px - x0) * dx + (py - y0) * dy) / len2));
      return (px - x0 - t * dx) ** 2 + (py - y0 - t * dy) ** 2 <= hw * hw;
    };
    this.shape(Math.min(x0, x1) - hw - 1, Math.min(y0, y1) - hw - 1, Math.max(x0, x1) + hw + 1, Math.max(y0, y1) + hw + 1, inside, c);
  }

  // Vertical gradient through color stops [[t, color], ...], t from 0 (top) to 1.
  vgradient(x, y, w, h, stops) {
    for (let yy = 0; yy < h; yy++) {
      const c = lerpStops(stops, h > 1 ? yy / (h - 1) : 0);
      for (let xx = 0; xx < w; xx++) this.blend(x + xx, y + yy, c);
    }
  }

  blit(src, dx, dy) {
    for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
      const c = src.get(x, y);
      if (c[3]) this.blend(dx + x, dy + y, c);
    }
  }

  crop(x, y, w, h) {
    const r = new Raster(w, h);
    for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) r.set(xx, yy, this.get(x + xx, y + yy));
    return r;
  }

  // Scales every pixel's color by f(x, y) (for shading), keeping alpha.
  shade(f) {
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const i = (y * this.w + x) * 4;
      if (!this.data[i + 3]) continue;
      const k = f(x, y);
      for (let j = 0; j < 3; j++) this.data[i + j] = this.data[i + j] * k;
    }
  }
}

function lerp(a, b, t) { return a + (b - a) * t; }
function mix(c0, c1, t) {
  return [lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t), lerp(c0[3] ?? 255, c1[3] ?? 255, t)];
}
function lerpStops(stops, t) {
  if (t <= stops[0][0]) return stops[0][1];
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) {
      const [t0, c0] = stops[i - 1], [t1, c1] = stops[i];
      return mix(c0, c1, (t - t0) / (t1 - t0 || 1));
    }
  }
  return stops[stops.length - 1][1];
}
function hex(s, a = 255) {
  const n = parseInt(s.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255, a];
}

module.exports = { Raster, mix, lerpStops, hex };
