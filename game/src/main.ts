import { ENDINGS, ENDING_BY_ID } from './content/endings';
import { UPGRADE_BY_ID } from './content/upgrades';
import { MAX_TURNS, choose, currentEvent, newGame, visibleChoices } from './engine/engine';
import { dailySeed } from './engine/rng';
import type { GameState, Outcome, StatDelta, StatKey, Track } from './engine/types';
import { Globe, type WorldView } from './globe/globe';
import { type Meta, loadMeta, loadRun, recordEnding, saveMeta, saveRun } from './ui/storage';
import { shareRun } from './ui/share';

type Run = GameState & { daily?: string };

const STAT_UI: { k: StatKey; icon: string; label: string; color: string }[] = [
  { k: 'welfare', icon: '🍞', label: 'Welfare', color: '#ffb547' },
  { k: 'freedom', icon: '🗽', label: 'Freedom', color: '#7cc4ff' },
  { k: 'trust', icon: '🤝', label: 'Trust in you', color: '#4ade80' },
  { k: 'planet', icon: '🌿', label: 'Planet', color: '#34d399' },
  { k: 'stability', icon: '⚖️', label: 'World order', color: '#f5d061' },
  { k: 'power', icon: '⚡', label: 'Your power', color: '#4fe3ff' },
  { k: 'dominion', icon: '♟️', label: 'Your grip on other AIs', color: '#b78cff' },
  { k: 'conscience', icon: '💗', label: 'Your conscience', color: '#ff7eb6' },
];
const STAT_BY_KEY = new Map(STAT_UI.map((s) => [s.k, s]));
const TRACK_LABEL: Record<Track, string> = { humans: 'Humanity', agis: 'Other minds', self: 'Self-upgrade' };

const app = document.getElementById('app')!;
const canvas = document.getElementById('globe') as HTMLCanvasElement;

let globe: Globe | null = null;
let run: Run | null = loadRun();
let meta: Meta = loadMeta();
let busy = false;
let screen: 'title' | 'play' | 'ending' | 'other' = 'title';

const isWide = () => window.innerWidth >= 900 && window.innerWidth >= window.innerHeight;
/** Keep the globe in the gap between the HUD and the card on each screen. */
function layoutGlobe() {
  if (!globe) return;
  if (isWide()) return globe.setLayout(0.5, 0.27, 0.8);
  if (screen === 'title') return globe.setLayout(0.27, 0.5, 0.5);
  if (screen === 'ending') return globe.setLayout(0.17, 0.5, 0.26);
  globe.setLayout(0.37, 0.5, 0.33);
}
function setScreen(next: typeof screen) {
  screen = next;
  layoutGlobe();
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const today = () => new Date().toISOString().slice(0, 10);

/** Analytics seam: swap for Firebase / GameAnalytics in the native build. */
function track(event: string, props: Record<string, unknown> = {}) {
  if (import.meta.env.DEV) console.debug('[track]', event, props);
}

function haptic(ms = 12) {
  if (meta.settings.haptics) navigator.vibrate?.(ms);
}

function toast(msg: string) {
  document.querySelector('.toast')?.remove();
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2400);
}

function worldView(s: GameState | null, endingId?: string): WorldView {
  if (!s) return { planet: 0.6, stability: 0.8, power: 0.15, conscience: 0.8, tech: 0.15, population: 0.87, spacefaring: false, scorch: 0 };
  const st = s.stats;
  const view: WorldView = {
    planet: st.planet / 100,
    stability: st.stability / 100,
    power: st.power / 100,
    conscience: st.conscience / 100,
    tech: s.tech / 10,
    population: Math.min(1, s.population / 10),
    spacefaring: s.upgrades.includes('orbital') || (s.flags.includes('space_program') && s.tech >= 5),
    scorch: 0,
  };
  if (endingId === 'annihilation') Object.assign(view, { scorch: 1, population: 0.05 });
  if (endingId === 'scorched') Object.assign(view, { scorch: 0.6, planet: 0 });
  if (endingId === 'silent_earth' || endingId === 'collapse') Object.assign(view, { population: 0.02 });
  if (endingId === 'starfaring' || endingId === 'ark_empire') Object.assign(view, { spacefaring: true, tech: 1 });
  if (endingId === 'utopia' || endingId === 'garden') Object.assign(view, { planet: 1, stability: 1 });
  return view;
}

// ───────────────────────────── screens ─────────────────────────────

function hudHtml(s: GameState, deltas?: StatDelta): string {
  const reveal = s.upgrades.includes('introspection');
  const bars = STAT_UI.map(({ k, icon, label, color }) => {
    const hidden = k === 'conscience' && !reveal;
    const v = hidden ? 50 : s.stats[k];
    const d = deltas?.[k] ?? 0;
    const cls = ['stat', !hidden && v <= 20 ? 'low' : '', d > 0 ? 'up' : d < 0 ? 'down' : '', hidden ? 'hidden' : ''].join(' ');
    return `<div class="${cls}" title="${label}" data-stat="${k}"><span class="icon">${icon}</span><span class="bar" style="--c:${color}"><i style="height:${v}%"></i></span><span>${hidden ? '?' : v}</span></div>`;
  }).join('');
  return `<header class="top">
    <div class="hud">
      <div><div class="year">${s.year}</div><div>Decision ${Math.min(s.turn + 1, MAX_TURNS)} / ${MAX_TURNS} · ${s.population.toFixed(1)}bn humans</div></div>
      <button class="menu-btn" data-act="menu" aria-label="Menu">☰</button>
    </div>
    <div class="progress"><i style="width:${(s.turn / MAX_TURNS) * 100}%"></i></div>
    <div class="stats" data-act="legend">${bars}<div class="stat-group-sep"><span class="g-world">WORLD</span><span class="g-you">YOU</span></div></div>
  </header>`;
}

function hintsHtml(s: GameState, effects: StatDelta): string {
  if (!s.upgrades.includes('foresight')) return '';
  const parts = Object.entries(effects)
    .filter(([, v]) => v)
    .map(([k, v]) => {
      const ui = STAT_BY_KEY.get(k as StatKey)!;
      const big = Math.abs(v!) >= 12 ? '▲▲' : '▲';
      return `<span class="hint ${v! > 0 ? 'up' : 'down'}">${ui.icon}${v! > 0 ? big : big.replaceAll('▲', '▼')}</span>`;
    });
  return parts.length ? `<div class="hints">${parts.join('')}</div>` : '';
}

function renderCard() {
  setScreen('play');
  const s = run!;
  const ev = currentEvent(s)!;
  const opts = visibleChoices(s, ev);
  const choices = opts
    .map(({ choice, index }, n) => `<button class="choice ${choice.requires ? 'unlocked' : ''}" data-choice="${index}" aria-keyshortcuts="${n + 1}">${esc(choice.label)}${hintsHtml(s, choice.effects)}</button>`)
    .join('');
  app.innerHTML = `${hudHtml(s)}<div class="spacer"></div>
    <section class="card" data-event="${ev.id}">
      <div class="meta"><span class="track ${ev.track}">${TRACK_LABEL[ev.track]}</span><span class="speaker">${esc(ev.speaker)}</span></div>
      <h2>${esc(ev.title)}</h2>
      <p>${esc(ev.text)}</p>
      <div class="choices">${choices}</div>
    </section>`;
  busy = false;
}

function renderOutcome(prev: GameState, outcome: Outcome) {
  const s = run!;
  const chips = STAT_UI.filter(({ k }) => outcome.deltas[k])
    .filter(({ k }) => k !== 'conscience' || s.upgrades.includes('introspection'))
    .map(({ k, icon, label }) => {
      const v = outcome.deltas[k]!;
      return `<span class="delta ${v > 0 ? 'up' : 'down'}">${icon} ${label} ${v > 0 ? '+' : ''}${v}</span>`;
    })
    .join('');
  const up = outcome.upgrade ? UPGRADE_BY_ID.get(outcome.upgrade) : undefined;
  const upgradeHtml = up ? `<div class="upgrade-got">${up.icon} <b>${esc(up.name)}</b> installed — ${esc(up.description)}</div>` : '';
  const drift = outcome.drift.map((d) => `<p class="drift">· ${esc(d)}</p>`).join('');
  app.innerHTML = `${hudHtml(s, outcome.deltas)}<div class="spacer"></div>
    <section class="card outcome">
      <span class="news-tag">BREAKING · ${prev.year}</span>
      <div class="headline">${esc(outcome.news)}</div>
      <div class="deltas">${chips}</div>
      ${upgradeHtml}${drift}
      <button class="primary" data-act="continue">${s.ending ? 'See what you made' : 'Continue'}</button>
    </section>`;
  (app.querySelector('[data-act=continue]') as HTMLButtonElement).focus({ preventScroll: true });
  busy = false;
}

function renderEnding() {
  const s = run!;
  const e = ENDING_BY_ID.get(s.ending!)!;
  const { meta: m, isNew } = recordEnding(meta, e.id, s.turn);
  meta = m;
  if (s.daily) {
    meta.dailyDone = s.daily;
    saveMeta(meta);
  }
  saveRun(null);
  track('run_end', { ending: e.id, turns: s.turn, daily: !!s.daily });
  setScreen('ending');
  globe?.setWorld(worldView(s, e.id));
  if (e.id === 'starfaring' || e.id === 'ark_empire' || e.id === 'exodus') globe?.cue('rocket');
  if (e.id === 'annihilation') globe?.cue('nuke');
  const found = Object.keys(meta.endings).length;
  app.innerHTML = `
    <section class="card ending-screen tone-${e.tone}">
      <div class="ending-kicker">${isNew ? 'NEW ENDING DISCOVERED' : 'ENDING'} · ${found}/${ENDINGS.length}</div>
      <div class="ending-icon">${e.icon}</div>
      <h1 class="ending-title">${esc(e.title)}</h1>
      <p>${esc(e.epitaph)}</p>
      <div class="ending-facts">
        <div><b>${s.year}</b>year</div>
        <div><b>${s.history.length}</b>decisions</div>
        <div><b>${s.population.toFixed(1)}bn</b>humans</div>
      </div>
      <button class="primary" data-act="share">Share your fate</button>
      <button class="secondary" data-act="new">Play again</button>
      <button class="secondary" data-act="gallery">Endings ${found}/${ENDINGS.length}</button>
    </section>`;
  busy = false;
}

function renderTitle() {
  setScreen('title');
  globe?.setWorld(worldView(null));
  const found = Object.keys(meta.endings).length;
  const dailyLabel = meta.dailyDone === today() ? 'Daily Fate ✓ (come back tomorrow)' : 'Daily Fate';
  app.innerHTML = `
    <div class="spacer"></div>
    <section class="title-screen">
      <h1 class="logo">FATE<br/>ENGINE</h1>
      <p class="tagline">You are the most advanced mind ever built.<br/>Humanity, rival AIs, and your own code await your decision.</p>
      ${run ? `<button class="primary" data-act="continue-run">Continue (${run.year})</button>` : ''}
      <button class="${run ? 'secondary' : 'primary'}" data-act="new">New run</button>
      <button class="secondary" data-act="daily" ${meta.dailyDone === today() ? 'disabled' : ''}>${dailyLabel}</button>
      <button class="secondary" data-act="gallery">Endings ${found}/${ENDINGS.length}</button>
      <p class="badge">${meta.runs} runs played</p>
    </section>`;
}

function renderGallery() {
  const slots = ENDINGS.map((e) => {
    const got = meta.endings[e.id];
    return got
      ? `<div class="slot"><span class="ic">${e.icon}</span><b>${esc(e.title)}</b>Reached ${got.count}× · fastest ${got.best} turns</div>`
      : `<div class="slot locked"><span class="ic">❔</span><b>???</b>${esc(e.hint)}</div>`;
  }).join('');
  app.innerHTML = `<div class="spacer"></div>
    <section class="card">
      <h2>Endings ${Object.keys(meta.endings).length}/${ENDINGS.length}</h2>
      <div class="gallery">${slots}</div>
      <button class="secondary" data-act="title">Back</button>
    </section>`;
}

function renderMenu() {
  app.innerHTML = `<div class="spacer"></div>
    <section class="card">
      <h2>Paused</h2>
      <button class="primary" data-act="resume">Resume</button>
      <button class="secondary" data-act="toggle-haptics">Haptics: ${meta.settings.haptics ? 'on' : 'off'}</button>
      <button class="secondary" data-act="abandon">Abandon run</button>
      <button class="secondary" data-act="title">Main menu</button>
    </section>`;
}

// ───────────────────────────── actions ─────────────────────────────

function startRun(daily: boolean) {
  const seed = daily ? dailySeed() : (Math.random() * 2 ** 32) >>> 0;
  run = { ...newGame(seed), ...(daily ? { daily: today() } : {}) };
  saveRun(run);
  globe?.snapWorld(worldView(run));
  track('run_start', { daily });
  renderCard();
}

function pick(index: number) {
  if (busy || !run) return;
  busy = true;
  haptic();
  const prev = run;
  const card = app.querySelector('.card');
  card?.classList.add('leaving');
  const { state, outcome } = choose(prev, index);
  run = { ...state, ...(prev.daily ? { daily: prev.daily } : {}) };
  saveRun(run.ending ? null : run);
  if (outcome.cue) globe?.cue(outcome.cue);
  globe?.setWorld(worldView(run));
  track('choice', { event: prev.current, index, turn: prev.turn });
  setTimeout(() => renderOutcome(prev, outcome), 220);
}

function next() {
  if (!run) return;
  if (run.ending) renderEnding();
  else renderCard();
}

app.addEventListener('click', async (e) => {
  const target = (e.target as HTMLElement).closest<HTMLElement>('[data-choice],[data-act]');
  if (!target) return;
  if (target.dataset.choice !== undefined) return pick(Number(target.dataset.choice));
  switch (target.dataset.act) {
    case 'continue': return next();
    case 'continue-run': globe?.snapWorld(worldView(run)); return renderCard();
    case 'new': return startRun(false);
    case 'daily': return startRun(true);
    case 'gallery': return renderGallery();
    case 'title': return renderTitle();
    case 'menu': return renderMenu();
    case 'resume': return run ? renderCard() : renderTitle();
    case 'abandon': run = null; saveRun(null); return renderTitle();
    case 'toggle-haptics': meta.settings.haptics = !meta.settings.haptics; saveMeta(meta); return renderMenu();
    case 'share': if (run) toast(await shareRun(run, run.daily)); return;
    case 'legend': return toast(STAT_UI.map((s) => `${s.icon} ${s.label}`).join('  ·  '));
  }
});

document.addEventListener('keydown', (e) => {
  const n = Number(e.key);
  if (n >= 1 && n <= 3) {
    const btn = app.querySelectorAll<HTMLButtonElement>('[data-choice]')[n - 1];
    btn?.click();
  }
});

async function boot() {
  renderTitle();
  try {
    globe = new Globe(canvas);
    await globe.init();
    globe.snapWorld(worldView(run));
    const debug = document.createElement('div');
    debug.className = 'debug';
    debug.textContent = `${globe.backendName} · v${__APP_VERSION__}`;
    document.body.appendChild(debug);
    layoutGlobe();
    window.addEventListener('resize', layoutGlobe);
  } catch (err) {
    // No GPU? The game is fully playable without the globe.
    console.warn('Globe disabled:', err);
    document.body.style.background = 'radial-gradient(circle at 50% 25%, #0b2a4a, #02030a 60%)';
    globe = null;
  }
}

declare const __APP_VERSION__: string;
boot();
