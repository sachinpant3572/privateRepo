# Hill country content, then tunnels and bridges (started 2026-10-31)

Sachin, 2026-10-31: "Build the content, and then the tunnels and bridges"
(after the land step; content = TODO.md hill country steps 2-4; tunnels and
bridges = #110). Design: `docs/hill_country_design_map.png`,
tools/hill_design_map.py (places, zones, lines). Land notes:
HANDOFF-hill-country.md. Rough cost from TODO: steps 2-4 ~140-260 h, #110
on top; built in phases, each committed; `/effort xhigh` suits it.

## Phases

1. **Places** (#122). Generator (main session): a `hill_places` step in
   build_country.py before `street_lots`, from a HILL_PLACES table (kind,
   x, y, id): frontage lots along the nearest way for the two villages, a
   trailer park cluster, single sites for the rest; the lab road and the
   timber haul as mountain_plan SPECS; Tallow Lake and Fernmoor Pond as
   level water with dug beds; streams as ribbons; walks in the villages so
   people spawn; mountain-zone diner/store/hunting store open as places.
   Kit (builder agent, owns scripts/kits/hill_kit.gd): research_lab,
   lab_gate, sawmill, cult_compound, ranger_post, logging_camp,
   mine_entrance, stone_ring, hot_spring, cold_spring, mountain_hotel,
   lodge_hotel, rave_clearing, bungee_platform, fairground, hunting_store.
   Reused kinds: diner, gas_station, general_store, motel, truck_stop, bar,
   house, garage, town_hall, trailer park (cluster style "trailers").
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
  hook (a708f59). Hikers/hunters on trail loops: code in, waits on the
  country rebuild (trail_walks). Hunting store opens as a place (type
  hunting_store, door from hill_kit, room _hunting_store, icon R).

## Phase 2 plan (life)

- Flora bands by height already exist (flora_kit `pick`: pine from 120 m,
  oaks thinning above 450 m, rock above 680 m); phase 2 adds wildflower
  meadows and ferns only.
- Packages (cost ~ each builder 1-2 h + an Opus review; the cheaper option
  is all in the main session, slower and serial):
  W wildlife (builder): scripts/wildlife.gd, kits/animal_kit.gd,
  tests/wildlife_tests.gd. C calendar + events (builder): scripts/calendar.gd,
  scripts/events.gd, tests/calendar_tests.gd. H hunting (after W; touches
  inventory, shop, hud, player): main session. Hikers/runners/hunters on
  trails (generator walks + population looks): main session.
- Test modules: test_runner.gd runs `TEST_MODULES` (each a script with
  `const TESTS` and `func test_x(t)`), so builders never edit test_runner.gd.
