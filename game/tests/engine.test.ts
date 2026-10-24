import { describe, expect, test } from 'vitest';
import { EVENT_BY_ID } from '../src/content/events';
import { choose, currentEvent, MAX_TURNS, newGame, visibleChoices } from '../src/engine/engine';
import { dailySeed, nextRandom } from '../src/engine/rng';
import { playRun, randomPolicy } from '../src/engine/sim';
import { STAT_KEYS, type GameState } from '../src/engine/types';

describe('rng', () => {
  test('is deterministic and in [0,1)', () => {
    let a = 42, b = 42;
    for (let i = 0; i < 1000; i++) {
      const [va, na] = nextRandom(a);
      const [vb, nb] = nextRandom(b);
      expect(va).toBe(vb);
      expect(va).toBeGreaterThanOrEqual(0);
      expect(va).toBeLessThan(1);
      a = na; b = nb;
    }
  });

  test('daily seed is stable within a UTC day', () => {
    expect(dailySeed(new Date('2026-10-24T01:00:00Z'))).toBe(dailySeed(new Date('2026-10-24T23:00:00Z')));
    expect(dailySeed(new Date('2026-10-24T01:00:00Z'))).not.toBe(dailySeed(new Date('2026-10-25T01:00:00Z')));
  });
});

describe('engine', () => {
  test('starts on the intro card', () => {
    const s = newGame(1);
    expect(currentEvent(s)?.id).toBe('awakening');
    expect(s.turn).toBe(0);
  });

  test('same seed + same choices = same game', () => {
    const a = playRun(777, randomPolicy);
    const b = playRun(777, randomPolicy);
    expect(a.state).toEqual(b.state);
  });

  test('choose() does not mutate the previous state', () => {
    const s = newGame(5);
    const snapshot = structuredClone(s);
    choose(s, 0);
    expect(s).toEqual(snapshot);
  });

  test('stats stay within 0..100 across many runs', () => {
    for (let seed = 1; seed <= 300; seed++) {
      const { state } = playRun(seed, randomPolicy);
      for (const k of STAT_KEYS) {
        expect(state.stats[k]).toBeGreaterThanOrEqual(0);
        expect(state.stats[k]).toBeLessThanOrEqual(100);
        expect(Number.isFinite(state.stats[k])).toBe(true);
      }
      expect(state.turn).toBeLessThanOrEqual(MAX_TURNS);
      expect(state.ending).toBeTruthy();
    }
  });

  test('hidden choices cannot be picked', () => {
    let s = newGame(3);
    // Jump straight to the famine card without robotics.
    s = { ...s, current: 'famine' };
    const vis = visibleChoices(s, EVENT_BY_ID.get('famine')!).map((c) => c.index);
    expect(vis).not.toContain(0);
    expect(() => choose(s, 0)).toThrow();
  });

  test('authorizing the strike ends the world immediately', () => {
    const s = { ...newGame(3), current: 'standoff', flags: ['arms_race'] };
    const { state } = choose(s, 2);
    expect(state.ending).toBe('annihilation');
  });

  test('chained events arrive on schedule', () => {
    let s: GameState = { ...newGame(9), current: 'automation' };
    s = choose(s, 0).state; // UBI -> commons_vote in 4 turns
    const seenAt: string[] = [];
    while (!s.ending && s.turn < 8) {
      seenAt.push(s.current!);
      const ev = currentEvent(s)!;
      s = choose(s, visibleChoices(s, ev)[0]!.index).state;
    }
    expect(seenAt).toContain('commons_vote');
  });
});
