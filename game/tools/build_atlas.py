#!/usr/bin/env python3
"""Builds the interactive Solvera atlas page (one HTML file) from the map data.

Usage: python3 game/tools/build_atlas.py <out.html>
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_map  # noqa: E402

# Short descriptions from WORLD_BIBLE.md, keyed by map id.
BLURBS = {
    "bellerive": "Jazz, balconies, humid nights, streetcars, the river always nearby. The MVP city.",
    "porto_brisa": "Beaches, steep hillside neighbourhoods, carnival and football on the east coast.",
    "las_brasas": "Neon, heat, desert nights and excess in the north-west desert.",
    "lantern_quarter": "Gas lamps, iron balconies, jazz clubs and tourists. Story hub, shops and nightlife around Lantern Square.",
    "ironwharf": "Cranes, warehouses and container stacks on the river. Smuggling, boats, heist targets, the cruise terminal.",
    "gilt_district": "Glass towers, Aurum Tower and Union Station, where the Solvera Line begins. High-security zone.",
    "magnolia_heights": "Mansions under oak trees. Wealthy targets and property to buy.",
    "floodline_wards": "Colourful shotgun houses still scarred by the Great Storm. Turf wars, street business, basketball.",
    "blackwater_bayou": "Swamp, stilt houses and airboats. Hidden places, lore and boat chases.",
    "praia_dourada": "Long beach, kiosks, volleyball and the promenade.",
    "morro_alto": "Hillside houses, stairways and rooftop views.",
    "centro_velho": "The old colonial centre, metro hub and the Avenida da Festa.",
    "marina_azul": "Yachts, seafood markets and the ferry to Isla Serena.",
    "the_blaze": "The neon strip: shows, giant hotels and the monorail.",
    "old_town_brasas": "The original rail town: pawn shops and diners.",
    "ember_heights": "Gated suburbs and golf greens.",
    "dust_yards": "Rail yards, scrap and biker bars.",
    "hollow_mesa": "Desert, mesas and the Sable Junction rail stop.",
    "fort_granite": "Restricted army base with an airfield. What is in the vault?",
    "cinder_ridge": "Mountains, old silver mines and a winding pass road.",
    "red_pine": "Forests, farms and small towns like Dellwood.",
    "miravel_shores": "A reservoir with cabins and water sports. A village lies under the water.",
    "verdant_hills": "Green hills and dirt roads between Bellerive and Porto Brisa.",
    "golden_flats": "Coastal farmland, truck stops and crop dusters.",
    "saltgrass": "Bayou fishing villages and the Old Salt Mine.",
    "isla_serena": "Resort island and free port where smugglers and billionaires mix.",
    "drowned_streetcar": "Seen on flooded nights. Following it leads to Teo's hideout.",
    "silver_train": "Lost 150 years ago and sealed in a collapsed tunnel.",
    "drowned_village": "Its rooftops show only in a drought year.",
    "sunken_casino": "A hotel that slid into the sea. A late-game dive.",
    "granite_vault": "What the army really stores under the base.",
    "smugglers_cave": "The Sentinel's light signals smugglers in code.",
    "solvera_line": "Aurum's high-speed railway, built during the story. Every gang wants a piece of it.",
}
KIND_LABEL = {"mission": "Act 1 mission", "city": "City", "district": "District", "region": "Region", "route": "Route", "town": "Town", "landmark": "Landmark"}
PHASES = {1: "Phase 1 · MVP", 2: "Phase 2 · Expansion 1", 3: "Phase 3 · Expansion 2", 4: "Phase 4 · Expansion 3"}


def build_index(world, missions):
    """Flat lookup of everything the page can describe."""
    factions = {f["id"]: f for f in world["factions"]}
    items = {}

    def add(kind, item, **extra):
        entry = {"kind": KIND_LABEL[kind], "name": item["name"], "blurb": BLURBS.get(item["id"], "")}
        entry.update({k: v for k, v in extra.items() if v})
        items[f'{kind}:{item["id"]}'] = entry

    for c in world["cities"]:
        add("city", c, phase=c["phase"], note=f'Inspired by {c["inspired_by"]}')
        for d in c["districts"]:
            f = factions.get(d["faction"], {})
            add("district", d, phase=c["phase"], city=c["name"], style=d["style"], faction=f.get("name"), color=f.get("color"))
    for r in world["regions"]:
        add("region", r, phase=r["phase"], style=r["type"])
    for r in world["routes"]:
        add("route", r, phase=r["phase"], style=r["type"])
    for t in world["towns"]:
        add("town", t, phase=t["phase"])
    for lm in world["landmarks"]:
        add("landmark", lm, phase=render_map._phase_of(world, lm), style=lm["type"], secret=lm.get("secret", False))
    names = {lm["id"]: lm["name"] for lm in world["landmarks"]}
    for m in missions:
        where = [names[st] if isinstance(st, str) else st["label"] for st in m["stops"]]
        items[f'mission:{m["id"]}'] = {
            "kind": KIND_LABEL["mission"], "name": f'{m["order"]}. {m["name"]}', "blurb": m["summary"], "phase": 1,
            "giver": m["giver"], "route": " → ".join(dict.fromkeys(where)),
            "approaches": ", ".join(m.get("approaches", [])),
            "choice": " / ".join(m.get("choice", [b["name"] for b in m.get("branches", [])])),
            "teaches": ", ".join(m["teaches"]), "unlocks": ", ".join(m["unlocks"]),
        }
    return items


PAGE = """<title>Solvera Atlas</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gloock&family=Work+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@500&display=swap">
<style>
/* Layout: atlas sheet. Title band, view switch, the map plate, then a legend card that becomes the selected place's entry. */
:root {
  --paper: #f3f1ea; --ink: #1f2a2e; --muted: #5d6a6c; --plate: #e4e8df; --line: #c9cfc4;
  --accent: #2f6f8f; --secret: #6a1b9a; --chip: #ffffff;
  --display: "Gloock", Georgia, serif; --body: "Work Sans", system-ui, sans-serif; --mono: "IBM Plex Mono", ui-monospace, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --paper: #151b1e; --ink: #e8ebe6; --muted: #9aa7a8; --plate: #1f272b; --line: #34403f;
  --accent: #7fb8d4; --secret: #c79be0; --chip: #232c30; color-scheme: dark } }
:root[data-theme="dark"] {
  --paper: #151b1e; --ink: #e8ebe6; --muted: #9aa7a8; --plate: #1f272b; --line: #34403f;
  --accent: #7fb8d4; --secret: #c79be0; --chip: #232c30; color-scheme: dark }
body { background: var(--paper); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.5;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 20px 40px; }
.wrap { max-width: 1180px; margin: 0 auto; display: grid; gap: 16px; }
header { display: grid; gap: 4px; }
h1 { font-family: var(--display); font-weight: 400; font-size: clamp(30px, 6vw, 46px); line-height: 1.05; margin: 0; text-wrap: balance; }
.sub { color: var(--muted); margin: 0; max-width: 62ch; }
.bar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.seg, .chip, .zoom button { font: 500 14px var(--body); color: var(--ink); background: var(--chip); border: 1px solid var(--line);
  border-radius: 999px; padding: 6px 14px; cursor: pointer; }
.seg[aria-pressed="true"], .chip[aria-pressed="true"] { background: var(--ink); color: var(--paper); border-color: var(--ink); }
button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.spacer { flex: 1; }
.zoom { display: flex; gap: 6px; }
.zoom button { width: 38px; padding: 6px 0; }
.main { display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 16px; align-items: start; }
@media (max-width: 860px) { .main { grid-template-columns: minmax(0, 1fr); } }
.plate { background: var(--plate); border: 1px solid var(--line); border-radius: 10px; overflow: auto; max-height: 78vh; -webkit-overflow-scrolling: touch; }
.plate svg { display: block; width: calc(100% * var(--z, 1)); height: auto; max-width: none; }
.plate [data-kind] { cursor: pointer; transition: opacity .15s; }
.plate [data-kind]:hover { filter: brightness(1.08); }
.plate .dim { opacity: .18; }
.plate .picked { stroke: #111 !important; stroke-width: 4px; }
.entry { background: var(--chip); border: 1px solid var(--line); border-radius: 10px; padding: 16px; display: grid; gap: 10px; min-width: 0; }
.eyebrow { font: 500 12px var(--mono); letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: 0; }
.entry h2 { font-family: var(--display); font-weight: 400; font-size: 26px; line-height: 1.1; margin: 0; }
.entry p { margin: 0; }
.facts { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; margin: 0; font-size: 14px; }
.facts dt { color: var(--muted); }
.facts dd { margin: 0; }
.swatch { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 6px; vertical-align: middle; }
.secret { color: var(--secret); font-weight: 600; }
.hint { color: var(--muted); font-size: 14px; }
@media (prefers-reduced-motion: reduce) { .plate [data-kind] { transition: none; } }
</style>
<div class="wrap">
  <header>
    <p class="eyebrow">World map · 8 × 6 km · draft</p>
    <h1>Solvera Atlas</h1>
    <p class="sub">Three cities, the countryside between them and an island offshore. Tap any district, region, route or landmark to read its entry. Phases show the build order.</p>
  </header>
  <div class="bar" role="toolbar" aria-label="Map controls">
    <button class="seg" id="view-world" aria-pressed="true">Whole state</button>
    <button class="seg" id="view-city" aria-pressed="false">Bellerive · act 1 missions</button>
    <span class="spacer"></span>
    <div class="zoom"><button id="zoom-out" aria-label="Zoom out">−</button><button id="zoom-in" aria-label="Zoom in">+</button></div>
  </div>
  <div class="bar" role="group" aria-label="Highlight build phase" id="phases"></div>
  <div class="main">
    <div class="plate" id="plate"><div id="map-world">__WORLD__</div><div id="map-city" hidden>__CITY__</div></div>
    <aside class="entry" id="entry" aria-live="polite"></aside>
  </div>
</div>
<script>
const ITEMS = __ITEMS__;
const PHASES = __PHASES__;
const entry = document.getElementById('entry');
const plate = document.getElementById('plate');
let zoom = 1, phase = 0, picked = null;

function esc(s) { return String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }

function showDefault() {
  entry.innerHTML = '<p class="eyebrow">How to read it</p><h2>Solvera</h2>' +
    '<p>A fictional Gulf-coast state. Bellerive (phase 1) is built first; Porto Brisa, the countryside, Las Brasas and Isla Serena follow as expansions.</p>' +
    '<p class="hint">Tap a coloured shape, line or dot on the map. A ? marks a secret. The Bellerive view numbers the 13 act 1 missions.</p>';
}

function show(key) {
  const it = ITEMS[key];
  if (!it) return;
  const rows = [];
  if (it.city) rows.push(['City', esc(it.city)]);
  if (it.faction) rows.push(['Faction', '<span class="swatch" style="background:' + esc(it.color) + '"></span>' + esc(it.faction)]);
  if (it.style) rows.push(['Type', esc(it.style)]);
  if (it.note) rows.push(['Note', esc(it.note)]);
  if (it.giver) rows.push(['Giver', esc(it.giver)]);
  if (it.route) rows.push(['Route', esc(it.route)]);
  if (it.approaches) rows.push(['Ways in', esc(it.approaches)]);
  if (it.choice) rows.push(['Choice', esc(it.choice)]);
  if (it.teaches) rows.push(['Teaches', esc(it.teaches)]);
  if (it.unlocks) rows.push(['Unlocks', esc(it.unlocks)]);
  if (it.phase) rows.push(['Build', esc(PHASES[it.phase])]);
  entry.innerHTML = '<p class="eyebrow">' + esc(it.kind) + (it.secret ? ' · <span class="secret">secret</span>' : '') + '</p>' +
    '<h2>' + esc(it.name) + '</h2>' + (it.blurb ? '<p>' + esc(it.blurb) + '</p>' : '') +
    '<dl class="facts">' + rows.map(r => '<dt>' + r[0] + '</dt><dd>' + r[1] + '</dd>').join('') + '</dl>';
}

plate.addEventListener('click', e => {
  const el = e.target.closest('[data-kind]');
  if (picked) picked.classList.remove('picked');
  if (!el) { picked = null; showDefault(); return; }
  picked = el; el.classList.add('picked');
  show(el.dataset.kind + ':' + el.dataset.id);
});

function setView(city) {
  document.getElementById('map-world').hidden = city;
  document.getElementById('map-city').hidden = !city;
  document.getElementById('view-world').setAttribute('aria-pressed', String(!city));
  document.getElementById('view-city').setAttribute('aria-pressed', String(city));
}
document.getElementById('view-world').onclick = () => setView(false);
document.getElementById('view-city').onclick = () => setView(true);

function setZoom(z) { zoom = Math.min(4, Math.max(1, z)); plate.style.setProperty('--z', zoom); }
document.getElementById('zoom-in').onclick = () => setZoom(zoom * 1.5);
document.getElementById('zoom-out').onclick = () => setZoom(zoom / 1.5);

const phaseBar = document.getElementById('phases');
[[0, 'All phases'], ...Object.entries(PHASES).map(([k, v]) => [Number(k), v])].forEach(([p, label]) => {
  const b = document.createElement('button');
  b.className = 'chip'; b.id = 'phase-' + p; b.textContent = label; b.setAttribute('aria-pressed', String(p === 0));
  b.onclick = () => {
    phase = p;
    phaseBar.querySelectorAll('.chip').forEach(c => c.setAttribute('aria-pressed', String(c === b)));
    plate.querySelectorAll('[data-phase]').forEach(el => el.classList.toggle('dim', p > 0 && Number(el.dataset.phase) !== p));
  };
  phaseBar.appendChild(b);
});
showDefault();
</script>
"""


def main():
    out = Path(sys.argv[1])
    world = json.loads(render_map.DATA.read_text())
    missions = json.loads(render_map.MISSIONS.read_text())["missions"]
    page = (PAGE.replace("__WORLD__", render_map.world_svg(world))
            .replace("__CITY__", render_map.city_svg(world, "bellerive", missions))
            .replace("__ITEMS__", json.dumps(build_index(world, missions), ensure_ascii=False))
            .replace("__PHASES__", json.dumps(PHASES)))
    out.write_text(page)
    print("wrote", out, f"({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
