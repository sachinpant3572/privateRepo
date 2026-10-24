import type { GameState } from '../engine/types';

// Local, per-device persistence. Every access is guarded: private mode,
// blocked storage and WebView quirks must never break a run.

const SAVE_KEY = 'fe.save.v1';
const META_KEY = 'fe.meta.v1';

export interface Meta {
  runs: number;
  endings: Record<string, { count: number; best: number }>;
  dailyDone: string | null;
  settings: { reducedMotion: boolean; haptics: boolean };
}

const DEFAULT_META: Meta = { runs: 0, endings: {}, dailyDone: null, settings: { reducedMotion: false, haptics: true } };

function read<T>(key: string): T | null {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

function write(key: string, value: unknown) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage unavailable: the game still plays, it just won't remember */
  }
}

export const loadRun = () => {
  const s = read<GameState & { daily?: string }>(SAVE_KEY);
  return s && s.version === 1 && !s.ending ? s : null;
};
export const saveRun = (s: (GameState & { daily?: string }) | null) => write(SAVE_KEY, s);

export function loadMeta(): Meta {
  const m = read<Meta>(META_KEY);
  return m ? { ...DEFAULT_META, ...m, settings: { ...DEFAULT_META.settings, ...m.settings } } : structuredClone(DEFAULT_META);
}
export const saveMeta = (m: Meta) => write(META_KEY, m);

export function recordEnding(meta: Meta, id: string, turns: number): { meta: Meta; isNew: boolean } {
  const prev = meta.endings[id];
  const next: Meta = {
    ...meta,
    runs: meta.runs + 1,
    endings: { ...meta.endings, [id]: { count: (prev?.count ?? 0) + 1, best: Math.min(prev?.best ?? Infinity, turns) } },
  };
  saveMeta(next);
  return { meta: next, isNew: !prev };
}
