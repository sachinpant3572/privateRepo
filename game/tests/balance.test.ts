import { expect, test } from 'vitest';
import { ENDINGS } from '../src/content/endings';
import { endingDistribution, playRun, randomPolicy, seekingPolicy } from '../src/engine/sim';

// These guard the "every ending is reachable, no ending dominates" promise
// that the ending-collection loop depends on.

test('a goal-seeking player can reach every ending', () => {
  const misses: string[] = [];
  for (const e of ENDINGS) {
    let hits = 0;
    for (let i = 0; i < 40; i++) if (playRun(5000 + i, seekingPolicy(e.id)).ending === e.id) hits++;
    if (hits < 2) misses.push(`${e.id} (${hits}/40)`);
  }
  expect(misses).toEqual([]);
}, 120_000);

test('random play does not collapse onto one ending', () => {
  const runs = 3000;
  const dist = endingDistribution(runs, randomPolicy);
  const top = Math.max(...Object.values(dist)) / runs;
  expect(top).toBeLessThan(0.22);
  expect(Object.keys(dist).length).toBeGreaterThanOrEqual(15);
}, 60_000);

test('runs last long enough to feel like a story', () => {
  let turns = 0;
  for (let i = 0; i < 1000; i++) turns += playRun(i + 1, randomPolicy).turns;
  const avg = turns / 1000;
  expect(avg).toBeGreaterThan(20);
  expect(avg).toBeLessThanOrEqual(28);
});
