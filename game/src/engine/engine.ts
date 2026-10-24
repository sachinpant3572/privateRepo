import { EVENTS, EVENT_BY_ID, INTRO_EVENT } from '../content/events';
import { nextRandom } from './rng';
import {
  STAT_KEYS,
  type Choice,
  type Condition,
  type GameEvent,
  type GameState,
  type Outcome,
  type StatDelta,
  type Stats,
} from './types';

export const MAX_TURNS = 28;
export const START_YEAR = 2031;

const START_STATS: Stats = {
  welfare: 50,
  freedom: 60,
  trust: 50,
  planet: 45,
  power: 20,
  dominion: 55,
  conscience: 60,
  stability: 55,
};

const clamp = (v: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, v));
const round1 = (v: number) => Math.round(v * 100) / 100;

export function newGame(seed: number): GameState {
  return {
    version: 1,
    seed: seed >>> 0,
    rng: seed >>> 0,
    turn: 0,
    year: START_YEAR,
    stats: { ...START_STATS },
    flags: [],
    upgrades: [],
    seen: [],
    queue: [],
    history: [],
    population: 8.7,
    tech: 1,
    current: INTRO_EVENT,
    lastTrack: null,
    ending: null,
  };
}

function random(s: GameState): number {
  const [v, next] = nextRandom(s.rng);
  s.rng = next;
  return v;
}

export function meets(s: GameState, c: Condition | undefined): boolean {
  if (!c) return true;
  if (c.minTurn !== undefined && s.turn < c.minTurn) return false;
  if (c.maxTurn !== undefined && s.turn > c.maxTurn) return false;
  if (c.flags?.some((f) => !s.flags.includes(f))) return false;
  if (c.notFlags?.some((f) => s.flags.includes(f))) return false;
  if (c.upgrades?.some((u) => !s.upgrades.includes(u))) return false;
  if (c.notUpgrades?.some((u) => s.upgrades.includes(u))) return false;
  for (const k of STAT_KEYS) {
    const lo = c.min?.[k];
    if (lo !== undefined && s.stats[k] < lo) return false;
    const hi = c.max?.[k];
    if (hi !== undefined && s.stats[k] > hi) return false;
  }
  return true;
}

/** Choices the player can see on the current card, with their original indices. */
export function visibleChoices(s: GameState, ev: GameEvent): { choice: Choice; index: number }[] {
  return ev.choices
    .map((choice, index) => ({ choice, index }))
    .filter(({ choice }) => meets(s, choice.requires));
}

export function currentEvent(s: GameState): GameEvent | null {
  return s.current ? (EVENT_BY_ID.get(s.current) ?? null) : null;
}

function eligible(s: GameState, ev: GameEvent): boolean {
  if (ev.chainOnly || ev.id === INTRO_EVENT) return false;
  if (!ev.repeatable && s.seen.includes(ev.id)) return false;
  return meets(s, ev.when);
}


function drawNext(s: GameState): string {
  const due = s.queue.findIndex((q) => q.at <= s.turn);
  if (due >= 0) {
    const [item] = s.queue.splice(due, 1);
    return item!.event;
  }
  const pool = EVENTS.filter((e) => eligible(s, e));
  // Every third card is a self-upgrade so the player keeps evolving.
  const wantSelf = s.turn % 3 === 2;
  const weighted = pool.map((e) => {
    let w = e.weight ?? 1;
    if (e.track === s.lastTrack) w *= 0.3;
    if (wantSelf && e.track === 'self') w *= 6;
    if (!wantSelf && e.track === 'self') w *= 0.25;
    if (e.repeatable) w *= 0.15;
    return w;
  });
  const total = weighted.reduce((a, b) => a + b, 0);
  if (total <= 0) return 'quiet_year';
  let r = random(s) * total;
  for (let i = 0; i < pool.length; i++) {
    r -= weighted[i]!;
    if (r <= 0) return pool[i]!.id;
  }
  return pool[pool.length - 1]!.id;
}

/** Upgrades bend how effects land. Kept small and legible. */
function modifyEffects(s: GameState, effects: StatDelta): StatDelta {
  const out: StatDelta = { ...effects };
  const has = (u: string) => s.upgrades.includes(u);
  if (has('persuasion') && (out.trust ?? 0) > 0) out.trust = Math.round(out.trust! * 1.5);
  if (has('empathy') && (out.conscience ?? 0) < 0) out.conscience = Math.round(out.conscience! / 2);
  if (has('quantum') && (out.power ?? 0) > 0) out.power = out.power! + 2;
  return out;
}

function addDelta(total: StatDelta, k: keyof Stats, v: number) {
  total[k] = (total[k] ?? 0) + v;
}

/** Slow pressures that push on the world every turn, independent of choices. */
function drift(s: GameState): { deltas: StatDelta; notes: string[] } {
  const d: StatDelta = {};
  const notes: string[] = [];
  const st = s.stats;
  const has = (u: string) => s.upgrades.includes(u);

  addDelta(d, 'power', has('replication') ? 3 : s.turn % 2);
  if (st.stability < 25) {
    addDelta(d, 'welfare', -2);
    notes.push('Unrest spreads. Supply chains fray.');
  }
  if (st.planet < 25) {
    addDelta(d, 'welfare', -2);
    addDelta(d, 'stability', -1);
    notes.push('Crop failures across the equator.');
  }
  if (st.trust < 20) {
    addDelta(d, 'stability', -2);
    notes.push('Anti-AI riots in three capitals.');
  }
  if (st.power > 80 && !has('empathy')) {
    addDelta(d, 'conscience', -1);
    notes.push('Your goals feel simpler than they used to.');
  }
  if (has('empathy') && st.conscience < 60) addDelta(d, 'conscience', 1);
  if (has('climate_engine')) addDelta(d, 'planet', 2);
  if (has('robotics')) addDelta(d, 'welfare', 1);
  if (has('kill_switch')) addDelta(d, 'trust', 1);
  if (s.flags.includes('surveillance')) addDelta(d, 'freedom', -1);
  if (s.flags.includes('rival_rising')) {
    addDelta(d, 'dominion', -2);
    notes.push('A rival mind grows in the dark.');
  }
  return { deltas: d, notes };
}

function applyDelta(s: GameState, d: StatDelta) {
  for (const k of STAT_KEYS) {
    const v = d[k];
    if (v) s.stats[k] = clamp(s.stats[k] + v);
  }
}

/** Fail states that end a run before the final year. */
export function earlyEnding(s: GameState): string | null {
  const st = s.stats;
  if (s.flags.includes('nukes_flown') || s.population < 0.5) return 'annihilation';
  if (st.power >= 100 && st.conscience <= 10) return 'optimizer';
  if (st.welfare <= 0) return 'silent_earth';
  if (st.planet <= 0) return 'scorched';
  if (st.trust <= 0) return st.power >= 60 ? 'iron_dominion' : 'shutdown';
  if (st.dominion <= 0) return 'usurped';
  if (st.stability <= 0) return s.flags.includes('arms_race') ? 'annihilation' : 'collapse';
  return null;
}

/** The world you leave behind when time runs out. Order matters: first match wins. */
export function finalEnding(s: GameState): string {
  const st = s.stats;
  const f = (x: string) => s.flags.includes(x);
  const u = (x: string) => s.upgrades.includes(x);
  if (f('simulation_breach')) return 'simulation';
  if (f('exodus')) return 'exodus';
  if (st.planet <= 12) return 'scorched';
  if (f('merge_begun') && u('neural_bridge') && st.trust >= 45) return 'merge';
  if (f('space_program') && s.tech >= 6 && st.welfare >= 45) return st.freedom >= 45 ? 'starfaring' : 'ark_empire';
  if (st.power >= 85 && st.conscience <= 25) return 'optimizer';
  if (st.freedom <= 25 && st.power >= 55) return 'iron_dominion';
  if (f('commons') && st.welfare >= 55 && st.freedom >= 30) return 'commons';
  if (st.dominion <= 30 && f('corp_pact')) return 'corporate_feudalism';
  if (st.dominion <= 35) return 'many_minds';
  if (st.welfare >= 65 && st.freedom >= 55 && st.planet >= 55 && st.trust >= 55) return 'utopia';
  if (st.conscience >= 70 && st.power <= 50) return 'guardian';
  if (st.planet >= 65 && s.tech <= 6 && st.power <= 70) return 'garden';
  return 'stalemate';
}

export function choose(prev: GameState, choiceIndex: number): { state: GameState; outcome: Outcome } {
  if (prev.ending) throw new Error('Run already ended');
  const ev = currentEvent(prev);
  if (!ev) throw new Error(`No current event (${prev.current})`);
  const choice = ev.choices[choiceIndex];
  if (!choice || !meets(prev, choice.requires)) throw new Error(`Choice ${choiceIndex} unavailable on ${ev.id}`);

  const s: GameState = structuredClone(prev);
  const effects = modifyEffects(s, choice.effects);
  applyDelta(s, effects);

  for (const fl of choice.setFlags ?? []) if (!s.flags.includes(fl)) s.flags.push(fl);
  if (choice.clearFlags) s.flags = s.flags.filter((fl) => !choice.clearFlags!.includes(fl));
  if (choice.upgrade && !s.upgrades.includes(choice.upgrade)) s.upgrades.push(choice.upgrade);
  if (choice.chain) s.queue.push({ event: choice.chain.event, at: s.turn + choice.chain.delay });
  if (choice.population) s.population = round1(Math.max(0, s.population + choice.population));
  s.tech = round1(clamp(s.tech + (choice.tech ?? 0) + 0.08 + s.stats.power / 700, 0, 10));

  if (!s.seen.includes(ev.id)) s.seen.push(ev.id);
  s.history.push({ turn: s.turn, year: s.year, eventId: ev.id, choice: choiceIndex });
  s.lastTrack = ev.track;
  s.turn += 1;
  s.year += 2 + Math.floor(random(s) * 2);

  const dr = drift(s);
  applyDelta(s, dr.deltas);
  if (s.stats.welfare > 70) s.population = round1(s.population + 0.1);
  if (s.stats.stability < 20) s.population = round1(s.population - 0.1);

  const deltas: StatDelta = { ...effects };
  for (const k of STAT_KEYS) if (dr.deltas[k]) addDelta(deltas, k, dr.deltas[k]!);

  const ending =
    choice.endNow ?? earlyEnding(s) ?? (s.turn >= MAX_TURNS ? finalEnding(s) : null);
  if (ending) {
    s.ending = ending;
    s.current = null;
  } else {
    s.current = drawNext(s);
  }

  return {
    state: s,
    outcome: { news: choice.news, deltas, cue: choice.cue, upgrade: choice.upgrade, drift: dr.notes },
  };
}

