# Hill country content, then tunnels and bridges (started 2026-10-31)

Sachin, 2026-10-31: "Build the content, and then the tunnels and bridges"
(after the land step; content = TODO.md hill country steps 2-4; tunnels and
bridges = #110). Design: `docs/hill_country_design_map.png`,
tools/hill_design_map.py (places, zones, lines). Land notes:
HANDOFF-hill-country.md. Rough cost from TODO: steps 2-4 ~140-260 h, #110
on top; built in phases, each committed; `/effort xhigh` suits it.

## Phases

1. **Places** (#122): done; plan text in the archive.
2. **Life** (#123): wildlife (deer, coyote, mountain lion, rabbit: built
   meshes, leg animation, wander/flee/attack), hunting (rifle sold with a
   licence at the hunting store, seasons, pelts), flora bands by height,
   hikers/runners/hunters on trails, a weekday calendar with small-town
   events (fair, rodeo, market, festival, speed trap) and night raves.
3. **Activities** (#124): checkpoint races and illegal night races on the
   hill loop, stunt jumps (ramp surface + airtime), cycling, parachuting,
   bungee.
4. **Tunnels and bridges** (#125, #110): a deck layer (polylines with width
   and z profile) that vehicles and people stand on when near its level;
   bridge meshes; tunnel portals, tubes, terrain cut at portals, the
   see-through view inside; then the 26 `structures`, stream crossings,
   the sky bridge, rail bridges.

## Decisions

- Hunting goes ahead (Sachin 2026-10-30 asked for licence, seasons, store,
  pelts); the older ACTIVITY_ROADMAP line "Hunting: never" is superseded.
  No weapons exist: a hunting rifle that fires only at animals, only in the
  hunting ground, keeps it from becoming a general weapons system.
- Cult: fictional beliefs, no real religious symbols or text (world bible).
- Parachuting: the summit helipad is #113 (not asked), so jumps start from
  a helicopter (#115) or a cliff BASE exit.
- Stunt ramps need a surface above the ground grid: built as the first use
  of the phase-4 deck layer, or as a ramp pad in the grid if that is enough.
- Hill places run after every other lot step and the trailer clusters draw
  from their own rng (HILL_SEED), so no existing lot moves.
- Lakes fill real closed basins of the raw grid below a set level
  (HILL_LAKES), so shores are natural; the bed is dug up to LAKE_DEPTH
  (mountain.grid, `lakes`), the water mesh runs LAKE_EDGE past the shore
  under the rising ground, at level - 0.3; invisible kind-3 walls on the
  shore keep movers out (no swimming yet).
- Streams: steepest descent on the smoothed grid from HILL_STREAMS springs,
  stopping at a lake, the sea or height 3; cut at roads (culverts implied
  until phase 4 adds crossings); ribbons in the tile's `water` mesh.
- Lab road (lane, 14 % at the cap) and Timber Haul (track, 25 %) are
  mountain_plan SPECS. The design's logging camp on the ridge west of the
  Morrow (-332, -4300) is off the play land (A), and a crossing there lands
  on a 13 m bank the game's low deck can't climb, so the camp and the haul
  moved into the forest east of Route 9 (250, -4110); no bridge.
- Village walks: a loop down both shoulders of each village road (no
  sidewalks on hill roads). Village diners/stores open as places in their
  own cap (places.gd HILL_MAX) after the suburbs', so suburb picks hold.

## Facts

- No ground collider: vehicles and people set y = Terrain.height
  (vehicle.gd:1368, humanoid.gd:170); colliders are boxes only.
- One water plane at y -0.55; lakes at a level need their own mesh.
- No peds in the hills: population spawns on `walks`, made only in
  WALK_ZONES (build_country.py:275).
- places.gd opens diners/stores only in SUBURB_ZONES (52-54).
- Rebuild: plan_dump, then build_country, then mountain_plan / world map
  (HANDOFF-hill-country.md). RNG use changes shift lots everywhere.

## Traps

- `_wet_only` keeps a planned bridge only over water; when the planner's
  span ends high on a bank, the road climbs it at 90 %+ (check the build
  log's "steepest" lines after adding a bridged way).

## Open
- Timber Haul hairpin_r 14 (8 put the hairpin's legs 16 m apart; one leg's
  carve broke the other's profile: 54.7 % at (304, -4192)).
- Lab gate stands beside Kestrel Hollow Road, not astride it (review M1):
  lay it across the road (yaw along it, excused from the lot-on-road
  check) in the phase-4 rebuild. Its arm is drawn raised until then.
- Bungee platform sits on a level pad: phase 3 needs a cliff-edge site.

## Status
- Phase 1 committed: hill_kit (e3f7d00, review fixes in), TEST_MODULES
  hook (a708f59). Hikers/hunters on 14 trail loops (trail_walks read
  self.trails; a point-offset loop on the 12 m resampled line, since round
  joins and switchbacks put points 6 m off). Hunting store opens as a place.
- Sachin 10-31: "It can be single hikers, couples or group of hikers, not
  same all the time" -> trail parties (Pedestrian.TRAIL_PARTY/pick_party,
  join_party slots; population queues bodies by party). Hikers 1-4,
  runners 1-2, hunters 1-2 in file. Done, tested (aa80800).
- hunting.gd + shop rows + save in (tests/hunting_tests.gd); shooting
  waits on the wildlife API.
- Calendar + events (package C) in and wired (39bb3df): main.gd makes
  calendar and hunting BEFORE missions (missions._ready loads the save into
  them; hunting used to be null there), events after taxi; save/load/reset
  carry "calendar" and set atmosphere.sky.day = calendar.day() (moon and
  the cult's full-moon rule day % 8 == 2 must agree); phone Events app.
  calendar_tests use the game's own nodes (a second Events built twice).
  Gates: 9 calendar tests 129/0; hunting, bag/save, phone, taxi-phone,
  city-population pass.

## Handover (paused 2026-10-31 at Sachin's request)
Resume order (each step: focused tests, then commit and push):
1. Wildlife (package W, 6d820f8, committed WIP, unreviewed, NOT hooked in):
   scripts/wildlife.gd, kits/animal_kit.gd, tests/wildlife_tests.gd (9
   tests; run in TEST_MODULES), tests/wildlife_gallery.tscn. API: static
   attach(atm) -> node; static startle(pos, r); animals_in(pos, r,
   with_dead); kill(a, dir, by); hurt(a, dmg, dir, by); carcass_near(pos,
   r); take_carcass(c) -> kind; signal killed(kind, pos, by). Animal dict
   keys: check _make() (kind deer/rabbit/coyote/lion, pos, dead, hp, ...).
   a. Patch atmosphere.gd: `const Wildlife = preload(...wildlife.gd)`,
      `var wildlife: Node`, `wildlife = Wildlife.attach(self)` after the
      birds block. Patch fx.gd: same preload, and after each
      Birds.startle (4 calls) the matching Wildlife.startle with the same
      pos and radius 18-28 / 20+30*strength / 60*scale / 25.
   b. Render check: game/tests/wildlife_gallery.tscn "all" under xvfb
      (opengl3), contact sheet, judge buck/coyote/lion/rabbit colours and
      night eyeshine (only the doe was checked after the colour fix); tune
      hide colours in animal_kit _deer/_rabbit/_coyote/_lion. Gallery
      blood decals pile up on z=0 (give each row its own z).
   c. Per-package Opus review of W, fix findings.
2. Hunting on the real API (main session): hunting.gd already calls
   _wildlife() = atmosphere.wildlife; adapt to the dict keys, then tests:
   shoot a deer in season, poaching (closed season / no licence / lion)
   gives a star, skin a carcass for a pelt. Name clash: hunting passes
   "lion", calendar's season table says "mountain_lion": use one (L8).
3. Calendar review leftovers (review of 39bb3df; H1 and M2 fixed):
   M1 time skips lose days (phone Skip 3 h runs paused; call
   calendar.tick after each press) and sky.day drifts while indoors
   (_apply_indoors skips sky.update): make the calendar the only day
   counter and have sky.gd read it. M3 event lights sit on top of the
   street-lamp budget: graphics should subtract Events.lights_used.
   Lows: ArrayMesh not cached per kind (rebuilt on each re-entry); queued
   PeopleBuilder tickets still build after free; show_banner shares the
   district label; phone Events should skip non-finite pos; stale
   comments calendar_tests.gd:7-8, sky.gd:47-48.
4. Phase 1 screenshots never taken: Tallow Lake, a stream, Brackett,
   Hollin, hunting store interior, trail parties.
5. Phase 2 close: full game/tests/run.sh, screenshots, one Opus review
   of the whole task, then phases 3 and 4 (above).
Every godot run under `flock /tmp/godot.lock`; worst off-flat 4.25 m at
(2341,-2140) near Brackett is unchecked (new or old).

Phase 2 package plan: HANDOFF-hill-content-archive.md.
