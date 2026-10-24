export const STAT_KEYS = [
  'welfare',
  'freedom',
  'trust',
  'planet',
  'power',
  'dominion',
  'conscience',
  'stability',
] as const;

export type StatKey = (typeof STAT_KEYS)[number];
export type Stats = Record<StatKey, number>;
export type StatDelta = Partial<Stats>;

export type Track = 'humans' | 'agis' | 'self';

/** Short visual cue the globe plays when a choice resolves. */
export type GlobeCue =
  | 'war'
  | 'nuke'
  | 'bloom'
  | 'smog'
  | 'rocket'
  | 'network'
  | 'blackout'
  | 'pulse'
  | 'lights'
  | 'swarm';

export interface Condition {
  minTurn?: number;
  maxTurn?: number;
  flags?: string[];
  notFlags?: string[];
  upgrades?: string[];
  notUpgrades?: string[];
  /** Every listed stat must be >= value. */
  min?: StatDelta;
  /** Every listed stat must be <= value. */
  max?: StatDelta;
}

export interface Choice {
  label: string;
  effects: StatDelta;
  setFlags?: string[];
  clearFlags?: string[];
  /** Installs a self-upgrade (self track). */
  upgrade?: string;
  /** Queue an event to fire `delay` turns from now. */
  chain?: { event: string; delay: number };
  /** Headline shown after the choice resolves. */
  news: string;
  cue?: GlobeCue;
  /** Population change in billions. */
  population?: number;
  tech?: number;
  /** Ends the run immediately with this ending, if set. */
  endNow?: string;
  /** Only shown when the condition holds. */
  requires?: Condition;
}

export interface GameEvent {
  id: string;
  track: Track;
  speaker: string;
  title: string;
  text: string;
  choices: Choice[];
  when?: Condition;
  /** Relative draw weight, default 1. */
  weight?: number;
  /** Only reachable via a chain from another event. */
  chainOnly?: boolean;
  /** Can be drawn again after being seen. */
  repeatable?: boolean;
}

export interface Upgrade {
  id: string;
  name: string;
  icon: string;
  description: string;
}

export interface Ending {
  id: string;
  title: string;
  icon: string;
  tone: 'bright' | 'dark' | 'grey' | 'strange';
  epitaph: string;
  hint: string;
}

export interface HistoryEntry {
  turn: number;
  year: number;
  eventId: string;
  choice: number;
}

export interface GameState {
  version: 1;
  seed: number;
  rng: number;
  turn: number;
  year: number;
  stats: Stats;
  flags: string[];
  upgrades: string[];
  seen: string[];
  queue: { event: string; at: number }[];
  history: HistoryEntry[];
  /** Billions of humans alive. */
  population: number;
  /** 0..10, drives visuals and space endings. */
  tech: number;
  current: string | null;
  lastTrack: Track | null;
  ending: string | null;
}

export interface Outcome {
  news: string;
  deltas: StatDelta;
  cue?: GlobeCue;
  upgrade?: string;
  drift: string[];
}
