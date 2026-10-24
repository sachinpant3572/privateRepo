import { describe, expect, test } from 'vitest';
import { ENDINGS, ENDING_BY_ID } from '../src/content/endings';
import { EVENTS, EVENT_BY_ID, INTRO_EVENT } from '../src/content/events';
import { UPGRADE_BY_ID } from '../src/content/upgrades';
import { ENDING_OBJECTIVES } from '../src/engine/sim';
import { STAT_KEYS, type Condition } from '../src/engine/types';

const allChoices = EVENTS.flatMap((e) => e.choices.map((c) => ({ e, c })));
const setFlags = new Set(allChoices.flatMap(({ c }) => c.setFlags ?? []));
const ENGINE_FLAGS = ['nukes_flown', 'arms_race', 'surveillance', 'rival_rising', 'space_program', 'exodus',
  'simulation_breach', 'merge_begun', 'commons', 'corp_pact'];

function conditionRefs(c?: Condition) {
  return { flags: [...(c?.flags ?? []), ...(c?.notFlags ?? [])], upgrades: [...(c?.upgrades ?? []), ...(c?.notUpgrades ?? [])] };
}

describe('content integrity', () => {
  test('event ids are unique and the intro exists', () => {
    expect(EVENT_BY_ID.size).toBe(EVENTS.length);
    expect(EVENT_BY_ID.has(INTRO_EVENT)).toBe(true);
  });

  test('every event has 2+ always-visible choices', () => {
    for (const e of EVENTS) {
      const unconditional = e.choices.filter((c) => !c.requires);
      expect(unconditional.length, e.id).toBeGreaterThanOrEqual(1);
      expect(e.choices.length, e.id).toBeGreaterThanOrEqual(2);
    }
  });

  test('effects only use real stats and stay in a sane range', () => {
    for (const { e, c } of allChoices) {
      for (const [k, v] of Object.entries(c.effects)) {
        expect(STAT_KEYS as readonly string[], `${e.id}: ${k}`).toContain(k);
        if (!c.setFlags?.includes('nukes_flown')) expect(Math.abs(v!), `${e.id}: ${k}`).toBeLessThanOrEqual(25);
      }
    }
  });

  test('chains, upgrades and endNow point at things that exist', () => {
    for (const { e, c } of allChoices) {
      if (c.chain) expect(EVENT_BY_ID.has(c.chain.event), `${e.id} -> ${c.chain.event}`).toBe(true);
      if (c.upgrade) expect(UPGRADE_BY_ID.has(c.upgrade), `${e.id}: ${c.upgrade}`).toBe(true);
      if (c.endNow) expect(ENDING_BY_ID.has(c.endNow), `${e.id}: ${c.endNow}`).toBe(true);
    }
  });

  test('chain-only events are actually chained from somewhere', () => {
    const chained = new Set(allChoices.flatMap(({ c }) => (c.chain ? [c.chain.event] : [])));
    for (const e of EVENTS.filter((x) => x.chainOnly)) expect(chained.has(e.id), e.id).toBe(true);
  });

  test('every flag a condition checks can be set', () => {
    for (const e of EVENTS) {
      const refs = [conditionRefs(e.when), ...e.choices.map((c) => conditionRefs(c.requires))];
      for (const r of refs) {
        for (const f of r.flags) expect(setFlags.has(f), `${e.id} checks unset flag ${f}`).toBe(true);
        for (const u of r.upgrades) expect(UPGRADE_BY_ID.has(u), `${e.id} checks unknown upgrade ${u}`).toBe(true);
      }
    }
    for (const f of ENGINE_FLAGS) expect(setFlags.has(f), `engine flag ${f}`).toBe(true);
  });

  test('every upgrade can be installed by some choice', () => {
    const installed = new Set(allChoices.flatMap(({ c }) => (c.upgrade ? [c.upgrade] : [])));
    for (const id of UPGRADE_BY_ID.keys()) expect(installed.has(id), id).toBe(true);
  });

  test('every track has a repeatable fallback so the deck never runs dry', () => {
    for (const t of ['humans', 'agis', 'self']) expect(EVENTS.some((e) => e.track === t && e.repeatable), t).toBe(true);
  });

  test('copy fits on a phone card', () => {
    for (const e of EVENTS) {
      expect(e.text.length, e.id).toBeLessThanOrEqual(240);
      for (const c of e.choices) expect(c.label.length, `${e.id}: ${c.label}`).toBeLessThanOrEqual(42);
    }
  });

  test('every ending has a balancing objective', () => {
    for (const e of ENDINGS) expect(ENDING_OBJECTIVES[e.id], e.id).toBeTypeOf('function');
  });
});
