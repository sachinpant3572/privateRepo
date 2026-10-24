/** mulberry32: tiny, fast, deterministic. State is a uint32 so it serializes cleanly. */
export function nextRandom(state: number): [value: number, next: number] {
  let t = (state + 0x6d2b79f5) >>> 0;
  const next = t;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return [((t ^ (t >>> 14)) >>> 0) / 4294967296, next];
}

export function hashString(s: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/** Same seed for everyone on the same UTC day — powers the Daily Fate mode. */
export function dailySeed(date = new Date()): number {
  return hashString(`fate-${date.toISOString().slice(0, 10)}`);
}
