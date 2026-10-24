// Bakes the planet's static noise fields into one equirectangular RGBA texture at boot,
// so the per-frame shader only does texture lookups (cheap on low-end phone GPUs).
//   R: continent height   G: terrain detail   B: city / unrest field   A: cloud cover

function hash3(x: number, y: number, z: number): number {
  let h = (x * 374761393 + y * 668265263 + z * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}

const fade = (t: number) => t * t * (3 - 2 * t);

function valueNoise(x: number, y: number, z: number): number {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = fade(x - xi), yf = fade(y - yi), zf = fade(z - zi);
  const l = (a: number, b: number, t: number) => a + (b - a) * t;
  const c = (dx: number, dy: number, dz: number) => hash3(xi + dx, yi + dy, zi + dz);
  return l(
    l(l(c(0, 0, 0), c(1, 0, 0), xf), l(c(0, 1, 0), c(1, 1, 0), xf), yf),
    l(l(c(0, 0, 1), c(1, 0, 1), xf), l(c(0, 1, 1), c(1, 1, 1), xf), yf),
    zf,
  ) * 2 - 1;
}

function fbm(x: number, y: number, z: number, octaves: number): number {
  let sum = 0, amp = 0.5, freq = 1, norm = 0;
  for (let i = 0; i < octaves; i++) {
    sum += valueNoise(x * freq + i * 17.3, y * freq, z * freq) * amp;
    norm += amp;
    amp *= 0.5;
    freq *= 2.03;
  }
  return sum / norm;
}

/** Map values to their percentile rank (0..1) so shader thresholds mean "top N%". */
function equalize(values: Float32Array): Float32Array {
  const sorted = Float32Array.from(values).sort();
  const out = new Float32Array(values.length);
  for (let n = 0; n < values.length; n++) {
    let lo = 0, hi = sorted.length - 1;
    const v = values[n]!;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (sorted[mid]! < v) lo = mid + 1;
      else hi = mid;
    }
    out[n] = lo / (sorted.length - 1);
  }
  return out;
}

export function bakeTerrain(width = 768, height = 384, seed = 3): Uint8Array {
  const n = width * height;
  const fields = [new Float32Array(n), new Float32Array(n), new Float32Array(n), new Float32Array(n)] as const;
  const off = seed * 31.7;
  for (let j = 0; j < height; j++) {
    // Match SphereGeometry's uv layout: v=1 at +Y (north), u wraps around Y.
    const theta = (1 - (j + 0.5) / height) * Math.PI;
    const st = Math.sin(theta), y = Math.cos(theta);
    for (let i = 0; i < width; i++) {
      const phi = ((i + 0.5) / width) * Math.PI * 2;
      const x = -Math.cos(phi) * st, z = Math.sin(phi) * st;
      const k = j * width + i;
      fields[0][k] = fbm(x * 1.8 + off, y * 1.8, z * 1.8, 6);
      fields[1][k] = valueNoise(x * 9 + off, y * 9, z * 9);
      fields[2][k] = valueNoise(x * 34, y * 34 + off, z * 34);
      fields[3][k] = fbm(x * 2.6, y * 2.6 + off, z * 2.6 - off, 4);
    }
  }
  const data = new Uint8Array(n * 4);
  fields.forEach((f, c) => {
    const eq = equalize(f);
    // Height: 65th percentile becomes sea level (0.5), so ~35% of pixels are land.
    for (let k = 0; k < n; k++) {
      const v = c === 0 ? (eq[k]! < 0.65 ? (eq[k]! / 0.65) * 0.5 : 0.5 + ((eq[k]! - 0.65) / 0.35) * 0.5) : eq[k]!;
      data[k * 4 + c] = Math.round(v * 255);
    }
  });
  return data;
}
