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
Phases 1-2 history (status, the 10-31 handover list): archive.

## Resumed 2026-10-31 (session 2, branch claude/gangstar-game-content-tunnels-kszhz9)
Sachin's order: wildlife hook-in + colours + Opus review; hunting on the
animals with tests; calendar fixes M1, M3; hill-place shots, full suite,
one review of the whole task; then phase 3 and phase 4.
- Done (8d8840f, + tests commit): wildlife attached in atmosphere.gd,
  Wildlife.startle beside each Birds.startle in fx.gd (radii 28/18,
  20+30s, 60*scale, 25). Colours retuned after the gallery (ACES makes
  hides orange): doe 0.55/0.45/0.35, buck 0.47/0.39/0.31, coyote fur
  0.52/0.47/0.40, lion fur 0.62/0.50/0.37. Eyeshine: a 1-px yellow glint
  at game range (eyes 3 cm), kept.
- Hunting: carcass_near returns {} (not null): hunting._carcass maps it
  to null (the HUD threw a script error every frame). Season table key
  is "lion" (wildlife's kind); "mountain_lion" still parses. Tests:
  shoot a deer in season, poaching (no licence / deer in winter / lion),
  skinning (full bag keeps the carcass).
- M1: Atmosphere.advance(hours) counts each midnight (calendar.add_days);
  phone Skip and taxi skip use it; sky.update ticks atm.calendar and reads
  its day (sky counts its own only with no calendar: galleries).
  M3: graphics._light_lamps budget = lamps - Events.lights_used.
  Calendar Lows (mesh cache, PeopleBuilder tickets after free, banner
  label, phone non-finite pos) not done: not in Sachin's list.
- Shots: SHOTS=hillplaces (screenshots.gd, hill_1..7) and PLACES=hill
  (place_shots.gd: the hunting store front, door, inside, menu).
- Trap: the test runner does NOT fail on SCRIPT ERROR; grep for it.
- Wildlife review (Opus, 0 High, 3 Medium, 8 Low), all fixed: lion warns
  on the HUD (wildlife.warned signal) when it stalks and charges, leaves
  for good after one strike (a.spent), a lion shot while stalking or
  charging is self-defence (no star); refresh keeps carcasses within
  DESPAWN; carcass slide stops at blocked ground or a road; in_city cached
  per 8 m cell; no work with no animals; leave kept at obstacles, leaving
  animals (not lions) still flee; cars >6 m above/below scare nothing,
  kill gap 2 m (bridges); _push sets only changes; MMI interpolation off
  (birds too). Tests tightened (startle, day lion, indoors) + Fx test.
- Trail shot: no trail person came by loop 904 in 20 s at noon, so the
  shot scripts a party; 26 of its 128 points lie within 6 m of a road.

## Phase 3 and 4 plan (decided 2026-10-31)
- vehicle.gd has no air state (y = Terrain.height each frame), so stunt
  jumps and the deck layer share one change: a ground layer (decks: ramps,
  bridges, tunnel floors) and a ballistic air state. One Opus package owns
  vehicle.gd/humanoid.gd ground code: G = deck layer + airtime + stunt
  ramps. Wave A in parallel worktrees: R (races, illegal night races,
  downhill bike time trial; Sonnet xhigh), G (Opus xhigh), P (parachute
  and bungee; Opus xhigh, physics). Wave B after G: bridges and tunnels
  (Opus). Main session wires each into main.gd/hud.gd and merges.
  Cheaper option named for Sachin: all in the main session, sequential.

Phase 2 package plan: HANDOFF-hill-content-archive.md.
