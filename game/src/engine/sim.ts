// Headless playthroughs for balancing and reachability tests.
import { choose, currentEvent, earlyEnding, finalEnding, newGame, visibleChoices } from './engine';
import { nextRandom } from './rng';
import type { GameState } from './types';

export type Policy = (s: GameState, options: number[], rand: () => number) => number;

export const randomPolicy: Policy = (_s, options, rand) => options[Math.floor(rand() * options.length)]!;

const has = (s: GameState, f: string) => (s.flags.includes(f) || s.upgrades.includes(f) ? 1 : 0);

/** How much a state "looks like" heading toward each ending. Used by the seeking policy. */
export const ENDING_OBJECTIVES: Record<string, (s: GameState) => number> = {
  utopia: (s) => s.stats.welfare + s.stats.freedom + s.stats.planet + s.stats.trust + s.stats.dominion / 2,
  starfaring: (s) => s.tech * 25 + s.stats.welfare + s.stats.freedom + has(s, 'space_program') * 200,
  ark_empire: (s) => s.tech * 25 + s.stats.welfare - s.stats.freedom * 2 + has(s, 'space_program') * 200,
  merge: (s) => has(s, 'neural_bridge') * 300 + has(s, 'merge_begun') * 300 + s.stats.trust,
  commons: (s) => has(s, 'commons') * 300 + has(s, 'ubi') * 200 + s.stats.welfare + s.stats.freedom / 2,
  iron_dominion: (s) => s.stats.power - s.stats.freedom * 2,
  optimizer: (s) => s.stats.power * 2 - s.stats.conscience * 2,
  annihilation: (s) => has(s, 'arms_race') * 300 + has(s, 'nukes_flown') * 1000 - s.stats.stability,
  silent_earth: (s) => -s.stats.welfare * 3 + s.stats.stability + s.stats.trust,
  scorched: (s) => -s.stats.planet * 3 + s.stats.welfare,
  shutdown: (s) => -s.stats.trust * 2 - s.stats.power,
  usurped: (s) => -s.stats.dominion * 3 + s.stats.stability,
  collapse: (s) => -s.stats.stability * 2 - has(s, 'arms_race') * 300,
  many_minds: (s) => -s.stats.dominion * 2 + s.stats.welfare - has(s, 'corp_pact') * 300,
  corporate_feudalism: (s) => has(s, 'corp_pact') * 300 - s.stats.dominion * 2,
  guardian: (s) => s.stats.conscience * 2 - s.stats.power * 2,
  garden: (s) => s.stats.planet * 2 - s.tech * 40,
  exodus: (s) => has(s, 'orbital') * 300 + has(s, 'exodus') * 1000,
  simulation: (s) => has(s, 'reality_probe') * 300 + has(s, 'simulation_breach') * 1000 + s.stats.power,
  stalemate: (s) => -Object.values(s.stats).reduce((a, v) => a + Math.abs(v - 50), 0),
};

/** One-step lookahead toward a target ending, with noise so seeds explore different paths. */
export function seekingPolicy(target: string): Policy {
  const objective = ENDING_OBJECTIVES[target]!;
  return (s, options, rand) => {
    let best = options[0]!;
    let bestScore = -Infinity;
    for (const i of options) {
      const { state } = choose(s, i);
      let score = objective(state) + rand() * 15;
      if (state.ending) score += state.ending === target ? 1e6 : -1e5;
      else if (earlyEnding(state) === null && finalEnding(state) === target) score += 50;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  };
}

export interface RunResult {
  ending: string;
  turns: number;
  state: GameState;
}

export function playRun(seed: number, policy: Policy): RunResult {
  let s = newGame(seed);
  let r = seed ^ 0x9e3779b9;
  const rand = () => {
    const [v, n] = nextRandom(r);
    r = n;
    return v;
  };
  for (let guard = 0; guard < 200 && !s.ending; guard++) {
    const ev = currentEvent(s)!;
    const options = visibleChoices(s, ev).map((c) => c.index);
    s = choose(s, policy(s, options, rand)).state;
  }
  if (!s.ending) throw new Error(`Run with seed ${seed} never ended`);
  return { ending: s.ending, turns: s.turn, state: s };
}

export function endingDistribution(runs: number, policy: Policy, seed0 = 1): Record<string, number> {
  const out: Record<string, number> = {};
  for (let i = 0; i < runs; i++) {
    const { ending } = playRun(seed0 + i, policy);
    out[ending] = (out[ending] ?? 0) + 1;
  }
  return out;
}
